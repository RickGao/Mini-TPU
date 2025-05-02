# =========================================================
# Mini TPU Test
# =========================================================
import random
import cocotb
from cocotb.clock     import Clock
from cocotb.triggers  import RisingEdge, Timer

# Instruction Encoding
OP_RUN, OP_LOAD, OP_STORE = 0b01, 0b10, 0b11

def make_instr(op, mem_sel=0, row=0, col=0, imm=0):
    return ((op & 3) << 14) | ((mem_sel & 1) << 13) | \
           ((row & 3) << 10) | ((col & 3) << 8) | (imm & 0xff)

async def send_instr(dut, instr):
    dut.ui_in.value  = instr & 0xff
    dut.uio_in.value = instr >> 8
    await RisingEdge(dut.clk)

# Reset
async def hw_reset(dut, n=3):
    dut.rst_n.value = 0
    for _ in range(n):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# 4×4 Matrix Multiplication
def matmul_ref(a, b):
    n = len(a)
    c = [[0]*n for _ in range(n)]
    for i in range(n):
        for j in range(n):
            c[i][j] = sum(a[i][k] * b[k][j] for k in range(n)) & 0xff
    return c

# LOAD A、B
async def load_matrices(dut, a, b):
    for r in range(4):
        for c in range(4):
            await send_instr(dut, make_instr(OP_LOAD, 0, r, c, a[r][c]))
    for r in range(4):
        for c in range(4):
            await send_instr(dut, make_instr(OP_LOAD, 1, r, c, b[c][r]))

# STORE
async def read_matrix(dut):
    out = [[0]*4 for _ in range(4)]
    for r in range(4):
        for c in range(4):
            await send_instr(dut, make_instr(OP_STORE, 0, r, c))
            await Timer(1, units="ns")        # 数据稳定
            out[r][c] = int(dut.uo_out.value)
    return out

# Matrix Multiplication
async def run_once(dut, a, b):
    await hw_reset(dut)
    await load_matrices(dut, a, b)

    # 11 Cycle, RUN=1
    for _ in range(11):
        await send_instr(dut, make_instr(OP_RUN))

    hw_out = await read_matrix(dut)
    sw_out = matmul_ref(a, b)
    return hw_out, sw_out

# Print Matrix
def log_matrix(dut, title, mat):
    dut._log.info(f"--- {title} ---")
    for i, row in enumerate(mat):
        dut._log.info(f"Row {i}: {row}")

# =========================================================
@cocotb.test()
async def Test_TPU(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    dut.ena.value, dut.ui_in.value, dut.uio_in.value = 1, 0, 0

    cocotb.log.info("\nStart Testing TPU\n")

    async def test_and_log(A: list, B: list):
        hw_res, sw_res = await run_once(dut, A, B)

        log_matrix(dut, "Matrix A", A)
        log_matrix(dut, "Matrix B", B)
        log_matrix(dut, "SW  Result (A×B)", sw_res)
        log_matrix(dut, "HW  Result", hw_res)
        print("\n")

    I = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]

    zero = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]

    await test_and_log(I, zero)

    A = [[1,2,3,4],[5,6,7,8],[9,10,11,12],[13,14,15,16]]
    B = [[2,0,0,0],[0,3,0,0],[0,0,4,0],[0,0,0,5]]

    await test_and_log(A, I)
    await test_and_log(B, I)
    await test_and_log(A, B)

    A = [[(i + j) % 2 for j in range(4)] for i in range(4)]
    B = [[(i * j) % 2 for j in range(4)] for i in range(4)]
    await test_and_log(A, B)

    A = [[5, 5, 5, 5] for _ in range(4)]  # all rows identical
    B = [[1, 2, 3, 4]] * 4       # all columns identical
    await test_and_log(A, B)

    for _ in range(3):
        A = [[random.randint(0, 15) for _ in range(4)] for _ in range(4)]
        B = [[random.randint(0, 15) for _ in range(4)] for _ in range(4)]

        await test_and_log(A, B)