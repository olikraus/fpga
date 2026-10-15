SHELL := /bin/bash
ENV = . ../toolchain/oss-cad-suite/environment &&

filename = top
cst_file = top.cst

.PHONY: all upload clean

all: $(filename).fs

$(filename).json: $(filename).v uart_tx.v
	$(ENV) yosys -p "read_verilog $(filename).v; synth_gowin -top top -json $(filename).json"

$(filename)_pnr.json: $(filename).json $(cst_file)
	$(ENV) nextpnr-himbaechel \
	  --json $(filename).json \
	  --write $@ \
	  --device GW1NR-LV9QN88PC6/I5 \
	  --vopt family=GW1N-9C \
	  --vopt cst=$(cst_file)

$(filename).fs: $(filename)_pnr.json
	$(ENV) gowin_pack -d GW1N-9C -o $(filename).fs $(filename)_pnr.json

upload: $(filename).fs
	$(ENV) openFPGALoader -b tangnano9k top.fs
#	$(ENV) openFPGALoader -b tangnano9k top.fs

uart:
	picocom /dev/ttyUSB1 --baud 9600 --imap lfcrlf

clean:
	rm -f $(filename).json $(filename)_pnr.json $(filename).fs
