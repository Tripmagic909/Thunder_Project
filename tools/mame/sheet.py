"""スナップショットを 1 枚に並べる: sheet.py <snapdir> <out.png> [ラベル...]"""
import sys, glob
from PIL import Image, ImageDraw
fs = sorted(glob.glob(sys.argv[1] + '/**/*.png', recursive=True))
labels = sys.argv[3:]
cols = 4
W = Image.new('RGB', (320 * cols, 234 * ((len(fs) + cols - 1) // cols)))
d = ImageDraw.Draw(W)
for k, f in enumerate(fs):
    im = Image.open(f).convert('RGB').resize((320, 224))
    x, y = (k % cols) * 320, (k // cols) * 234
    W.paste(im, (x, y + 10))
    d.text((x + 2, y), labels[k] if k < len(labels) else str(k), fill=(255, 255, 0))
W.save(sys.argv[2])
