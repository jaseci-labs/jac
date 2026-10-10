obj:pub AddressValueError(ValueError) {}
obj:pub NetmaskValueError(ValueError) {}

glob _V4_ALL: int = 4294967295;

glob _V4_PRIV: list[int] = [
         0,
         8,
         167772160,
         8,
         2130706432,
         8,
         2851995648,
         16,
         2886729728,
         12,
         3221225472,
         24,
         3221225642,
         31,
         3221225984,
         24,
         3232235520,
         16,
         3323068416,
         15,
         3325256704,
         24,
         3405803776,
         24,
         4026531840,
         4,
         4294967295,
         32
     ];
glob _V4_PRIV_EXC: list[int] = [3221225481, 32, 3221225482, 32];
glob _V4_PUBLIC: list[int] = [1681915904, 10];
glob _V4_RESERVED: list[int] = [4026531840, 4];
glob _V4_LINKLOCAL: list[int] = [2851995648, 16];
glob _V4_LOOPBACK: list[int] = [2130706432, 8];
glob _V4_MULTICAST: list[int] = [3758096384, 4];

glob _V6_PRIV_HI: list[int] = [
         0,
         0,
         0,
         28428538856144896,
         72057594037927936,
         2306124484190404608,
         2306139568115548160,
         2306405959167115264,
         4611404543450677248,
         18158513697557839872,
         18338657682652659712
     ];
glob _V6_PRIV_LO: list[int] = [1, 0, 281470681743360, 0, 0, 0, 0, 0, 0, 0, 0];
glob _V6_PRIV_PL: list[int] = [128, 128, 96, 48, 64, 23, 32, 16, 20, 7, 10];
glob _V6_PRIV_EXC_HI: list[int] = [
         2306124488485371904,
         2306124488485371904,
         2306124497075306496,
         2306124501388230656,
         2306124621629358080,
         2306124690348834816
     ];
glob _V6_PRIV_EXC_LO: list[int] = [1, 2, 0, 0, 0, 0];
glob _V6_PRIV_EXC_PL: list[int] = [128, 128, 32, 48, 28, 28];
glob _V6_RESERVED_HI: list[int] = [
         0,
         72057594037927936,
         144115188075855872,
         288230376151711744,
         576460752303423488,
         1152921504606846976,
         4611686018427387904,
         6917529027641081856,
         9223372036854775808,
         11529215046068469760,
         13835058055282163712,
         16140901064495857664,
         17293822569102704640,
         17870283321406128128,
         18302628885633695744
     ];
glob _V6_RESERVED_PL: list[int] = [8, 8, 7, 6, 5, 4, 3, 3, 3, 3, 3, 4, 5, 6, 9];
glob _V6_LINKLOCAL: list[int] = [18338657682652659712, 0, 10];
glob _V6_MULTICAST: list[int] = [18374686479671623680, 0, 8];

glob _HEXD: str = "0123456789abcdef",
     _PRINTABLE: str = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";


def _q(s: str) -> str {
    has_sq: bool = False;
    has_dq: bool = False;
    n: int = len(s);
    i: int = 0;
    while i < n {
        c: str = s[i];
        if c == "'" {
            has_sq = True;
        } elif c == '"' {
            has_dq = True;
        }
        i += 1;
    }
    quote: str = "'";
    if has_sq and not has_dq {
        quote = '"';
    }
    body: str = "";
    i = 0;
    while i < n {
        c = s[i];
        if c == "\\" or c == quote {
            body = body + "\\" + c;
        } elif c == "\n" {
            body = body + "\\n";
        } elif c == "\r" {
            body = body + "\\r";
        } elif c == "\t" {
            body = body + "\\t";
        } else {
            body = body + c;
        }
        i += 1;
    }
    return quote + body + quote;
}


def _qb(b: bytes) -> str {
    body: str = "";
    n: int = len(b);
    i: int = 0;
    while i < n {
        c: int = b[i];
        if c == 92 {
            body = body + "\\\\";
        } elif c == 39 {
            body = body + "\\'";
        } elif c == 9 {
            body = body + "\\t";
        } elif c == 10 {
            body = body + "\\n";
        } elif c == 13 {
            body = body + "\\r";
        } elif c >= 32 and c <= 126 {
            body = body + _PRINTABLE[c - 32];
        } else {
            body = body + "\\x" + _HEXD[(c >> 4) & 15] + _HEXD[c & 15];
        }
        i += 1;
    }
    return "b'" + body + "'";
}


def _arg_repr(address: any) -> str {
    if isinstance(address, str) {
        s: str = address;
        return _q(s);
    }
    if isinstance(address, bytes) {
        return _qb(address);
    }
    if isinstance(address, int) {
        v: int = address;
        return str(v);
    }
    return "<unprintable>";
}


def _hexx(v: int) -> str {
    if v == 0 {
        return "0";
    }
    out: str = "";
    while v > 0 {
        out = _HEXD[v & 15] + out;
        v = v >> 4;
    }
    return out;
}


def _hex4(v: int) -> str {
    return _HEXD[(v >> 12) & 15]
        + _HEXD[(v >> 8) & 15]
        + _HEXD[(v >> 4) & 15]
        + _HEXD[v & 15];
}


def _find_ch(s: str, code: int) -> int {
    n: int = len(s);
    i: int = 0;
    while i < n {
        if ord(s[i]) == code {
            return i;
        }
        i += 1;
    }
    return -1;
}


def _split_max(s: str, sep: str, maxsplit: int) -> list[str] {
    out: list[str] = [];
    start: int = 0;
    n: int = len(s);
    i: int = 0;
    while i < n {
        if s[i] == sep {
            if maxsplit >= 0 and len(out) >= maxsplit {
                break;
            }
            out.append(s[start:i]);
            start = i + 1;
        }
        i += 1;
    }
    out.append(s[start:n]);
    return out;
}


def _ctz32(v: int) -> int {
    if v == 0 {
        return 32;
    }
    c: int = 0;
    while (v & 1) == 0 {
        v = v >> 1;
        c += 1;
    }
    return c;
}


def _v4_prefix_mask(prefixlen: int) -> int {
    return _V4_ALL ^ (_V4_ALL >> prefixlen);
}


def _v4_in(ip: int, net: int, pl: int) -> bool {
    if pl == 0 {
        return True;
    }
    return (ip >> (32 - pl)) == (net >> (32 - pl));
}


def _v4_parse_octet(octet: str) -> int {
    if octet == "" {
        raise ValueError("Empty octet not permitted");
    }
    n: int = len(octet);
    i: int = 0;
    while i < n {
        c: str = octet[i];
        if c < "0" or c > "9" {
            raise ValueError("Only decimal digits permitted in " + _q(octet));
        }
        i += 1;
    }
    if n > 3 {
        raise ValueError("At most 3 characters permitted in " + _q(octet));
    }
    if octet != "0" and octet[0] == "0" {
        raise ValueError("Leading zeros are not permitted in " + _q(octet));
    }
    v: int = 0;
    i = 0;
    while i < n {
        v = v * 10 + (ord(octet[i]) - 48);
        i += 1;
    }
    if v > 255 {
        raise ValueError("Octet " + str(v) + " (> 255) not permitted");
    }
    return v;
}


def _v4_parse(s: str) -> int {
    if s == "" {
        raise AddressValueError("Address cannot be empty");
    }
    octets: list[str] = _split_max(s, ".", -1);
    if len(octets) != 4 {
        raise AddressValueError("Expected 4 octets in " + _q(s));
    }
    ip: int = 0;
    shift: int = 24;
    k: int = 0;
    while k < 4 {
        try {
            v: int = _v4_parse_octet(octets[k]);
        } except ValueError as e {
            raise AddressValueError(str(e) + " in " + _q(s));
        }
        ip = ip | (v << shift);
        shift -= 8;
        k += 1;
    }
    return ip;
}


def _v4_str(ip: int) -> str {
    return str((ip >> 24) & 255)
        + "."
        + str((ip >> 16) & 255)
        + "."
        + str((ip >> 8) & 255)
        + "."
        + str(ip & 255);
}


def _v4_ptr(s: str) -> str {
    parts: list[str] = _split_max(s, ".", -1);
    out: str = "";
    i: int = len(parts) - 1;
    while i >= 0 {
        if out != "" {
            out = out + ".";
        }
        out = out + parts[i];
        i -= 1;
    }
    return out + ".in-addr.arpa";
}


def _one_slash(s: str, orig: str) -> int {
    first: int = _find_ch(s, 47);
    if first >= 0 {
        rest: str = s[first + 1:len(s)];
        if _find_ch(rest, 47) >= 0 {
            raise AddressValueError("Only one '/' permitted in " + _q(orig));
        }
    }
    return first;
}


def _v4_make_netmask_int(prefixlen: int) -> list[int] {
    if prefixlen < 0 or prefixlen > 32 {
        raise NetmaskValueError(str(prefixlen) + " is not a valid netmask");
    }
    mask: int = _v4_prefix_mask(prefixlen);
    out: list[int] = [];
    out.append(mask);
    out.append(prefixlen);
    return out;
}


