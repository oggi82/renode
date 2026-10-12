if request.IsInit:
    mux_selectors = [0] * 32
if 0x280 <= request.Offset < 0x300:
    sel = (request.Offset - 0x280) // 4
    if request.IsWrite:
        mux_selectors[sel] = request.Value
    else:
        request.Value = mux_selectors[sel]
else:
    request.Value = {0x264: 0x3, 0x320: 0xFF, 0x3A0: 0xFF, 0x508: 0x0, 0x568: 0x0, 0xA18: 0xFF}.get(request.Offset, (0x0 if (request.Counter % 2) else 0xFFFFFFFF))
