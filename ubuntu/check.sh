#!/bin/bash
chmod +x package-manager.sh

# Check for missing packages
# ./package-manager.sh --file=packages.txt --check --verbose
./package-manager.sh --file=packages.txt --check
