# TicTacToe 3-Link Robot (RRP) 🤖

A **3-link robot arm** (2 revolute + 1 prismatic) controlled via **Arduino** and **MATLAB**
that plays **Tic Tac Toe** autonomously — physically drawing the grid, X's, and O's on
paper, while running a **Minimax AI** to compete against a human opponent.

[![Demo Video](https://img.shields.io/badge/▶_Watch_Demo-YouTube-red)](YOUR_YOUTUBE_LINK_HERE)
![MATLAB](https://img.shields.io/badge/MATLAB-R2022b+-orange)
![Arduino](https://img.shields.io/badge/Arduino-Uno-teal)
![License](https://img.shields.io/badge/License-MIT-green)

---

## 📹 Demo

> **[Watch the full demo here](YOUR_YOUTUBE_LINK_HERE)**


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

---

## API Key Setup

```matlab
% Copy the template, add your key, it never gets pushed
copyfile('config.example.m', 'config.m')
```

`config.m` is in `.gitignore` — it stays on your machine only.

---

## Dependencies

- MATLAB R2022b+
- [Robotics Toolbox for MATLAB](https://petercorke.com/toolboxes/robotics-toolbox/) (Peter Corke)
- MATLAB Support Package for Arduino Hardware

---

## Author

**Yusuf Guenena** | M.S. Robotics Engineering, Wayne State University
[LinkedIn](https://www.linkedin.com/in/yusuf-guenena) · [GitHub](https://github.com/yusufdxb)
