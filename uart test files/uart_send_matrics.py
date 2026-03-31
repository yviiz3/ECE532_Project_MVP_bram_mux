import serial
import time

COM_PORT = "COM6"
BAUDRATE = 115200
MEM_FILE = "svd_vectors_200x200_img07.mem"   # 改成你现在的 mem file 名字
CHUNK_SIZE = 256
WRITE_GAP_SEC = 0.002

LITTLE_ENDIAN = True
WORD_BITS = 16
BYTES_PER_WORD = 2
MAX_VALUE = (1 << WORD_BITS) - 1


def load_mem_as_bytes(path: str) -> bytes:
    out = bytearray()

    with open(path, "r", encoding="utf-8") as f:
        for line_num, line in enumerate(f, 1):
            s = line.strip()

            if not s:
                continue

            if s.startswith("//") or s.startswith("#"):
                continue

            if s.lower().startswith("0x"):
                s = s[2:]

            value = int(s, 16)

            if not (0 <= value <= MAX_VALUE):
                raise ValueError(
                    f"Line {line_num}: value out of {WORD_BITS}-bit range: {s}"
                )

            if LITTLE_ENDIAN:
                # low byte first, then high byte
                out.append(value & 0xFF)
                out.append((value >> 8) & 0xFF)
            else:
                # high byte first, then low byte
                out.append((value >> 8) & 0xFF)
                out.append(value & 0xFF)

    return bytes(out)


def send_all(ser: serial.Serial, data: bytes) -> None:
    total = len(data)
    sent = 0

    print(f"TX start: {total} bytes")

    while sent < total:
        end = min(sent + CHUNK_SIZE, total)
        n = ser.write(data[sent:end])

        if n and n > 0:
            sent += n
            print(f"\rTX: {sent}/{total}", end="", flush=True)

        time.sleep(WRITE_GAP_SEC)

    ser.flush()
    print("\nTX done")


def main() -> None:
    tx_data = load_mem_as_bytes(MEM_FILE)

    print(f"Loaded: {MEM_FILE}")
    print(f"Total bytes: {len(tx_data)}")
    print(f"Total {WORD_BITS}-bit words: {len(tx_data) // BYTES_PER_WORD}")

    ser = serial.Serial(
        port=COM_PORT,
        baudrate=BAUDRATE,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=0.2,
    )

    try:
        time.sleep(0.2)
        ser.reset_input_buffer()
        ser.reset_output_buffer()

        send_all(ser, tx_data)

    finally:
        ser.close()


if __name__ == "__main__":
    main()