"""只依赖标准库的 PNG 读写，供美术流程脚本使用。

读取支持 8 位灰度、RGB、灰度+透明、RGBA，以及 1/2/4/8 位索引色（含 tRNS）。
不支持 16 位和隔行 PNG，遇到时报错并说明原因。
"""
import struct
import zlib

PNG_SIG = b"\x89PNG\r\n\x1a\n"
MAX_SIDE = 2048  # 精灵图远小于这个尺寸；限制它是为了防止异常文件耗尽内存
CHANNELS = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}


class PngError(Exception):
    pass


def _chunks(data):
    pos = 8
    while pos + 8 <= len(data):
        length, ctype = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if len(body) != length:
            raise PngError("文件被截断")
        yield ctype, body
        if ctype == b"IEND":
            return
        pos += 12 + length


def _paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def _unfilter(raw, height, stride, bpp):
    out = bytearray()
    prev = bytearray(stride)
    pos = 0
    for _ in range(height):
        ftype = raw[pos]
        line = bytearray(raw[pos + 1:pos + 1 + stride])
        pos += 1 + stride
        for i in range(stride):
            left = line[i - bpp] if i >= bpp else 0
            up = prev[i]
            if ftype == 1:
                line[i] = (line[i] + left) & 255
            elif ftype == 2:
                line[i] = (line[i] + up) & 255
            elif ftype == 3:
                line[i] = (line[i] + ((left + up) >> 1)) & 255
            elif ftype == 4:
                upleft = prev[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + _paeth(left, up, upleft)) & 255
            elif ftype != 0:
                raise PngError(f"未知的行过滤类型 {ftype}")
        out += line
        prev = line
    return out


def read_rgba(path):
    """读取 PNG，返回 (宽, 高, 像素列表)。像素按行优先排列，每个是 (r, g, b, a)。"""
    with open(path, "rb") as f:
        data = f.read()
    if not data.startswith(PNG_SIG):
        raise PngError("不是 PNG 文件")
    ihdr = plte = trns = None
    idat = []
    for ctype, body in _chunks(data):
        if ctype == b"IHDR":
            ihdr = struct.unpack(">IIBBBBB", body)
        elif ctype == b"PLTE":
            plte = [tuple(body[i:i + 3]) for i in range(0, len(body) - 2, 3)]
        elif ctype == b"tRNS":
            trns = body
        elif ctype == b"IDAT":
            idat.append(body)
    if ihdr is None:
        raise PngError("缺少 IHDR")
    w, h, depth, ctype, _, _, interlace = ihdr
    if ctype not in CHANNELS:
        raise PngError(f"不支持的颜色类型 {ctype}")
    if interlace:
        raise PngError("不支持隔行 PNG，请重新导出为非隔行")
    if depth != 8 and not (ctype == 3 and depth in (1, 2, 4)):
        raise PngError(f"不支持 {depth} 位色深，请导出为 8 位 RGBA 或索引色")
    if not (0 < w <= MAX_SIDE and 0 < h <= MAX_SIDE):
        raise PngError(f"尺寸 {w}×{h} 超出范围（单边最大 {MAX_SIDE}）")
    if ctype == 3 and plte is None:
        raise PngError("索引色 PNG 缺少调色板")

    ch = CHANNELS[ctype]
    stride = (w * ch * depth + 7) // 8
    expected = h * (stride + 1)
    dec = zlib.decompressobj()
    raw = dec.decompress(b"".join(idat), expected + 1)
    if len(raw) != expected:
        raise PngError("图像数据长度不对，文件可能已损坏")
    rows = _unfilter(raw, h, stride, max(1, ch * depth // 8))

    pixels = []
    for y in range(h):
        line = rows[y * stride:(y + 1) * stride]
        if ctype == 3:
            per_byte = 8 // depth
            mask = (1 << depth) - 1
            for x in range(w):
                shift = 8 - depth * (x % per_byte + 1)
                idx = (line[x // per_byte] >> shift) & mask
                if idx >= len(plte):
                    raise PngError("像素引用了不存在的调色板索引")
                a = trns[idx] if trns is not None and idx < len(trns) else 255
                pixels.append(plte[idx] + (a,))
        else:
            for x in range(w):
                px = line[x * ch:(x + 1) * ch]
                if ctype == 0:
                    a = 0 if trns is not None and px[0] == trns[1] else 255
                    pixels.append((px[0], px[0], px[0], a))
                elif ctype == 2:
                    rgb = tuple(px)
                    a = 0 if trns is not None and rgb == (trns[1], trns[3], trns[5]) else 255
                    pixels.append(rgb + (a,))
                elif ctype == 4:
                    pixels.append((px[0], px[0], px[0], px[1]))
                else:
                    pixels.append(tuple(px))
    return w, h, pixels


def _chunk(ctype, body):
    crc = zlib.crc32(ctype + body) & 0xFFFFFFFF
    return struct.pack(">I", len(body)) + ctype + body + struct.pack(">I", crc)


def write_rgba(path, w, h, pixels):
    """把 (r, g, b, a) 像素列表写成 8 位 RGBA PNG。"""
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for px in pixels[y * w:(y + 1) * w]:
            raw += bytes(px)
    with open(path, "wb") as f:
        f.write(PNG_SIG
                + _chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                + _chunk(b"IDAT", zlib.compress(bytes(raw), 9))
                + _chunk(b"IEND", b""))
