import cocotb
from cocotb.clock     import Clock
from cocotb.triggers  import RisingEdge, Timer
import random


# -------- opcode 定义，与 RTL 保持一致 -------- #
OP_RUN   = 0b01
OP_STOP =  0b00
OP_LOAD  = 0b10
OP_STORE = 0b11


# ========== TB 辅助类 ========= #
class ControlTB:
    CLK_PERIOD = 10  # ns

    def __init__(self, dut):
        self.dut = dut
        cocotb.start_soon(Clock(dut.clk, self.CLK_PERIOD, units="ns").start())


    # --- 复位 --- #
    async def reset(self):
        self.dut.rst_n.value = 0
        # 保持低电平跨 3 个上升沿
        for _ in range(3):
            await RisingEdge(self.dut.clk)
        self.dut.rst_n.value = 1
        await RisingEdge(self.dut.clk)

    # ---------- 打印对比行 ----------
    def _print_cmp(self, prefix: str, exp: str, act: str):
        self.dut._log.info(f"{prefix:<20} | expected={exp} | actual={act}")

    # --- 生成 16-bit 指令 --- #
    @staticmethod
    def make_instr(op, mem_sel=0, row=0, col=0, imm=0):
        return (op  & 0b11)   << 14 | \
               (mem_sel & 1)  << 13 | \
               (row & 0b11)   << 10 | \
               (col & 0b11)   <<  8 | \
               (imm & 0xff)

    # ------- 单条 LOAD 检查 ------- #
    async def load_once(self, mem_sel, row, col, imm):
        instr = self.make_instr(OP_LOAD, mem_sel, row, col, imm)
        self.dut.instruction.value = instr
        await RisingEdge(self.dut.clk)

        # 构造期望串
        exp_en = '1'
        exp_line = f"{row:02b}"
        exp_elem = f"{col:02b}"
        exp_data = f"{imm:02x}"

        if mem_sel == 0:  # 写 A
            act_en = str(int(self.dut.mema_write_enable.value))
            act_line = f"{int(self.dut.mema_write_line.value):02b}"
            act_elem = f"{int(self.dut.mema_write_elem.value):02b}"
            act_data = f"{int(self.dut.mema_data_in.value):02x}"
            self._print_cmp("LOAD-A enable", exp_en, act_en)
            self._print_cmp("LOAD-A line", exp_line, act_line)
            self._print_cmp("LOAD-A elem", exp_elem, act_elem)
            self._print_cmp("LOAD-A data", exp_data, act_data)
            assert act_en == exp_en and act_line == exp_line \
                   and act_elem == exp_elem and act_data == exp_data
        else:  # 写 B
            act_en = str(int(self.dut.memb_write_enable.value))
            act_line = f"{int(self.dut.memb_write_line.value):02b}"
            act_elem = f"{int(self.dut.memb_write_elem.value):02b}"
            act_data = f"{int(self.dut.memb_data_in.value):02x}"
            self._print_cmp("LOAD-B enable", exp_en, act_en)
            self._print_cmp("LOAD-B line", exp_line, act_line)
            self._print_cmp("LOAD-B elem", exp_elem, act_elem)
            self._print_cmp("LOAD-B data", exp_data, act_data)
            assert act_en == exp_en and act_line == exp_line \
                   and act_elem == exp_elem and act_data == exp_data

    # ------- 单条 STORE 检查 ------- #
    async def store_once(self, row, col):
        instr = self.make_instr(OP_STORE, 0, row, col, 0)
        self.dut.instruction.value = instr
        await RisingEdge(self.dut.clk)

        exp_row = f"{row:02b}"
        exp_col = f"{col:02b}"
        act_row = f"{int(self.dut.array_output_row.value):02b}"
        act_col = f"{int(self.dut.array_output_col.value):02b}"
        self._print_cmp("STORE row", exp_row, act_row)
        self._print_cmp("STORE col", exp_col, act_col)
        assert act_row == exp_row and act_col == exp_col

    # ------- RUN-phase 读使能检查并完整打印 ------- #
    async def run_phase_check(self, cycles=9):
        """
        cycles : 想观察多少拍就填多少；默认 9 拍能覆盖 4×4 systolic array 的一次完整滑窗
        """
        # ① 发 RUN 指令启动阵列
        self.dut.instruction.value = self.make_instr(OP_RUN)
        await RisingEdge(self.dut.clk)  # cycle-0

        exp = [0, 0, 0, 0]
        act_a = [int(self.dut.mema_read_enable[r].value) for r in range(4)]
        act_b = [int(self.dut.memb_read_enable[r].value) for r in range(4)]
        exp_str = ''.join(str(b) for b in exp)
        act_a_str = ''.join(str(b) for b in act_a)
        act_b_str = ''.join(str(b) for b in act_b)
        self.dut._log.info(
            f"Cycle {0 :2d} | Expected={exp_str} | "
            f"MEMA={act_a_str} | MEMB={act_b_str}"
        )

        # ② 连续观测 cycles 拍
        for cyc in range(cycles):
            await RisingEdge(self.dut.clk)

            # —— 计算期望 —— #
            exp = [1 if (cyc >= r and cyc < r + 4) else 0 for r in range(4)]

            # —— 读取实际值 —— #
            act_a = [int(self.dut.mema_read_enable[r].value) for r in range(4)]
            act_b = [int(self.dut.memb_read_enable[r].value) for r in range(4)]

            # —— 打印 —— #
            # 这里用 Python f-string 把数组格式化为 0/1 字符串，例如 "1100"
            exp_str = ''.join(str(b) for b in exp)
            act_a_str = ''.join(str(b) for b in act_a)
            act_b_str = ''.join(str(b) for b in act_b)

            self.dut._log.info(
                f"Cycle {cyc + 1 :2d} | Expected={exp_str} | "
                f"MEMA={act_a_str} | MEMB={act_b_str}"
            )

            # —— 断言不变 —— #
            assert act_a == exp, f"cycle{cyc}: memA {act_a_str}!={exp_str}"
            assert act_b == exp, f"cycle{cyc}: memB {act_b_str}!={exp_str}"

        self.dut.instruction.value = self.make_instr(OP_STOP)


# ========== TEST 1：确定性功能 ========= #
@cocotb.test()
async def control_basic(dut):
    tb = ControlTB(dut)
    await tb.reset()

    # LOAD A / LOAD B
    for i in range(4):
        await tb.load_once(0, i, (i+1)&3, 0xA0+i)
        await tb.load_once(1, (i+1)&3, i, 0xB0+i)

    # STORE
    for i in range(4):
        await tb.store_once(i, (i+1)&3)


    await tb.reset()
    # RUN 检查
    await tb.run_phase_check()


# ========== TEST 2：随机指令 ========= #
@cocotb.test()
async def control_random(dut):
    tb = ControlTB(dut)
    await tb.reset()

    # 随机 LOAD
    for _ in range(6):
        await tb.load_once(random.randint(0,1),
                           random.randint(0,3),
                           random.randint(0,3),
                           random.randint(0,255))

    # 随机 STORE
    for _ in range(6):
        await tb.store_once(random.randint(0,3),
                            random.randint(0,3))
    await tb.reset()
    # 再跑一次 RUN
    await tb.run_phase_check()

    await tb.reset()
    # RUN 检查
    await tb.run_phase_check(15)