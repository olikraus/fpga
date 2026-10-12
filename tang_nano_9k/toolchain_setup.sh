#!/bin/bash
# Tang Nano 9K Toolchain Setup Script
# Based on Lushay Labs and YosysHQ recommendations

INSTALL_DIR="$HOME/git/fpga/tang_nano_9k/toolchain"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "Downloading OSS CAD Suite (this may take a few minutes)..."
# Using the latest release URL found via search
wget https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2026-10-09/oss-cad-suite-linux-x64-20261009.tgz -O oss-cad-suite.tgz

echo "Extracting..."
tar -xzf oss-cad-suite.tgz

echo "Cleaning up..."
rm oss-cad-suite.tgz

echo ""
echo "Toolchain setup complete in $INSTALL_DIR/oss-cad-suite"
echo "To use the toolchain, run: source $INSTALL_DIR/oss-cad-suite/environment"
echo "Or add it to your PATH."
