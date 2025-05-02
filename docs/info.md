<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This is a Mini TPU, an ASIC that aim to accelerate AI workload

The core architecture is a Systolic Array


## How to test

## Instruction Format

| Instruction   | Format                          | Description |
|--------------|--------------------------------|-------------|
| `LOAD m, r, c, x` | `10m0 rrcc xxxxxxxx` | Load data from memory `m` (0=MemoryA, 1=MemoryB) into `row r`, `column c` |
| `STORE r, c` | `1100 rrcc 00000000` | Store data from `row r`, `column c` |
| `RUN` | `0100 0000 00000000` | Run the array computation |


## External hardware

FPGA Board with button/switch
