; Parts of Mandelbrot65 that ewere used for tests but are not useful anymore

MARKER = $FF

;-----------------------------------------------------------------------------
; Input AX
; If number is NAN or OVERFLOW, make it 00 01
; Set carry to 1
;-----------------------------------------------------------------------------
NORMALIZE:
.(
	PHA
	TXA
	BIT NAN
	BNE MAKENAN
	PLA
	PHA
	CLC
	AND #$90		; Isolate sign bit and overflow bit
	ADC #$70		; Propagate overflow to sign
	AND #$80		; If signed is zero then no overflow
	BNE MAKENAN
	PLA
	RTS
MAKENAN:
	PLA
	LDA #0
	LDX #1
	RTS
.)



;-----------------------------------------------------------------------------
; Print A as an HEX value
; Does not trash A
;-----------------------------------------------------------------------------
PRHEX:
.(
	PHA
	JSR PRBYTE
	PLA
	RTS
.)

;-----------------------------------------------------------------------------
; Prints A as a binary value
; Does not trash A
;-----------------------------------------------------------------------------
PRBIN:
.(
	STA TMP
	PHA
	TXA
	PHA
	LDA TMP
	LDX #8
LOOP:
	ROL
	PHA
	LDA #'0'
	ADC #0
	JSR ECHO
	PLA
	DEX
	BNE LOOP
NEXT:
	PLA
	TAX
	PLA
	RTS
.)

TESTPRINT:
.(
	JSR PRINTINLINE
	.byte "TESTING PRINT ROUTINES", $d, 0
	MLEA(PTR2,TESTDATA)
LOOP:
	; Print first number
	LDY #0
	LDA (PTR2),Y
	CMP #MARKER
	BNE CONTINUE
	RTS
CONTINUE:
	TAX
	INY
	LDA (PTR2),Y
	PHA
	PHA
	JSR PRHEX
	LDA #' '
	JSR ECHO
	PLA
	JSR PRBIN
	LDA #' '
	JSR ECHO
	TXA
	PHA
	JSR PRHEX
	LDA #' '
	JSR ECHO
	PLA
	JSR PRBIN
	LDA #' '
	JSR ECHO
	PLA
	MSTOREAX(NUM1)
	JSR PRINT_AX
	LDA #$0d
	JSR ECHO
	MINC2W(PTR2)
	JMP LOOP
.)

TESTADD:
.(
	JSR PRINTINLINE
	.byte " NUM1     NUM2   EXPECTED   RESULT", $d, 0
	MLEA(PTR2,TESTDATA)
LOOP:
		; Print first number
	LDY #0
	LDA (PTR2),Y
	CMP #MARKER
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

HERE:
		; Compute sum
	CLC
	LDA NUM1
	ADC NUM2
	TAX
	LDA NUM1+1
	ADC NUM2+1
	JSR NORMALIZE
	MSTOREAX(RES2)
	JSR PRINT_AX

		; Check result
	LDA #' '
	JSR ECHO
	LDA RES1
	CMP RES2
	BNE ERROR
	LDA RES1+1
	CMP RES2+1
	BNE ERROR
	LDA #' ' ; OK
	JMP DISPLAY
ERROR:
	LDA #'*' ; Error
DISPLAY:
	JSR ECHO

	LDA #$d
	JSR ECHO

	JMP LOOP
.)

MAKENUM:
.(
	PHA
	TXA
	CLC
	ROL
	TAX
	PLA
	ROL
	RTS
.)

TESTSQUARE:
.(
	; LDA #1
	; LDX #128
	; JSR MAKENUM
	; JSR PRINT_AX
	; JSR SQUARE
	; JSR PRINT_AX

	JSR PRINTINLINE
	.byte " NUM     SQUARE", $d, 0
	MLEA(PTR2,TESTSQUAREDATA)
LOOP:
		; Print first number
	LDY #0
	LDA (PTR2),Y
	CMP #MARKER
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
	.byte "^2=", 0

	MLOADAX(NUM1)
	JSR SQUARE
	JSR PRINT_AX

	LDA #$d
	JSR ECHO

	JMP LOOP
.)

