;-----------------------------------------------------------------------------
;	MANDELBROT65 : A 3.8 FIXED POINT MATH MANDELBROT CALCULATOR FOR THE APPLE1
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; INCLUDE DEBUGGING SUPPORT
;-----------------------------------------------------------------------------

#define noDEBUG		; Define DEBUG to include some debugging support

;-----------------------------------------------------------------------------
; Apple1 ROM & Hardware constants
;-----------------------------------------------------------------------------

ECHO 	= $FFEF
WOZMON 	= $FF00
PRBYTE 	= $FFDC
KBD 	= $D010
KBDCR 	= $D011

;-----------------------------------------------------------------------------
; Zero page variables
;-----------------------------------------------------------------------------

FACC = $00			; Fixed accumulator, used to address the square table

NUM = $02  ; 3 bytes
INCR = $05 ; 3 bytes

PTR = $08
TMP = $0A
NAN = $0B

SCRNX = $0C	        ; When iterating, the counter of lines and columns left to draw
SCRNY = $0D

ZX = $28		; X in current iteration
ZY = $2A		; Y in current iteration
ZX2 = $2C		; X^2 in current iteration
ZY2 = $2E		; Y^2 in current iteration
IT = $30		; Iteration counter


X0 = $0E
Y0 = $10
DX = $12
DY = $14

X = $16			; Current position in the set
Y = $18

PLACEPTR = $35

SEED = $37
FREQ = $38

NEXTX = $39		; Next position when auto zoom
NEXTY = $3B
NEXTDX = $3D	; Next delta when auto zoom
NEXTDY = $3F


ZOOMLEVEL = $42	; 0, 1, 2, 3 or 4
NEXTZOOMLEVEL = $43

;-----------------------------------------------------------------------------
; Constants
;-----------------------------------------------------------------------------


; Default Mandelbrot coordinates
INITALX = $FBD0
INITALY = $FDC0
INITIALDX = $0026
INITIALDY = $0030

; Time to wait between two mandelbrot displays in "rought seconds"
WAITIME = 4

; 16 bits number
; Format of numbers (16 bits, stored little endian -- reversed from this drawing)
;         A                 X
; +-+-+-+-+-+-+-+-+ +-+-+-+-+-+-+-+-+
; |i|i|i|i|i|i|i|f| |f|f|f|f|f|f|f|N|
; +-+-+-+-+-+-+-+-+ +-+-+-+-+-+-+-+-+
;  S     V
; iiiiiii = integer part (7 bits, 3 sgnificant + sign, two complement)
; ffffffff = fractional part (8 bits)
; N is Nan:
; 	0 for having even addresses in the square table
;	1 for illegal number
; The cannonical NaN is 00000000 00000001
; S = SIGNBIT
; V = OVERFLOW
; If S!=V the overflow
; Square table is at 00010000 00000000
;                 to 00011111 11111111
; Numbers in the form of 00001nnn nnnnnnn0 have squares that overflow,
; so there is opportunity to either squeeze more numbers in a rewrite (3.9 fixed point)
; or using less memory for the table

SIGNBIT = $80
OVFBIT = $10
NANBIT = $01

SQUARETABLE = $1000			; This table cannot be moved
SQUARETABLE_END = $2000		; End of table


;-----------------------------------------------------------------------------
; Couple of macros easing the manipulation of 16 bits numbers
;-----------------------------------------------------------------------------

	; Loads A number into AX
#define MLOADAX(NUM) LDX NUM: LDA NUM+1

	; Stores AX into NUM
#define MSTOREAX(NUM) STX NUM: STA NUM+1



;-----------------------------------------------------------------------------
; Software starts at 0x0280
; It can be assembled anywhere but memory 0x1000-0x2000 must be available RAM
;-----------------------------------------------------------------------------
* = $0280

	JMP MAIN

;-----------------------------------------------------------------------------
; The data that defines how this whole thing looks
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; One palette for each zoom level
;-----------------------------------------------------------------------------
PALETTE:
	.byte " .,'~=+:;[/<*?&O0X# XXXXXXXXXXXXXXXXXXXX"
	.byte " ..,'~==+:;[[/<*??&OO0X# XXXXXXXXXXXXXXX"
	.byte " ..,,''~==+::;[[/<<**??&OO0X# XXXXXXXXXX"
	.byte " ..,,''~~==++::;[[/<<**??&&OO00XX# XXXXX"
	.byte " ...,,'''~~==++::;;[[//<<***??&&OO00XX# "

