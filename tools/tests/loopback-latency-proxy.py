"""Owned 8.60 QA relay. Delays whole frames; persists counts, never payloads/keys."""
import argparse
import asyncio
import base64
import collections
import json
from pathlib import Path
import random
import struct
import time
import zlib


def rsa_numbers(path):
    pem = Path(path).read_text(encoding="ascii")
    if "BEGIN RSA PRIVATE KEY" not in pem:
        raise ValueError("Owned fixture requires its PKCS1 RSA key")
    raw = base64.b64decode("".join(line for line in pem.splitlines() if not line.startswith("---")))

    def field(data, pos):
        tag, length = data[pos], data[pos + 1]
        pos += 2
        if length & 128:
            n = length & 127
            length = int.from_bytes(data[pos:pos+n], "big")
            pos += n
        end = pos + length
        if end > len(data):
            raise ValueError("Truncated fixture RSA key")
        return tag, data[pos:end], end

    tag, sequence, _ = field(raw, 0)
    if tag != 48:
        raise ValueError("Invalid fixture RSA key")
    values, cursor = [], 0
    while cursor < len(sequence):
        tag, value, cursor = field(sequence, cursor)
        if tag != 2:
            raise ValueError("Invalid fixture RSA integer")
        values.append(int.from_bytes(value, "big"))
    return values[1], values[3]


def decrypt(data, key):
    if not data or len(data) % 8:
        raise ValueError("Invalid encrypted QA frame")
    output = bytearray()
    for offset in range(0, len(data), 8):
        left, right = struct.unpack_from("<II", data, offset)
        total = 0xC6EF3720
        for _ in range(32):
            right = (right - ((((left << 4) ^ (left >> 5)) + left) ^ (total + key[(total >> 11) & 3]))) & 0xFFFFFFFF
            total = (total - 0x9E3779B9) & 0xFFFFFFFF
            left = (left - ((((right << 4) ^ (right >> 5)) + right) ^ (total + key[total & 3]))) & 0xFFFFFFFF
        output.extend(struct.pack("<II", left, right))
    size = struct.unpack_from("<H", output)[0]
    if not 0 < size <= len(output)-2 or len(output)-2-size > 7:
        raise ValueError("Invalid QA plaintext length")
    return output[2:2+size]


class Metrics:
    def __init__(self, args):
        self.args = args
        self.started = time.monotonic()
        self.events = collections.defaultdict(list)
        self.connections = 0
        self.closed = 0
        self.errors = []
        self.frames = 0

    def record(self, payload):
        if self.frames >= 100000:
            raise ValueError("QA capture capacity exhausted")
        label = "%02X" % payload[0]
        if payload[0] == 0x32 and len(payload) >= 4:
            size = struct.unpack_from("<H", payload, 2)[0]
            if len(payload) != 4 + size:
                raise ValueError("Invalid extended QA shape")
            label += ":%d" % payload[1]
            raw = bytes(payload[4:]).decode("utf-8")
            if raw.startswith("{"):
                value = json.loads(raw)
                action = value.get("action", value.get("protocol", value.get("response", "json")))
                if isinstance(action, str) and len(action) < 80:
                    label += ":" + action
            elif raw.startswith("cp|1|req|"):
                label += ":" + raw.split("|")[3]
            elif raw == "status":
                label += ":status"
        now = time.monotonic() - self.started
        self.events[label].append(now)
        self.events["all"].append(now)
        self.frames += 1

    @staticmethod
    def peak(events, window):
        left = peak = 0
        for right, stamp in enumerate(events):
            while stamp - events[left] >= window:
                left += 1
            peak = max(peak, right-left+1)
        return peak

    def save(self):
        data = {"scope": "loopback-only actual encrypted client frames", "rttMs": self.args.rtt_ms,
                "jitterMs": self.args.jitter_ms, "connections": self.connections, "closed": self.closed,
                "frames": self.frames, "errors": self.errors, "byOpcodeAction": {}}
        for label, events in sorted(self.events.items()):
            data["byOpcodeAction"][label] = {"count": len(events), "P1": self.peak(events, 1), "P10": self.peak(events, 10)}
        target = Path(self.args.report)
        target.parent.mkdir(parents=True, exist_ok=True)
        temporary = target.with_suffix(".pending")
        temporary.write_text(json.dumps(data, indent=2), encoding="utf-8")
        temporary.replace(target)


async def run(args):
    modulus, exponent = rsa_numbers(args.server_key)
    metrics = Metrics(args)

    async def connection(client_reader, client_writer):
        metrics.connections += 1
        number = metrics.connections
        key = None
        server_writer = None
        randomizer = random.Random(0x860 + number)
        try:
            server_reader, server_writer = await asyncio.open_connection("127.0.0.1", 7175)

            async def direction(reader, writer, client_to_server):
                queue = asyncio.Queue(maxsize=256)

                async def receive():
                    nonlocal key
                    previous_due = 0
                    while True:
                        try:
                            header = await reader.readexactly(2)
                            size = struct.unpack("<H", header)[0]
                            if not 0 < size < 24574:
                                raise ValueError("Frame outside QA bound")
                            body = await reader.readexactly(size)
                        except asyncio.IncompleteReadError:
                            await queue.put(None)
                            return
                        if client_to_server:
                            if zlib.adler32(body[4:]) != struct.unpack_from("<I", body)[0]:
                                raise ValueError("QA client checksum mismatch")
                            if key is None:
                                if len(body) != 265:
                                    raise ValueError("Unexpected owned 860 handshake shape")
                                plain = pow(int.from_bytes(body[9:137], "big"), exponent, modulus).to_bytes(128, "big")
                                if plain[0] != 0:
                                    raise ValueError("Cannot decrypt owned fixture handshake")
                                key = struct.unpack_from("<IIII", plain, 1)
                            else:
                                metrics.record(decrypt(body[4:], key))
                        delay = max(0, args.rtt_ms/2 + randomizer.uniform(-args.jitter_ms, args.jitter_ms)) / 1000
                        due = max(previous_due, time.monotonic()+delay)
                        previous_due = due
                        await queue.put((due, header+body))

                async def transmit():
                    while True:
                        entry = await queue.get()
                        if entry is None:
                            if writer.can_write_eof():
                                writer.write_eof()
                            return
                        due, data = entry
                        await asyncio.sleep(max(0, due-time.monotonic()))
                        writer.write(data)
                        await writer.drain()

                await asyncio.gather(receive(), transmit())

            await asyncio.gather(direction(client_reader, server_writer, True), direction(server_reader, client_writer, False))
        except (ConnectionError, BrokenPipeError, asyncio.IncompleteReadError):
            pass  # Force logout intentionally closes the transport.
        except Exception as error:
            metrics.errors.append(type(error).__name__+": "+str(error))
        finally:
            key = None
            client_writer.close()
            if server_writer:
                server_writer.close()
            metrics.closed += 1
            metrics.save()

    listener = await asyncio.start_server(connection, "127.0.0.1", 7176)
    print("LOOPBACK_LATENCY_PROXY_READY", flush=True)
    async with listener:
        deadline = time.monotonic() + args.duration
        while time.monotonic() < deadline:
            metrics.save()
            if args.stop_file and Path(args.stop_file).exists():
                break
            await asyncio.sleep(.25)
    metrics.save()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--rtt-ms", type=int, choices=(0, 150, 500), required=True)
    parser.add_argument("--jitter-ms", type=int, choices=(0, 20, 50), default=0)
    parser.add_argument("--server-key", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--stop-file")
    parser.add_argument("--duration", type=int, default=180)
    asyncio.run(run(parser.parse_args()))
