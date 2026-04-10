        ;------------------------------------------
        ; NEW ZIP LOADER
        ; RESIDES ON TRACK 34 OF CO-CO DISK
        ; AND IS LOADED BY CO-CO WITH 'DOS' COMMAND
        ;------------------------------------------

        INCLUDE "COCO_EQ.ASM"

        ; EQUATES

BUG     EQU     0
ZSTART  EQU     $1100
ZEND    EQU     $3000+BUG

        ;---------------------------------------------------------
        ; BOOT SECTOR ENTRY POINT
        ; The 'DOS' command loads all 18 sectors in track 34 to 
        ; $2600 and JMPs here. Total bytes read are 4.5k but code
        ; is far less than that.
        ;---------------------------------------------------------

        ORG     $2600

        FCC     "OS"            ; REQUIRED BY DOS BOOT SECTOR

MOVE:   LDX     #00             ; SET UP TO MOVE BOOT CODE OUT OF WAY OF ZIP
MOVLP:  LDD     HERE,X
        STD     THERE,X
        LEAX    2,X
        CMPX    #$800           ; currently 2k out of 4.5k is copied, but 
        BLO     MOVLP           ; boot code is much shorter than that anyway
        JMP     RUN

HERE:   EQU *

        ORG     $5000

THERE:  EQU *

        ;---------------------------------------------------------
        ; MAIN LOADER LOOP
        ; Relocated to $5000. Loads ZIP from Track 1 into $1100.
        ;---------------------------------------------------------

RUN:    LDX     #DIRQSV         ; SET SYSTEM IRQ VECTOR
        STX     IRQVEC+1
        LDA     #$7E            ; JMP OP-CODE
        STA     IRQVEC

        LDD     #$0001          ; START AT TRACK 0, SECTOR 1
        STD     TRACK
        LDD     #ZSTART         ; INITIAL LOADING ADDRESS ($1100)
        STD     BUFFER
LOOP:   LDX     #DCB            ; POINT TO DISK CONTROL BLOCK
        LDD     #$0200          ; OP-CODE 2 (READ), DRIVE 0
        STD     ,X
        LDD     TRACK           ; SET TARGET TRACK AND SECTOR
        STD     2,X
        INCB                    ; INCREMENT SECTOR
        CMPB    #19             ; END OF TRACK? (18 SECTORS/TRACK)
        BLO     DOBUFF
        LDB     #1              ; RESET TO SECTOR 1
        INCA                    ; INCREMENT TRACK
DOBUFF: STD     TRACK
        LDD     BUFFER          ; SET DESTINATION BUFFER
        STD     4,X
        INCA                    ; ADVANCE BUFFER BY 256 BYTES
        STD     BUFFER
        LBSR    MYCON           ; CALL DISK CONTROLLER
        TST     6,X             ; CHECK STATUS
        BNE     ERROR           ; HALT ON DISK ERROR
        CMPD    #ZEND           ; FINISHED LOADING ZIP?
        BLO     LOOP
        JMP     ZSTART          ; START THE INTERPRETER

        ; ERROR HANDLER

ERRM:   FCB     $0D
        FCC     "DISK ERRROR!"
        FCB     $0D
ERRML:  EQU     *-ERRM

ERROR:  LDX     #ERRM
        LDB     #ERRML
ELOOP:  LDA     ,X+
        LBSR    MYCHR
        DECB
        BNE     ELOOP
FREEZ:  BRA     FREEZ

TRACK:  FCB     $00,$00
BUFFER: FCB     $00,$00

ZZZ:    EQU *


; ---------------------------------------------------------------------
; ROM-REPLACEMENT ROUTINES (See IO.ASM and MEMORY.md for details)
;
; These routines (MYCHR, MYCON, DIRQSV) are functional replacements for
; standard CoCo ROM subroutines, allowing the bootloader and 
; interpreter to run with ROMs disabled.
; ---------------------------------------------------------------------

        ;---------------------------------------------------------
        ; DIRQSV: IRQ SERVICE ROUTINE
        ; Manages 60Hz timer and disk motor timeout.
        ; (Replacement for ROM IRQ handler at $D644)
        ;---------------------------------------------------------

