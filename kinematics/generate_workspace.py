#!/usr/bin/env python3
"""
generate_workspace.py — Reachable Workspace Visualization for RRP Robot
=======================================================================
Python equivalent of workspace_plot.m. Generates a 2D reachable workspace
plot for the 2-DOF planar arm (J1+J2) and saves workspace.png.

Robot parameters (from robot_kinematics.m):
  Link 1: 110 mm  (J1 -> J2)
  Link 2: 104 mm  (J2 -> EE)
  Base offset: X = -29 mm, Y = 121 mm

Run from repo root:
  python3 kinematics/generate_workspace.py

Outputs:
  kinematics/workspace.png

Dependencies:
  pip install matplotlib numpy scipy
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np

try:
    import matplotlib
    matplotlib.use("Agg")  # headless — no display required
    import matplotlib.pyplot as plt
    import matplotlib.patches as mpatches
    from scipy.spatial import ConvexHull
except ImportError as e:
    print(f"Missing dependency: {e}")
    print("Install with: pip install matplotlib numpy scipy")
    sys.exit(1)

# ── Robot parameters (from robot_kinematics.m) ──────────────────────────────
L1 = 110.0    # mm — link 1 length (J1 → J2)
L2 = 104.0    # mm — link 2 length (J2 → EE)
BASE_X = -29.0   # mm — base frame X offset
BASE_Y = 121.0   # mm — base frame Y offset

# Joint limits (mechanical, from workspace_plot.m)
THETA1_MIN, THETA1_MAX = 0.0, 180.0   # degrees
THETA2_MIN, THETA2_MAX = 0.0, 180.0   # degrees

# TicTacToe grid (from robot_kinematics.m, grid_center ≈ (80, 150) mm)
GRID_CENTER_X = 80.0
GRID_CENTER_Y = 150.0
CELL_SIZE = 30.0  # mm


def compute_reachable_workspace(n_steps: int = 360) -> tuple[np.ndarray, np.ndarray]:
    """Sweep all valid joint configurations, compute EE world positions."""
    theta1_vals = np.linspace(np.radians(THETA1_MIN), np.radians(THETA1_MAX), n_steps)
    theta2_vals = np.linspace(np.radians(THETA2_MIN), np.radians(THETA2_MAX), n_steps)

    t1, t2 = np.meshgrid(theta1_vals, theta2_vals)
    x = L1 * np.cos(t1) + L2 * np.cos(t1 + t2) + BASE_X
    y = L1 * np.sin(t1) + L2 * np.sin(t1 + t2) + BASE_Y

    return x.ravel(), y.ravel()


def grid_squares() -> tuple[list[float], list[float]]:
    """Return world-frame (x, y) of all 9 TicTacToe grid squares."""
    xs, ys = [], []
    idx = 1
    for row in range(-1, 2):
        for col in range(-1, 2):
            xs.append(GRID_CENTER_X + col * CELL_SIZE)
            ys.append(GRID_CENTER_Y + row * CELL_SIZE)
            idx += 1
    return xs, ys


def check_reachability(gx: list[float], gy: list[float]) -> list[bool]:
    """Check each grid square against the annular reachable region."""
    r_max = L1 + L2
    r_min = abs(L1 - L2)
    reachable = []
    for x, y in zip(gx, gy):
        dx, dy = x - BASE_X, y - BASE_Y
        r = math.sqrt(dx ** 2 + dy ** 2)
        reachable.append(r_min <= r <= r_max)
    return reachable


def plot_workspace(out_path: Path) -> None:
    rx, ry = compute_reachable_workspace(n_steps=360)
    gx, gy = grid_squares()
    reachable = check_reachability(gx, gy)

    r_max = L1 + L2   # 214 mm
    r_min = abs(L1 - L2)  # 6 mm

    fig, ax = plt.subplots(figsize=(7, 7))
    fig.patch.set_facecolor("white")

    # ── Reachable workspace scatter ──────────────────────────────────────────
    ax.scatter(rx, ry, s=1, c="#b3d1f7", alpha=0.5, linewidths=0, label="Reachable workspace")

    # ── Convex hull boundary ─────────────────────────────────────────────────
    pts = np.column_stack([rx, ry])
    try:
        hull = ConvexHull(pts)
        hull_pts = pts[np.append(hull.vertices, hull.vertices[0])]
        ax.plot(hull_pts[:, 0], hull_pts[:, 1], "b-", linewidth=1.5,
                label="Workspace boundary")
    except Exception:
        pass

    # ── Max/min reach circles ────────────────────────────────────────────────
    theta_c = np.linspace(0, 2 * math.pi, 360)
    ax.plot(BASE_X + r_max * np.cos(theta_c), BASE_Y + r_max * np.sin(theta_c),
            "k--", linewidth=0.8, alpha=0.4, label=f"Max reach ({r_max:.0f} mm)")
    ax.plot(BASE_X + r_min * np.cos(theta_c), BASE_Y + r_min * np.sin(theta_c),
            "k:", linewidth=0.8, alpha=0.4, label=f"Min reach ({r_min:.0f} mm)")

    # ── Base ─────────────────────────────────────────────────────────────────
    ax.plot(BASE_X, BASE_Y, "ks", markersize=10, markerfacecolor="k",
            label="Robot base")

    # ── Grid squares ─────────────────────────────────────────────────────────
    colors = ["#e04040" if not r else "#28a745" for r in reachable]
    ax.scatter(gx, gy, s=120, c=colors, zorder=5, label="Grid squares")
    for i, (x, y) in enumerate(zip(gx, gy), start=1):
        ax.text(x + 3, y + 3, str(i), fontsize=8,
                color="#28a745" if reachable[i - 1] else "#e04040")

    # ── Labels & formatting ──────────────────────────────────────────────────
    ax.set_xlabel("X (mm)", fontsize=11)
    ax.set_ylabel("Y (mm)", fontsize=11)
    ax.set_title(
        f"RRP Robot — Reachable Workspace\n"
        f"L1={L1:.0f} mm, L2={L2:.0f} mm, Base=({BASE_X:.0f},{BASE_Y:.0f} mm)",
        fontsize=12,
    )
    ax.legend(loc="upper left", fontsize=8)
    ax.set_aspect("equal")
    ax.grid(True, alpha=0.3)
    ax.set_xlim(-250, 250)
    ax.set_ylim(-50, 350)

    n_reachable = sum(reachable)
    ax.text(
        0.98, 0.04,
        f"Max reach: {r_max:.0f} mm\nMin reach: {r_min:.0f} mm\n"
        f"Grid reachable: {n_reachable}/9",
        transform=ax.transAxes,
        ha="right", va="bottom", fontsize=8,
        bbox=dict(boxstyle="round,pad=0.3", facecolor="white", edgecolor="gray"),
    )

    fig.tight_layout()
    fig.savefig(str(out_path), dpi=150)
    plt.close(fig)

    print(f"Workspace plot saved: {out_path}")
    print(f"Max reach: {r_max:.0f} mm")
    print(f"Min reach: {r_min:.0f} mm")
    print(f"\nGrid square reachability ({n_reachable}/9 in workspace):")
    labels = [f"({gx[i]:.0f},{gy[i]:.0f})" for i in range(9)]
    for i, (label, ok) in enumerate(zip(labels, reachable), start=1):
        status = "reachable" if ok else "OUT OF REACH"
        print(f"  Square {i} {label} mm: {status}")


if __name__ == "__main__":
    out_path = Path(__file__).parent / "workspace.png"
    plot_workspace(out_path)
