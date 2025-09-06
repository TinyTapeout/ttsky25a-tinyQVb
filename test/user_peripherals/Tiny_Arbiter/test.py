# tests/test_pac_rr.py
import os, random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge
from tqv import TinyQV

PERIPHERAL_NUM = 32  # 16 + 16

# ------------------
class ArbiterTB:
    def __init__(self, dut, tqv: TinyQV):
        self.dut = dut
        self.tqv = tqv

    # SV: write_reg(addr,val) -> TinyQV
    async def write_reg(self, addr: int, val: int):
        await self.tqv.write_reg(addr & 0xF, val & 0xFF)

    # SV: read_reg(addr,val) -> TinyQV
    async def read_reg(self, addr: int) -> int:
        return (await self.tqv.read_reg(addr & 0xF)) & 0xFF

    # SV: cfg_weights(w0..w3) + commit @ 0x6
    async def cfg_weights(self, w0: int, w1: int, w2: int, w3: int):
        await self.write_reg(0x2, w0 & 0x7)
        await self.write_reg(0x3, w1 & 0x7)
        await self.write_reg(0x4, w2 & 0x7)
        await self.write_reg(0x5, w3 & 0x7)
        await self.write_reg(0x6, 0x01)   # commit shadow -> live
        await ClockCycles(self.dut.clk, 1)

    # SV: drive internal stubs (req_stub/ready_stub/valid_stub)
    async def drive_stubs(self, reqs: int, ready: int, valid: int):
        self.dut.req_stub.value   = reqs & 0xF
        self.dut.ready_stub.value = 1 if ready else 0
        self.dut.valid_stub.value = 1 if valid else 0
        await ClockCycles(self.dut.clk, 1)

    # SV: read_grant_idx + read_grant_vec from readback map
    async def read_grant_idx(self):
        rE = await self.read_reg(0xE)   # {5'b0, busy, gi[1:0]}
        gi   =  rE        & 0x3
        busy = (rE >> 2)  & 0x1
        return gi, busy

    async def read_grant_vec(self):
        rF = await self.read_reg(0xF)   # {4'b0, gv[3:0]}
        return rF & 0xF

    async def show_grant_status(self, tag="RB"):
        gi, busy = await self.read_grant_idx()
        gv = await self.read_grant_vec()
        self.dut._log.info(f"[{tag}] t={cocotb.utils.get_sim_time('ns')}  busy={busy}  gi={gi}  gv={gv:04b}")
        return gi, gv, busy

    # SV: trial_reset()
    async def trial_reset(self):
        self.dut.rst_n.value = 0
        await ClockCycles(self.dut.clk, 2)
        self.dut.rst_n.value = 1
        await ClockCycles(self.dut.clk, 1)


# Python port of arbiter_cfg “randomize”
class ArbiterCfg:
    def __init__(self, rnd: random.Random):
        self.rnd = rnd

    def randomize(self, force_rv11=False):
        # weights in [0..4] with ~10% zeros, ~90% non-zero 
        def w():
            return self.rnd.choices([0,1,2,3,4], weights=[1,9,9,9,9], k=1)[0]
        weights = [w(), w(), w(), w()]

        # reqs != 0
        reqs = 0
        while reqs == 0:
            reqs = self.rnd.randrange(1, 16)

        # rv_code distribution (70% 11, 10/01/00 = 10% each), or forced 11
        if force_rv11:
            ready = 1; valid = 1
        else:
            rv_choice = self.rnd.choices([0b11,0b10,0b01,0b00], weights=[70,10,10,10], k=1)[0]
            ready = (rv_choice >> 1) & 1
            valid = (rv_choice >> 0) & 1

        return dict(w=weights, reqs=reqs, ready=ready, valid=valid)

    @staticmethod
    def show(dut, tag, s):
        w = s["w"]; reqs = s["reqs"]; ready=s["ready"]; valid=s["valid"]
        dut._log.info(
            f"[{tag}] w={w[0]}:{w[1]}:{w[2]}:{w[3]}  reqs={reqs:04b} "
            f"(r0={reqs&1} r1={(reqs>>1)&1} r2={(reqs>>2)&1} r3={(reqs>>3)&1}) "
            f"ready={ready} valid={valid}"
        )

#########################################################################

# =========================
def _time_ns():
    return cocotb.utils.get_sim_time("ns")

def _rr_pick_first(mask: int, rr_ptr: int) -> int:
    """Round-robin pick-first among set bits of mask starting at rr_ptr."""
    for j in range(4):
        idx = (rr_ptr + j) % 4
        if (mask >> idx) & 1:
            return idx
    return rr_ptr

def _max_weight_elig(weights, elig: int) -> int:
    """Max weight among eligible requesters."""
    mw = 0
    for i in range(4):
        if (elig >> i) & 1:
            wi = weights[i]
            if wi > mw:
                mw = wi
    return mw

def _has_xz(sig) -> bool:
    """True if BinaryValue contains any X/Z."""
    return any(c in sig.value.binstr for c in "xXzZ")

