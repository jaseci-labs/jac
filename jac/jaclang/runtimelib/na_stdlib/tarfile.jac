import os;
import from os.path { abspath, normpath }
import from io { BytesIO }
import from compression.zstd { ZstdFile }
import from _tarfile_native {
    tar_read_file,
    tar_create,
    tar_write,
    tar_close,
    tar_chmod,
    tar_symlink,
    tar_link,
    tar_utime
}

glob:pub BLOCKSIZE: int = 512,
     RECORDSIZE: int = 10240;

glob:pub USTAR_FORMAT: int = 0,
     GNU_FORMAT: int = 1,
     PAX_FORMAT: int = 2,
     DEFAULT_FORMAT: int = 2;

glob:pub REGTYPE: bytes = b"0",
     AREGTYPE: bytes = b"\x00",
     LNKTYPE: bytes = b"1",
     SYMTYPE: bytes = b"2",
     CHRTYPE: bytes = b"3",
     BLKTYPE: bytes = b"4",
     DIRTYPE: bytes = b"5",
     FIFOTYPE: bytes = b"6",
     CONTTYPE: bytes = b"7",
     GNUTYPE_LONGNAME: bytes = b"L",
     GNUTYPE_LONGLINK: bytes = b"K",
     GNUTYPE_SPARSE: bytes = b"S",
     XHDTYPE: bytes = b"x",
     XGLTYPE: bytes = b"g",
     SOLARIS_XHDTYPE: bytes = b"X";

glob _COPY_BUFSIZE: int = 65536,
     _STREAM_CHUNK: int = 1048576,
     _MODE_NONE: int = -1;


obj:pub TarError(Exception) {}


obj:pub ReadError(TarError) {}


obj:pub CompressionError(TarError) {}


obj:pub StreamError(TarError) {}


obj:pub ExtractError(TarError) {}


obj:pub HeaderError(TarError) {}


obj:pub InvalidHeaderError(HeaderError) {}


obj:pub FilterError(TarError) {}


obj:pub AbsolutePathError(FilterError) {}


obj:pub OutsideDestinationError(FilterError) {}


obj:pub SpecialFileError(FilterError) {}


obj:pub AbsoluteLinkError(FilterError) {}


obj:pub LinkOutsideDestinationError(FilterError) {}


def _is_supported_type(t: bytes) -> bool {
    return t == b"0"
        or t == b"\x00"
        or t == b"1"
        or t == b"2"
        or t == b"5"
        or t == b"6"
        or t == b"7"
        or t == b"3"
        or t == b"4"
        or t == b"L"
        or t == b"K"
        or t == b"S";
}


def _is_gnu_type(t: bytes) -> bool {
    return t == b"L" or t == b"K" or t == b"S";
}


def _nts(s: bytes) -> str {
    n: int = len(s);
    i: int = 0;
    while i < n and s[i] != 0 {
        i += 1;
    }
    return s[0:i].decode();
}


def _nti(s: bytes) -> int {
    n: int = len(s);
    if n == 0 {
        return 0;
    }
    first: int = s[0];
    if first == 128 or first == 255 {
        mag_len: int = n - 1;
        if mag_len > 8 {
            extra: int = mag_len - 8;
            j: int = 1;
            while j <= extra {
                if (first == 128 and s[j] != 0) or (first == 255 and s[j] != 255) {
                    raise InvalidHeaderError(
                        "number field exceeds the native integer range"
                    );
                }
                j += 1;
            }
            low = s[n - 8:n];
            if first == 128 and low[0] >= 128 {
                raise InvalidHeaderError(
                    "number field exceeds the native integer range"
                );
            }
            return int.from_bytes(low, "big");
        }
        value: int = int.from_bytes(s[1:n], "big");
        if first == 255 {
            span: int = 1;
            k: int = 0;
            while k < mag_len {
                span = span * 256;
                k += 1;
            }
            value = value - span;
        }
        return value;
    }
    i: int = 0;
    while i < n and s[i] != 0 {
        i += 1;
    }
    end: int = i;
    i = 0;
    while i < end and s[i] == 32 {
        i += 1;
    }
    while end > i and s[end - 1] == 32 {
        end -= 1;
    }
    value: int = 0;
    while i < end {
        c: int = s[i];
        if c < 48 or c > 55 {
            raise InvalidHeaderError("invalid header");
        }
        value = value * 8 + (c - 48);
        i += 1;
    }
    return value;
}


