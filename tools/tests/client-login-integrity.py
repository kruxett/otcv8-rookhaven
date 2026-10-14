"""RH2 wire regressions against the disposable IPv4 loopback fixture only.

No remote hosts or credentials are accepted. Expected pins and the RSA key come
from the local fixture. A claimed build hash is compatibility data, not attestation.
"""
import argparse
import hashlib
import json
from pathlib import Path
import socket
import struct
import time
import zlib
from cryptography.hazmat.primitives.serialization import load_pem_private_key


def string(value):
    data = value.encode()
    return struct.pack('<H', len(data)) + data


def receive(sock):
    def exact(size):
        data = b''
        while len(data) < size:
            more = sock.recv(size - len(data))
            if not more:
                raise EOFError()
            data += more
        return data
    return exact(struct.unpack('<H', exact(2))[0])


def decrypt(data, key):
    out = bytearray()
    mask = 0xFFFFFFFF
    for offset in range(0, len(data), 8):
        v0, v1 = struct.unpack_from('<II', data, offset)
        total = 0xC6EF3720
        for _ in range(32):
            v1 = (v1 - ((((v0 << 4) ^ (v0 >> 5)) + v0) ^ (total + key[(total >> 11) & 3]))) & mask
            total = (total - 0x9E3779B9) & mask
            v0 = (v0 - ((((v1 << 4) ^ (v1 >> 5)) + v1) ^ (total + key[total & 3]))) & mask
        out += struct.pack('<II', v0, v1)
    length = struct.unpack_from('<H', out)[0]
    return bytes(out[2:2 + length])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--qa-disabled', action='store_true')
    args = parser.parse_args()
    rsa = load_pem_private_key((args.runtime / 'key.pem').read_bytes(), None).public_key().public_numbers()
    pin_file = args.runtime / 'data/client_integrity_expected.txt'
    pins = pin_file.read_text().split()
    key = (0x12345678, 0x23456789, 0x34567890, 0x45678901)
    rows = []

    def rsa_block(data):
        assert len(data) <= 128
        return pow(int.from_bytes(data.ljust(128, b'\0'), 'big'), rsa.e, rsa.n).to_bytes(128, 'big')

    def attempt(label, variant='valid', should_accept=False):
        time.sleep(0.25)
        accepted = False
        responses = []
        with socket.create_connection(('127.0.0.1', 7175), timeout=8) as sock:
            challenge = receive(sock)
            timestamp, random = struct.unpack('<IB', challenge[-5:])
            payload = b'\0' + struct.pack('<4I', *key) + b'\0'
            payload += string('passivetest') + string('Passive Tester') + string('passivetest')
            payload += struct.pack('<IB', timestamp, random)
            marker = 'CS1:00000000' if variant == 'legacy' else 'RH2'
            if variant == 'marker':
                marker = 'OTHER'
            payload += string(marker)
            material = f'RH2|{pins[0]}|{pins[1]}|{timestamp}|{random}'
            if variant == 'nonce':
                material += 'stale'
            proof = hashlib.sha256(material.encode()).hexdigest()
            if variant == 'wrong':
                proof = '0' * 64
            if variant == 'short':
                proof = '0'
            body = b'\x0a' + struct.pack('<HH', 10, 860) + rsa_block(payload)
            if variant != 'legacy':
                mode = 1 if variant == 'qa' else (2 if variant == 'mode' else 0)
                body += rsa_block(b'\0' + bytes([mode]) + string(proof))
            if variant == 'truncated':
                body = body[:-1]
            if variant == 'trailing':
                body += b'x'
            packet = struct.pack('<I', zlib.adler32(body)) + body
            sock.sendall(struct.pack('<H', len(packet)) + packet)
            try:
                for _ in range(10):
                    packet = receive(sock)
                    clear = decrypt(packet[4:], key)
                    responses.append(clear[:120].hex())
                    # Login map/creature init follows an optional extended-opcode enable.
                    if clear.startswith(b'\x32\x00\x00\x00'):
                        clear = clear[4:]
                    if clear and clear[0] in (0x0A, 0x17):
                        accepted = True
                        break
                    if clear and clear[0] == 0x14:
                        break
            except (EOFError, ConnectionResetError):
                pass
        passed = accepted == should_accept
        rows.append({'case': label, 'passed': passed, 'accepted': accepted, 'responses': responses})
        args.output.write_text(json.dumps(rows, indent=2))
        print(label, 'PASS' if passed else 'FAIL', flush=True)
        if not passed:
            raise AssertionError(rows[-1])
        time.sleep(0.5)

    attempt('stock/old CS1 login', 'legacy')
    attempt('missing RSA byte', 'truncated')
    attempt('additional trailing bytes', 'trailing')
    attempt('wrong protocol marker', 'marker')
    attempt('wrong build/resource proof', 'wrong')
    attempt('wrong challenge proof', 'nonce')
    attempt('short proof', 'short')
    attempt('unknown mode', 'mode')
    pin_text = pin_file.read_text()
    try:
        pin_file.unlink()
        attempt('missing server build pin')
        pin_file.write_text('invalid\n')
        attempt('malformed server build pin')
        pin_file.write_text(pin_text + '\nextra\n')
        attempt('ambiguous server build pin')
    finally:
        pin_file.write_text(pin_text)
    if args.qa_disabled:
        attempt('QA client refused without local test flag', 'qa')
    else:
        attempt('QA client accepted only by local fixture', 'qa', True)
    # Positive must run after the rejection cases: it proves they were not simply
    # failing because of a down server, incorrect password or broken test framing.
    attempt('matching official build proof', should_accept=True)
    print(f'{len(rows)} native server login cases passed')


if __name__ == '__main__':
    main()
