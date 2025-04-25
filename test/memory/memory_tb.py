# =============================================================
#  test_memory.py  —— 仅测试 load & read_enable
#  * 全过程中文日志
# =============================================================
import cocotb
from cocotb.clock    import Clock
from cocotb.triggers import RisingEdge, Timer
import random


class MemTB:
    CLK_PERIOD = 10  # ns

    def __init__(self, dut):
        self.dut = dut
        cocotb.start_soon(Clock(dut.clk, self.CLK_PERIOD, units="ns").start())

    async def reset(self):
        self.dut.rst_n.value = 0
        for _ in range(3):
            await RisingEdge(self.dut.clk)
        self.dut.rst_n.value = 1
        await RisingEdge(self.dut.clk)

    # ---------- 写函数 ----------
    async def mem_write(self, line: int, elem: int, data: int):
        """
        line : 写哪一列   (0-3)
        elem : 写哪一行   (0-3)
        data : 写入的数据（十进制整数）
        """
        # ---- 打印输入参数 ----
        cocotb.log.info(f"[WRITE] line = {line:d}, elem = {elem:d}, data = {data:d}")

        # 1️⃣ 设置信号
        self.dut.write_enable.value = 1
        self.dut.write_line.value = line
        self.dut.write_elem.value = elem
        self.dut.data_in.value = data

        self.dut.read_enable.value = 0
        self.dut.read_elem.value = 0

        # 2️⃣ 等待上升沿：此拍写入
        await RisingEdge(self.dut.clk)

        # 3️⃣ 关写使能，再空一拍
        self.dut.write_enable.value = 0
        await RisingEdge(self.dut.clk)

    # ---------- 读函数 ----------
    async def mem_read(self, enable_mask: int, elem_sel: int) -> int:
        """
        enable_mask : 4 位列使能（bit0 控列0 … bit3 控列3）
        elem_sel    : 8 位行选择（每 2 位对应 1 列，低位列0）
        """
        # ====== ❶ 解析并格式化输出 ======
        enable_list = [str((enable_mask >> i) & 1) for i in range(4)]  # 列0→列3
        elem_list = [str((elem_sel >> (i * 2)) & 0b11) for i in range(4)]  # 列0→列3

        cocotb.log.info(f"[READ ] enable: {' '.join(enable_list)}, "
                        f"elem: {' '.join(elem_list)}")

        # ====== ❷ 设置信号 ======
        self.dut.read_enable.value = enable_mask
        self.dut.read_elem.value = elem_sel

        self.dut.write_enable.value = 0
        self.dut.write_line.value = 0
        self.dut.write_elem.value = 0
        self.dut.data_in.value = 0

        await Timer(1, units="ns")

        dout = int(self.dut.data_out.value)
        width = 8  # DATA_WIDTH = 8
        col_vals = [(dout >> (i * width)) & 0xFF for i in range(4)]  # 列0→列3
        # → col_vals[0] 是列0, col_vals[1] 是列1, 以此类推

        cocotb.log.info(f"[READ ] Data Out: "
                        f"{col_vals[0]} {col_vals[1]} {col_vals[2]} {col_vals[3]}")

        return dout


@cocotb.test()
async def demo_single_column(dut):
    tb = MemTB(dut)
    await tb.reset()


    # await tb.mem_write(line=0, elem=0, data=0x55)
    #
    #
    # await tb.mem_read(enable_mask=0b1111,
    #                          elem_sel   =0b00000000)

    for line in range(4):
        for elem in range(4):
            await tb.mem_write(line, elem, random.randint(0, 255))
    for elem in range(4):
        await tb.mem_read(enable_mask=0b1111,
                                     elem_sel = elem << 6 | elem << 4 | elem << 2 | elem)


