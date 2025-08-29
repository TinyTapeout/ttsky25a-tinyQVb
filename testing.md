# Building and testing small TinyQV programs

This is a guide for compiling a program for TinyQV, and testing it in cocotb or on FPGA.

## Setup

- Get the [TinyQV toolchain](https://github.com/MichaelBell/riscv-gnu-toolchain/releases/tag/13.2.0-tqv-1.0) (a slightly modified version of the standard Risc-V GNU toolchain).
- Extract to `/opt/tinyQV`, or set the `RISCV_TOOLCHAIN` environment variable to where you have extracted it.
- Clone the [tinyQV-sdk](https://github.com/MichaelBell/tinyQV-sdk).

## Creating a new project

- Create a new directory for the project
- Copy the files from `tinyQV-sdk/example-project-sim` into your project directory
- Set your project name in the Makefile

Write your program.  The `main.c` contains a simple example, using the WS2812b peripheral, which shows how to access your registers.

## Testing in cocotb

`make` your program and copy the `.hex` file to the `test` directory in this repo.

Create a cocotb test script named after the program, e.g. `test_example.py` for a program called `example.hex`.  The included `test_example.py` works with the SDK example.

Run with

    PROG=<program name> make -B -f test_prog.mk

## Testing on FPGA

You will first need to setup the project in `fpga/generic` to work correctly with your FPGA.  See the [README](fpga/generic/README.md) for details.

`make` your program and copy the `.hex` file to the `fpga/generic` directory.

Make the bitstream with

    PROG=<program name> make
