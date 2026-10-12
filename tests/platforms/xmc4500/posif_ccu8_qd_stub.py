# Stand-in for CCU81 while the 'ccu8' component is not part of the platform: POSIF_QD prints a line whenever it sees the period
# match flag (INTS bit 0) of slice 2 (offset 0x3A0). The flag reads as set on every 20000th poll, everything else reads as 0.
if request.IsInit:
    reads = 0
elif request.IsRead:
    request.Value = 0
    if request.Offset == 0x3A0:
        reads += 1
        if reads >= 20000:
            reads = 0
            request.Value = 1