def _v4_make_netmask_str(arg: str) -> list[int] {
    n: int = len(arg);
    isdig: bool = n > 0;
    i: int = 0;
    while i < n {
        c: str = arg[i];
        if c < "0" or c > "9" {
            isdig = False;
        }
        i += 1;
    }
    if isdig {
        pl: int = 0;
        i = 0;
        while i < n {
            pl = pl * 10 + (ord(arg[i]) - 48);
            i += 1;
        }
        if pl < 0 or pl > 32 {
            raise NetmaskValueError(_q(arg) + " is not a valid netmask");
        }
        return _v4_make_netmask_int(pl);
    }
    ip: int = 0;
    try {
        ip = _v4_parse(arg);
    } except AddressValueError {
        raise NetmaskValueError(_q(arg) + " is not a valid netmask");
    }
    tz: int = _ctz32(ip);
    pl = 32 - tz;
    if (ip >> tz) == ((1 << pl) - 1) {
        return _v4_make_netmask_int(pl);
    }
    inv: int = ip ^ _V4_ALL;
    tz = _ctz32(inv);
    pl = 32 - tz;
    if (inv >> tz) == ((1 << pl) - 1) {
        return _v4_make_netmask_int(pl);
    }
    raise NetmaskValueError(_q(arg) + " is not a valid netmask");
}


def _v4_make_netmask(arg: any) -> list[int] {
    if isinstance(arg, int) {
        v: int = arg;
        return _v4_make_netmask_int(v);
    }
    s: str = arg;
    return _v4_make_netmask_str(s);
}


obj:pub IPv4Address {
    has _ip: int = 0,
        version: int = 4,
        max_prefixlen: int = 32;

    has is_multicast: bool { getter; }
    has is_loopback: bool { getter; }
    has is_link_local: bool { getter; }
    has is_reserved: bool { getter; }
    has is_unspecified: bool { getter; }
    has is_private: bool { getter; }
    has is_global: bool { getter; }
    has packed: bytes { getter; }
    has ipv6_mapped: IPv6Address { getter; }
    has compressed: str { getter; }
    has exploded: str { getter; }
    has reverse_pointer: str { getter; }

    def init(address: any) {
        if isinstance(address, int) {
            v: int = address;
            if v < 0 {
                raise AddressValueError(
                    str(v) + " (< 0) is not permitted as an IPv4 address"
                );
            }
            if v > _V4_ALL {
                raise AddressValueError(
                    str(v) + " (>= 2**32) is not permitted as an IPv4 address"
                );
            }
            self._ip = v;
            return;
        }
        if isinstance(address, bytes) {
            if len(address) != 4 {
                raise AddressValueError(
                    _qb(address)
                        + " (len "
                        + str(len(address))
                        + " != 4) is not permitted as an IPv4 address"
                );
            }
            self._ip = (
                (address[0] << 24) | (address[1] << 16) | (address[2] << 8) | address[3]
            )
                & _V4_ALL;
            return;
        }
        if isinstance(address, str) {
            s: str = address;
            if _find_ch(s, 47) >= 0 {
                raise AddressValueError("Unexpected '/' in " + _q(s));
            }
            self._ip = _v4_parse(s);
            return;
        }
        raise TypeError("IPv4Address() argument must be a str, int or bytes");
    }

    def __eq__(other: IPv4Address) -> bool {
        return self._ip == other._ip;
    }

    def __lt__(other: IPv4Address) -> bool {
        return self._ip < other._ip;
    }

    def __add__(other: int) -> IPv4Address {
        return IPv4Address(self._ip + other);
    }

    def __sub__(other: int) -> IPv4Address {
        return IPv4Address(self._ip - other);
    }

    def __str__ -> str {
        return _v4_str(self._ip);
    }
}


impl IPv4Address.is_multicast.getter -> bool {
    return _v4_in(self._ip, _V4_MULTICAST[0], _V4_MULTICAST[1]);
}


impl IPv4Address.is_loopback.getter -> bool {
    return _v4_in(self._ip, _V4_LOOPBACK[0], _V4_LOOPBACK[1]);
}


impl IPv4Address.is_link_local.getter -> bool {
    return _v4_in(self._ip, _V4_LINKLOCAL[0], _V4_LINKLOCAL[1]);
}


impl IPv4Address.is_reserved.getter -> bool {
    return _v4_in(self._ip, _V4_RESERVED[0], _V4_RESERVED[1]);
}


impl IPv4Address.is_unspecified.getter -> bool {
    return self._ip == 0;
}


def _v4_priv(ip: int) -> bool {
    hit: bool = False;
    k: int = 0;
    while k < len(_V4_PRIV) {
        if _v4_in(ip, _V4_PRIV[k], _V4_PRIV[k + 1]) {
            hit = True;
        }
        k += 2;
    }
    if not hit {
        return False;
    }
    k = 0;
    while k < len(_V4_PRIV_EXC) {
        if _v4_in(ip, _V4_PRIV_EXC[k], _V4_PRIV_EXC[k + 1]) {
            return False;
        }
        k += 2;
    }
    return True;
}


impl IPv4Address.is_private.getter -> bool {
    return _v4_priv(self._ip);
}


impl IPv4Address.is_global.getter -> bool {
    if _v4_in(self._ip, _V4_PUBLIC[0], _V4_PUBLIC[1]) {
        return False;
    }
    return not self.is_private;
}


impl IPv4Address.packed.getter -> bytes {
    out: list[int] = [];
    out.append((self._ip >> 24) & 255);
    out.append((self._ip >> 16) & 255);
    out.append((self._ip >> 8) & 255);
    out.append(self._ip & 255);
    return bytes(out);
}


impl IPv4Address.ipv6_mapped.getter -> IPv6Address {
    return IPv6Address("::ffff:" + _v4_str(self._ip));
}


impl IPv4Address.compressed.getter -> str {
    return _v4_str(self._ip);
}


impl IPv4Address.exploded.getter -> str {
    return _v4_str(self._ip);
}


impl IPv4Address.reverse_pointer.getter -> str {
    return _v4_ptr(_v4_str(self._ip));
}


def _v4_network_from(ip: int, prefixlen: int) -> IPv4Network {
    mask: int = _v4_prefix_mask(prefixlen);
    n: IPv4Network = IPv4Network(0);
    n.network_address = IPv4Address(ip & mask);
    n.netmask = IPv4Address(mask);
    n._prefixlen = prefixlen;
    n._hosts_full = prefixlen >= 31;
    return n;
}


