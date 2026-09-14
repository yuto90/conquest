#!/usr/bin/env python3
"""Reproduce the 36 island PNGs and review sheets from user-supplied originals."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage, signal

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
FACTIONS = ('ally', 'enemy', 'neutral')
XB = (0, 360, 750, 1105, 1448)
YB = (0, 400, 730, 1086)
HASHES = {
    'ally': 'd9368f60b6a29ca850e40ba63f250b7d88b7e04968abadc24b44cce5bb95438f',
    'enemy': '80f7f492c36611cef1a6f666b3497ed932d37a4dce61ce4b1ca2803ad0adde42',
    'neutral': 'e0c5363f8ceca3935338630aac8137bbd41efb297873b6e3cc1fadb5cc7b08ab',
}


def remove_background(image):
    rgb = np.asarray(image.convert('RGB')).astype(np.float64)
    r, g, b = rgb.transpose(2, 0, 1)
    # Only the high-chroma green connected to the crop perimeter is keyed out.
    candidate = (g > 150) & (g - r > 30) & (g - b > 50)
    seeds = np.zeros(candidate.shape, dtype=bool)
    seeds[0] = candidate[0]
    seeds[-1] = candidate[-1]
    seeds[:, 0] = candidate[:, 0]
    seeds[:, -1] = candidate[:, -1]
    background = ndimage.binary_propagation(seeds, mask=candidate)
    foreground = ~background
    assert not (foreground[0].any() or foreground[-1].any()
                or foreground[:, 0].any() or foreground[:, -1].any()), 'Crop cuts an island'
    inside_distance = ndimage.distance_transform_edt(foreground)
    outside_distance = ndimage.distance_transform_edt(background)
    core = inside_distance > 3
    # Estimate the unpolluted shore from its nearest interior pixel. Unmix only
    # a 3px edge band; forest/interior RGB values remain byte-for-byte intact.
    _, nearest = ndimage.distance_transform_edt(~core, return_indices=True)
    shore = rgb[tuple(nearest)]
    key = np.median(rgb[background & (outside_distance > 6)], axis=0)
    direction = shore - key
    alpha = np.clip(np.sum((rgb - key) * direction, axis=2)
                    / np.maximum(np.sum(direction * direction, axis=2), 1), 0, 1)
    band = (inside_distance <= 3) & (outside_distance <= 3)
    alpha = np.where(band, alpha, foreground.astype(float))
    alpha[alpha < 2 / 255] = 0
    # Project the edge onto the estimated shore/key mixture. Extending the
    # nearest clean shore color avoids amplifying compression noise into a
    # magenta fringe when alpha is small. Alpha retains the original contour.
    output_rgb = np.where(band[..., None], shore, rgb)
    output_rgb[alpha == 0] = 0
    rgba = np.dstack((np.rint(output_rgb), np.rint(alpha * 255))).astype(np.uint8)
    return Image.fromarray(rgba), key.tolist()


def translation(reference, moving):
    a = np.asarray(reference)[..., 3] >= 128
    b = np.asarray(moving)[..., 3] >= 128
    correlation = signal.fftconvolve(a.astype(float), b[::-1, ::-1].astype(float), mode='full')
    cy, cx = np.array(b.shape) - 1
    # Only rigid integer translations, never individual resizing or deformation.
    options = [(round(correlation[cy + dy, cx + dx]), -(dx * dx + dy * dy), dx, dy)
               for dy in range(-8, 9) for dx in range(-8, 9)]
    overlap, _, dx, dy = max(options)
    iou = overlap / (a.sum() + b.sum() - overlap)
    assert abs(dx) < 8 and abs(dy) < 8, 'Alignment requires manual inspection'
    return (dx, dy), round(float(iou), 5)


def backdrop(size, kind):
    colors = {'sea': '#163b4c', 'white': '#ffffff', 'dark': '#111722', 'checker': '#dddddd'}
    canvas = Image.new('RGB', size, colors[kind])
    if kind == 'checker':
        draw = ImageDraw.Draw(canvas)
        for y in range(0, size[1], 12):
            for x in range(0, size[0], 12):
                if (x // 12 + y // 12) % 2:
                    draw.rectangle((x, y, x + 11, y + 11), fill='#aaaaaa')
    return canvas


def review_sheets(outputs):
    folder = HERE / 'review'
    folder.mkdir(exist_ok=True)
    for kind in ('sea', 'white', 'dark', 'checker'):
        sheet = backdrop((1440, 1050), kind)
        draw = ImageDraw.Draw(sheet)
        text_color = '#17212b' if kind in ('white', 'checker') else '#ffffff'
        for index in range(12):
            x, y = (index % 4) * 360, (index // 4) * 350
            draw.text((x + 12, y + 12), f'ISLAND {index + 1:02d}', fill=text_color)
            for column, faction in enumerate(FACTIONS):
                island = outputs[index][faction]
                large = island.resize((116, 116), Image.Resampling.LANCZOS)
                sheet.paste(large, (x + column * 120 + 2, y + 55), large)
                draw.text((x + column * 120 + 10, y + 180), faction.upper(), fill=text_color)
                small = island.resize((50, 50), Image.Resampling.LANCZOS)
                sheet.paste(small, (x + column * 120 + 35, y + 220), small)
            draw.text((x + 12, y + 300), 'Top: 116px  /  Bottom: 50px', fill=text_color)
        sheet.save(folder / f'contact-{kind}.png')
    # RGB silhouettes share the same canvas: white means all three overlap.
    overlay = backdrop((1440, 1080), 'dark')
    draw = ImageDraw.Draw(overlay)
    for index, variants in enumerate(outputs):
        alpha = np.stack([np.asarray(variants[f])[..., 3] for f in FACTIONS], axis=-1)
        sample = Image.fromarray(alpha).resize((300, 300), Image.Resampling.NEAREST)
        x, y = index % 4 * 360 + 30, index // 4 * 360 + 35
        overlay.paste(sample, (x, y))
        draw.text((x, y - 22), f'{index+1:02d}  R:ALLY G:ENEMY B:NEUTRAL', fill='white')
    overlay.save(folder / 'alignment-overlay.png')


def main():
    sources = {}
    for faction in FACTIONS:
        source = HERE / 'sources' / f'conquest_isles_{faction}.png'
        assert hashlib.sha256(source.read_bytes()).hexdigest() == HASHES[faction], source
        sources[faction] = Image.open(source).convert('RGB')
        assert sources[faction].size == (1448, 1086), 'Unexpected source resolution'
        (ROOT / 'assets' / 'islands' / faction).mkdir(parents=True, exist_ok=True)
    plan = {'source': 'User supplied on 2026-09-13 from Desktop/isles; supersedes Issue #63 hashes',
            'sha256': HASHES, 'source_size': [1448, 1086], 'x_boundaries': XB,
            'y_boundaries': YB, 'padding_min_px': 4, 'scale': 1, 'layouts': []}
    outputs = []
    for index in range(12):
        row, col = divmod(index, 4)
        box = (XB[col], YB[row], XB[col+1], YB[row+1])
        cropped, keys = {}, {}
        for faction in FACTIONS:
            cropped[faction], keys[faction] = remove_background(sources[faction].crop(box))
        shifts = {'ally': (0, 0)}
        scores = {'ally': 1.0}
        for faction in FACTIONS[1:]:
            shifts[faction], scores[faction] = translation(cropped['ally'], cropped[faction])
        bounds = []
        for faction in FACTIONS:
            l, t, r, b = cropped[faction].getbbox()
            dx, dy = shifts[faction]
            bounds.append((l+dx, t+dy, r+dx, b+dy))
        left, top = min(b[0] for b in bounds), min(b[1] for b in bounds)
        right, bottom = max(b[2] for b in bounds), max(b[3] for b in bounds)
        side = max(right-left, bottom-top) + 8
        origin = ((side-(right-left))//2-left, (side-(bottom-top))//2-top)
        variants = {}
        for faction in FACTIONS:
            canvas = Image.new('RGBA', (side, side))
            dx, dy = shifts[faction]
            canvas.paste(cropped[faction], (origin[0]+dx, origin[1]+dy))
            path = ROOT / 'assets' / 'islands' / faction / f'island_{index+1:02d}.png'
            canvas.save(path)
            with Image.open(path) as check:
                assert check.mode == 'RGBA' and check.size == (side, side)
                l, t, r, b = check.getbbox()
                assert min(l, t, side-r, side-b) >= 4
                assert np.any((np.asarray(check)[..., 3] > 0) & (np.asarray(check)[..., 3] < 255))
            variants[faction] = canvas
        outputs.append(variants)
        plan['layouts'].append({'id': index+1, 'crop_ltrb': box, 'canvas_size': side,
                                'common_origin_xy': origin, 'translation_xy': shifts,
                                'mask_iou_vs_ally': scores, 'sampled_background_rgb': keys})
    (HERE / 'crop_plan.json').write_text(json.dumps(plan, indent=2) + '\n')
    review_sheets(outputs)
    print(json.dumps({'files': len(outputs)*3, 'alignment': [
        {'id': p['id'], 'shift': p['translation_xy'], 'iou': p['mask_iou_vs_ally']}
        for p in plan['layouts']]}, indent=2))


if __name__ == '__main__':
    main()
