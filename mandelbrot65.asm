
* = $0280
FACC = $00

NUM = $02  ; 3 bytes
INCR = $05 ; 3 bytes
PTR = $08
TMP = $0A
NAN = $0B
SCRNX = $0C
SCRNY = $0D

X0 = $0E
Y0 = $10
DX = $12
DY = $14

X = $16
Y = $18

; Format of numbers (16 bits, stored little endian -- reversed from this drawing)
; +-+-+-+-+-+-+-+-+ +-+-+-+-+-+-+-+-+
; |S| | |1|i|i|i|f| |f|f|f|f|f|f|f|0|
; +-+-+-+-+-+-+-+-+ +-+-+-+-+-+-+-+-+
; S = Sign
; 1 is for addressing 0x1000 for square table
; iii = integer part (3 bits)
; ffffffff = fractional part (8 bits)
; 0 is for having even addresses in the square table

SIGNBIT = $80
NUMBIT = $10

ECHO = $FFEF
WOZMON = $FF00
PRBYTE = $FFDC

SQUARETABLE = $1000			; This table cannot be moved
SQUARETABLE_END = $2000		; End of table

#define MZEROT(ADRS) LDA #0:STA ADRS:STA ADRS+1:STA ADRS+2

	; Increments
#define MINCW(ADRS) LDA ADRS:CLC:ADC #1:STA ADRS:LDA ADRS+1:ADC #0:STA ADRS+1
#define MINCT(ADRS) LDA ADRS:CLC:ADC #1:STA ADRS:LDA ADRS+1:ADC #0:STA ADRS+1:LDA ADRS+2:ADC #0:STA ADRS+2
#define MINC2W(ADRS) LDA ADRS:CLC:ADC #2:STA ADRS:LDA ADRS+1:ADC #0:STA ADRS+1

	; Additions
#define MADDT(DEST,SRC) LDA DEST:CLC:ADC SRC:STA DEST:LDA DEST+1:ADC SRC+1:STA DEST+1:LDA DEST+2:ADC SRC+2:STA DEST+2

	; Load effective address
#define MLEA(DEST,ADRS) LDA #<ADRS:STA DEST:LDA #>ADRS:STA DEST+1

	; Creates a zero in (AX)
#define MZEROAX LDX #$0: LDA #NUMBIT

	; Loads A number into AX
#define MLOADAX(NUM) LDX NUM: LDA NUM+1

	; Stores AX into NUM
#define MSTOREAX(NUM) STX NUM: STA NUM+1

	; Z if NUM is NaN
#define MISNAN(NUM) LDA NUM+1: AND #NUMBIT

	; Push (A,X) into stack
#define MPUSHAX PHA: STA TMP: TXA: PHA: LDA TMP

	; Restore (A,X) from stack
#define MPULLAX PLA: TAX: PLA

; Load square of number in (A,X)
; Does not manage NaNs
; Z set if NaN
#define SQUARE(NUM) LDY #0: LDA (NUM),Y: TAX: INY: LDA (NUM),Y: BIT NAN

	LDA #$0D
	JSR ECHO
	JSR ECHO

	LDA #NUMBIT
	STA NAN   ; Bit mask for NaN
	JSR FILLSQUARES

; Initialize variables
		; X0 = -1.5
	LDA #%00000000
	STA X0
	LDA #%10010011
	STA X0+1
	MLOADAX(X0)
	JSR PRINT_AX

		; Y0 = -1
	LDA #%00000000
	STA Y0
	LDA #%10010010
	STA Y0+1
	; MLOADAX(Y0)
	; JSR PRINT_AX

		; DX = 0.05
	LDA #%00011010
	STA DX
	LDA #%00010000
	STA DX+1
	; MLOADAX(DX)
	; JSR PRINT_AX

		; DY = 0.05
	LDA #%00011010
	STA DY
	LDA #%00010000
	STA DY+1
	; MLOADAX(DY)
	; JSR PRINT_AX

; Draw mandelbrot
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
		; Move X to next position in set
	MLOADAX(DX)
	MSTOREAX(NUM)
	MLOADAX(X)
	JSR ADD_AX_SS
	MSTOREAX(X)

	DEC SCRNX
	BNE LOOP2

		; Move Y to next position in set
	MLOADAX(DY)
	MSTOREAX(NUM)
	MLOADAX(Y)
	JSR ADD_AX_SS
	MSTOREAX(Y)

	DEC SCRNY
	BNE LOOP1
	RTS

