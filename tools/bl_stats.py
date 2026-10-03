"""BLACK LABEL 調整用: ダンプから敵弾数・プール満杯率・横ラインのスプライト数を集計する."""
import sys, struct, glob, collections
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from vdp import Dump
import numpy as np

def stats(pattern):
    fs = sorted(glob.glob(pattern + '*.ram'), key=lambda f: int(''.join(c for c in f.rsplit('/', 1)[1] if c.isdigit())))
    bul, full, line_max, vis = [], 0, [], []
    for f in fs:
        d = Dump(f[:-4])
        r = d.ram
        w = lambda a: struct.unpack('>H', r[a - 0xff0000:a - 0xff0000 + 2])[0]
        mask = struct.unpack('>I', r[0x78c6:0x78ca])[0]
        n = (w(0xff6014) if w(0xff6006) else w(0xff4c08)) + 1
        used = bin(mask & ((1 << n) - 1)).count('1')
        bul.append(used)
        full += used >= n
        link, k, cnt = 0, 0, collections.Counter()
        nv = 0
        while True:
            a = d.sat + link * 8
            y, s, t, x = struct.unpack('>4H', d.vram[a:a + 8])
            hgt = ((s >> 8) & 3) + 1
            if 0 < (x & 0x1ff) < 448:
                nv += 1
                for yy in range((y & 0x3ff) - 128, (y & 0x3ff) - 128 + hgt * 8):
                    if 0 <= yy < 224:
                        cnt[yy] += 1
            link = s & 0x7f
            k += 1
            if link == 0 or k >= 80:
                break
        line_max.append(max(cnt.values()) if cnt else 0)
        vis.append(nv)
    b = np.array(bul)
    return dict(samples=len(fs), bullets_mean=round(b.mean(), 1), bullets_max=int(b.max()),
                pool_full_pct=round(100 * full / len(fs), 1), sprites_max=max(vis),
                line_max=max(line_max), line_over20_pct=round(100 * sum(l > 20 for l in line_max) / len(fs), 1))

if __name__ == '__main__':
    for p in sys.argv[1:]:
        print(p, stats(p))
