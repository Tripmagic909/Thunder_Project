"""P-47II MD タイトル画面差し替え用アセットを生成する.

入力: assets/title_bg.jpg (BG 元絵), assets/P47_logo_md.png (ロゴ, MD 用ドット絵. 無ければ P47_logo.png から生成),
      assets/font_title.txt (フォント)
出力: build/title_data.s (アセンブラ用データ), build/preview_*.png (確認用)

VRAM / パレット割り当て (タイトル画面のみ):
  PAL0, PAL2 : BG (8x8 タイル毎にどちらかを選択). 初期は黒, 文字スライド開始時にフェードイン
  PAL1       : 新ロゴ (旧ロゴのパレットを置き換え)
  PAL3       : 文字 / スプライト (既存のまま. 文字は 15=白, 1=黒 を使用)
  Plane A    : ロゴ (行 5-12, 列 2-37), 文字 (列 40 以降に描いて H スクロールでスライド)
  Plane B    : BG (行 0-27, 列 0-39)
"""
import os
import struct
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
ASSETS = os.path.join(ROOT, 'assets')
BUILD = os.path.join(ROOT, 'build')

# ---------------------------------------------------------------- 画面レイアウト
LOGO_W = 272              # ロゴ幅 (px)
LOGO_X, LOGO_Y = 24, 44   # ロゴ左上 (画面座標)
LOGO_COL0, LOGO_ROW0 = 2, 5
LOGO_COLS, LOGO_ROWS = 36, 8
BG_BRIGHT = 0.8           # BG の明るさ

LINE1 = ('P·47II THE FREEDOM STAR', 64, 112)
MENU = [('START', 136, 136), ('OPTION', 136, 144)]
COPYRIGHT = ('©2025 CITY CONNECTION CO\x01LTD.', 40, 176)   # \x01 = '.,' を 1 タイルにまとめた字形
CONTINUE = ('CONTINUE', 128, 152)
DIGIT_POS = (200, 152)
SCROLL_COLS = 32          # 文字の最終 H スクロール値 0x100 (= 32 列)

# VRAM の空き領域 (タイル番号の範囲, 両端含む). タイトル画面の間だけ使う.
FREE_TILES = [
    (0x0100, 0x02ff),   # 0x2000-0x5FFF
    (0x0390, 0x03ff),   # 0x7200-0x7FFF (フォントの後ろ)
    (0x0400, 0x057f),   # 0x8000-0xAFFF (旧ロゴ含む)
    (0x0580, 0x059f),   # 0xB000-0xB3FF (ウインドウ面, 未使用)
    (0x05d4, 0x05ff),   # 0xBA80-0xBFFF (スプライト表の後ろ)
    (0x0670, 0x06ff),   # 0xCE00-0xDFFF (Plane A の 28 行目以降)
    (0x0770, 0x07ff),   # 0xEE00-0xFFFF (Plane B の 28 行目以降)
]


# ---------------------------------------------------------------- 共通
def snap(c):
    """RGB(0..255) -> MD 9bit の段階値 (0..7)."""
    return np.clip(np.rint(np.asarray(c, float) / 34), 0, 7).astype(int)


def cram_word(c):
    r, g, b = (int(v) for v in c)
    return (b << 9) | (g << 5) | (r << 1)


def kmeans_pal(px, k, iters=12, seed=0):
    rng = np.random.default_rng(seed)
    c = [px[rng.integers(len(px))]]
    for _ in range(k - 1):
        d = np.min(((px[:, None] - np.array(c)[None]) ** 2).sum(2), 1)
        c.append(px[rng.choice(len(px), p=d / d.sum())])
    c = np.array(c, float)
    for _ in range(iters):
        lab = np.argmin(((px[:, None] - c[None]) ** 2).sum(2), 1)
        for j in range(k):
            m = lab == j
            if m.any():
                c[j] = px[m].mean(0)
    return np.unique(snap(c), axis=0)


def tile_bytes(t):
    """8x8 のカラーインデックス -> 4bpp 32 バイト."""
    t = np.asarray(t, np.uint8)
    return bytes(((t[:, 0::2] << 4) | t[:, 1::2]).reshape(-1))


