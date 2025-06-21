
filename = top
pcf_file = ../common/io.pcf

ICELINK_DIR=$(shell df | grep iCELink | awk '{print $$6}')
${warning iCELink path: $(ICELINK_DIR)}

build:
	# input: .v, output: .json
	yosys -l $(filename).log -p "synth_ice40 -json $(filename).json -blif $(filename).blif" $(filename).v
	# input: .json .pcf, output: .asc
	nextpnr-ice40 --lp1k --package cm36 --json $(filename).json --pcf $(pcf_file) --asc $(filename).asc --freq 48
	# input: .asc, output: .bin
	icepack $(filename).asc $(filename).bin

upload:
	@if [ -d '$(ICELINK_DIR)' ]; \
        then \
            cp $(filename).bin $(ICELINK_DIR); \
        else \
            echo "iCELink not found"; \
            exit 1; \
    fi


uart:
	picocom /dev/ttyACM0 --baud 9600 --imap crcrlf

clean:
	rm -rf $(filename).blif $(filename).asc $(filename).bin $(filename).json $(filename).log
