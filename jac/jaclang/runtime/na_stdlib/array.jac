import struct;


def _arr_itemsize(tc: str) -> int {
    if tc == "b" or tc == "B" {
        return 1;
    }
    if tc == "h" or tc == "H" {
        return 2;
    }
    if tc == "i" or tc == "I" or tc == "f" {
        return 4;
    }
    if tc == "l" or tc == "L" or tc == "q" or tc == "Q" or tc == "d" {
        return 8;
    }
    raise ValueError(
        "bad typecode (must be b, B, u, w, h, H, i, I, l, L, q, Q, f or d)"
    );
}


def _arr_signed(tc: str) -> bool {
    return tc == "b" or tc == "h" or tc == "i" or tc == "l" or tc == "q";
}


def _arr_float(tc: str) -> bool {
    return tc == "f" or tc == "d";
}


def _arr_cname(tc: str) -> str {
    if tc == "b" {
        return "signed char";
    }
    if tc == "B" {
        return "unsigned byte integer";
    }
    if tc == "h" {
        return "signed short integer";
    }
    if tc == "H" {
        return "unsigned short";
    }
    if tc == "i" {
        return "signed integer";
    }
    return "unsigned int";
}


def _arr_bounds(tc: str) -> tuple[int, int] {
    sz: int = _arr_itemsize(tc);
    if _arr_signed(tc) {
        top: int = (1 << (sz * 8 - 1)) - 1;
        return (-(top + 1), top);
    }
    return (0, (1 << (sz * 8)) - 1);
}


def _put_le(buf: bytearray, off: int, v: int, size: int) {
    dp: int = __bytearray_data(buf);
    p: int = dp + off;
    if size == 1 {
        __mem_store_i8(p, v);
    } elif size == 2 {
        __mem_store_i16(p, v);
    } elif size == 4 {
        __mem_store_i32(p, v);
    } else {
        __mem_store_i64(p, v);
    }
}


def _get_le(buf: bytearray, off: int, size: int, signed: bool) -> int {
    dp: int = __bytearray_data(buf);
    p: int = dp + off;
    if size == 8 {
        return __mem_load_i64(p);
    }
    v: int = 0;
    if size == 1 {
        v = __mem_load_i8(p);
    } elif size == 2 {
        v = __mem_load_i16(p);
    } else {
        v = __mem_load_i32(p);
    }
    if signed and v >= (1 << (size * 8 - 1)) {
        v -= 1 << (size * 8);
    }
    return v;
}


