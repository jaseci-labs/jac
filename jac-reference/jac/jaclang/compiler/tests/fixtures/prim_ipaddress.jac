"""Bundled native `ipaddress` cross-backend equivalence fixture (#6978).

The same `import ipaddress` binds CPython's pure-Python `ipaddress` on the sv
backend and `na_stdlib/ipaddress.jac` on the na (native LLVM) backend. Pins the
v4/v6 address and network surfaces that are representable on both: text round
trips, ordering, netmask/hostmask/prefixlen/num_addresses, membership, the
`is_*` predicate family, `reverse_pointer`, host enumeration, and the
`AddressValueError`/`NetmaskValueError` messages (both ValueError subclasses on
each lane, so the fixture compares `str(e)`). IPv6 addresses are an unsigned
128-bit (hi, lo) pair natively, so no `.int` key is pinned.

The concrete classes -- not the `ip_address`/`ip_network` factories -- carry the
work, because a factory returns a union that erases to `any`, and `a in net`
over an `any` operand is E1124 on the native pathway (there is no layout to
answer the membership test from). `__contains__`/`__lt__` are spelled out for
the same reason. The `ip_address`/`ip_network`/`ip_interface` factories return a union that
erases to `any`, which neither `in` nor `str()` can dispatch on natively, so they
are covered by the module's own docs rather than pinned here. The bad-address arm
catches `ipaddress.AddressValueError` by its exact class: a parent-class arm does
not catch a module-defined subclass on the ctypes-JIT path (jaseci-labs/jac#9380),
so `except Exception` would let the raise escape and abort the JIT with no
diagnostic. The host-bits case is a genuine builtin `ValueError` on both lanes.
ES/JS opts out.
"""

import ipaddress;


def ipaddress_py -> dict[any, any] {
    a = ipaddress.IPv4Address("192.168.0.1");
    b = ipaddress.IPv4Address("10.0.0.255");
    net = ipaddress.IPv4Network("192.168.0.0/24");
    small = ipaddress.IPv4Network("192.168.0.0/30");
    v6 = ipaddress.IPv6Address("2001:db8::1");
    v6net = ipaddress.IPv6Network("2001:db8::/32");
    iface = ipaddress.IPv4Interface("192.168.0.5/24");
    loop = ipaddress.IPv4Address("127.0.0.1");
    mcast = ipaddress.IPv4Address("224.0.0.1");
    hosts = 0;
    for h in small.hosts() {
        hosts += 1;
    }
    bad = "";
    try {
        ipaddress.IPv4Address("300.1.1.1");
    } except ipaddress.AddressValueError as e {
        bad = str(e);
    }
    badnet = "";
    try {
        ipaddress.IPv4Network("192.168.0.1/24");
    } except ValueError as e {
        badnet = str(e);
    }
    return {
        "a_str": str(a),
        "a_ver": a.version,
        "b_str": str(b),
        "cmp_lt": 1 if b.__lt__(a) else 0,
        "net_str": str(net),
        "net_netmask": str(net.netmask),
        "net_hostmask": str(net.hostmask),
        "net_prefixlen": net.prefixlen,
        "net_num": net.num_addresses,
        "net_first": str(net.network_address),
        "net_last": str(net.broadcast_address),
        "contains": 1 if net.__contains__(a) else 0,
        "not_contains": 1 if net.__contains__(b) else 0,
        "small_hosts": hosts,
        "v6_str": str(v6),
        "v6_ver": v6.version,
        "v6net_str": str(v6net),
        "v6net_prefixlen": v6net.prefixlen,
        "iface_str": str(iface),
        "iface_net": str(iface.network),
        "loop_is_loopback": 1 if loop.is_loopback else 0,
        "loop_is_private": 1 if loop.is_private else 0,
        "mcast_is_multicast": 1 if mcast.is_multicast else 0,
        "a_is_private": 1 if a.is_private else 0,
        "a_is_global": 1 if a.is_global else 0,
        "rev": a.reverse_pointer,
        "bad": bad,
        "badnet": badnet,

    };
}


def ipaddress_cl -> dict[any, any] {
    return {};
}


def ipaddress_na -> dict[str, any] {
    a = ipaddress.IPv4Address("192.168.0.1");
    b = ipaddress.IPv4Address("10.0.0.255");
    net = ipaddress.IPv4Network("192.168.0.0/24");
    small = ipaddress.IPv4Network("192.168.0.0/30");
    v6 = ipaddress.IPv6Address("2001:db8::1");
    v6net = ipaddress.IPv6Network("2001:db8::/32");
    iface = ipaddress.IPv4Interface("192.168.0.5/24");
    loop = ipaddress.IPv4Address("127.0.0.1");
    mcast = ipaddress.IPv4Address("224.0.0.1");
    hosts = 0;
    for h in small.hosts() {
        hosts += 1;
    }
    bad = "";
    try {
        ipaddress.IPv4Address("300.1.1.1");
    } except ipaddress.AddressValueError as e {
        bad = str(e);
    }
    badnet = "";
    try {
        ipaddress.IPv4Network("192.168.0.1/24");
    } except ValueError as e {
        badnet = str(e);
    }
    return {
        "a_str": str(a),
        "a_ver": a.version,
        "b_str": str(b),
        "cmp_lt": 1 if b.__lt__(a) else 0,
        "net_str": str(net),
        "net_netmask": str(net.netmask),
        "net_hostmask": str(net.hostmask),
        "net_prefixlen": net.prefixlen,
        "net_num": net.num_addresses,
        "net_first": str(net.network_address),
        "net_last": str(net.broadcast_address),
        "contains": 1 if net.__contains__(a) else 0,
        "not_contains": 1 if net.__contains__(b) else 0,
        "small_hosts": hosts,
        "v6_str": str(v6),
        "v6_ver": v6.version,
        "v6net_str": str(v6net),
        "v6net_prefixlen": v6net.prefixlen,
        "iface_str": str(iface),
        "iface_net": str(iface.network),
        "loop_is_loopback": 1 if loop.is_loopback else 0,
        "loop_is_private": 1 if loop.is_private else 0,
        "mcast_is_multicast": 1 if mcast.is_multicast else 0,
        "a_is_private": 1 if a.is_private else 0,
        "a_is_global": 1 if a.is_global else 0,
        "rev": a.reverse_pointer,
        "bad": bad,
        "badnet": badnet,

    };
}
