"""68000 逆アセンブル (capstone): m68dis.py <開始アドレス16進> <命令数> [ROM]"""
import sys, capstone
rom = open(sys.argv[3] if len(sys.argv) > 3 else 'rom/P-47_II_MD_Japan_En.md', 'rb').read()
md = capstone.Cs(capstone.CS_ARCH_M68K, capstone.CS_MODE_BIG_ENDIAN | capstone.CS_MODE_M68K_000)
md.skipdata = True
a = int(sys.argv[1], 16); n = int(sys.argv[2])
for i in md.disasm(rom[a:a + n * 10], a):
    print('%06x: %-24s %s %s' % (i.address, i.bytes.hex(), i.mnemonic, i.op_str))
    n -= 1
    if n <= 0: break
