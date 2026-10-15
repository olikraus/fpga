# Adapted from blinky Makefile for echo_hex
SHELL := /bin/bash
# Define the environment source prefix (pointing up one level to toolchain)
ENV = . ../toolchain/oss-cad-suite/environment &&

filename = top
cst_file = top.cst

.PHONY: all upload clean

all: $(filename).fs

# 1. Synthesis (Yosys)
$(filename).json: $(filename).v uart_rx.v uart_tx.v hex_tx.v
	$(ENV) yosys -p "read_verilog $(filename).v; synth_gowin -top top -json $(filename).json"

# 2. Place and Route (nextpnr-himbaechel)
$(filename)_pnr.json: $(filename).json $(cst_file)
	$(ENV) nextpnr-himbaechel \
	  --json $(filename).json \
	  --write $@ \
	  --device GW1NR-LV9QN88PC6/I5 \
	  --vopt family=GW1N-9C \
	  --vopt cst=$(cst_file)

# 3. Bitstream Generation (Apicula)
$(filename).fs: $(filename)_pnr.json
	$(ENV) gowin_pack -d GW1N-9C -o $(filename).fs $(filename)_pnr.json

# Flash to Board
upload: $(filename).fs
#	usbreset 0403:6010
	$(ENV) openFPGALoader -b tangnano9k $(filename).fs

upload2: $(filename).fs
	echo '1-3' | sudo tee /sys/bus/usb/drivers/usb/unbind
	sleep 1
	echo '1-3' | sudo tee /sys/bus/usb/drivers/usb/bind
	sleep 1
	$(ENV) openFPGALoader -b tangnano9k $(filename).fs

# UART communication
uart:
	picocom /dev/ttyUSB1 --baud 9600 --imap lfcrlf

# Cleanup generated files

clean:
	rm -f $(filename).json $(filename)_pnr.json $(filename).fs
