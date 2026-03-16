% robot_kinematics.m
% =========================================================
% 2-DOF Planar Robot Kinematics
% =========================================================
% Closed-form IK, FK, servo calibration, joint limits.
% Author: Yusuf Guenena
% =========================================================

function robot = create_robot()
    L(1) = Link('revolute','d',25,'a',110,'alpha',0,'offset',-0.43);
    L(2) = Link('revolute','d',5, 'a',104,'alpha',0,'offset', 0.43-pi/2);
    L(1).qlim = deg2rad([-5  205]);
    L(2).qlim = deg2rad([-80 130]);
    robot      = SerialLink(L, 'name', 'TicTacToeArm');
    robot.base = transl(-29, 121, 77);
end

function [q1, q2, ok] = planar_ik(robot, x_world, y_world, current_q)
    a1=110; a2=104; x0=-29; y0=121;
    x = x_world-x0;  y = y_world-y0;
    r2 = x^2+y^2;
    c2 = (r2-a1^2-a2^2)/(2*a1*a2);
    if abs(c2)>1, q1=NaN; q2=NaN; ok=false; return; end
    s2a= sqrt(1-c2^2); s2b=-s2a;
    t2a=atan2(s2a,c2); t1a=atan2(y,x)-atan2(a2*s2a,a1+a2*c2);
    t2b=atan2(s2b,c2); t1b=atan2(y,x)-atan2(a2*s2b,a1+a2*c2);
    q1a=t1a-robot.links(1).offset; q2a=t2a-robot.links(2).offset;
    q1b=t1b-robot.links(1).offset; q2b=t2b-robot.links(2).offset;
    if norm([q1a q2a]-current_q) <= norm([q1b q2b]-current_q)
        q1=q1a; q2=q2a;
    else
        q1=q1b; q2=q2b;
    end
    ok=true;
end

function cal = get_servo_calibration()
    cal.joint1_q = deg2rad([-5  45  95  145 205]);
    cal.joint1_s =         [0.92 0.72 0.50 0.28 0.08];
    cal.joint2_q = deg2rad([-80 -30  20   75  130]);
    cal.joint2_s =         [0.75 0.62 0.48 0.33 0.20];
    cal.servo1_reversed = false;
    cal.servo2_reversed = false;
    cal.servo3_reversed = false;
end

function pos = joint1_to_servo(q1, cal)
    pos = max(0,min(1, interp1(cal.joint1_q, cal.joint1_s, q1,'linear','extrap')));
    if cal.servo1_reversed, pos = 1-pos; end
end

function pos = joint2_to_servo(q2, cal)
    pos = max(0,min(1, interp1(cal.joint2_q, cal.joint2_s, q2,'linear','extrap')));
    if cal.servo2_reversed, pos = 1-pos; end
end

function [q1,q2] = clamp_joints(robot, q1, q2)
    q1 = max(min(q1,robot.links(1).qlim(2)),robot.links(1).qlim(1));
    q2 = max(min(q2,robot.links(2).qlim(2)),robot.links(2).qlim(1));
end

function [x,y] = forward_kinematics(q1, q2)
    a1=110; a2=104; x0=-29; y0=121;
    t1=q1-0.43; t2=q2+(0.43-pi/2);
    x = x0 + a1*cos(t1) + a2*cos(t1+t2);
    y = y0 + a1*sin(t1) + a2*sin(t1+t2);
end
