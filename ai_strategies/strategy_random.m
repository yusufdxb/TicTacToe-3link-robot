function [row, col] = strategy_random(board, ~)
% STRATEGY_RANDOM  Pick a uniformly random legal move.
%
%   [row, col] = strategy_random(board, player)
%
%   board  : 3x3 matrix  (0=empty, 1=X, 2=O)
%   player : ignored — random strategy is player-agnostic
%
%   Useful as a baseline for comparing AI strategies.
%
% Author: Yusuf Guenena

    [rows, cols] = find(board == 0);
    if isempty(rows)
        error('strategy_random: no legal moves available');
    end
    idx = randi(length(rows));
    row = rows(idx);
    col = cols(idx);
end
