#!/usr/bin/env python3
"""
uart_host.py  —  PC tester for Systolic Array FPGA accelerator
Protocol:
  SEND  8 bytes: [a0,a1,a2,a3,w0,w1,w2,w3]  signed int8
  RECV 48 bytes: 16 results × 3 bytes (19-bit signed encoding)
    Byte 0: {5'h0, bit18:16}  top 3 bits
    Byte 1: bits[15:8]
    Byte 2: bits[7:0]
"""
import argparse, sys, time
try:
    import serial
except ImportError:
    print("pip install pyserial"); sys.exit(1)

BAUD    = 115_200
TIMEOUT = 5.0
N       = 10   # COMPUTE_CYCLES

def to_int8(v):
    return max(-128, min(127, int(v))) & 0xFF

def from_19bit(b0, b1, b2):
    raw = ((b0 & 0x07) << 16) | (b1 << 8) | b2
    return raw - (1 << 19) if raw & (1 << 18) else raw

def expected(a, w, r, c):
    return (N - max(r,c)) * int(a[r]) * int(w[c])

def run(port, a, w):
    print(f"\n{'─'*50}")
    print(f"  Port: {port}  |  a={a}  w={w}")
    print(f"{'─'*50}")

    payload = bytes(to_int8(v) for v in a+w)
    try:
        ser = serial.Serial(port, BAUD, timeout=TIMEOUT)
    except serial.SerialException as e:
        print(f"[ERROR] {e}"); sys.exit(1)

    time.sleep(0.1)
    ser.reset_input_buffer()
    ser.write(payload); ser.flush()
    print(f"  Sent: {list(payload)}")

    rx = b""
    t0 = time.time()
    while len(rx) < 48 and (time.time()-t0) < TIMEOUT:
        rx += ser.read(48-len(rx))
    ser.close()

    if len(rx) < 48:
        print(f"[ERROR] Timeout: got {len(rx)}/48 bytes"); sys.exit(1)

    results = [from_19bit(rx[i*3], rx[i*3+1], rx[i*3+2]) for i in range(16)]
    got = [[results[r*4+c] for c in range(4)] for r in range(4)]
    exp = [[expected(a,w,r,c) for c in range(4)] for r in range(4)]

    print(f"\n  {'═'*42}")
    print(f"  FPGA Result:")
    for row in got: print("  │ "+"  ".join(f"{v:8d}" for v in row)+" │")
    print(f"  {'═'*42}")
    print(f"  Expected:")
    for row in exp: print("  │ "+"  ".join(f"{v:8d}" for v in row)+" │")

    passed = sum(got[r][c]==exp[r][c] for r in range(4) for c in range(4))
    failed = 16 - passed
    if failed:
        for r in range(4):
            for c in range(4):
                if got[r][c] != exp[r][c]:
                    print(f"  FAIL [{r}][{c}] got={got[r][c]} exp={exp[r][c]}")
    print(f"\n  {passed}/16 PASSED  |  {failed} FAILED")
    return failed == 0

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--port", required=True)
    p.add_argument("--a", nargs=4, type=int, default=[1,2,3,4])
    p.add_argument("--w", nargs=4, type=int, default=[1,2,3,4])
    args = p.parse_args()
    ok = run(args.port, args.a, args.w)
    sys.exit(0 if ok else 1)
