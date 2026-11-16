#!/usr/bin/env python3
"""Independently compute a TOTP code to compare against the app (stdlib only).

Usage:
    python3 scripts/verify-totp.py JBSWY3DPEHPK3PXP [--time 1700000000] [--digits 6] [--period 30]
"""
import argparse
import base64
import hashlib
import hmac
import struct
import time


def hotp(secret: bytes, counter: int, digits: int = 6, digest=hashlib.sha1) -> str:
    message = struct.pack(">Q", counter)
    digest_bytes = hmac.new(secret, message, digest).digest()
    offset = digest_bytes[-1] & 0x0F
    truncated = struct.unpack(">I", digest_bytes[offset:offset + 4])[0] & 0x7FFFFFFF
    return str(truncated % (10 ** digits)).zfill(digits)


def decode_base32(value: str) -> bytes:
    normalized = value.strip().replace(" ", "").replace("-", "").upper()
    padding = "=" * ((8 - len(normalized) % 8) % 8)
    return base64.b32decode(normalized + padding)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("secret")
    parser.add_argument("--digits", type=int, default=6)
    parser.add_argument("--period", type=int, default=30)
    parser.add_argument("--time", type=float, default=None, help="unix timestamp, defaults to now")
    args = parser.parse_args()

    timestamp = args.time if args.time is not None else time.time()
    counter = int(timestamp // args.period)
    code = hotp(decode_base32(args.secret), counter, args.digits)
    grouped = code[: len(code) // 2] + " " + code[len(code) // 2:]
    print(f"time={int(timestamp)} counter={counter} code={grouped} remaining={args.period - int(timestamp % args.period)}s")


if __name__ == "__main__":
    main()