obj:pub IPv4Network {
    has network_address: IPv4Address,
        netmask: IPv4Address,
        _prefixlen: int = 32,
        _hosts_full: bool = False,
        version: int = 4,
        max_prefixlen: int = 32;

    has prefixlen: int { getter; }
    has hostmask: IPv4Address { getter; }
    has broadcast_address: IPv4Address { getter; }
    has num_addresses: int { getter; }
    has with_prefixlen: str { getter; }
    has with_netmask: str { getter; }
    has with_hostmask: str { getter; }
    has exploded: str { getter; }
    has compressed: str { getter; }
    has reverse_pointer: str { getter; }
    has is_multicast: bool { getter; }
    has is_reserved: bool { getter; }
    has is_link_local: bool { getter; }
    has is_private: bool { getter; }
    has is_global: bool { getter; }
    has is_unspecified: bool { getter; }
    has is_loopback: bool { getter; }

    def init(address: any, strict: bool = True) {
        addr: any = address;
        mask_arg: any = 32;
        if isinstance(address, tuple) {
            nt: int = len(address);
            if nt == 0 {
                raise IndexError("tuple index out of range");
            }
            if nt > 2 {
                raise ValueError(
                    "too many values to unpack (expected 2, got " + str(nt) + ")"
                );
            }
            addr = address[0];
            if nt > 1 {
                mask_arg = address[1];
            }
        } elif isinstance(address, str) {
            s0: str = address;
            sep: int = _one_slash(s0, s0);
            if sep >= 0 {
                mask_arg = s0[sep + 1:len(s0)];
                addr = s0[0:sep];
            }
        }
        ip: int = 0;
        if isinstance(addr, int) {
            v: int = addr;
            if v < 0 {
                raise AddressValueError(
                    str(v) + " (< 0) is not permitted as an IPv4 address"
                );
            }
            if v > _V4_ALL {
                raise AddressValueError(
                    str(v) + " (>= 2**32) is not permitted as an IPv4 address"
                );
            }
            ip = v;
        } elif isinstance(addr, bytes) {
            if len(addr) != 4 {
                raise AddressValueError(
                    _qb(addr)
                        + " (len "
                        + str(len(addr))
                        + " != 4) is not permitted as an IPv4 address"
                );
            }
            ip = ((addr[0] << 24) | (addr[1] << 16) | (addr[2] << 8) | addr[3])
                & _V4_ALL;
        } elif isinstance(addr, str) {
            ip = _v4_parse(addr);
        } else {
            raise TypeError("IPv4Network() argument must be a str, int or bytes");
        }
        pair: list[int] = _v4_make_netmask(mask_arg);
        mask: int = pair[0];
        self.network_address = IPv4Address(ip);
        self.netmask = IPv4Address(mask);
        self._prefixlen = pair[1];
        packed: int = ip;
        if (packed & mask) != packed {
            if strict {
                raise ValueError(
                    _v4_str(packed) + "/" + str(pair[1]) + " has host bits set"
                );
            }
            self.network_address = IPv4Address(packed & mask);
        }
        self._hosts_full = pair[1] >= 31;
    }

    def __str__ -> str {
        return _v4_str(self.network_address._ip) + "/" + str(self._prefixlen);
    }

    def __eq__(other: IPv4Network) -> bool {
        return self._prefixlen == other._prefixlen
            and self.network_address._ip == other.network_address._ip;
    }

    def __lt__(other: IPv4Network) -> bool {
        if self.network_address._ip != other.network_address._ip {
            return self.network_address._ip < other.network_address._ip;
        }
        return self.netmask._ip < other.netmask._ip;
    }

    def __contains__(other: IPv4Address) -> bool {
        return _v4_in(other._ip, self.network_address._ip, self._prefixlen);
    }

    def hosts -> list[IPv4Address] {
        if self.num_addresses > 1048576 {
            raise ValueError(
                "hosts(): network has more than 2**20 addresses; the native hosts() materializes a list and refuses (CPython returns a lazy iterator)"
            );
        }
        out: list[IPv4Address] = [];
        if self._hosts_full {
            out.append(IPv4Address(self.network_address._ip));
            if self._prefixlen == 31 {
                out.append(self.broadcast_address);
            }
            return out;
        }
        cur: int = self.network_address._ip + 1;
        last: int = self.broadcast_address._ip;
        while cur < last {
            out.append(IPv4Address(cur));
            cur += 1;
        }
        return out;
    }

    def subnets(
        prefixlen_diff: int = 1, new_prefix: int | None = None
    ) -> list[IPv4Network] {
        if self._prefixlen == 32 {
            out0: list[IPv4Network] = [];
            out0.append(self);
            return out0;
        }
        diff: int = prefixlen_diff;
        if new_prefix is not None {
            if new_prefix < self._prefixlen {
                raise ValueError("new prefix must be longer");
            }
            if prefixlen_diff != 1 {
                raise ValueError("cannot set prefixlen_diff and new_prefix");
            }
            diff = new_prefix - self._prefixlen;
        }
        if diff < 0 {
            raise ValueError("prefix length diff must be > 0");
        }
        new_prefixlen: int = self._prefixlen + diff;
        if new_prefixlen > 32 {
            raise ValueError(
                "prefix length diff "
                    + str(new_prefixlen)
                    + " is invalid for netblock "
                    + self.__str__()
            );
        }
        if diff > 20 {
            raise ValueError(
                "subnets(): refusing to materialize more than 2**20 subnets on native (CPython returns a lazy iterator)"
            );
        }
        out: list[IPv4Network] = [];
        start: int = self.network_address._ip;
        end: int = self.broadcast_address._ip + 1;
        step: int = (_V4_ALL - self.netmask._ip + 1) >> diff;
        cur: int = start;
        while cur < end {
            out.append(_v4_network_from(cur, new_prefixlen));
            cur += step;
        }
        return out;
    }

    def supernet(
        prefixlen_diff: int = 1, new_prefix: int | None = None
    ) -> IPv4Network {
        if self._prefixlen == 0 {
            return self;
        }
        diff: int = prefixlen_diff;
        if new_prefix is not None {
            if new_prefix > self._prefixlen {
                raise ValueError("new prefix must be shorter");
            }
            if prefixlen_diff != 1 {
                raise ValueError("cannot set prefixlen_diff and new_prefix");
            }
            diff = self._prefixlen - new_prefix;
        }
        new_prefixlen: int = self._prefixlen - diff;
        if new_prefixlen < 0 {
            raise ValueError(
                "current prefixlen is "
                    + str(self._prefixlen)
                    + ", cannot have a prefixlen_diff of "
                    + str(diff)
            );
        }
        new_net: int = (self.network_address._ip & (self.netmask._ip << diff))
            & _V4_ALL;
        return _v4_network_from(new_net, new_prefixlen);
    }

    def overlaps(other: IPv4Network) -> bool {
        return _v4_in(
            self.network_address._ip, other.network_address._ip, other._prefixlen
        )
            or _v4_in(
                self.broadcast_address._ip, other.network_address._ip, other._prefixlen
            )
            or _v4_in(
                other.network_address._ip, self.network_address._ip, self._prefixlen
            )
            or _v4_in(
                other.broadcast_address._ip, self.network_address._ip, self._prefixlen
            );
    }

    def subnet_of(other: IPv4Network) -> bool {
        return other.network_address._ip <= self.network_address._ip
            and other.broadcast_address._ip >= self.broadcast_address._ip;
    }

    def supernet_of(other: IPv4Network) -> bool {
        return self.network_address._ip <= other.network_address._ip
            and self.broadcast_address._ip >= other.broadcast_address._ip;
    }

    def compare_networks(other: IPv4Network) -> int {
        if self.network_address._ip < other.network_address._ip {
            return -1;
        }
        if self.network_address._ip > other.network_address._ip {
            return 1;
        }
        if self.netmask._ip < other.netmask._ip {
            return -1;
        }
        if self.netmask._ip > other.netmask._ip {
            return 1;
        }
        return 0;
    }

    def address_exclude(other: IPv4Network) -> list[IPv4Network] {
        out: list[IPv4Network] = [];
        if not other.subnet_of(self) {
            raise ValueError(
                _v4_str(other.network_address._ip)
                    + "/"
                    + str(other._prefixlen)
                    + " not contained in "
                    + _v4_str(self.network_address._ip)
                    + "/"
                    + str(self._prefixlen)
            );
        }
        if other.__eq__(self) {
            return out;
        }
        o: IPv4Network = _v4_network_from(other.network_address._ip, other._prefixlen);
        s: list[IPv4Network] = self.subnets();
        s1: IPv4Network = s[0];
        s2: IPv4Network = s[1];
        while not s1.__eq__(o) and not s2.__eq__(o) {
            if o.subnet_of(s1) {
                out.append(s2);
                s = s1.subnets();
            } elif o.subnet_of(s2) {
                out.append(s1);
                s = s2.subnets();
            } else {
                raise AssertionError("Error performing exclusion");
            }
            s1 = s[0];
            s2 = s[1];
        }
        if s1.__eq__(o) {
            out.append(s2);
        } elif s2.__eq__(o) {
            out.append(s1);
        } else {
            raise AssertionError("Error performing exclusion");
        }
        return out;
    }
}


impl IPv4Network.prefixlen.getter -> int {
    return self._prefixlen;
}


impl IPv4Network.hostmask.getter -> IPv4Address {
    return IPv4Address(self.netmask._ip ^ _V4_ALL);
}


impl IPv4Network.broadcast_address.getter -> IPv4Address {
    return IPv4Address(self.network_address._ip | (self.netmask._ip ^ _V4_ALL));
}


impl IPv4Network.num_addresses.getter -> int {
    return 1 << (32 - self._prefixlen);
}


impl IPv4Network.with_prefixlen.getter -> str {
    return self.__str__();
}


impl IPv4Network.with_netmask.getter -> str {
    return _v4_str(self.network_address._ip) + "/" + _v4_str(self.netmask._ip);
}


impl IPv4Network.with_hostmask.getter -> str {
    return _v4_str(self.network_address._ip)
        + "/"
        + _v4_str(self.netmask._ip ^ _V4_ALL);
}


impl IPv4Network.exploded.getter -> str {
    return self.__str__();
}


impl IPv4Network.compressed.getter -> str {
    return self.__str__();
}


impl IPv4Network.reverse_pointer.getter -> str {
    return _v4_ptr(self.__str__());
}


impl IPv4Network.is_multicast.getter -> bool {
    return self.network_address.is_multicast and self.broadcast_address.is_multicast;
}


impl IPv4Network.is_reserved.getter -> bool {
    return self.network_address.is_reserved and self.broadcast_address.is_reserved;
}


impl IPv4Network.is_link_local.getter -> bool {
    return self.network_address.is_link_local and self.broadcast_address.is_link_local;
}


impl IPv4Network.is_private.getter -> bool {
    na: int = self.network_address._ip;
    ba: int = self.broadcast_address._ip;
    hit: bool = False;
    k: int = 0;
    while k < len(_V4_PRIV) {
        if _v4_in(na, _V4_PRIV[k], _V4_PRIV[k + 1])
            and _v4_in(ba, _V4_PRIV[k], _V4_PRIV[k + 1]) {
            hit = True;
        }
        k += 2;
    }
    if not hit {
        return False;
    }
    k = 0;
    while k < len(_V4_PRIV_EXC) {
        if _v4_in(na, _V4_PRIV_EXC[k], _V4_PRIV_EXC[k + 1])
            or _v4_in(ba, _V4_PRIV_EXC[k], _V4_PRIV_EXC[k + 1]) {
            return False;
        }
        k += 2;
    }
    return True;
}