obj:pub array {
    has typecode: str = "b",
        _buf: bytearray = bytearray(0),
        itemsize: int = 1,
        _sgn: bool = True,
        _flt: bool = False,
        _lo: int = -128,
        _hi: int = 127,
        _enc: bytearray = bytearray(0);

    def init(typecode: str, initial: (list[any] | None) = None) {
        self.typecode = typecode;
        self.itemsize = _arr_itemsize(typecode);
        self._sgn = _arr_signed(typecode);
        self._flt = _arr_float(typecode);
        if self.itemsize == 8 {
            self._lo = 0;
            self._hi = -1;
        } else {
            bounds: tuple[int, int] = _arr_bounds(typecode);
            self._lo = bounds[0];
            self._hi = bounds[1];
        }
        self._buf = bytearray(0);
        self._enc = bytearray(self.itemsize);
        if initial is not None {
            self.extend(initial);
        }
    }

    def _count -> int {
        return len(self._buf) // self.itemsize;
    }

    def __len__ -> int {
        return self._count();
    }

    def _coerce_int(v: any) -> int {
        if isinstance(v, float) {
            raise TypeError("'float' object cannot be interpreted as an integer");
        }
        iv: int = v;
        return iv;
    }

    def _coerce_float(v: any) -> float {
        if isinstance(v, int) {
            iv: int = v;
            return float(iv);
        }
        fv: float = v;
        return fv;
    }

    def _check_range(v: int) {
        tc = self.typecode;
        if self.itemsize == 8 {
            if v < 0 and not self._sgn {
                if tc == "L" {
                    raise OverflowError("can't convert negative value to unsigned int");
                }
                raise OverflowError("can't convert negative int to unsigned");
            }
            return;
        }
        if v < self._lo or v > self._hi {
            if tc == "I" {
                if v < 0 {
                    raise OverflowError("can't convert negative value to unsigned int");
                }
                raise OverflowError("unsigned int is greater than maximum");
            }
            name: str = _arr_cname(tc);
            if v < 0 {
                raise OverflowError(name + " is less than minimum");
            }
            raise OverflowError(name + " is greater than maximum");
        }
    }

    def _write_elem(off: int, v: int) {
        b = self._buf;
        _put_le(b, off, v, self.itemsize);
    }

    def _read_elem(off: int) -> int {
        b = self._buf;
        return _get_le(b, off, self.itemsize, self._sgn);
    }

    def _write_float_elem(off: int, v: float) {
        b = self._buf;
        if self.typecode == "f" {
            struct.pack_into("<f", b, off, v);
        } else {
            struct.pack_into("<d", b, off, v);
        }
    }

    def _read_float_elem(off: int) -> float {
        b = self._buf;
        if self.typecode == "f" {
            (fv, ) = struct.unpack_from("<f", b, off);
            return fv;
        }
        (dv, ) = struct.unpack_from("<d", b, off);
        return dv;
    }

    def _encode_one(v: any, dst: bytearray) {
        if self._flt {
            fv: float = self._coerce_float(v);
            if self.typecode == "f" {
                struct.pack_into("<f", dst, 0, fv);
            } else {
                struct.pack_into("<d", dst, 0, fv);
            }
            return;
        }
        iv: int = self._coerce_int(v);
        self._check_range(iv);
        _put_le(dst, 0, iv, self.itemsize);
    }

    def append(v: any) {
        self._encode_one(v, self._enc);
        b = self._buf;
        b.extend(self._enc);
    }

    def extend(seq: list[any]) {
        n: int = len(seq);
        i: int = 0;
        while i < n {
            self.append(seq[i]);
            i += 1;
        }
    }

    def extend_array(other: array) {
        if other.typecode != self.typecode {
            raise TypeError("can only extend with array of same kind");
        }
        b = self._buf;
        b.extend(other._buf);
    }

    def extend_bytes(data: bytes) {
        n: int = len(data);
        i: int = 0;
        while i < n {
            self.append(data[i]);
            i += 1;
        }
    }

    def fromlist(seq: list[any]) {
        self.extend(seq);
    }

    def insert(i: int, v: any) {
        n: int = self._count();
        at: int = i;
        if at < 0 {
            at += n;
            if at < 0 {
                at = 0;
            }
        }
        if at > n {
            at = n;
        }
        self._encode_one(v, self._enc);
        pos: int = at * self.itemsize;
        b = self._buf;
        self._buf = b[0:pos] + self._enc + b[pos:];
    }

    def pop(i: int = -1) -> any {
        n: int = self._count();
        if n == 0 {
            raise IndexError("pop from empty array");
        }
        at: int = i;
        if at < 0 {
            at += n;
        }
        if at < 0 or at >= n {
            raise IndexError("pop index out of range");
        }
        v: any = self.__getitem__(at);
        sz: int = self.itemsize;
        b = self._buf;
        self._buf = b[0:at * sz] + b[(at + 1) * sz:];
        return v;
    }

    def remove(v: any) {
        i: int = self._find(v);
        if i < 0 {
            raise ValueError("array.remove(x): x not in array");
        }
        sz: int = self.itemsize;
        b = self._buf;
        self._buf = b[0:i * sz] + b[(i + 1) * sz:];
    }

    def _elem_eq(v: any, i: int) -> bool {
        sz: int = self.itemsize;
        if self._flt {
            return self._read_float_elem(i * sz) == self._coerce_float(v);
        }
        return self._read_elem(i * sz) == self._coerce_int(v);
    }

    def _find(v: any) -> int {
        n: int = self._count();
        i: int = 0;
        while i < n {
            if self._elem_eq(v, i) {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    def index(v: any, start: int = 0, stop: int = 9223372036854775807) -> int {
        n: int = self._count();
        lo: int = start;
        if lo < 0 {
            lo += n;
            if lo < 0 {
                lo = 0;
            }
        }
        hi: int = stop;
        if hi < 0 {
            hi += n;
            if hi < 0 {
                hi = 0;
            }
        }
        if hi > n {
            hi = n;
        }
        i: int = lo;
        while i < hi {
            if self._elem_eq(v, i) {
                return i;
            }
            i += 1;
        }
        raise ValueError("array.index(x): x not in array");
    }

    def count(v: any) -> int {
        n: int = self._count();
        c: int = 0;
        i: int = 0;
        while i < n {
            if self._elem_eq(v, i) {
                c += 1;
            }
            i += 1;
        }
        return c;
    }

    def __contains__(v: any) -> bool {
        return self._find(v) >= 0;
    }

    def reverse {
        sz: int = self.itemsize;
        n: int = self._count();
        b = self._buf;
        i: int = 0;
        j: int = n - 1;
        while i < j {
            k: int = 0;
            while k < sz {
                t: int = b[i * sz + k];
                b[i * sz + k] = b[j * sz + k];
                b[j * sz + k] = t;
                k += 1;
            }
            i += 1;
            j -= 1;
        }
    }

    def byteswap {
        sz: int = self.itemsize;
        if sz == 1 {
            return;
        }
        b = self._buf;
        n: int = len(b);
        i: int = 0;
        while i < n {
            k: int = 0;
            while k < sz // 2 {
                t: int = b[i + k];
                b[i + k] = b[i + sz - 1 - k];
                b[i + sz - 1 - k] = t;
                k += 1;
            }
            i += sz;
        }
    }

    def tobytes -> bytes {
        return bytes(self._buf);
    }

    def frombytes(data: bytes) {
        sz: int = self.itemsize;
        if len(data) % sz != 0 {
            raise ValueError("bytes length not a multiple of item size");
        }
        b = self._buf;
        b.extend(data);
    }

    def tofile(f: any) {
        f.write(bytes(self._buf));
    }

    def fromfile(f: any, n: int) {
        self.frombytes(f.read(n * self.itemsize));
    }

    def tolist -> list[any] {
        out: list[any] = [];
        n: int = self._count();
        sz: int = self.itemsize;
        i: int = 0;
        while i < n {
            if self._flt {
                out.append(self._read_float_elem(i * sz));
            } else {
                out.append(self._read_elem(i * sz));
            }
            i += 1;
        }
        return out;
    }

    def buffer_info -> tuple[int, int] {
        n: int = len(self._buf);
        if n == 0 {
            return (0, 0);
        }
        return (__bytearray_data(self._buf), self._count());
    }

    def __getitem__(i: int) -> any {
        n: int = self._count();
        at: int = i;
        if at < 0 {
            at += n;
        }
        if at < 0 or at >= n {
            raise IndexError("array index out of range");
        }
        if self._flt {
            return self._read_float_elem(at * self.itemsize);
        }
        return self._read_elem(at * self.itemsize);
    }

    def __setitem__(i: int, v: any) {
        n: int = self._count();
        at: int = i;
        if at < 0 {
            at += n;
        }
        if at < 0 or at >= n {
            raise IndexError("array assignment index out of range");
        }
        if self._flt {
            self._write_float_elem(at * self.itemsize, self._coerce_float(v));
        } else {
            iv: int = self._coerce_int(v);
            self._check_range(iv);
            self._write_elem(at * self.itemsize, iv);
        }
    }

    def _same_elem(other: array, i: int) -> bool {
        if self._flt {
            lv: float = self._read_float_elem(i * self.itemsize);
            if other._flt {
                return lv == other._read_float_elem(i * other.itemsize);
            }
            return lv == float(other._read_elem(i * other.itemsize));
        }
        li: int = self._read_elem(i * self.itemsize);
        if other._flt {
            return float(li) == other._read_float_elem(i * other.itemsize);
        }
        return li == other._read_elem(i * other.itemsize);
    }

    def __eq__(other: array) -> bool {
        if self._count() != other._count() {
            return False;
        }
        i: int = 0;
        n: int = self._count();
        while i < n {
            if not self._same_elem(other, i) {
                return False;
            }
            i += 1;
        }
        return True;
    }

    def __ne__(other: array) -> bool {
        return not self.__eq__(other);
    }

    def __add__(other: array) -> array {
        if other.typecode != self.typecode {
            raise TypeError("bad argument type for built-in operation");
        }
        out: array = array(self.typecode);
        out._buf = self._buf + other._buf;
        return out;
    }

    def __mul__(n: int) -> array {
        out: array = array(self.typecode);
        if n <= 0 {
            return out;
        }
        b = self._buf;
        out._buf = b * n;
        return out;
    }
}
