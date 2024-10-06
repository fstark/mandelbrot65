;-----------------------------------------------------------------------------
;	MANDELBROT65 : A 3.8 FIXED POINT MATH MANDELBROT CALCULATOR FOR THE APPLE1
;-----------------------------------------------------------------------------
; FREDERIC STARK SEPTEMBER 2024
; https://www.github.com/fstark/mandelbrot65
; http://stark.fr/blog/mandelbrot65 (coming soon)
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; Software starts at 0x0280
; It can be assembled anywhere but memory 0x1000-0x2000 must be available RAM
;-----------------------------------------------------------------------------
* = $0280

#define noNONRANDOM	; Define NONRANDOM to have a repeatable sequence
#define noDEBUG		; Define DEBUG to include some debugging support

;-----------------------------------------------------------------------------
; Apple1 ROM & Hardware constants
;-----------------------------------------------------------------------------

ECHO 			= $FFEF		; ECHO A CHARACTER
KBD 			= $D010		; KEYBOARD
KBDCR 			= $D011		; KEYBOARD CONTROL

;-----------------------------------------------------------------------------
; Zero page variables layout
;-----------------------------------------------------------------------------


;-----------------------------------------------------------------------------
; Coordinates of the current mandelbrot displayed,
; frequency for choice of next one
; iteration count for the current "pixel"
; and a few of internal variables (seed, abort, nan mask)
;-----------------------------------------------------------------------------

;    +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
; 00 | X COORD | Y COORD | X DELTA | Y DELTA |ZOOM|FREQ|         |    |SEED|ABRT| IT |
;    +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
X0 				= $00		; Top-left position in the set
Y0 				= $02
DX 				= $04		; Current delta
DY 				= $06
ZOOMLEVEL		= $08		; Current zoom level (0-4)
FREQ 			= $09		; Used to randomly choose the next coordinates during the computation of the current one
SEED 			= $0D		; The random seed
ABORT 			= $0E		; If bit 7 is set, abort was requested by the user
							; Use BIT ABORT + BMI to check
							; It aborts the menu display or the current mandelbrot
IT 				= $0F		; Iteration counter

;-----------------------------------------------------------------------------
;    Coordinates of the next mandelbrot to display (X,Y and X,Y deltas)
;-----------------------------------------------------------------------------

;    +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
; 10 | NEXT X  | NEXT  Y | NX DELTA| NY DELTA|ZOOM|                                  |
;    +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
NEXTX 			= $10		; Next position we will zoom in
NEXTY 			= $12
NEXTDX 			= $14		; Next delta we will use after zooming in
NEXTDY 			= $16
NEXTZOOMLEVEL	= $18		; Next zoom level (0-4)

;-----------------------------------------------------------------------------
; Current "pixel" beging computed, in mandelbrot and screen space
;-----------------------------------------------------------------------------

;    +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
; 20 | X CURR  | Y CURR  | X SCRN  | Y SCRN  |   ZX    |   ZY    |  ZX^2   |  ZY^ 2  |
;    +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
X 				= $20		; Current position in the set
Y 				= $22
SCRNX 			= $24      	; Counter of lines and columns left to draw
SCRNY 			= $26
ZX 				= $28		; X in current iteration
ZY 				= $2A
ZX2 			= $2C		; X^2 in current iteration
ZY2 			= $2E

;-----------------------------------------------------------------------------
; Various temporaries
;-----------------------------------------------------------------------------

;    +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
; 30 | 3 BYTES NUM  | 3 BYTES INC  | POINTER |               			             |
;    +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
NUM 			= $30		; A 3 bytes number used to build the square table
INCR 			= $33		; 3 bytes increment used to build the square table
PTR 			= $36		; A generic pointer




#ifdef DEBUG

;-----------------------------------------------------------------------------
; Temporary variables used by debug code
;-----------------------------------------------------------------------------

;    +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
; 40 | DBG TMP1| DBG TMP2|    DBG TMP   |                                            |
;    +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
TMP1 			= $40
TMP2 			= $42
TMP_DBG 		= $44		; 3 Bytes needed

#endif

;-----------------------------------------------------------------------------
; Constants
;-----------------------------------------------------------------------------

; 16 bits number
; Format of numbers (16 bits, stored little endian -- reversed from this drawing)
;         A                 X
; +-+-+-+-+-+-+-+-+ +-+-+-+-+-+-+-+-+
; |i|i|i|i|i|i|i|f| |f|f|f|f|f|f|f|N|
; +-+-+-+-+-+-+-+-+ +-+-+-+-+-+-+-+-+
;
; iiii = integer part (7 bits, 3 significant + sign, two complement)
; ffffffff = fractional part (8 bits)
; N is Nan:
; 	0 for having even addresses in the square table
;	1 for illegal number
; The cannonical NaN is 00000000 00000001
; Square table is at 00010000 00000000
;                 to 00011111 11111111
; All numbers in the form of 00001iif fffffff0 have squares that overflow,
; (because they are larger than 4, so they square is larger than 8, the maxium)
; so there is opportunity to either squeeze more numbers in a rewrite (3.9 fixed point)
; or using less memory for the table
; Also, the least significant bits are not that important, 
; so we could move to a 4.12 or 5.11 fixed point representation
; (with loss of precision in squares)

