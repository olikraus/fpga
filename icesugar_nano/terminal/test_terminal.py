import serial
import time
import sys

def test_terminal(port='/dev/ttyACM0', baud=9600):
    try:
        ser = serial.Serial(port, baud, timeout=1)
    except Exception as e:
        print(f"Error opening serial port {port}: {e}")
        sys.exit(1)

    print("Waiting 3 seconds for FPGA to start after flashing...")
    time.sleep(3) 
    ser.reset_input_buffer()
    ser.reset_output_buffer()
    
    def send_and_check_echo(data):
        print(f"Sending: {repr(data)}")
        for char in data:
            ser.write(char.encode('ascii'))
            echo_raw = ser.read(1)
            if not echo_raw:
                print(f"Timeout waiting for echo of {repr(char)}")
                continue
            echo = echo_raw.decode('ascii')
            if echo != char:
                print(f"Echo mismatch: sent {repr(char)}, got {repr(echo)} (0x{echo_raw[0]:02x})")
            else:
                print(f"Echo OK: {repr(echo)}")

    # Test Echo
    print("\n--- Testing Echo ---")
    send_and_check_echo("Hello!")
    
    # Test Write command
    print("\n--- Testing Write Command 'w 55\\r' ---")
    send_and_check_echo("w 55\r")
    
    time.sleep(0.1)

    # Test Read command
    print("\n--- Testing Read Command 'r\\r' ---")
    send_and_check_echo("r\r")
    
    # Read response (2 hex chars + \r)
    resp_raw = ser.read(3)
    print(f"Raw response: {resp_raw}")
    response = resp_raw.decode('ascii')
    print(f"Response: {repr(response)}")
    
    if response == "55\r":
        print("SUCCESS: Read back correct value.")
    else:
        print(f"FAILURE: Expected '55\\r', got {repr(response)}")

    # Test another Write/Read
    print("\n--- Testing Write Command 'w A2\\r' ---")
    send_and_check_echo("w A2\r")
    time.sleep(0.1)
    print("\n--- Testing Read Command 'r\\r' ---")
    send_and_check_echo("r\r")
    
    resp_raw = ser.read(3)
    print(f"Raw response: {resp_raw}")
    response = resp_raw.decode('ascii')
    print(f"Response: {repr(response)}")
    
    if response == "A2\r":
        print("SUCCESS: Read back correct value.")
    else:
        print(f"FAILURE: Expected 'A2\\r', got {repr(response)}")

    ser.close()

if __name__ == "__main__":
    test_terminal()
