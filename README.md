# 🧠 Mini-TPU: A Tiny Tapeout-Based Systolic Array Accelerator

[![](../../workflows/gds/badge.svg)](../../workflows/gds)
[![](../../workflows/docs/badge.svg)](../../workflows/docs)
[![](../../workflows/test/badge.svg)](../../workflows/test)
[![](../../workflows/fpga/badge.svg)](../../workflows/fpga)

This project implements a **Mini Tensor Processing Unit (Mini-TPU)** on the **Tiny Tapeout** open-source ASIC platform. It features a compact 4×4 systolic array optimized for efficient **matrix multiplication**, making it ideal for resource-constrained AI inference tasks.

> ✨ Built using [Tiny Tapeout](https://tinytapeout.com) and [Skywater 130nm PDK](https://skywater-pdk.readthedocs.io)!

---

## 🔍 Project Overview

The Mini-TPU is designed for **educational** and **exploratory** purposes. Despite the severe area constraints (~160µm × 100µm), it demonstrates:
- A fully functional 4×4 **systolic array** of 8-bit MAC units
- An **output-stationary dataflow**
- Custom instruction set (`LOAD`, `RUN`, `STORE`)
- **On-chip dual memory banks** for activations and weights
- A lightweight **control**

---

## 🧱 System Architecture

- `pe.v`: Single Processing Element (8-bit MAC)
- `array.v`: 4x4 systolic array
- `memory.v`: Two 4x4 on-chip memories (A and B)
- `control.v`: Control unit to execute instructions
- `tpu_top.v`: System integration module

---

## 🧪 Verification

We used a combination of:
- `SystemVerilog` + **constraint-random tests**
- `Cocotb` + Python **testbench and reference model**
- FPGA emulation on **Nexys A7-100T**

✅ All modules and system-level simulation passed.

## 🎬 Demo & Resources

- ▶️ **[Project Video](https://youtu.be/X8vROCTOxMI)**
- 📂 **[GitHub Codebase](https://github.com/RickGao/Mini-TPU)**
