# cdc_primitives

Library of generic Clock Domain Crossing (CDC) primitives in SystemVerilog,
Verilog, and VHDL. All modules are fully synthesizable, vendor-agnostic, and
suitable for FPGA and ASIC flows.

---

## Repository Structure

```
cdc/
├── synchronizers/     # Single-bit synchronizers and event synchronizers
│   ├── cdc_sync2      # 2-flip-flop synchronizer
│   ├── cdc_sync3      # 3-flip-flop synchronizer (higher MTBF)
│   ├── cdc_pulse_sync # Toggle-based pulse synchronizer
│   └── cdc_toggle_sync# Toggle event synchronizer with pulse output
├── handshakes/        # Multi-bit data transfer primitives
│   ├── cdc_handshake  # 4-phase request/acknowledge handshake
│   └── cdc_data_sync  # Bundled-data synchronizer (multi-bit + valid/ready)
├── fifo/              # Streaming CDC
│   └── cdc_async_fifo # Dual-clock async FIFO (Gray-coded pointers)
├── reset/             # Reset distribution
│   └── cdc_reset_sync # Async-assert / sync-deassert reset synchronizer
└── examples/          # Simple top-level instantiation examples
```

Each module is provided in three languages:
- **`.sv`** – SystemVerilog (primary implementation)
- **`.v`**  – Verilog-2001 (compatible with older toolchains)
- **`.vhd`** – VHDL-2008

---

## Module Overview

### 1. `cdc_sync2` — 2-Flip-Flop Synchronizer

**Purpose:** Synchronize a quasi-static single-bit signal across clock domains.

**CDC Principle:** Two flip-flops in series in the destination domain reduce the
probability of metastability propagating to downstream logic exponentially.

**Parameters:**
| Parameter   | Default | Description                         |
|-------------|---------|-------------------------------------|
| `RESET_VAL` | `1'b0`  | Reset value for synchronizer FFs    |

**Ports:**
| Port        | Dir | Description                                      |
|-------------|-----|--------------------------------------------------|
| `clk_dst`   | in  | Destination domain clock                         |
| `rst_dst_n` | in  | Destination domain reset (active low, async)     |
| `data_src`  | in  | Single-bit input from source domain              |
| `data_dst`  | out | Synchronized output in destination domain        |

**Latency:** 2 destination clock cycles.

**Limitation:** Only safe for single-bit signals that are quasi-static between
transitions. Use `cdc_pulse_sync` for short pulses.

---

### 2. `cdc_sync3` — 3-Flip-Flop Synchronizer

**Purpose:** Higher-MTBF single-bit synchronizer for high-frequency designs.

**CDC Principle:** Same as `cdc_sync2` with one additional FF stage, providing
approximately `e^(Tclk/tau)` more metastability rejection.

**Parameters:** Same as `cdc_sync2`.

**Latency:** 3 destination clock cycles.

**Use when:** The destination clock is >500 MHz, or when safety-critical
applications demand very high MTBF.

---

### 3. `cdc_pulse_sync` — Pulse Synchronizer

**Purpose:** Cross a single-cycle pulse safely between any two clock domains.

**CDC Principle (Toggle-Based):**
1. Source: Toggle a FF on each input pulse (persistent level change).
2. Sync: 2-stage FF synchronizer moves the toggle to the destination domain.
3. Destination: XOR edge detection regenerates a single-cycle pulse.

**Ports:**
| Port        | Dir | Description                                      |
|-------------|-----|--------------------------------------------------|
| `clk_src`   | in  | Source domain clock                              |
| `rst_src_n` | in  | Source domain reset (active low)                 |
| `pulse_src` | in  | Single-cycle pulse in source domain              |
| `clk_dst`   | in  | Destination domain clock                         |
| `rst_dst_n` | in  | Destination domain reset (active low)            |
| `pulse_dst` | out | Single-cycle pulse in destination domain         |

**Limitation:** Minimum spacing between source pulses ≈ 4 destination clock cycles.

---

### 4. `cdc_toggle_sync` — Toggle Event Synchronizer

**Purpose:** Synchronize a toggle signal and optionally generate a pulse per event.

**CDC Principle:** The persistent toggle is synchronized with a 2FF chain. XOR
of current and previous synchronized value produces a one-cycle pulse per event.

**Ports:**
| Port         | Dir | Description                                     |
|--------------|-----|-------------------------------------------------|
| `clk_dst`    | in  | Destination domain clock                        |
| `rst_dst_n`  | in  | Destination domain reset (active low)           |
| `toggle_src` | in  | Toggle signal from source domain                |
| `toggle_dst` | out | Synchronized toggle in destination domain       |
| `pulse_dst`  | out | One-cycle pulse per toggle event                |

