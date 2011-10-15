#!/usr/bin/env python
import sys, textwrap

if len(sys.argv) < 4:
    print "Usage: %s <ROM file> <JS file> <variable name>" % sys.argv[0]
    sys.exit(1)

with file(sys.argv[1], 'rb') as ifile:
    rom = ifile.read()
    chars = ', '.join('0x%02x' % ord(byte) for byte in rom)
    output = textwrap.wrap(chars, 76)

with file(sys.argv[2], 'w') as ofile:
    ofile.write('%s = new Uint8Array([\n' % sys.argv[3])
    ofile.write('\n'.join(output))
    ofile.write(']);\n')