impl IPv4Network.is_global.getter -> bool {
    if _v4_in(self.network_address._ip, _V4_PUBLIC[0], _V4_PUBLIC[1])
        and _v4_in(self.broadcast_address._ip, _V4_PUBLIC[0], _V4_PUBLIC[1]) {
        return False;
    }
    return not self.is_private;
}


impl IPv4Network.is_unspecified.getter -> bool {
    return self.network_address.is_unspecified
        and self.broadcast_address.is_unspecified;
}


impl IPv4Network.is_loopback.getter -> bool {
    return self.network_address.is_loopback and self.broadcast_address.is_loopback;
}


obj:pub IPv4Interface {
    has network: IPv4Network,
        netmask: IPv4Address,
        _ip: int = 0,
        _prefixlen: int = 32,
        version: int = 4,
        max_prefixlen: int = 32;

    has ip: IPv4Address { getter; }
    has hostmask: IPv4Address { getter; }
    has with_prefixlen: str { getter; }
    has with_netmask: str { getter; }
    has with_hostmask: str { getter; }
    has exploded: str { getter; }
    has compressed: str { getter; }
    has reverse_pointer: str { getter; }
    has is_multicast: bool { getter; }
    has is_reserved: bool { getter; }
    has is_link_local: bool { getter; }
    has is_private: bool { getter; }
    has is_global: bool { getter; }
    has is_unspecified: bool { getter; }
    has is_loopback: bool { getter; }
    has packed: bytes { getter; }
    has ipv6_mapped: IPv6Address { getter; }

    def init(address: any) {
        addr: any = address;
        mask_arg: any = 32;
        if isinstance(address, tuple) {
            nt: int = len(address);
            if nt == 0 {
                raise IndexError("tuple index out of range");
            }
            if nt > 2 {
                raise ValueError(
                    "too many values to unpack (expected 2, got " + str(nt) + ")"
                );
            }
            addr = address[0];
            if nt > 1 {
                mask_arg = address[1];
            }
        } elif isinstance(address, str) {
            s0: str = address;
            sep: int = _one_slash(s0, s0);
            if sep >= 0 {
                mask_arg = s0[sep + 1:len(s0)];
                addr = s0[0:sep];
            }
        }
        if isinstance(addr, int) {
            v: int = addr;
            if v < 0 {
                raise AddressValueError(
                    str(v) + " (< 0) is not permitted as an IPv4 address"
                );
            }
            if v > _V4_ALL {
                raise AddressValueError(
                    str(v) + " (>= 2**32) is not permitted as an IPv4 address"
                );
            }
            self._ip = v;
        } elif isinstance(addr, bytes) {
            if len(addr) != 4 {
                raise AddressValueError(
                    _qb(addr)
                        + " (len "
                        + str(len(addr))
                        + " != 4) is not permitted as an IPv4 address"
                );
            }
            self._ip = ((addr[0] << 24) | (addr[1] << 16) | (addr[2] << 8) | addr[3])
                & _V4_ALL;
        } elif isinstance(addr, str) {
            self._ip = _v4_parse(addr);
        } else {
            raise TypeError("IPv4Interface() argument must be a str, int or bytes");
        }
        pair: list[int] = _v4_make_netmask(mask_arg);
        self._prefixlen = pair[1];
        self.netmask = IPv4Address(pair[0]);
        self.network = _v4_network_from(self._ip, self._prefixlen);
    }

    def __str__ -> str {
        return _v4_str(self._ip) + "/" + str(self._prefixlen);
    }

    def __eq__(other: IPv4Interface) -> bool {
        return self._ip == other._ip and self._prefixlen == other._prefixlen;
    }

    def __lt__(other: IPv4Interface) -> bool {
        if self.network.__lt__(other.network) {
            return True;
        }
        if self.network.__eq__(other.network) {
            return self._ip < other._ip;
        }
        return False;
    }

    def __contains__(other: IPv4Address) -> bool {
        return self.network.__contains__(other);
    }
}


impl IPv4Interface.ip.getter -> IPv4Address {
    return IPv4Address(self._ip);
}


impl IPv4Interface.hostmask.getter -> IPv4Address {
    return IPv4Address(_v4_prefix_mask(self._prefixlen) ^ _V4_ALL);
}


impl IPv4Interface.with_prefixlen.getter -> str {
    return self.__str__();
}


impl IPv4Interface.with_netmask.getter -> str {
    return _v4_str(self._ip) + "/" + _v4_str(self.netmask._ip);
}


impl IPv4Interface.with_hostmask.getter -> str {
    return _v4_str(self._ip) + "/" + _v4_str(self.netmask._ip ^ _V4_ALL);
}


impl IPv4Interface.exploded.getter -> str {
    return self.__str__();
}


impl IPv4Interface.compressed.getter -> str {
    return self.__str__();
}


impl IPv4Interface.reverse_pointer.getter -> str {
    return _v4_ptr(self.__str__());
}


impl IPv4Interface.is_multicast.getter -> bool {
    return _v4_in(self._ip, _V4_MULTICAST[0], _V4_MULTICAST[1]);
}


impl IPv4Interface.is_loopback.getter -> bool {
    return _v4_in(self._ip, _V4_LOOPBACK[0], _V4_LOOPBACK[1]);
}


impl IPv4Interface.is_link_local.getter -> bool {
    return _v4_in(self._ip, _V4_LINKLOCAL[0], _V4_LINKLOCAL[1]);
}


impl IPv4Interface.is_reserved.getter -> bool {
    return _v4_in(self._ip, _V4_RESERVED[0], _V4_RESERVED[1]);
}


impl IPv4Interface.is_unspecified.getter -> bool {
    return self._ip == 0;
}


impl IPv4Interface.is_private.getter -> bool {
    return _v4_priv(self._ip);
}


impl IPv4Interface.is_global.getter -> bool {
    return not _v4_in(self._ip, _V4_PUBLIC[0], _V4_PUBLIC[1]) and not self.is_private;
}


impl IPv4Interface.packed.getter -> bytes {
    out: list[int] = [];
    out.append((self._ip >> 24) & 255);
    out.append((self._ip >> 16) & 255);
    out.append((self._ip >> 8) & 255);
    out.append(self._ip & 255);
    return bytes(out);
}


impl IPv4Interface.ipv6_mapped.getter -> IPv6Address {
    return IPv6Address("::ffff:" + _v4_str(self._ip));
}


def _v6_hextet(hextet: str, full: str) -> int {
    n: int = len(hextet);
    i: int = 0;
    while i < n {
        c: str = hextet[i];
        if not (
            (c >= "0" and c <= "9")
            or (c >= "a" and c <= "f")
            or (c >= "A" and c <= "F")
        ) {
            raise AddressValueError(
                "Only hex digits permitted in " + _q(hextet) + " in " + _q(full)
            );
        }
        i += 1;
    }
    if n > 4 {
        raise AddressValueError(
            "At most 4 characters permitted in " + _q(hextet) + " in " + _q(full)
        );
    }
    v: int = 0;
    i = 0;
    while i < n {
        c = hextet[i];
        d: int = ord(c);
        if d <= 57 {
            d -= 48;
        } elif d <= 70 {
            d -= 55;
        } else {
            d -= 87;
        }
        v = (v << 4) | d;
        i += 1;
    }
    return v;
}


