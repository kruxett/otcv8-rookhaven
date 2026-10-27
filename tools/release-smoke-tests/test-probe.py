"""Offline wire-framing/failure-cleanup check. No real sockets or credentials."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import struct
import sys
from unittest.mock import patch
import uuid
import zlib

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("release_probe", HERE / "live-compatibility.py")
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
KEY = (0x11223344,) * 4
BASE = HERE.parents[1] / "out/release-smoke-20261027" / ("probe-fixture-" + uuid.uuid4().hex)
BASE.mkdir(parents=True)


def frame(clear, encrypted=True):
    if encrypted:
        clear = struct.pack("<H", len(clear)) + clear
        clear = probe.wire.encrypt(clear.ljust((len(clear) + 7) // 8 * 8, b"\0"), KEY)
    packet = struct.pack("<I", zlib.adler32(clear)) + clear
    return struct.pack("<H", len(packet)) + packet


def run(label):
    config = {"loginHost": "testserver2.rookhaven-ot.com", "loginPort": 7173,
              "oldVersion": 10099, "newVersion": 10100, "oldResourceFingerprint": "a" * 64,
              "oldExeSha256": "b" * 64, "newResourceFingerprint": "c" * 64,
              "newExeSha256": "d" * 64, "ownedQaAccountConfirmed": True}
    # Deliberately public fake credentials, never an actual QA account.
    private = {("account" if label == "healthy" else "accountName"): "SyntheticOnly",
               "password": "PublicDummy", "characterName": "Synthetic"}
    cfg, credential, output = (BASE / (label + suffix) for suffix in ("-config.json", "-dummy.json", "-result.json"))
    cfg.write_text(json.dumps(config))
    credential.write_text(json.dumps(private))
    products = [{"id": offer, "type": row[2], "title": row[0], "cost": row[1]}
                for offer, row in probe.LEGACY_PRODUCTS.items()]
    if label == "legacy-row-replaced": products[4]["title"] = "Unapproved replacement"
    outfit_titles = [family + " (" + gender + ")" for family in probe.FAMILIES for gender in ("Female", "Male")]
    outfits = [{"id": 6001 + i, "type": "outfit", "title": outfit_titles[i], "description": "Ö" * 400,
                "cost": 250, "outfit": {"type": 373 + i, "addons": 3}} for i in range(26)]
    catalog = {"action": "categories", "status": {"points": 1000},
               "data": [{"name": "Premium", "offers": products[:3]},
                        {"name": "Utility", "offers": products[3:]}, {"name": "Outfits", "offers": outfits}]}
    connections, actions = [], []

    class FakeSocket:
        def __init__(self):
            self.index = len(connections)
            connections.append(self)
            self.buffer, self.first, self.logout = bytearray(), True, False
            if self.index:
                self.buffer.extend(frame(b"\x06\0\x1f" + struct.pack("<IB", 1234, 37), False))

        def __enter__(self): return self
        def __exit__(self, *ignored): return False
        def settimeout(self, timeout): pass

        def recv(self, size):
            if not self.buffer: raise EOFError()
            value = bytes(self.buffer[:size])
            del self.buffer[:size]
            return value

        def sendall(self, packet):
            if self.first:
                self.first = False
                if self.index == 0:
                    payload = (b"\x64\x01" + probe.wire.string("Synthetic") + probe.wire.string("Rookhaven")
                               + bytes((192, 168, 1, 44)) + struct.pack("<HH", 7174, 0))
                elif self.index == 2:
                    # Native RSA_decrypt(msg, 2) closes before XTEA on missing
                    # block2. No encrypted verification message can be sent.
                    return
                elif self.index == 4 or (label == "unexpected-old-acceptance" and self.index == 1):
                    payload = b"\x32\0\0\0\x17"
                else:
                    payload = b"\x14" + probe.wire.string("Client verification failed. Please update the official client.")
                self.buffer.extend(frame(payload))
                return
            clear = probe.wire.decrypt(packet[6:], KEY)
            if clear == b"\x14":
                if label == "logout-send-fails": raise OSError("Synthetic failed logout send")
                self.logout = True
                return
            assert clear[:2] == b"\x32\xc9", "Unexpected gameplay command from read-only probe"
            message, _ = probe.string_at(clear, 2)
            action = json.loads(message)["action"]
            assert action in ("init", "history")
            actions.append(action)
            value = catalog if action == "init" else {"action": "history", "data": [], "status": {"points": 1000}}
            encoded = json.dumps(value, ensure_ascii=False).encode()
            chunks = [encoded[i:i + 8000] for i in range(0, len(encoded), 8000)]
            payload = b""
            for i, chunk in enumerate(chunks):
                marker = b"" if len(chunks) == 1 else b"S" if i == 0 else b"E" if i == len(chunks) - 1 else b"P"
                chunk = marker + chunk
                payload += b"\x32\xc9" + struct.pack("<H", len(chunk)) + chunk
            response = frame(payload)
            if label == "bad-server-checksum" and action == "init":
                response = response[:2] + bytes([response[2] ^ 1]) + response[3:]
            self.buffer.extend(response)

    failed = False
    with patch.object(probe.socket, "create_connection", side_effect=lambda *a, **kw: FakeSocket()), \
         patch.object(probe.socket, "gethostbyname", return_value="192.168.1.44"), \
         patch.object(probe.secrets, "randbits", return_value=KEY[0]), \
         patch.object(probe.select, "select", return_value=([], [], [])), \
         patch.object(probe.time, "sleep"), \
         patch.object(sys, "argv", ["probe", "--config", str(cfg), "--private-account-file", str(credential), "--output", str(output)]), \
         contextlib.redirect_stdout(io.StringIO()):
        try: probe.main()
        except AssertionError: failed = True
    result = json.loads(output.read_text())
    if label == "healthy":
        assert not failed and result["state"].startswith("PASS_")
        assert len(result["cases"]) == 4 and all(row["passed"] for row in result["cases"])
        assert actions == ["init", "history", "init"] and connections[-1].logout
        assert result["catalog"]["fragmentMarkers"] == ["S", "P", "P", "E"]
    elif label == "logout-send-fails":
        assert failed and result["state"] == "FAIL"
        assert result["lastAttempt"]["accepted"] and not result["lastAttempt"]["logoutSent"]
        assert not connections[-1].logout
    else:
        assert failed and result["state"] == "FAIL"
        assert result["lastAttempt"]["accepted"] and result["lastAttempt"]["logoutSent"]
        assert connections[-1].logout
    return {"case": label, "passed": True, "realNetworkUsed": False}


results = [run(label) for label in ("healthy", "bad-server-checksum", "unexpected-old-acceptance", "logout-send-fails", "legacy-row-replaced")]
(BASE / "receipt.json").write_text(json.dumps({"state": "PASS_OFFLINE_PROBE_REGRESSIONS", "cases": results}, indent=2))
print(json.dumps({"state": "PASS_OFFLINE_PROBE_REGRESSIONS", "cases": results}))
