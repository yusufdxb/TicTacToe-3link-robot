# ROS2 Topic Reference — TicTacToe Robot

All topics use `std_msgs/String`. Message encoding is documented below.

## Topic List

| Topic | Direction | Publisher | Subscriber | Encoding |
|-------|-----------|-----------|------------|----------|
| `/tictactoe/human_move` | remote → robot | remote player | robot node | `"1"` – `"9"` |
| `/tictactoe/robot_move` | robot → remote | robot node | remote player | `"1"` – `"9"` |
| `/tictactoe/game_state` | robot → remote | robot node | remote player | 9-char board string |
| `/tictactoe/status` | robot → remote | robot node | remote player | status keyword |
| `/tictactoe/command` | remote → robot | remote player | robot node | command keyword |

---

## Message Encoding

### `/tictactoe/human_move` and `/tictactoe/robot_move`

A single ASCII digit `"1"` through `"9"` representing the square played.

Square numbering (left-to-right, top-to-bottom):

```
1 | 2 | 3
4 | 5 | 6
7 | 8 | 9
```

### `/tictactoe/game_state`

A 9-character string of `'0'`, `'1'`, `'2'` in row-major order.

- `0` = empty
- `1` = human (X)
- `2` = robot (O)

Example: `"010020000"` means:

```
. X .
. O .
. . .
```

### `/tictactoe/status`

| Value | Meaning |
|-------|---------|
| `"idle"` | Node started, no game active |
| `"waiting"` | Ready for human move |
| `"robot_turn"` | Robot is computing or drawing |
| `"human_wins"` | Game over — human won |
| `"robot_wins"` | Game over — robot won |
| `"draw"` | Game over — draw |

### `/tictactoe/command`

| Value | Effect |
|-------|--------|
| `"new_game"` | Reset board, start a new game |
| `"draw_grid"` | Trigger physical grid drawing (robot-side only) |
| `"quit"` | Cleanly shut down the robot node loop |

---

## Verifying Topics on Either Machine

```bash
source /opt/ros/humble/setup.bash
export ROS_DOMAIN_ID=42

# List all active topics
ros2 topic list

# Watch game state updates
ros2 topic echo /tictactoe/game_state

# Watch status
ros2 topic echo /tictactoe/status

# Send a test move manually
ros2 topic pub --once /tictactoe/human_move std_msgs/String '{data: "5"}'

# Send new_game command
ros2 topic pub --once /tictactoe/command std_msgs/String '{data: "new_game"}'
```

---

## DDS / Network Notes

- Both machines must be on the **same network segment** (same Wi-Fi hotspot, same Ethernet switch, or same LAN).
- `ROS_DOMAIN_ID` must match on both machines (default `0` if not set — set to any integer, e.g. `42`).
- No ROS2 master node is needed (DDS peer discovery is automatic).
- If topics do not appear across machines, check firewall rules: ROS2 (CycloneDDS) uses UDP multicast on ports 7400-7500 by default.
- On hotspot: some hotspots block multicast. If discovery fails, set `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp` and use a unicast config (see `~/helix_ws/cyclonedds_loopback.xml` for reference).
