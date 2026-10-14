"""Make an IPS patch from an original ROM and a modified ROM (same size).

usage: python3 make_ips.py original.nes modified.nes output.ips
"""
import sys

def make_ips(a, b, gap=6):
    assert len(a) == len(b), 'ROMs must be the same size'
    assert len(b) < 0x454F46, 'offsets above "EOF" are not supported'
    runs, i, n = [], 0, len(a)
    while i < n:
        if a[i] == b[i]: i += 1; continue
        j = i + 1; last = i                       # extend the run over small unchanged gaps
        while j < n and j - last <= gap:
            if a[j] != b[j]: last = j
            j += 1
        runs.append((i, last + 1)); i = last + 1
    out = bytearray(b'PATCH')
    for s, e in runs:
        while s < e:
            m = min(e, s + 0xFFFF)
            out += s.to_bytes(3, 'big') + (m - s).to_bytes(2, 'big') + b[s:m]
            s = m
    return bytes(out + b'EOF')

def apply_ips(rom, ips):
    rom, p = bytearray(rom), 5
    assert ips[:5] == b'PATCH'
    while ips[p:p + 3] != b'EOF':
        o = int.from_bytes(ips[p:p + 3], 'big'); n = int.from_bytes(ips[p + 3:p + 5], 'big'); p += 5
        assert n, 'RLE records are not used by this tool'
        rom[o:o + n] = ips[p:p + n]; p += n
    return bytes(rom)

if __name__ == '__main__':
    a, b = open(sys.argv[1], 'rb').read(), open(sys.argv[2], 'rb').read()
    ips = make_ips(a, b)
    assert apply_ips(a, ips) == b
    open(sys.argv[3], 'wb').write(ips)
    print('wrote', sys.argv[3], len(ips), 'bytes')
