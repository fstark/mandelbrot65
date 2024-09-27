def mandelbrot(real, imag, max_iterations=10):
    # Starting point for the iteration (z = 0 initially)
    z = 0 + 0j
    # Constant c derived from the real and imaginary parts
    c = complex(real, imag)
    
    # Perform Mandelbrot iterations
    for i in range(max_iterations):
        z = z**2 + c
        print(f"Iteration {i+1}: z = {z}")

# Example usage:
real_input = float(input("Enter the real part of the complex number: "))
imag_input = float(input("Enter the imaginary part of the complex number: "))

mandelbrot(real_input, imag_input)
