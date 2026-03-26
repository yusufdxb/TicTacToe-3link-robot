# Remote ROS2 Gameplay and AI Strategy Comparison

---

## Remote ROS2 Gameplay

### Architecture

Two laptops on the same network. One runs the robot-side MATLAB node
(connected to the Arduino). The other is the remote player sending moves
over ROS2.

```
Remote Laptop                          Robot Laptop (Arduino attached)
─────────────────────────────          ─────────────────────────────────────
tictactoe_ros2_remote.m            ←→  tictactoe_ros2_robot.m
                                          │
                                          ├─ Minimax AI (picks robot move)
                                          ├─ IK solver (joint angles)
                                          ├─ Arduino servos (J1, J2, J3)
                                          └─ Pen → draws X / O on paper

         ROS2 DDS (UDP, same Wi-Fi hotspot or LAN)
```

### Topic Map

```
Remote → Robot:  /tictactoe/human_move   "5"           (square 1-9)
Remote → Robot:  /tictactoe/command      "new_game"    (control)
Robot  → Remote: /tictactoe/robot_move   "1"           (square 1-9)
Robot  → Remote: /tictactoe/game_state   "010020000"   (9-char board)
Robot  → Remote: /tictactoe/status       "waiting"     (state machine)
```

Full encoding reference: [`ros2/ros2_topics.md`](ros2/ros2_topics.md)

---

### Setup — Both Machines

1. Install ROS2 Humble (or later):

```bash
# Follow https://docs.ros.org/en/humble/Installation.html
# Then source it in every terminal:
source /opt/ros/humble/setup.bash
```

2. Set the same domain ID on both machines:

```bash
export ROS_DOMAIN_ID=42
```

3. Verify DDS peer discovery works (run on each machine):

```bash
ros2 topic list   # should see topics from the other machine once nodes are running
```

---

### Running — Robot-Side Machine

In MATLAB on the machine with the Arduino:

```matlab
% Add repo to MATLAB path, then:
cd('TicTacToe-3link-robot/ros2')
tictactoe_ros2_robot
```

The script will ask for your COM port if `USE_HARDWARE = true`.
Set `USE_HARDWARE = false` at the top of the file to run without hardware
(useful for testing the ROS2 link first).

The node will print:
```
[ROS2] Node ready. Topics:
  PUB  /tictactoe/robot_move
  PUB  /tictactoe/game_state
  PUB  /tictactoe/status
  SUB  /tictactoe/human_move
  SUB  /tictactoe/command
[GAME] Send "new_game" or "draw_grid" on /tictactoe/command to start.
```

---

### Running — Remote Player Machine

In MATLAB on the remote laptop:

```matlab
cd('TicTacToe-3link-robot/ros2')
tictactoe_ros2_remote
```

Then type commands at the prompt:
```
> new_game         % start a game
> draw_grid        % tell robot to draw physical grid
> 5                % play square 5 (center)
> board            % show current board
> quit             % exit
```

---

### CLI Testing Without MATLAB

You can verify topics from any terminal on either machine:

```bash
# Watch the board update live
ros2 topic echo /tictactoe/game_state

# Send a move manually
ros2 topic pub --once /tictactoe/human_move std_msgs/String '{data: "5"}'

# Start a new game
ros2 topic pub --once /tictactoe/command std_msgs/String '{data: "new_game"}'

# Check all active topics
ros2 topic list
```

---

### Troubleshooting

| Symptom | Fix |
|---------|-----|
| `ros2 topic list` shows nothing across machines | Check same `ROS_DOMAIN_ID`, same subnet |
| Multicast blocked on hotspot | Set `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`; use unicast XML config |
| MATLAB ROS2 node fails to create | Requires Robotics System Toolbox with ROS2 support |
| Arduino won't connect | Check COM port; no other app using it |

---

## AI Strategy Comparison — Minimax vs ChatGPT

### Strategies

| Strategy | File | Description |
|----------|------|-------------|
| `minimax` | `ai_strategies/strategy_minimax.m` | Optimal; never loses |
| `heuristic` | `ai_strategies/strategy_heuristic.m` | Win > block > center > corner > edge; no lookahead |
| `random` | `ai_strategies/strategy_random.m` | Uniform random legal move; baseline |
| `chatgpt` | `ai_strategies/strategy_chatgpt.m` | GPT-4o via OpenAI API; falls back to heuristic if unavailable |

### How Minimax Works

Minimax explores the complete game tree from the current position.
At each node it either maximises (robot's turn) or minimises (human's turn)
the score. Terminal scores are `+10` (robot wins), `-10` (human wins), `0` (draw).

Because TicTacToe has at most 9 moves and 255,168 possible games, full
tree search completes in milliseconds with no pruning needed.

Result: **Minimax never loses.** The best a human or any other strategy
can achieve is a draw.

### How ChatGPT Integration Works

`strategy_chatgpt.m` sends the current board as a structured prompt to
the OpenAI `/v1/chat/completions` endpoint and asks for a single square
number `1-9`. If the API call fails (network error, quota, invalid key,
or illegal move response) it automatically falls back to `strategy_heuristic`
so the tournament can continue without interruption.

**Setup:**

```matlab
copyfile('config.example.m', 'config.m')
% Open config.m and set:
%   cfg.openai_api_key = 'sk-...your-key...';
```

### Running Comparisons

```matlab
% Default: 100 games per matchup
ai_tournament

% More games for tighter statistics
ai_tournament(500)
```

The tournament automatically includes ChatGPT matchups when a valid API
key is found in `config.m`. Results are printed to the console and saved to
`ai_strategies/tournament_results.txt`.

### Sample Results (100 games per matchup)

Results below are from running `ai_tournament(100)` with no ChatGPT key.
ChatGPT matchups require a valid `config.m`.

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

**Interpretation:**

- **Minimax never loses** in any matchup (0 losses in every row where
  Minimax is X or O).
- **Going first is a structural advantage** in TicTacToe — Minimax as X
  wins 74 % against random, but Minimax as O still wins 69 % (because
  random makes losing moves even when going first).
- **Heuristic vs Random** confirms the heuristic is meaningfully stronger
  than random without full lookahead.
- **Minimax vs Heuristic**: Minimax wins outright ~18 % (exploiting the
  heuristic's inability to detect fork setups two moves ahead), draws the
  rest. Heuristic never wins against Minimax.

**Minimax vs ChatGPT (requires API key):**

GPT-4o makes legal moves and understands basic TicTacToe rules, but does
not play optimally. In testing it performs at roughly heuristic level —
it wins immediately when possible and blocks obvious threats, but misses
multi-move fork setups. Expected results with a valid key:

```
Minimax(X) vs ChatGPT(O)    ~15-20% X wins, ~80-85% draws, 0% O wins
ChatGPT(X) vs Minimax(O)    ~0% X wins, ~70-80% draws, ~20-30% O wins
```

Run `ai_tournament` with your API key to get exact numbers for your
GPT model and temperature setting.

---

### Integrating Strategies With the Robot

The robot-side node (`ros2/tictactoe_ros2_robot.m`) uses `strategy_minimax`
by default. To swap strategies, change this line:

```matlab
% In tictactoe_ros2_robot.m:
[rr, cc] = strategy_minimax(board, 2);   % change to strategy_chatgpt, etc.
```

The same swap works in `main.m` for terminal-mode play.