; Default Mandelbrot coordinates
INITALX 		= $FBD0		; LEFT = 11111011 11010000 = -2.093
INITALY 		= $FDC0		; TOP  = 11111101 11000000 = -1.125
INITIALDX 		= $0026		; DX   = 00000000 00100110 = 0.073
INITIALDY 		= $0030		; DY   = 00000000 00110000 = 0.094

; Time to wait between two mandelbrot displays in "rought seconds"
WAITIME 		= 4			; Approx number of seconds to wait before going
							; to the next mandelbrot display

; Location of the square table (cannot be changed)
; It may be a good idea to support $E000-$EFFF for square table as well
; (for 4K+4K machines with RAM for BASIC)
SQUARETABLE 	= $1000		; This table cannot be moved
SQUARETABLE_END = $2000		; End of table

; Width and height of the screen
; Cannot be changed, but usefull to avoid magic numbers
SCREENWIDTH 	= 40
SCREENHEIGHT 	= 24

;-----------------------------------------------------------------------------
; Couple of macros easing the manipulation of 16 bits numbers
;-----------------------------------------------------------------------------

	; Loads A number into AX
#define MLOADAX(NUM) LDX NUM: LDA NUM+1

	; Stores AX into NUM
#define MSTOREAX(NUM) STX NUM: STA NUM+1

;-----------------------------------------------------------------------------
; Entry point
;-----------------------------------------------------------------------------

	JMP MAIN

;-----------------------------------------------------------------------------
; The data that defines how this whole thing looks
; Placed at the beginning for easier editing
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; One palette for each zoom level
;-----------------------------------------------------------------------------
PALETTE:
	.byte "..,'~=+:;[/<*?&O0X# XXXXXXXXXXXXXXXXXXXX"
	.byte "..,'~==+:;;[[/<*??&OO0X# XXXXXXXXXXXXXXX"
	.byte "..,''~==++::;;[[/<<**??&OO0X# XXXXXXXXXX"
	.byte "..,''~~==+++::;;[[/<<**??&&OO00XX# XXXXX"
	.byte "..,''~~==+++:::;;;[[[//<<***??&&OO00XX# "

	; Useful to debug
	; .byte "01234567890abcdefghijklmnopqrstuvwxyz!@#"
	; .byte "01234567890abcdefghijklmnopqrstuvwxyz!@#"
	; .byte "01234567890abcdefghijklmnopqrstuvwxyz!@#"
	; .byte "01234567890abcdefghijklmnopqrstuvwxyz!@#"
	; .byte "01234567890abcdefghijklmnopqrstuvwxyz!@#"

;-----------------------------------------------------------------------------
; The offset of each palette
; (Not ideal as it limits the total palette to < 256 chars)
; (A double indirection would be better)
;-----------------------------------------------------------------------------
PALETTEDELTA:
	.byte 0, 40, 80, 120, 160

;-----------------------------------------------------------------------------
; The number of iteration per zoom level
; This also defines each palette length
;-----------------------------------------------------------------------------
MAXITER:
	.byte 19, 24, 29, 34, 39

;-----------------------------------------------------------------------------
; If iteration is lower than ZOOMTRIGGERMIN, the point cannot be chosen
; as next position (too far away from the set0)
;-----------------------------------------------------------------------------
ZOOMTRIGGERMIN:
	.byte 15, 17, 18, 19, 20

;-----------------------------------------------------------------------------
; If iteration is larger or equal to ZOOMTRIGGERMAX, the poinr cannot be chosen
; as next position (too close to the set)
;-----------------------------------------------------------------------------
ZOOMTRIGGERMAX:
	.byte 20, 20, 21, 22, 23