# ---------------------------------------------------------------- BG
def dither_tiles(img, pals, tile_pal, strength=0.6):
    h, w, _ = img.shape
    work = img.astype(float).copy()
    out = np.zeros((h, w), int)          # パレット内インデックス
    prgb = [p * 34.0 for p in pals]
    for y in range(h):
        for x in range(w):
            j = tile_pal[y // 8, x // 8]
            pr = prgb[j]
            v = work[y, x]
            i = int(np.argmin(((pr - v) ** 2).sum(1)))
            out[y, x] = i
            e = (v - pr[i]) * strength
            if x + 1 < w:
                work[y, x + 1] += e * 7 / 16
            if y + 1 < h:
                if x > 0:
                    work[y + 1, x - 1] += e * 3 / 16
                work[y + 1, x] += e * 5 / 16
                if x + 1 < w:
                    work[y + 1, x + 1] += e * 1 / 16
    return out


def make_bg():
    src = Image.open(os.path.join(ASSETS, 'title_bg.jpg')).convert('RGB')
    h = round(src.height * 320 / src.width)
    bg = src.resize((320, h), Image.LANCZOS).crop((0, 0, 320, 224))
    a = np.array(bg).astype(float)
    a = np.clip((a - 128) * 1.08 + 128, 0, 255) * BG_BRIGHT
    tiles = a.reshape(28, 8, 40, 8, 3).transpose(0, 2, 1, 3, 4).reshape(28, 40, 64, 3)
    m = tiles.mean(2)
    tile_pal = (m[..., 0] - m[..., 2] > 10).astype(int)
    for _ in range(4):
        pals = []
        for j in range(2):
            sel = tiles[tile_pal == j].reshape(-1, 3)
            if len(sel) == 0:
                sel = tiles.reshape(-1, 3)
            sub = sel[np.random.default_rng(j).choice(len(sel), min(len(sel), 6000), replace=False)]
            p = kmeans_pal(sub, 15, seed=j)
            p = p[(p != 0).any(1)]                      # 黒は index 0 (バックドロップ) に任せる
            pals.append(np.vstack([[[0, 0, 0]], p]))    # index 0 = 透明 (背景色 黒)
        err = []
        for p in pals:
            pr = p * 34.0
            d = ((tiles[..., None, :] - pr[None, None, None]) ** 2).sum(-1).min(-1).sum(-1)
            err.append(d)
        tile_pal = np.argmin(np.array(err), 0)
    idx = dither_tiles(a, pals, tile_pal)
    assert all(len(p) <= 16 for p in pals)
    return idx, pals, tile_pal


# ---------------------------------------------------------------- ロゴ
def make_logo():
    """ロゴ -> 画面座標のインデックス, 不透明マスク, パレット.

    assets/P47_logo_md.png (MD 用に手直ししたドット絵) があればそのまま使う.
    無ければ assets/P47_logo.png を縮小・減色し 1px の白縁を付ける.
    """
    md = os.path.join(ASSETS, 'P47_logo_md.png')
    if os.path.exists(md):
        a = np.array(Image.open(md).convert('RGBA')).astype(int)
        assert a.shape[:2] == (56, LOGO_W), a.shape
        alpha = a[..., 3] >= 128
        rgb = a[..., :3]
        assert not (rgb[alpha] % 34).any(), 'MD の色 (0,34,68,...,238) 以外が含まれています'
        layer = np.full((224, 320, 3), -1, int)
        ys, xs = np.nonzero(alpha)
        layer[LOGO_Y + ys, LOGO_X + xs] = rgb[ys, xs] // 34
        return logo_indexed(layer)
    src = Image.open(os.path.join(ASSETS, 'P47_logo.png')).convert('RGBA')
    h = round(src.height * LOGO_W / src.width)
    lg = src.resize((LOGO_W, h), Image.LANCZOS)
    a = np.array(lg).astype(float)
    alpha = a[..., 3] >= 110
    rgb = a[..., :3]
    pal = kmeans_pal(rgb[alpha], 13, seed=3)
    pr = pal * 34.0
    q = pal[np.argmin(((rgb[..., None, :] - pr[None, None]) ** 2).sum(-1), -1)]
    m = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))
    ring = (np.array(m) > 0) & ~alpha
    # 画面座標のレイヤ (色の段階値, -1 = 透明)
    layer = np.full((224, 320, 3), -1, int)
    ys, xs = np.nonzero(ring)
    layer[LOGO_Y + ys, LOGO_X + xs] = (7, 7, 7)
    ys, xs = np.nonzero(alpha)
    layer[LOGO_Y + ys, LOGO_X + xs] = q[ys, xs]
    return logo_indexed(layer)


def logo_indexed(layer):
    """色の段階値レイヤ (-1 = 透明) -> インデックス, 不透明マスク, パレット (PAL1)."""
    opaque = (layer >= 0).all(2)
    cols = sorted({tuple(c) for c in layer[opaque]})
    assert len(cols) <= 15, len(cols)
    palette = [(0, 0, 0)] + cols
    lut = {c: i + 1 for i, c in enumerate(cols)}
    idx = np.zeros((224, 320), int)
    for y, x in zip(*np.nonzero(opaque)):
        idx[y, x] = lut[tuple(layer[y, x])]
    return idx, opaque, palette


