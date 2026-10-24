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


def _v4_priv(ip: int) -> bool;


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
