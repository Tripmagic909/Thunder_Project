"""メガドライブ VDP の簡易レンダラ (解析・検証用).

MAME のダンプ (vram/cram/vsram/regs) から 320x224 の画面を再現する.
対応: Plane A/B, スプライト, 優先度, 水平スクロール(全体/セル/ライン), 垂直スクロール(全体).
ウインドウ・シャドウ/ハイライトは未対応.
"""
import struct
import numpy as np


class Dump:
    def __init__(self, prefix):
        self.vram = open(prefix + '.vram', 'rb').read()
        self.cram = struct.unpack('>64H', open(prefix + '.cram', 'rb').read())
        self.vsram = struct.unpack('>40H', open(prefix + '.vsram', 'rb').read()[:80])
        self.regs = struct.unpack('>32H', open(prefix + '.regs', 'rb').read())
        try:
            self.ram = open(prefix + '.ram', 'rb').read()
        except OSError:
            self.ram = None

    def w(self, a):
        return struct.unpack('>H', self.vram[a & 0xfffe:(a & 0xfffe) + 2])[0]

    @property
    def plane_a(self):
        return (self.regs[2] & 0x38) << 10

    @property
    def plane_b(self):
        return (self.regs[4] & 7) << 13

    @property
    def sat(self):
        return (self.regs[5] & 0x7f) << 9

    @property
    def hscroll(self):
        return (self.regs[13] & 0x3f) << 10

    @property
    def plane_size(self):
        s = {0: 32, 1: 64, 3: 128}
        return s[self.regs[16] & 3], s[(self.regs[16] >> 4) & 3]

    def tile(self, n):
        """タイル n -> 8x8 のカラーインデックス配列."""
        b = np.frombuffer(self.vram, np.uint8, 32, (n & 0x7ff) * 32)
        px = np.empty(64, np.uint8)
        px[0::2] = b >> 4
        px[1::2] = b & 15
        return px.reshape(8, 8)

    def palette_rgb(self):
        c = np.array(self.cram)
        r = (c >> 1) & 7
        g = (c >> 5) & 7
        b = (c >> 9) & 7
        return (np.stack([r, g, b], 1) * 34).astype(np.uint8)


def render_plane(d, base, hs_index):
    pw, ph = d.plane_size
    W, H = pw * 8, ph * 8
    idx = np.zeros((H, W), np.uint8)
    pri = np.zeros((H, W), bool)
    for r in range(ph):
        for c in range(pw):
            e = d.w(base + (r * pw + c) * 2)
            t = d.tile(e & 0x7ff)
            if e & 0x800:
                t = t[:, ::-1]
            if e & 0x1000:
                t = t[::-1]
            pal = (e >> 13) & 3
            v = np.where(t > 0, t + pal * 16, 0)
            idx[r * 8:r * 8 + 8, c * 8:c * 8 + 8] = v
            pri[r * 8:r * 8 + 8, c * 8:c * 8 + 8] = bool(e & 0x8000)
    # スクロール
    mode = d.regs[11] & 3
    vs = d.vsram[0 if hs_index == 0 else 1] & (H - 1)
    out_i = np.zeros((224, 320), np.uint8)
    out_p = np.zeros((224, 320), bool)
    for y in range(224):
        if mode == 0:
            ha = d.hscroll
        elif mode == 2:
            ha = d.hscroll + (y & ~7) * 4
        else:
            ha = d.hscroll + y * 4
        hsv = d.w(ha + hs_index * 2) & 0x3ff
        sy = (y + vs) % H
        xs = (np.arange(320) - hsv) % W
        out_i[y] = idx[sy, xs]
        out_p[y] = pri[sy, xs]
    return out_i, out_p


def sprites(d):
    """スプライトを低/高優先度の 2 レイヤで返す."""
    lo = np.zeros((224, 320), np.uint8)
    hi = np.zeros((224, 320), np.uint8)
    order = []
    link, n = 0, 0
    while True:
        a = d.sat + link * 8
        y, s, t, x = struct.unpack('>4H', d.vram[a:a + 8])
        order.append((y, s, t, x))
        link = s & 0x7f
        n += 1
        if link == 0 or n >= 80:
            break
    # 先頭が最前面なので逆順に描く
    for y, s, t, x in reversed(order):
        w = ((s >> 10) & 3) + 1
        h = ((s >> 8) & 3) + 1
        base = t & 0x7ff
        pal = (t >> 13) & 3
        hf, vf = t & 0x800, t & 0x1000
        px0, py0 = (x & 0x1ff) - 128, (y & 0x3ff) - 128
        layer = hi if t & 0x8000 else lo
        for cx in range(w):
            for cy in range(h):
                tx = (w - 1 - cx) if hf else cx
                ty = (h - 1 - cy) if vf else cy
                tl = d.tile(base + tx * h + ty)
                if hf:
                    tl = tl[:, ::-1]
                if vf:
                    tl = tl[::-1]
                for yy in range(8):
                    Y = py0 + cy * 8 + yy
                    if not 0 <= Y < 224:
                        continue
                    for xx in range(8):
                        X = px0 + cx * 8 + xx
                        if 0 <= X < 320 and tl[yy, xx]:
                            layer[Y, X] = tl[yy, xx] + pal * 16
    return lo, hi


def render(d):
    pal = d.palette_rgb()
    bg = d.regs[7] & 0x3f
    a, ap = render_plane(d, d.plane_a, 0)
    b, bp = render_plane(d, d.plane_b, 1)
    slo, shi = sprites(d)
    out = np.full((224, 320), bg, np.uint8)
    for layer, mask in [(b, ~bp), (a, ~ap), (slo, None), (b, bp), (a, ap), (shi, None)]:
        m = (layer & 15) > 0
        if mask is not None:
            m &= mask
        out[m] = layer[m]
    if not d.regs[1] & 0x40:
        return np.zeros((224, 320, 3), np.uint8)
    return pal[out]


if __name__ == '__main__':
    import sys
    from PIL import Image
    d = Dump(sys.argv[1])
    Image.fromarray(render(d)).save(sys.argv[2])
