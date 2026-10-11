# Minimal stand-in for the FCE (CRC engine) kernel 0, only used by the flash tests while the real model of the
# 'dma-fce' component is not part of the platform. Not a CRC32: it folds every input word into a rotating
# checksum, which is all the emulated-EEPROM library needs (the same data always yields the same result).
if request.IsInit:
    crc = 0
    cfg = 0
    clc = 0
elif request.IsRead:
    if request.Offset == 0x00:
        request.Value = clc
    elif request.Offset == 0x08:
        request.Value = 0x00A3C001
    elif request.Offset == 0x24 or request.Offset == 0x38:
        request.Value = crc
    elif request.Offset == 0x28:
        request.Value = cfg
    else:
        request.Value = 0
elif request.IsWrite:
    if request.Offset == 0x00:
        clc = request.Value
    elif request.Offset == 0x20:
        crc = (((crc << 5) | (crc >> 27)) & 0xFFFFFFFF) ^ (request.Value & 0xFFFFFFFF)
    elif request.Offset == 0x28:
        cfg = request.Value
    elif request.Offset == 0x38:
        crc = request.Value
