import from mmap { MAP_SHARED, mmap }

with entry {
    mm = mmap(-1, 8, flags=MAP_SHARED);
    address = mm._addr;
    mm.resize(4);
    print("length=" + str(len(mm)));
    print("same-address=" + str(mm._addr == address));
    mm.close();
}
