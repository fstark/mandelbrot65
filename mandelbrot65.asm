
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

TMP1 = $1A
TMP2 = $1C

PTR2 = $1E

NUM1 = $20
NUM2 = $22
RES1 = $24
RES2 = $26

; Format of numbers (16 bits, stored little endian -- reversed from this drawing)
;         A                 X
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

	JSR PRINTINLINE
.byte "Mandelbrot 65", 0

	LDA #$0D
	JSR ECHO
	JSR ECHO

	LDA #NUMBIT
	STA NAN   ; Bit mask for NaN
	JSR FILLSQUARES

	JMP TEST

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

; Increments PTR`
INCPTR:
.(
	CLC
	INC PTR
	BNE DONE
	INC PTR+1
DONE:
	RTS
.)

; Prints the string that is stored after the JSR instruction that sent us here
PRINTINLINE:
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
.(
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
.)

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
.(
	CLC
	PHA
	TXA
	ADC NUM
	TAX
	PLA
	ADC NUM+1
	BIT NAN     ; We expect NAN to be cleared due to the addition
				; of two NUBITS and the lack of overflow
	BNE ERROR
	AND #$8F 	; Clear unused bits (so next operation don't overflow into sign)
	ORA #NUMBIT ; Sets Number bit
	RTS
ERROR:
	LDA #0	; Z = 1
	RTS
.)

	; Sub NUM from AX
	; NUM & AX are of same sign
	; Z if overflow
SUB_AX_SS:
.(
	SEC
	PHA
	TXA
	SBC NUM
	TAX
	PLA
	SBC NUM+1
	BIT NAN     ; We expect NAN to be cleared due to the addition
				; of two NUBITS and the lack of overflow
	BNE ERROR
	AND #$8F 	; Clear unused bits (so next operation don't overflow into sign)
	ORA #NUMBIT ; Sets Number bit
	RTS
ERROR:
	LDA #0	; Z = 1
	RTS
.)

	; Prints the number. No change to any register. Trashes TMP and PTR
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
	JSR PRFRACT
PRINT_EXIT:
	MPULLAX
	PLP
	RTS
PRINT_NAN:
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

TEST:
.(
	JSR PRINTINLINE
	.byte " NUM1     NUM2   EXPECTED   RESULT", $d, 0
	MLEA(PTR2,TESTDATA)
LOOP:
		; Print first number
	LDY #0
	LDA (PTR2),Y
	CMP #$FF
	BNE CONTINUE
	RTS
CONTINUE:
	TAX
	INY
	LDA (PTR2),Y
	MSTOREAX(NUM1)
	JSR PRINT_AX
	MINC2W(PTR2)

	JSR PRINTINLINE
	.byte " + ", 0

		; Print second number
	LDY #0
	LDA (PTR2),Y
	TAX
	INY
	LDA (PTR2),Y
	JSR PRINT_AX
	MSTOREAX(NUM2)
	MINC2W(PTR2)

	JSR PRINTINLINE
	.byte " = ", 0

		; Print third number
	LDY #0
	LDA (PTR2),Y
	TAX
	INY
	LDA (PTR2),Y
	MSTOREAX(RES1)
	JSR PRINT_AX
	MINC2W(PTR2)

	JSR PRINTINLINE
	.byte " vs ", 0

		; Compute sum

	LDA NUM1+1
	BMI NEG1
	LDA NUM2+1
	BPL SUM	; Both numbers are positive
			; We do a normal addition
	JMP DIFF
			; We do a difference

NEG1:	; First number is negative
	LDA NUM2+1
	BMI SUM	; Both numbers are negative
			; We do a normal addition
DIFF:
		; We do a difference
	MLOADAX(NUM1)
	MSTOREAX(NUM)
	MLOADAX(NUM2)
	JSR SUB_AX_SS
	BNE OK
	LDX #0
	LDA #0
	JMP OK

SUM:
	MLOADAX(NUM1)
	MSTOREAX(NUM)
	MLOADAX(NUM2)
	JSR ADD_AX_SS
	BNE OK
	LDX #0
	LDA #0
OK:
	MSTOREAX(RES2)
	JSR PRINT_AX

		; Check result
	LDA #' ' ; OK
	JSR ECHO
	LDA RES1
	CMP RES2
	BNE ERROR
	LDA RES1+1
	CMP RES2+1
	BNE ERROR
	JMP DISPLAY
ERROR:
	LDA #'*' ; Error
DISPLAY:
	JSR ECHO

	LDA #$d
	JSR ECHO

	JMP LOOP
.)

TESTDATA:
.byte $3C,$9D,$3A,$9A,$00,$00	;  -6.617188 + -5.113281 = <NaN>
.byte $8E,$19,$D4,$19,$00,$00	;  4.777344 + 4.914062 = <NaN>
.byte $6A,$98,$AC,$1C,$42,$14	;  -4.207031 + 6.335938 = 2.128906
.byte $C6,$1A,$04,$9F,$3E,$94	;  5.386719 + -7.507812 = -2.121094
.byte $B4,$96,$D8,$12,$DC,$93	;  -3.351562 + 1.421875 = -1.929688
.byte $46,$9B,$0E,$14,$38,$97	;  -5.636719 + 2.027344 = -3.609375
.byte $62,$11,$1E,$10,$80,$11	;  0.691406 + 0.058594 = 0.750000
.byte $7A,$9C,$DA,$13,$A0,$98	;  -6.238281 + 1.925781 = -4.312500
.byte $14,$19,$DA,$1E,$00,$00	;  4.539062 + 7.425781 = <NaN>
.byte $58,$12,$78,$1F,$00,$00	;  1.171875 + 7.734375 = <NaN>
.byte $6C,$1A,$BC,$16,$00,$00	;  5.210938 + 3.367188 = <NaN>
.byte $22,$1D,$DC,$18,$00,$00	;  6.566406 + 4.429688 = <NaN>
.byte $70,$9C,$10,$1B,$60,$91	;  -6.218750 + 5.531250 = -0.687500
.byte $46,$9A,$C2,$9D,$00,$00	;  -5.136719 + -6.878906 = <NaN>
.byte $DE,$93,$46,$1E,$68,$1A	;  -1.933594 + 7.136719 = 5.203125
.byte $DC,$13,$9A,$17,$76,$1B	;  1.929688 + 3.800781 = 5.730469
.byte $F4,$9B,$1E,$16,$D6,$95	;  -5.976562 + 3.058594 = -2.917969
.byte $24,$1A,$56,$14,$7A,$1E	;  5.070312 + 2.167969 = 7.238281
.byte $CA,$12,$EA,$14,$B4,$17	;  1.394531 + 2.457031 = 3.851562
.byte $06,$1E,$16,$1C,$00,$00	;  7.011719 + 6.042969 = <NaN>
.byte $76,$10,$42,$9D,$CC,$9C	;  0.230469 + -6.628906 = -6.398438
.byte $D8,$18,$2A,$9E,$52,$95	;  4.421875 + -7.082031 = -2.660156
.byte $92,$1B,$EE,$9A,$A4,$10	;  5.785156 + -5.464844 = 0.320312
.byte $66,$1E,$A6,$14,$00,$00	;  7.199219 + 2.324219 = <NaN>
.byte $5E,$93,$BE,$10,$A0,$92	;  -1.683594 + 0.371094 = -1.312500
.byte $D4,$1C,$F2,$98,$E2,$13	;  6.414062 + -4.472656 = 1.941406
.byte $2E,$10,$F6,$19,$24,$1A	;  0.089844 + 4.980469 = 5.070312
.byte $EA,$1F,$BE,$13,$00,$00	;  7.957031 + 1.871094 = <NaN>
.byte $BA,$1D,$A8,$91,$12,$1C	;  6.863281 + -0.828125 = 6.035156
.byte $FE,$15,$90,$12,$8E,$18	;  2.996094 + 1.281250 = 4.277344
.byte $64,$93,$26,$96,$8A,$99	;  -1.695312 + -3.074219 = -4.769531
.byte $D4,$95,$A8,$10,$2C,$95	;  -2.914062 + 0.328125 = -2.585938
.byte $54,$97,$FE,$92,$52,$9A	;  -3.664062 + -1.496094 = -5.160156
.byte $4E,$92,$76,$1B,$28,$19	;  -1.152344 + 5.730469 = 4.578125
.byte $60,$95,$4A,$94,$AA,$99	;  -2.687500 + -2.144531 = -4.832031
.byte $C0,$9F,$36,$9C,$00,$00	;  -7.875000 + -6.105469 = <NaN>
.byte $2A,$17,$18,$19,$00,$00	;  3.582031 + 4.546875 = <NaN>
.byte $60,$9A,$BC,$12,$A4,$97	;  -5.187500 + 1.367188 = -3.820312
.byte $22,$99,$46,$93,$68,$9C	;  -4.566406 + -1.636719 = -6.203125
.byte $16,$10,$80,$13,$96,$13	;  0.042969 + 1.750000 = 1.792969
.byte $D4,$99,$9E,$15,$36,$94	;  -4.914062 + 2.808594 = -2.105469
.byte $8E,$1A,$5C,$16,$00,$00	;  5.277344 + 3.179688 = <NaN>
.byte $6C,$90,$D4,$9C,$40,$9D	;  -0.210938 + -6.414062 = -6.625000
.byte $CE,$12,$B2,$92,$1C,$10	;  1.402344 + -1.347656 = 0.054688
.byte $82,$11,$34,$97,$B2,$95	;  0.753906 + -3.601562 = -2.847656
.byte $DE,$1F,$1E,$1E,$00,$00	;  7.933594 + 7.058594 = <NaN>
.byte $5A,$1B,$BC,$12,$16,$1E	;  5.675781 + 1.367188 = 7.042969
.byte $7A,$17,$FA,$9B,$80,$94	;  3.738281 + -5.988281 = -2.250000
.byte $8C,$97,$D4,$9A,$00,$00	;  -3.773438 + -5.414062 = <NaN>
.byte $D0,$97,$14,$13,$BC,$94	;  -3.906250 + 1.539062 = -2.367188
.byte $98,$19,$24,$11,$BC,$1A	;  4.796875 + 0.570312 = 5.367188
.byte $DE,$16,$C2,$10,$A0,$17	;  3.433594 + 0.378906 = 3.812500
.byte $F0,$12,$CC,$9A,$DC,$97	;  1.468750 + -5.398438 = -3.929688
.byte $CE,$93,$CE,$19,$00,$16	;  -1.902344 + 4.902344 = 3.000000
.byte $A2,$1A,$04,$9B,$62,$90	;  5.316406 + -5.507812 = -0.191406
.byte $B2,$92,$7C,$96,$2E,$99	;  -1.347656 + -3.242188 = -4.589844
.byte $9A,$1A,$90,$10,$2A,$1B	;  5.300781 + 0.281250 = 5.582031
.byte $6E,$97,$E2,$12,$8C,$94	;  -3.714844 + 1.441406 = -2.273438
.byte $BA,$13,$60,$1B,$1A,$1F	;  1.863281 + 5.687500 = 7.550781
.byte $1C,$97,$C4,$9A,$00,$00	;  -3.554688 + -5.382812 = <NaN>
.byte $1E,$93,$76,$11,$A8,$91	;  -1.558594 + 0.730469 = -0.828125
.byte $F0,$93,$C4,$97,$B4,$9B	;  -1.968750 + -3.882812 = -5.851562
.byte $CE,$9B,$76,$9C,$00,$00	;  -5.902344 + -6.230469 = <NaN>
.byte $F6,$14,$5A,$15,$50,$1A	;  2.480469 + 2.675781 = 5.156250
.byte $6C,$11,$26,$9A,$BA,$98	;  0.710938 + -5.074219 = -4.363281
.byte $22,$11,$B6,$13,$D8,$14	;  0.566406 + 1.855469 = 2.421875
.byte $FE,$16,$B4,$10,$B2,$17	;  3.496094 + 0.351562 = 3.847656
.byte $D4,$92,$12,$96,$E6,$98	;  -1.414062 + -3.035156 = -4.449219
.byte $9C,$1E,$5E,$19,$00,$00	;  7.304688 + 4.683594 = <NaN>
.byte $90,$93,$40,$19,$B0,$15	;  -1.781250 + 4.625000 = 2.843750
.byte $F2,$98,$BE,$19,$CC,$10	;  -4.472656 + 4.871094 = 0.398438
.byte $8A,$94,$58,$9E,$00,$00	;  -2.269531 + -7.171875 = <NaN>
.byte $02,$13,$0A,$14,$0C,$17	;  1.503906 + 2.019531 = 3.523438
.byte $8A,$14,$44,$99,$BA,$94	;  2.269531 + -4.632812 = -2.363281
.byte $96,$90,$6E,$1D,$D8,$1C	;  -0.292969 + 6.714844 = 6.421875
.byte $AE,$14,$4C,$1C,$00,$00	;  2.339844 + 6.148438 = <NaN>
.byte $98,$17,$8E,$96,$0A,$11	;  3.796875 + -3.277344 = 0.519531
.byte $C4,$92,$82,$9B,$46,$9E	;  -1.382812 + -5.753906 = -7.136719
.byte $B2,$15,$1A,$95,$98,$10	;  2.847656 + -2.550781 = 0.296875
.byte $D8,$19,$E4,$98,$F4,$10	;  4.921875 + -4.445312 = 0.476562
.byte $C2,$10,$06,$95,$44,$94	;  0.378906 + -2.511719 = -2.132812
.byte $78,$9C,$74,$10,$04,$9C	;  -6.234375 + 0.226562 = -6.007812
.byte $AE,$1B,$B4,$10,$62,$1C	;  5.839844 + 0.351562 = 6.191406
.byte $62,$1A,$00,$9D,$9E,$92	;  5.191406 + -6.500000 = -1.308594
.byte $EE,$95,$78,$90,$66,$96	;  -2.964844 + -0.234375 = -3.199219
.byte $40,$1C,$D4,$19,$00,$00	;  6.125000 + 4.914062 = <NaN>
.byte $FA,$11,$4A,$98,$50,$96	;  0.988281 + -4.144531 = -3.156250
.byte $7C,$1B,$04,$9B,$78,$10	;  5.742188 + -5.507812 = 0.234375
.byte $8C,$9B,$BA,$18,$D2,$92	;  -5.773438 + 4.363281 = -1.410156
.byte $48,$94,$E0,$13,$68,$90	;  -2.140625 + 1.937500 = -0.203125
.byte $DE,$1E,$E6,$96,$F8,$17	;  7.433594 + -3.449219 = 3.984375
.byte $E0,$18,$74,$16,$54,$1F	;  4.437500 + 3.226562 = 7.664062
.byte $8C,$12,$30,$91,$5C,$11	;  1.273438 + -0.593750 = 0.679688
.byte $F2,$1A,$C2,$97,$30,$13	;  5.472656 + -3.878906 = 1.593750
.byte $B8,$19,$CA,$14,$82,$1E	;  4.859375 + 2.394531 = 7.253906
.byte $0E,$18,$86,$95,$88,$12	;  4.027344 + -2.761719 = 1.265625
.byte $88,$97,$96,$1B,$0E,$14	;  -3.765625 + 5.792969 = 2.027344
.byte $5E,$9C,$24,$93,$82,$9F	;  -6.183594 + -1.570312 = -7.753906
.byte $B6,$93,$06,$1E,$50,$1A	;  -1.855469 + 7.011719 = 5.156250
.byte $24,$90,$0E,$1F,$EA,$1E	;  -0.070312 + 7.527344 = 7.457031
.byte $ff