TESTDATA:
.byte $C6,$0A,$FC,$F0,$C2,$FB	;  5.386719 + -7.507812 = -2.121094
.byte $96,$F7,$AC,$0C,$42,$04	;  -4.207031 + 6.335938 = 2.128906
.byte $C4,$F2,$C6,$F5,$01,$00	;  -6.617188 + -5.113281 = <NaN>
.byte $8E,$09,$D4,$09,$01,$00	;  4.777344 + 4.914062 = <NaN>
.byte $4C,$F9,$D8,$02,$24,$FC	;  -3.351562 + 1.421875 = -1.929688
.byte $BA,$F4,$0E,$04,$C8,$F8	;  -5.636719 + 2.027344 = -3.609375
.byte $62,$01,$1E,$00,$80,$01	;  0.691406 + 0.058594 = 0.750000
.byte $86,$F3,$DA,$03,$60,$F7	;  -6.238281 + 1.925781 = -4.312500
.byte $14,$09,$DA,$0E,$01,$00	;  4.539062 + 7.425781 = <NaN>
.byte $58,$02,$78,$0F,$01,$00	;  1.171875 + 7.734375 = <NaN>
.byte $6C,$0A,$BC,$06,$01,$00	;  5.210938 + 3.367188 = <NaN>
.byte $22,$0D,$DC,$08,$01,$00	;  6.566406 + 4.429688 = <NaN>
.byte $90,$F3,$10,$0B,$A0,$FE	;  -6.218750 + 5.531250 = -0.687500
.byte $BA,$F5,$3E,$F2,$01,$00	;  -5.136719 + -6.878906 = <NaN>
.byte $22,$FC,$46,$0E,$68,$0A	;  -1.933594 + 7.136719 = 5.203125
.byte $DC,$03,$9A,$07,$76,$0B	;  1.929688 + 3.800781 = 5.730469
.byte $0C,$F4,$1E,$06,$2A,$FA	;  -5.976562 + 3.058594 = -2.917969
.byte $24,$0A,$56,$04,$7A,$0E	;  5.070312 + 2.167969 = 7.238281
.byte $CA,$02,$EA,$04,$B4,$07	;  1.394531 + 2.457031 = 3.851562
.byte $06,$0E,$16,$0C,$01,$00	;  7.011719 + 6.042969 = <NaN>
.byte $76,$00,$BE,$F2,$34,$F3	;  0.230469 + -6.628906 = -6.398438
.byte $D8,$08,$D6,$F1,$AE,$FA	;  4.421875 + -7.082031 = -2.660156
.byte $92,$0B,$12,$F5,$A4,$00	;  5.785156 + -5.464844 = 0.320312
.byte $66,$0E,$A6,$04,$01,$00	;  7.199219 + 2.324219 = <NaN>
.byte $A2,$FC,$BE,$00,$60,$FD	;  -1.683594 + 0.371094 = -1.312500
.byte $D4,$0C,$0E,$F7,$E2,$03	;  6.414062 + -4.472656 = 1.941406
.byte $2E,$00,$F6,$09,$24,$0A	;  0.089844 + 4.980469 = 5.070312
.byte $EA,$0F,$BE,$03,$01,$00	;  7.957031 + 1.871094 = <NaN>
.byte $BA,$0D,$58,$FE,$12,$0C	;  6.863281 + -0.828125 = 6.035156
.byte $FE,$05,$90,$02,$8E,$08	;  2.996094 + 1.281250 = 4.277344
.byte $9C,$FC,$DA,$F9,$76,$F6	;  -1.695312 + -3.074219 = -4.769531
.byte $2C,$FA,$A8,$00,$D4,$FA	;  -2.914062 + 0.328125 = -2.585938
.byte $AC,$F8,$02,$FD,$AE,$F5	;  -3.664062 + -1.496094 = -5.160156
.byte $B2,$FD,$76,$0B,$28,$09	;  -1.152344 + 5.730469 = 4.578125
.byte $A0,$FA,$B6,$FB,$56,$F6	;  -2.687500 + -2.144531 = -4.832031
.byte $40,$F0,$CA,$F3,$01,$00	;  -7.875000 + -6.105469 = <NaN>
.byte $2A,$07,$18,$09,$01,$00	;  3.582031 + 4.546875 = <NaN>
.byte $A0,$F5,$BC,$02,$5C,$F8	;  -5.187500 + 1.367188 = -3.820312
.byte $DE,$F6,$BA,$FC,$98,$F3	;  -4.566406 + -1.636719 = -6.203125
.byte $16,$00,$80,$03,$96,$03	;  0.042969 + 1.750000 = 1.792969
.byte $2C,$F6,$9E,$05,$CA,$FB	;  -4.914062 + 2.808594 = -2.105469
.byte $8E,$0A,$5C,$06,$01,$00	;  5.277344 + 3.179688 = <NaN>
.byte $94,$FF,$2C,$F3,$C0,$F2	;  -0.210938 + -6.414062 = -6.625000
.byte $CE,$02,$4E,$FD,$1C,$00	;  1.402344 + -1.347656 = 0.054688
.byte $82,$01,$CC,$F8,$4E,$FA	;  0.753906 + -3.601562 = -2.847656
.byte $DE,$0F,$1E,$0E,$01,$00	;  7.933594 + 7.058594 = <NaN>
.byte $5A,$0B,$BC,$02,$16,$0E	;  5.675781 + 1.367188 = 7.042969
.byte $7A,$07,$06,$F4,$80,$FB	;  3.738281 + -5.988281 = -2.250000
.byte $74,$F8,$2C,$F5,$01,$00	;  -3.773438 + -5.414062 = <NaN>
.byte $30,$F8,$14,$03,$44,$FB	;  -3.906250 + 1.539062 = -2.367188
.byte $98,$09,$24,$01,$BC,$0A	;  4.796875 + 0.570312 = 5.367188
.byte $DE,$06,$C2,$00,$A0,$07	;  3.433594 + 0.378906 = 3.812500
.byte $F0,$02,$34,$F5,$24,$F8	;  1.468750 + -5.398438 = -3.929688
.byte $32,$FC,$CE,$09,$00,$06	;  -1.902344 + 4.902344 = 3.000000
.byte $A2,$0A,$FC,$F4,$9E,$FF	;  5.316406 + -5.507812 = -0.191406
.byte $4E,$FD,$84,$F9,$D2,$F6	;  -1.347656 + -3.242188 = -4.589844
.byte $9A,$0A,$90,$00,$2A,$0B	;  5.300781 + 0.281250 = 5.582031
.byte $92,$F8,$E2,$02,$74,$FB	;  -3.714844 + 1.441406 = -2.273438
.byte $BA,$03,$60,$0B,$1A,$0F	;  1.863281 + 5.687500 = 7.550781
.byte $E4,$F8,$3C,$F5,$01,$00	;  -3.554688 + -5.382812 = <NaN>
.byte $E2,$FC,$76,$01,$58,$FE	;  -1.558594 + 0.730469 = -0.828125
.byte $10,$FC,$3C,$F8,$4C,$F4	;  -1.968750 + -3.882812 = -5.851562
.byte $32,$F4,$8A,$F3,$01,$00	;  -5.902344 + -6.230469 = <NaN>
.byte $F6,$04,$5A,$05,$50,$0A	;  2.480469 + 2.675781 = 5.156250
.byte $6C,$01,$DA,$F5,$46,$F7	;  0.710938 + -5.074219 = -4.363281
.byte $22,$01,$B6,$03,$D8,$04	;  0.566406 + 1.855469 = 2.421875
.byte $FE,$06,$B4,$00,$B2,$07	;  3.496094 + 0.351562 = 3.847656
.byte $2C,$FD,$EE,$F9,$1A,$F7	;  -1.414062 + -3.035156 = -4.449219
.byte $9C,$0E,$5E,$09,$01,$00	;  7.304688 + 4.683594 = <NaN>
.byte $70,$FC,$40,$09,$B0,$05	;  -1.781250 + 4.625000 = 2.843750
.byte $0E,$F7,$BE,$09,$CC,$00	;  -4.472656 + 4.871094 = 0.398438
.byte $76,$FB,$A8,$F1,$01,$00	;  -2.269531 + -7.171875 = <NaN>
.byte $02,$03,$0A,$04,$0C,$07	;  1.503906 + 2.019531 = 3.523438
.byte $8A,$04,$BC,$F6,$46,$FB	;  2.269531 + -4.632812 = -2.363281
.byte $6A,$FF,$6E,$0D,$D8,$0C	;  -0.292969 + 6.714844 = 6.421875
.byte $AE,$04,$4C,$0C,$01,$00	;  2.339844 + 6.148438 = <NaN>
.byte $98,$07,$72,$F9,$0A,$01	;  3.796875 + -3.277344 = 0.519531
.byte $3C,$FD,$7E,$F4,$BA,$F1	;  -1.382812 + -5.753906 = -7.136719
.byte $B2,$05,$E6,$FA,$98,$00	;  2.847656 + -2.550781 = 0.296875
.byte $D8,$09,$1C,$F7,$F4,$00	;  4.921875 + -4.445312 = 0.476562
.byte $C2,$00,$FA,$FA,$BC,$FB	;  0.378906 + -2.511719 = -2.132812
.byte $88,$F3,$74,$00,$FC,$F3	;  -6.234375 + 0.226562 = -6.007812
.byte $AE,$0B,$B4,$00,$62,$0C	;  5.839844 + 0.351562 = 6.191406
.byte $62,$0A,$00,$F3,$62,$FD	;  5.191406 + -6.500000 = -1.308594
.byte $12,$FA,$88,$FF,$9A,$F9	;  -2.964844 + -0.234375 = -3.199219
.byte $40,$0C,$D4,$09,$01,$00	;  6.125000 + 4.914062 = <NaN>
.byte $FA,$01,$B6,$F7,$B0,$F9	;  0.988281 + -4.144531 = -3.156250
.byte $7C,$0B,$FC,$F4,$78,$00	;  5.742188 + -5.507812 = 0.234375
.byte $74,$F4,$BA,$08,$2E,$FD	;  -5.773438 + 4.363281 = -1.410156
.byte $B8,$FB,$E0,$03,$98,$FF	;  -2.140625 + 1.937500 = -0.203125
.byte $DE,$0E,$1A,$F9,$F8,$07	;  7.433594 + -3.449219 = 3.984375
.byte $E0,$08,$74,$06,$54,$0F	;  4.437500 + 3.226562 = 7.664062
.byte $8C,$02,$D0,$FE,$5C,$01	;  1.273438 + -0.593750 = 0.679688
.byte $F2,$0A,$3E,$F8,$30,$03	;  5.472656 + -3.878906 = 1.593750
.byte $B8,$09,$CA,$04,$82,$0E	;  4.859375 + 2.394531 = 7.253906
.byte $0E,$08,$7A,$FA,$88,$02	;  4.027344 + -2.761719 = 1.265625
.byte $78,$F8,$96,$0B,$0E,$04	;  -3.765625 + 5.792969 = 2.027344
.byte $A2,$F3,$DC,$FC,$7E,$F0	;  -6.183594 + -1.570312 = -7.753906
.byte $4A,$FC,$06,$0E,$50,$0A	;  -1.855469 + 7.011719 = 5.156250
.byte $DC,$FF,$0E,$0F,$EA,$0E	;  -0.070312 + 7.527344 = 7.457031
.byte MARKER

