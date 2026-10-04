import serial
import time
import sys

def test_terminal(port='/dev/ttyACM0', baud=115200):
    try:
        ser = serial.Serial(port, baud, timeout=0.5)
    except Exception as e:
        print(f"Error opening serial port {port}: {e}")
        sys.exit(1)

    print("Waiting 3 seconds for FPGA to start...")
    time.sleep(3) 
    ser.reset_input_buffer()
    ser.reset_output_buffer()
    
    def send_cmd(cmd):
        """Sends a command char-by-char and waits for echo of the command including the trailing \\r."""
        # print(f"Sending command: {repr(cmd)}")
        for char in cmd + "\r":
            ser.write(char.encode('ascii'))
            echo = ser.read(1)
            if not echo:
                print(f"Timeout waiting for echo of {repr(char)}")
        time.sleep(0.01)

    def read_reg():
        """Sends 'r\\r', consumes its echo, and returns the 8-digit hex response."""
        # Send 'r' and wait for echo
        ser.write(b"r")
        ser.read(1) 
        # Send '\r' and wait for echo
        ser.write(b"\r")
        ser.read(1) 
        
        # Read the 8 hex chars and the trailing CR
        resp = b''
        for _ in range(9):
            resp += ser.read(1)
        
        try:
            return resp.decode('ascii').strip().upper()
        except:
            return f"ERR({resp.hex()})"

    # --- Phase 1: Basic Echo and Register Test ---
    print("\n--- Phase 1: Basic Echo and Register Test ---")
    
    test_str = "Hello FPGA!"
    print(f"Testing char echo with string: {repr(test_str)}")
    for char in test_str:
        ser.write(char.encode('ascii'))
        echo = ser.read(1).decode('ascii')
        if echo != char:
            print(f"FAILURE: Sent {repr(char)}, got echo {repr(echo)}")
            sys.exit(1)
    print("SUCCESS: String echo matches.")

    print("\nTesting simple Write/Read...")
    send_cmd("w 12345678")
    val = read_reg()
    if val == "12345678":
        print(f"SUCCESS: Read back expected value {val}")
    else:
        print(f"FAILURE: Expected 12345678, got {repr(val)}")
        sys.exit(1)

    # --- Phase 2: Bulk Memory Integrity Test ---
    print("\n--- Phase 2: Bulk Memory Integrity Test (EBR Blocks) ---")
    
    print("Step 1: Storing values 0-15 at addresses 0x00-0x0F...")
    for i in range(16):
        val_hex = f"{i:08X}"
        addr_hex = f"{i:02X}"
        send_cmd(f"w {val_hex}")
        send_cmd(f"s {addr_hex}")

    print("Step 2: Clearing register to 00000000...")
    send_cmd("w 00000000")
    
    print("Step 3: Loading and verifying values...")
    success_count = 0
    for i in range(16):
        expected_hex = f"{i:08X}"
        addr_hex = f"{i:02X}"
        
        send_cmd(f"l {addr_hex}")
        actual_hex = read_reg()
        
        if actual_hex == expected_hex:
            success_count += 1
        else:
            print(f"FAILURE: Addr {addr_hex} expected {expected_hex}, got {repr(actual_hex)}")

    print(f"Memory Test Result: {success_count}/16 matches.")
    if success_count != 16:
        print("PHASE 2 FAILED!")
        sys.exit(1)

    # --- Phase 3: Hardware EP1 Test ---
    print("\n--- Phase 3: Hardware EP1 Test ---")
    
    def rotr32(n, c):
        return ((n >> c) | (n << (32 - c))) & 0xFFFFFFFF

    def ep1_sw(x):
        return rotr32(x, 6) ^ rotr32(x, 11) ^ rotr32(x, 25)

    test_vals = [0x00000001, 0x12345678, 0xFFFFFFFF, 0xABCDEF01]
    
    success_ep1 = 0
    for val in test_vals:
        expected = ep1_sw(val)
        print(f"Testing EP1(0x{val:08X})...")
        send_cmd(f"w {val:08X}")
        send_cmd("s 4")
        send_cmd("w 00000000")
        send_cmd("e")
        actual_hex = read_reg()
        actual = int(actual_hex, 16)
        
        if actual == expected:
            print(f"  MATCH: Got 0x{actual:08X}")
            success_ep1 += 1
        else:
            print(f"  FAILURE: Expected 0x{expected:08X}, got 0x{actual:08X}")

    print(f"EP1 Test Result: {success_ep1}/{len(test_vals)} matches.")
    if success_ep1 != len(test_vals):
        print("PHASE 3 FAILED!")
        sys.exit(1)
    
    # --- Phase 4: Cross-Block Test ---
    print("\n--- Phase 4: Cross-Block Memory Test ---")
    # Store unique values in different blocks (0, 1, 2, 3)
    test_data = {
        "05": "DEADBEEF",
        "15": "CAFEBABE",
        "25": "1234ABCD",
        "35": "98765432"
    }
    
    for addr, val in test_data.items():
        print(f"Storing {val} in EBR block {addr[0]} at offset {addr[1]}...")
        send_cmd(f"w {val}")
        send_cmd(f"s {addr}")
        
    print("Verifying cross-block data...")
    for addr, expected in test_data.items():
        send_cmd(f"l {addr}")
        actual = read_reg()
        if actual == expected:
            print(f"MATCH: Addr {addr} contains {actual}")
        else:
            print(f"FAILURE: Addr {addr} expected {expected}, got {repr(actual)}")
            sys.exit(1)

    print("\nALL TESTS PASSED SUCCESSFULLY!")
    ser.close()

if __name__ == "__main__":
    test_terminal()
