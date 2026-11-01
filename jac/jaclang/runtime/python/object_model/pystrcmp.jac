import from c {
    def PyOS_mystrnicmp(s1: ptr[u8], s2: ptr[u8], size: i64) -> i32 {
        if size == 0 {
            return 0;
        }
        p1 = s1;
        p2 = s2;
        n = size;
        while True {
            n -= 1;
            if not (
                n > 0
                and p1.view(1)[0] != u8(0)
                and p2.view(1)[0] != u8(0)
                and py_tolower(p1.view(1)[0]) == py_tolower(p2.view(1)[0])
            ) {
                break;
            }
            p1 = p1 + 1;
            p2 = p2 + 1;
        }
        return i32(py_tolower(p1.view(1)[0])) - i32(py_tolower(p2.view(1)[0]));
    }  def PyOS_mystricmp(s1: ptr[u8], s2: ptr[u8]) -> i32 {
        p1 = s1;
        p2 = s2;
        while p1.view(1)[0] != u8(0)
            and p2.view(1)[0] != u8(0)
            and py_tolower(p1.view(1)[0]) == py_tolower(p2.view(1)[0]) {
            p1 = p1 + 1;
            p2 = p2 + 1;
        }
        return i32(py_tolower(p1.view(1)[0])) - i32(py_tolower(p2.view(1)[0]));
    }
}
