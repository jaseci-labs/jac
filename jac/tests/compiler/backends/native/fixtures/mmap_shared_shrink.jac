import from mmap { MAP_SHARED, mmap }

with entry {
    mm: mmap = mmap(-1, 8, MAP_SHARED);
    mm[0] = 65;
    mm.resize(4);
    print(mm[0]);
    mm.close();
}
