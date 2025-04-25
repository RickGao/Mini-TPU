import random

import cocotb
from cocotb.clock    import Clock
from cocotb.triggers import RisingEdge, Timer


# =====================================================================
#  如果你的 TestBench 里已经写好了 __init__ / reset()，可直接复用
# =====================================================================
class ControlTB:
    CLK_PERIOD = 10  # ns

    def __init__(self, dut):
        self.dut = dut
        cocotb.start_soon(Clock(dut.clk, self.CLK_PERIOD, units="ns").start())

    async def reset(self):
        self.dut.rst_n.value = 0
        for _ in range(3):
            await RisingEdge(self.dut.clk)
        self.dut.rst_n.value = 1
        self.dut.instruction.value = 0
        await RisingEdge(self.dut.clk)

    # -----------------------------------------------------------------
    #  指令编码（示例）：16-bit
    #    [15:14]  op   00=STOP 01=RUN 10=LOAD 11=STORE
    #    [13]     memsel
    #    [11:10]  line
    #    [ 9: 8]  elem
    #    [ 7: 0]  imm8   (仅 LOAD 用)
    # -----------------------------------------------------------------
    def _encode(self, op, memsel=0 ,line=0, elem=0, imm=0):
        return (op << 14) | (memsel << 13) | (line << 10) | (elem << 8) | imm & 0xFF

    # -----------------------------------------------------------------
    #  LOAD —— 写两块 memory 同一个 (line,elem)=imm
    # -----------------------------------------------------------------
    async def load(self, memsel: int, line: int, elem: int, imm: int):
        inst = self._encode(op=0b10, memsel=memsel, line=line, elem=elem, imm=imm)
        self.dut.instruction.value = inst
        await Timer(1, units="ns")       # 给组合逻辑一点时间
        self._show("LOAD")
        await RisingEdge(self.dut.clk)   # 指令被采样

    # -----------------------------------------------------------------
    #  STORE —— 读两块 memory 的 (line,elem)
    # -----------------------------------------------------------------
    async def store(self, row: int, col: int):
        inst = self._encode(op=0b11, line=row, elem=col)
        self.dut.instruction.value = inst
        await Timer(1, units="ns")
        self._show("STORE")
        await RisingEdge(self.dut.clk)

    # -----------------------------------------------------------------
    #  RUN —— 触发阵列运算
    # -----------------------------------------------------------------
    async def run(self, cycle):
        cocotb.log.info("RUN, Cycle = " + str(cycle))
        inst = self._encode(op=0b01, line=0, elem=0)
        self.dut.instruction.value = inst
        await Timer(1, units="ns")
        self._show("RUN")
        await RisingEdge(self.dut.clk)

    # -----------------------------------------------------------------
    #  把 14 个输出端口直接 print 出来
    # -----------------------------------------------------------------
    def _show(self, tag):
        d = self.dut
        cocotb.log.info(f"[{tag}] "
              f"array_we={int(d.array_write_enable)} "
              f"out_row={int(d.array_output_row)} "
              f"out_col={int(d.array_output_col)} \n"
              f"MA_we={int(d.mema_write_enable)} "
              f"MA_data_in={int(d.mema_data_in)} "
              f"MA_write_line_elem=({int(d.mema_write_line)}, {int(d.mema_write_elem)}) \n"
              f"MA_read_enable={[(int(d.mema_read_enable) >> i) & 1 for i in range(4)]} "
              f"MA_read_elem={[(int(d.mema_read_elem) >> i * 2) & 3 for i in range(4)]} \n"
              f"MB_we={int(d.memb_write_enable)} "
              f"MB_data_in={int(d.memb_data_in)} "
              f"MB_write_line_elem=({int(d.memb_write_line)}, {int(d.memb_write_elem)}) \n"
              f"MB_read_enable={[(int(d.memb_read_enable) >> i) & 1 for i in range(4)]} "
              f"MB_read_elem={[(int(d.memb_read_elem) >> i * 2) & 3 for i in range(4)]}\n"
        )


# =====================================================================
#  一个最小的测试例：先 LOAD，再 STORE，再 RUN
# =====================================================================
@cocotb.test()
async def simple_flow(dut):
    tb = ControlTB(dut)
    await tb.reset()

    await tb.load(memsel=1, line=1, elem=2, imm=104)
    await tb.load(memsel=0, line=3, elem=1, imm=80)
    for line in range(4):
        for elem in range(4):
            await tb.load(memsel=0,line=line, elem=elem, imm=random.randint(0,255))
            await tb.load(memsel=1,line=line, elem=elem, imm=random.randint(0,255))
    await tb.store(row=1, col=2)
    await tb.store(row=0, col=2)
    await tb.store(row=2, col=1)
    for row in range(4):
        for col in range(4):
            await tb.store(row=row, col=col)

    for cycle in range(15):
        await tb.run(cycle)

    await tb.reset()

    for cycle in range(15):
        await tb.run(cycle)