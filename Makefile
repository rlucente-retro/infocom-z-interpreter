
SHELF = /Users/richardlucente/development/git/coco-shelf
LWASM = $(SHELF)/bin/lwasm
DECB = $(SHELF)/bin/decb
STORY = /Users/richardlucente/development/emulator/frotz/ZORK1.DAT

all: zork1.dsk

cocozip.bin: COCOZIP.ASM *.ASM
	$(LWASM) -f raw -o cocozip.bin COCOZIP.ASM
	# Pad to exactly 23 sectors ($1700 bytes) to match original expectations
	printf "\0%.0s" {1..64} >> cocozip.bin

boot.bin: BOOT.ASM
	$(LWASM) -f raw -o boot.bin BOOT.ASM

zork1.dsk: cocozip.bin boot.bin $(STORY)
	# Create empty 35-track, 18-sector disk image (161280 bytes)
	dd if=/dev/zero of=zork1.dsk bs=256 count=630
	# Format it with DECB (Initializes Track 17 directory)
	$(DECB) dskini zork1.dsk
	# Write boot loader to Track 34 (Sector 612)
	dd if=boot.bin of=zork1.dsk bs=256 seek=612 conv=notrunc
	# Write interpreter starting at Track 0, Sector 1 (Sector 0)
	dd if=cocozip.bin of=zork1.dsk bs=256 seek=0 conv=notrunc
	
	# Write Story Data with Track 16/17 Gap
	# Story starts at Track 2, Sector 1 (Sector 36)
	# Track 0-15 = 16 tracks = 288 sectors.
	# Part 1: Sectors 36 to 287 (252 sectors)
	dd if=$(STORY) of=zork1.dsk bs=256 count=252 seek=36 conv=notrunc
	# Part 2: Remaining sectors starting at Track 18, Sector 1 (Sector 324)
	# Skip the first 252 sectors of the story file and write to sector 324 of the disk
	dd if=$(STORY) of=zork1.dsk bs=256 skip=252 seek=324 conv=notrunc

clean:
	rm -f cocozip.bin boot.bin zork1.dsk *.map *.list
