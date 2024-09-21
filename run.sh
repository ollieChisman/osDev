#!/bin/bash

echo "Running Floppy Disk!"
qemu-system-i386 -fda build/main_floppy.img
