# Setup Guide — TicTacToe 3-Link Robot

Complete instructions for getting the TicTacToe robot running, from dependency installation to first game.

---

## Requirements

- MATLAB R2022b or later
- [Robotics Toolbox for MATLAB](https://petercorke.com/toolboxes/robotics-toolbox/) (Peter Corke)
- MATLAB Support Package for Arduino Hardware
- Arduino Uno (or compatible) with servos wired per the hardware docs

---

## 1. Install MATLAB Dependencies

### Robotics Toolbox
In MATLAB:
```matlab
% Option A — MATLAB Add-On Explorer (recommended)
% Home → Add-Ons → Get Add-Ons → search "Robotics Toolbox Peter Corke"

% Option B — Command line
websave('rvctools.zip', 'https://petercorke.com/download/rvctools.zip');
unzip('rvctools.zip');
addpath(genpath('rvctools'));
savepath;
```

### Arduino Support Package
```
Home → Add-Ons → Get Hardware Support Packages → MATLAB Support Package for Arduino Hardware
```

---

## 2. Clone the Repository

```bash
git clone https://github.com/yusufdxb/TicTacToe-3link-robot.git
cd TicTacToe-3link-robot
```

---

## 3. Configure API Key (Optional — for ChatGPT opponent)

```matlab
% Copy the template
copyfile('config.example.m', 'config.m')
```

Open `config.m` and add your OpenAI API key. This file is in `.gitignore` and will never be committed.

---

## 4. Upload Arduino Firmware

1. Open Arduino IDE
2. Open the firmware sketch from `hardware/firmware/` (if available)
3. Select your board: **Tools → Board → Arduino Uno**
4. Select your port: **Tools → Port → COMx** (Windows) or `/dev/ttyUSBx` (Linux)
5. Upload

---

## 5. Run the Application

### GUI Mode (recommended)
```matlab
% In MATLAB, open the App Designer project
open('TicTacToe_App.mlapp')
% Click Run in the App Designer toolbar
```

Then in the GUI:
1. **Arduino menu → Connect** — enter your COM port
2. **Arduino menu → Connect Motor**
3. Click **Create Robot**
4. Click **New Game**
5. Click any square to make your move — the robot draws on paper

### Terminal Mode (no GUI)
```matlab
main
```

### Hardware Verification
Run this first to confirm servo connections are correct:
```matlab
test_robot
```

---

## 6. Hardware Wiring

| Joint | Servo | Arduino Pin |
|---|---|---|
| J1 (base rotation) | MG996R | D3 |
| J2 (elbow) | MG996R | D5 |
| J3 (pen up/down) | MG996R | D6 |

Refer to `hardware/` for full wiring diagrams and mechanical assembly.

---

## Troubleshooting

**"Cannot connect to Arduino"**
- Confirm the correct COM port in Device Manager (Windows) or `ls /dev/ttyUSB*` (Linux)
- Try unplugging and replugging the USB cable
- Ensure no other application (e.g. Arduino IDE Serial Monitor) is using the port

**Pen not reaching paper**
- Adjust the `PEN_DOWN` servo position constant in `robot_kinematics.m`
- Recalibrate the base offset values for your specific print surface height

**Robot moves to wrong squares**
- Re-run `test_robot.m` to verify joint calibration
- Check that link length constants in `robot_kinematics.m` match your physical build
