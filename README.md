# TicTacToe 3-Link Robot (RRP) 🤖

A **3-link robot arm** (2 revolute + 1 prismatic) controlled via **Arduino** and **MATLAB**
that plays **Tic Tac Toe** autonomously — physically drawing the grid, X's, and O's on
paper, while running a **Minimax AI** to compete against a human opponent.

[![Demo Video](https://img.shields.io/badge/▶_Watch_Demo-YouTube-red)](https://youtu.be/CDlnx14gcMo)
![MATLAB](https://img.shields.io/badge/MATLAB-R2022b+-orange)
![Arduino](https://img.shields.io/badge/Arduino-Uno-teal)
![License](https://img.shields.io/badge/License-MIT-green)

---

## 📹 Demo

<p align="center">
  <a href="https://youtu.be/CDlnx14gcMo">
    <img src="https://img.youtube.com/vi/CDlnx14gcMo/maxresdefault.jpg" width="640">
  </a>
</p>

**GUI Demo**

<p align="center">
  <a href="https://youtu.be/jF2vLUy49Z8">
    <img src="https://img.youtube.com/vi/jF2vLUy49Z8/maxresdefault.jpg" width="640">
  </a>
</p>


---

## What This Project Does

This project combines **robotics**, **embedded systems**, and **AI** into one
physical system:

1. The robot has **two revolute joints** (R1, R2) controlling planar arm motion
2. A **prismatic joint** (P3) drives a rack-and-pinion pen mechanism — extending
   the pen down to touch paper and retracting it to lift clear
3. MATLAB computes **closed-form planar inverse kinematics** to move the
   end-effector to any XY position on the drawing surface
4. A **Minimax AI** plays optimally — it never loses
5. Human clicks a square in the GUI → robot draws an **X** on paper
6. AI selects the best response → robot draws an **O** on paper
7. Game continues until win or draw

```
Human clicks square in GUI
        ↓
IK → R1 + R2 rotate → end-effector positions over square
        ↓
P3 extends → pen contacts paper → X drawn → P3 retracts
        ↓
Minimax AI selects optimal move
        ↓
IK → R1 + R2 rotate → O drawn the same way
        ↓
Win / Draw check → repeat or end
```

---

## Robot Configuration — RRP

| Joint | Type | Axis | Actuator | Arduino Pin |
|---|---|---|---|---|
| J1 | Revolute | Z | Servo motor | D3 |
| J2 | Revolute | Z | Servo motor | D5 |
| J3 | Prismatic | Z (vertical) | Servo + rack & pinion | D6 |

**Link lengths:**

| Link | Length |
|---|---|
| Link 1 (J1 → J2) | 110 mm |
| Link 2 (J2 → J3/EE) | 104 mm |
| Base offset | X: −29 mm, Y: 121 mm, Z: 77 mm |

The prismatic joint (J3) has two discrete states:
- **Extended** (pen down) — servo position 0.20 → pen contacts paper
- **Retracted** (pen up) — servo position 0.80 → pen lifted clear

---

## File Structure

```
TicTacToe-3link-robot/
├── TicTacToe_App.mlapp          ← GUI — open in MATLAB App Designer
├── twolink_App.m                ← Full app class (all callbacks)
├── robot_kinematics.m           ← Planar IK, FK, servo calibration
├── drawing_functions.m          ← drawGrid, drawX, drawO, pen control
├── tictactoe_game.m             ← Minimax AI + board logic (standalone)
├── main.m                       ← Terminal game loop (no GUI needed)
├── test_robot.m                 ← Hardware verification script
├── config.example.m             ← API key template (copy → config.m)
├── ai_tournament.m              ← Head-to-head AI strategy comparison runner
├── ai_strategies/
│   ├── strategy_minimax.m       ← Optimal Minimax (never loses)
│   ├── strategy_heuristic.m     ← Priority heuristic (win>block>center>corner)
│   ├── strategy_random.m        ← Random legal move (baseline)
│   └── strategy_chatgpt.m       ← GPT-4o via OpenAI API (needs config.m)
├── ros2/
│   ├── tictactoe_ros2_robot.m   ← MATLAB ROS2 node — robot side (Arduino)
│   ├── tictactoe_ros2_remote.m  ← MATLAB ROS2 node — remote player side
│   └── ros2_topics.md           ← Full topic/message encoding reference
├── REMOTE_AND_AI.md             ← Remote ROS2 gameplay + AI comparison docs
├── .gitignore                   ← Keeps config.m (secrets) off GitHub
├── LICENSE
└── README.md
```

---

## Quickstart

### With GUI (recommended)
```matlab
% 1. Open MATLAB → double-click TicTacToe_App.mlapp
% 2. Click Run in App Designer
% 3. Arduino menu → Connect → enter your COM port
% 4. Arduino menu → Connect Motor
% 5. Click "Create Robot"
% 6. Click "New Game" → click squares to play
```

### Terminal mode (no GUI)
```matlab
main
```

### Hardware test
```matlab
test_robot
```

---

## Kinematics

The RRP robot uses **closed-form 2-DOF planar IK** for the two revolute joints.
The prismatic joint is controlled independently as a binary pen state.

```
c₂ = (r² − a₁² − a₂²) / (2·a₁·a₂)
θ₂ = atan2(±√(1−c₂²), c₂)
θ₁ = atan2(y,x) − atan2(a₂·sin(θ₂), a₁ + a₂·cos(θ₂))
```

Both elbow-up and elbow-down solutions are computed. The one closest
to the current configuration is selected to minimise motion.

---

## Minimax AI

| Priority | Action |
|---|---|
| 1 | Win immediately |
| 2 | Block human win |
| 3 | Take center |
| 4 | Take a corner |
| 5 | Take any square |

The robot **never loses**. Best human outcome is a draw.

Minimax explores the complete game tree from the current board state,
alternating between maximising (robot) and minimising (human) at each
depth level. TicTacToe has at most 255,168 games so full tree search
completes in milliseconds with no pruning required.

---

## Remote ROS2 Gameplay

Play the robot from another laptop over Wi-Fi — no physical proximity required.

```
Remote Laptop                    Robot Laptop (Arduino)
─────────────────────────────    ──────────────────────────────────
tictactoe_ros2_remote.m      ←→  tictactoe_ros2_robot.m
                                       │
                                       ├─ Minimax picks robot move
                                       ├─ IK → servo angles
                                       └─ Arduino draws X / O on paper

              ROS2 DDS  (same Wi-Fi hotspot or LAN)
```

**ROS2 topics:**

| Topic | Direction | Encoding |
|-------|-----------|----------|
| `/tictactoe/human_move` | remote → robot | `"1"` – `"9"` (square) |
| `/tictactoe/robot_move` | robot → remote | `"1"` – `"9"` (square) |
| `/tictactoe/game_state` | robot → remote | 9-char board, e.g. `"010020000"` |
| `/tictactoe/command` | remote → robot | `"new_game"` / `"draw_grid"` / `"quit"` |
| `/tictactoe/status` | robot → remote | `"waiting"` / `"robot_wins"` / `"draw"` / … |

**Quick start (both machines — same `ROS_DOMAIN_ID`):**

```bash
# Both machines:
source /opt/ros/humble/setup.bash
export ROS_DOMAIN_ID=42
```

```matlab
% Robot-side machine (MATLAB):
cd('TicTacToe-3link-robot/ros2')
tictactoe_ros2_robot          % set USE_HARDWARE=true for real Arduino

% Remote-side machine (MATLAB):
tictactoe_ros2_remote
% then type:  new_game  draw_grid  5  board  quit
```


Full setup guide, troubleshooting, and CLI test commands:
[`REMOTE_AND_AI.md`](REMOTE_AND_AI.md) · [`ros2/ros2_topics.md`](ros2/ros2_topics.md)

---

## AI Strategy Comparison — Minimax vs ChatGPT

Four interchangeable strategies, all sharing the same `(board, player) → (row, col)` interface:

| Strategy | File | Notes |
|----------|------|-------|
| `minimax` | `ai_strategies/strategy_minimax.m` | Optimal — never loses |
| `heuristic` | `ai_strategies/strategy_heuristic.m` | Win > block > center > corner; no lookahead |
| `random` | `ai_strategies/strategy_random.m` | Uniform random; baseline |
| `chatgpt` | `ai_strategies/strategy_chatgpt.m` | GPT-4o; falls back to heuristic if key absent |

**Run the tournament:**

```matlab
ai_tournament        % 100 games per matchup
ai_tournament(500)   % tighter statistics
```

**ChatGPT setup (optional):**

```matlab
copyfile('config.example.m', 'config.m')
% Edit config.m → set cfg.openai_api_key = 'sk-...';
```

**Sample results (100 games per matchup, no ChatGPT key):**

```
Matchup                                   X-Win    Draw   O-Win   X WinRate
---------------------------------------------------------------------------
Minimax(X) vs Random(O)                      74      26       0      74.0%
Random(X)  vs Minimax(O)                      0      31      69       0.0%
Minimax(X) vs Heuristic(O)                   18      82       0      18.0%
Heuristic(X) vs Minimax(O)                    0      71      29       0.0%
Heuristic(X) vs Random(O)                    72      24       4      72.0%
Random(X)  vs Heuristic(O)                    4      25      71       4.0%
```

Minimax has **zero losses** in every matchup. GPT-4o plays at roughly
heuristic level — legal and threat-aware but unable to set up multi-move
forks. Full analysis: [`REMOTE_AND_AI.md`](REMOTE_AND_AI.md)

---

## API Key Setup

```matlab
% Copy the template, add your key, it never gets pushed
copyfile('config.example.m', 'config.m')
```

`config.m` is in `.gitignore` — it stays on your machine only.
Used by `strategy_chatgpt.m` and the app's optional ChatGPT mode.

---

## Dependencies

| Dependency | Required for |
|---|---|
| MATLAB R2022b+ | Everything |
| [Robotics Toolbox for MATLAB](https://petercorke.com/toolboxes/robotics-toolbox/) (Peter Corke) | Robot model, IK, FK |
| MATLAB Support Package for Arduino Hardware | Servo control |
| MATLAB Robotics System Toolbox (ROS2 support) | Remote ROS2 gameplay |
| ROS2 Humble+ | Remote ROS2 gameplay |

---

## Author

**Yusuf Guenena** | M.S. Robotics Engineering, Wayne State University
[LinkedIn](https://www.linkedin.com/in/yusuf-guenena) · [GitHub](https://github.com/yusufdxb)
