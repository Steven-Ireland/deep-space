"""Contact sheets and close-ups of screenshots and renders, for reviewing by eye (Blender's Python
has numpy; the system Python has no PIL):

    Blender -b --factory-startup -P tools/sheet.py -- tile <out.png> <columns> <in.png>... [--half]
    Blender -b --factory-startup -P tools/sheet.py -- crop <in.png> <out.png> <x> <y> <w> <h> [scale]

`tile` lays images out left to right, top to bottom, in cells the size of the largest, on black
(`--half` shrinks each by half first). `crop` cuts a w x h box from x, y (pixels from the top left)
and enlarges it `scale` times (default 2), unsmoothed, so the PSX pixels stay crisp.
"""

import sys

import bpy
import numpy as np


def load(path):
    """An image's pixels, top row first: (height, width, 4) floats."""
    image = bpy.data.images.load(path)
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    return pixels.reshape(height, width, 4)[::-1]


def save(pixels, path):
    height, width, _ = pixels.shape
    image = bpy.data.images.new("sheet", width, height, alpha=True)
    image.pixels.foreach_set(np.ascontiguousarray(pixels[::-1]).ravel())
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    print(f"Sheet: {path}")


def tile(out, columns, paths, half=False):
    tiles = [load(p) for p in paths]
    if half:
        tiles = [t[::2, ::2] for t in tiles]
    height, width = max(t.shape[0] for t in tiles), max(t.shape[1] for t in tiles)
    tiles = [np.pad(t, ((0, height - t.shape[0]), (0, width - t.shape[1]), (0, 0))) for t in tiles]
    blank = np.zeros_like(tiles[0])
    rows = []
    for start in range(0, len(tiles), columns):
        row = tiles[start:start + columns]
        rows.append(np.concatenate(row + [blank] * (columns - len(row)), axis=1))
    sheet = np.concatenate(rows, axis=0)
    sheet[..., 3] = 1.0
    save(sheet, out)


def crop(source, out, x, y, width, height, scale=2):
    pixels = load(source)[y:y + height, x:x + width]
    save(pixels.repeat(scale, axis=0).repeat(scale, axis=1), out)


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    half = "--half" in args
    args = [a for a in args if a != "--half"]
    if args[0] == "tile":
        tile(args[1], int(args[2]), args[3:], half)
    elif args[0] == "crop":
        crop(args[1], args[2], *(int(v) for v in args[3:8]))
    else:
        sys.exit(__doc__)


main()