;-----------------------------------------------------------------------------
; Main loop
;-----------------------------------------------------------------------------
MAIN:
.(
		; Initialize ZP constants
	LDA #0
	STA ABORT		; Will be $80 if user abort

		; Display intro
	JSR PRINTINLINE
.byte $d, $d
.byte "        --== Mandelbrot 65 ==--  ", $d, $d
.byte "A 6502 MANDELBROT & JULIA TIME WASTER", $d
.byte "                        FOR YOUR APPLE 1", $d, $d
.byte "                V1.0 BY FRED STARK, 2024"
.byte "       http://stark.fr/blog/mandelbrot65",$d,$d
.byte "        (PRESS ANY KEY TO START)", $d
.byte 0

		; If user aborted, we skip waiting for keypress
		; as we already collected entropy in the amount
		; of characters displayed
	BIT ABORT
	BMI SKIP

		; Wait for key and init SEED
	LDA KBD
LOOP:
	INC SEED
	LDA KBDCR
	BPL LOOP
	LDA KBD

SKIP:
#ifdef NONRANDOM
		; If you want repeatability
	LDA #$1
	STA SEED
#endif

		; Clear any potential previous abort
	LDA #0
	STA ABORT

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
		; Starts a full mandelbrot
	JSR INITIALPLACE

LOOP:
		; Load next place to go
	JSR GOTOPLACE

		; Make future next place standard mandelbrot
		; as a default
	JSR INITIALPLACE

		; A couple of lines between drawings
	LDA #$d
	JSR ECHO
	JSR ECHO

		; Clear ABORT flag
	LDA #0
	STA ABORT
		; Draw the mandelbrot set & pick a new spot
	JSR DRAWSET

		; Wait for a while (or key press)
	JSR WAIT			
	; BNE MANDELAUTO		; If non-space pressed, restart full mandelbrot

	JMP LOOP
.)

;-----------------------------------------------------------------------------
; Prints the string that is stored after the JSR instruction that sent us here
; Input:
;   Data stored in the code after the jsr instruction
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

		; We skip actual slow printing if abort was requested
	BIT ABORT
	BMI SKIP
	JSR ECHO

SKIP:
		; See if a key was pressed
	JSR KEYPRESSED
	BCC SKIP2
	LDA #$FF
	STA ABORT

		; Increment random seed with number of chars really displayed
	INC SEED

		; Incremement and next
SKIP2:
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
; Fills ZP "next" variables with the initial values
; Output:
;   ZP:NEXTX, ZP:NEXTY, ZP:NEXTDX, ZP:NEXTDY, ZP:NEXTZOOMLEVEL
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
; Output:
;   ZP:ABORT bit #7 sets if abort was requested
;-----------------------------------------------------------------------------
WAIT:
.(
		; If ABORT was requested, we exit
	BIT ABORT
	BMI DONE

		; Wait for around WAITIME seconds
	LDX #WAITIME*2				; Each double loop take around 1/2 second (0.72 seconds)
LOOP1:
	TXA
	PHA
	LDY #0
LOOP2:
	LDX #0
LOOP3:
	DEX
	BNE LOOP3
		; Exit if key pressed
	LDA KBDCR
	BMI KEY
	DEY
	BNE LOOP2
	PLA
	TAX
	DEX
	BNE LOOP1
DONE:
	RTS

KEY:
	LDA #$80
	STA ABORT
	PLA
	LDA KBD			; Clear key
	CMP #' '
	RTS
.)