;-----------------------------------------------------------------------------
; The offset of each palette
;-----------------------------------------------------------------------------
PALETTEDELTA:
	.byte 0, 40, 80, 120, 160

;-----------------------------------------------------------------------------
; The number of iteration per zoom level
;-----------------------------------------------------------------------------
MAXITER:
	.byte 19, 24, 29, 34, 39

;-----------------------------------------------------------------------------
; If iteration is lower than ZOOMTRIGGERMIN, the poinr cannot be chosen
; as next position
;-----------------------------------------------------------------------------
ZOOMTRIGGERMIN:
	.byte 15, 17, 18, 19, 20

;-----------------------------------------------------------------------------
; If iteration is larger or equal to ZOOMTRIGGERMAX, the poinr cannot be chosen
; as next position
;-----------------------------------------------------------------------------
ZOOMTRIGGERMAX:
	.byte 19, 19, 20, 21, 22




;-----------------------------------------------------------------------------
; Main loop
;-----------------------------------------------------------------------------
MAIN:
.(
		; Initialize ZP constants
	LDA #NANBIT
	STA NAN   ; Bit mask for NaN

		; Display intro
	JSR PRINTINLINE
.byte $d, $d
.byte "        --== Mandelbrot 65 ==--  ", $d, $d
.byte "A 6502 MANDELBROT & JULIA TIME WASTER", $d
.byte "                        FOR YOUR APPLE 1", $d, $d
.byte "                     BY FRED STARK, 2024", $d
.byte "        (PRESS ANY KEY TO START)", $d
.byte 0

		; Wait for key and init SEED
	LDA KBD
LOOP:
	INC SEED
	LDA KBDCR
	BPL LOOP
	LDA KBD

		; Initialize Square table
	JSR FILLSQUARES

		; Goes in AUTO mode
	JMP MANDELAUTO
.)

;-----------------------------------------------------------------------------
; Display and zooms in the mandelbrot set
;-----------------------------------------------------------------------------
MANDELAUTO:
.(
	JSR INITIALPLACE	; Starts a mandelbrot

LOOP:
	JSR GOTOPLACE		; Go to next place
	JSR INITIALPLACE	; If we don't find a new spot
						; We go back to Mandelbrot

	LDA #$d				; A couple of lines between drawings
	JSR ECHO
	JSR ECHO

	JSR DRAWSET			; Draw the mandelbrot set & pick a new spot

	JSR WAIT			; 4 seconds or a keypress
	BNE MANDELAUTO		; If non-space pressed, restart full mandelbrot

	JMP LOOP
.)

;-----------------------------------------------------------------------------
; Fills ZP variables with the initial values
;-----------------------------------------------------------------------------
INITIALPLACE:
.(
	LDA #<INITALX
	STA NEXTX
	LDA #>INITALX
	STA NEXTX+1

	LDA #<INITALY
	STA NEXTY
	LDA #>INITALY
	STA NEXTY+1

	LDA #<INITIALDX
	STA NEXTDX
	LDA #>INITIALDX
	STA NEXTDX+1

	LDA #<INITIALDY
	STA NEXTDY
	LDA #>INITIALDY
	STA NEXTDY+1

	LDA #0
	STA NEXTZOOMLEVEL

	RTS
.)

;-----------------------------------------------------------------------------
; Copies NEXTX/NEXTY/NEXTDX/NEXTDY/NEXTZOOMLEVEL
; into X/0/Y0/DX/DY/ZOOMLEVEL
;-----------------------------------------------------------------------------
GOTOPLACE:
.(
	LDA NEXTX
	STA X0
	LDA NEXTX+1
	STA X0+1

	LDA NEXTY
	STA Y0
	LDA NEXTY+1
	STA Y0+1

	LDA NEXTDX
	STA DX
	LDA NEXTDX+1
	STA DX+1

	LDA NEXTDY
	STA DY
	LDA NEXTDY+1
	STA DY+1

	LDA NEXTZOOMLEVEL
	STA ZOOMLEVEL

	RTS
.)

;-----------------------------------------------------------------------------
; Wait for some time at the end of the mandelbrot display
; (tuned for something like 4 seconds)
; Can be interrupted by pressing a key
; NZ if should abort
;-----------------------------------------------------------------------------
WAIT:
.(
	LDX #WAITIME*2				; Each double loop take around 1/2 second (0.72 seconds)
LOOP1:
	TXA
	PHA
	LDY #0
LOOP2:
	LDX #0
LOOP3:
	LDA KBDCR					; Exit on keypress
	BMI DONE
	DEX
	BNE LOOP3
	DEY
	BNE LOOP2
	PLA
	TAX
	DEX
	BNE LOOP1
	RTS

DONE:
	PLA
	LDA KBD			; Clear key
	CMP #' '
	RTS
.)

