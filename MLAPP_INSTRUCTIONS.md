## About TicTacToe_App.mlapp

The GUI file (`TicTacToe_App.mlapp`) is a MATLAB App Designer file.

### How to add it to this repo

The `.mlapp` file is not included here because it must be saved directly
from MATLAB App Designer. To add it:

1. Open MATLAB App Designer
2. Open your existing `.mlapp` file
3. Save it into this repo folder
4. Then run:

```bash
git add TicTacToe_App.mlapp
git commit -m "Add App Designer GUI"
git push origin main
```

### What is a .mlapp file?

A `.mlapp` is a ZIP archive containing XML. GitHub renders it as a
binary file — you won't see syntax highlighting, but it uploads, downloads,
and versions correctly just like any other file.

To open it from GitHub: clone the repo, then double-click the `.mlapp`
file in MATLAB's file browser — App Designer opens it automatically.

### Running without the GUI

Use `main.m` for a terminal-based game loop — no GUI required.
