test: validate
	./validate

validate: validate.cpp
	# cc -g -std=c++23 validate.cpp -o validate -lstdc++
	cc -O3 -std=c++23 validate.cpp -o validate -lstdc++

clean:
	rm -f validate