DIRQSV: LDA     PIA0+3          ; CHECK FOR 60HZ INTERRUPT
        BPL     DRTI            ; EXIT IF NOT FIELD SYNC
        LDA     PIA0+2          ; RESET PIA INTERRUPT FLAG
        LDA     RDYTMR          ; CHECK MOTOR-ON TIMER
        BEQ     DRTI            ; ALREADY OFF?
        DECA                    ; DECREMENT TIMER
        STA     RDYTMR
        BNE     DRTI            ; NOT ZERO YET
        LDA     DRGRAM          ; GET DISK REGISTER SHADOW
        ANDA    #$B0            ; KILL MOTOR AND DRIVE SELECT
        STA     DRGRAM
        STA     DSKREG          ; UPDATE HARDWARE REGISTER
DRTI:   RTI

        ;---------------------------------------------------------
        ; LA7D1: SHORT DELAY LOOP
        ;---------------------------------------------------------

LA7D1:  LDX     ZERO
LA7D3:  LEAX    -1,X
        BNE     LA7D3
        RTS


; ---------------------------------------------------------------------
; MYCHR: Character Output (Replacement for CHROUT at $A002)
; Based on "Color Basic Unravelled"
; ---------------------------------------------------------------------

MYCHR:  JSR     RVEC3           ; RAM HOOK FOR CHARACTER OUTPUT
        PSHS    B
        LDB     DEVNUM          ; CHECK OUTPUT DEVICE
        INCB
        PULS    B
        BMI     LA2BF           ; EXIT IF DEVICE IS CASSETTE
        BNE     LA30A           ; PRINT TO SCREEN IF DEVICE 0
        RTS

LA2BF:  RTS

LA30A:  PSHS    A,B,X           ; OUTPUT CHAR IN 'A' TO SCREEN
        LDX     CURPOS          ; GET CURRENT CURSOR POSITION
        CMPA    #BS             ; IS IT A BACKSPACE?
        BNE     LA31D
        CMPX    #VIDRAM         ; AT START OF SCREEN?
        BEQ     LA35D
        LDA     #$60            ; CLEAR CHARACTER
        STA     ,-X
        BRA     LA344           ; UPDATE CURSOR
LA31D:  CMPA    #CR             ; IS IT A CARRIAGE RETURN?
        BNE     LA32F
        LDX     CURPOS          ; FILL REMAINDER OF LINE WITH BLANKS
LA323:  LDA     #$60
        STA     ,X+
        TFR     X,D
        BITB    #$1F            ; END OF LINE?
        BNE     LA323
        BRA     LA344           ; UPDATE CURSOR
LA32F:  CMPA    #SPACE          ; IS IT A PRINTABLE CHARACTER?
        BLO     LA35D
        TSTA                    ; CONVERT ASCII TO COCO CHARSET
        BMI     LA342
        CMPA    #$40
        BLO     LA340
        CMPA    #$60
        BLO     LA342
        ANDA    #$DF            ; CONVERT TO UPPER CASE
LA340:  EORA    #$40            ; TOGGLE BIT 6
LA342:  STA     ,X+             ; STORE TO VIDEO RAM
LA344:  STX     CURPOS          ; SAVE NEW CURSOR POSITION
        CMPX    #VIDRAM+511     ; OFF THE END OF SCREEN?
        BLS     LA35D
        LDX     #VIDRAM         ; SCROLL SCREEN UP ONE LINE

LA34E:  LDD     32,X            ; MOVE LINE UP
        STD     ,X++
        CMPX    #VIDRAM+$1E0
        BLO     LA34E
        LDB     #$60            ; CLEAR BOTTOM LINE
        BSR     LA92D
LA35D:  PULS    A,B,X,PC

LA92D:  STX     CURPOS          ; CLEAR FROM X TO END OF SCREEN
LA92F:  STB     ,X+
        CMPX    #VIDRAM+511
        BLS     LA92F
        RTS

