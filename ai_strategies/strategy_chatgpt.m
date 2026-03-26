function [row, col] = strategy_chatgpt(board, player)
% STRATEGY_CHATGPT  Query the OpenAI ChatGPT API to select a move.
%
%   [row, col] = strategy_chatgpt(board, player)
%
%   board  : 3x3 matrix  (0=empty, 1=X, 2=O)
%   player : 1 or 2 — whose turn it is
%
%   Requires config.m to exist with a valid openai_api_key field.
%   See config.example.m for the template.
%
%   On API failure (network error, quota exceeded, invalid key), this
%   function falls back to strategy_heuristic automatically and logs
%   a warning so the tournament can continue uninterrupted.
%
%   Model: gpt-4o (change OPENAI_MODEL below if needed)
%
% Author: Yusuf Guenena

    OPENAI_MODEL = 'gpt-4o';
    OPENAI_URL   = 'https://api.openai.com/v1/chat/completions';

    % Load API key
    api_key = load_api_key();
    if isempty(api_key)
        warning('strategy_chatgpt: no API key — falling back to heuristic');
        [row, col] = strategy_heuristic(board, player);
        return;
    end

    % Build prompt
    board_str = board_to_string(board, player);
    prompt    = sprintf([ ...
        'You are playing TicTacToe. The 3x3 board uses positions 1-9 ' ...
        '(left to right, top to bottom). 0=empty, 1=X, 2=O.\n' ...
        'Board (row,col): %s\n' ...
        'You are player %d. Reply with ONLY a single integer 1-9 ' ...
        'for your move. No explanation.'], board_str, player);

    % Build request body
    body = struct();
    body.model = OPENAI_MODEL;
    body.messages = {struct('role','user','content',prompt)};
    body.max_tokens = 5;
    body.temperature = 0;

    body_json = jsonencode(body);

    % HTTP POST to OpenAI
    try
        opts = weboptions( ...
            'MediaType',       'application/json', ...
            'RequestMethod',   'post', ...
            'HeaderFields',    {'Authorization', ['Bearer ' api_key]; ...
                                'Content-Type',  'application/json'}, ...
            'Timeout',         15);
        response = webwrite(OPENAI_URL, body_json, opts);
    catch ME
        warning('strategy_chatgpt: API call failed (%s) — falling back to heuristic', ME.message);
        [row, col] = strategy_heuristic(board, player);
        return;
    end

    % Parse response
    try
        content = strtrim(response.choices{1}.message.content);
        sq = str2double(content);
        if isnan(sq) || sq < 1 || sq > 9 || floor(sq) ~= sq
            warning('strategy_chatgpt: unexpected reply "%s" — falling back to heuristic', content);
            [row, col] = strategy_heuristic(board, player);
            return;
        end
        sq  = floor(sq);
        row = ceil(sq / 3);
        col = mod(sq - 1, 3) + 1;
        if board(row, col) ~= 0
            warning('strategy_chatgpt: replied with occupied square %d — falling back to heuristic', sq);
            [row, col] = strategy_heuristic(board, player);
        end
    catch ME
        warning('strategy_chatgpt: parse error (%s) — falling back to heuristic', ME.message);
        [row, col] = strategy_heuristic(board, player);
    end
end

% ── Helpers ─────────────────────────────────────────────────────────────

function key = load_api_key()
    key = '';
    if exist('config.m', 'file')
        try
            cfg = config();
            if isfield(cfg, 'openai_api_key') && ~isempty(cfg.openai_api_key) ...
                    && ~strcmp(cfg.openai_api_key, 'YOUR_OPENAI_API_KEY_HERE')
                key = cfg.openai_api_key;
            end
        catch
        end
    end
end

function s = board_to_string(board, ~)
    % Returns a compact row-major representation for the prompt
    rows = cell(3,1);
    for r = 1:3
        rows{r} = sprintf('(%d,%d)=%d (%d,%d)=%d (%d,%d)=%d', ...
            r,1,board(r,1), r,2,board(r,2), r,3,board(r,3));
    end
    s = strjoin(rows, ' | ');
end
