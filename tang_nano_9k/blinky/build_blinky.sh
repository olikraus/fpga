#!/bin/bash
# set -e # Exit immediately if a command exits with a non-zero status

# 1. Source the OSS CAD Suite environment (adjust the path if your folder is located elsewhere)
source ./toolchain/oss-cad-suite/environment

echo "Starting synthesis..."
# 2. Synthesis (Yosys)
yosys -p "read_verilog blinky.v; synth_gowin -top blinky -json blinky.json"

echo "Starting place and route..."
# 3. Place and Route (nextpnr-himbaechel)
nextpnr-himbaechel \
  --json blinky.json \
  --write blinky_pnr.json \
  --device GW1NR-LV9QN88PC6/I5 \
  --vopt family=GW1N-9C \
  --vopt cst=../tangnano9k.cst
  
echo "Generating bitstream..."
# 4. Bitstream Generation (Apicula)
gowin_pack -d GW1N-9C -o blinky.fs blinky_pnr.json

echo "Flashing to Tang Nano 9K..."
# 5. Flash to Board
openFPGALoader -b tangnano9k blinky.fs

echo "Build and flash complete successfully!"
