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
            #else:
            #    print(f"Echo OK: {repr(echo)}")

    def check_read_response(expected_hex):
        # Read response (8 hex chars + \r)
        resp_raw = ser.read(9)
        print(f"Raw response: {resp_raw}")
        try:
            response = resp_raw.decode('ascii')
            print(f"Response: {repr(response)}")
            
            expected = expected_hex.upper() + "\r"
            if response.upper() == expected:
                print(f"SUCCESS: Read back correct value {expected_hex}")
            else:
                print(f"FAILURE: Expected {repr(expected)}, got {repr(response)}")
        except UnicodeDecodeError:
            print(f"FAILURE: Got non-ASCII response: {resp_raw.hex()}")

    # Test Echo
    print("\n--- Testing Echo ---")
    send_and_check_echo("Hello!")
    
    # Test Write command (full 32-bit)
    print("\n--- Testing Write Command 'w 12345678\\r' ---")
    send_and_check_echo("w 12345678\r")
    time.sleep(0.1)
    print("\n--- Testing Read Command 'r\\r' ---")
    send_and_check_echo("r\r")
    check_read_response("12345678")

    # Test Write command (incomplete, padding check)
    print("\n--- Testing Write Command 'w AB\\r' ---")
    send_and_check_echo("w AB\r")
    time.sleep(0.1)
    print("\n--- Testing Read Command 'r\\r' ---")
    send_and_check_echo("r\r")
    check_read_response("000000AB")

    # Test Write command (max value)
    print("\n--- Testing Write Command 'w FFFFFFFF\\r' ---")
    send_and_check_echo("w FFFFFFFF\r")
    time.sleep(0.1)
    print("\n--- Testing Read Command 'r\\r' ---")
    send_and_check_echo("r\r")
    check_read_response("FFFFFFFF")

    ser.close()

if __name__ == "__main__":
    test_terminal()
