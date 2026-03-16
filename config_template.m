% config_template.m
% =========================================================
% Configuration Template — SAFE TO COMMIT
% =========================================================
% Copy this file to config_local.m and fill in real values.
% config_local.m is blocked by .gitignore.
%
% DO NOT put real API keys in this file.
% =========================================================

% Copy this file → config_local.m, then fill in your keys:
cfg.openai_key   = 'YOUR_OPENAI_API_KEY_HERE';
cfg.openai_model = 'gpt-4o';                    % or gpt-3.5-turbo

% Arduino COM port default (override per machine)
cfg.arduino_port = 'COM5';                       % Windows: COM5, Mac: /dev/tty.usbmodem*
