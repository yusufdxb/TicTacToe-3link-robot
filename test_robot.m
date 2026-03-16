% test_robot.m — Hardware verification script
% Author: Yusuf Guenena
clc; clear; close all;

robot = create_robot();
cal   = get_servo_calibration();
cfg   = drawing_config();

fprintf('[1] IK test for all 9 squares...\n');
for r=1:3, for c=1:3
    idx=(r-1)*3+c;
    cx=cfg.square_centers(idx,1); cy=cfg.square_centers(idx,2);
    [q1,q2,ok] = planar_ik(robot,cx,cy,[0 0]);
    if ok
        [xfk,yfk] = forward_kinematics(q1,q2);
        fprintf('  (%d,%d) OK | FK err=%.2fmm\n',r,c,sqrt((xfk-cx)^2+(yfk-cy)^2));
    else
        fprintf('  (%d,%d) UNREACHABLE\n',r,c);
    end
end; end

com = input('\nCOM port (Enter to skip hardware): ','s');
if isempty(com), fprintf('Skipping hardware tests.\n'); return; end

device = arduino(com,'uno','libraries','Servo');
servo1 = servo(device,'D3','MinPulseDuration',0.5e-3,'MaxPulseDuration',2.5e-3);
servo2 = servo(device,'D5','MinPulseDuration',0.5e-3,'MaxPulseDuration',2.5e-3);
servo3 = servo(device,'D6','MinPulseDuration',0.5e-3,'MaxPulseDuration',2.5e-3);

input('[2] Press Enter to test pen down/up');
pen_down(servo3,cfg); pause(1); pen_up(servo3,cfg);

input('[3] Press Enter to draw X in square (1,1)');
draw_X(robot,servo1,servo2,servo3,cal,cfg,1,1);

input('[4] Press Enter to draw O in square (2,2)');
draw_O(robot,servo1,servo2,servo3,cal,cfg,2,2);

input('[5] Press Enter to draw full grid (fresh paper)');
draw_grid(robot,servo1,servo2,servo3,cal,cfg);

pen_up(servo3,cfg);
fprintf('All tests complete.\n');
