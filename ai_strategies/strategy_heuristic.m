function [row, col] = strategy_heuristic(board, player)
% STRATEGY_HEURISTIC  Priority-based TicTacToe heuristic.
%
%   [row, col] = strategy_heuristic(board, player)
%
%   board  : 3x3 matrix  (0=empty, 1=X, 2=O)
%   player : 1 or 2 — whose turn it is
%
%   Move priority (in order):
%     1. Win immediately if possible
%     2. Block opponent's immediate win
%     3. Take center
%     4. Take any corner
%     5. Take any edge
%
%   This is stronger than random but weaker than Minimax because it does
%   not look ahead more than one move (no two-move fork detection).
%
% Author: Yusuf Guenena

    opponent = 3 - player;

    % 1. Win immediately
    [r, c] = find_winning_move(board, player);
    if r > 0, row = r; col = c; return; end

    % 2. Block opponent win
    [r, c] = find_winning_move(board, opponent);
    if r > 0, row = r; col = c; return; end

    % 3. Center
    if board(2,2) == 0, row = 2; col = 2; return; end

    % 4. Any corner (prefer opposite corner if opponent is there)
    corners = [1 1; 1 3; 3 1; 3 3];
    order   = randperm(4);          % shuffle to avoid deterministic corner bias
    for k = order
        r = corners(k,1); c = corners(k,2);
        if board(r,c) == 0, row = r; col = c; return; end
    end

    % 5. Any edge
    edges = [1 2; 2 1; 2 3; 3 2];
    for k = 1:4
        r = edges(k,1); c = edges(k,2);
        if board(r,c) == 0, row = r; col = c; return; end
    end

    % Fallback — should never reach here if board is not full
    [rows, cols] = find(board == 0);
    row = rows(1); col = cols(1);
end

% ── Find a move that wins for 'p' in one step ────────────────────────────
function [row, col] = find_winning_move(board, p)
    row = -1; col = -1;
    for r = 1:3
        for c = 1:3
            if board(r,c) == 0
                board(r,c) = p;
                if check_win(board, p)
                    row = r; col = c;
                    board(r,c) = 0;
                    return;
                end
                board(r,c) = 0;
            end
        end
    end
end

function won = check_win(board, p)
    won = false;
    for r = 1:3, if all(board(r,:) == p), won = true; return; end; end
    for c = 1:3, if all(board(:,c) == p), won = true; return; end; end
    if board(1,1)==p && board(2,2)==p && board(3,3)==p, won = true; return; end
    if board(1,3)==p && board(2,2)==p && board(3,1)==p, won = true; return; end
end
