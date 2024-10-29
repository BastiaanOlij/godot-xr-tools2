#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys
import re

if len(sys.argv) < 2:
    print("Invalid usage of copyright_headers.py, it should be called with a path to one or multiple files.")
    sys.exit(1)

for f in sys.argv[1:]:
    fname = f
    text = ""

    pattern = re.compile(r'uid://[0-9a-z]+')

    with open(fname.strip(), "r", encoding="utf-8") as fileread:
        line = fileread.readline()

        while line != "":  # Dump everything until EOF
            for (uid) in re.findall(pattern, line):
             fix = "uid://xrt2" + uid[10:18]
             line = line.replace(uid, fix)

            text += line
            line = fileread.readline()

    # Write
    with open(fname.strip(), "w", encoding="utf-8", newline="\n") as filewrite:
        filewrite.write(text)