# ---------------------------------------------------------------- 文字
def load_font():
    g = {}
    lines = [l.rstrip('\n') for l in open(os.path.join(ASSETS, 'font_title.txt'), encoding='utf-8')
             if not l.startswith('# ')]
    for i in range(0, len(lines), 9):
        code, ch = lines[i].split(' ', 1)
        g[ch] = np.array([[c == '#' for c in r] for r in lines[i + 1:i + 9]])
    g[' '] = np.zeros((8, 8), bool)
    # '.,' をまとめた字形と末尾の '.' (確認済みイメージと同じ形)
    def rows(*r):
        return np.array([[c == '#' for c in x] for x in r])
    comb = rows('........', '........', '........', '........', '........',
                '##.##...', '##.##...', '...#....')
    g['.'] = rows('........', '........', '........', '........', '........',
                  '.##.....', '.##.....', '........')
    g['\x01'] = comb
    return g


def render_text(font, items):
    """文字列 [(str, x, y)] -> 画面座標のマスク (白)."""
    m = np.zeros((224, 320), bool)
    for s, x, y in items:
        for i, ch in enumerate(s):
            m[y:y + 8, x + i * 8:x + i * 8 + 8] |= font[ch]
    return m


def outline(m):
    o = np.zeros_like(m)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            o |= np.roll(np.roll(m, dy, 0), dx, 1)
    return o & ~m


def text_layer(font, items):
    w = render_text(font, items)
    idx = np.zeros((224, 320), int)
    idx[outline(w)] = 1       # PAL3 の 1 = 黒
    idx[w] = 15               # PAL3 の 15 = 白
    return idx


# ---------------------------------------------------------------- タイル管理
class TileAlloc:
    def __init__(self):
        self.free = [t for a, b in FREE_TILES for t in range(a, b + 1)]
        self.data = {}            # タイル番号 -> 32 バイト
        self.lookup = {}          # (bytes) -> タイル番号

    def get(self, pix, flips=True):
        """8x8 インデックス -> (タイル番号, hflip, vflip). 空タイルは 0."""
        pix = np.asarray(pix)
        if not pix.any():
            return 0, False, False
        variants = [(pix, False, False)]
        if flips:
            variants += [(pix[:, ::-1], True, False), (pix[::-1], False, True), (pix[::-1, ::-1], True, True)]
        for p, hf, vf in variants:
            n = self.lookup.get(tile_bytes(p))
            if n is not None:
                return n, hf, vf
        n = self.free.pop(0)
        b = tile_bytes(pix)
        self.data[n] = b
        self.lookup[b] = n
        return n, False, False


def entry(n, pal, hf=False, vf=False, pri=False):
    if n == 0:
        return 0
    return (0x8000 if pri else 0) | (pal << 13) | (0x1000 if vf else 0) | (0x800 if hf else 0) | n


def plane_strings(layer, alloc, rows, pal=3):
    """文字レイヤ (画面座標) -> 文字列描画リスト [(plane_offset, [words])].

    文字は Plane A の列 (画面列 + 32) に描き, 最終 H スクロール 0x100 で所定位置に来る.
    Plane は 64 列で折り返すので, 折り返しを跨ぐ部分は別エントリにする.
    """
    out = []
    for r in rows:
        cells = {}
        for sc in range(40):
            t = layer[r * 8:r * 8 + 8, sc * 8:sc * 8 + 8]
            if t.any():
                n, hf, vf = alloc.get(t, flips=False)
                cells[(sc + SCROLL_COLS) % 64] = entry(n, pal)
        if not cells:
            continue
        cols = sorted(cells)
        run = [cols[0]]
        for c in cols[1:]:
            if c == run[-1] + 1:
                run.append(c)
            else:
                out.append((r, run[0], [cells.get(x, 0) for x in range(run[0], run[-1] + 1)]))
                run = [c]
        out.append((r, run[0], [cells.get(x, 0) for x in range(run[0], run[-1] + 1)]))
    return [((r * 64 + c) * 2, words) for r, c, words in out]


def strings_asm(label, strings):
    s = [f'{label}:']
    for off, words in strings:
        assert all(w < 0x8000 for w in words)
        s.append('    dc.w 0x%04x' % off)
        for i in range(0, len(words), 12):
            s.append('    dc.w ' + ','.join('0x%04x' % w for w in words[i:i + 12]))
        s.append('    dc.w 0xffff')
    s.append('    dc.w 0xffff')
    return s