def _count_ones_4(v: int) -> int:
    v &= 0xF
    return ((v>>0)&1) + ((v>>1)&1) + ((v>>2)&1) + ((v>>3)&1)

# ==========================================================
# p_gi_matches_expected_next
#   $rose(new_grant) |=> (gi == exp_idx_d1)
#   Prints PASS/FAIL 
# ==========================================================
async def rr_expected_index_scoreboard(dut, H):
    rr_ptr = 0
    gv_prev = 0
    exp_idx_prev = 0
    elig_prev    = 0
    w_prev       = [0,0,0,0]

    while True:
        await RisingEdge(dut.clk)
        if int(dut.rst_n.value) == 0:
            rr_ptr=0; gv_prev=0; exp_idx_prev=0; elig_prev=0; w_prev=[0,0,0,0]
            continue

        # Sample DUT signals
        w = [ int(H["w"][i].value) & 0x7 for i in range(4) ]
        req   = int(H["req"].value)   & 0xF
        ready = int(H["ready"].value) & 0x1
        valid = int(H["valid"].value) & 0x1
        gv    = int(H["gv"].value)    & 0xF
        gi    = int(H["gi"].value)    & 0x3

        # Decision-time eligibility (match: req & {4{valid}})
        elig_T = req if valid else 0

        # new_grant = 0 -> onehot
        new_grant = (gv_prev == 0) and (gv != 0)

        # Check at T+1 using expected-from-T
        if new_grant:
            if gi != exp_idx_prev:
                dut._log.error(
                    "[SB] MISMATCH t=%s  gi=%d exp=%d  elig=%04b  w={%d,%d,%d,%d}",
                    _time_ns(), gi, exp_idx_prev, elig_prev,
                    w_prev[0], w_prev[1], w_prev[2], w_prev[3]
                )
            else:
                dut._log.info(
                    "[SB] OK PASSED Grant expectations t=%s  gi=%d  elig=%04b  w={%d,%d,%d,%d}",
                    _time_ns(), gi, elig_prev,
                    w_prev[0], w_prev[1], w_prev[2], w_prev[3]
                )
            # Mirror ROTATE rule: advance when !req[curr] OR (ready & valid)
            if (((req >> gi) & 1) == 0) or (ready and valid):
                rr_ptr = (gi + 1) % 4

        # Compute expected for next cycle
        maxw = _max_weight_elig(w, elig_T)
        tie_mask = 0
        for i in range(4):
            if ((elig_T >> i) & 1) and (w[i] == maxw):
                tie_mask |= (1 << i)
        exp_idx_T = _rr_pick_first(tie_mask, rr_ptr)

        # Pipeline updates
        exp_idx_prev = exp_idx_T
        elig_prev    = elig_T
        w_prev       = w[:]
        gv_prev      = gv

# ==========================================================
# p_max_next
#   $rose(new_grant) |=> (f_weight_prev(gi) == max_w_T)
#   Here: at T+1, compare w_prev[gi] vs max_weight_elig(w_prev, elig_prev)
# ==========================================================
async def max_weight_next_checker(dut, H):
    gv_prev = 0
    w_prev  = [0,0,0,0]
    elig_prev = 0

    while True:
        await RisingEdge(dut.clk)
        if int(dut.rst_n.value) == 0:
            gv_prev=0; w_prev=[0,0,0,0]; elig_prev=0
            continue

        w = [ int(H["w"][i].value) & 0x7 for i in range(4) ]
        req   = int(H["req"].value)   & 0xF
        valid = int(H["valid"].value) & 0x1
        gv    = int(H["gv"].value)    & 0xF
        gi    = int(H["gi"].value)    & 0x3

        elig_T = req if valid else 0
        new_grant = (gv_prev == 0) and (gv != 0)

        if new_grant:
            mw_prev = _max_weight_elig(w_prev, elig_prev)
            fw_prev = w_prev[gi]
            if fw_prev != mw_prev:
                mw_curr = _max_weight_elig(w, elig_T)
                dut._log.error(
                    "=> Next-Cycle mismatch t=%s: gi=%d fw_prev=%d mw_prev=%d elig_prev=%04b "
                    "mw_curr=%d elig_curr=%04b",
                    _time_ns(), gi, fw_prev, mw_prev, elig_prev, mw_curr, elig_T
                )

        w_prev = w[:]
        elig_prev = elig_T
        gv_prev = gv

# ==========================================================
# p_no_x_on_grant_bus
#   !(^grant_vec === 1’bx) && !(^grant_idx === 1’bx)
# ==========================================================
async def check_no_x_on_grant_bus(dut, H):
    while True:
        await RisingEdge(dut.clk)
        if int(dut.rst_n.value) == 0:
            continue
        if _has_xz(H["gv"]) or _has_xz(H["gi"]):
            dut._log.error(
                "[X] Unknown on grant bus t=%s gv=%s gi=%s",
                _time_ns(), H["gv"].value.binstr, H["gi"].value.binstr
            )

