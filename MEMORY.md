# Infocom Z-machine Interpreter (ZIP/6809) Memory Map

This document describes the memory layout of the 6809-based Z-machine interpreter for the TRS-80 Color Computer.

## System Memory Layout

The interpreter is designed for a 64K Color Computer 2.

| Address Range   | Description                                     |
|-----------------|-------------------------------------------------|
| `$0000` - `$00FF` | **Direct Page (DP) RAM** (Fastest access)      |
| `$010C`         | `IRQVEC` Interrupt Vector                       |
| `$0400` - `$05FF` | **Video RAM** (32x16 Text Screen)               |
| `$0A00` - `$0AFE` | **Machine Stack** (6809 S-stack, grows down)    |
| `$0B00` - `$0BFF` | **Disk I/O Buffer** (256 bytes)                 |
| `$0C00` - `$0DFE` | **Z-Stack** (255 words / 510 bytes)             |
| `$0E00` - `$0F3F` | **Paging Table** ($140 bytes)                   |
| `$0F50` - `$0FEF` | **LRU Map** ($A0 bytes)                         |
| `$1000` - `$101F` | **Local Variables** (32 bytes)                  |
| `$1020` - `$103F` | **I/O Line Buffer** (32 bytes)                  |
| `$1040` - `$105F` | **I/O Save Buffer** (32 bytes)                  |
| `$1100` - `$27FF` | **Interpreter Code (ZIP)** ($1700 bytes)        |
| `$2800` - `...`   | **Z-Code Preload** (Includes Game Header)       |
| `...` - `$FDFF`   | **Swapping Space** (LRU Paging Buffers)         |
| `$FE00` - `$FFFF` | **System / I/O** (ROMs and Hardware Registers)  |

## System & Hardware Constants

These addresses are used for interacting with the Color Computer hardware and ROM.

| Address   | Label     | Description                                     |
|-----------|-----------|-------------------------------------------------|
| `$006F`   | `DEVNUM`  | I/O Device Number ($00=Screen, $FE=Printer)     |
| `$0088`   | `CURSOR`  | Absolute cursor address                         |
| `$A000`   | `POLCAT`  | ROM Keycode Fetch Vector                        |
| `$A002`   | `CHROUT`  | ROM Character Output Vector                     |
| `$FF03`   | `INT60`   | 60Hz Interrupt Control                          |
| `$FFDE`   | `ROMON`   | ROM Enable (Bank Switch)                        |
| `$FFDF`   | `ROMOFF`  | ROM Disable (Bank Switch)                       |

## Direct Page (DP) Variables

The Direct Page contains the most frequently used variables for the interpreter.

| Offset | Label    | Size | Description                               |
|--------|----------|------|-------------------------------------------|
| `$00`  | `OPCODE` | 1    | Current Z-machine opcode                  |
| `$01`  | `ARGCNT` | 1    | Number of arguments for current opcode    |
| `$02`  | `ARG1`   | 2    | Argument #1 (Word)                        |
| `$04`  | `ARG2`   | 2    | Argument #2 (Word)                        |
| `$06`  | `ARG3`   | 2    | Argument #3 (Word)                        |
| `$08`  | `ARG4`   | 2    | Argument #4 (Word)                        |
| `$0A`  | `LRU`    | 1    | Least Recently Used page index            |
| `$0B`  | `ZPURE`  | 1    | First virtual page of "pure" Z-code       |
| `$0C`  | `PMAX`   | 1    | Maximum number of swapping pages          |
| `$13`  | `ZPCH`   | 1    | High bit of Z-machine PC                  |
| `$14`  | `ZPCM`   | 1    | Middle 8 bits of PC                       |
| `$15`  | `ZPCL`   | 1    | Low 8 bits of PC                          |
| `$16`  | `ZPCPNT` | 2    | Pointer to current PC page in RAM         |
| `$1A`  | `MPCH`   | 1    | High bit of Memory Pointer (MPC)          |
| `$1B`  | `MPCM`   | 1    | Middle 8 bits of MPC                      |
| `$1C`  | `MPCL`   | 1    | Low 8 bits of MPC                         |
| `$1D`  | `MPCPNT` | 2    | Pointer to current MPC page in RAM        |
| `$21`  | `GLOBAL` | 2    | Pointer to Global Variable Table          |
| `$23`  | `VOCAB`  | 2    | Pointer to Vocabulary Table               |
| `$25`  | `FWORDS` | 2    | Pointer to F-Words (Abbreviation) Table   |
| `$3D`  | `VAL`    | 2    | Value return register                     |
| `$49`  | `DRIVE`  | 1    | Current disk drive number                 |
| `$4B`  | `DBLOCK` | 2    | Current Z-block number                    |
| `$58`  | `RAND1`  | 1    | Random number seed 1                      |
| `$59`  | `RAND2`  | 1    | Random number seed 2                      |

## Z-Code Header Offsets

These offsets are relative to the start of the `ZCODE` preload at `$2800`.

| Offset | Label    | Description                               |
|--------|----------|-------------------------------------------|
| `0`    | `ZVERS`  | Version byte                              |
| `1`    | `ZMODE`  | Mode select byte                          |
| `2`    | `ZID`    | Game ID word                              |
| `4`    | `ZENDLD` | Start of non-preloaded Z-code             |
| `6`    | `ZBEGIN` | Initial Execution Address (PC)            |
| `8`    | `ZVOCAB` | Start of Vocabulary Table                 |
| `10`   | `ZOBJEC` | Start of Object Table                     |
| `12`   | `ZGLOBA` | Start of Global Variable Table            |
| `14`   | `ZPURBT` | Start of "Pure" Z-code                    |
| `24`   | `ZFWORD` | Start of F-Words Table                    |
| `26`   | `ZLENTH` | Length of Z-program in words              |
| `28`   | `ZCHKSM` | Z-code checksum                           |

## Virtual Memory Paging

The paging system uses a pool of 256-byte buffers starting from the end of the Z-code preload up to `$FDFF`. The number of pages is dynamically calculated at startup (in `WARM.ASM`) based on available RAM, with a maximum of `$A0` (160) pages.

- `PTABLE`: Maps virtual Z-code pages to physical RAM page indices.
- `LRUMAP`: Stores timestamps for each page to implement the LRU eviction policy.
