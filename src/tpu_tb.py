# =========================================================
#  test_tpu.py  —  TinyTapeout TPU 4×4 end-to-end demo
# =========================================================
import random
import cocotb
from cocotb.clock     import Clock
from cocotb.triggers  import RisingEdge, Timer

# ---------- 指令编码 ----------
OP_RUN, OP_LOAD, OP_STORE = 0b01, 0b10, 0b11

def make_instr(op, mem_sel=0, row=0, col=0, imm=0):
    return ((op & 3) << 14) | ((mem_sel & 1) << 13) | \
           ((row & 3) << 10) | ((col & 3) << 8) | (imm & 0xff)

async def send_instr(dut, instr):
    dut.ui_in.value  = instr & 0xff
    dut.uio_in.value = instr >> 8
    await RisingEdge(dut.clk)

# ---------- 复位 ----------
async def hw_reset(dut, n=3):
    dut.rst_n.value = 0
    for _ in range(n):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# ---------- 4×4 参考矩阵乘 ----------
def matmul_ref(a, b):
    n = len(a)
    c = [[0]*n for _ in range(n)]
    for i in range(n):
        for j in range(n):
            c[i][j] = sum(a[i][k] * b[k][j] for k in range(n)) & 0xff
    return c

# ---------- LOAD A、B ----------
async def load_matrices(dut, a, b):
    for r in range(4):
        for c in range(4):
            await send_instr(dut, make_instr(OP_LOAD, 0, r, c, a[3-r][3-c]))
    for r in range(4):
        for c in range(4):
            await send_instr(dut, make_instr(OP_LOAD, 1, r, c, b[3-c][3-r]))

# ---------- STORE 读取矩阵 ----------
async def read_matrix(dut):
    out = [[0]*4 for _ in range(4)]
    for r in range(4):
        for c in range(4):
            await send_instr(dut, make_instr(OP_STORE, 0, r, c))
            await Timer(1, units="ns")        # 数据稳定
            out[r][c] = int(dut.uo_out.value)
    return out

# ---------- 主流程 ----------
async def run_once(dut, a, b):
    await hw_reset(dut)
    await load_matrices(dut, a, b)

    # 连续 8 拍保持 RUN=1
    for _ in range(15):
        await send_instr(dut, make_instr(OP_RUN))

    # dut.ui_in.value = 0
    # dut.uio_in.value = 0

    # 额外等待 3 拍：数据完全流入右下角
    # for _ in range(3):
    #     await RisingEdge(dut.clk)

    hw_out = await read_matrix(dut)
    sw_out = matmul_ref(a, b)
    return hw_out, sw_out

# ---------- 日志打印 ----------
def log_matrix(dut, title, mat):
    dut._log.info(f"--- {title} ---")
    for i, row in enumerate(mat):
        dut._log.info(f"Row {i}: {row}")

# =========================================================
@cocotb.test()
async def tpu_matrix_show(dut):
    """打印 A、B、软件参考和硬件结果矩阵（无断言）"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    dut.ena.value, dut.ui_in.value, dut.uio_in.value = 1, 0, 0

    # # 随机 or 手动矩阵
    A = [[1,2,3,4],[5,6,7,8],[9,10,11,12],[13,14,15,16]]
    B = [[2,0,0,0],[0,3,0,0],[0,0,4,0],[0,0,0,5]]

    hw_res, sw_res = await run_once(dut, A, B)

    log_matrix(dut, "Matrix A", A)
    log_matrix(dut, "Matrix B", B)
    log_matrix(dut, "SW  Result (A×B)", sw_res)
    log_matrix(dut, "HW  Result", hw_res)

    # A = [[random.randint(0, 15) for _ in range(4)] for _ in range(4)]
    # B = [[random.randint(0, 15) for _ in range(4)] for _ in range(4)]
    #
    # hw_res, sw_res = await run_once(dut, A, B)
    #
    # log_matrix(dut, "Matrix A", A)
    # log_matrix(dut, "Matrix B", B)
    # log_matrix(dut, "SW  Result (A×B)", sw_res)
    # log_matrix(dut, "HW  Result", hw_res)