ITER:
	MLOADAX(X)
	JSR PRINT_AX
	MLOADAX(Y)
	JSR PRINT_AX
	LDA #' '
	JSR ECHO
	RTS

	LDA #$16
	LDX #$28
	JSR PRINT_AX

	LDA #$0D
	JSR ECHO

	LDA #$16
	LDX #$28
	MSTOREAX(NUM)
	JSR ADD_AX_SS
	JSR PRINT_AX

	MPUSHAX
	LDA #$0D
	JSR ECHO
	MPULLAX
	JSR SUB_AX_SS
	JSR PRINT_AX

	LDA #$0D
	JSR ECHO
	JSR ECHO

	LDA #$13
	LDX #$28
	JSR PRINT_AX
	LDA #'^': JSR ECHO
	LDA #'2': JSR ECHO
	LDA #'=': JSR ECHO
	LDA #$13
	LDX #$28
	MSTOREAX(NUM)
	; LDY #0
	; LDA (NUM),Y
	; TAX
	; INY
	; LDA (NUM),Y
	SQUARE(NUM)
	JSR PRINT_AX
	MSTOREAX(NUM)
	LDA #' '
	JSR ECHO
	SQUARE(NUM)
	JSR PRINT_AX
	MSTOREAX(NUM)
	LDA #' '
	JSR ECHO
	SQUARE(NUM)
	JSR PRINT_AX

	LDA #$0D
	JSR ECHO
	JSR ECHO

	JMP WOZMON

		; Clear screen
	JSR FILLSQUARES
	JMP WOZMON

	; Fill square table with squares of numbers
FILLSQUARES:
		; NUM = INCR = 0
	MZEROT(NUM)
	MZEROT(INCR)

		; Pointer to square table
	MLEA(PTR,SQUARETABLE)

LOOP:
		; Store current square value
	LDY #0
	LDA NUM+1
	CLC
	ROL
	STA (PTR),Y
	LDA NUM+2
	ROL
	ORA #NUMBIT
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
		; 0,0 is not a number (missing the NUMBIT)
	LDY #0
	LDA #0
	STA (PTR),Y
	INY
	STA (PTR),Y

			; Increment pointer
	MINC2W(PTR)

	JMP FILLNAN

; IN (X,A) = NUMBER
; OUT (X,A) = NUMBER^2
; SQUARE:
; 	STX FACC
; 	STA FACC+1
; 	LDY #0
; 	LDA (FACC),Y
; 	TAX
; 	LDA (FACC+1),Y
; 	RTS



	; Adds NUM with AX
	; NUM & AX are of same sign
	; Z if overflow
ADD_AX_SS:
	CLC
	PHA
	TXA
	ADC NUM
	TAX
	PLA
	ADC NUM+1
	EOR #NUMBIT
	RTZ
	AND #$8F 	; Clear unused bits (so next operation don't overflow into sign)
	ORA #NUMBIT ; Sets Number bit
	RTS

	; Substract NUM from AX. AX must be greater than NUM.
SUB_AX_SS:
	SEC
	PHA
	TXA
	SBC NUM
	TAX
	PLA
	SBC NUM+1
	AND #$8F 	; Clear unused bits (so next operation don't overflow into sign)
	ORA #NUMBIT ; Sets Number bit
	RTS

	; Prints the number. No change to any register. Trashes TMP
PRINT_AX:
	PHP
	MPUSHAX
	BIT NAN
	BEQ PRINT_NAN
	PHA
	AND #SIGNBIT
	BEQ POSITIVE
	LDA #'-'
	JMP PRINTSIGN
POSITIVE:
	LDA #'+'
PRINTSIGN:
	JSR ECHO
	PLA
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
	JSR PRBYTE
PRINT_EXIT:
	MPULLAX
	PLP
	RTS
PRINT_NAN:
	LDA #'<'
	JSR ECHO
	LDA #'N'
	JSR ECHO
	LDA #'A'
	JSR ECHO
	LDA #'N'
	JSR ECHO
	LDA #'>'
	JSR ECHO
	JMP PRINT_EXIT