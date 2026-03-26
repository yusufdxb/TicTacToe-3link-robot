function [row, col] = strategy_minimax(board, player)
% STRATEGY_MINIMAX  Select the optimal move using the Minimax algorithm.
%
%   [row, col] = strategy_minimax(board, player)
%
%   board  : 3x3 matrix  (0=empty, 1=player-1/X, 2=player-2/O)
%   player : integer, 1 or 2 — whose turn it is
%
%   Returns the row and column of the optimal move.
%   This player never loses; best human outcome is a draw.
%
% Author: Yusuf Guenena

    opponent = 3 - player;   % player=1 → opponent=2, and vice versa

    bestScore = -Inf;
    row = -1; col = -1;

    for r = 1:3
        for c = 1:3
            if board(r, c) == 0
                board(r, c) = player;
                s = mm_score(board, player, opponent, false);
                board(r, c) = 0;
                if s > bestScore
                    bestScore = s;
                    row = r; col = c;
                end
            end
        end
    end
end

% ── Recursive minimax ────────────────────────────────────────────────────
function score = mm_score(board, maxPlayer, minPlayer, isMax)
    w = mm_check_winner(board);
    if w == maxPlayer, score =  10; return; end
    if w == minPlayer, score = -10; return; end
    if w == 3,         score =   0; return; end   % draw

    if isMax
        best = -Inf;
        for i = 1:3
            for j = 1:3
                if board(i,j) == 0
                    board(i,j) = maxPlayer;
                    best = max(best, mm_score(board, maxPlayer, minPlayer, false));
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
                    board(i,j) = minPlayer;
                    best = min(best, mm_score(board, maxPlayer, minPlayer, true));
                    board(i,j) = 0;
                end
            end
        end
        score = best;
    end
end

% ── Terminal check (0=none, 1=p1 wins, 2=p2 wins, 3=draw) ───────────────
function result = mm_check_winner(board)
    result = 0;
    for p = [1 2]
        for r = 1:3, if all(board(r,:) == p), result = p; return; end; end
        for c = 1:3, if all(board(:,c) == p), result = p; return; end; end
        if board(1,1)==p && board(2,2)==p && board(3,3)==p, result = p; return; end
        if board(1,3)==p && board(2,2)==p && board(3,1)==p, result = p; return; end
    end
    if all(board(:) ~= 0), result = 3; end
end
