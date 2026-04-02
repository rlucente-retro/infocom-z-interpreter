# Infocom Z-machine Interpreter for TRS-80 Color Computer (ZIP/6809-C)

This project is a 6809 assembly language implementation of the Infocom Z-machine interpreter (ZIP) for the TRS-80 Color Computer (CoCo). It is designed to run on a 64K CoCo 2 and provides support for Version 3 Z-code games.

## Architecture Overview

The interpreter follows the standard Z-machine architecture but is heavily optimized for the 6809 CPU and the CoCo's hardware constraints. It uses a virtual memory paging system to handle games that are larger than the available RAM.

### Core Components

*   **Main Loop (`main.src`):** The central execution engine. It fetches opcodes, decodes them (0-OP, 1-OP, 2-OP, X-OP), and dispatches to specific handlers.
*   **Paging System (`paging.src`):** A sophisticated virtual memory manager using a Least Recently Used (LRU) algorithm with timestamps. It allows the interpreter to access up to 128KB (or more) of Z-code by swapping 256-byte pages from disk into a RAM-resident buffer pool.
*   **Z-String Handler (`zstring.src`):** Implements the complex Z-string compression and decoding logic, including support for three character sets, temporary/permanent shifts, and abbreviations (F-words).
*   **Object & Property Handler (`objects.src`):** Manages the Z-machine's object tree and property tables, providing efficient traversal and manipulation.
*   **I/O System (`ioprims.src`, `screen.src`):** Provides a 32-column text display, status line updates (Score/Moves or Time), and keyboard input. It includes specialized routines to bypass the CoCo's ROM for compatibility with different operating systems like Nitros9 (as seen in the provided source).
*   **Disk System (`disk.src`):** Handles track/sector-based disk I/O for both loading Z-code blocks and performing SAVE/RESTORE operations.

## Memory Organization

The interpreter is designed to fit within the 64K address space:

*   **Direct Page (Page 0):** Used for the most frequently accessed Z-machine variables (Opcode, Arguments, PC, MPC, etc.).
*   **Machine Stack:** Standard 6809 stack for subroutine calls and local state.
*   **Z-Stack:** Dedicated 255-word stack for Z-machine operations and CALL/RET state.
*   **Paging Table & LRU Map:** Used by the paging system to track which Z-code pages are in RAM and when they were last accessed.
*   **Preloaded Z-Code:** The "pure" part of the Z-code (header and initial data) is kept permanently in RAM.
*   **Swapping Space:** A pool of RAM buffers used to cache "impure" and non-preloaded Z-code pages from disk.

## Disk Organization

The interpreter expects the Z-code game data to be arranged on the disk in a specific format:

*   **Boot Track (Track 34):** Contains the initial loader (`boot.src`).
*   **Story Data:** Starts at Track 2, Sector 1.
*   **Save Slots:** Support for 7 save positions, each occupying 5 tracks on a separate save disk.

## Building and Files

The project is structured into multiple source files, with `cocozip.src` acting as the master file that includes all other components.

*   `zequates.src`: Z-machine constants and memory layout.
*   `main.src`: The main interpreter loop.
*   `mainsubs.src`: Core utility subroutines.
*   `dispatch.src`: Opcode dispatch tables.
*   `ops*.src`: Implementation of the various Z-machine opcodes.
*   `read.src`: Lexical analyzer and input parser.
*   `paging.src`: Virtual memory and LRU paging.
*   `zstring.src`: Z-string decoding and encoding.
*   `objects.src`: Object and property manipulation.
*   `ioprims.src`: Low-level hardware I/O.
*   `screen.src`: High-level display and status line management.
*   `disk.src`: Disk I/O and Save/Restore logic.
*   `warm.src`: Interpreter initialization and startup.
*   `boot.src`: Initial loader for the CoCo.

## Version History

*   **Version A (1984):** Initial archival.
*   **Version C (1985):** Significant updates for OS9 compatibility and paging improvements.