; ---------------------------------------------------------------------
; MYCON: Disk Controller (Replacement for DSKCON at $C004)
; Based on "Disk Basic Unravelled"
; ---------------------------------------------------------------------

MYCON:  PSHS    U,Y,X,D         ; ENTRY POINT FOR DSKCON
        LDA     #5              ; RETRY COUNTER
        PSHS    A
LD672:  CLR     RDYTMR          ; KILL MOTOR TIMER DURING I/O
        LDB     DCDRV           ; GET DRIVE NUMBER
        LDX     #LD7AA          ; DRIVE SELECT TABLE
        LDA     DRGRAM          ; GET CURRENT REGISTER STATE
        ANDA    #$A8            ; PRESERVE DENSITY/DELAY
        ORA     B,X             ; ADD DRIVE SELECT BIT
        ORA     #$20            ; ENABLE MOTOR
        LDB     DCTRK           ; GET TARGET TRACK
        CMPB    #22             ; DOUBLE SIDED?
        BLO     LD68B
        ORA     #$10            ; SELECT SIDE 1
LD68B:  TFR     A,B
        ORA     #8              ; HALT ENABLE
        STA     DRGRAM          ; UPDATE SHADOW
        STA     DSKREG          ; UPDATE HARDWARE
        BITB    #8              ; WAS MOTOR ALREADY ON?
        BNE     LD69F
        JSR     LA7D1           ; DELAY FOR MOTOR START
        JSR     LA7D1
LD69F:  BSR     LD6DE           ; WAIT FOR FDC NOT BUSY
        BNE     LD6AD           ; EXIT ON ERROR
        CLR     DCSTA           ; CLEAR STATUS
        LDX     #LD7A2          ; COMMAND JUMP TABLE
        LDB     DCOPC           ; GET OP-CODE
        ASLB
        JSR     [B,X]           ; EXECUTE DISK COMMAND
LD6AD:  PULS    A               ; GET RETRY COUNT
        LDB     DCSTA           ; CHECK STATUS
        BEQ     LD6BE           ; SUCCESS?
        DECA                    ; DECREMENT RETRIES
        BEQ     LD6BE           ; GIVE UP?
        PSHS    A
        BSR     LD6C5           ; RESTORE HEAD AND RETRY
        BNE     LD6AD
        BRA     LD672
LD6BE:  LDA     #120            ; RESET MOTOR TIMER (2 SECONDS)
        STA     RDYTMR
        PULS    PC,U,Y,X,D

        ; RESTORE DRIVE HEAD TO TRACK 0
LD6C5:  LDX     #DR0TRK
        LDB     DCDRV
        CLR     B,X             ; SET CURRENT TRACK TO 0
        LDA     #3              ; RESTORE COMMAND
        STA     FDCREG
        EXG     A,A             ; FDC DELAY
        EXG     A,A
        BSR     LD6DE           ; WAIT FOR BUSY CLEAR
        BSR     LD6FD           ; DELAY FOR HEAD SETTLE
        ANDA    #$10            ; CHECK FOR SEEK ERROR
        STA     DCSTA
LD6DD:  RTS

        ; WAIT FOR FDC TO CLEAR BUSY FLAG
LD6DE:  LDX     ZERO
LD6E0:  LEAX    -1,X
        BEQ     LD6EC           ; TIMEOUT?
        LDA     FDCREG
        BITA    #1              ; BUSY?
        BNE     LD6E0
        RTS
LD6EC:  LDA     #$D0            ; FORCE INTERRUPT COMMAND
        STA     FDCREG
        EXG     A,A
        EXG     A,A
        LDA     FDCREG
        LDA     #$80            ; SET TIMEOUT ERROR
        STA     DCSTA
        RTS

        ; SHORT DELAY FOR HEAD SETTLING
LD6FD:  LDX     #8750
LD700:  LEAX    -1,X
        BNE     LD700
        RTS

        ; WRITE SECTOR ENTRY
LD705:  LDA     #$80            ; WRITE SECTOR OP
        FCB     SKP2
        ; READ SECTOR ENTRY
