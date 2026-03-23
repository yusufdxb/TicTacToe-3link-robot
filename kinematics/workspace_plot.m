%% workspace_plot.m — Reachable Workspace Visualization for RRP Robot
% Generates a 2D reachable workspace plot for the 2-DOF planar arm (J1+J2).
% The prismatic joint (J3) is not a positioning joint; it is excluded.
%
% Robot parameters (from robot_kinematics.m):
%   Link 1: 110 mm  (J1 -> J2)
%   Link 2: 104 mm  (J2 -> EE)
%   Base offset: X = -29 mm, Y = 121 mm
%
% Run from the repo root:
%   workspace_plot
%
% Outputs:
%   kinematics/workspace.png  — reachable workspace figure (saved automatically)

clear; close all;

%% Parameters
L1 = 110;   % mm — link 1 length
L2 = 104;   % mm — link 2 length
base_x = -29;  % mm — base offset X
base_y = 121;  % mm — base offset Y

% Joint limits (mechanical stops, from test_robot.m calibration)
% theta1: full 0..180 deg range (servo maps 0->180)
% theta2: full 0..180 deg range
THETA1_MIN = 0;    THETA1_MAX = 180;   % degrees
THETA2_MIN = 0;    THETA2_MAX = 180;   % degrees

%% Sweep all valid joint configurations
theta1_vals = linspace(THETA1_MIN, THETA1_MAX, 180);
theta2_vals = linspace(THETA2_MIN, THETA2_MAX, 180);

reachable_x = [];
reachable_y = [];

for t1 = theta1_vals
    for t2 = theta2_vals
        t1r = deg2rad(t1);
        t2r = deg2rad(t2);

        % Forward kinematics (planar, from base frame)
        x = L1*cos(t1r) + L2*cos(t1r + t2r);
        y = L1*sin(t1r) + L2*sin(t1r + t2r);

        % Transform to world frame (add base offset)
        reachable_x(end+1) = x + base_x;
        reachable_y(end+1) = y + base_y;
    end
end

%% Drawing surface: TicTacToe grid squares (from robot_kinematics.m)
% Grid center approximately at (80, 150) mm from robot origin
grid_center_x = 80;
grid_center_y = 150;
cell_size = 30;  % mm per cell

grid_x = [];
grid_y = [];
for row = -1:1
    for col = -1:1
        grid_x(end+1) = grid_center_x + col * cell_size;
        grid_y(end+1) = grid_center_y + row * cell_size;
    end
end

%% Plot
fig = figure('Position', [100 100 700 700]);

% Reachable workspace (scatter)
scatter(reachable_x, reachable_y, 1, [0.7 0.85 1.0], 'filled', ...
    'DisplayName', 'Reachable workspace');
hold on;

% Outer boundary trace (convex hull)
try
    k = convhull(reachable_x, reachable_y);
    plot(reachable_x(k), reachable_y(k), 'b-', 'LineWidth', 1.5, ...
        'DisplayName', 'Workspace boundary');
catch
end

% Base position
plot(base_x, base_y, 'ks', 'MarkerSize', 10, 'MarkerFaceColor', 'k', ...
    'DisplayName', 'Robot base');

% TicTacToe grid squares
scatter(grid_x, grid_y, 80, 'r', 'filled', 'DisplayName', 'Grid squares');
for i = 1:length(grid_x)
    text(grid_x(i)+2, grid_y(i)+2, num2str(i), 'FontSize', 8, 'Color', 'r');
end

% Workspace radius circles for reference
theta_circle = linspace(0, 2*pi, 360);
r_max = L1 + L2;
r_min = abs(L1 - L2);
plot(base_x + r_max*cos(theta_circle), base_y + r_max*sin(theta_circle), ...
    'k--', 'Alpha', 0.3, 'DisplayName', sprintf('Max reach (%d mm)', r_max));
plot(base_x + r_min*cos(theta_circle), base_y + r_min*sin(theta_circle), ...
    'k:', 'Alpha', 0.3, 'DisplayName', sprintf('Min reach (%d mm)', r_min));

%% Labels and formatting
xlabel('X (mm)'); ylabel('Y (mm)');
title(sprintf('RRP Robot — Reachable Workspace\nL1=%d mm, L2=%d mm, Base=(%d,%d)', ...
    L1, L2, base_x, base_y));
legend('Location', 'northwest', 'FontSize', 9);
axis equal; grid on;
xlim([-250 250]); ylim([-50 350]);

% Add reach annotation
annotation('textbox', [0.62 0.04 0.35 0.08], ...
    'String', sprintf('Max reach: %d mm\nMin reach: %d mm', r_max, r_min), ...
    'FitBoxToText', 'on', 'BackgroundColor', 'white', 'FontSize', 8);

%% Save figure
out_dir = fileparts(mfilename('fullpath'));
out_path = fullfile(out_dir, 'workspace.png');
exportgraphics(fig, out_path, 'Resolution', 150);
fprintf('Workspace plot saved: %s\n', out_path);
fprintf('Max reach: %d mm\n', r_max);
fprintf('Min reach: %d mm\n', r_min);

% Check all 9 grid squares are reachable
in_workspace = false(1, length(grid_x));
for i = 1:length(grid_x)
    dx = grid_x(i) - base_x;
    dy = grid_y(i) - base_y;
    r = sqrt(dx^2 + dy^2);
    in_workspace(i) = (r >= r_min) && (r <= r_max);
end
fprintf('\nGrid square reachability (%d/9 in workspace):\n', sum(in_workspace));
for i = 1:length(grid_x)
    fprintf('  Square %d (%3.0f, %3.0f mm): %s\n', i, grid_x(i), grid_y(i), ...
        ternary(in_workspace(i), 'reachable', 'OUT OF REACH'));
end

function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end
