# TicTacToe 3-Link Drawing Robot 🤖

A 2-DOF serial robot arm controlled via **Arduino** and **MATLAB** that plays
**Tic Tac Toe** autonomously — physically drawing the grid, X's, and O's on
paper using a pen servo, while running a **Minimax AI** to compete against a
human opponent.

[![Demo Video](https://img.shields.io/badge/▶_Watch_Demo-YouTube-red)](YOUR_YOUTUBE_LINK_HERE)
![MATLAB](https://img.shields.io/badge/MATLAB-R2022b+-orange)
![Arduino](https://img.shields.io/badge/Arduino-Uno-teal)
![License](https://img.shields.io/badge/License-MIT-green)

---

## 📹 Demo

> **[Watch the full demo here](YOUR_YOUTUBE_LINK_HERE)**
> *(Replace with your YouTube URL when ready)*

---

## What This Project Does

This project combines **robotics**, **embedded systems**, and **AI**:

1. A 2-joint robot arm is controlled by servo motors via Arduino Uno
2. A third servo operates a rack-and-pinion **pen mechanism** (up/down)
3. MATLAB computes **closed-form planar inverse kinematics** to move the
   end-effector to any XY position on the drawing surface
4. A **Minimax AI** plays optimally — it never loses
5. Human clicks a square in the GUI → robot physically draws an **X**
6. AI selects the best response → robot draws an **O**
7. Game continues until win or draw

```
Human clicks square in GUI
        ↓
IK computed → servo motion → X drawn on paper
        ↓
Minimax AI selects optimal move
        ↓
IK computed → servo motion → O drawn on paper
        ↓
Win / Draw check → repeat or end
```

---

## Hardware

| Component | Details |
|---|---|
| Robot arm | 2-DOF serial link (planar) |
| Link 1 length | 110 mm |
| Link 2 length | 104 mm |
| Base offset | X: −29 mm, Y: 121 mm, Z: 77 mm |
| Microcontroller | Arduino Uno |
| Joint 1 servo | Pin D3 |
| Joint 2 servo | Pin D5 |
| Pen servo | Pin D6 (rack and pinion) |

---

## File Structure

```
TicTacToe-3link-robot/
├── TicTacToe_App.mlapp      ← GUI — open in MATLAB App Designer
├── twolink_App.m            ← Full app class (all callbacks)
├── robot_kinematics.m       ← Planar IK, FK, servo calibration
├── drawing_functions.m      ← drawGrid, drawX, drawO, pen control
├── tictactoe_game.m         ← Minimax AI + board logic
├── main.m                   ← Terminal game loop (no GUI needed)
├── test_robot.m             ← Hardware verification script
├── config.example.m         ← API key template (copy → config.m)
├── .gitignore               ← Keeps config.m (secrets) off GitHub
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

## API Key Setup

**Never hardcode API keys.** This repo uses a local config file that is
excluded from Git:

```matlab
% 1. Copy the template
copyfile('config.example.m', 'config.m')

% 2. Open config.m and paste your key
% 3. config.m is in .gitignore — never pushed to GitHub
```

---

## Kinematics

Closed-form 2-DOF planar IK:

```
c₂ = (r² − a₁² − a₂²) / (2·a₁·a₂)
θ₂ = atan2(±√(1−c₂²), c₂)
θ₁ = atan2(y,x) − atan2(a₂·sin(θ₂), a₁ + a₂·cos(θ₂))
```

Both elbow-up and elbow-down solutions are computed — the one closest
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

---

## Dependencies

- MATLAB R2022b+
- [Robotics Toolbox for MATLAB](https://petercorke.com/toolboxes/robotics-toolbox/) (Peter Corke)
- MATLAB Support Package for Arduino Hardware

---

## Author

**Yusuf Guenena** | M.S. Robotics Engineering, Wayne State University
[LinkedIn](https://www.linkedin.com/in/yusuf-guenena) · [GitHub](https://github.com/yusufdxb)
