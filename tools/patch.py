"""P-47II MD タイトル画面差し替えパッチを作る.

  python3 tools/patch.py [元ROM]

1. tools/build_title.py でアセットを生成
2. src/title.s をアセンブルし ROM 空き領域 (0x085000-) に配置
3. 元のコードに jsr/jmp などのフックを書き込む (書き換え前のバイト列を確認)
4. build/P-47_II_MD_title.md (パッチ済み ROM) と patch/P-47_II_MD_title.ips を出力
"""
import os
import struct
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
BUILD = os.path.join(ROOT, 'build')
DEFAULT_ROM = os.path.join(ROOT, 'rom', 'P-47_II_MD_Japan_En.md')
OUT_ROM = os.path.join(BUILD, 'P-47_II_MD_title.md')
OUT_IPS = os.path.join(ROOT, 'patch', 'P-47_II_MD_title.ips')

BASE = 0x085000           # 追加コード・データの配置先 (元 ROM では 0xFF 埋め)
ROM_SIZE = 0x100000


def run(cmd, **kw):
    print('+', ' '.join(cmd))
    subprocess.run(cmd, check=True, **kw)


def assemble():
    run([sys.executable, os.path.join(ROOT, 'tools', 'build_title.py')])
    obj = os.path.join(BUILD, 'title.o')
    elf = os.path.join(BUILD, 'title.elf')
    binf = os.path.join(BUILD, 'title.bin')
    run(['m68k-linux-gnu-as', '-m68000', '--register-prefix-optional',
         '-I', BUILD, '-o', obj, os.path.join(ROOT, 'src', 'title.s')])
    run(['m68k-linux-gnu-ld', '-Ttext=0x%x' % BASE, '-e', '0x%x' % BASE, '-o', elf, obj])
    run(['m68k-linux-gnu-objcopy', '-O', 'binary', '-j', '.text', elf, binf])
    syms = {}
    out = subprocess.run(['m68k-linux-gnu-nm', elf], check=True, capture_output=True, text=True).stdout
    for line in out.splitlines():
        p = line.split()
        if len(p) == 3:
            syms[p[2]] = int(p[0], 16)
    return open(binf, 'rb').read(), syms


def jsr(a):
    return struct.pack('>HI', 0x4EB9, a)


def jmp(a):
    return struct.pack('>HI', 0x4EF9, a)


def lea_a0(a):
    return struct.pack('>HI', 0x41F9, a)


def bra_s(frm, to):
    d = to - (frm + 2)
    assert -128 <= d <= 127 and d != 0
    return struct.pack('>Bb', 0x60, d)


def w(v):
    return struct.pack('>H', v)


def hooks(s):
    """(アドレス, 元のバイト列, 新しいバイト列) のリスト."""
    h = []
    # タイトル初期化: プレーン消去の後に新タイル・BG マップを転送
    h.append((0x0167c0, '4eb900020342', jsr(s['TitleInit'])))
    # ロゴのパレット (PAL1) を新ロゴに
    h.append((0x017096, '000000000008000600080' '00c000e020e06640e000444066608880aaa040e0eee',
              open(os.path.join(BUILD, 'logo_pal.bin'), 'rb').read()))
    # ロゴを 1 列ずつ出す処理
    h.append((0x016b3a, '3c3900ff5208', jmp(s['TitleReveal'])))
    # スキップ時のロゴ一括描画
    h.append((0x016c6a, '207900ff147043fa', jsr(s['TitleFullLogo']) + bra_s(0x016c70, 0x016c98)))
    # 文字列 (1 行目 + メニュー)
    h.append((0x07f800, '41fa000e4eb9000202324ef900016bf8' '0750',
              lea_a0(s['TitleMenuStrings']) + jsr(0x020232) + jmp(0x016bf8)))
    # コンティニュー表示
    h.append((0x016c10, '41fa01084eb90002023233fc', jsr(s['TitleCont']) + bra_s(0x016c16, 0x016c48) + b'\x4e\x71' * 2))
    # スキップ時: コピーライト描画 + BG フェードイン
    h.append((0x016d38, '41f900ffe04a43fa', jsr(s['TitleSkip']) + bra_s(0x016d3e, 0x016d70)))
    # 文字スライド
    h.append((0x016d56, '0679040000ff', jmp(s['TitleSlide'])))
    h.append((0x016d86, '303900ff52aa', jmp(s['TitleBands'])))
    # カーソル: 8x16 スプライト, 黒縁付き矢印 (メニューが 1 行下がった分と相殺して Y は据え置き)
    cur = 0x6000 | s['TITLE_CURSOR_TILE']
    h.append((0x016e10, '0000', w(0x0100)))
    h.append((0x016e18, '6329', w(cur)))
    # 隠しメニュー: 元の位置のままなのでカーソルは 8 ドット上に (8x16 化の分)
    h.append((0x016f5a, '0100', w(0x00f8)))
    h.append((0x016f6c, '0000', w(0x0100)))
    h.append((0x016f74, '6329', w(cur)))
    h.append((0x016ede, '41fa01324eb900020232', jsr(s['TitleDbg']) + b'\x4e\x71' * 2))
    return h


def make_ips(orig, new):
    out = bytearray(b'PATCH')
    i = 0
    n = len(new)
    while i < n:
        if orig[i] == new[i]:
            i += 1
            continue
        j = i
        while j < n and (new[j] != orig[j] or (j + 1 < n and new[j + 1] != orig[j + 1] and j - i < 0xfff0)):
            j += 1
            if j - i >= 0xffff:
                break
        chunk = new[i:j]
        assert i < 0x1000000 and i != 0x454f46  # 'EOF'
        out += struct.pack('>I', i)[1:] + struct.pack('>H', len(chunk)) + chunk
        i = j
    out += b'EOF'
    return bytes(out)


def main():
    rom_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_ROM
    orig = open(rom_path, 'rb').read()
    assert len(orig) == ROM_SIZE, 'ROM サイズが違います'
    assert orig[0x120:0x130] == b'The Freedom Star', 'ROM が違います'
    code, syms = assemble()
    print('追加コード+データ: 0x%06x-0x%06x (%d バイト)' % (BASE, BASE + len(code) - 1, len(code)))
    rom = bytearray(orig)
    assert all(b == 0xff for b in rom[BASE:BASE + len(code)]), '配置先が空いていません'
    rom[BASE:BASE + len(code)] = code
    for addr, before, after in hooks(syms):
        before = bytes.fromhex(before)
        assert rom[addr:addr + len(before)] == before, 'フック位置のバイト列が違います: %06x' % addr
        rom[addr:addr + len(after)] = after
        print('  hook %06x: %s' % (addr, after.hex()))
    os.makedirs(os.path.dirname(OUT_IPS), exist_ok=True)
    open(OUT_ROM, 'wb').write(rom)
    ips = make_ips(orig, bytes(rom))
    open(OUT_IPS, 'wb').write(ips)
    # IPS を当て直して一致確認
    chk = bytearray(orig)
    p = 5
    while ips[p:p + 3] != b'EOF':
        off = int.from_bytes(ips[p:p + 3], 'big')
        ln = int.from_bytes(ips[p + 3:p + 5], 'big')
        chk[off:off + ln] = ips[p + 5:p + 5 + ln]
        p += 5 + ln
    assert chk == rom
    print('出力:', OUT_ROM)
    print('出力:', OUT_IPS, '(%d バイト)' % len(ips))


if __name__ == '__main__':
    main()