# ==========================================================
# p_onehot_or_zero
#   $countones(grant_vec) <= 1
# ==========================================================
async def check_onehot_or_zero(dut, H):
    while True:
        await RisingEdge(dut.clk)
        if int(dut.rst_n.value) == 0:
            continue
        if _has_xz(H["gv"]):
            continue
        gv = int(H["gv"].value) & 0xF
        if _count_ones_4(gv) > 1:
            dut._log.error("[SB] onehot violation t=%s gv=%04b", _time_ns(), gv)

# ==========================================================
# p_vec_matches_idx
#   (gv == 0) || (gv == (1 << gi))
# ==========================================================
async def check_vec_matches_idx(dut, H):
    while True:
        await RisingEdge(dut.clk)
        if int(dut.rst_n.value) == 0:
            continue
        if _has_xz(H["gv"]) or _has_xz(H["gi"]):
            continue
        gv = int(H["gv"].value) & 0xF
        gi = int(H["gi"].value) & 0x3
        if gv != 0 and gv != (1 << gi):
            dut._log.error("[SB] vec!=idx t=%s gv=%04b gi=%d", _time_ns(), gv, gi)

# ==========================================================
# p_no_rotate_without_accept
#   (gv != 0 && !(ready && valid)) |=> $stable(grant_idx)
# ==========================================================
async def check_no_rotate_without_accept(dut, H):
    hold_check = False
    gi_hold = 0
    while True:
        await RisingEdge(dut.clk)
        if int(dut.rst_n.value) == 0:
            hold_check = False
            continue

        gv    = int(H["gv"].value)    & 0xF
        gi    = int(H["gi"].value)    & 0x3
        ready = int(H["ready"].value) & 0x1
        valid = int(H["valid"].value) & 0x1

        # If obligation armed last cycle, check it now
        if hold_check:
            if gi != gi_hold:
                dut._log.error(
                    "[SB] rotate-without-accept t=%s prev_gi=%d curr_gi=%d",
                    _time_ns(), gi_hold, gi
                )
            hold_check = False

        # Arm obligation for next cycle if antecedent holds now
        if (gv != 0) and not (ready and valid):
            hold_check = True
            gi_hold = gi

# ----------------------------------------------------------
# Start all checkers (DIRECT handles under dut)
# ----------------------------------------------------------
def start_all_checkers(dut):
    H = {
        "gv":    dut.grant_vec,         # logic [3:0]
        "gi":    dut.grant_idx,         # logic [1:0]
        "req":   dut.req_stub,          # logic [3:0]
        "ready": dut.ready_stub,        # logic
        "valid": dut.valid_stub,        # logic
        "w":    [dut.weight[0], dut.weight[1], dut.weight[2], dut.weight[3]],
    }
    cocotb.start_soon(rr_expected_index_scoreboard(dut, H))
    cocotb.start_soon(max_weight_next_checker(dut, H))
    cocotb.start_soon(check_no_x_on_grant_bus(dut, H))
    cocotb.start_soon(check_onehot_or_zero(dut, H))
    cocotb.start_soon(check_vec_matches_idx(dut, H))
    cocotb.start_soon(check_no_rotate_without_accept(dut, H))

###########################################################################


@cocotb.test()
async def test_project(dut):
    # Clock: template uses 100 ns; keep it unless you need 10 ns like SV TB
    cocotb.start_soon(Clock(dut.clk, 100, units="ns").start())

    # TinyQV bridge
    tqv = TinyQV(dut, PERIPHERAL_NUM)
    await tqv.reset()

    tb  = ArbiterTB(dut, tqv)
   
    start_all_checkers(dut)

    # === Test 1: Equal Weights 1:1:1:1 (directed anchor) ===
    await tb.cfg_weights(1,1,1,1)
    await tb.drive_stubs(reqs=0b1111, ready=1, valid=1)
    for _ in range(12):
        await tb.show_grant_status("T1")

    # === Test 2: Weighted 2:1:1:2 (directed) ===
    await tb.cfg_weights(2,1,1,2)
    await tb.drive_stubs(reqs=0b1111, ready=1, valid=1)
    for _ in range(20):
        await tb.show_grant_status("T2")

    # === Test 3: Randomized Trials (Python RNG = constraints) ===
    SEED   = int(os.getenv("SEED",   "2"))
    TRIALS = int(os.getenv("TRIALS", "8"))
    CYCLES = int(os.getenv("CYCLES", "10"))
    rnd = random.Random(SEED)
    cfg = ArbiterCfg(rnd)

    await ClockCycles(dut.clk, 5)
    for t in range(TRIALS):
        s = cfg.randomize(force_rv11=False)   # can be modified if needed { rv_code==2'b11; }
        ArbiterCfg.show(dut, f"RAND t={t}", s)

        await tb.cfg_weights(*s["w"])
        await tb.drive_stubs(s["reqs"], s["ready"], s["valid"])

        for _ in range(CYCLES):
            await tb.show_grant_status(f"T3 t={t}")
