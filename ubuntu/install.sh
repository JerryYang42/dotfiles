#!/bin/bash
chmod +x package-manager.sh

# Install missing packages
./package-manager.sh --file=packages.txt --verbose
