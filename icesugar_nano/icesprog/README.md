# icesprog

## Purpose

 * Change clock speed of the attached FPGA icesugar-nano board
 * Upload the binary (which can also be done via the mounted drive)

## License

This is a copy from here: https://github.com/wuxx/icesugar/tree/master/tools/src

Published under GNU Lesser General Public License v2.1 (see source code).


## Required libs for make

sudo apt install libhidapi-dev                 // for icesprog from https://github.com/wuxx/icesugar/tree/master/tools
sudo apt install libusb-1.0-0-dev               // for icesprog from https://github.com/wuxx/icesugar/tree/master/tools



## Install 60-icesugar.rules
```bash
sudo install -Dm0644 60-icesugar.rules -t /etc/udev/rules.d/
sudo udevadm control --reload
```

## GPIO control
```
$icesprog --gpio PB14 --mode out
$icesprog --gpio PB14 --write 0
$icesprog --gpio PB14 --write 1
$icesprog --gpio PB14 --read
```

## JTAG select (available on iCESugar-pro)
```
$icesprog --jtag-sel ?
$icesprog --jtag-sel 1
$icesprog --jtag-sel 2
```

## MCO config (available on iCESugar-nano)
```
$icesprog --clk-sel ?
$icesprog --clk-sel 1
$icesprog --clk-sel 2
$icesprog --clk-sel 3
$icesprog --clk-sel 4
```
