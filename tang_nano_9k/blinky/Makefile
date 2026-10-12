# Define the environment source prefix (pointing up one level to toolchain)
ENV = . ../toolchain/oss-cad-suite/environment &&

.PHONY: all flash clean

all: blinky.fs

# 1. Synthesis (Yosys)
blinky.json: blinky.v
	$(ENV) yosys -p "read_verilog blinky.v; synth_gowin -top blinky -json blinky.json"

# 2. Place and Route (nextpnr-himbaechel)
blinky_pnr.json: blinky.json ../tangnano9k.cst
	$(ENV) nextpnr-himbaechel \
	  --json blinky.json \
	  --write blinky_pnr.json \
	  --device GW1NR-LV9QN88PC6/I5 \
	  --vopt family=GW1N-9C \
	  --vopt cst=../tangnano9k.cst

# 3. Bitstream Generation (Apicula)
blinky.fs: blinky_pnr.json
	$(ENV) gowin_pack -d GW1N-9C -o blinky.fs blinky_pnr.json

# 4. Flash to Board
upload: blinky.fs
	$(ENV) openFPGALoader -b tangnano9k blinky.fs

# Cleanup generated files
clean:
	rm -f blinky.json blinky_pnr.json blinky.fs