def _v6_parse(s: str) -> list[int] {
    if s == "" {
        raise AddressValueError("Address cannot be empty");
    }
    n: int = len(s);
    if n > 45 {
        shorten: str = s;
        if n > 100 {
            shorten = s[0:45] + "(" + str(n - 90) + " chars elided)" + s[n - 45:n];
        }
        raise AddressValueError("At most 45 characters expected in " + _q(shorten));
    }
    parts: list[str] = _split_max(s, ":", 9);
    if len(parts) < 3 {
        raise AddressValueError("At least 3 parts expected in " + _q(s));
    }
    if _find_ch(parts[len(parts) - 1], 46) >= 0 {
        v4int: int = 0;
        try {
            v4int = _v4_parse(parts[len(parts) - 1]);
        } except AddressValueError as e {
            raise AddressValueError(str(e) + " in " + _q(s));
        }
        head: list[str] = parts[0:len(parts) - 1];
        head.append(_hexx((v4int >> 16) & 65535));
        head.append(_hexx(v4int & 65535));
        parts = head;
    }
    if len(parts) > 9 {
        raise AddressValueError("At most 8 colons permitted in " + _q(s));
    }
    skip_index: int = -1;
    i: int = 1;
    while i < len(parts) - 1 {
        if parts[i] == "" {
            if skip_index != -1 {
                raise AddressValueError("At most one '::' permitted in " + _q(s));
            }
            skip_index = i;
        }
        i += 1;
    }
    parts_hi: int = 0;
    parts_lo: int = 0;
    parts_skipped: int = 0;
    if skip_index != -1 {
        parts_hi = skip_index;
        parts_lo = len(parts) - skip_index - 1;
        if parts[0] == "" {
            parts_hi -= 1;
            if parts_hi != 0 {
                raise AddressValueError(
                    "Leading ':' only permitted as part of '::' in " + _q(s)
                );
            }
        }
        if parts[len(parts) - 1] == "" {
            parts_lo -= 1;
            if parts_lo != 0 {
                raise AddressValueError(
                    "Trailing ':' only permitted as part of '::' in " + _q(s)
                );
            }
        }
        parts_skipped = 8 - (parts_hi + parts_lo);
        if parts_skipped < 1 {
            raise AddressValueError(
                "Expected at most 7 other parts with '::' in " + _q(s)
            );
        }
    } else {
        if len(parts) != 8 {
            raise AddressValueError(
                "Exactly 8 parts expected without '::' in " + _q(s)
            );
        }
        if parts[0] == "" {
            raise AddressValueError(
                "Leading ':' only permitted as part of '::' in " + _q(s)
            );
        }
        if parts[len(parts) - 1] == "" {
            raise AddressValueError(
                "Trailing ':' only permitted as part of '::' in " + _q(s)
            );
        }
        parts_hi = len(parts);
        parts_lo = 0;
        parts_skipped = 0;
    }
    hi: int = 0;
    lo: int = 0;
    k: int = 0;
    while k < parts_hi {
        v: int = _v6_hextet(parts[k], s);
        hi = ((hi << 16) & -1) | ((lo >> 48) & 65535);
        lo = ((lo << 16) | v) & -1;
        k += 1;
    }
    k = 0;
    while k < parts_skipped {
        hi = ((hi << 16) & -1) | ((lo >> 48) & 65535);
        lo = (lo << 16) & -1;
        k += 1;
    }
    k = len(parts) - parts_lo;
    while k < len(parts) {
        v = _v6_hextet(parts[k], s);
        hi = ((hi << 16) & -1) | ((lo >> 48) & 65535);
        lo = ((lo << 16) | v) & -1;
        k += 1;
    }
    out: list[int] = [];
    out.append(hi);
    out.append(lo);
    return out;
}


def _u64_lt(a: int, b: int) -> bool {
    return (a ^ -9223372036854775808) < (b ^ -9223372036854775808);
}


def _u64_add(a: int, other: int) -> list[int] {
    s: int = a + other;
    carry: int = 0;
    if a >= 0 {
        if s < 0 {
            carry = 1;
        }
    } elif s >= 0 {
        carry = 1;
    }
    out: list[int] = [];
    out.append(s);
    out.append(carry);
    return out;
}


def _u64_sub(a: int, other: int) -> list[int] {
    borrow: int = 0;
    s: int = 0;
    if a >= 0 {
        s = a - other;
        if s < 0 {
            borrow = 1;
        }
    } else {
        s = a - other;
    }
    out: list[int] = [];
    out.append(s);
    out.append(borrow);
    return out;
}


def _v6_add1(hi: int, lo: int) -> list[int] {
    r: list[int] = _u64_add(lo, 1);
    return [hi + r[1], r[0]];
}


def _v6_compress(parts: list[str]) -> list[str] {
    best_start: int = -1;
    best_len: int = 0;
    cur_start: int = -1;
    cur_len: int = 0;
    i: int = 0;
    while i < len(parts) {
        if parts[i] == "0" {
            cur_len += 1;
            if cur_start == -1 {
                cur_start = i;
            }
            if cur_len > best_len {
                best_len = cur_len;
                best_start = cur_start;
            }
        } else {
            cur_len = 0;
            cur_start = -1;
        }
        i += 1;
    }
    if best_len <= 1 {
        return parts;
    }
    best_end: int = best_start + best_len;
    out: list[str] = [];
    i = 0;
    while i < best_start {
        out.append(parts[i]);
        i += 1;
    }
    out.append("");
    i = best_end;
    while i < len(parts) {
        out.append(parts[i]);
        i += 1;
    }
    if best_end == len(parts) {
        out.append("");
    }
    if best_start == 0 {
        front: list[str] = [""];
        i = 0;
        while i < len(out) {
            front.append(out[i]);
            i += 1;
        }
        out = front;
    }
    return out;
}


def _v6_join(parts: list[str]) -> str {
    s: str = "";
    i: int = 0;
    while i < len(parts) {
        if i > 0 {
            s = s + ":";
        }
        s = s + parts[i];
        i += 1;
    }
    return s;
}


def _v6_str_hextets(hi: int, lo: int) -> list[str] {
    parts: list[str] = [];
    parts.append(_hexx((hi >> 48) & 65535));
    parts.append(_hexx((hi >> 32) & 65535));
    parts.append(_hexx((hi >> 16) & 65535));
    parts.append(_hexx(hi & 65535));
    parts.append(_hexx((lo >> 48) & 65535));
    parts.append(_hexx((lo >> 32) & 65535));
    parts.append(_hexx((lo >> 16) & 65535));
    parts.append(_hexx(lo & 65535));
    return parts;
}


def _v6_str(hi: int, lo: int) -> str {
    return _v6_join(_v6_compress(_v6_str_hextets(hi, lo)));
}


def _v6_exploded(hi: int, lo: int) -> str {
    parts: list[str] = [];
    parts.append(_hex4((hi >> 48) & 65535));
    parts.append(_hex4((hi >> 32) & 65535));
    parts.append(_hex4((hi >> 16) & 65535));
    parts.append(_hex4(hi & 65535));
    parts.append(_hex4((lo >> 48) & 65535));
    parts.append(_hex4((lo >> 32) & 65535));
    parts.append(_hex4((lo >> 16) & 65535));
    parts.append(_hex4(lo & 65535));
    return _v6_join(parts);
}


def _v6_str_v4mapped(lo: int) -> str {
    hi96: int = 0;
    lo96: int = (lo >> 32) & 4294967295;
    parts: list[str] = ["0", "0"];
    parts.append(_hexx((hi96 >> 16) & 65535));
    parts.append(_hexx(hi96 & 65535));
    parts.append(_hexx((lo96 >> 48) & 65535));
    parts.append(_hexx((lo96 >> 32) & 65535));
    parts.append(_hexx((lo96 >> 16) & 65535));
    parts.append(_hexx(lo96 & 65535));
    return _v6_join(_v6_compress(parts)) + ":" + _v4_str(lo & 4294967295);
}


def _v6_is_v4mapped(hi: int, lo: int) -> bool {
    return hi == 0 and ((lo >> 32) & 4294967295) == 65535;
}


def _hex8(v: int) -> str {
    return _hex4((v >> 16) & 65535) + _hex4(v & 65535);
}


def _v6_ptr(s: str) -> str {
    out: str = "";
    first: bool = True;
    i: int = len(s) - 1;
    while i >= 0 {
        c: str = s[i];
        if c != ":" {
            if first {
                first = False;
            } else {
                out = out + ".";
            }
            out = out + c;
        }
        i -= 1;
    }
    return out + ".ip6.arpa";
}


def _v6_netmask(arg: any) -> int {
    if isinstance(arg, int) {
        if arg < 0 or arg > 128 {
            raise NetmaskValueError(str(arg) + " is not a valid netmask");
        }
        return arg;
    }
    isdig: bool = False;
    if isinstance(arg, str) {
        isdig = len(arg) > 0;
        i: int = 0;
        while i < len(arg) {
            c: str = arg[i];
            if c < "0" or c > "9" {
                isdig = False;
            }
            i += 1;
        }
        if isdig {
            pl: int = 0;
            i = 0;
            while i < len(arg) {
                pl = pl * 10 + (ord(arg[i]) - 48);
                i += 1;
            }
            if pl > 128 {
                raise NetmaskValueError(_q(arg) + " is not a valid netmask");
            }
            return pl;
        }
        raise NetmaskValueError(_q(arg) + " is not a valid netmask");
    }
    if isinstance(arg, bytes) {
        isdig = len(arg) > 0;
        i = 0;
        while i < len(arg) {
            if arg[i] < 48 or arg[i] > 57 {
                isdig = False;
            }
            i += 1;
        }
        if not isdig {
            raise NetmaskValueError(_qb(arg) + " is not a valid netmask");
        }
        pl = 0;
        i = 0;
        while i < len(arg) {
            pl = pl * 10 + (arg[i] - 48);
            i += 1;
        }
        if pl > 128 {
            raise NetmaskValueError(_qb(arg) + " is not a valid netmask");
        }
        return pl;
    }
    raise TypeError("IPv6 netmask must be an int or decimal string");
}


def _v6_mask(pl: int) -> list[int] {
    hi: int = 0;
    lo: int = 0;
    if pl >= 64 {
        hi = -1;
        if pl == 64 {
            lo = 0;
        } else {
            lo = -(1 << (128 - pl));
        }
    } elif pl > 0 {
        hi = -(1 << (64 - pl));
        lo = 0;
    }
    out: list[int] = [];
    out.append(hi);
    out.append(lo);
    return out;
}


