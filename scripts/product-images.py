#!/usr/bin/env python3
"""Export approved synthetic previews, retaining only PNG image data."""
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parent.parent


def clean_png(source, destination):
    data = source.read_bytes()
    signature = b"\x89PNG\r\n\x1a\n"
    if not data.startswith(signature):
        raise ValueError(f"Not a PNG: {source.name}")
    output = bytearray(signature)
    offset = len(signature)
    finished = False
    while offset < len(data):
        length = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4:offset + 8]
        end = offset + 12 + length
        payload = data[offset + 8:offset + 8 + length]
        crc = struct.unpack_from(">I", data, offset + 8 + length)[0]
        if end > len(data) or zlib.crc32(kind + payload) & 0xFFFFFFFF != crc:
            raise ValueError(f"Invalid PNG chunk: {source.name}")
        if kind in {b"IHDR", b"PLTE", b"IDAT", b"IEND", b"tRNS"}:
            output.extend(data[offset:end])
        offset = end
        if kind == b"IEND":
            finished = True
            break
    if not finished or offset != len(data):
        raise ValueError(f"Incomplete PNG or trailing data: {source.name}")
    destination.write_bytes(output)
    print(f"Exported {destination.name}")


if __name__ == "__main__":
    target = ROOT / "docs/images"
    target.mkdir(parents=True, exist_ok=True)
    preview = ROOT / ".build/previews"
    images = {
        "app-Playground-en-1020.png": "playground-en.png",
        "app-Playground-zh-Hans-1020.png": "playground-zh-CN.png",
        "cat-en.png": "cat-en.png",
        "cat-zh-Hans.png": "cat-zh-CN.png",
        "girl-en.png": "girl-en.png",
        "banner-en.png": "banner-en.png",
        "fbi-en.png": "fbi-en.png",
    }
    for source, destination in images.items():
        clean_png(preview / source, target / destination)
    clean_png(ROOT / ".build/AppIcon.iconset/icon_512x512@2x.png", target / "logo.png")