TESTSQUAREDATA:
.byte $C6,$0A,$FC,$F0,$C2,$FB	;  5.386719 + -7.507812 = -2.121094
.byte $96,$F7,$AC,$0C,$42,$04	;  -4.207031 + 6.335938 = 2.128906
.byte $C4,$F2,$C6,$F5
.byte MARKER





// places

#ifdef PLACES
VISIT:
.(
	JSR INITPLACES
LOOP:
	JSR NEXTPLACE
	LDA #$d
	JSR ECHO
	JSR ECHO
	JSR DRAWSET
	JSR WAIT
	JMP LOOP
.)
#endif

#ifdef PLACES

NEXTPLACE:
.(
	LDA #$d
	JSR ECHO
	JSR ECHO
	JSR ECHO
	JSR ECHO
	JSR ECHO

	LDY #0

		; LOAD X0, Y0, DX, DY
	LDA (PLACEPTR),Y
	STA X0
	INY
	LDA (PLACEPTR),Y
	STA X0+1
	INY

	LDA (PLACEPTR),Y
	STA Y0
	INY
	LDA (PLACEPTR),Y
	STA Y0+1
	INY

	LDA (PLACEPTR),Y
	STA DX
	INY
	LDA (PLACEPTR),Y
	STA DX+1
	INY

	LDA (PLACEPTR),Y
	STA DY
	INY
	LDA (PLACEPTR),Y
	STA DY+1
	INY

		; PRINT PLACE NAME
	LDA #$d
	JSR ECHO
	JSR ECHO
LOOP:
	LDA (PLACEPTR),Y
	BEQ DONE
	INY
	; JSR ECHO
	JMP LOOP
DONE:
	INY
	LDA #$d
	JSR ECHO

		; Increment PLACEPTR
	CLC
	TYA
	ADC PLACEPTR
	STA PLACEPTR
	LDA PLACEPTR+1
	ADC #0
	STA PLACEPTR+1

		; Check if end of places
	LDY #0
	LDA (PLACEPTR),Y
	BEQ INITPLACES

	RTS
.)

#endif

#ifdef PLACES

INITPLACES:
.(
	LDA #<PLACES
	STA PLACEPTR
	LDA #>PLACES
	STA PLACEPTR+1
	RTS
.)

#endif

#ifdef PLACES

PLACES:
	.byte $D0, $FB, $C0, $FD, $26, $00, $30, $00, "MANDELBROT", 0
	.byte $C0, $FE, $80, $FD, $10, $00, $10, $00, "ZOOM ON TOP", 0
	.byte $26, $FF, $B0, $FD, $08, $00, $08, $00, "ZOOM MORE", 0
	.byte $A2, $FF, $06, $FE, $04, $00, $04, $00, "CLOSER", 0
	.byte $D8, $FF, $40, $FE, $02, $00, $02, $00, "MAX ZOOM", 0


	.byte $CA, $FF, $E0, $FD, $02, $00, $02, $00, "UNNAMED", 0
	.byte $CA, $FF, $40, $FE, $02, $00, $02, $00, "UNNAMED", 0
	.byte $9A, $FD, $60, $FF, $02, $00, $02, $00, "UNNAMED", 0
	.byte 0

#endif
