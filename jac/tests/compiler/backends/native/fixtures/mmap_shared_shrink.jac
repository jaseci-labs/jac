import from mmap { MAP_SHARED, mmap }

with entry {
    mm: mmap = mmap(-1, 8, MAP_SHARED);
    mm.write_byte(65);
    mm.resize(4);
    mm.seek(0);
    print(mm.read_byte());
    mm.close();
}