;-----------------------------------------------------------------------------
; Sets Z 1/A times
;-----------------------------------------------------------------------------
RNDCHOICE:
.(
	TAX				; X = FREQ
	JSR RANDOM
	TAY				; Y = RANDOM
	TXA				; A = FREQ
LOOP:
	DEX
	BNE SKIP		; Skip if not last
	TAX				; Reset FREQ
SKIP:
	DEY
	BNE LOOP
	TXA				; If X will be 1 1/FREQ times
	CMP #1
DONE:
	RTS
.)

;-----------------------------------------------------------------------------
; Return a random number in A
;-----------------------------------------------------------------------------
RANDOM:
.(
    LDA SEED
    ASL
    BCC SKIP
    EOR #$1d
SKIP:
	sta SEED
	RTS
.)

;-----------------------------------------------------------------------------
; Draw a single mandelbrot screen
; Selects the next place to zoom in when displaying, according to ZOOMTRIGGER*
;-----------------------------------------------------------------------------
DRAWSET:
.(
	LDA #0
	STA FREQ

	LDA #24
	STA SCRNY
	MLOADAX(Y0)
	MSTOREAX(Y)
LOOP1:
	LDA #40
	STA SCRNX
	MLOADAX(X0)
	MSTOREAX(X)

LOOP2:
	JSR ITER

		; Get character
	JSR CHARFROMIT

		; To avoid scrolling when image is complete, we skip the last char
	TAX
	LDA SCRNY
	CMP #1
	BNE CONTINUE
	LDA SCRNX
	CMP #1
	BNE CONTINUE
	RTS

CONTINUE:
	TXA
	JSR ECHO

		; Maybe this could be the new zoom ?
	LDA IT
	LDY ZOOMLEVEL
	CMP ZOOMTRIGGERMIN,Y
	BMI SKIP
	CMP ZOOMTRIGGERMAX,Y
	BPL SKIP

	JSR SELECTNEXT

SKIP:
		; Move X to next position in set
	LDA DX
	CLC
	ADC X
	STA X
	LDA DX+1
	ADC X+1
	STA X+1

	DEC SCRNX
	BNE LOOP2

		; Move Y to next position in set
	LDA DY
	CLC
	ADC Y
	STA Y
	LDA DY+1
	ADC Y+1
	STA Y+1

	DEC SCRNY
	BNE LOOP1

	RTS
.)

;-----------------------------------------------------------------------------
; Choose a zoomed in view centered on the current position
; (X-20*DX/2,Y-12*DY/2,DX/2,DY/2,ZOOMLEVEL+1) as the next position
; This choice is done 1/FREQ times, and FREQ is incremented
; This will choose a position uniformally
; without keeping all candidates in memory
; Only works for zooms where DX<128 (ie: all of them) because the /2 division
; is only made on the LSB
;-----------------------------------------------------------------------------
SELECTNEXT:
.(
	INC FREQ
	LDA FREQ
	JSR RNDCHOICE
	BNE SKIP

	LDA DX
	CMP #$80
	ROR
	CMP #1
	BEQ SKIP		; Zoom is too high
	AND #$FE
	STA NEXTDX
	LDA DX+1
	STA NEXTDX+1

	LDA DY
	CMP #$80
	ROR
	CMP #1
	BEQ SKIP		; Zoom is too high
	AND #$FE
	STA NEXTDY
	LDA DY+1
	STA NEXTDY+1

	LDA X
	STA NEXTX
	LDA X+1
	STA NEXTX+1

	LDA Y
	STA NEXTY
	LDA Y+1
	STA NEXTY+1

					; Remove 20x NEXTDX to NEXTX
	LDX #20
LOOP1:
	LDA NEXTX
	SEC
	SBC NEXTDX
	STA NEXTX
	LDA NEXTX+1
	SBC NEXTDX+1
	STA NEXTX+1
	DEX
	BNE LOOP1

					; Remove 12x NEXTDY to NEXTY
	LDX #12
LOOP2:
	LDA NEXTY
	SEC
	SBC NEXTDY
	STA NEXTY
	LDA NEXTY+1
	SBC NEXTDY+1
	STA NEXTY+1
	DEX
	BNE LOOP2

	LDA ZOOMLEVEL
	STA NEXTZOOMLEVEL
	INC NEXTZOOMLEVEL

	; #### Should check with some MAXZOOMLEVEL
SKIP:
	RTS
.)

