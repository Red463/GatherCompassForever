"""Own terrain-only mask rules validated in the Ashenvale experiment."""
from collections import deque
import math
import struct

TILE = 1600 / 3
CELL = TILE / 128
ORIGIN = TILE * 32
ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'


def chunks(blob, start=0, end=None):
    end = len(blob) if end is None else end
    while start < end:
        if start + 8 > end: raise ValueError('Truncated chunk header')
        tag, size = struct.unpack_from('<4sI', blob, start)
        stop = start + 8 + size
        if stop > end: raise ValueError('Chunk exceeds its container')
        yield tag[::-1].decode('ascii'), start + 8, stop
        start = stop


def slope(a, b, c, d, centre):
    gradients = (((b-a)/CELL, (2*centre-a-b)/CELL),
                 ((b+d-2*centre)/CELL, (d-b)/CELL),
                 ((d-c)/CELL, (c+d-2*centre)/CELL),
                 ((2*centre-a-c)/CELL, (c-a)/CELL))
    return math.degrees(math.atan(max(math.hypot(x,y) for x,y in gradients)))


def tile_mask(blob):
    result = bytearray([64]) * (128*128)  # missing: distinct from liquid
    top = list(chunks(blob));liquid = bytearray(128*128);seen=set()
    for tag, base, end in top:
        if tag!='MH2O':continue
        for ci in range(256):
            offset,layers,_=struct.unpack_from('<3I',blob,base+ci*12)
            for li in range(layers):
                p=base+offset+li*24
                _,fmt,low,high,xo,yo,width,height,bitmap,vertices=struct.unpack_from('<HHff4BII',blob,p)
                if xo+width>8 or yo+height>8:raise ValueError('Invalid liquid bounds')
                for y in range(height):
                    for x in range(width):
                        bit=y*width+x
                        if bitmap and not blob[base+bitmap+bit//8]&(1<<(bit%8)):continue
                        liquid[((ci//16)*8+yo+y)*128+(ci%16)*8+xo+x]=1
    for tag,base,end in top:
        if tag!='MCNK':continue
        flags,cx,cy=struct.unpack_from('<3I',blob,base)
        if not (0<=cx<16 and 0<=cy<16) or (cx,cy) in seen:raise ValueError('Invalid terrain chunk index')
        seen.add((cx,cy))
        values=next(struct.unpack_from('<145f',blob,a) for name,a,b in chunks(blob,base+128,end) if name=='MCVT')
        if not all(math.isfinite(v) for v in values):raise ValueError('Nonfinite height')
        low_holes=struct.unpack_from('<H',blob,base+60)[0]
        high_holes=int.from_bytes(blob[base+20:base+28],'little')
        for y in range(8):
            for x in range(8):
                at=(cy*8+y)*128+cx*8+x
                angle=slope(values[y*17+x],values[y*17+x+1],values[(y+1)*17+x],values[(y+1)*17+x+1],values[y*17+9+x])
                hole=high_holes&(1<<(y*8+x)) if flags&65536 else low_holes&(1<<((y//2)*4+x//2))
                # Preserve liquid as separate review until after connectivity cleanup.
                result[at]=128 if liquid[at] else 0 if hole or angle>=50 else 255
    if len(seen)!=256:raise ValueError('Terrain tile has missing chunks')
    return bytes(result)


def components(raw,w,h,value):
    seen=bytearray(len(raw))
    for first in range(len(raw)):
        if raw[first]!=value or seen[first]:continue
        q=deque([first]);seen[first]=1;members=[];edge=False;unknown=False
        while q:
            at=q.popleft();members.append(at);x,y=at%w,at//w
            edge=edge or x==0 or x==w-1 or y==0 or y==h-1
            for ny in range(max(0,y-1),min(h,y+2)):
                for nx in range(max(0,x-1),min(w,x+2)):
                    n=ny*w+nx
                    if raw[n] not in (0,255):unknown=True
                    if raw[n]==value and not seen[n]:seen[n]=1;q.append(n)
        yield members,edge,unknown


def cleanup(raw,w,h):
    result=bytearray(raw);removed=filled=0
    for members,edge,unknown in components(raw,w,h,0):
        if len(members)<=2 and not edge and not unknown:
            for p in members:result[p]=255
            removed+=len(members)
    # Find the largest candidate component separately to avoid retaining every
    # full-world component simultaneously in Python objects.
    cleaned=bytes(result);largest_at=None;largest=0
    for members,_,_ in components(cleaned,w,h,255):
        if len(members)>largest:largest=len(members);largest_at=members[0]
    for members,edge,unknown in components(cleaned,w,h,255):
        if members[0]!=largest_at and not edge and not unknown:
            for p in members:result[p]=0
            filled+=len(members)
    return bytes(result),dict(tiny_cells_removed=removed,enclosed_cells_filled=filled)


def encode_rows(raw,w,h):
    rows=[]
    for y in range(h):
        row=[]
        for x in range(0,w,6):
            value=0
            for bit in range(6):
                value=value*2+int(x+bit<w and raw[y*w+x+bit] in (128,255))
            row.append(ALPHABET[value])
        rows.append(''.join(row))
    return rows