def _blocks(size: int) -> int {
    if size <= 0 {
        return 0;
    }
    full: int = size // 512;
    if size % 512 != 0 {
        full += 1;
    }
    return full * 512;
}


def _all_zero(buf: bytes) -> bool {
    n: int = len(buf);
    i: int = 0;
    while i < n {
        if buf[i] != 0 {
            return False;
        }
        i += 1;
    }
    return True;
}


def _checksums(buf: bytes) -> tuple[(int, int)] {
    unsigned_sum: int = 256;
    signed_sum: int = 256;
    i: int = 0;
    while i < 512 {
        if i < 148 or i >= 156 {
            v: int = buf[i];
            unsigned_sum += v;
            if v >= 128 {
                signed_sum += v - 256;
            } else {
                signed_sum += v;
            }
        }
        i += 1;
    }
    return (unsigned_sum, signed_sum);
}


def _parse_int_field(value: str) -> int {
    text: str = value;
    dot: int = text.find(".");
    if dot != -1 {
        text = text[0:dot];
    }
    text = text.strip();
    if text == "" {
        return 0;
    }
    neg: bool = False;
    if text.startswith("-") {
        neg = True;
        text = text[1:];
    }
    n: int = len(text);
    i: int = 0;
    out: int = 0;
    while i < n {
        c: int = ord(text[i]);
        if c < 48 or c > 57 {
            return 0;
        }
        out = out * 10 + (c - 48);
        i += 1;
    }
    if neg {
        return -out;
    }
    return out;
}


obj:pub TarInfo {
    has name: str = "",
        mode: int = 0o644,
        uid: int = 0,
        gid: int = 0,
        size: int = 0,
        mtime: int = 0,
        chksum: int = 0,
        `type: bytes = b"0",
        linkname: str = "",
        uname: str = "",
        gname: str = "",
        devmajor: int = 0,
        devminor: int = 0,
        offset: int = 0,
        offset_data: int = 0,
        pax_headers: dict[str, str] = {};

    def isreg -> bool {
        return self.`type == b"0"
            or self.`type == b"\x00"
            or self.`type == b"7"
            or self.`type == b"S";
    }

    def isfile -> bool {
        return self.isreg();
    }

    def isdir -> bool {
        return self.`type == b"5";
    }

    def issym -> bool {
        return self.`type == b"2";
    }

    def islnk -> bool {
        return self.`type == b"1";
    }

    def ischr -> bool {
        return self.`type == b"3";
    }

    def isblk -> bool {
        return self.`type == b"4";
    }

    def isfifo -> bool {
        return self.`type == b"6";
    }

    def issparse -> bool {
        return self.`type == b"S";
    }

    def isdev -> bool {
        return self.ischr() or self.isblk() or self.isfifo();
    }

    def _clone -> TarInfo {
        return TarInfo(
            name=self.name,
            mode=self.mode,
            uid=self.uid,
            gid=self.gid,
            size=self.size,
            mtime=self.mtime,
            chksum=self.chksum,
            `type=self.`type,
            linkname=self.linkname,
            uname=self.uname,
            gname=self.gname,
            devmajor=self.devmajor,
            devminor=self.devminor,
            offset=self.offset,
            offset_data=self.offset_data,
            pax_headers=self.pax_headers
        );
    }

    def _apply_pax_info(pax_headers: dict[str, str]) {
        for key in pax_headers.keys() {
            value: str = pax_headers[key];
            if key == "path" {
                self.name = value.rstrip("/");
            } elif key == "linkpath" {
                self.linkname = value;
            } elif key == "size" {
                self.size = _parse_int_field(value);
            } elif key == "mtime" {
                self.mtime = _parse_int_field(value);
            } elif key == "uid" {
                self.uid = _parse_int_field(value);
            } elif key == "gid" {
                self.gid = _parse_int_field(value);
            } elif key == "uname" {
                self.uname = value;
            } elif key == "gname" {
                self.gname = value;
            }
        }
        copied: dict[str, str] = {};
        for key in pax_headers.keys() {
            copied[key] = pax_headers[key];
        }
        self.pax_headers = copied;
    }
}


