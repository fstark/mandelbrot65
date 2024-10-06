all: mandelbrot65.o65 mandelbrot65.hex

clean:
	rm -f others/validate mandelbrot65.lst mandelbrot65.o65 mandelbrot65.hex mandelbrot65.snp

test: mandelbrot65.o65
	( echo "	MF" ; python3 ../apple1loader/utils/bin2woz.py mandelbrot65.o65 280 ; echo "	" ; echo "280R" ; echo " "  ) > ../napple1/AUTOTYPING.TXT

others/validate: others/validate.cpp
	# cc -g -std=c++23 others/validate.cpp -o others/validate -lstdc++
	cc -O3 -std=c++23 others/validate.cpp -o others/validate -lstdc++

# The snapshot for mame (Lunix only?)
mandelbrot65.snp: mandelbrot65.o65
	( /bin/echo -en "LOAD:\x02\x80DATA:" ; cat mandelbrot65.o65 ) > mandelbrot65.snp

# The binary file
mandelbrot65.o65: mandelbrot65.asm
	xa -C -P mandelbrot65.lst -XCA65 -o mandelbrot65.o65 mandelbrot65.asm

# The hexfile
mandelbrot65.hex: mandelbrot65.o65
	python3 bin/bin2woz.py mandelbrot65.o65 > mandelbrot65.hex	

# Lanches mame (linux)
mame: mandelbrot65.snp
	mame -video opengl -debug apple1 -ui_active -resolution 640x480 -snapshot mandelbrot65.snp -rompath ~/mame/roms -ui_active
#	mame -debug apple1 -ui_active -resolution 640x480 -snapshot mandelbrot65.snp
