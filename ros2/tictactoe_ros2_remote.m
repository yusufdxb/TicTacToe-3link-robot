% ros2/tictactoe_ros2_remote.m
% =========================================================
% REMOTE PLAYER — ROS2 Interface — TicTacToe 3-Link Robot
% =========================================================
% Run this on the REMOTE laptop (not connected to the robot).
% Both machines must be on the same network and share the same
% ROS_DOMAIN_ID environment variable.
%
% What it does:
%   - Publishes  to /tictactoe/human_move  (std_msgs/String)
%   - Publishes  to /tictactoe/command     (std_msgs/String)
%   - Subscribes to /tictactoe/game_state  (std_msgs/String)
%   - Subscribes to /tictactoe/robot_move  (std_msgs/String)
%   - Subscribes to /tictactoe/status      (std_msgs/String)
%
% The remote player clicks squares 1-9 in this terminal UI.
% The game state display updates in real time as the robot
% side publishes changes.
%
% Prerequisites:
%   MATLAB Robotics System Toolbox (ROS2 support, R2022b+)
%   ROS2 Humble or later on the same network as the robot PC
%
% Network setup (both machines, same shell session):
%   export ROS_DOMAIN_ID=42
%   source /opt/ros/humble/setup.bash
%
% Run:
%   >> cd TicTacToe-3link-robot/ros2
%   >> tictactoe_ros2_remote
%
% Author: Yusuf Guenena
% =========================================================

clc;
fprintf('TicTacToe ROS2 Remote Player\n');
fprintf('============================\n\n');

% ── ROS2 setup ────────────────────────────────────────────────────────
fprintf('[ROS2] Creating node /tictactoe_remote ...\n');
node = ros2node('/tictactoe_remote');

pub_human_move = ros2publisher(node, '/tictactoe/human_move', 'std_msgs/String');
pub_command    = ros2publisher(node, '/tictactoe/command',    'std_msgs/String');

sub_game_state = ros2subscriber(node, '/tictactoe/game_state', 'std_msgs/String');
sub_robot_move = ros2subscriber(node, '/tictactoe/robot_move', 'std_msgs/String');
sub_status     = ros2subscriber(node, '/tictactoe/status',     'std_msgs/String');

fprintf('[ROS2] Connected.\n\n');

% ── UI loop ───────────────────────────────────────────────────────────
board = zeros(3,3);
last_status = '';

print_help();

while true
    % Refresh game state from robot side
    [board, state_changed] = poll_board(sub_game_state, board);

    % Check status
    status_msg = sub_status.LatestMessage;
    if ~isempty(status_msg)
        new_status = strtrim(char(status_msg.data));
        if ~strcmp(new_status, last_status)
            last_status = new_status;
            fprintf('\n[STATUS] %s\n', new_status);
            if state_changed
                print_board_console(board);
            end
            if ismember(new_status, {'human_wins','robot_wins','draw'})
                fprintf('\n--- Game over. Send "new_game" to play again. ---\n\n');
            end
        end
    end

    % Check robot move notification
    rm_msg = sub_robot_move.LatestMessage;
    if ~isempty(rm_msg)
        sub_robot_move.LatestMessage = [];
        sq = str2double(strtrim(char(rm_msg.data)));
        if ~isnan(sq)
            fprintf('[ROBOT] Robot played square %d\n', sq);
        end
    end

    % Get user input (non-blocking via drawnow trick)
    drawnow;
    cmd = get_user_input();
    if isempty(cmd), pause(0.2); continue; end

    cmd = strtrim(lower(cmd));

    switch cmd
        case 'new_game'
            send_command(pub_command, 'new_game');
            board = zeros(3,3);
            fprintf('[CMD] new_game sent\n');

        case 'draw_grid'
            send_command(pub_command, 'draw_grid');
            fprintf('[CMD] draw_grid sent\n');

        case 'quit'
            send_command(pub_command, 'quit');
            fprintf('[CMD] quit sent — exiting.\n');
            break;

        case 'board'
            print_board_console(board);

        case 'help'
            print_help();

        otherwise
            % Try to parse as a move (integer 1-9)
            sq = str2double(cmd);
            if ~isnan(sq) && sq >= 1 && sq <= 9 && floor(sq) == sq
                row = ceil(sq / 3);
                col = mod(sq - 1, 3) + 1;
                if board(row, col) ~= 0
                    fprintf('[WARN] Square %d is already taken. Choose another.\n', sq);
                else
                    send_move(pub_human_move, sq);
                    fprintf('[MOVE] Sent move: square %d\n', sq);
                end
            else
                fprintf('[WARN] Unknown input: "%s" (type "help" for commands)\n', cmd);
            end
    end
end

% ── Clean up ──────────────────────────────────────────────────────────
clear node;
fprintf('[ROS2] Disconnected.\n');

% =========================================================
%  Helper functions
% =========================================================

function [board, changed] = poll_board(sub, board)
    changed = false;
    msg = sub.LatestMessage;
    if isempty(msg), return; end
    raw = strtrim(char(msg.data));
    if length(raw) ~= 9, return; end
    new_board = zeros(3,3);
    for k = 1:9
        new_board(ceil(k/3), mod(k-1,3)+1) = str2double(raw(k));
    end
    if any(new_board(:) ~= board(:))
        board   = new_board;
        changed = true;
    end
end

function send_move(pub, sq)
    msg      = ros2message('std_msgs/String');
    msg.data = num2str(floor(sq));
    send(pub, msg);
end

function send_command(pub, cmd_str)
    msg      = ros2message('std_msgs/String');
    msg.data = cmd_str;
    send(pub, msg);
end

function print_board_console(board)
    syms = {'.', 'X', 'O'};
    sq   = 1;
    fprintf('\n  Board  (square numbers)\n');
    for r = 1:3
        fprintf('  ');
        for c = 1:3
            fprintf(' %s ', syms{board(r,c)+1});
            if c < 3, fprintf('|'); end
        end
        fprintf('     ');
        for c = 1:3
            fprintf(' %d ', sq); sq = sq + 1;
            if c < 3, fprintf('|'); end
        end
        fprintf('\n');
        if r < 3
            fprintf('  ---|---|---     ---|---|---\n');
        end
    end
    fprintf('\n');
end

function print_help()
    fprintf('Commands:\n');
    fprintf('  1-9        Send your move (square number)\n');
    fprintf('  new_game   Start a new game\n');
    fprintf('  draw_grid  Tell robot to draw the grid\n');
    fprintf('  board      Show current board\n');
    fprintf('  quit       Exit\n');
    fprintf('  help       Show this help\n\n');
    fprintf('Square layout:\n');
    fprintf('  1 | 2 | 3\n');
    fprintf('  4 | 5 | 6\n');
    fprintf('  7 | 8 | 9\n\n');
end

function cmd = get_user_input()
    % MATLAB input() blocks — use a timer-based non-blocking approach.
    % For simplicity in a terminal loop, we call input() synchronously.
    % Users can press Enter with no text to skip a poll cycle.
    try
        cmd = input('> ', 's');
    catch
        cmd = '';
    end
end
