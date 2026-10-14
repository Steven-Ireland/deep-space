"""Prints the bone turns a rig's clip keys at a moment, in degrees (and moves, in metres), for
checking a solved pose's numbers (characters.py prints its solves as it builds, too):

    Blender -b art/source/ch_arms.blend -P tools/clip_angles.py -- <clip> [t]

`t` is 0..1 through the clip (default 0).
"""

import math
import sys

import bpy
from bpy_extras import anim_utils


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    name, t = args[0], float(args[1]) if len(args) > 1 else 0.0
    action = bpy.data.actions.get(name) or bpy.data.actions.get(name + "-loop")
    if action is None:
        sys.exit(f"No clip {name}: {', '.join(a.name for a in bpy.data.actions)}")
    if hasattr(action, "fcurves") and len(action.fcurves):
        curves = list(action.fcurves)
    else:
        curves = [c for slot in action.slots for c in anim_utils.action_get_channelbag_for_slot(action, slot).fcurves]
    start, end = action.frame_range
    frame = start + t * (end - start)
    bones = {}
    for curve in curves:
        bone = curve.data_path.split('"')[1]
        channel = curve.data_path.rsplit(".", 1)[-1]
        bones.setdefault(bone, {}).setdefault(channel, [0.0, 0.0, 0.0])[curve.array_index] = curve.evaluate(frame)
    for bone, channels in bones.items():
        turn = channels.get("rotation_euler")
        move = channels.get("location")
        line = f"{bone:14}"
        if turn is not None:
            line += " turn (" + ", ".join(f"{math.degrees(a):7.2f}" for a in turn) + ")"
        if move is not None and any(abs(v) > 1e-5 for v in move):
            line += " move (" + ", ".join(f"{v:6.3f}" for v in move) + ")"
        print(line)


main()