def _v6_in_net(hi: int, lo: int, net_hi: int, net_lo: int, pl: int) -> bool {
    m: list[int] = _v6_mask(pl);
    return (hi & m[0]) == (net_hi & m[0]) and (lo & m[1]) == (net_lo & m[1]);
}


def _v6_net_from(hi: int, lo: int, prefixlen: int) -> IPv6Network {
    m: list[int] = _v6_mask(prefixlen);
    n: IPv6Network = IPv6Network(0);
    n.network_address = IPv6Address(hi & m[0], lo & m[1]);
    n.netmask = IPv6Address(m[0], m[1]);
    n._prefixlen = prefixlen;
    n._hosts_full = prefixlen >= 127;
    return n;
}


obj:pub IPv6Address {
    has _hi: int = 0,
        _lo: int = 0,
        _scope_id: str = "",
        version: int = 6,
        max_prefixlen: int = 128;

    has exploded: str { getter; }
    has compressed: str { getter; }
    has reverse_pointer: str { getter; }
    has packed: bytes { getter; }
    has ipv4_mapped: (IPv4Address | None) { getter; }
    has sixtofour: (IPv4Address | None) { getter; }
    has _teredo_server: (IPv4Address | None) { getter; }
    has _teredo_client: (IPv4Address | None) { getter; }
    has scope_id: (str | None) { getter; }
    has is_multicast: bool { getter; }
    has is_reserved: bool { getter; }
    has is_link_local: bool { getter; }
    has is_site_local: bool { getter; }
    has is_unspecified: bool { getter; }
    has is_loopback: bool { getter; }
    has is_private: bool { getter; }
    has is_global: bool { getter; }

    def init(address: any, hi: int = -1) {
        if hi >= 0 {
            h0: int = address;
            self._hi = h0;
            self._lo = hi;
            return;
        }
        if isinstance(address, int) {
            v: int = address;
            if v < 0 {
                raise AddressValueError(
                    str(v) + " (< 0) is not permitted as an IPv6 address"
                );
            }
            self._hi = 0;
            self._lo = v;
            return;
        }
        if isinstance(address, bytes) {
            if len(address) != 16 {
                raise AddressValueError(
                    _qb(address)
                        + " (len "
                        + str(len(address))
                        + " != 16) is not permitted as an IPv6 address"
                );
            }
            h: int = 0;
            l: int = 0;
            k: int = 0;
            while k < 8 {
                h = (h << 8) | address[k];
                l = (l << 8) | address[k + 8];
                k += 1;
            }
            self._hi = h;
            self._lo = l;
            return;
        }
        if isinstance(address, str) {
            s: str = address;
            if _find_ch(s, 47) >= 0 {
                raise AddressValueError("Unexpected '/' in " + _q(s));
            }
            pct: int = _find_ch(s, 37);
            if pct >= 0 {
                scope: str = s[pct + 1:len(s)];
                if scope == "" or _find_ch(scope, 37) >= 0 {
                    raise AddressValueError("Invalid IPv6 address: \"" + _q(s) + "\"");
                }
                self._scope_id = scope;
                s = s[0:pct];
            }
            r: list[int] = _v6_parse(s);
            self._hi = r[0];
            self._lo = r[1];
            return;
        }
        raise TypeError("IPv6Address() argument must be a str, int or bytes");
    }

    def __eq__(other: IPv6Address) -> bool {
        return self._hi == other._hi
            and self._lo == other._lo
            and self._scope_id == other._scope_id;
    }

    def __lt__(other: IPv6Address) -> bool {
        if self._hi != other._hi {
            return _u64_lt(self._hi, other._hi);
        }
        return _u64_lt(self._lo, other._lo);
    }

    def __add__(other: int) -> IPv6Address {
        if other == 0 {
            return IPv6Address(self._hi, self._lo);
        }
        if other > 0 {
            r: list[int] = _u64_add(self._lo, other);
            if self._hi == -1 and r[1] == 1 {
                raise AddressValueError(
                    "IPv6 address overflow (>= 2**128) on the native i64 pathway"
                );
            }
            return IPv6Address(self._hi + r[1], r[0]);
        }
        neg: int = -other;
        return self.__sub__(neg);
    }

    def __sub__(other: int) -> IPv6Address {
        if other == 0 {
            return IPv6Address(self._hi, self._lo);
        }
        if other < 0 {
            raise AddressValueError("IPv6 int offset out of the native i64 range");
        }
        if self._hi == 0 and self._lo >= 0 and self._lo < other {
            raise AddressValueError(
                str(self._lo - other) + " (< 0) is not permitted as an IPv6 address"
            );
        }
        r: list[int] = _u64_sub(self._lo, other);
        return IPv6Address(self._hi - r[1], r[0]);
    }

    def __str__ -> str {
        s: str = "";
        if _v6_is_v4mapped(self._hi, self._lo) {
            s = _v6_str_v4mapped(self._lo);
        } else {
            s = _v6_str(self._hi, self._lo);
        }
        if self._scope_id != "" {
            return s + "%" + self._scope_id;
        }
        return s;
    }

    def _is_v4mapped -> bool {
        return _v6_is_v4mapped(self._hi, self._lo);
    }
}


impl IPv6Address.exploded.getter -> str {
    if self._scope_id != "" {
        _v6_parse(self.__str__());
    }
    if _v6_is_v4mapped(self._hi, self._lo) {
        return _v6_exploded(0, (self._lo >> 32) & 4294967295)[0:30]
            + _v4_str(self._lo & 4294967295);
    }
    return _v6_exploded(self._hi, self._lo);
}


impl IPv6Address.compressed.getter -> str {
    return self.__str__();
}


impl IPv6Address.reverse_pointer.getter -> str {
    if self._scope_id != "" {
        _v6_parse(self.__str__());
    }
    if _v6_is_v4mapped(self._hi, self._lo) {
        raw: str = _v6_exploded(0, (self._lo >> 32) & 4294967295)[0:30]
            + _hex8(self._lo & 4294967295);
        return _v6_ptr(raw);
    }
    return _v6_ptr(_v6_exploded(self._hi, self._lo));
}


impl IPv6Address.packed.getter -> bytes {
    out: list[int] = [];
    sh: int = 48;
    while sh >= 0 {
        out.append((self._hi >> sh) & 255);
        sh -= 8;
    }
    sh = 48;
    while sh >= 0 {
        out.append((self._lo >> sh) & 255);
        sh -= 8;
    }
    return bytes(out);
}


impl IPv6Address.ipv4_mapped.getter -> IPv4Address | None {
    if _v6_is_v4mapped(self._hi, self._lo) {
        return IPv4Address(self._lo & 4294967295);
    }
    return None;
}


impl IPv6Address.sixtofour.getter -> IPv4Address | None {
    if ((self._hi >> 48) & 65535) != 8194 {
        return None;
    }
    return IPv4Address((self._hi >> 16) & 4294967295);
}


impl IPv6Address._teredo_server.getter -> IPv4Address | None {
    if ((self._hi >> 32) & 4294967295) != 536936448 {
        return None;
    }
    return IPv4Address(self._hi & 4294967295);
}


impl IPv6Address._teredo_client.getter -> IPv4Address | None {
    if ((self._hi >> 32) & 4294967295) != 536936448 {
        return None;
    }
    return IPv4Address((self._lo ^ -1) & 4294967295);
}


impl IPv6Address.scope_id.getter -> str | None {
    if self._scope_id == "" {
        return None;
    }
    return self._scope_id;
}


impl IPv6Address.is_multicast.getter -> bool {
    if _v6_is_v4mapped(self._hi, self._lo) {
        return IPv4Address(self._lo & 4294967295).is_multicast;
    }
    return _v6_in_net(
        self._hi, self._lo, _V6_MULTICAST[0], _V6_MULTICAST[1], _V6_MULTICAST[2]
    );
}


impl IPv6Address.is_reserved.getter -> bool {
    if _v6_is_v4mapped(self._hi, self._lo) {
        return IPv4Address(self._lo & 4294967295).is_reserved;
    }
    k: int = 0;
    while k < len(_V6_RESERVED_HI) {
        if _v6_in_net(self._hi, self._lo, _V6_RESERVED_HI[k], 0, _V6_RESERVED_PL[k]) {
            return True;
        }
        k += 1;
    }
    return False;
}


impl IPv6Address.is_link_local.getter -> bool {
    if _v6_is_v4mapped(self._hi, self._lo) {
        return IPv4Address(self._lo & 4294967295).is_link_local;
    }
    return _v6_in_net(
        self._hi, self._lo, _V6_LINKLOCAL[0], _V6_LINKLOCAL[1], _V6_LINKLOCAL[2]
    );
}


impl IPv6Address.is_site_local.getter -> bool {
    return _v6_in_net(self._hi, self._lo, 18356672081162141696, 0, 10);
}


