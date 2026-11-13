import from mmap { MAP_SHARED, mmap }

with entry {
    # Jac constructors keep tagname after the init arguments; None is its default.
    mm: mmap = mmap(-1, 8, None, MAP_SHARED);
    mm[0] = 65;
    mm.resize(4);
    length: int = len(mm);
    print(length);
    print(mm[0]);
    mm.close();
}
