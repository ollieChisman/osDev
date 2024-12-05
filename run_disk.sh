#!/bin/bash

echo "Running Hard Disk!"
qemu-system-i386 -hda build/main_floppy.img
