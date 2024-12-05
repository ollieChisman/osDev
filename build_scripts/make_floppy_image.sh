#!/bin/bash

TARGET=$1

STAGE1_STAGE2_LOCATION_OFFSET=480

# generate image file
dd if=/dev/zero of=$TARGET bs=512 count=2880 >/dev/null

# determine how many reserved sectors
#STAGE2_SIZE=$(stat -c%s ${BUILD_DIR}/stage2.bin)
#echo ${STAGE2_SIZE}
#STAGE2_SECTORS=$(((${STAGE2_SIZE} + 511) / 512))
#echo ${STAGE2_SECTORS}
#RESERVED_SECTORS=$((1 + ${STAGE2_SECTORS}))
#echo ${RESERVED_SECTORS}

# create file system
#mkfs.fat -F 12 -R ${RESERVED_SECTORS} -n "NBOS" $TARGET >/dev/null

#install bootloader
dd if=${BUILD_DIR}/bootloader.bin of=$TARGET conv=notrunc bs=1 count=3 2>&1 >/dev/null
dd if=${BUILD_DIR}/bootloader.bin of=$TARGET conv=notrunc bs=1 seek=90 skip=90 2>&1 >/dev/null
dd if=${BUILD_DIR}/stage2.bin of=$TARGET conv=notrunc bs=512 seek=1

#write lba address of stage2 to the bootloader
#echo "01 00 00 00" | xxd -r -p | dd of=$TARGET conv=notrunc bs=1 seek=$STAGE1_STAGE2_LOCATION_OFFSET

#oh my god this was a hell of a lot of work for not much
#if [ ${STAGE2_SECTORS} -lt 16 ]; then
#    printf "0%x" ${STAGE2_SECTORS} | xxd -r -p | dd of=$TARGET conv=notrunc bs=1 seek=$(($STAGE1_STAGE2_LOCATION_OFFSET + 4))
#else
#    printf "%x" ${STAGE2_SECTORS} | xxd -r -p | dd of=$TARGET conv=notrunc bs=1 seek=$(($STAGE1_STAGE2_LOCATION_OFFSET + 4))
#fi

# copy files
#mcopy -i $TARGET test.txt "::test.txt"
