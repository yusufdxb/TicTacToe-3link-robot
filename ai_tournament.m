% ai_tournament.m
% =========================================================
% AI Strategy Tournament — TicTacToe 3-Link Robot
% =========================================================
% Runs head-to-head matches between AI strategies and prints
% a results table: wins, draws, losses, and win rate.
%
% Strategies available:
%   'minimax'   — Optimal Minimax AI (never loses)
%   'heuristic' — Priority-based (win > block > center > corner > edge)
%   'random'    — Uniform random legal move
%   'chatgpt'   — OpenAI GPT-4o (requires config.m with valid API key;
%                 falls back to heuristic when key is absent/invalid)
%
% Usage:
%   ai_tournament           % run default suite (no hardware required)
%   ai_tournament(200)      % run each matchup 200 times
%
% Results are printed to the console and saved to
%   ai_strategies/tournament_results.txt
%
% Author: Yusuf Guenena
% =========================================================

function ai_tournament(n_games)

    if nargin < 1, n_games = 100; end

    % Add strategy folder to path
    this_dir = fileparts(mfilename('fullpath'));
    addpath(fullfile(this_dir, 'ai_strategies'));

    fprintf('\n=== TicTacToe AI Tournament (%d games per matchup) ===\n\n', n_games);

    % ── Define matchups ────────────────────────────────────────────────
    % Each row: {player-X strategy, player-O strategy, label}
    matchups = {
        'minimax',   'random',    'Minimax(X) vs Random(O)';
        'random',    'minimax',   'Random(X)  vs Minimax(O)';
        'minimax',   'heuristic', 'Minimax(X) vs Heuristic(O)';
        'heuristic', 'minimax',   'Heuristic(X) vs Minimax(O)';
        'heuristic', 'random',    'Heuristic(X) vs Random(O)';
        'random',    'heuristic', 'Random(X)  vs Heuristic(O)';
    };

    % Check if ChatGPT is available
    if chatgpt_available()
        matchups = [matchups; {
            'minimax',  'chatgpt',  'Minimax(X) vs ChatGPT(O)';
            'chatgpt',  'minimax',  'ChatGPT(X) vs Minimax(O)';
            'chatgpt',  'heuristic','ChatGPT(X) vs Heuristic(O)';
            'chatgpt',  'random',   'ChatGPT(X) vs Random(O)';
        }];
        fprintf('[INFO] ChatGPT API key found — ChatGPT matchups included.\n\n');
    else
        fprintf('[INFO] No ChatGPT API key — ChatGPT matchups skipped.\n');
        fprintf('       Copy config.example.m to config.m and add your OpenAI key.\n\n');
    end

    % ── Run all matchups ───────────────────────────────────────────────
    n = size(matchups, 1);
    results = zeros(n, 3);   % [wins_for_X, draws, wins_for_O]

    for m = 1:n
        strat_x = matchups{m, 1};
        strat_o = matchups{m, 2};
        label   = matchups{m, 3};

        fprintf('Running: %s ... ', label);
        [wx, d, wo] = run_matchup(strat_x, strat_o, n_games);
        results(m,:) = [wx, d, wo];
        fprintf('X wins=%d  Draws=%d  O wins=%d\n', wx, d, wo);
    end

    % ── Print results table ────────────────────────────────────────────
    fprintf('\n%-40s  %6s  %6s  %6s  %8s\n', 'Matchup', 'X-Win', 'Draw', 'O-Win', 'X WinRate');
    fprintf('%s\n', repmat('-', 1, 75));
    for m = 1:n
        wx = results(m,1); d = results(m,2); wo = results(m,3);
        rate = 100 * wx / n_games;
        fprintf('%-40s  %6d  %6d  %6d  %7.1f%%\n', matchups{m,3}, wx, d, wo, rate);
    end
    fprintf('\n');

    % ── Save results to file ───────────────────────────────────────────
    out_file = fullfile(this_dir, 'ai_strategies', 'tournament_results.txt');
    fid = fopen(out_file, 'w');
    fprintf(fid, 'TicTacToe AI Tournament Results\n');
    fprintf(fid, 'Games per matchup: %d\n', n_games);
    fprintf(fid, 'Run date: %s\n\n', datestr(now));
    fprintf(fid, '%-40s  %6s  %6s  %6s  %8s\n', 'Matchup', 'X-Win', 'Draw', 'O-Win', 'X WinRate');
    fprintf(fid, '%s\n', repmat('-', 1, 75));
    for m = 1:n
        wx = results(m,1); d = results(m,2); wo = results(m,3);
        rate = 100 * wx / n_games;
        fprintf(fid, '%-40s  %6d  %6d  %6d  %7.1f%%\n', matchups{m,3}, wx, d, wo, rate);
    end
    fclose(fid);
    fprintf('Results saved to: %s\n\n', out_file);
end

% ── Simulate n_games between two strategies ──────────────────────────────
function [wins_x, draws, wins_o] = run_matchup(strat_x, strat_o, n)
    wins_x = 0; draws = 0; wins_o = 0;
    for g = 1:n
        outcome = play_game(strat_x, strat_o);
        if     outcome == 1, wins_x = wins_x + 1;
        elseif outcome == 3, draws  = draws  + 1;
        else,                wins_o = wins_o + 1;
        end
    end
end

% ── Play a single game, return winner (1=X, 2=O, 3=draw) ────────────────
function result = play_game(strat_x, strat_o)
    board   = zeros(3, 3);
    players = {strat_x, strat_o};
    ids     = [1 2];

    for turn = 1:9
        p     = ids(mod(turn-1, 2) + 1);
        strat = players{mod(turn-1, 2) + 1};

        [r, c] = call_strategy(strat, board, p);

        % Guard: reject illegal moves (shouldn't happen with correct strategies)
        if board(r, c) ~= 0
            warning('ai_tournament: strategy "%s" returned occupied square — choosing random fallback', strat);
            [r, c] = strategy_random(board, p);
        end

        board(r, c) = p;
        result = check_winner_tournament(board);
        if result ~= 0, return; end
    end
    result = 3;  % draw
end

% ── Dispatch to the correct strategy function ────────────────────────────
function [row, col] = call_strategy(name, board, player)
    switch lower(name)
        case 'minimax',   [row, col] = strategy_minimax(board, player);
        case 'random',    [row, col] = strategy_random(board, player);
        case 'heuristic', [row, col] = strategy_heuristic(board, player);
        case 'chatgpt',   [row, col] = strategy_chatgpt(board, player);
        otherwise
            error('ai_tournament: unknown strategy "%s"', name);
    end
end

% ── Terminal check ───────────────────────────────────────────────────────
function result = check_winner_tournament(board)
    result = 0;
    for p = [1 2]
        for r = 1:3, if all(board(r,:) == p), result = p; return; end; end
        for c = 1:3, if all(board(:,c) == p), result = p; return; end; end
        if board(1,1)==p && board(2,2)==p && board(3,3)==p, result = p; return; end
        if board(1,3)==p && board(2,2)==p && board(3,1)==p, result = p; return; end
    end
    if all(board(:) ~= 0), result = 3; end
end

% ── Check if ChatGPT is usable ───────────────────────────────────────────
function ok = chatgpt_available()
    ok = false;
    if ~exist('config.m', 'file'), return; end
    try
        cfg = config();
        if isfield(cfg, 'openai_api_key') && ~isempty(cfg.openai_api_key) ...
                && ~strcmp(cfg.openai_api_key, 'YOUR_OPENAI_API_KEY_HERE')
            ok = true;
        end
    catch
    end
end
