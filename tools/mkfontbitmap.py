#!/usr/bin/env python
import sys
from PIL import Image

if len(sys.argv) < 3:
    print "Usage: %s <font file> <bitmap file>" % sys.argv[0]
    sys.exit(1)

bitmaps = []
with file(sys.argv[1], 'r') as input_file:
    in_bitmap = False
    for line in input_file:
        line = line.strip()
        if in_bitmap:
            if line == 'ENDCHAR':
                bitmaps.append((code_point, bitmap))
                in_bitmap = False
            else:
                bits = int(line, 16)
                pixels = [bits & 1 << b for b in range(15, 3, -1)]
                bitmap.append(pixels)
        else:
            words = line.split()
            if words[0] == 'ENCODING':
                code_point = int(words[1])
            elif words[0] == 'BITMAP':
                in_bitmap = True
                bitmap = []

palette = [
    0, 0, 0,
    255, 0, 0,
    0, 255, 0,
    255, 255, 0,
    0, 0, 255,
    255, 0, 255,
    0, 255, 255,
    255, 255, 255
]
image = Image.new('P', (12*256, 19*7), 0)
image.putpalette(palette)
for code_point, bitmap in bitmaps:
    for line in range(0, 19):
        for pixel in range(0, 12):
            for colour in range(1, 8):
                image.putpixel(
                    (code_point*12 + pixel, (colour-1)*19 + line),
                    colour if bitmap[line][pixel] else 0
                )
image.save(sys.argv[2], transparency=0, optimize=True)
