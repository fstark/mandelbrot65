
* = $0280
FACC = $00

; IN: (X,A) = NUMBER
; OUT: (X,A) = NUMBER^2
SQUARE:
	STX FACC
	STA FACC+1
	LDY #0
	LDA (FACC),Y
	TAX
	LDA (FACC+1),Y
	RTS

* = $1000