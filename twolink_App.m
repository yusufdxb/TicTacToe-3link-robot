classdef twolink_App < matlab.apps.AppBase

% TicTacToe 3-Link Drawing Robot — MATLAB App
% =====================================================
% 2-DOF robot arm controlled via Arduino servos.
% Plays TicTacToe by physically drawing X and O on paper.
%
% Hardware:
%   Joint 1 servo → Arduino D3
%   Joint 2 servo → Arduino D5
%   Pen servo     → Arduino D6
%
% API keys: store in config.m (see config.example.m)
%           config.m is excluded from Git via .gitignore
%
% Author: Yusuf Guenena
% =====================================================

    properties (Access = public)
        figure1           matlab.ui.Figure
        Arduino           matlab.ui.container.Menu
        Connect           matlab.ui.container.Menu
        Disconnect        matlab.ui.container.Menu
        ConnectMotorMenu  matlab.ui.container.Menu
        DRAWButton        matlab.ui.control.Button
        NewGameButton     matlab.ui.control.Button
        slider3           matlab.ui.control.Slider
        HardwareMove      matlab.ui.control.Button
        text3             matlab.ui.control.Label
        text2             matlab.ui.control.Label
        textStatus        matlab.ui.control.Label
        textBoard         matlab.ui.control.Label
        Create            matlab.ui.control.Button
        slider2           matlab.ui.control.Slider
        slider1           matlab.ui.control.Slider
        axes1             matlab.ui.control.UIAxes
        % TicTacToe board buttons (3x3)
        BoardBtn          matlab.ui.control.Button
    end

    properties (Access = private)
        % ── Hardware ──────────────────────────────────────
        device          = []
        robot           = []
        servo_motor1    = []
        servo_motor2    = []
        servo_motor3    = []
        jointangle      = [0 0]
        data_available  = false
        base_joint      = 0

        % ── Servo smoothing ───────────────────────────────
        lastServoPos        = NaN
        lastServoWriteTime  = 0
        lastServoPos2       = NaN
        lastServoWriteTime2 = 0
        lastServoPos3       = NaN
        lastServoWriteTime3 = 0
        servoDeadband   = 0.01
        servoMinPeriod  = 0.03

        % ── Robot config ──────────────────────────────────
        joint1PlotOffset = pi/2
        joint2PlotOffset = 0
        servo1Reversed   = false
        servo2Reversed   = false
        servo3Reversed   = false
        penServoStartPos = 0.8
        horizontalArcComp = -0.0025
        verticalArcComp   = 0

        % ── Calibration tables (filled in Create_Callback) ─
        joint1Cal_q = []
        joint1Cal_s = []
        joint2Cal_q = []
        joint2Cal_s = []

        % ── TicTacToe game state ──────────────────────────
        board           = zeros(3,3)   % 0=empty 1=human 2=robot
        gameActive      = false
        boardButtons    = []           % 3x3 cell of button handles

        % ── API config (loaded from config.m) ─────────────
        % DO NOT hardcode keys here — use config.m instead
        apiConfig       = []
    end

    % =============================================================
    %  PRIVATE HELPER METHODS
    % =============================================================
    methods (Access = private)

        % ── Load API config safely ────────────────────────
        function loadConfig(app)
            if exist('config.m', 'file')
                app.apiConfig = config();
            else
                app.apiConfig = struct('openai_api_key', '');
                warning(['config.m not found. ' ...
                    'Copy config.example.m to config.m and add your key.']);
            end
        end

        % ── Robot plot update ─────────────────────────────
        function updateRobotPlot(app)
            if ~isempty(app.robot)
                app.robot.plot(app.jointangle, ...
                    'workspace', [-300 300 -300 300 -50 300]);
                drawnow limitrate;
            end
        end

        % ── Servo calibration mappings ────────────────────
        function pos01 = joint1ToServoPosition(app, q1)
            if isempty(app.joint1Cal_q)
                qlim  = app.slider1.Limits;
                pos01 = (q1 - qlim(1)) / (qlim(2) - qlim(1));
            else
                pos01 = interp1(app.joint1Cal_q, app.joint1Cal_s, ...
                                q1, 'linear', 'extrap');
            end
            pos01 = max(0, min(1, pos01));
        end

        function pos01 = joint2ToServoPosition(app, q2)
            if isempty(app.joint2Cal_q)
                qlim  = app.slider2.Limits;
                pos01 = (q2 - qlim(1)) / (qlim(2) - qlim(1));
            else
                pos01 = interp1(app.joint2Cal_q, app.joint2Cal_s, ...
                                q2, 'linear', 'extrap');
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
            if ~isnan(app.lastServoPos)
                if abs(targetPos - app.lastServoPos) < app.servoDeadband, return; end
            end
            if app.lastServoWriteTime ~= 0
                if toc(app.lastServoWriteTime) < app.servoMinPeriod, return; end
            end
            newPos = isnan(app.lastServoPos) * targetPos + ...
                     ~isnan(app.lastServoPos) * (app.lastServoPos + 0.35*(targetPos - app.lastServoPos));
            newPos = max(0, min(1, newPos));
            writePosition(app.servo_motor1, newPos);
            app.lastServoPos       = newPos;
            app.lastServoWriteTime = tic;
        end

        function writeServoFromJoint2(app, q2)
            if isempty(app.servo_motor2), return; end
            targetPos = app.joint2ToServoPosition(q2);
            if ~isnan(app.lastServoPos2)
                if abs(targetPos - app.lastServoPos2) < app.servoDeadband, return; end
            end
            if app.lastServoWriteTime2 ~= 0
                if toc(app.lastServoWriteTime2) < app.servoMinPeriod, return; end
            end
            newPos = isnan(app.lastServoPos2) * targetPos + ...
                     ~isnan(app.lastServoPos2) * (app.lastServoPos2 + 0.35*(targetPos - app.lastServoPos2));
            newPos = max(0, min(1, newPos));
            writePosition(app.servo_motor2, newPos);
            app.lastServoPos2       = newPos;
            app.lastServoWriteTime2 = tic;
        end

        function writeServoFromSlider3(app, s3)
            if isempty(app.servo_motor3), return; end
            targetPos = app.slider3ToServoPosition(s3);
            if app.servo3Reversed, targetPos = 1 - targetPos; end
            if ~isnan(app.lastServoPos3)
                if abs(targetPos - app.lastServoPos3) < app.servoDeadband, return; end
            end
            if app.lastServoWriteTime3 ~= 0
                if toc(app.lastServoWriteTime3) < app.servoMinPeriod, return; end
            end
            newPos = isnan(app.lastServoPos3) * targetPos + ...
                     ~isnan(app.lastServoPos3) * (app.lastServoPos3 + 0.35*(targetPos - app.lastServoPos3));
            newPos = max(0, min(1, newPos));
            writePosition(app.servo_motor3, newPos);
            app.lastServoPos3       = newPos;
            app.lastServoWriteTime3 = tic;
        end

        % ── Direct servo writes (used during drawing) ─────
        function writeServoFromJoint1Direct(app, q1)
            if isempty(app.servo_motor1), return; end
            pos01 = max(0, min(1, app.joint1ToServoPosition(q1)));
            writePosition(app.servo_motor1, pos01);
            app.lastServoPos       = pos01;
            app.lastServoWriteTime = tic;
        end

        function writeServoFromJoint2Direct(app, q2)
            if isempty(app.servo_motor2), return; end
            pos01 = max(0, min(1, app.joint2ToServoPosition(q2)));
            writePosition(app.servo_motor2, pos01);
            app.lastServoPos2       = pos01;
            app.lastServoWriteTime2 = tic;
        end

        % ── Arm motion ────────────────────────────────────
        function moveArmToJointAngles(app, q1, q2)
            q1 = max(min(q1, app.slider1.Limits(2)), app.slider1.Limits(1));
            q2 = max(min(q2, app.slider2.Limits(2)), app.slider2.Limits(1));
            app.jointangle = [q1 q2];
            app.slider1.Value = q1;  app.slider2.Value = q2;
            app.writeServoFromJoint1(q1);
            app.writeServoFromJoint2(q2);
            app.updateRobotPlot();
            drawnow;
        end

        function moveArmToJointAnglesDirect(app, q1, q2)
            q1 = max(min(q1, app.slider1.Limits(2)), app.slider1.Limits(1));
            q2 = max(min(q2, app.slider2.Limits(2)), app.slider2.Limits(1));
            app.jointangle = [q1 q2];
            app.slider1.Value = q1;  app.slider2.Value = q2;
            app.writeServoFromJoint1Direct(q1);
            app.writeServoFromJoint2Direct(q2);
            app.updateRobotPlot();
            drawnow;
        end

        % ── Planar IK ─────────────────────────────────────
        function [q1, q2, ok] = planarIK(app, xWorld, yWorld)
            a1 = 110;  a2 = 104;
            x0 = -29;  y0 = 121;
            x  = xWorld - x0;
            y  = yWorld - y0;
            r2 = x^2 + y^2;
            c2 = (r2 - a1^2 - a2^2) / (2*a1*a2);
            if abs(c2) > 1
                q1 = NaN; q2 = NaN; ok = false; return;
            end
            s2a =  sqrt(1 - c2^2);
            s2b = -s2a;
            theta2a = atan2(s2a, c2);
            theta1a = atan2(y,x) - atan2(a2*s2a, a1 + a2*c2);
            theta2b = atan2(s2b, c2);
            theta1b = atan2(y,x) - atan2(a2*s2b, a1 + a2*c2);
            q1a = theta1a - app.robot.links(1).offset;
            q2a = theta2a - app.robot.links(2).offset;
            q1b = theta1b - app.robot.links(1).offset;
            q2b = theta2b - app.robot.links(2).offset;
            if norm([q1a q2a] - app.jointangle) <= norm([q1b q2b] - app.jointangle)
                q1 = q1a; q2 = q2a;
            else
                q1 = q1b; q2 = q2b;
            end
            ok = true;
        end

        % ── Pen control ───────────────────────────────────
        function penDown(app)
            if ~isempty(app.servo_motor3)
                writePosition(app.servo_motor3, 0.20);
                pause(0.3);
            end
        end

        function penUp(app)
            if ~isempty(app.servo_motor3)
                writePosition(app.servo_motor3, 0.80);
                pause(0.3);
            end
        end

        % ── Line drawing ──────────────────────────────────
        function drawVerticalLine(app, xLine, yStart, yEnd, nPts)
            yVals = linspace(yStart, yEnd, nPts);
            [q1s, q2s, ok] = app.planarIK(xLine, yStart);
            if ~ok, warning('Vertical line start unreachable'); return; end
            app.moveArmToJointAnglesDirect(q1s, q2s);
            pause(0.5);
            app.penDown();
            for k = 1:length(yVals)
                [q1, q2, ok] = app.planarIK(xLine, yVals(k));
                if ~ok, continue; end
                app.moveArmToJointAnglesDirect(q1, q2);
                pause(0.08);
            end
            app.penUp();
        end

        function drawHorizontalLine(app, yLine, xStart, xEnd, nPts)
            xVals = linspace(xStart, xEnd, nPts);
            xMid  = (xStart + xEnd) / 2;
            yCmd  = yLine + app.horizontalArcComp * (xVals - xMid).^2;
            [q1s, q2s, ok] = app.planarIK(xVals(1), yCmd(1));
            if ~ok, warning('Horizontal line start unreachable'); return; end
            app.moveArmToJointAnglesDirect(q1s, q2s);
            pause(0.5);
            app.penDown();
            for k = 1:length(xVals)
                [q1, q2, ok] = app.planarIK(xVals(k), yCmd(k));
                if ~ok, continue; end
                app.moveArmToJointAnglesDirect(q1, q2);
                pause(0.08);
            end
            app.penUp();
        end

        % ── Symbol drawing ────────────────────────────────
        function drawX(app, row, col)
            centers = app.squareCenters();
            idx = (row-1)*3 + col;
            cx = centers(idx,1);  cy = centers(idx,2);  s = 18;
            app.drawDiagonal(cx-s, cy+s, cx+s, cy-s);
            pause(0.3);
            app.drawDiagonal(cx+s, cy+s, cx-s, cy-s);
        end

        function drawO(app, row, col)
            centers = app.squareCenters();
            idx = (row-1)*3 + col;
            cx = centers(idx,1);  cy = centers(idx,2);  r = 18;
            nPts   = 40;
            tVals  = linspace(0, 2*pi, nPts);
            xVals  = cx + r*cos(tVals);
            yVals  = cy + r*sin(tVals);
            curQ   = app.jointangle;
            [q1, q2, ok] = app.planarIK(xVals(1), yVals(1));
            if ~ok, return; end
            app.moveArmToJointAnglesDirect(q1, q2);
            pause(0.5);
            app.penDown();
            for k = 1:nPts
                [q1, q2, ok] = app.planarIK(xVals(k), yVals(k));
                if ~ok, continue; end
                app.moveArmToJointAnglesDirect(q1, q2);
                pause(0.08);
            end
            app.penUp();
        end

        function drawDiagonal(app, x1, y1, x2, y2)
            nPts  = 40;
            xVals = linspace(x1, x2, nPts);
            yVals = linspace(y1, y2, nPts);
            [q1, q2, ok] = app.planarIK(xVals(1), yVals(1));
            if ~ok, return; end
            app.moveArmToJointAnglesDirect(q1, q2);
            pause(0.5);
            app.penDown();
            for k = 1:nPts
                [q1, q2, ok] = app.planarIK(xVals(k), yVals(k));
                if ~ok, continue; end
                app.moveArmToJointAnglesDirect(q1, q2);
                pause(0.08);
            end
            app.penUp();
        end

        function centers = squareCenters(~)
            centers = [
                60,170; 90,170; 120,170;
                60,140; 90,140; 120,140;
                60,110; 90,110; 120,110;
            ];
        end

        % ── TicTacToe game logic ──────────────────────────
        function result = checkWinner(~, board)
            result = 0;
            for p = [1 2]
                for r = 1:3
                    if all(board(r,:) == p), result = p; return; end
                end
                for c = 1:3
                    if all(board(:,c) == p), result = p; return; end
                end
                if board(1,1)==p && board(2,2)==p && board(3,3)==p, result=p; return; end
                if board(1,3)==p && board(2,2)==p && board(3,1)==p, result=p; return; end
            end
            if all(board(:) ~= 0), result = 3; end
        end

        function [row, col] = minimaxBestMove(app)
            bestScore = -Inf;  row = -1;  col = -1;
            for r = 1:3
                for c = 1:3
                    if app.board(r,c) == 0
                        app.board(r,c) = 2;
                        score = app.minimaxScore(app.board, false);
                        app.board(r,c) = 0;
                        if score > bestScore
                            bestScore = score;
                            row = r;  col = c;
                        end
                    end
                end
            end
        end

        function score = minimaxScore(app, board, isMax)
            r = app.checkWinner(board);
            if r == 2,  score =  10; return; end
            if r == 1,  score = -10; return; end
            if r == 3,  score =   0; return; end
            if isMax
                best = -Inf;
                for i = 1:3
                    for j = 1:3
                        if board(i,j) == 0
                            board(i,j) = 2;
                            best = max(best, app.minimaxScore(board, false));
                            board(i,j) = 0;
                        end
                    end
                end
                score = best;
            else
                best = Inf;
                for i = 1:3
                    for j = 1:3
                        if board(i,j) == 0
                            board(i,j) = 1;
                            best = min(best, app.minimaxScore(board, true));
                            board(i,j) = 0;
                        end
                    end
                end
                score = best;
            end
        end

        function updateBoardDisplay(app)
            symbols = {' ', 'X', 'O'};
            str = '';
            for r = 1:3
                for c = 1:3
                    str = [str ' ' symbols{app.board(r,c)+1} ' '];
                    if c < 3, str = [str '|']; end
                end
                str = [str newline];
                if r < 3, str = [str '---|---|---' newline]; end
            end
            app.textBoard.Text = str;

            % Update button colors
            colors_empty  = [0.94 0.94 0.94];
            colors_human  = [0.53 0.81 0.98];
            colors_robot  = [1.00 0.71 0.40];
            for r = 1:3
                for c = 1:3
                    idx = (r-1)*3 + c;
                    btn = app.boardButtons{idx};
                    switch app.board(r,c)
                        case 0, btn.BackgroundColor = colors_empty;
                        case 1, btn.BackgroundColor = colors_human;  btn.Text = 'X';
                        case 2, btn.BackgroundColor = colors_robot;  btn.Text = 'O';
                    end
                end
            end
        end

    end % private methods

    % =============================================================
    %  CALLBACKS
    % =============================================================
    methods (Access = private)

        function Connect_Callback(app, ~)
            com = char(inputdlg('What COM Port?', 'COM Select', 1, {'COM5'}));
            if isempty(com), return; end
            try
                app.device = arduino(com, 'uno', 'libraries', 'Servo');
            catch
                msgbox(['Port failed: ' com], 'Error'); return;
            end
            app.data_available     = true;
            app.lastServoWriteTime = tic;
            msgbox('Arduino connected successfully');
        end

        function Disconnect_Callback(app, ~)
            try
                app.device.delete;
            catch
                msgbox('Error closing port.'); return;
            end
            app.device = [];
            app.servo_motor1 = [];  app.servo_motor2 = [];  app.servo_motor3 = [];
            app.data_available = false;
            msgbox('Arduino disconnected');
        end

        function Create_Callback(app, ~)
            L(1) = Link('revolute','d',25,'a',110,'alpha',0,'offset',-0.43);
            L(2) = Link('revolute','d',5, 'a',104,'alpha',0,'offset', 0.43-pi/2);
            L(1).qlim = deg2rad([-5  205]);
            L(2).qlim = deg2rad([-80 130]);
            app.robot      = SerialLink(L, 'name', 'TicTacToeArm');
            app.robot.base = transl(-29, 121, 77);
            app.slider1.Limits = L(1).qlim;
            app.slider2.Limits = L(2).qlim;
            app.joint1Cal_q = deg2rad([-5  45  95  145 205]);
            app.joint1Cal_s = [0.92 0.72 0.50 0.28 0.08];
            app.joint2Cal_q = deg2rad([-80 -30  20   75 130]);
            app.joint2Cal_s = [0.75 0.62 0.48 0.33 0.20];
            q1s = max(min(app.joint1PlotOffset, L(1).qlim(2)), L(1).qlim(1));
            q2s = max(min(app.joint2PlotOffset, L(2).qlim(2)), L(2).qlim(1));
            app.jointangle = [q1s q2s];
            app.slider1.Value = q1s;  app.slider2.Value = q2s;
            app.robot.plot(app.jointangle, 'workspace', [-300 300 -300 300 -50 300]);
            app.loadConfig();
        end

        function ConnectMotor(app, ~)
            if ~app.data_available
                msgbox('Connect Arduino first'); return;
            end
            try
                app.servo_motor1 = servo(app.device,'D3','MinPulseDuration',0.5e-3,'MaxPulseDuration',2.5e-3);
                app.servo_motor2 = servo(app.device,'D5','MinPulseDuration',0.5e-3,'MaxPulseDuration',2.5e-3);
                app.servo_motor3 = servo(app.device,'D6','MinPulseDuration',0.5e-3,'MaxPulseDuration',2.5e-3);
                app.lastServoPos  = app.joint1ToServoPosition(app.slider1.Value);
                app.lastServoPos2 = app.joint2ToServoPosition(app.slider2.Value);
                app.lastServoWriteTime  = tic;
                app.lastServoWriteTime2 = tic;
                startPos3 = app.penServoStartPos;
                if app.servo3Reversed, startPos3 = 1 - startPos3; end
                writePosition(app.servo_motor3, startPos3);
                app.lastServoPos3       = startPos3;
                app.lastServoWriteTime3 = tic;
                msgbox('Motors connected');
            catch ME
                msgbox(['Servo error: ' ME.message], 'Error');
            end
        end

        function HardwareMove_Callback(app, ~)
            if ~app.data_available, msgbox('Connect hardware first'); return; end
            raw = inputdlg('How many steps?', 'Steps');
            if isempty(raw), return; end
            steps = str2double(raw{1});
            if isnan(steps) || steps < 1, msgbox('Enter a positive integer','Error'); return; end
            steps = round(steps);
            btn = questdlg('Which Joint?','Joint','1','2','Cancel','1');
            if strcmp(btn,'Cancel') || isempty(btn), return; end
            J = str2double(btn);
            for i = 1:steps
                value = app.device.readVoltage('A0');
                if isnumeric(value)
                    pause(0.1);
                    if J==1, app.jointangle(1)=value; else, app.jointangle(2)=value; end
                    app.robot.plot(app.jointangle);
                end
            end
            msgbox('Done');
        end

        function slider1_Callback(app, ~)
            app.jointangle = [app.slider1.Value app.slider2.Value];
            app.updateRobotPlot();
        end

        function slider2_Callback(app, ~)
            app.jointangle = [app.slider1.Value app.slider2.Value];
            app.updateRobotPlot();
        end

        function slider1ValueChanging(app, event)
            app.jointangle(1) = event.Value;
            app.writeServoFromJoint1(event.Value);
            app.updateRobotPlot();
        end

        function slider2ValueChanging(app, event)
            app.jointangle(2) = event.Value;
            app.writeServoFromJoint2(event.Value);
            app.updateRobotPlot();
        end

        function slider3ValueChanged(app, event)
            app.writeServoFromSlider3(event.Value);
        end

        function slider3ValueChanging(app, event)
            app.writeServoFromSlider3(event.Value);
        end

        function MoveWithKey(app, event)
            if strcmp(event.Key, 'leftarrow'),  app.base_joint = app.base_joint - 0.1; end
            if strcmp(event.Key, 'rightarrow'), app.base_joint = app.base_joint + 0.1; end
            if ~isempty(app.robot)
                app.robot.plot([app.base_joint, 0], 'workspace', [-300 300 -300 300 -50 300]);
            end
        end

        function DRAWButtonPushed(app, ~)
            if isempty(app.robot),       msgbox('Create robot first'); return; end
            if isempty(app.servo_motor1), msgbox('Connect motors first'); return; end
            nPts = 40;
            app.drawVerticalLine(120, 10, 200, nPts);  pause(0.5);
            app.drawVerticalLine( 60, 10, 160, nPts);  pause(0.5);
            app.drawHorizontalLine( 90, 0, 170, nPts); pause(0.5);
            app.drawHorizontalLine(150, 0, 170, nPts);
        end

        % ── TicTacToe callbacks ───────────────────────────
        function NewGame_Callback(app, ~)
            app.board      = zeros(3,3);
            app.gameActive = true;
            app.textStatus.Text = 'Your turn — click a square';
            for idx = 1:9
                app.boardButtons{idx}.Text            = '';
                app.boardButtons{idx}.BackgroundColor = [0.94 0.94 0.94];
            end
            app.updateBoardDisplay();
        end

        function BoardButton_Callback(app, ~, row, col)
            if ~app.gameActive, return; end
            if app.board(row,col) ~= 0, return; end

            % Human move
            app.board(row,col) = 1;
            app.textStatus.Text = 'Drawing X...';
            app.updateBoardDisplay();
            if ~isempty(app.servo_motor1)
                app.drawX(row, col);
            end

            result = app.checkWinner(app.board);
            if result ~= 0
                app.endGame(result); return;
            end

            % Robot move
            app.textStatus.Text = 'Robot thinking...';
            drawnow;
            [rr, cc] = app.minimaxBestMove();
            app.board(rr,cc) = 2;
            app.textStatus.Text = 'Drawing O...';
            app.updateBoardDisplay();
            if ~isempty(app.servo_motor1)
                app.drawO(rr, cc);
            end

            result = app.checkWinner(app.board);
            if result ~= 0
                app.endGame(result); return;
            end

            app.textStatus.Text = 'Your turn — click a square';
        end

        function endGame(app, result)
            app.gameActive = false;
            switch result
                case 1, app.textStatus.Text = 'You win!';
                case 2, app.textStatus.Text = 'Robot wins!';
                case 3, app.textStatus.Text = 'Draw!';
            end
        end

    end % callbacks

    % =============================================================
    %  COMPONENT INITIALIZATION
    % =============================================================
    methods (Access = private)

        function createComponents(app)
            app.figure1 = uifigure('Visible','off');
            app.figure1.Position         = [100 100 1000 550];
            app.figure1.Name             = 'TicTacToe 3-Link Robot';
            app.figure1.KeyPressFcn      = createCallbackFcn(app, @MoveWithKey, true);
            app.figure1.KeyReleaseFcn    = createCallbackFcn(app, @MoveWithKey, true);

            % Arduino menu
            app.Arduino          = uimenu(app.figure1);
            app.Arduino.Text     = 'Arduino';
            app.Connect          = uimenu(app.Arduino);
            app.Connect.Text     = 'Connect';
            app.Connect.MenuSelectedFcn = createCallbackFcn(app, @Connect_Callback, true);
            app.Disconnect       = uimenu(app.Arduino);
            app.Disconnect.Text  = 'Disconnect';
            app.Disconnect.MenuSelectedFcn = createCallbackFcn(app, @Disconnect_Callback, true);
            app.ConnectMotorMenu = uimenu(app.Arduino);
            app.ConnectMotorMenu.Text = 'Connect Motor';
            app.ConnectMotorMenu.MenuSelectedFcn = createCallbackFcn(app, @ConnectMotor, true);

            % Left panel — Robot
            app.axes1          = uiaxes(app.figure1);
            app.axes1.Position = [20 120 480 400];
            app.axes1.NextPlot = 'replace';

            app.slider1 = uislider(app.figure1);
            app.slider1.Orientation      = 'vertical';
            app.slider1.Limits           = [0 1];
            app.slider1.MajorTicks       = [];
            app.slider1.Position         = [10 240 3 150];
            app.slider1.ValueChangedFcn  = createCallbackFcn(app, @slider1_Callback, true);
            app.slider1.ValueChangingFcn = createCallbackFcn(app, @slider1ValueChanging, true);

            app.slider2 = uislider(app.figure1);
            app.slider2.Orientation      = 'vertical';
            app.slider2.Limits           = [0 6.28];
            app.slider2.MajorTicks       = [];
            app.slider2.Position         = [510 240 3 150];
            app.slider2.ValueChangedFcn  = createCallbackFcn(app, @slider2_Callback, true);
            app.slider2.ValueChangingFcn = createCallbackFcn(app, @slider2ValueChanging, true);

            app.slider3 = uislider(app.figure1);
            app.slider3.Orientation      = 'vertical';
            app.slider3.Limits           = [0 6.28];
            app.slider3.MajorTicks       = [];
            app.slider3.Position         = [525 240 3 150];
            app.slider3.ValueChangedFcn  = createCallbackFcn(app, @slider3ValueChanged, true);
            app.slider3.ValueChangingFcn = createCallbackFcn(app, @slider3ValueChanging, true);

            app.text2          = uilabel(app.figure1);
            app.text2.Text     = 'Joint 1';
            app.text2.Position = [0 220 50 20];

            app.text3          = uilabel(app.figure1);
            app.text3.Text     = 'Joint 2';
            app.text3.Position = [505 220 50 20];

            app.Create = uibutton(app.figure1, 'push');
            app.Create.Text            = 'Create Robot';
            app.Create.Position        = [20 70 120 30];
            app.Create.ButtonPushedFcn = createCallbackFcn(app, @Create_Callback, true);

            app.HardwareMove = uibutton(app.figure1, 'push');
            app.HardwareMove.Text            = 'Hardware Move';
            app.HardwareMove.Position        = [160 70 120 30];
            app.HardwareMove.ButtonPushedFcn = createCallbackFcn(app, @HardwareMove_Callback, true);

            app.DRAWButton = uibutton(app.figure1, 'push');
            app.DRAWButton.Text            = 'Draw Grid';
            app.DRAWButton.Position        = [300 70 100 30];
            app.DRAWButton.ButtonPushedFcn = createCallbackFcn(app, @DRAWButtonPushed, true);

            % Right panel — TicTacToe
            app.NewGameButton = uibutton(app.figure1, 'push');
            app.NewGameButton.Text            = 'New Game';
            app.NewGameButton.Position        = [560 490 120 35];
            app.NewGameButton.ButtonPushedFcn = createCallbackFcn(app, @NewGame_Callback, true);

            app.textStatus          = uilabel(app.figure1);
            app.textStatus.Text     = 'Press New Game to start';
            app.textStatus.Position = [550 450 250 30];
            app.textStatus.FontSize = 13;

            % 3x3 board buttons
            app.boardButtons = cell(1,9);
            btnSize  = 90;
            btnGap   = 5;
            boardX   = 555;
            boardY   = 200;
            for r = 1:3
                for c = 1:3
                    idx = (r-1)*3 + c;
                    btn = uibutton(app.figure1, 'push');
                    btn.Position        = [boardX + (c-1)*(btnSize+btnGap), ...
                                           boardY + (3-r)*(btnSize+btnGap), ...
                                           btnSize, btnSize];
                    btn.Text            = '';
                    btn.FontSize        = 36;
                    btn.FontWeight      = 'bold';
                    btn.BackgroundColor = [0.94 0.94 0.94];
                    btn.ButtonPushedFcn = createCallbackFcn(app, @(src,evt) BoardButton_Callback(app,src,evt,r,c), true);
                    app.boardButtons{idx} = btn;
                end
            end

            app.textBoard          = uilabel(app.figure1);
            app.textBoard.Text     = '';
            app.textBoard.Position = [555 60 300 130];
            app.textBoard.FontName = 'Courier';
            app.textBoard.FontSize = 14;

            app.figure1.Visible = 'on';
        end

    end

    % =============================================================
    %  APP CREATION & DELETION
    % =============================================================
    methods (Access = public)

        function app = twolink_App
            runningApp = getRunningApp(app);
            if isempty(runningApp)
                createComponents(app);
                registerApp(app, app.figure1);
            else
                figure(runningApp.figure1);
                app = runningApp;
            end
            if nargout == 0, clear app; end
        end

        function delete(app)
            delete(app.figure1);
        end

    end

end