LD708:  LDA     #$A0            ; READ SECTOR OP
        PSHS    A
        LDX     #DR0TRK
        LDB     DCDRV
        ABX
        LDB     ,X              ; GET CURRENT TRACK FOR DRIVE
        STB     FDCREG+1        ; SET FDC TRACK REGISTER
        CMPB    DCTRK           ; ALREADY ON TARGET TRACK?
        BEQ     LD739
        LDA     DCTRK           ; SEEK TO NEW TRACK
        STA     FDCREG+3
        STA     ,X              ; UPDATE CURRENT TRACK
        LDA     #$17            ; SEEK COMMAND
        STA     FDCREG
        EXG     A,A
        EXG     A,A
        BSR     LD6DE           ; WAIT FOR SEEK
        BNE     LD737
        BSR     LD6FD           ; SETTLE HEAD
        ANDA    #$18            ; CHECK SEEK ERRORS
        BEQ     LD739
        STA     DCSTA
LD737:  PULS    PC,A

        ; SETUP FOR NMI-DRIVEN DATA TRANSFER
LD739:  LDA     DSEC            ; SET TARGET SECTOR
        STA     FDCREG+2
        LDX     #LD798          ; SET NMI VECTOR
        STX     DNMIVC
        LDX     DCBPT           ; GET DATA BUFFER POINTER
        LDA     FDCREG          ; RESET STATUS
        LDA     DRGRAM          ; ENABLE NMI IN DISK REGISTER
        ORA     #$80
        PULS    B               ; GET READ/WRITE OP-CODE
        LDY     ZERO            ; TIMEOUT COUNTER
        LDU     #FDCREG
        COM     NMIFLG          ; ENABLE NMI SYNC
        ORCC    #$50            ; DISABLE MASKABLE INTERRUPTS
        STB     FDCREG          ; ISSUE COMMAND TO FDC
        EXG     A,A             ; FDC DELAY
        EXG     A,A
        CMPB    #$80            ; IS IT A WRITE?
        BEQ     LD782

        ; READ SECTOR LOOP
        LDB     #2              ; DRQ BIT
LD768:  BITB    ,U              ; DATA REQUEST?
        BNE     LD778           ; YES, TRANSFER BYTE
        LEAY    -1,Y            ; TIMEOUT?
        BNE     LD768
LD770:  CLR     NMIFLG          ; DISABLE NMI SYNC
        ANDCC   #$AF            ; RE-ENABLE INTERRUPTS
        JMP     LD6EC           ; ERROR EXIT


        ; WRITE SECTOR LOOP (TRANSFER DATA)
LD778:  LDB     ,X+             ; GET BYTE FROM BUFFER
        STB     FDCREG+3        ; SEND TO FDC
        STA     DSKREG          ; RE-TRIGGER NMI (BY WRITING TO $FF40)
        BRA     LD778

LD782:  LDB     #2              ; DRQ BIT
LD784:  BITB    ,U              ; READY TO WRITE?
        BNE     LD78E           ; YES
        LEAY    -1,Y
        BNE     LD784
        BRA     LD770           ; TIMEOUT

LD78E:  LDB     FDCREG+3        ; READ BYTE FROM FDC
        STB     ,X+             ; STORE TO BUFFER
        STA     DSKREG          ; RE-TRIGGER NMI
        BRA     LD78E

        ; NMI INTERRUPT HANDLER (END OF SECTOR)
LD798:  ANDCC   #$AF            ; ENABLE INTERRUPTS
        LDA     FDCREG          ; GET FINAL STATUS
        ANDA    #$7C            ; MASK ERRORS
        STA     DCSTA           ; SAVE STATUS
        RTS

        ; DSKCON JUMP TABLE
LD7A2:  FDB     LD6C5           ; RESTORE
        FDB     LD6DD           ; NOP
        FDB     LD705           ; WRITE
        FDB     LD708           ; READ

        ; DRIVE SELECT BIT TABLE
LD7AA:  FCB     1               ; DRIVE 0
        FCB     2               ; DRIVE 1
        FCB     4               ; DRIVE 2
        FCB     $40             ; DRIVE 3

        END
