% drawing_functions.m
% =========================================================
% Robot Drawing Functions
% =========================================================
% drawGrid, drawX, drawO, penUp, penDown, line drawing.
% Author: Yusuf Guenena
% =========================================================

function cfg = drawing_config()
    cfg.pen_down_pos  = 0.20;
    cfg.pen_up_pos    = 0.80;
    cfg.n_pts         = 40;
    cfg.pause_time    = 0.08;
    cfg.pen_settle    = 0.30;
    cfg.symbol_size   = 18;
    cfg.h_arc_comp    = -0.0025;
    cfg.square_centers = [
        60,170; 90,170; 120,170;
        60,140; 90,140; 120,140;
        60,110; 90,110; 120,110;
    ];
    cfg.grid_x_start = 45;
    cfg.grid_x_end   = 135;
    cfg.grid_y_start = 95;
    cfg.grid_y_end   = 185;
end

function pen_down(servo3, cfg)
    if isempty(servo3), return; end
    writePosition(servo3, cfg.pen_down_pos);
    pause(cfg.pen_settle);
end

function pen_up(servo3, cfg)
    if isempty(servo3), return; end
    writePosition(servo3, cfg.pen_up_pos);
    pause(cfg.pen_settle);
end

function draw_grid(robot, servo1, servo2, servo3, cal, cfg)
    x1 = cfg.grid_x_start + (cfg.grid_x_end-cfg.grid_x_start)/3;
    x2 = cfg.grid_x_start + (cfg.grid_x_end-cfg.grid_x_start)*2/3;
    y1 = cfg.grid_y_start + (cfg.grid_y_end-cfg.grid_y_start)/3;
    y2 = cfg.grid_y_start + (cfg.grid_y_end-cfg.grid_y_start)*2/3;
    draw_vertical_line(robot,servo1,servo2,servo3,cal,cfg, x1,cfg.grid_y_start,cfg.grid_y_end);
    pause(0.5);
    draw_vertical_line(robot,servo1,servo2,servo3,cal,cfg, x2,cfg.grid_y_start,cfg.grid_y_end);
    pause(0.5);
    draw_horizontal_line(robot,servo1,servo2,servo3,cal,cfg, y1,cfg.grid_x_start,cfg.grid_x_end);
    pause(0.5);
    draw_horizontal_line(robot,servo1,servo2,servo3,cal,cfg, y2,cfg.grid_x_start,cfg.grid_x_end);
end

function draw_X(robot, servo1, servo2, servo3, cal, cfg, row, col)
    idx = (row-1)*3+col;
    cx=cfg.square_centers(idx,1); cy=cfg.square_centers(idx,2); s=cfg.symbol_size;
    draw_diagonal(robot,servo1,servo2,servo3,cal,cfg, cx-s,cy+s,cx+s,cy-s);
    pause(0.3);
    draw_diagonal(robot,servo1,servo2,servo3,cal,cfg, cx+s,cy+s,cx-s,cy-s);
end

function draw_O(robot, servo1, servo2, servo3, cal, cfg, row, col)
    idx = (row-1)*3+col;
    cx=cfg.square_centers(idx,1); cy=cfg.square_centers(idx,2); r=cfg.symbol_size;
    t = linspace(0,2*pi,cfg.n_pts);
    xv = cx+r*cos(t); yv = cy+r*sin(t);
    curQ = [0 0];
    [q1,q2,ok] = planar_ik(robot,xv(1),yv(1),curQ);
    if ~ok, return; end
    move_arm(robot,servo1,servo2,cal,q1,q2); pause(0.5);
    pen_down(servo3,cfg);
    for k=1:cfg.n_pts
        [q1,q2,ok] = planar_ik(robot,xv(k),yv(k),curQ);
        if ~ok, continue; end
        move_arm(robot,servo1,servo2,cal,q1,q2);
        curQ=[q1 q2];
    end
    pen_up(servo3,cfg);
end

function draw_vertical_line(robot,servo1,servo2,servo3,cal,cfg,xLine,yStart,yEnd)
    yv = linspace(yStart,yEnd,cfg.n_pts); curQ=[0 0];
    [q1,q2,ok] = planar_ik(robot,xLine,yStart,curQ);
    if ~ok, return; end
    move_arm(robot,servo1,servo2,cal,q1,q2); pause(0.5);
    pen_down(servo3,cfg);
    for k=1:length(yv)
        [q1,q2,ok]=planar_ik(robot,xLine,yv(k),curQ);
        if ~ok, continue; end
        move_arm(robot,servo1,servo2,cal,q1,q2);
        curQ=[q1 q2]; pause(cfg.pause_time);
    end
    pen_up(servo3,cfg);
end

function draw_horizontal_line(robot,servo1,servo2,servo3,cal,cfg,yLine,xStart,xEnd)
    xv = linspace(xStart,xEnd,cfg.n_pts);
    xm = (xStart+xEnd)/2;
    yv = yLine + cfg.h_arc_comp*(xv-xm).^2;
    curQ=[0 0];
    [q1,q2,ok] = planar_ik(robot,xv(1),yv(1),curQ);
    if ~ok, return; end
    move_arm(robot,servo1,servo2,cal,q1,q2); pause(0.5);
    pen_down(servo3,cfg);
    for k=1:length(xv)
        [q1,q2,ok]=planar_ik(robot,xv(k),yv(k),curQ);
        if ~ok, continue; end
        move_arm(robot,servo1,servo2,cal,q1,q2);
        curQ=[q1 q2]; pause(cfg.pause_time);
    end
    pen_up(servo3,cfg);
end

function draw_diagonal(robot,servo1,servo2,servo3,cal,cfg,x1,y1,x2,y2)
    xv=linspace(x1,x2,cfg.n_pts); yv=linspace(y1,y2,cfg.n_pts); curQ=[0 0];
    [q1,q2,ok]=planar_ik(robot,xv(1),yv(1),curQ);
    if ~ok, return; end
    move_arm(robot,servo1,servo2,cal,q1,q2); pause(0.5);
    pen_down(servo3,cfg);
    for k=1:cfg.n_pts
        [q1,q2,ok]=planar_ik(robot,xv(k),yv(k),curQ);
        if ~ok, continue; end
        move_arm(robot,servo1,servo2,cal,q1,q2);
        curQ=[q1 q2]; pause(cfg.pause_time);
    end
    pen_up(servo3,cfg);
end

function move_arm(robot,servo1,servo2,cal,q1,q2)
    [q1,q2] = clamp_joints(robot,q1,q2);
    writePosition(servo1, joint1_to_servo(q1,cal));
    writePosition(servo2, joint2_to_servo(q2,cal));
    pause(0.05);
end
