"""Plot actual solver snapshots and traces; no generated or hand-authored sail shapes."""
from pathlib import Path
import json
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

root = Path(__file__).resolve().parents[1]
data = json.loads((root / "docs/realism/fore-sail-cycle.json").read_text())
fig = plt.figure(figsize=(16, 7), facecolor="#f3f2ec")
labels = ["Calm", "Gust · 8 m/s", "Lull", "Backwind · −8 m/s", "Sheets released"]
triangles = np.array(data["triangles"]).reshape(-1, 3)
for i, (snapshot, label) in enumerate(zip(data["snapshots"], labels)):
    ax = fig.add_subplot(2, 5, i + 1, projection="3d", computed_zorder=False)
    ax.set_facecolor("#f3f2ec")
    vertices = np.array(snapshot["points_m"])[:, [0, 2, 1]]
    ax.add_collection3d(Poly3DCollection(vertices[triangles], facecolors="#c4af7f",
        edgecolors="#78694b", linewidths=.4, alpha=.95, zorder=3))
    ax.plot([-2.75, 2.75], [0, 0], [0, 0], color="#58442e", lw=3, zorder=4)
    angle, height = np.meshgrid(np.linspace(0, 2*np.pi, 24), [-3.2, -.4])
    ax.plot_surface(.18*np.cos(angle), .6+.18*np.sin(angle), height,
                    color="#9ca1a4", alpha=.6, zorder=2)
    ax.set(xlim=(-3, 3), ylim=(-2, 2), zlim=(-3.7, .1), title=label)
    ax.view_init(elev=15, azim=-55)
    ax.set_box_aspect((6, 4, 3.8))
    ax.set_axis_off()
    ax.text2D(.05, .02, f'{snapshot["seconds"]:.0f} s', transform=ax.transAxes, color="#4b5660")
time = np.array([row["seconds"] for row in data["trace"]])
ax = fig.add_axes([.07, .16, .35, .32], facecolor="#f3f2ec")
ax.plot(time, [row["mean_free_depth_m"] for row in data["trace"]],
        color="#2a766e", lw=2, label="Solved depth (m)")
ax.axhline(0, color="#abb1ad", lw=.8)
ax.set(xlabel="Simulated seconds", ylabel="Mean free-node depth (m)")
ax.spines[["top", "right"]].set_visible(False)
wind = ax.twinx()
wind.plot(time, [row["wind_z_mps"] for row in data["trace"]],
          color="#7595ac", lw=1.2, ls="--", label="Wind (m/s)")
wind.set_ylabel("Normal wind (m/s)", color="#597b93")
wind.spines["top"].set_visible(False)
ax.legend(loc="upper left", frameon=False)
wind.legend(loc="upper right", frameon=False)
ax = fig.add_axes([.56, .16, .38, .32], facecolor="#f3f2ec")
loads = np.array([row["sheet_tensions_n"] for row in data["trace"]])
ax.plot(time, loads[:, 0], color="#9a643d", lw=2, label="Port sheet")
ax.plot(time, loads[:, 1], color="#4a5d81", lw=1.2, ls="--", label="Starboard sheet")
ax.axvline(25, color="#89918b", ls=":", lw=1)
ax.text(25.2, 70, "Free tails", fontsize=9)
ax.set(xlabel="Simulated seconds", ylabel="Sheet tension (N)")
ax.spines[["top", "right"]].set_visible(False)
ax.legend(frameon=False, loc="upper left")
fig.suptitle("Fore-sail behavior: one reproducible physics fixture", x=.04,
             ha="left", y=.98, fontsize=18, fontweight="bold", color="#263730")
fig.text(.04, .91, "Solved particle geometry, gravity on, fixed head, one frictionless spar. "
         "Provisional fabric; no self-contact or calibrated luffing.", fontsize=10, color="#59635e")
fig.text(.04, .02, "Diagnostic geometry • 35 nodes / 48 panels • 60 Hz outer tick • "
         "not an in-game screenshot or a training-validation result", fontsize=9, color="#59635e")
fig.subplots_adjust(left=.06, right=.94, bottom=.13, top=.87, wspace=.1, hspace=.2)
fig.savefig(root / "docs/realism/fore-sail-cycle.png", dpi=130, facecolor=fig.get_facecolor())
