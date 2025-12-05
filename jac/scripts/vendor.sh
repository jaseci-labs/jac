#!/bin/bash
# Vendor dependencies for jaclang
# Uses pip-tools to compile dependencies from requirements-vendor.in

# Install pip-tools if not available
pip install pip-tools

# Compile requirements (generate requirements.txt from requirements-vendor.in)
pip-compile requirements-vendor.in --output-file=requirements.txt

# Install dependencies to vendor directory
pip install --no-binary :all: --target=vendor/ -r requirements.txt