;-----------------------------------------------------------------------------
; Prints the string that is stored after the JSR instruction that sent us here
;-----------------------------------------------------------------------------
PRINTINLINE:
.(
	PLA
	STA PTR
	PLA
	STA PTR+1
	JSR INCPTR
	LDY #0
PRINTLOOP:
	LDA (PTR),Y
	BEQ PRINTDONE
	JSR ECHO
	JSR INCPTR
	JMP PRINTLOOP
PRINTDONE:
	LDA PTR+1
	PHA
	LDA PTR
	PHA
	RTS
.)

;-----------------------------------------------------------------------------
; Increments PTR
;-----------------------------------------------------------------------------
INCPTR:
.(
	CLC
	INC PTR
	BNE DONE
	INC PTR+1
DONE:
	RTS
.)

;-----------------------------------------------------------------------------
; Compute one mandelbrot set of iterations
; ZP:X and ZP:Y contains the current position
; ZP:IT iteration counter
;-----------------------------------------------------------------------------
ITER:
.(
		; IT = 0
	LDA #0
	STA IT

		; ZX = X
		; ZX2 = ZX^2
	MLOADAX(X)
	MSTOREAX(ZX)
	JSR SQUARE
	BCS DONE
	MSTOREAX(ZX2)

		; ZY = Y
		; ZY2 = ZY^2
	MLOADAX(Y)
	MSTOREAX(ZY)
	JSR SQUARE
	BCS DONE
	MSTOREAX(ZY2)

LOOP:
		;	Compute one mandelbrot iteration
	JSR MANDEL1
	BCS DONE

		; Increment iteration
	INC IT

		; Stop at 42
	LDY ZOOMLEVEL
	LDA MAXITER,Y
	CMP IT
	BNE LOOP

DONE:
	RTS
.)

;-----------------------------------------------------------------------------
; Compute one madelbrot iteration
; ZP:ZX, ZP:ZY, ZP:ZX2, ZP:ZY2, ZP:IT
; C if overflow or stop
;-----------------------------------------------------------------------------
MANDEL1:
.(
	; COMPUTE ZY

	; zy = 2zx.zy + y
	; zy = zx2-(zx-zy)^2+zy2+y
	; zy = -(-zy+zx)^2+zx2+zy2+y

	; -zy
	MLOADAX(ZY)
	JSR NEG

	; -zy+zx
	CLC
	PHA
	TXA
	ADC ZX
	TAX
	PLA
	ADC ZX+1

	; (-zy+zx)^2
	JSR SQUARE

	; -(-zy+zx)^2
	JSR NEG

	; -(-zy+zx)^2+zx2
	CLC
	PHA
	TXA
	ADC ZX2
	TAX
	PLA
	ADC ZX2+1

	; -(-zy+zx)^2+zx2+zy2
	CLC
	PHA
	TXA
	ADC ZY2
	TAX
	PLA
	ADC ZY2+1

	; -(-zy+zx)^2+zx2+zy2+y
	CLC
	PHA
	TXA
	ADC Y
	TAX
	PLA
	ADC Y+1

	; zy = -(-zy+zx)^2+zx2+zy2+y
	MSTOREAX(ZY)

	; COMPUTE ZX

	; zx = zx2 - zy2 + x;
	; zx = -zy2 + zx2 + x

	; zy2
	MLOADAX(ZY2)

	; -zy2
	JSR NEG

	; -zy2 + zx2
	CLC
	PHA
	TXA
	ADC ZX2
	TAX
	PLA
	ADC ZX2+1

	; -zy2 + zx2 + x
	CLC
	PHA
	TXA
	ADC X
	TAX
	PLA
	ADC X+1

	; zx = -zy2 + zx2 + x
	MSTOREAX(ZX)

	; If not a number, done
	JSR ISNUMBER
	BCS DONE

	; zx2 = zx^2
	MLOADAX(ZX)
	JSR SQUARE
	BCS DONE
	MSTOREAX(ZX2)

	; zy2 = zy^2
	MLOADAX(ZY)
	JSR SQUARE
	BCS DONE
	MSTOREAX(ZY2)

DONE:
	RTS
.)