def:pub frombuf(buf: bytes, dircheck: bool = True) -> TarInfo {
    if len(buf) == 0 {
        raise HeaderError("empty header");
    }
    if len(buf) != 512 {
        raise HeaderError("truncated header");
    }
    if _all_zero(buf) {
        raise HeaderError("end of file header");
    }
    chksum: int = _nti(buf[148:156]);
    (unsigned_sum, signed_sum) = _checksums(buf);
    if chksum != unsigned_sum and chksum != signed_sum {
        raise InvalidHeaderError("bad checksum");
    }
    info = TarInfo();
    info.name = _nts(buf[0:100]);
    info.mode = _nti(buf[100:108]);
    info.uid = _nti(buf[108:116]);
    info.gid = _nti(buf[116:124]);
    info.size = _nti(buf[124:136]);
    info.mtime = _nti(buf[136:148]);
    info.chksum = chksum;
    info.`type = buf[156:157];
    info.linkname = _nts(buf[157:257]);
    info.uname = _nts(buf[265:297]);
    info.gname = _nts(buf[297:329]);
    info.devmajor = _nti(buf[329:337]);
    info.devminor = _nti(buf[337:345]);
    prefix: str = _nts(buf[345:500]);
    if dircheck and info.`type == b"\x00" and info.name.endswith("/") {
        info.`type = b"5";
    }
    if info.isdir() {
        info.name = info.name.rstrip("/");
    }
    if prefix != "" and not _is_gnu_type(info.`type) {
        info.name = prefix + "/" + info.name;
    }
    return info;
}


def _frombuf_checked(buf: bytes, dircheck: bool, at_start: bool) -> TarInfo {
    try {
        return frombuf(buf, dircheck);
    } except HeaderError as e {
        if at_start {
            raise ReadError("invalid header");
        }
        raise e;
    }
}


def _parse_pax_records(buf: bytes, into: dict[str, str]) {
    n: int = len(buf);
    pos: int = 0;
    while pos < n and buf[pos] != 0 {
        length: int = 0;
        digits: int = 0;
        i: int = pos;
        while i < n and buf[i] >= 48 and buf[i] <= 57 {
            length = length * 10 + (buf[i] - 48);
            digits += 1;
            i += 1;
        }
        if digits == 0 or i >= n or buf[i] != 32 {
            raise InvalidHeaderError("invalid header");
        }
        if length < 5 or pos + length > n {
            raise InvalidHeaderError("invalid header");
        }
        last: int = pos + length - 1;
        if buf[last] != 10 {
            raise InvalidHeaderError("invalid header");
        }
        body = buf[i + 1:last];
        eq: int = -1;
        j: int = 0;
        blen: int = len(body);
        while j < blen {
            if body[j] == 61 {
                eq = j;
                break;
            }
            j += 1;
        }
        if eq <= 0 {
            raise InvalidHeaderError("invalid header");
        }
        keyword: str = body[0:eq].decode();
        value: str = body[eq + 1:blen].decode();
        into[keyword] = value;
        pos += length;
    }
}


