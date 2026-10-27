"""Read-only DEV RH2 compatibility/catalog smoke with one owned ordinary QA account.

This is a wire compatibility test, not remote attestation. It neither starts a
server nor edits accounts, profiles, items, outfits, points or privileges. The
sole successful login sends init/history/init, then logout. Run it serially with
any native QA account session. Credentials are read privately and never emitted.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import secrets
import select
import socket
import struct
import time
import zlib


ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("wire", ROOT / "tools/tests/client-login-integrity.py")
wire = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wire)


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def bytes_at(data, offset):
    require(offset + 2 <= len(data), "Truncated native string header")
    length = struct.unpack_from("<H", data, offset)[0]
    offset += 2
    require(offset + length <= len(data), "Truncated native string")
    return data[offset:offset + length], offset + length


def string_at(data, offset):
    value, offset = bytes_at(data, offset)
    return value.decode("utf-8"), offset


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--private-account-file", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    cfg = json.loads(args.config.read_text(encoding="utf-8-sig"))
    require(cfg["loginHost"] == "testserver2.rookhaven-ot.com" and cfg["loginPort"] == 7173,
            "Only the designated DEV login route is allowed")
    require(cfg["ownedQaAccountConfirmed"] is True, "Owned ordinary QA account must be confirmed by the release owner")
    require(not args.output.exists(), "Refuse to replace existing smoke evidence")
    creds = json.loads(args.private_account_file.read_text(encoding="utf-8-sig"))
    character = creds.get("characterName") or creds.get("character") or cfg.get("character")
    require(isinstance(character, str) and character, "Owned QA character is missing")
    pins = {}
    for version in ("old", "new"):
        pins[version] = (cfg[version + "ResourceFingerprint"], cfg[version + "ExeSha256"])
        require(all(re.fullmatch("[0-9a-f]{64}", value) for value in pins[version]), "Invalid compatibility pin")
    require(pins["old"] != pins["new"], "Old and new compatibility claims must differ")
    const = (ROOT / "modules/gamelib/const.lua").read_text()
    rsa = int("".join(re.findall(r'"(\d+)"', const.split("OTSERV_RSA  =", 1)[1].split("CIPSOFT_RSA", 1)[0])))
    key = tuple(secrets.randbits(32) for _ in range(4))
    rows = []
    report = {"state": "FAIL", "cases": rows, "characterListPassed": False,
              "nativeGuiLoginPerformed": False, "compatibilityNotAttestation": True,
              "noPurchaseOrGameplayCommands": True}

    def rsa_block(data):
        require(len(data) <= 128, "Dedicated QA login fields exceed the native RSA block")
        return pow(int.from_bytes(data.ljust(128, b"\0"), "big"), 65537, rsa).to_bytes(128, "big")

    def send(sock, data, encrypted=False):
        if encrypted:
            data = struct.pack("<H", len(data)) + data
            data = wire.encrypt(data.ljust((len(data) + 7) // 8 * 8, b"\0"), key)
        packet = struct.pack("<I", zlib.adler32(data)) + data
        sock.sendall(struct.pack("<H", len(packet)) + packet)

    def receive(sock, encrypted=True):
        packet = wire.receive(sock)
        require(len(packet) >= 4 and struct.unpack_from("<I", packet)[0] == zlib.adler32(packet[4:]),
                "Invalid server Adler frame checksum")
        if not encrypted:
            return packet[4:]
        require((len(packet) - 4) % 8 == 0, "Invalid encrypted frame size")
        return wire.decrypt(packet[4:], key)

    # After draining the initial map frame, an init/history response consists of
    # native extended opcodes. Parse their boundaries exactly; do not scan map
    # bytes for coincidental opcode signatures. Unrelated whole frames are
    # skipped only before a catalog fragment has started.
    def collect(sock, action):
        deadline = time.monotonic() + 12
        fragments, markers = [], []
        while time.monotonic() < deadline:
            data = receive(sock)
            position = 0
            while position < len(data):
                opcode = data[position]
                position += 1
                if opcode == 0x1e:
                    send(sock, b"\x1e", True)
                    continue
                if opcode != 0x32:
                    require(not fragments, "Unrelated frame interrupted a fragmented catalog")
                    break
                require(position < len(data), "Truncated extended opcode")
                extended = data[position]
                position += 1
                payload, position = bytes_at(data, position)
                if extended != 201:
                    continue
                require(payload, "Empty shop JSON payload")
                if payload[:1] == b"S":
                    require(not fragments, "Nested JSON start fragment")
                    fragments = [payload[1:]]
                    markers.append("S")
                    continue
                if payload[:1] in (b"P", b"E"):
                    require(fragments, "JSON continuation without start")
                    fragments.append(payload[1:])
                    markers.append(chr(payload[0]))
                    if payload[:1] == b"P":
                        continue
                    payload = b"".join(fragments)
                    fragments = []
                else:
                    require(not fragments, "Unframed JSON interrupted fragments")
                message = json.loads(payload)
                require(isinstance(message, dict), "Shop JSON must be an object")
                if message.get("action") == action:
                    return message, markers, len(payload)
        raise TimeoutError("Expected read-only shop response did not arrive")

    def check_catalog(message):
        categories = message["data"]
        require(isinstance(categories, list) and len(categories) == 3, "Unexpected category count")
        offers = [offer for category in categories for offer in category["offers"]]
        outfits = [offer for offer in offers if offer["type"] == "outfit"]
        items = [offer for offer in offers if offer["type"] != "outfit"]
        require(len(offers) == 36 and len(outfits) == 26 and len(items) == 10, "Expected 26 outfits and 10 existing products")
        require([offer["id"] for offer in outfits] == list(range(6001, 6027)), "Outfit offer IDs/order differ")
        require([offer["outfit"]["type"] for offer in outfits] == list(range(373, 399)), "Native look types/order differ")
        require(all(offer["cost"] == 250 and offer["outfit"]["addons"] == 3 for offer in outfits),
                "Outfit price/addon contract differs")
        require(all(not offer.get("image") for offer in outfits), "Outfit catalog must use native creatures")
        titles = [offer["title"] for offer in items]
        require("Magic Quiver" in titles and "Keyring" in titles, "Existing Quiver/Keyring missing")
        return {"categoryNames": [category["name"] for category in categories],
                "totalOffers": len(offers), "outfitOffers": len(outfits), "existingProductOffers": len(items),
                "outfits": [{"offer": offer["id"], "title": offer["title"], "look": offer["outfit"]["type"],
                              "addons": offer["outfit"]["addons"], "cost": offer["cost"]} for offer in outfits]}

    try:
        payload = (b"\0" + struct.pack("<4I", *key) + wire.string(creds["accountName"])
                   + wire.string(creds["password"]) + wire.string("OTCv8") + struct.pack("<H", cfg["newVersion"]))
        with socket.create_connection((cfg["loginHost"], cfg["loginPort"]), timeout=12) as sock:
            send(sock, b"\x01" + struct.pack("<HHIII", 10, 860, 0, 0, 0) + rsa_block(payload))
            data = receive(sock)
        position, characters = 0, []
        while position < len(data):
            opcode = data[position]
            position += 1
            if opcode == 20:
                _, position = string_at(data, position)
            elif opcode == 100:
                count = data[position]
                position += 1
                for _ in range(count):
                    name, position = string_at(data, position)
                    world, position = string_at(data, position)
                    ip = socket.inet_ntoa(data[position:position + 4])
                    position += 4
                    port = struct.unpack_from("<H", data, position)[0]
                    position += 2
                    characters.append((name, world, ip, port))
                position += 2
            else:
                raise AssertionError("Dedicated QA character-list login refused or malformed")
        chosen = [row for row in characters if row[0] == character]
        require(len(chosen) == 1, "Dedicated QA character missing from account")
        _, world, world_ip, world_port = chosen[0]
        require(world == "Rookhaven" and world_port == 7174, "Unexpected world route")
        require(world_ip in {socket.gethostbyname(cfg["loginHost"]), "192.168.1.44"}, "Unexpected game IP")
        report["characterListPassed"] = True
        for label, version, mode, second, expected in (
            ("old_build_RH2_refused", "old", 0, True, False),
            ("missing_verification_block_refused", "new", 0, False, False),
            ("QA_mode_refused_on_normal_DEV", "new", 1, True, False),
            ("target_retail_RH2_accepted", "new", 0, True, True),
        ):
            accepted, refused, logout = False, False, False
            with socket.create_connection((world_ip, world_port), timeout=12) as sock:
                challenge = receive(sock, False)
                require(challenge[:3] == b"\x06\x00\x1f", "Unexpected native game challenge")
                timestamp, random = struct.unpack("<IB", challenge[-5:])
                payload = (b"\0" + struct.pack("<4I", *key) + b"\0" + wire.string(creds["accountName"])
                           + wire.string(character) + wire.string(creds["password"])
                           + struct.pack("<IB", timestamp, random) + wire.string("RH2"))
                body = b"\x0a" + struct.pack("<HH", 10, 860) + rsa_block(payload)
                if second:
                    material = f"RH2|{pins[version][0]}|{pins[version][1]}|{timestamp}|{random}"
                    proof = hashlib.sha256(material.encode()).hexdigest()
                    body += rsa_block(bytes([0, mode]) + wire.string(proof))
                send(sock, body)
                try:
                    for _ in range(15):
                        data = receive(sock)
                        if data.startswith(b"\x32\0\0\0"):
                            data = data[4:]
                        if data and data[0] in (0x0a, 0x17):
                            accepted = True
                            break
                        if data and data[0] == 0x14:
                            message, _ = string_at(data, 1)
                            refused = message == "Client verification failed. Please update the official client."
                            break
                except (EOFError, ConnectionResetError):
                    pass
                report["lastAttempt"] = {"case": label, "accepted": accepted, "logoutSent": False}
                try:
                    if accepted and expected:
                        # Drain initial map/status packets before requesting exact
                        # boundary parsed read-only extended-JSON response frames.
                        while select.select([sock], [], [], .25)[0]:
                            receive(sock)
                        send(sock, b"\x32\xc9" + wire.string('{"action":"init","data":{}}'), True)
                        catalog, markers, size = collect(sock, "categories")
                        require(markers[0:1] == ["S"] and markers[-1:] == ["E"] and size > 8192,
                                "Actual expanded catalog must use native S/P/E fragmentation")
                        report["catalog"] = check_catalog(catalog)
                        report["catalog"].update({"fragmentMarkers": markers, "jsonBytes": size,
                                                   "sha256": hashlib.sha256(json.dumps(catalog, sort_keys=True).encode()).hexdigest()})
                        points = catalog["status"]["points"]
                        send(sock, b"\x32\xc9" + wire.string('{"action":"history","data":{}}'), True)
                        history, _, _ = collect(sock, "history")
                        require(history["status"]["points"] == points, "Read-only history altered points")
                        send(sock, b"\x32\xc9" + wire.string('{"action":"init","data":{}}'), True)
                        after, _, _ = collect(sock, "categories")
                        require(after == catalog, "Catalog/status changed during read-only smoke")
                        report["readOnlyActions"] = ["init", "history", "init"]
                        report["catalog"]["pointsUnchanged"] = True
                        report["catalog"]["historyEntries"] = len(history["data"])
                finally:
                    if accepted:
                        try:
                            send(sock, b"\x14", True)
                            logout = True
                            time.sleep(1)
                        except OSError:
                            pass
                    report["lastAttempt"]["logoutSent"] = logout
            row = {"case": label, "accepted": accepted, "verificationRefusal": refused,
                   "logoutSent": logout, "passed": accepted if expected else refused and not accepted}
            rows.append(row)
            require(row["passed"], "Compatibility case failed: " + label)
            time.sleep(1)
        report["state"] = "PASS_LIVE_DEV_COMPATIBILITY_AND_READ_ONLY_CATALOG"
    except Exception as error:
        # Only our stable public diagnostic strings are retained. Never include
        # raw packets, credential mappings, account fields or exception reprs.
        report["failureType"] = type(error).__name__
        if isinstance(error, (AssertionError, TimeoutError)):
            report["failure"] = str(error)
        raise
    finally:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(json.dumps({"state": report["state"], "cases": rows,
                          "characterListPassed": report["characterListPassed"]}))


if __name__ == "__main__":
    main()
