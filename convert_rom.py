#!/usr/bin/env python
import sys, textwrap

rom = file(sys.argv[1], 'rb').read()
chars = ', '.join('0x%02x' % ord(byte) for byte in rom)
output = textwrap.wrap(chars, 76)
file(sys.argv[2], 'w').write('\n'.join(output))
