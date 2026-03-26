% ros2/tictactoe_ros2_robot.m
% =========================================================
% ROBOT-SIDE ROS2 Interface — TicTacToe 3-Link Robot
% =========================================================
% Run this on the machine directly connected to the Arduino.
%
% What it does:
%   - Subscribes to /tictactoe/human_move  (std_msgs/String)
%   - Publishes  to /tictactoe/robot_move  (std_msgs/String)
%   - Publishes  to /tictactoe/game_state  (std_msgs/String)
%   - Publishes  to /tictactoe/status      (std_msgs/String)
%   - Subscribes to /tictactoe/command     (std_msgs/String)
%
% Move encoding (both directions):
%   A single digit 1-9, where squares are numbered:
%     1 | 2 | 3
%     4 | 5 | 6
%     7 | 8 | 9
%
% Command encoding (/tictactoe/command):
%   "new_game"   — reset board and start a new game
%   "draw_grid"  — draw the physical grid (robot-side only)
%   "quit"       — cleanly exit the loop
%
% Game state encoding (/tictactoe/game_state):
%   9-character string of '0','1','2' (row-major)
%   e.g. "010020000" means X in (1,2), O in (2,2), rest empty
%
% Status encoding (/tictactoe/status):
%   "waiting"    — ready for human move
%   "robot_turn" — robot is computing/drawing
%   "human_wins" — game over
%   "robot_wins" — game over
%   "draw"       — game over
%
% Prerequisites:
%   MATLAB Robotics System Toolbox (ROS2 support, R2022b+)
%   ROS2 Humble or later on same network / same host
%
% Setup:
%   source /opt/ros/humble/setup.bash    (both machines)
%   export ROS_DOMAIN_ID=42              (match on both machines)
%
% Run:
%   >> cd TicTacToe-3link-robot/ros2
%   >> tictactoe_ros2_robot
%
% Author: Yusuf Guenena
% =========================================================

clc;
fprintf('TicTacToe ROS2 Robot Node\n');
fprintf('=========================\n\n');

% ── Add paths ─────────────────────────────────────────────────────────
script_dir = fileparts(mfilename('fullpath'));
root_dir   = fileparts(script_dir);
addpath(root_dir);
addpath(fullfile(root_dir, 'ai_strategies'));

% ── Hardware setup (optional — set USE_HARDWARE=false for sim-only) ───
USE_HARDWARE = false;

robot = []; servo1 = []; servo2 = []; servo3 = [];
cal   = []; cfg    = [];

if USE_HARDWARE
    robot = create_robot();
    cal   = get_servo_calibration();
    cfg   = drawing_config();
    com   = input('COM port for Arduino (e.g. COM5 or /dev/ttyUSB0): ', 's');
    try
        device = arduino(com, 'uno', 'libraries', 'Servo');
        servo1 = servo(device,'D3','MinPulseDuration',0.5e-3,'MaxPulseDuration',2.5e-3);
        servo2 = servo(device,'D5','MinPulseDuration',0.5e-3,'MaxPulseDuration',2.5e-3);
        servo3 = servo(device,'D6','MinPulseDuration',0.5e-3,'MaxPulseDuration',2.5e-3);
        pen_up(servo3, cfg);
        fprintf('[HW] Arduino connected on %s\n', com);
    catch ME
        warning('[HW] Arduino connection failed: %s\nRunning without hardware.', ME.message);
        USE_HARDWARE = false;
    end
end

% ── ROS2 node setup ───────────────────────────────────────────────────
fprintf('[ROS2] Creating node /tictactoe_robot ...\n');
node = ros2node('/tictactoe_robot');

pub_robot_move  = ros2publisher(node, '/tictactoe/robot_move',  'std_msgs/String');
pub_game_state  = ros2publisher(node, '/tictactoe/game_state',  'std_msgs/String');
pub_status      = ros2publisher(node, '/tictactoe/status',      'std_msgs/String');

sub_human_move  = ros2subscriber(node, '/tictactoe/human_move', 'std_msgs/String');
sub_command     = ros2subscriber(node, '/tictactoe/command',    'std_msgs/String');

fprintf('[ROS2] Node ready. Topics:\n');
fprintf('  PUB  /tictactoe/robot_move\n');
fprintf('  PUB  /tictactoe/game_state\n');
fprintf('  PUB  /tictactoe/status\n');
fprintf('  SUB  /tictactoe/human_move\n');
fprintf('  SUB  /tictactoe/command\n\n');

% ── Game state ────────────────────────────────────────────────────────
board      = zeros(3,3);
gameActive = false;

publish_status(pub_status, 'idle');
publish_state(pub_game_state, board);
fprintf('[GAME] Send "new_game" or "draw_grid" on /tictactoe/command to start.\n');
fprintf('       Press Ctrl+C to quit.\n\n');