---

### 5. `cdc_handshake` — Request/Acknowledge Handshake

**Purpose:** Reliable 4-phase req/ack handshake for low-bandwidth control signals.

**CDC Principle:** Only single-bit REQ and ACK cross the boundary, each through
a 2-stage synchronizer. The 4-phase protocol ensures both sides complete before
proceeding.

**4-Phase Protocol:**
1. Source asserts `src_req_i` and holds it high.
2. Destination sees `dst_req_o` high, processes, asserts `dst_ack_i`.
3. Source sees `src_ack_o` high, deasserts `src_req_i`.
4. Destination sees `dst_req_o` fall, deasserts `dst_ack_i`.

**Limitation:** Low throughput — one transaction per ~4× (worst-case domain latency).

---

### 6. `cdc_data_sync` — Bundled-Data Synchronizer

**Purpose:** Transfer a multi-bit word atomically across clock domains.

**CDC Principle:** Data is held stable in a source-domain hold register throughout
a `cdc_handshake` cycle. The destination captures the data when it sees the
synchronized REQ edge; by then the data has been stable ≥ 2 destination clock
cycles.

**Parameters:**
| Parameter    | Default | Description             |
|--------------|---------|-------------------------|
| `DATA_WIDTH` | `8`     | Width of the data bus   |

**Key Timing Constraint (required in synthesis tool):**
```
set_max_delay -datapath_only \
    -from [get_cells *src_data_hold*] \
    -to   [get_cells *dst_data_o*]
```

**Limitation:** Data must remain stable while `src_valid_i` is asserted. Not
suitable for streaming — use `cdc_async_fifo` instead.

---

### 7. `cdc_async_fifo` — Asynchronous FIFO

**Purpose:** High-bandwidth data streaming between two independent clock domains.

**CDC Principle (Gray-Coded Pointers):**
Gray code ensures only 1 bit changes per pointer increment, making pointer
synchronization safe. The synchronized Gray-coded pointers are used to generate
conservative full/empty flags.
- **Empty:** `rd_gray == wr_gray_sync`
- **Full:** `wr_gray == {~rd_gray_sync[MSB], ~rd_gray_sync[MSB-1], rd_gray_sync[rest]}`

**Parameters:**
| Parameter     | Default | Description                             |
|---------------|---------|-----------------------------------------|
| `DATA_WIDTH`  | `8`     | Width of each FIFO entry                |
| `DEPTH`       | `16`    | FIFO depth (must be power of 2, ≥ 4)   |
| `SYNC_STAGES` | `2`     | Pointer synchronizer stages (≥ 2)       |

**Limitation:** `DEPTH` must be a power of 2 and ≥ 4. Full/empty flags have
~2-cycle pessimism due to pointer synchronization latency.

---

### 8. `cdc_reset_sync` — Reset Synchronizer

**Purpose:** Generate a clean, glitch-free reset in a target clock domain from
an asynchronous reset source.

**CDC Principle (Async Assert / Sync Deassert):**
- **Assert:** `rst_async_n` low immediately clears all synchronizer FFs
  (asynchronous), ensuring fast reset propagation regardless of clock state.
- **Deassert:** After `rst_async_n` goes high, `SYNC_STAGES` clean clock edges
  are required before `rst_sync_n` releases, preventing metastability on the
  reset deassertion edge.

**Parameters:**
| Parameter     | Default | Description                        |
|---------------|---------|------------------------------------|
| `SYNC_STAGES` | `2`     | Synchronizer stages (≥ 2)          |

**Requirement:** The target clock must be running when `rst_async_n` is released.

---

## CDC Safety Guidelines

1. **Single-bit crossings:** Use `cdc_sync2` or `cdc_sync3` for quasi-static
   signals. Use `cdc_pulse_sync` for short pulses.

2. **Multi-bit crossings:** Never use a simple synchronizer on a multi-bit bus.
   Use `cdc_data_sync` (low bandwidth) or `cdc_async_fifo` (streaming).

3. **Gray code only:** When crossing pointers or counters, first convert to
   Gray code (only 1 bit changes per increment).

4. **Synthesis constraints:** Always apply `ASYNC_REG`/`keep_hierarchy`
   constraints on synchronizer chains, and `set_max_delay -datapath_only`
   on bundled-data bus paths.

5. **Reset:** Always use `cdc_reset_sync` when distributing resets to multiple
   clock domains.

---

## License

See [LICENSE](LICENSE).
