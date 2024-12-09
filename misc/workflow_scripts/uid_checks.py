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
                # Make sure it starts with xrt2 and cap to 7 extra digits to prevent overflows
                fix = "uid://xrt2" + uid[10:17]

                # Mark 9 and z as ? so they stand out, they shouldn't be used (see Godot GH-83843)
                fix = fix.replace("9", "?")
                fix = fix.replace("z", "?")

                # And update
                line = line.replace(uid, fix)

            text += line
            line = fileread.readline()

    # Write
    with open(fname.strip(), "w", encoding="utf-8", newline="\n") as filewrite:
        filewrite.write(text)