% ── Main loop ─────────────────────────────────────────────────────────
while true
    pause(0.1);   % 10 Hz poll

    % ── Handle commands ──────────────────────────────────────────────
    cmd_msg = sub_command.LatestMessage;
    if ~isempty(cmd_msg)
        cmd = strtrim(char(cmd_msg.data));
        sub_command.LatestMessage = [];   % clear after reading

        switch lower(cmd)
            case 'new_game'
                board      = zeros(3,3);
                gameActive = true;
                fprintf('[CMD] new_game — board reset\n');
                publish_state(pub_game_state, board);
                publish_status(pub_status, 'waiting');
                if USE_HARDWARE
                    fprintf('[HW] Drawing grid...\n');
                    draw_grid(robot, servo1, servo2, servo3, cal, cfg);
                end

            case 'draw_grid'
                fprintf('[CMD] draw_grid\n');
                if USE_HARDWARE
                    draw_grid(robot, servo1, servo2, servo3, cal, cfg);
                else
                    fprintf('[SIM] (no hardware) draw_grid skipped\n');
                end

            case 'quit'
                fprintf('[CMD] quit received — exiting.\n');
                publish_status(pub_status, 'idle');
                break;

            otherwise
                fprintf('[CMD] unknown command: "%s"\n', cmd);
        end
    end

    if ~gameActive, continue; end

    % ── Handle human move ────────────────────────────────────────────
    move_msg = sub_human_move.LatestMessage;
    if isempty(move_msg), continue; end
    sub_human_move.LatestMessage = [];   % clear

    sq = str2double(strtrim(char(move_msg.data)));
    if isnan(sq) || sq < 1 || sq > 9 || floor(sq) ~= sq
        fprintf('[WARN] Invalid human move message: "%s"\n', char(move_msg.data));
        continue;
    end
    sq  = floor(sq);
    row = ceil(sq / 3);
    col = mod(sq - 1, 3) + 1;

    if board(row, col) ~= 0
        fprintf('[WARN] Square %d is already occupied — ignoring.\n', sq);
        continue;
    end

    % Apply human move
    board(row, col) = 1;
    fprintf('[GAME] Human plays square %d  (%d,%d)\n', sq, row, col);
    publish_state(pub_game_state, board);

    if USE_HARDWARE
        draw_X(robot, servo1, servo2, servo3, cal, cfg, row, col);
    end

    % Check result after human move
    result = ttt_check_winner(board);
    if result ~= 0
        publish_state(pub_game_state, board);
        handle_game_over(result, pub_status);
        gameActive = false;
        continue;
    end

    % Robot move via Minimax
    publish_status(pub_status, 'robot_turn');
    [rr, cc] = strategy_minimax(board, 2);
    board(rr, cc) = 2;
    robot_sq = (rr-1)*3 + cc;
    fprintf('[GAME] Robot plays square %d  (%d,%d)\n', robot_sq, rr, cc);

    % Publish robot move first so remote sees it immediately
    msg_rm       = ros2message('std_msgs/String');
    msg_rm.data  = num2str(robot_sq);
    send(pub_robot_move, msg_rm);

    publish_state(pub_game_state, board);

    if USE_HARDWARE
        draw_O(robot, servo1, servo2, servo3, cal, cfg, rr, cc);
    end

    % Check result after robot move
    result = ttt_check_winner(board);
    if result ~= 0
        publish_state(pub_game_state, board);
        handle_game_over(result, pub_status);
        gameActive = false;
    else
        publish_status(pub_status, 'waiting');
    end
end

% ── Clean up ──────────────────────────────────────────────────────────
clear node;
fprintf('[ROS2] Node shut down.\n');

% =========================================================
%  Helper functions
% =========================================================

function publish_state(pub, board)
    msg      = ros2message('std_msgs/String');
    flat     = board(:)';            % row-major reshape
    msg.data = num2str(flat, '%d');
    msg.data = strrep(msg.data, ' ', '');   % e.g. "010020000"
    send(pub, msg);
end

function publish_status(pub, status_str)
    msg      = ros2message('std_msgs/String');
    msg.data = status_str;
    send(pub, msg);
    fprintf('[STATUS] %s\n', status_str);
end

function handle_game_over(result, pub_status)
    switch result
        case 1, publish_status(pub_status, 'human_wins');
        case 2, publish_status(pub_status, 'robot_wins');
        case 3, publish_status(pub_status, 'draw');
    end
end

function result = ttt_check_winner(board)
    result = 0;
    for p = [1 2]
        for r = 1:3, if all(board(r,:)==p), result=p; return; end; end
        for c = 1:3, if all(board(:,c)==p), result=p; return; end; end
        if board(1,1)==p&&board(2,2)==p&&board(3,3)==p, result=p; return; end
        if board(1,3)==p&&board(2,2)==p&&board(3,1)==p, result=p; return; end
    end
    if all(board(:)~=0), result=3; end
end