impl IPv6Address.is_unspecified.getter -> bool {
    if _v6_is_v4mapped(self._hi, self._lo) {
        return IPv4Address(self._lo & 4294967295).is_unspecified;
    }
    return self._hi == 0 and self._lo == 0;
}


impl IPv6Address.is_loopback.getter -> bool {
    if _v6_is_v4mapped(self._hi, self._lo) {
        return IPv4Address(self._lo & 4294967295).is_loopback;
    }
    return self._hi == 0 and self._lo == 1;
}


impl IPv6Address.is_private.getter -> bool {
    if _v6_is_v4mapped(self._hi, self._lo) {
        return IPv4Address(self._lo & 4294967295).is_private;
    }
    hit: bool = False;
    k: int = 0;
    while k < len(_V6_PRIV_HI) {
        if _v6_in_net(
            self._hi, self._lo, _V6_PRIV_HI[k], _V6_PRIV_LO[k], _V6_PRIV_PL[k]
        ) {
            hit = True;
        }
        k += 1;
    }
    if not hit {
        return False;
    }
    k = 0;
    while k < len(_V6_PRIV_EXC_HI) {
        if _v6_in_net(
            self._hi,
            self._lo,
            _V6_PRIV_EXC_HI[k],
            _V6_PRIV_EXC_LO[k],
            _V6_PRIV_EXC_PL[k]
        ) {
            return False;
        }
        k += 1;
    }
    return True;
}


impl IPv6Address.is_global.getter -> bool {
    if _v6_is_v4mapped(self._hi, self._lo) {
        return IPv4Address(self._lo & 4294967295).is_global;
    }
    return not self.is_private;
}


obj:pub IPv6Network {
    has network_address: IPv6Address,
        netmask: IPv6Address,
        _prefixlen: int = 128,
        _hosts_full: bool = False,
        version: int = 6,
        max_prefixlen: int = 128;

    has prefixlen: int { getter; }
    has hostmask: IPv6Address { getter; }
    has broadcast_address: IPv6Address { getter; }
    has num_addresses: int { getter; }
    has with_prefixlen: str { getter; }
    has with_netmask: str { getter; }
    has with_hostmask: str { getter; }
    has exploded: str { getter; }
    has compressed: str { getter; }
    has reverse_pointer: str { getter; }
    has is_multicast: bool { getter; }
    has is_reserved: bool { getter; }
    has is_link_local: bool { getter; }
    has is_site_local: bool { getter; }
    has is_private: bool { getter; }
    has is_global: bool { getter; }
    has is_unspecified: bool { getter; }
    has is_loopback: bool { getter; }

    def init(address: any, strict: bool = True) {
        addr: any = address;
        mask_arg: any = 128;
        if isinstance(address, tuple) {
            nt: int = len(address);
            if nt == 0 {
                raise IndexError("tuple index out of range");
            }
            if nt > 2 {
                raise ValueError(
                    "too many values to unpack (expected 2, got " + str(nt) + ")"
                );
            }
            addr = address[0];
            if nt > 1 {
                mask_arg = address[1];
            }
        } elif isinstance(address, str) {
            s0: str = address;
            sep: int = _one_slash(s0, s0);
            if sep >= 0 {
                mask_arg = s0[sep + 1:len(s0)];
                addr = s0[0:sep];
            }
        }
        hi: int = 0;
        lo: int = 0;
        scope: str = "";
        if isinstance(addr, int) {
            v: int = addr;
            if v < 0 {
                raise AddressValueError(
                    str(v) + " (< 0) is not permitted as an IPv6 address"
                );
            }
            hi = 0;
            lo = v;
        } elif isinstance(addr, bytes) {
            if len(addr) != 16 {
                raise AddressValueError(
                    _qb(addr)
                        + " (len "
                        + str(len(addr))
                        + " != 16) is not permitted as an IPv6 address"
                );
            }
            h: int = 0;
            l: int = 0;
            k: int = 0;
            while k < 8 {
                h = (h << 8) | addr[k];
                l = (l << 8) | addr[k + 8];
                k += 1;
            }
            hi = h;
            lo = l;
        } elif isinstance(addr, str) {
            s: str = addr;
            pct: int = _find_ch(s, 37);
            if pct >= 0 {
                scope = s[pct + 1:len(s)];
                if scope == "" or _find_ch(scope, 37) >= 0 {
                    raise AddressValueError("Invalid IPv6 address: \"" + _q(s) + "\"");
                }
                s = s[0:pct];
            }
            r: list[int] = _v6_parse(s);
            hi = r[0];
            lo = r[1];
        } else {
            raise TypeError("IPv6Network() argument must be a str, int or bytes");
        }
        pl: int = _v6_netmask(mask_arg);
        m: list[int] = _v6_mask(pl);
        self.network_address = IPv6Address(hi, lo);
        self.network_address._scope_id = scope;
        self.netmask = IPv6Address(m[0], m[1]);
        self._prefixlen = pl;
        if ((hi & m[0]) != hi) or ((lo & m[1]) != lo) {
            if strict {
                raise ValueError(self.__str__() + " has host bits set");
            }
            self.network_address = IPv6Address(hi & m[0], lo & m[1]);
        }
        self._hosts_full = pl >= 127;
    }

    def __str__ -> str {
        return self.network_address.__str__() + "/" + str(self._prefixlen);
    }

    def __eq__(other: IPv6Network) -> bool {
        return self._prefixlen == other._prefixlen
            and self.network_address._hi == other.network_address._hi
            and self.network_address._lo == other.network_address._lo;
    }

    def __contains__(other: IPv6Address) -> bool {
        return _v6_in_net(
            other._hi,
            other._lo,
            self.network_address._hi,
            self.network_address._lo,
            self._prefixlen
        );
    }

    def hosts -> list[IPv6Address] {
        if self.num_addresses > 1048576 {
            raise ValueError(
                "hosts(): network has more than 2**20 addresses; the native hosts() materializes a list and refuses (CPython returns a lazy iterator)"
            );
        }
        out: list[IPv6Address] = [];
        if self._hosts_full {
            out.append(IPv6Address(self.network_address._hi, self.network_address._lo));
            if self._prefixlen == 127 {
                out.append(self.broadcast_address);
            }
            return out;
        }
        cur: list[int] = _v6_add1(self.network_address._hi, self.network_address._lo);
        count: int = self.num_addresses - 2;
        i: int = 0;
        while i < count {
            out.append(IPv6Address(cur[0], cur[1]));
            cur = _v6_add1(cur[0], cur[1]);
            i += 1;
        }
        return out;
    }

    def subnets(
        prefixlen_diff: int = 1, new_prefix: int | None = None
    ) -> list[IPv6Network] {
        if self._prefixlen == 128 {
            out0: list[IPv6Network] = [];
            out0.append(self);
            return out0;
        }
        diff: int = prefixlen_diff;
        if new_prefix is not None {
            if new_prefix < self._prefixlen {
                raise ValueError("new prefix must be longer");
            }
            if prefixlen_diff != 1 {
                raise ValueError("cannot set prefixlen_diff and new_prefix");
            }
            diff = new_prefix - self._prefixlen;
        }
        if diff < 0 {
            raise ValueError("prefix length diff must be > 0");
        }
        new_prefixlen: int = self._prefixlen + diff;
        if new_prefixlen > 128 {
            raise ValueError(
                "prefix length diff "
                    + str(new_prefixlen)
                    + " is invalid for netblock "
                    + self.__str__()
            );
        }
        if diff > 20 {
            raise ValueError(
                "subnets(): refusing to materialize more than 2**20 subnets on native (CPython returns a lazy iterator)"
            );
        }
        count: int = 1 << diff;
        shift: int = 128 - (self._prefixlen + diff);
        step_hi: int = 0;
        step_lo: int = 0;
        if shift == 64 {
            step_hi = 1;
        } elif shift >= 64 {
            step_hi = 1 << (shift - 64);
        } else {
            step_lo = 1 << shift;
        }
        out: list[IPv6Network] = [];
        cur_hi: int = self.network_address._hi;
        cur_lo: int = self.network_address._lo;
        i: int = 0;
        while i < count {
            out.append(_v6_net_from(cur_hi, cur_lo, new_prefixlen));
            if i + 1 < count {
                r: list[int] = _u64_add(cur_lo, step_lo);
                cur_hi = cur_hi + r[1] + step_hi;
                cur_lo = r[0];
            }
            i += 1;
        }
        return out;
    }

    def supernet(
        prefixlen_diff: int = 1, new_prefix: int | None = None
    ) -> IPv6Network {
        if self._prefixlen == 0 {
            return self;
        }
        diff: int = prefixlen_diff;
        if new_prefix is not None {
            if new_prefix > self._prefixlen {
                raise ValueError("new prefix must be shorter");
            }
            if prefixlen_diff != 1 {
                raise ValueError("cannot set prefixlen_diff and new_prefix");
            }
            diff = self._prefixlen - new_prefix;
        }
        new_prefixlen: int = self._prefixlen - diff;
        if new_prefixlen < 0 {
            raise ValueError(
                "current prefixlen is "
                    + str(self._prefixlen)
                    + ", cannot have a prefixlen_diff of "
                    + str(diff)
            );
        }
        return _v6_net_from(
            self.network_address._hi, self.network_address._lo, new_prefixlen
        );
    }
}


