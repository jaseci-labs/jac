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
         -288230376151711744,
         -108086391056891904
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
         -9223372036854775808,
         -6917529027641081856,
         -4611686018427387904,
         -2305843009213693952,
         -1152921504606846976,
         -576460752303423488,
         -144115188075855872
     ];
glob _V6_RESERVED_PL: list[int] = [8, 8, 7, 6, 5, 4, 3, 3, 3, 3, 3, 4, 5, 6, 9];
glob _V6_LINKLOCAL: list[int] = [-108086391056891904, 0, 10];
glob _V6_MULTICAST: list[int] = [-72057594037927936, 0, 8];

glob _HEXD: str = "0123456789abcdef",
     _PRINTABLE: str = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";


def _q(s: str) -> str;


def _qb(b: bytes) -> str;


def _arg_repr(address: any) -> str;


def _hexx(v: int) -> str;


def _hex4(v: int) -> str;


def _find_ch(s: str, code: int) -> int;


def _split_max(s: str, sep: str, maxsplit: int) -> list[str];


def _ctz32(v: int) -> int;


def _v4_prefix_mask(prefixlen: int) -> int;


def _v4_in(ip: int, net: int, pl: int) -> bool;


def _v4_parse_octet(octet: str) -> int;


def _v4_parse(s: str) -> int;


def _v4_str(ip: int) -> str;


def _v4_ptr(s: str) -> str;


def _one_slash(s: str, orig: str) -> int;


def _v4_make_netmask_int(prefixlen: int) -> list[int];


def _v4_make_netmask_str(arg: str) -> list[int];


def _v4_make_netmask(arg: any) -> list[int];


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

    def init(address: any);
    def __eq__(other: IPv4Address) -> bool;
    def __lt__(other: IPv4Address) -> bool;
    def __add__(other: int) -> IPv4Address;
    def __sub__(other: int) -> IPv4Address;
    def __str__ -> str;
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


def _v4_priv(ip: int) -> bool;


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


def _v4_network_from(ip: int, prefixlen: int) -> IPv4Network;


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

    def init(address: any, strict: bool = True);
    def __str__ -> str;
    def __eq__(other: IPv4Network) -> bool;
    def __lt__(other: IPv4Network) -> bool;
    def __contains__(other: IPv4Address) -> bool;
    def hosts -> list[IPv4Address];
    def subnets(
        prefixlen_diff: int = 1, new_prefix: int | None = None
    ) -> list[IPv4Network];

    def supernet(
        prefixlen_diff: int = 1, new_prefix: int | None = None
    ) -> IPv4Network;

    def overlaps(other: IPv4Network) -> bool;
    def subnet_of(other: IPv4Network) -> bool;
    def supernet_of(other: IPv4Network) -> bool;
    def compare_networks(other: IPv4Network) -> int;
    def address_exclude(other: IPv4Network) -> list[IPv4Network];
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

    def init(address: any);
    def __str__ -> str;
    def __eq__(other: IPv4Interface) -> bool;
    def __lt__(other: IPv4Interface) -> bool;
    def __contains__(other: IPv4Address) -> bool;
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


def _v6_hextet(hextet: str, full: str) -> int;


def _v6_parse(s: str) -> list[int];


def _u64_lt(a: int, b: int) -> bool;


def _u64_add(a: int, other: int) -> list[int];


def _u64_sub(a: int, other: int) -> list[int];


def _v6_add1(hi: int, lo: int) -> list[int];


def _v6_compress(parts: list[str]) -> list[str];


def _v6_join(parts: list[str]) -> str;


def _v6_str_hextets(hi: int, lo: int) -> list[str];


def _v6_str(hi: int, lo: int) -> str;


def _v6_exploded(hi: int, lo: int) -> str;


def _v6_str_v4mapped(lo: int) -> str;


def _v6_is_v4mapped(hi: int, lo: int) -> bool;


def _hex8(v: int) -> str;


def _v6_ptr(s: str) -> str;


def _v6_netmask(arg: any) -> int;


def _v6_mask(pl: int) -> list[int];


def _v6_in_net(hi: int, lo: int, net_hi: int, net_lo: int, pl: int) -> bool;


def _v6_net_from(hi: int, lo: int, prefixlen: int) -> IPv6Network;


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

    def init(address: any, hi: int = -1);
    def __eq__(other: IPv6Address) -> bool;
    def __lt__(other: IPv6Address) -> bool;
    def __add__(other: int) -> IPv6Address;
    def __sub__(other: int) -> IPv6Address;
    def __str__ -> str;
    def _is_v4mapped -> bool;
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
    return _v6_in_net(self._hi, self._lo, -90071992547409920, 0, 10);
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

    def init(address: any, strict: bool = True);
    def __str__ -> str;
    def __eq__(other: IPv6Network) -> bool;
    def __contains__(other: IPv6Address) -> bool;
    def hosts -> list[IPv6Address];
    def subnets(
        prefixlen_diff: int = 1, new_prefix: int | None = None
    ) -> list[IPv6Network];

    def supernet(
        prefixlen_diff: int = 1, new_prefix: int | None = None
    ) -> IPv6Network;
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

    def init(address: any);
    def ip -> IPv6Address;
    def network -> IPv6Network;
    def netmask -> IPv6Address;
    def hostmask -> IPv6Address;
    def with_prefixlen -> str;
    def __str__ -> str;
    def __eq__(other: IPv6Interface) -> bool;
}


def:pub ip_address(address: any) -> any;


def:pub ip_network(address: any, strict: bool = True) -> any;


def:pub ip_interface(address: any) -> any;