;-----------------------------------------------------------------------------
; Has a key been pressed ?
; Output:
;   C if key
;   Z if key is ' '
;-----------------------------------------------------------------------------
KEYPRESSED:
.(
	LDA KBDCR
	BPL NOKEY

		; Key pressed
	LDA #$80
	STA ABORT

		; Read key
	LDA KBD
	CMP #' '					; Z if space
	SEC
	RTS
NOKEY:
	CLC							; No key, no Carry
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

	LDA #SCREENHEIGHT
	STA SCRNY
	MLOADAX(Y0)
	MSTOREAX(Y)
LOOP1:
	LDA #SCREENWIDTH
	STA SCRNX
	MLOADAX(X0)
	MSTOREAX(X)

LOOP2:
#ifdef DEBUG
	MLOADAX(X)
	JSR DBG_AX
	.byte "X:", 0
	MLOADAX(Y)
	JSR DBG_AX
	.byte " Y:", 0
	LDA #' '
	JSR ECHO
#endif

	JSR ITER

#ifdef DEBUG
	LDA #' '
	JSR ECHO
#endif

		; Get character
	JSR CHARFROMIT

		; To avoid scrolling when image is complete, we skip the last char
	TAX
	LDA SCRNY
	CMP #1			; Last line
	BNE CONTINUE
	LDA SCRNX
	CMP #1			; and last column
	BEQ DONE		; we stop

CONTINUE:
		; Handle keypress
	JSR KEYPRESSED
	BIT ABORT
	BMI DONE

		; Display character
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

DONE:
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
; Input:
;   ZP:FREQ number of previous choices (probability that this one is the right one)
;   ZP:X, ZP:Y, ZP:DX, ZP:DY, ZP:ZOOMLEVEL current position
;   ZP:NEXTX, ZP:NEXTY, ZP:NEXTDX, ZP:NEXTDY, ZP:NEXTZOOMLEVEL next position
; Output:
;   ZP:FREQ incremented
;   ZP:NEXTX, ZP:NEXTY, ZP:NEXTDX, ZP:NEXTDY, ZP:NEXTZOOMLEVEL next position
;-----------------------------------------------------------------------------
SELECTNEXT:
.(
	INC FREQ
	LDA FREQ
	JSR RNDCHOICE	; Sets Z 1/FREQ times
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
	LDX #SCREENWIDTH/2
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
	LDX #SCREENHEIGHT/2
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
; Sets Z flag 1/A times
; Fundamentally we compute (A%Z)==1, quite slowly
; Input:
;   A: FREQ
; Output:
;   Z flag: set 1/FREQ times
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
	TXA				; If X will be equal to 1 1/FREQ times
	CMP #1			; Test A%Z == 1
	RTS
.)

;-----------------------------------------------------------------------------
; Return a random number in A
; Only an 8 bits seed, 255 different sequences
; Source: https://codebase64.org/doku.php?id=base:small_fast_8-bit_prng
; Input:
;   ZP:SEED seed
; Output:
;   A random number
;   SEED updated
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
; Increments PTR
; Input:
;  ZP:PTR, ZP:PTR+1
; Output:
;  ZP:PTR, ZP:PTR+1 is incremented
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
; Compute one set of mandelbrot iterations
; Input:
;   ZP:X, ZP:Y contains the current position
; Output:
;   ZP:IT iteration counter
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

#ifdef DEBUG
	PHP
	MLOADAX(ZX)
	JSR DBG_AX
	.byte "ZX:", 0
	MLOADAX(ZY)
	JSR DBG_AX
	.byte " ZY:", 0
	LDA #' '
	JSR ECHO
	PLP
#endif

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
; Compute one mandelbrot iteration
; Inputs:
;   ZP:ZX, ZP:ZY, ZP:ZX2, ZP:ZY2
; Outputs:
;   ZP:ZX, ZP:ZY, ZP:ZX2, ZP:ZY2
;   C if overflow or stop
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
	BCS DIVERGE

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

	; zx2 = zx^2
	MLOADAX(ZX)
	JSR SQUARE
	BCS DIVERGE
	MSTOREAX(ZX2)

	; zy2 = zy^2
	MLOADAX(ZY)
	JSR SQUARE
	BCS DIVERGE
	MSTOREAX(ZY2)

DONE:
	CLC
	RTS

DIVERGE:
	SEC
	RTS
.)

;-----------------------------------------------------------------------------
; Returns the correct char for current iteration
; Input:
;   ZP:IT the iteration number
;   ZP:ZOOMLEVEL the current zoom level
; Output:
;   A: the character to be displayed
;-----------------------------------------------------------------------------
CHARFROMIT:
.(
	LDA IT
	LDY ZOOMLEVEL
	CLC
	ADC PALETTEDELTA,Y	; A = PALETTEDELTA[ZOOMLEVEL] + IT
	TAY
	LDA PALETTE,Y		; PALETTE[A]
	RTS
.)

;-----------------------------------------------------------------------------
; Input:
;   A,X: number
; Output
;   A,X: AX^2
;   Carry if overflow
;-----------------------------------------------------------------------------
SQUARE:
.(
	JSR ABS				; Absolute value
	CMP #$08
	BPL DONENAN			; Larger than 4, we overflow the table (faster than ANDing with F0)
	ORA #$10			; Set square table address bit (0x1000)
	STX PTR
	STA PTR+1
	LDY #0
	LDA (PTR),Y
	CMP #1
	BEQ DONENAN
	TAX
	INY
	LDA (PTR),Y
DONE:
	CLC
	RTS
DONENAN:
	SEC
	RTS	
.)

;-----------------------------------------------------------------------------
; Input:
;   A,X: valid number
; Output
;   A,X: abs(AX)
;-----------------------------------------------------------------------------
ABS:
.(
	ORA #0
	BMI NEG					; Neg if negative
DONE:
	RTS
.)

;-----------------------------------------------------------------------------
; Input:
;   A,X: valid number
; Output
;   A,X: -AX
;-----------------------------------------------------------------------------
NEG:
.(
	PHA
	TXA
	EOR #$FF				; Complement of X
	CLC
	ADC #1					; +1
	TAX
	PLA
	EOR #$FF				; Complement of A
	ADC #0
	RTS
.)

;-----------------------------------------------------------------------------
; Some macros to deal with the filling of the square table
;-----------------------------------------------------------------------------

	; Zeroes a **T**hree bytes variable
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
	BPL POSITIVE			; PRINTS '+' AND NUMBER
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
.(
	ASL TMP1
	ROL TMP1+1
	RTS
.)

	; Add TMP2 to TMP1
ADDTMP1:
.(
	CLC
	LDA TMP1
	ADC TMP2
	STA TMP1
	LDA TMP1+1
	ADC TMP2+1
	STA TMP1+1
	RTS
.)

#endif
