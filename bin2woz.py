def binary_to_mozmon(binary_file_path, start_address=0x0280):
    with open(binary_file_path, 'rb') as binary_file:
        binary_data = binary_file.read()

    address = start_address
    output_lines = []

    for i in range(0, len(binary_data), 8):
        chunk = binary_data[i:i+8]
        hex_values = ' '.join(f'{byte:02X}' for byte in chunk)
        output_lines.append(f'{address:04X}: {hex_values}')
        address += len(chunk)

    return '\n'.join(output_lines)

if __name__ == "__main__":
    binary_file_path = 'a.o65'  # Replace with your binary file path
    mozmon_output = binary_to_mozmon(binary_file_path)
    print(mozmon_output)
