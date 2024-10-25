ASM=nasm
CC=gcc

SRC_DIR=src
TOOLS_DIR=tools
BUILD_DIR=build

MAKE_DISK_SIZE = 16777216 #16MB 

export BUILD_DIR

.PHONY: all floppy_image kernel bootloader clean always tools_fat disk_image

all: floppy_image tools_fat 



#
#Floppy image
#
floppy_image: $(BUILD_DIR)/main_floppy.img 

$(BUILD_DIR)/main_floppy.img: bootloader S2Entry
	./build_scripts/make_floppy_image.sh $@
	echo "--> Created:  " $@


#
#Disk image
#
disk_image: $(BUILD_DIR)/main_disk.raw 

$(BUILD_DIR)/main_disk.raw: bootloader S2Entry
	./build_scripts/make_disk_image.sh $@ $(MAKE_DISK_SIZE)
	echo "--> Created:  " $@



#
#Bootloader
#
bootloader: $(BUILD_DIR)/bootloader.bin


$(BUILD_DIR)/bootloader.bin: always
	$(ASM) $(SRC_DIR)/bootloader/boot.asm -f bin -o $(BUILD_DIR)/bootloader.bin
#
#Kernel
#
kernal: $(BUILD_DIR)/kernel.bin

$(BUILD_DIR)/kernel.bin: always
	$(ASM) $(SRC_DIR)/kernel/main.asm -f bin -o $(BUILD_DIR)/kernel.bin

#
#Stage 2 Entry
#
S2Entry: $(BUILD_DIR)/entry.bin

$(BUILD_DIR)/entry.bin: always
	$(ASM) $(SRC_DIR)/bootloader/stage2/entry.asm -f bin -o $(BUILD_DIR)/stage2.bin

#
# Tools
#
tools_fat: $(BUILD_DIR)/tools/fat

$(BUILD_DIR)/tools/fat: always $(TOOLS_DIR)/fat/fat.c
	mkdir -p $(BUILD_DIR)/tools
	$(CC) -g -o $(BUILD_DIR)/tools/fat $(TOOLS_DIR)/fat/fat.c



#
#Always
#
always:
	mkdir -p $(BUILD_DIR)

#
#clean
#
clean:
	rm -rf $(BUILD_DIR)
