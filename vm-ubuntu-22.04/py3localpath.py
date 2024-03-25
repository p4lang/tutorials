#! /usr/bin/env python3

import re
import sys

l1=[x for x in sys.path if re.match(r'/usr/local/lib/python3.[0-9]+/dist-packages', x)]

if len(l1) == 1:
    py3distdir = l1[0]
    m = re.match(r'(/usr/local/lib/python3.[0-9]+)/dist-packages', l1[0])
    if m:
        print(m.group(1))
    else:
        print("Inconceivable!  Somehow the second pattern did not match but the first did.")
        sys.exit(1)
else:
    print("Found %d matching entries in Python3 sys.path instead of 1: %s"
          % (len(l1), l1))
    sys.exit(1)

sys.exit(0)
