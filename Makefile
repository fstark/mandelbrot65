test: validate
	./validate

validate: validate.cpp
	# cc -g -std=c++23 validate.cpp -o validate -lstdc++
	cc -O3 -std=c++23 validate.cpp -o validate -lstdc++

clean:
	rm -f validate

mandelbrot65.snp: mandelbrot65.o65
	( /bin/echo -en "LOAD:\x02\x80DATA:" ; cat mandelbrot65.o65 ) > mandelbrot65.snp

mandelbrot65.o65: mandelbrot65.asm
	xa -C -P mandelbrot65.lst -XCA65 -o mandelbrot65.o65 mandelbrot65.asm

mame: mandelbrot65.snp
	mame -video opengl -debug apple1 -ui_active -resolution 640x480 -snapshot mandelbrot65.snp -rompath ~/mame/roms -ui_active
#	mame -debug apple1 -ui_active -resolution 640x480 -snapshot mandelbrot65.snp
