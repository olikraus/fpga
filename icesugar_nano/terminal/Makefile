
filename = top
pcf_file = ../common/io.pcf

ICELINK_DIR=$(shell df | grep iCELink | awk '{print $$6}')
${warning iCELink path: $(ICELINK_DIR)}

build:
	# input: .v, output: .json
	yosys -l $(filename).log -p "synth_ice40 -json $(filename).json -blif $(filename).blif; show -format dot -prefix ./$(filename);" $(filename).v
	# input: .json .pcf, output: .asc
	nextpnr-ice40 --lp1k --package cm36 --json $(filename).json --pcf $(pcf_file) --asc $(filename).asc --freq 36
	# input: .asc, output: .bin
	icepack $(filename).asc $(filename).bin
	grep "    SB_\| Number of" $(filename).log

upload:
	../icesprog/icesprog -c 3
	@if [ -d '$(ICELINK_DIR)' ]; \
        then \
            cp $(filename).bin $(ICELINK_DIR); \
        else \
            echo "iCELink not found"; \
            exit 1; \
    fi

uart:
	picocom /dev/ttyACM0 --baud 115200 --imap lfcrlf,crcrlf

python-test:
	python3 test_terminal.py


clean:
	rm -rf $(filename).blif $(filename).asc $(filename).bin $(filename).json $(filename).log $(filename).dot sum fpga_sum

sum: sum.c
	gcc -Wall -O2 -o sum sum.c

fpga_sum: fpga_sum.c
	gcc -Wall -O2 -o fpga_sum fpga_sum.c