impl IPv6Network.prefixlen.getter -> int {
    return self._prefixlen;
}


impl IPv6Network.hostmask.getter -> IPv6Address {
    return IPv6Address(self.netmask._hi ^ -1, self.netmask._lo ^ -1);
}


impl IPv6Network.broadcast_address.getter -> IPv6Address {
    return IPv6Address(
        self.network_address._hi | (self.netmask._hi ^ -1),
        self.network_address._lo | (self.netmask._lo ^ -1)
    );
}


impl IPv6Network.num_addresses.getter -> int {
    if self._prefixlen < 65 {
        raise OverflowError("number of addresses exceeds the 64-bit signed range");
    }
    return 1 << (128 - self._prefixlen);
}


impl IPv6Network.with_prefixlen.getter -> str {
    return self.__str__();
}


impl IPv6Network.with_netmask.getter -> str {
    return _v6_str(self.network_address._hi, self.network_address._lo)
        + "/"
        + _v6_str(self.netmask._hi, self.netmask._lo);
}


impl IPv6Network.with_hostmask.getter -> str {
    return _v6_str(self.network_address._hi, self.network_address._lo)
        + "/"
        + _v6_str(self.netmask._hi ^ -1, self.netmask._lo ^ -1);
}


impl IPv6Network.exploded.getter -> str {
    return _v6_exploded(self.network_address._hi, self.network_address._lo)
        + "/"
        + str(self._prefixlen);
}


impl IPv6Network.compressed.getter -> str {
    return self.__str__();
}


impl IPv6Network.reverse_pointer.getter -> str {
    return _v6_ptr(self.__str__());
}


impl IPv6Network.is_multicast.getter -> bool {
    return self.network_address.is_multicast and self.broadcast_address.is_multicast;
}


impl IPv6Network.is_reserved.getter -> bool {
    return self.network_address.is_reserved and self.broadcast_address.is_reserved;
}


impl IPv6Network.is_link_local.getter -> bool {
    return self.network_address.is_link_local and self.broadcast_address.is_link_local;
}


impl IPv6Network.is_site_local.getter -> bool {
    return self.network_address.is_site_local and self.broadcast_address.is_site_local;
}


impl IPv6Network.is_private.getter -> bool {
    na: IPv6Address = self.network_address;
    ba: IPv6Address = self.broadcast_address;
    hit: bool = False;
    k: int = 0;
    while k < len(_V6_PRIV_HI) {
        if _v6_in_net(na._hi, na._lo, _V6_PRIV_HI[k], _V6_PRIV_LO[k], _V6_PRIV_PL[k])
            and _v6_in_net(
                ba._hi, ba._lo, _V6_PRIV_HI[k], _V6_PRIV_LO[k], _V6_PRIV_PL[k]
            ) {
            hit = True;
        }
        k += 1;
    }
    if not hit {
        return False;
    }
    k = 0;
    while k < len(_V6_PRIV_EXC_HI) {
        if _v6_in_net(
            na._hi, na._lo, _V6_PRIV_EXC_HI[k], _V6_PRIV_EXC_LO[k], _V6_PRIV_EXC_PL[k]
        )
            or _v6_in_net(
                ba._hi,
                ba._lo,
                _V6_PRIV_EXC_HI[k],
                _V6_PRIV_EXC_LO[k],
                _V6_PRIV_EXC_PL[k]
            ) {
            return False;
        }
        k += 1;
    }
    return True;
}


impl IPv6Network.is_global.getter -> bool {
    return not self.is_private;
}


impl IPv6Network.is_unspecified.getter -> bool {
    return self.network_address.is_unspecified
        and self.broadcast_address.is_unspecified;
}


impl IPv6Network.is_loopback.getter -> bool {
    return self.network_address.is_loopback and self.broadcast_address.is_loopback;
}


obj:pub IPv6Interface {
    has _hi: int = 0,
        _lo: int = 0,
        _prefixlen: int = 128;

    def init(address: any) {
        if isinstance(address, int) {
            v: int = address;
            if v < 0 {
                raise AddressValueError(
                    str(v) + " (< 0) is not permitted as an IPv6 address"
                );
            }
            self._hi = 0;
            self._lo = v;
            self._prefixlen = 128;
            return;
        }
        if isinstance(address, bytes) {
            if len(address) != 16 {
                raise AddressValueError(
                    _qb(address)
                        + " (len "
                        + str(len(address))
                        + " != 16) is not permitted as an IPv6 address"
                );
            }
            h: int = 0;
            l: int = 0;
            k: int = 0;
            while k < 8 {
                h = (h << 8) | address[k];
                l = (l << 8) | address[k + 8];
                k += 1;
            }
            self._hi = h;
            self._lo = l;
            self._prefixlen = 128;
            return;
        }
        if isinstance(address, str) {
            s: str = address;
            sep: int = -1;
            k: int = len(s) - 1;
            while k >= 0 {
                if s[k] == "/" {
                    sep = k;
                    k = -1;
                }
                k -= 1;
            }
            if sep >= 0 {
                ms: str = s[sep + 1:len(s)];
                isdig: bool = len(ms) > 0;
                i: int = 0;
                while i < len(ms) {
                    c: str = ms[i];
                    if c < "0" or c > "9" {
                        isdig = False;
                    }
                    i += 1;
                }
                if not isdig {
                    raise NetmaskValueError(_q(ms) + " is not a valid netmask");
                }
                self._prefixlen = 0;
                i = 0;
                while i < len(ms) {
                    self._prefixlen = self._prefixlen * 10 + (ord(ms[i]) - 48);
                    i += 1;
                }
                if self._prefixlen > 128 {
                    raise NetmaskValueError(_q(ms) + " is not a valid netmask");
                }
                s = s[0:sep];
            } else {
                self._prefixlen = 128;
            }
            r: list[int] = _v6_parse(s);
            self._hi = r[0];
            self._lo = r[1];
            return;
        }
        raise TypeError("IPv6Interface() argument must be a str, int or bytes");
    }

    def ip -> IPv6Address {
        return IPv6Address(self._hi, self._lo);
    }

    def network -> IPv6Network {
        return _v6_net_from(self._hi, self._lo, self._prefixlen);
    }

    def netmask -> IPv6Address {
        m: list[int] = _v6_mask(self._prefixlen);
        return IPv6Address(m[0], m[1]);
    }

    def hostmask -> IPv6Address {
        m: list[int] = _v6_mask(self._prefixlen);
        return IPv6Address(m[0] ^ -1, m[1] ^ -1);
    }

    def with_prefixlen -> str {
        return self.ip().__str__() + "/" + str(self._prefixlen);
    }

    def __str__ -> str {
        return self.with_prefixlen();
    }

    def __eq__(other: IPv6Interface) -> bool {
        return self._hi == other._hi
            and self._lo == other._lo
            and self._prefixlen == other._prefixlen;
    }
}


def:pub ip_address(address: any) -> any {
    try {
        return IPv4Address(address);
    } except AddressValueError {
        _ignore = 0;
    } except NetmaskValueError {
        _ignore = 0;
    } except ValueError {
        _ignore = 0;
    }
    try {
        return IPv6Address(address);
    } except AddressValueError {
        _ignore = 0;
    } except NetmaskValueError {
        _ignore = 0;
    } except ValueError {
        _ignore = 0;
    }
    raise ValueError(
        _arg_repr(address) + " does not appear to be an IPv4 or IPv6 address"
    );
}


def:pub ip_network(address: any, strict: bool = True) -> any {
    try {
        return IPv4Network(address, strict);
    } except AddressValueError {
        _ignore = 0;
    } except NetmaskValueError {
        _ignore = 0;
    } except ValueError {
        _ignore = 0;
    }
    try {
        return IPv6Network(address, strict);
    } except AddressValueError {
        _ignore = 0;
    } except NetmaskValueError {
        _ignore = 0;
    } except ValueError {
        _ignore = 0;
    }
    raise ValueError(
        _arg_repr(address) + " does not appear to be an IPv4 or IPv6 network"
    );
}


def:pub ip_interface(address: any) -> any {
    try {
        return IPv4Interface(address);
    } except AddressValueError {
        _ignore = 0;
    } except NetmaskValueError {
        _ignore = 0;
    } except ValueError {
        _ignore = 0;
    }
    try {
        return IPv6Interface(address);
    } except AddressValueError {
        _ignore = 0;
    } except NetmaskValueError {
        _ignore = 0;
    } except ValueError {
        _ignore = 0;
    }
    raise ValueError(
        _arg_repr(address) + " does not appear to be an IPv4 or IPv6 interface"
    );
}
