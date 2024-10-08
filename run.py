#!/usr/bin/env python3
from vunit import VUnit

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Optionally add VUnit's builtin HDL utilities for checking, logging, communication...
# See http://vunit.github.io/hdl_libraries.html.
vu.add_vhdl_builtins()
# or
# vu.add_verilog_builtins()

# Create library
lib = vu.add_library("dcpu16_lib")

# Add all files ending in .vhd in current working directory to library
lib.add_source_files("src/*.vhd", vhdl_standard="2008")

# Also a test library
test_lib = vu.add_library("dcpu16_test_lib")
test_lib.add_source_files("src/test/*.vhd", vhdl_standard="2008")

# Run vunit function
vu.main()

