"""Trimma Pipoya RPG Monster Pack till repo-storlek.
Usage: python trim_pipoya.py <unzipped 'Pipoya RPG Monster Pack' dir> <out dir> [--variant shade|non shade] [--recolors]
"""
import sys, glob, os, argparse
from PIL import Image
ap=argparse.ArgumentParser(); ap.add_argument('src'); ap.add_argument('out')
ap.add_argument('--variant',default='shade'); ap.add_argument('--recolors',action='store_true')
a=ap.parse_args()
pat='pipo-*.png' if a.recolors else 'pipo-*[0-9].png'
os.makedirs(f'{a.out}/full-480',exist_ok=True); os.makedirs(f'{a.out}/small-256',exist_ok=True)
for f in sorted(glob.glob(os.path.join(a.src,a.variant,pat))):
    im=Image.open(f).convert('RGBA'); n=os.path.basename(f)
    im.save(f'{a.out}/full-480/{n}',optimize=True,compress_level=9)
    small=im.resize((640,300) if 'boss' in n else (256,256),Image.LANCZOS)
    small.quantize(256,method=Image.Quantize.FASTOCTREE,dither=Image.Dither.NONE).save(f'{a.out}/small-256/{n}',optimize=True)
print('done')
