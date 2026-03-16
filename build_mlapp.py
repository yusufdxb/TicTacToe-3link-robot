"""
build_mlapp.py
Generates TicTacToe_App.mlapp from the MATLAB classdef code.
A .mlapp is a ZIP archive containing:
  - metadata/appMetadata.xml
  - matlab/document.xml   (layout)
  - matlab/code.m         (the classdef)
Run: python3 build_mlapp.py
"""
import zipfile, textwrap, os

# ── The full classdef (no API key, safe to commit) ─────────────────────────
CODE = r'''classdef TicTacToe_App < matlab.apps.AppBase

    % =========================================================
    % TicTacToe 3-Link Robot — Combined App
    % ROS visualization + TicTacToe game + Arduino servo control
    %
    % API keys are NEVER stored here.
    % Load them at runtime from config.m:
    %   cfg = load_config();
    %   api_key = cfg.openai_key;
    % =========================================================

    properties (Access = public)
        figure1           matlab.ui.Figure
        % ── Menus ──────────────────────────────────────────
        Arduino           matlab.ui.container.Menu
        Connect           matlab.ui.container.Menu
        Disconnect        matlab.ui.container.Menu
        ConnectMotorMenu  matlab.ui.container.Menu
        % ── Robot panel ────────────────────────────────────
        axes1             matlab.ui.control.UIAxes
        slider1           matlab.ui.control.Slider
        slider2           matlab.ui.control.Slider
        slider3           matlab.ui.control.Slider
        text2             matlab.ui.control.Label
        text3             matlab.ui.control.Label
        text_pen          matlab.ui.control.Label
        Create            matlab.ui.control.Button
        HardwareMove      matlab.ui.control.Button
        DRAWButton        matlab.ui.control.Button
        PenUpButton       matlab.ui.control.Button
        PenDownButton     matlab.ui.control.Button
        % ── TicTacToe panel ────────────────────────────────
        NewGameButton     matlab.ui.control.Button
        StatusLabel       matlab.ui.control.Label
        BoardLabel        matlab.ui.control.Label
        btn11             matlab.ui.control.Button
        btn12             matlab.ui.control.Button
        btn13             matlab.ui.control.Button
        btn21             matlab.ui.control.Button
        btn22             matlab.ui.control.Button
        btn23             matlab.ui.control.Button
        btn31             matlab.ui.control.Button
        btn32             matlab.ui.control.Button
        btn33             matlab.ui.control.Button
    end

    properties (Access = private)
        % ── Hardware ───────────────────────────────────────
        device          = []
        robot           = []
        servo_motor1    = []
        servo_motor2    = []
        servo_motor3    = []
        jointangle      = [0 0]
        data_available  = false
        base_joint      = 0

        % ── Servo smoothing ────────────────────────────────
        lastServoPos        = NaN
        lastServoWriteTime  = 0
        lastServoPos2       = NaN
        lastServoWriteTime2 = 0
        lastServoPos3       = NaN
        lastServoWriteTime3 = 0
        servoDeadband   = 0.01
        servoMinPeriod  = 0.03

        % ── Robot config ───────────────────────────────────
        joint1PlotOffset = pi/2
        joint2PlotOffset = 0
        servo1Reversed   = false
        servo2Reversed   = false
        servo3Reversed   = false
        penServoStartPos = 0.8
        horizontalArcComp = -0.0025
        joint1Cal_q = []
        joint1Cal_s = []
        joint2Cal_q = []
        joint2Cal_s = []

        % ── TicTacToe state ────────────────────────────────
        board           = zeros(3,3)   % 0=empty 1=human 2=robot
        gameActive      = false
        squareBtns      = []           % 3x3 cell of button handles
    end

    % =============================================================
    %  PRIVATE HELPERS
    % =============================================================
    methods (Access = private)

        % ── Robot plot ────────────────────────────────────
        function updateRobotPlot(app)
            if ~isempty(app.robot)
                app.robot.plot(app.jointangle, ...
                    'workspace', [-300 300 -300 300 -50 300]);
                drawnow limitrate;
            end
        end

        % ── Calibration ───────────────────────────────────
        function pos01 = joint1ToServoPosition(app, q1)
            if isempty(app.joint1Cal_q)
                qlim  = app.slider1.Limits;
                pos01 = (q1 - qlim(1)) / (qlim(2) - qlim(1));
            else
                pos01 = interp1(app.joint1Cal_q, app.joint1Cal_s, q1, 'linear', 'extrap');
            end
            pos01 = max(0, min(1, pos01));
        end

        function pos01 = joint2ToServoPosition(app, q2)
            if isempty(app.joint2Cal_q)
                qlim  = app.slider2.Limits;
                pos01 = (q2 - qlim(1)) / (qlim(2) - qlim(1));
            else
                pos01 = interp1(app.joint2Cal_q, app.joint2Cal_s, q2, 'linear', 'extrap');
            end
            pos01 = max(0, min(1, pos01));
        end

        function pos01 = slider3ToServoPosition(app, s3)
            qlim  = app.slider3.Limits;
            pos01 = (s3 - qlim(1)) / (qlim(2) - qlim(1));
            pos01 = max(0, min(1, pos01));
        end

        % ── Smooth servo writes ───────────────────────────
        function writeServoFromJoint1(app, q1)
            if isempty(app.servo_motor1), return; end
            targetPos = app.joint1ToServoPosition(q1);
            if ~isnan(app.lastServoPos) && abs(targetPos - app.lastServoPos) < app.servoDeadband, return; end
            if app.lastServoWriteTime ~= 0 && toc(app.lastServoWriteTime) < app.servoMinPeriod, return; end
            newPos = isnan(app.lastServoPos) * targetPos + ~isnan(app.lastServoPos) * (app.lastServoPos + 0.35*(targetPos - app.lastServoPos));
            newPos = max(0, min(1, newPos));
            writePosition(app.servo_motor1, newPos);
            app.lastServoPos       = newPos;
            app.lastServoWriteTime = tic;
        end

        function writeServoFromJoint2(app, q2)
            if isempty(app.servo_motor2), return; end
            targetPos = app.joint2ToServoPosition(q2);
            if ~isnan(app.lastServoPos2) && abs(targetPos - app.lastServoPos2) < app.servoDeadband, return; end
            if app.lastServoWriteTime2 ~= 0 && toc(app.lastServoWriteTime2) < app.servoMinPeriod, return; end
            newPos = isnan(app.lastServoPos2) * targetPos + ~isnan(app.lastServoPos2) * (app.lastServoPos2 + 0.35*(targetPos - app.lastServoPos2));
            newPos = max(0, min(1, newPos));
            writePosition(app.servo_motor2, newPos);
            app.lastServoPos2       = newPos;
            app.lastServoWriteTime2 = tic;
        end

        function writeServoFromSlider3(app, s3)
            if isempty(app.servo_motor3), return; end
            targetPos = app.slider3ToServoPosition(s3);
            if app.servo3Reversed, targetPos = 1 - targetPos; end
            if ~isnan(app.lastServoPos3) && abs(targetPos - app.lastServoPos3) < app.servoDeadband, return; end
            if app.lastServoWriteTime3 ~= 0 && toc(app.lastServoWriteTime3) < app.servoMinPeriod, return; end
            newPos = isnan(app.lastServoPos3) * targetPos + ~isnan(app.lastServoPos3) * (app.lastServoPos3 + 0.35*(targetPos - app.lastServoPos3));
            newPos = max(0, min(1, newPos));
            writePosition(app.servo_motor3, newPos);
            app.lastServoPos3       = newPos;
            app.lastServoWriteTime3 = tic;
        end

        % ── Direct servo writes (drawing) ─────────────────
        function writeServoFromJoint1Direct(app, q1)
            if isempty(app.servo_motor1), return; end
            pos01 = max(0, min(1, app.joint1ToServoPosition(q1)));
            writePosition(app.servo_motor1, pos01);
            app.lastServoPos = pos01; app.lastServoWriteTime = tic;
        end

        function writeServoFromJoint2Direct(app, q2)
            if isempty(app.servo_motor2), return; end
            pos01 = max(0, min(1, app.joint2ToServoPosition(q2)));
            writePosition(app.servo_motor2, pos01);
            app.lastServoPos2 = pos01; app.lastServoWriteTime2 = tic;
        end

        % ── Arm motion ────────────────────────────────────
        function moveArmToJointAnglesDirect(app, q1, q2)
            q1 = max(min(q1, app.slider1.Limits(2)), app.slider1.Limits(1));
            q2 = max(min(q2, app.slider2.Limits(2)), app.slider2.Limits(1));
            app.jointangle = [q1 q2];
            app.slider1.Value = q1; app.slider2.Value = q2;
            app.writeServoFromJoint1Direct(q1);
            app.writeServoFromJoint2Direct(q2);
            app.updateRobotPlot(); drawnow;
        end

        % ── Planar IK ─────────────────────────────────────
        function [q1, q2, ok] = planarIK(app, xWorld, yWorld)
            a1=110; a2=104; x0=-29; y0=121;
            x=xWorld-x0; y=yWorld-y0;
            c2=(x^2+y^2-a1^2-a2^2)/(2*a1*a2);
            if abs(c2)>1, q1=NaN; q2=NaN; ok=false; return; end
            s2a=sqrt(1-c2^2); s2b=-s2a;
            t2a=atan2(s2a,c2); t1a=atan2(y,x)-atan2(a2*s2a,a1+a2*c2);
            t2b=atan2(s2b,c2); t1b=atan2(y,x)-atan2(a2*s2b,a1+a2*c2);
            q1a=t1a-app.robot.links(1).offset; q2a=t2a-app.robot.links(2).offset;
            q1b=t1b-app.robot.links(1).offset; q2b=t2b-app.robot.links(2).offset;
            if norm([q1a q2a]-app.jointangle) <= norm([q1b q2b]-app.jointangle)
                q1=q1a; q2=q2a;
            else
                q1=q1b; q2=q2b;
            end
            ok=true;
        end

        % ── Pen ───────────────────────────────────────────
        function penDown(app)
            if ~isempty(app.servo_motor3), writePosition(app.servo_motor3,0.20); pause(0.3); end
        end
        function penUp(app)
            if ~isempty(app.servo_motor3), writePosition(app.servo_motor3,0.80); pause(0.3); end
        end

        % ── Line drawing ──────────────────────────────────
        function drawVerticalLine(app, xLine, yStart, yEnd, nPts)
            yVals = linspace(yStart, yEnd, nPts);
            [q1s,q2s,ok] = app.planarIK(xLine, yStart);
            if ~ok, return; end
            app.moveArmToJointAnglesDirect(q1s,q2s); pause(0.5);
            app.penDown();
            for k=1:length(yVals)
                [q1,q2,ok]=app.planarIK(xLine,yVals(k));
                if ~ok, continue; end
                app.moveArmToJointAnglesDirect(q1,q2); pause(0.08);
            end
            app.penUp();
        end

        function drawHorizontalLine(app, yLine, xStart, xEnd, nPts)
            xVals = linspace(xStart,xEnd,nPts);
            xMid  = (xStart+xEnd)/2;
            yCmd  = yLine + app.horizontalArcComp*(xVals-xMid).^2;
            [q1s,q2s,ok]=app.planarIK(xVals(1),yCmd(1));
            if ~ok, return; end
            app.moveArmToJointAnglesDirect(q1s,q2s); pause(0.5);
            app.penDown();
            for k=1:length(xVals)
                [q1,q2,ok]=app.planarIK(xVals(k),yCmd(k));
                if ~ok, continue; end
                app.moveArmToJointAnglesDirect(q1,q2); pause(0.08);
            end
            app.penUp();
        end

        % ── Draw X ────────────────────────────────────────
        function drawX(app, row, col)
            centers = [60,170; 90,170; 120,170;
                       60,140; 90,140; 120,140;
                       60,110; 90,110; 120,110];
            idx = (row-1)*3+col;
            cx=centers(idx,1); cy=centers(idx,2); s=18;
            app.drawDiagonal(cx-s,cy+s,cx+s,cy-s); pause(0.3);
            app.drawDiagonal(cx+s,cy+s,cx-s,cy-s);
        end

        function drawO(app, row, col)
            centers = [60,170; 90,170; 120,170;
                       60,140; 90,140; 120,140;
                       60,110; 90,110; 120,110];
            idx=(row-1)*3+col;
            cx=centers(idx,1); cy=centers(idx,2); r=18; nPts=40;
            t=linspace(0,2*pi,nPts);
            xV=cx+r*cos(t); yV=cy+r*sin(t);
            [q1s,q2s,ok]=app.planarIK(xV(1),yV(1));
            if ~ok, return; end
            app.moveArmToJointAnglesDirect(q1s,q2s); pause(0.5);
            app.penDown();
            for k=1:nPts
                [q1,q2,ok]=app.planarIK(xV(k),yV(k));
                if ~ok, continue; end
                app.moveArmToJointAnglesDirect(q1,q2); pause(0.08);
            end
            app.penUp();
        end

        function drawDiagonal(app, x1,y1,x2,y2)
            nPts=40;
            xV=linspace(x1,x2,nPts); yV=linspace(y1,y2,nPts);
            [q1s,q2s,ok]=app.planarIK(xV(1),yV(1));
            if ~ok, return; end
            app.moveArmToJointAnglesDirect(q1s,q2s); pause(0.5);
            app.penDown();
            for k=1:nPts
                [q1,q2,ok]=app.planarIK(xV(k),yV(k));
                if ~ok, continue; end
                app.moveArmToJointAnglesDirect(q1,q2); pause(0.08);
            end
            app.penUp();
        end

        % ── TicTacToe logic ───────────────────────────────
        function result = checkWinner(app)
            b=app.board;
            for p=[1 2]
                for r=1:3
                    if all(b(r,:)==p), result=p; return; end
                end
                for c=1:3
                    if all(b(:,c)==p), result=p; return; end
                end
                if b(1,1)==p&&b(2,2)==p&&b(3,3)==p, result=p; return; end
                if b(1,3)==p&&b(2,2)==p&&b(3,1)==p, result=p; return; end
            end
            if all(b(:)~=0), result=3; return; end
            result=0;
        end

        function [br,bc] = minimaxBestMove(app)
            bestScore=-Inf; br=-1; bc=-1;
            for r=1:3
                for c=1:3
                    if app.board(r,c)==0
                        app.board(r,c)=2;
                        score=app.minimaxScore(false);
                        app.board(r,c)=0;
                        if score>bestScore, bestScore=score; br=r; bc=c; end
                    end
                end
            end
        end

        function s = minimaxScore(app, isMax)
            res=app.checkWinner();
            if res==2, s=10; return; end
            if res==1, s=-10; return; end
            if res==3, s=0; return; end
            if isMax
                s=-Inf;
                for r=1:3, for c=1:3
                    if app.board(r,c)==0
                        app.board(r,c)=2;
                        s=max(s,app.minimaxScore(false));
                        app.board(r,c)=0;
                    end
                end, end
            else
                s=Inf;
                for r=1:3, for c=1:3
                    if app.board(r,c)==0
                        app.board(r,c)=1;
                        s=min(s,app.minimaxScore(true));
                        app.board(r,c)=0;
                    end
                end, end
            end
        end

        function updateBoardDisplay(app)
            sym={'.','X','O'};
            str='';
            for r=1:3
                for c=1:3
                    str=[str ' ' sym{app.board(r,c)+1} ' '];
                    if c<3, str=[str '|']; end
                end
                str=[str newline];
                if r<3, str=[str '---|---|---' newline]; end
            end
            app.BoardLabel.Text=str;
        end

        function updateSquareButtons(app)
            sym={' ','X','O'};
            colors={[0.94 0.94 0.94],[0.2 0.5 0.9],[0.9 0.5 0.2]};
            for r=1:3
                for c=1:3
                    btn=app.squareBtns{r,c};
                    v=app.board(r,c);
                    btn.Text=sym{v+1};
                    btn.BackgroundColor=colors{v+1};
                    btn.Enable = app.gameActive && (v==0);
                end
            end
        end

    end % private methods

    % =============================================================
    %  CALLBACKS
    % =============================================================
    methods (Access = private)

        function Connect_Callback(app, ~)
            com=char(inputdlg('COM Port?','Connect',[1 30],{'COM5'}));
            if isempty(com), return; end
            try
                app.device=arduino(com,'uno','libraries','Servo');
                app.data_available=true;
                app.lastServoWriteTime=tic;
                msgbox('Arduino connected.');
            catch
                msgbox(['Failed: ' com],'Error');
            end
        end

        function Disconnect_Callback(app, ~)
            try, app.device.delete; catch, end
            app.device=[]; app.servo_motor1=[]; app.servo_motor2=[]; app.servo_motor3=[];
            app.data_available=false;
            msgbox('Disconnected.');
        end

        function Create_Callback(app, ~)
            L(1)=Link('revolute','d',25,'a',110,'alpha',0,'offset',-0.43);
            L(2)=Link('revolute','d',5, 'a',104,'alpha',0,'offset', 0.43-pi/2);
            L(1).qlim=deg2rad([-5 205]); L(2).qlim=deg2rad([-80 130]);
            app.robot=SerialLink(L,'name','TicTacToeArm');
            app.robot.base=transl(-29,121,77);
            app.slider1.Limits=L(1).qlim; app.slider2.Limits=L(2).qlim;
            app.joint1Cal_q=deg2rad([-5 45 95 145 205]);
            app.joint1Cal_s=[0.92 0.72 0.50 0.28 0.08];
            app.joint2Cal_q=deg2rad([-80 -30 20 75 130]);
            app.joint2Cal_s=[0.75 0.62 0.48 0.33 0.20];
            q1s=max(min(app.joint1PlotOffset,L(1).qlim(2)),L(1).qlim(1));
            q2s=max(min(app.joint2PlotOffset,L(2).qlim(2)),L(2).qlim(1));
            app.jointangle=[q1s q2s];
            app.slider1.Value=q1s; app.slider2.Value=q2s;
            app.robot.plot(app.jointangle,'workspace',[-300 300 -300 300 -50 300]);
        end

        function ConnectMotor(app, ~)
            if ~app.data_available, msgbox('Connect Arduino first.'); return; end
            try
                app.servo_motor1=servo(app.device,'D3','MinPulseDuration',0.5e-3,'MaxPulseDuration',2.5e-3);
                app.servo_motor2=servo(app.device,'D5','MinPulseDuration',0.5e-3,'MaxPulseDuration',2.5e-3);
                app.servo_motor3=servo(app.device,'D6','MinPulseDuration',0.5e-3,'MaxPulseDuration',2.5e-3);
                writePosition(app.servo_motor3, app.penServoStartPos);
                app.lastServoPos=app.joint1ToServoPosition(app.slider1.Value);
                app.lastServoPos2=app.joint2ToServoPosition(app.slider2.Value);
                app.lastServoPos3=app.penServoStartPos;
                app.lastServoWriteTime=tic; app.lastServoWriteTime2=tic; app.lastServoWriteTime3=tic;
                msgbox('Motors connected.');
            catch ME
                msgbox(['Servo error: ' ME.message],'Error');
            end
        end

        function HardwareMove_Callback(app, ~)
            if ~app.data_available, msgbox('Connect hardware first.'); return; end
            raw=inputdlg('Steps?','Steps'); if isempty(raw), return; end
            steps=round(str2double(raw{1}));
            if isnan(steps)||steps<1, msgbox('Enter a positive integer.'); return; end
            btn=questdlg('Joint?','Joint','1','2','Cancel','1');
            if strcmp(btn,'Cancel')||isempty(btn), return; end
            J=str2double(btn);
            for i=1:steps
                v=app.device.readVoltage('A0');
                if isnumeric(v), pause(0.1);
                    if J==1, app.jointangle(1)=v; else, app.jointangle(2)=v; end
                    app.robot.plot(app.jointangle);
                end
            end
            msgbox('Done.');
        end

        % ── Sliders ───────────────────────────────────────
        function slider1_Callback(app, ~)
            app.jointangle=[app.slider1.Value app.slider2.Value];
            app.updateRobotPlot();
        end
        function slider2_Callback(app, ~)
            app.jointangle=[app.slider1.Value app.slider2.Value];
            app.updateRobotPlot();
        end
        function slider1ValueChanging(app, event)
            app.jointangle(1)=event.Value; app.writeServoFromJoint1(event.Value); app.updateRobotPlot();
        end
        function slider2ValueChanging(app, event)
            app.jointangle(2)=event.Value; app.writeServoFromJoint2(event.Value); app.updateRobotPlot();
        end
        function slider3ValueChanged(app, event)
            app.writeServoFromSlider3(event.Value);
        end
        function slider3ValueChanging(app, event)
            app.writeServoFromSlider3(event.Value);
        end

        % ── Pen buttons ───────────────────────────────────
        function PenUpButton_Callback(app, ~)
            app.penUp();
        end
        function PenDownButton_Callback(app, ~)
            app.penDown();
        end

        % ── Key jog ───────────────────────────────────────
        function MoveWithKey(app, event)
            if strcmp(event.Key,'leftarrow'),  app.base_joint=app.base_joint-0.1;
            elseif strcmp(event.Key,'rightarrow'), app.base_joint=app.base_joint+0.1; end
            if ~isempty(app.robot)
                app.robot.plot([app.base_joint 0],'workspace',[-300 300 -300 300 -50 300]);
            end
        end

        % ── DRAW grid ─────────────────────────────────────
        function DRAWButtonPushed(app, ~)
            if isempty(app.robot),        msgbox('Create robot first.');   return; end
            if isempty(app.servo_motor1), msgbox('Connect motors first.'); return; end
            nPts=40;
            app.drawVerticalLine(120,10,200,nPts); pause(0.5);
            app.drawVerticalLine(60, 10,160,nPts); pause(0.5);
            app.drawHorizontalLine(90, 0,170,nPts); pause(0.5);
            app.drawHorizontalLine(150,0,170,nPts);
        end

        % ── TicTacToe — New Game ──────────────────────────
        function NewGame_Callback(app, ~)
            app.board=zeros(3,3);
            app.gameActive=true;
            app.StatusLabel.Text='Your turn — click a square (you are X)';
            app.updateBoardDisplay();
            app.updateSquareButtons();
        end

        % ── TicTacToe — Square clicked ────────────────────
        function SquareClicked(app, row, col)
            if ~app.gameActive, return; end
            if app.board(row,col)~=0, return; end

            % Human move
            app.board(row,col)=1;
            app.updateBoardDisplay();
            app.updateSquareButtons();

            % Draw X on paper
            if ~isempty(app.servo_motor1)
                app.drawX(row,col);
            end

            res=app.checkWinner();
            if res==1
                app.StatusLabel.Text='You win!';
                app.gameActive=false;
                app.updateSquareButtons(); return;
            elseif res==3
                app.StatusLabel.Text='Draw!';
                app.gameActive=false;
                app.updateSquareButtons(); return;
            end

            % Robot move (Minimax)
            app.StatusLabel.Text='Robot thinking...';
            drawnow;
            [br,bc]=app.minimaxBestMove();
            app.board(br,bc)=2;
            app.updateBoardDisplay();
            app.updateSquareButtons();

            % Draw O on paper
            if ~isempty(app.servo_motor1)
                app.drawO(br,bc);
            end

            res=app.checkWinner();
            if res==2
                app.StatusLabel.Text='Robot wins!';
                app.gameActive=false;
                app.updateSquareButtons();
            elseif res==3
                app.StatusLabel.Text='Draw!';
                app.gameActive=false;
                app.updateSquareButtons();
            else
                app.StatusLabel.Text='Your turn — click a square';
            end
        end

        % ── Square button callbacks (one per cell) ────────
        function btn11_Callback(app,~), app.SquareClicked(1,1); end
        function btn12_Callback(app,~), app.SquareClicked(1,2); end
        function btn13_Callback(app,~), app.SquareClicked(1,3); end
        function btn21_Callback(app,~), app.SquareClicked(2,1); end
        function btn22_Callback(app,~), app.SquareClicked(2,2); end
        function btn23_Callback(app,~), app.SquareClicked(2,3); end
        function btn31_Callback(app,~), app.SquareClicked(3,1); end
        function btn32_Callback(app,~), app.SquareClicked(3,2); end
        function btn33_Callback(app,~), app.SquareClicked(3,3); end

    end % callbacks

    % =============================================================
    %  COMPONENT CREATION
    % =============================================================
    methods (Access = private)

        function createComponents(app)
            app.figure1 = uifigure('Visible','off');
            app.figure1.Position = [100 100 1100 520];
            app.figure1.Name     = 'TicTacToe Robot';
            app.figure1.Resize   = 'off';
            app.figure1.KeyPressFcn   = createCallbackFcn(app,@MoveWithKey,true);
            app.figure1.KeyReleaseFcn = createCallbackFcn(app,@MoveWithKey,true);

            % ── Menus ─────────────────────────────────────
            app.Arduino          = uimenu(app.figure1,'Text','Arduino');
            app.Connect          = uimenu(app.Arduino,'Text','Connect','MenuSelectedFcn',createCallbackFcn(app,@Connect_Callback,true));
            app.Disconnect       = uimenu(app.Arduino,'Text','Disconnect','MenuSelectedFcn',createCallbackFcn(app,@Disconnect_Callback,true));
            app.ConnectMotorMenu = uimenu(app.Arduino,'Text','Connect Motor','MenuSelectedFcn',createCallbackFcn(app,@ConnectMotor,true));

            % ── Left panel — Robot ────────────────────────
            lp = uipanel(app.figure1,'Position',[5 5 620 510],'Title','Robot Control','FontSize',12);

            app.axes1 = uiaxes(lp,'Position',[60 160 480 310],'FontSize',11,'NextPlot','replace','Tag','axes1');

            % Joint sliders
            app.slider1 = uislider(lp,'Limits',[0 1],'Orientation','vertical','Position',[15 200 3 200],'MajorTicks',[],'Tag','slider1');
            app.slider1.ValueChangedFcn  = createCallbackFcn(app,@slider1_Callback,true);
            app.slider1.ValueChangingFcn = createCallbackFcn(app,@slider1ValueChanging,true);

            app.slider2 = uislider(lp,'Limits',[0 6.28],'Orientation','vertical','Position',[595 200 3 200],'MajorTicks',[],'Tag','slider2');
            app.slider2.ValueChangedFcn  = createCallbackFcn(app,@slider2_Callback,true);
            app.slider2.ValueChangingFcn = createCallbackFcn(app,@slider2ValueChanging,true);

            app.slider3 = uislider(lp,'Limits',[0 6.28],'Orientation','vertical','Position',[595 30 3 120],'MajorTicks',[],'Tag','slider3');
            app.slider3.ValueChangedFcn  = createCallbackFcn(app,@slider3ValueChanged,true);
            app.slider3.ValueChangingFcn = createCallbackFcn(app,@slider3ValueChanging,true);

            app.text2     = uilabel(lp,'Text','Joint 1','Position',[2  370 50 20],'HorizontalAlignment','center');
            app.text3     = uilabel(lp,'Text','Joint 2','Position',[575 370 50 20],'HorizontalAlignment','center');
            app.text_pen  = uilabel(lp,'Text','Pen','Position',[575 155 50 20],'HorizontalAlignment','center');

            % Buttons row 1
            app.Create       = uibutton(lp,'push','Text','Create Robot','Position',[60  110 120 30],'ButtonPushedFcn',createCallbackFcn(app,@Create_Callback,true));
            app.HardwareMove = uibutton(lp,'push','Text','Hw Move',     'Position',[200 110 100 30],'ButtonPushedFcn',createCallbackFcn(app,@HardwareMove_Callback,true));
            app.DRAWButton   = uibutton(lp,'push','Text','Draw Grid',   'Position',[320 110 100 30],'ButtonPushedFcn',createCallbackFcn(app,@DRAWButtonPushed,true));

            % Buttons row 2
            app.PenUpButton   = uibutton(lp,'push','Text','Pen Up',  'Position',[60  70 100 30],'ButtonPushedFcn',createCallbackFcn(app,@PenUpButton_Callback,true));
            app.PenDownButton = uibutton(lp,'push','Text','Pen Down','Position',[180 70 100 30],'ButtonPushedFcn',createCallbackFcn(app,@PenDownButton_Callback,true));

            % ── Right panel — TicTacToe ───────────────────
            rp = uipanel(app.figure1,'Position',[630 5 465 510],'Title','TicTacToe','FontSize',12);

            app.NewGameButton = uibutton(rp,'push','Text','New Game','Position',[155 455 130 35],...
                'FontSize',14,'ButtonPushedFcn',createCallbackFcn(app,@NewGame_Callback,true));

            app.StatusLabel = uilabel(rp,'Text','Press New Game to start','Position',[10 415 430 30],...
                'HorizontalAlignment','center','FontSize',12);

            % 3x3 board buttons
            bSize=100; bGap=10; bX0=55; bY0=270;
            btnCallbacks = {@btn11_Callback,@btn12_Callback,@btn13_Callback;
                            @btn21_Callback,@btn22_Callback,@btn23_Callback;
                            @btn31_Callback,@btn32_Callback,@btn33_Callback};
            btnProps = {'btn11','btn12','btn13';'btn21','btn22','btn23';'btn31','btn32','btn33'};
            app.squareBtns = cell(3,3);
            for r=1:3
                for c=1:3
                    bx = bX0 + (c-1)*(bSize+bGap);
                    by = bY0 - (r-1)*(bSize+bGap);
                    b  = uibutton(rp,'push','Text',' ','Position',[bx by bSize bSize],...
                         'FontSize',32,'FontWeight','bold',...
                         'BackgroundColor',[0.94 0.94 0.94],...
                         'ButtonPushedFcn',createCallbackFcn(app,btnCallbacks{r,c},true));
                    app.(btnProps{r,c}) = b;
                    app.squareBtns{r,c} = b;
                end
            end

            % ASCII board display
            app.BoardLabel = uilabel(rp,'Text','','Position',[10 10 430 240],...
                'FontName','Courier New','FontSize',14,...
                'HorizontalAlignment','left','VerticalAlignment','top',...
                'WordWrap','on');

            app.figure1.Visible = 'on';
        end

    end % createComponents

    % =============================================================
    %  APP LIFECYCLE
    % =============================================================
    methods (Access = public)
        function app = TicTacToe_App
            running = getRunningApp(app);
            if isempty(running)
                createComponents(app);
                registerApp(app, app.figure1);
            else
                figure(running.figure1);
                app = running;
            end
            if nargout == 0, clear app; end
        end
        function delete(app)
            delete(app.figure1);
        end
    end

end
'''

# ── metadata/appMetadata.xml ───────────────────────────────────────────────
METADATA = '''<?xml version="1.0" encoding="utf-8"?>
<AppMetadata>
  <AppName>TicTacToe_App</AppName>
  <Description>TicTacToe 3-Link Drawing Robot — Arduino + ROS + Minimax AI</Description>
  <Author>Yusuf Guenena</Author>
  <Version>1.0</Version>
</AppMetadata>
'''

# ── matlab/document.xml (minimal — App Designer regenerates this) ──────────
DOCUMENT = '''<?xml version="1.0" encoding="utf-8"?>
<MATLABDocument>
  <View />
</MATLABDocument>
'''

out = 'TicTacToe_App.mlapp'
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    z.writestr('matlab/code.m',          CODE)
    z.writestr('metadata/appMetadata.xml', METADATA)
    z.writestr('matlab/document.xml',    DOCUMENT)

print(f'Created: {out}  ({os.path.getsize(out):,} bytes)')
print('Copy this file into your repo folder and commit it.')
print('Open in MATLAB: double-click TicTacToe_App.mlapp in the file browser.')
