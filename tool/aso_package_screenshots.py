#!/usr/bin/env python3
"""Make App Store RGB PNG bundles from the screenshot editor's RGBA exports.

Requires ffmpeg on PATH. No visual edits: only the alpha channel is removed.
"""
import argparse
import json
from pathlib import Path, PurePosixPath
import struct
import subprocess
import zipfile


def package(inputs, output):
    output.mkdir(parents=True, exist_ok=True)
    manifest = []
    seen = set()
    for source in inputs:
        with zipfile.ZipFile(source) as archive:
            images = [item for item in archive.infolist() if item.filename.endswith('.png')]
            if not images:
                raise ValueError(f'No PNGs in {source}')
            destination = output / source.name
            if destination.resolve() == source.resolve():
                raise ValueError('Output must not overwrite an input ZIP')
            with zipfile.ZipFile(destination, 'w', compression=zipfile.ZIP_DEFLATED) as bundle:
                for item in images:
                    relative = PurePosixPath(item.filename)
                    if relative.is_absolute() or '..' in relative.parts or item.filename in seen:
                        raise ValueError(f'Unsafe or duplicate image path: {item.filename}')
                    seen.add(item.filename)
                    converted = subprocess.run(
                        ['ffmpeg', '-v', 'error', '-i', 'pipe:0', '-frames:v', '1',
                         '-pix_fmt', 'rgb24', '-f', 'image2pipe', '-c:v', 'png', 'pipe:1'],
                        input=archive.read(item), capture_output=True, check=True, timeout=30,
                    ).stdout
                    if converted[:8] != b'\x89PNG\r\n\x1a\n' or converted[25] != 2:
                        raise ValueError(f'Not an RGB PNG: {item.filename}')
                    size = struct.unpack('>II', converted[16:24])
                    target = output.joinpath(*relative.parts)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(converted)
                    bundle.writestr(item.filename, converted)
                    manifest.append({'path': item.filename, 'size': list(size), 'mode': 'RGB'})
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Packaged {len(manifest)} RGB PNGs in {output}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, action='append', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    package(args.input, args.output)


if __name__ == '__main__':
    main()