obj:pub TarFile {
    has _data: bytes = b"",
        name: (str | None) = None,
        mode: str = "r",
        stream: bool = False,
        offset: int = 0,
        closed: bool = False,
        members: list[TarInfo] = [],
        pax_headers: dict[str, str] = {},
        firstmember: (TarInfo | None) = None,
        _loaded: bool = False,
        _src: (ZstdFile | None) = None,
        _window: bytes = b"",
        _window_start: int = 0,
        _src_eof: bool = False;

    def init(
        data: bytes = b"",
        name: (str | None) = None,
        mode: str = "r",
        stream: bool = False,
        src: (ZstdFile | None) = None
    ) {
        self._data = data;
        self._src = src;
        self._window = b"";
        self._window_start = 0;
        self._src_eof = False;
        self.name = name;
        self.mode = mode;
        self.stream = stream;
        self.closed = False;
        self.members = [];
        self.pax_headers = {};
        self._loaded = False;
        self.offset = 0;
        self.firstmember = None;
        self.firstmember = self.next();
    }

    def _check {
        if self.closed {
            raise OSError("TarFile is closed");
        }
    }

    def _read_at(pos: int, n: int) -> bytes {
        src = self._src;
        if src is None {
            total: int = len(self._data);
            if pos >= total {
                return b"";
            }
            end: int = pos + n;
            if end > total {
                end = total;
            }
            return self._data[pos:end];
        }
        if pos < self._window_start {
            raise StreamError("seeking backwards is not allowed");
        }
        if pos > self._window_start {
            ahead: int = pos - self._window_start;
            if ahead >= len(self._window) {
                beyond: int = ahead - len(self._window);
                self._window = b"";
                self._discard(beyond, src);
            } else {
                self._window = self._window[ahead:];
            }
            self._window_start = pos;
        }
        while len(self._window) < n and not self._src_eof {
            want: int = n - len(self._window);
            if want < _STREAM_CHUNK {
                want = _STREAM_CHUNK;
            }
            chunk = src.read(want);
            if len(chunk) == 0 {
                self._src_eof = True;
                break;
            }
            self._window = self._window + chunk;
        }
        avail: int = len(self._window);
        end2: int = n if n < avail else avail;
        return self._window[0:end2];
    }

    def _discard(count: int, src: ZstdFile) {
        remaining: int = count;
        while remaining > 0 and not self._src_eof {
            want: int = remaining if remaining < _STREAM_CHUNK else _STREAM_CHUNK;
            chunk = src.read(want);
            if len(chunk) == 0 {
                self._src_eof = True;
                break;
            }
            remaining -= len(chunk);
        }
    }

    def _read_header(at_start: bool, dircheck: bool) -> (TarInfo | None) {
        buf = self._read_at(self.offset, 512);
        if len(buf) == 0 {
            if at_start {
                raise ReadError("empty file");
            }
            return None;
        }
        if len(buf) != 512 {
            if at_start {
                raise ReadError("truncated header");
            }
            return None;
        }
        if _all_zero(buf) {
            return None;
        }
        info = _frombuf_checked(buf, dircheck, at_start);
        info.offset = self.offset;
        self.offset += 512;
        return info;
    }

    def _proc_builtin(info: TarInfo) -> TarInfo {
        info.offset_data = self.offset;
        if info.isreg() or not _is_supported_type(info.`type) {
            self.offset = info.offset_data + _blocks(info.size);
        }
        info._apply_pax_info(self.pax_headers);
        if info.isdir() {
            info.name = info.name.rstrip("/");
        }
        return info;
    }

    def _proc_gnulong(info: TarInfo) -> (TarInfo | None) {
        total: int = _blocks(info.size);
        buf = self._read_at(self.offset, total);
        if len(buf) != total {
            raise ReadError("unexpected end of data");
        }
        self.offset += total;
        nxt = self._read_header(False, False);
        if nxt is None {
            raise ReadError("missing or bad subsequent header");
        }
        nxt = self._proc_member(nxt);
        if nxt is None {
            raise ReadError("missing or bad subsequent header");
        }
        nxt.offset = info.offset;
        if info.`type == b"L" {
            nxt.name = _nts(buf[0:info.size]);
        } elif info.`type == b"K" {
            nxt.linkname = _nts(buf[0:info.size]);
        }
        if nxt.isdir() {
            nxt.name = nxt.name.removesuffix("/");
        }
        return nxt;
    }

    def _proc_pax(info: TarInfo) -> (TarInfo | None) {
        total: int = _blocks(info.size);
        buf = self._read_at(self.offset, total);
        if len(buf) != total {
            raise ReadError("unexpected end of data");
        }
        self.offset += total;
        pax: dict[str, str] = {};
        if info.`type == b"g" {
            pax = self.pax_headers;
        } else {
            for key in self.pax_headers.keys() {
                pax[key] = self.pax_headers[key];
            }
        }
        _parse_pax_records(buf[0:info.size], pax);
        nxt = self._read_header(False, False);
        if nxt is None {
            raise ReadError("missing or bad subsequent header");
        }
        nxt = self._proc_member(nxt);
        if nxt is None {
            raise ReadError("missing or bad subsequent header");
        }
        if info.`type == b"x" or info.`type == b"X" {
            nxt._apply_pax_info(pax);
            nxt.offset = info.offset;
            if "size" in pax {
                if nxt.isreg() or not _is_supported_type(nxt.`type) {
                    self.offset = nxt.offset_data + _blocks(nxt.size);
                }
            }
        }
        return nxt;
    }

    def _proc_member(info: TarInfo) -> (TarInfo | None) {
        if info.`type == b"L" or info.`type == b"K" {
            return self._proc_gnulong(info);
        }
        if info.`type == b"S" {
            raise ReadError(
                "GNU sparse members are not supported on the native pathway"
            );
        }
        if info.`type == b"x" or info.`type == b"g" or info.`type == b"X" {
            return self._proc_pax(info);
        }
        return self._proc_builtin(info);
    }

    def next -> (TarInfo | None) {
        self._check();
        if self.firstmember is not None {
            m = self.firstmember;
            self.firstmember = None;
            return m;
        }
        if self._loaded {
            return None;
        }
        info = self._read_header(self.offset == 0, True);
        if info is None {
            self._loaded = True;
            return None;
        }
        info = self._proc_member(info);
        if info is None {
            self._loaded = True;
            return None;
        }
        if not self.stream {
            self.members.append(info);
        }
        return info;
    }

    def __iter__ -> TarFile {
        return self;
    }

    def __next__ -> TarInfo {
        m = self.next();
        if m is None {
            raise StopIteration();
        }
        return m;
    }

    def getmembers -> list[TarInfo] {
        self._check();
        while not self._loaded {
            if self.next() is None {
                break;
            }
        }
        return self.members;
    }

    def getnames -> list[str] {
        out: list[str] = [];
        for m in self.getmembers() {
            out.append(m.name);
        }
        return out;
    }

    def extractfile(member: TarInfo) -> (BytesIO | None) {
        self._check();
        if member.isreg() or not _is_supported_type(member.`type) {
            data = self._read_at(member.offset_data, member.size);
            if len(data) != member.size {
                raise ReadError("unexpected end of data");
            }
            return BytesIO(data);
        }
        if member.islnk() or member.issym() {
            raise StreamError("cannot extract (sym)link as file object");
        }
        return None;
    }

    def _within(target: str, dest: str) -> bool {
        if target == dest {
            return True;
        }
        prefix: str = dest;
        if not prefix.endswith("/") {
            prefix = prefix + "/";
        }
        return target.startswith(prefix);
    }

    def _filter_member(member: TarInfo, dest_path: str, kind: str) -> TarInfo {
        if kind == "fully_trusted" {
            return member;
        }
        for_data: bool = False;
        if kind == "data" {
            for_data = True;
        } elif kind != "tar" {
            raise ValueError("filter '" + kind + "' not found");
        }
        info = member._clone();
        dest: str = os.path.realpath(dest_path);
        name: str = member.name;
        if name.startswith("/") {
            name = name.lstrip("/");
            info.name = name;
        }
        if name.startswith("/") {
            raise AbsolutePathError(
                "member '" + member.name + "' has an absolute path"
            );
        }
        target_path: str = os.path.realpath(os.path.join(dest, name));
        if not self._within(target_path, dest) {
            raise OutsideDestinationError(
                "'"
                    + member.name
                    + "' would be extracted to '"
                    + target_path
                    + "', which is outside the destination"
            );
        }
        mode: int = member.mode & 0o755;
        if for_data {
            if member.isreg() or member.islnk() {
                if (mode & 0o100) == 0 {
                    mode = mode & 0o666;
                }
                mode = mode | 0o600;
            } elif member.isdir() or member.issym() {
                mode = _MODE_NONE;
            } else {
                raise SpecialFileError("'" + member.name + "' is a special file");
            }
        }
        info.mode = mode;
        if for_data {
            info.uid = -1;
            info.gid = -1;
            info.uname = "";
            info.gname = "";
            if member.islnk() or member.issym() {
                if member.linkname.startswith("/") {
                    raise AbsoluteLinkError(
                        "'" + member.name + "' is a link to an absolute path"
                    );
                }
                if target_path == dest {
                    raise OutsideDestinationError(
                        "'"
                            + member.name
                            + "' would be extracted to '"
                            + target_path
                            + "', which is outside the destination"
                    );
                }
                normalized: str = normpath(member.linkname);
                info.linkname = normalized;
                link_target: str = "";
                if member.issym() {
                    link_dir: str = os.path.dirname(name.rstrip("/"));
                    link_target = os.path.join(
                        os.path.join(dest, link_dir), normalized
                    );
                } else {
                    link_target = os.path.join(dest, normalized);
                }
                link_target = os.path.realpath(link_target);
                if not self._within(link_target, dest) {
                    raise LinkOutsideDestinationError(
                        "'"
                            + member.name
                            + "' would link to '"
                            + link_target
                            + "', which is outside the destination"
                    );
                }
            }
        }
        return info;
    }

    def _makefile(info: TarInfo, targetpath: str) {
        fd: int = tar_create(targetpath);
        if fd < 0 {
            raise OSError("could not create file '" + targetpath + "'");
        }
        pos: int = info.offset_data;
        remaining: int = info.size;
        while remaining > 0 {
            step: int = _COPY_BUFSIZE;
            if remaining < step {
                step = remaining;
            }
            chunk = self._read_at(pos, step);
            if len(chunk) < step {
                tar_close(fd);
                raise ReadError("unexpected end of data");
            }
            if tar_write(fd, chunk) != 0 {
                tar_close(fd);
                raise OSError("could not write file '" + targetpath + "'");
            }
            pos += step;
            remaining -= step;
        }
        tar_close(fd);
    }

    def _makedir(info: TarInfo, targetpath: str) {
        if os.path.isdir(targetpath) {
            return;
        }
        if info.mode == _MODE_NONE {
            os.mkdir(targetpath);
        } else {
            os.mkdir(targetpath, 0o700);
        }
        if not os.path.isdir(targetpath) {
            raise OSError("could not create directory '" + targetpath + "'");
        }
    }

    def _makelink(info: TarInfo, targetpath: str, extraction_root: str) {
        if info.issym() {
            if tar_symlink(info.linkname, targetpath) != 0 {
                raise ExtractError("could not create symlink '" + targetpath + "'");
            }
            return;
        }
        link_target: str = os.path.join(extraction_root, info.linkname);
        if not os.path.exists(link_target) {
            raise ExtractError("unable to resolve link inside archive");
        }
        if tar_link(link_target, targetpath) != 0 {
            raise ExtractError("could not create hard link '" + targetpath + "'");
        }
    }

    def _chmod(info: TarInfo, targetpath: str) {
        if info.mode == _MODE_NONE {
            return;
        }
        if tar_chmod(targetpath, info.mode & 0o7777) != 0 {
            raise ExtractError("could not change mode");
        }
    }

    def _utime(info: TarInfo, targetpath: str) {
        if tar_utime(targetpath, info.mtime) != 0 {
            raise ExtractError("could not change modification time");
        }
    }

    def _extract_member(
        info: TarInfo, targetpath: str, set_attrs: bool, extraction_root: str
    ) {
        target: str = targetpath.rstrip("/");
        upperdirs: str = os.path.dirname(target);
        if upperdirs != "" and not os.path.exists(upperdirs) {
            os.makedirs(upperdirs);
        }
        if info.isreg() {
            self._makefile(info, target);
        } elif info.isdir() {
            self._makedir(info, target);
        } elif info.isfifo() or info.ischr() or info.isblk() {
            raise ExtractError(
                "special file '"
                    + info.name
                    + "' is not supported on the native pathway"
            );
        } elif info.islnk() or info.issym() {
            self._makelink(info, target, extraction_root);
        } else {
            self._makefile(info, target);
        }
        if set_attrs and not info.issym() {
            self._chmod(info, target);
            self._utime(info, target);
        }
    }

    def extract(member: TarInfo, path: str = "", filter: str = "data") {
        self._check();
        kind: str = filter;
        info = self._filter_member(member, path, kind);
        self._extract_member(info, os.path.join(path, info.name), True, path);
    }

    def extractall(path: str = ".", filter: str = "data") {
        self._check();
        kind: str = filter;
        directories: list[TarInfo] = [];
        member = self.next();
        while member is not None {
            info = self._filter_member(member, path, kind);
            if info.isdir() {
                directories.append(member);
            }
            self._extract_member(
                info, os.path.join(path, info.name), not info.isdir(), path
            );
            member = self.next();
        }
        n: int = len(directories);
        i: int = 0;
        while i < n {
            j: int = i + 1;
            while j < n {
                if directories[j].name > directories[i].name {
                    tmp = directories[i];
                    directories[i] = directories[j];
                    directories[j] = tmp;
                }
                j += 1;
            }
            i += 1;
        }
        for unfiltered in directories {
            info = self._filter_member(unfiltered, path, kind);
            dirpath: str = os.path.join(path, info.name);
            if not os.path.isdir(dirpath) {
                continue;
            }
            self._utime(info, dirpath);
            self._chmod(info, dirpath);
        }
    }

    def close {
        self.closed = True;
    }

    def __enter__ -> TarFile {
        self._check();
        return self;
    }

    def __exit__(exc_type: any, exc: any, tb: any) -> bool {
        self.close();
        return False;
    }
}


def _as_str(value: (str | None)) -> str {
    if value is None {
        return "";
    }
    return value;
}


def _open_tar(
    name: (str | None) = None,
    mode: str = "r",
    fileobj: (ZstdFile | None) = None,
    bufsize: int = 10240
) -> TarFile {
    if name is None and fileobj is None {
        raise ValueError("nothing to open");
    }
    stream: bool = False;
    if mode == "r" or mode == "r:" or mode == "r:*" {
        stream = False;
    } elif mode == "r|" or mode == "r|*" {
        stream = True;
    } elif mode.startswith("r:") or mode.startswith("r|") {
        raise CompressionError(
            "compressed tar mode '" + mode + "' is not supported on the native pathway"
        );
    } else {
        raise ValueError(
            "mode '" + mode + "' is not supported on the native pathway (read-only)"
        );
    }
    resolved_name: (str | None) = None;
    if fileobj is not None {
        if name is not None {
            resolved_name = abspath(_as_str(name));
        }
        return TarFile(name=resolved_name, mode="r", stream=stream, src=fileobj);
    }
    nm: str = _as_str(name);
    return TarFile(data=tar_read_file(nm), name=abspath(nm), mode="r", stream=stream);
}


def:pub open(
    name: (str | None) = None,
    mode: str = "r",
    fileobj: (ZstdFile | None) = None,
    bufsize: int = 10240
) -> TarFile {
    return _open_tar(name=name, mode=mode, fileobj=fileobj, bufsize=bufsize);
}


def:pub is_tarfile(name: str) -> bool {
    try {
        t = _open_tar(name=name, mode="r");
        t.close();
        return True;
    } except TarError as e {
        return False;
    }
}
