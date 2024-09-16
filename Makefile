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
	xa -C -o mandelbrot65.o65 mandelbrot65.asm

mame: mandelbrot65.snp
	mame -debug apple1 -ui_active -resolution 640x480 -snapshot mandelbrot65.snp
