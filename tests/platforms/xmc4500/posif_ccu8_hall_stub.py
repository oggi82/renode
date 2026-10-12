# Stand-in for CCU80 while the 'ccu8' component is not part of the platform: POSIF_Hall only waits for the period match flag
# (INTS bit 0) of slice 2 (offset 0x3A0), which reads as always set. All other registers read as 0, writes are ignored.
if request.IsRead:
    request.Value = 1 if request.Offset == 0x3A0 else 0