;-----------------------------------------------------------------------------
; Returns the correct char for current iteration
; Intput: ZP:IT constains the iteration number
;         ZP:ZOOMLEVEL contains the current zoom level
; Output: A contains the character to be displayed
;-----------------------------------------------------------------------------
CHARFROMIT:
.(
	LDA IT
	LDY ZOOMLEVEL
	CLC
	ADC PALETTEDELTA,Y	; A = IT + PALETTEDELTA[ZOOMLEVEL]
	TAY
	LDA PALETTE,Y		; Correct palette entry
	RTS
.)


;-----------------------------------------------------------------------------
; Input AX, valid number
; Output -AX
;-----------------------------------------------------------------------------
NEG:
.(
	PHA
	TXA
	EOR #$FF				; 2 COMPLEMENT OF (A,X)
	CLC
	ADC #1
	TAX
	PLA
	EOR #$FF
	ADC #0
	RTS
.)

;-----------------------------------------------------------------------------
; Input AX
; Retuns SQUARE of AX, set carry if overflow
;-----------------------------------------------------------------------------
SQUARE:
.(
	JSR ISNUMBER		; Not a number or overflow ?
	BCS DONE
	JSR ABS				; Get absolute value
	ORA #$10			; Set square table address bit (0x1000)
	STA FACC+1
	STX FACC
	LDY #0
	LDA (FACC),Y
	TAX
	INY
	LDA (FACC),Y
DONE:
	RTS
.)

;-----------------------------------------------------------------------------
; Input AX, valid number
; Output abs(AX)
;-----------------------------------------------------------------------------
ABS:
.(
	ORA #0
	BMI NEG					; Neg if negative
DONE:
	RTS
.)

;-----------------------------------------------------------------------------
; Input AX
; If number is NAN or OVERFLOW, set carry
;-----------------------------------------------------------------------------
ISNUMBER:
.(
	PHA
	TXA
	BIT NAN
	BNE DONENAN		; Skip if NAN
	PLA
	PHA
	CLC
	AND #$90		; Isolate sign bit and overflow bit
	ADC #$70		; Propagate overflow to sign
	AND #$80		; If signed is zero then no overflow
	BNE DONENAN
	PLA
	CLC
	RTS
DONENAN:
	PLA
	SEC
	RTS
.)







;-----------------------------------------------------------------------------
; Some macros to deal with the filling of the square table
;-----------------------------------------------------------------------------


	; Zeroes a **T**hree byt varaible
#define MZEROT(ADRS) LDA #0:STA ADRS:STA ADRS+1:STA ADRS+2

	; Increments
#define MINCT(ADRS) LDA ADRS:CLC:ADC #1:STA ADRS:LDA ADRS+1:ADC #0:STA ADRS+1:LDA ADRS+2:ADC #0:STA ADRS+2
#define MINC2W(ADRS) LDA ADRS:CLC:ADC #2:STA ADRS:LDA ADRS+1:ADC #0:STA ADRS+1

	; Additions
#define MADDT(DEST,SRC) LDA DEST:CLC:ADC SRC:STA DEST:LDA DEST+1:ADC SRC+1:STA DEST+1:LDA DEST+2:ADC SRC+2:STA DEST+2


;-----------------------------------------------------------------------------
; Fill square table with squares of numbers
;-----------------------------------------------------------------------------
FILLSQUARES:
.(
		; NUM = INCR = 0
	MZEROT(NUM)
	MZEROT(INCR)

		; Pointer to square table
	LDA #<SQUARETABLE
	STA PTR
	LDA #>SQUARETABLE
	STA PTR+1

LOOP:
		; Store current square value
	LDY #0
	LDA NUM+1
	CLC
	ROL
	STA (PTR),Y
	LDA NUM+2
	ROL
;	ORA #NUMBIT
	INY
	STA (PTR),Y

		; Increment pointer
	MINC2W(PTR)

		; Add INCR to NUM
	MADDT(NUM,INCR)

		; Check if NUM has overflown
	LDA NUM+2
	AND #$08
	BNE FILLNAN

		; Increment INCR
	MINCT(INCR)

		; Add INCR to NUM
	MADDT(NUM,INCR)

		; Check if NUM has overflown
	LDA NUM+2
	AND #$08
	BEQ LOOP

FILLNAN:
	; Fill rest of the table with NaN
	
	; Compare PTR with end of table
	LDA PTR
	CMP #<SQUARETABLE_END
	BNE CONTINUE
	LDA PTR+1
	CMP #>SQUARETABLE_END
	BNE CONTINUE
	RTS

CONTINUE:
		; 0,1 is NaN
	LDY #0
	LDA #1
	STA (PTR),Y
	INY
	LDA #0
	STA (PTR),Y

			; Increment pointer
	MINC2W(PTR)

	JMP FILLNAN
.)

