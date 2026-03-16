% main.m — Terminal game loop (no GUI required)
% Author: Yusuf Guenena
clc; clear; close all;

fprintf('TicTacToe 3-Link Robot — Terminal Mode\n\n');

robot = create_robot();
cal   = get_servo_calibration();
cfg   = drawing_config();

com = input('COM port (e.g. COM5): ','s');
try
    device = arduino(com,'uno','libraries','Servo');
catch
    error('Could not connect on %s', com);
end

servo1 = servo(device,'D3','MinPulseDuration',0.5e-3,'MaxPulseDuration',2.5e-3);
servo2 = servo(device,'D5','MinPulseDuration',0.5e-3,'MaxPulseDuration',2.5e-3);
servo3 = servo(device,'D6','MinPulseDuration',0.5e-3,'MaxPulseDuration',2.5e-3);
pen_up(servo3, cfg);

input('Press Enter to draw grid...');
draw_grid(robot,servo1,servo2,servo3,cal,cfg);

board   = new_board();
player  = 1;
fprintf('You=X  Robot=O\n');
fprintf('Squares 1-9 (left→right, top→bottom)\n\n');

while true
    print_board(board);
    result = check_winner(board);
    if result==1, fprintf('You win!\n'); break; end
    if result==2, fprintf('Robot wins!\n'); break; end
    if result==3, fprintf('Draw!\n'); break; end

    if player==1
        while true
            sq = input('Your move (1-9): ');
            r=ceil(sq/3); c=mod(sq-1,3)+1;
            if is_valid_move(board,r,c), break; end
            fprintf('Invalid. Try again.\n');
        end
        board = apply_move(board,r,c,1);
        draw_X(robot,servo1,servo2,servo3,cal,cfg,r,c);
        player=2;
    else
        fprintf('Robot thinking...\n');
        [r,c] = minimax_best_move(board);
        board = apply_move(board,r,c,2);
        fprintf('Robot plays square %d\n',(r-1)*3+c);
        draw_O(robot,servo1,servo2,servo3,cal,cfg,r,c);
        player=1;
    end
end

print_board(board);
pen_up(servo3,cfg);
