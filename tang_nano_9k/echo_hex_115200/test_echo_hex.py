import serial
import time
import sys

def test_echo_hex(port='/dev/ttyUSB1', baud=115200):
    try:
        print(f"Initializing serial port {port} (open-close reset cycle & buffer flush)...")
        init_ser = serial.Serial(port, baud, timeout=0.1)
        init_ser.reset_input_buffer()
        init_ser.reset_output_buffer()
        init_ser.close()
        time.sleep(0.5)

        print(f"Opening serial port {port} for real test...")
        ser = serial.Serial(port, baud, timeout=0.5)
        print(f"Successfully opened and configured {port} at {baud} baud.")
    except Exception as e:
        print(f"Error opening serial port {port}: {e}")
        sys.exit(1)

    test_chars = ['A', 'B', '1', '0']
    for char in test_chars:
        print(f"\nSending character: {repr(char)} (ASCII: {ord(char)}, Hex: {hex(ord(char))})")
        ser.write(char.encode('ascii'))
        time.sleep(0.3)
        resp = ser.read_all()
        print(f"Received ({len(resp)} bytes): {resp} {[chr(b) if 32 <= b < 127 else f'\\x{b:02x}' for b in resp]}")
    
    ser.close()
    print("\nTest completed successfully.")

if __name__ == "__main__":
    port = sys.argv[1] if len(sys.argv) > 1 else '/dev/ttyUSB1'
    test_echo_hex(port)