;-----------------------------------------------------------------------------
;	Debug support, optionally compiled in
;-----------------------------------------------------------------------------

#ifdef DEBUG

TMP1 = $1A
TMP2 = $1C

TMP_DBG = $FD		; 3 Bytes needed

DBGNEXT:
.(
	LDA #$d
	JSR ECHO
	JSR ECHO
	MLOADAX(NEXTX)
	JSR PRINT_AX
	LDA #' '
	JSR ECHO
	MLOADAX(NEXTY)
	JSR PRINT_AX
	LDA #' '
	JSR ECHO
	MLOADAX(NEXTDX)
	JSR PRINT_AX
	LDA #' '
	JSR ECHO
	MLOADAX(NEXTDY)
	JSR PRINT_AX
	LDA #$d
	JSR ECHO
	JSR ECHO
	RTS
.)

;-----------------------------------------------------------------------------
; Prints the string that is stored after the JSR instruction that sent us here
; Followed by AX
;-----------------------------------------------------------------------------
DBG_AX:
.(
	MSTOREAX(TMP_DBG)
	STY TMP_DBG+2
	PLA
	STA PTR
	PLA
	STA PTR+1
	JSR INCPTR
	LDY #0
PRINTLOOP:
	LDA (PTR),Y
	BEQ PRINTDONE
	JSR ECHO
	JSR INCPTR
	JMP PRINTLOOP
PRINTDONE:
	LDA PTR+1
	PHA
	LDA PTR
	PHA
	MLOADAX(TMP_DBG)
	JSR PRINT_AX
	; LDA #$d
	; JSR ECHO
	MLOADAX(TMP_DBG)
	LDY TMP_DBG+2
	RTS
.)


;-----------------------------------------------------------------------------
; Prints the number. No change to any register. Trashes TMP and PTR
;-----------------------------------------------------------------------------
PRINT_AX:
.(
	PHP
	MPUSHAX
	PHA
	TXA
	BIT NAN					; BIT 0 is 1 for NAN
	BNE PRINT_NAN			; PRINT <NAN?>
	PLA
	PHA
	AND #SIGNBIT			; TEST SIGN
	BEQ POSITIVE			; PRINTS '+' AND NUMBER
	LDA #'-'				; PRINTS '-' AND -NUMBER
	JSR ECHO
	TXA
	EOR #$FF				; 2 COMPLEMENT OF (A,X)
	CLC
	ADC #1
	TAX
	PLA
	EOR #$FF
	ADC #0
	JMP PRINTNOSIGN
POSITIVE:
	LDA #'+'
	JSR ECHO
	PLA
PRINTNOSIGN:
	PHA
	ROR
	AND #$07
	CLC
	ADC #'0'
	JSR ECHO
	LDA #'.'
	JSR ECHO
	PLA
	ROR
	TXA
	ROR
	JSR PRFRACT
PRINT_EXIT:
	MPULLAX
	PLP
	RTS
PRINT_NAN:
	PLA
	JSR PRINTINLINE
.byte "<NAN!>", 0
	JMP PRINT_EXIT

; Print fractional part of A
; 0->0 255->1-1/256
PRFRACT:
		; TMP1 = TMP2 = A
	STA TMP1
	LDX #3

LOOP3:
	LDA TMP1
	STA TMP2
	LDA #0
	STA TMP1+1
	STA TMP2+1

		; TMP1 = TMP1 * 10
		; 10n = ((n*4) + n) *2
	JSR DBLTMP1
	JSR DBLTMP1
	JSR ADDTMP1
	JSR DBLTMP1

		; Display digit
	LDA TMP1+1
	ORA #'0'
	JSR ECHO


	DEX
	BNE LOOP3
	RTS
.)

	; Double TMP1
DBLTMP1:
	ASL TMP1
	ROL TMP1+1
	RTS

	; Add TMP2 to TMP1
ADDTMP1:
	CLC
	LDA TMP1
	ADC TMP2
	STA TMP1
	LDA TMP1+1
	ADC TMP2+1
	STA TMP1+1
	RTS

#endif
