# TicTacToe 3-Link Robot

> Physical 3-DOF robot arm that draws and plays TicTacToe on paper.

This project combines a simple mechatronic platform, closed-form planar inverse kinematics, MATLAB control tooling, and Arduino actuation. Its value is that it is a real physical robot project, not that it is a high-end manipulation benchmark.

## What The Project Demonstrates

- closed-form IK for a planar 2R arm with a pen up/down mechanism
- calibration from joint angles to servo commands
- game logic integration through a Minimax agent
- physical execution of a turn-based task through a GUI and embedded controller

## Robot Configuration

| Joint | Type | Function |
|---|---|---|
| J1 | revolute | first planar shoulder joint |
| J2 | revolute | second planar elbow joint |
| J3 | prismatic-style pen actuation | pen down / pen up |

## Hardware and Software Split

| Layer | Implementation |
|---|---|
| Control GUI | MATLAB App Designer |
| Kinematics | MATLAB scripts |
| Game logic | MATLAB Minimax implementation |
| Actuation | Arduino + servos |

## Core Files

| File | Role |
|---|---|
| `robot_kinematics.m` | IK, FK, limits, calibration helpers |
| `drawing_functions.m` | grid and move drawing routines |
| `tictactoe_game.m` | game state and Minimax logic |
| `twolink_App.m` | main app logic |
| `test_robot.m` | hardware verification helper |

## Kinematics

The arm uses closed-form planar IK for the two revolute joints. The drawing mechanism is then handled separately through the pen actuator.

```text
board coordinate --> planar IK --> servo targets --> pen down/up --> mark drawn on paper
```

## Validation Scaffold

Measurement plan for repeatability and calibration checks:

See: [docs/VALIDATION.md](docs/VALIDATION.md)

First metrics to add:
- cell placement error
- repeated-move deviation
- calibration drift over a session
- move duration per mark

## Quick Start

### GUI path
```matlab
% Open TicTacToe_App.mlapp in App Designer and run the app
```

### Script path
```matlab
main
```

### Hardware check
```matlab
test_robot
```

## Dependencies

- MATLAB R2022b+
- Robotics Toolbox for MATLAB
- MATLAB Support Package for Arduino Hardware