def diff_strings(base, variant, alloc, rows, cols):
    """variant と base で異なるタイルだけでなく, 指定範囲を丸ごと描くリスト."""
    lay = variant
    out = []
    for r in rows:
        words = []
        for sc in cols:
            t = lay[r * 8:r * 8 + 8, sc * 8:sc * 8 + 8]
            n, _, _ = alloc.get(t, flips=False)
            words.append(entry(n, 3))
        out.append((((r * 64) + (cols[0] + SCROLL_COLS) % 64) * 2, words))
    return out


# ---------------------------------------------------------------- メイン
def main():
    os.makedirs(BUILD, exist_ok=True)
    alloc = TileAlloc()
    asm = ['| 自動生成: tools/build_title.py', '    .section .text', '    .even']

    # --- ロゴ
    lidx, lopaque, lpal = make_logo()
    logo_map = []
    for r in range(LOGO_ROW0, LOGO_ROW0 + LOGO_ROWS):
        for c in range(LOGO_COL0, LOGO_COL0 + LOGO_COLS):
            t = lidx[r * 8:r * 8 + 8, c * 8:c * 8 + 8]
            n, hf, vf = alloc.get(t)
            logo_map.append(entry(n, 1, hf, vf, pri=True))
    assert not lidx[:, :LOGO_COL0 * 8].any() and not lidx[:, (LOGO_COL0 + LOGO_COLS) * 8:].any()
    assert not lidx[:LOGO_ROW0 * 8].any() and not lidx[(LOGO_ROW0 + LOGO_ROWS) * 8:].any()
    n_logo = len(alloc.data)

    # --- 文字
    font = load_font()
    base_items = [LINE1] + MENU
    lay_menu = text_layer(font, base_items)
    menu_strings = plane_strings(lay_menu, alloc, range(12, 21))
    lay_copy = text_layer(font, [COPYRIGHT])
    copy_strings = plane_strings(lay_copy, alloc, range(20, 25))
    # コンティニュー表示: START/OPTION/CONTINUE と残り回数 (0-9)
    cont_cols = list(range(15, 24))       # 画面列 15-23 (CONTINUE と左の縁)
    digit_cols = list(range(24, 27))      # 画面列 24-26 (数字と縁)
    lay_cont = text_layer(font, base_items + [CONTINUE])
    cont_strings = diff_strings(lay_menu, lay_cont, alloc, [18, 19], cont_cols)
    digit_strings = []
    for dgt in range(10):
        lay_d = text_layer(font, base_items + [CONTINUE, (str(dgt),) + DIGIT_POS])
        digit_strings.append(diff_strings(lay_menu, lay_d, alloc, [18, 19], digit_cols))
    # 隠しメニュー用: 行 16-19 を消す
    dbg_clear = [(((r * 64) + 40) * 2, [0] * 24) for r in range(16, 20)]
    n_text = len(alloc.data) - n_logo

    # --- カーソル (8x16 スプライト, 下のタイルの 0-6 行目に矢印)
    arrow = np.zeros((16, 8), bool)
    arrow[8:16] = font['>']
    aidx = np.zeros((16, 8), int)
    aidx[outline(np.pad(arrow, 1))[1:-1, 1:-1]] = 1
    aidx[arrow] = 15
    cur = [alloc.free.pop(0), None]
    assert alloc.free[0] == cur[0] + 1
    cur[1] = alloc.free.pop(0)
    alloc.data[cur[0]] = tile_bytes(aidx[:8])
    alloc.data[cur[1]] = tile_bytes(aidx[8:])

    # --- BG (ロゴで完全に隠れるタイルは省く)
    bidx, bpals, btp = make_bg()
    bg_map = []
    for r in range(28):
        for c in range(40):
            if lopaque[r * 8:r * 8 + 8, c * 8:c * 8 + 8].all():
                bg_map.append(0)
                continue
            t = bidx[r * 8:r * 8 + 8, c * 8:c * 8 + 8]
            n, hf, vf = alloc.get(t)
            bg_map.append(entry(n, 0 if btp[r, c] == 0 else 2, hf, vf))
    n_bg = len(alloc.data) - n_logo - n_text - 2
    print(f'tiles: logo {n_logo}, text {n_text}, cursor 2, bg {n_bg}, total {len(alloc.data)}, free left {len(alloc.free)}')

    # --- パレット
    def pal16(cols):
        w = [cram_word(c) for c in cols]
        return w + [0] * (16 - len(w))
    logo_pal = pal16(lpal)
    bg_pal0 = pal16(bpals[0])
    bg_pal2 = pal16(bpals[1])

    # --- VRAM 転送表 (連続タイルをまとめる)
    runs = []
    for n in sorted(alloc.data):
        if runs and runs[-1][1] == n - 1:
            runs[-1][1] = n
        else:
            runs.append([n, n])
    blob = bytearray()
    load = []
    for a, b in runs:
        load.append((a * 32, len(blob), (b - a + 1) * 8))
        for n in range(a, b + 1):
            blob += alloc.data[n]
    open(os.path.join(BUILD, 'title_tiles.bin'), 'wb').write(blob)
    bgmap_bin = b''.join(struct.pack('>H', w) for w in bg_map)
    open(os.path.join(BUILD, 'title_bgmap.bin'), 'wb').write(bgmap_bin)

    def vdp_cmd(addr):
        return 0x40000000 | ((addr & 0x3fff) << 16) | (addr >> 14)

    asm.append('| VRAM 転送表: cmd.l, src.l, (long 数 - 1).w. cmd=0 で終了')
    asm.append('TitleLoadTable:')
    for addr, off, nlong in load:
        asm.append('    dc.l 0x%08x, TitleTiles+%d' % (vdp_cmd(addr), off))
        asm.append('    dc.w %d' % (nlong - 1))
    for r in range(28):
        asm.append('    dc.l 0x%08x, TitleBgMap+%d' % (vdp_cmd(0xE000 + r * 128), r * 80))
        asm.append('    dc.w 19')
    asm.append('    dc.l 0')
    asm.append('')
    asm.append('| 新パレット (フェード目標). PAL0/PAL2 = BG, PAL1 = ロゴ, PAL3 = 既存')
    asm.append('TitleNewPal:')
    orig_pal3 = [0x0e60, 0x0000, 0x0ea4, 0x0a40, 0x0620, 0x0606, 0x02e6, 0x0080,
                 0x044e, 0x0006, 0x000e, 0x006e, 0x02ce, 0x0644, 0x0a88, 0x0eee]
    for p in (bg_pal0, logo_pal, bg_pal2, orig_pal3):
        asm.append('    dc.w ' + ','.join('0x%04x' % w for w in p))
    asm.append('TitleLogoPal:')
    asm.append('    dc.w ' + ','.join('0x%04x' % w for w in logo_pal))
    asm.append('')
    asm.append('| ロゴのマップ (36 x 8, 行優先)')
    asm.append('TitleLogoMap:')
    for i in range(0, len(logo_map), 12):
        asm.append('    dc.w ' + ','.join('0x%04x' % w for w in logo_map[i:i + 12]))
    asm.append('')
    asm += strings_asm('TitleMenuStrings', menu_strings)
    asm += strings_asm('TitleCopyStrings', copy_strings)
    asm += strings_asm('TitleContStrings', cont_strings)
    for dgt in range(10):
        asm += strings_asm(f'TitleDigit{dgt}', digit_strings[dgt])
    asm.append('TitleDigitTable:')
    asm.append('    dc.l ' + ','.join(f'TitleDigit{d}' for d in range(10)))
    asm += strings_asm('TitleDbgClear', dbg_clear)
    asm.append('')
    asm.append('    .equ TITLE_CURSOR_TILE, 0x%04x' % cur[0])
    asm.append('    .even')
    asm.append('TitleBgMap:')
    asm.append('    .incbin "title_bgmap.bin"')
    asm.append('TitleTiles:')
    asm.append('    .incbin "title_tiles.bin"')
    open(os.path.join(BUILD, 'title_data.s'), 'w', encoding='utf-8').write('\n'.join(asm) + '\n')
    open(os.path.join(BUILD, 'logo_pal.bin'), 'wb').write(b''.join(struct.pack('>H', w) for w in logo_pal))

    # --- 確認用プレビュー (最終画面を合成)
    prev = np.zeros((224, 320, 3), np.uint8)
    for r in range(28):
        for c in range(40):
            j = btp[r, c]
            t = bidx[r * 8:r * 8 + 8, c * 8:c * 8 + 8]
            prev[r * 8:r * 8 + 8, c * 8:c * 8 + 8] = (bpals[j][t] * 34).astype(np.uint8)
    lp = np.array(lpal) * 34
    prev[lopaque] = lp[lidx[lopaque]]
    tl = text_layer(font, base_items + [COPYRIGHT])
    prev[tl == 1] = 0
    prev[tl == 15] = 238
    Image.fromarray(prev).resize((640, 448), Image.NEAREST).save(os.path.join(BUILD, 'preview_final.png'))


if __name__ == '__main__':
    main()
