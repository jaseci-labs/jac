"""
node:dns native bridge — OS resolver (getaddrinfo / getnameinfo) and shared DNS state.

Exposed as globalThis.__dns; JS layer: src/builtins/js/dns.js
"""

import from engine.src.ffi.libc {
    calloc,
    free,
    getaddrinfo,
    freeaddrinfo,
    getnameinfo,
    gai_strerror,
    inet_pton,
    inet_ntop,
    get_errno
}
import from engine.src.net.constants { AF_INET, AF_INET6 }
import from engine.src.runtime.mem {
    io_alloc,
    read_i32,
    read_u32,
    read_u16,
    read_ptr,
    write_i32,
    write_byte
}

def _dns_write_u16(ptr: int, off: int, value: int) {
    write_byte(ptr, off, value & 255);
    write_byte(ptr, off + 1, (value // 256) & 255);
}

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_null,
    js_int,
    js_true,
    js_false,
    jsv_from_string_id,
    jsv_is_string_cell,
    jsv_is_int32,
    jsv_is_object_cell,
    jsv_is_undefined,
    jsv_to_int32,
    jsv_to_table_id
}
import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_set,
    js_object_get
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.builtins.array {
    js_array_create,
    js_array_len,
    js_array_get,
    js_is_array
}
import from engine.src.builtins.dns_wire {
    dns_wire_load_resolv_conf,
    dns_wire_query,
    dns_wire_qtype_a,
    dns_wire_qtype_aaaa,
    dns_wire_qtype_ptr,
    dns_wire_qtype_cname,
    dns_wire_qtype_mx,
    dns_wire_qtype_ns,
    dns_wire_qtype_txt,
    dns_wire_qtype_soa,
    dns_wire_qtype_srv,
    dns_wire_qtype_naptr,
    dns_wire_qtype_caa
}

# struct addrinfo (x86_64 Linux)
glob:priv _DNS_AI_FLAGS: int = 0,
     _DNS_AI_FAMILY: int = 4,
     _DNS_AI_SOCKTYPE: int = 8,
     _DNS_AI_PROTOCOL: int = 12,
     _DNS_AI_ADDRLEN: int = 16,
     _DNS_AI_ADDR: int = 24,
     _DNS_AI_NEXT: int = 40,
     _DNS_SIN_FAMILY: int = 0,
     _DNS_SIN_PORT: int = 2,
     _DNS_SIN_ADDR: int = 4,
     _DNS_SIN6_FAMILY: int = 0,
     _DNS_SIN6_ADDR: int = 8,
     _DNS_INET_STRLEN: int = 16,
     _DNS_INET6_STRLEN: int = 46,
     _DNS_SS_SIZE: int = 128,
     _DNS_NI_NUMERICHOST: int = 1,
     _DNS_NI_NUMERICSERV: int = 2,
     _DNS_NI_NAMEREQD: int = 4,
     _DNS_DEFAULT_ORDER: str = "verbatim";

# getnameinfo flags
glob _dns_servers: list[str] = [],
     _dns_query_in_progress: bool = False,
     _dns_resolv_loaded: bool = False;

def _dns_ensure_resolv -> None {
    if _dns_resolv_loaded {
        return;
    }
    if len(_dns_servers) == 0 {
        _dns_servers = dns_wire_load_resolv_conf();
    }
    _dns_resolv_loaded = True;
}

def _dns_servers_from_js(servers_val: JSValue) -> list[str] {
    _dns_ensure_resolv();
    if jsv_is_undefined(servers_val) {
        return _dns_servers;
    }
    if js_is_array(servers_val) {
        out: list[str] = [];
        n: int = js_array_len(servers_val);
        si: int = 0;
        while si < n {
            sv: JSValue = js_array_get(servers_val, si);
            if jsv_is_string_cell(sv) {
                out.append(str_from_id(jsv_to_table_id(sv)));
            }
            si = si + 1;
        }
        if len(out) > 0 {
            return out;
        }
    }
    return _dns_servers;
}

def _dns_host_from_val(host_val: JSValue) -> str {
    if jsv_is_string_cell(host_val) {
        return str_from_id(jsv_to_table_id(host_val));
    }
    return "";
}

def:pub dns_wire_resolve(
    host_val: JSValue, qtype: int, servers_val: JSValue
) -> JSValue {
    host: str = _dns_host_from_val(host_val);
    if len(host) == 0 {
        err: JSValue = js_object_create_null();
        js_object_set(
            err,
            str_intern("code"),
            jsv_from_string_id(str_intern("ERR_INVALID_ARG_TYPE"))
        );
        return err;
    }
    servers: list[str] = _dns_servers_from_js(servers_val);
    _dns_query_in_progress = True;
    res: JSValue = dns_wire_query(host, qtype, servers);
    _dns_query_in_progress = False;
    return res;
}

def:pub dns_get_default_result_order -> str {
    return _DNS_DEFAULT_ORDER;
}

def:pub dns_set_default_result_order(order: str) {
    if order == "ipv4first" or order == "ipv6first" or order == "verbatim" {
        _DNS_DEFAULT_ORDER = order;
    }
}

def:pub dns_get_servers -> list[str] {
    _dns_ensure_resolv();
    return _dns_servers;
}

def:pub dns_set_servers(servers: list[str]) {
    _dns_servers = servers;
    _dns_resolv_loaded = True;
}

def:pub dns_set_servers_js(servers_val: JSValue) -> JSValue {
    if _dns_query_in_progress {
        err: JSValue = js_object_create_null();
        js_object_set(
            err,
            str_intern("code"),
            jsv_from_string_id(str_intern("ERR_DNS_SET_SERVERS_FAILED"))
        );
        return err;
    }
    if not js_is_array(servers_val) {
        err2: JSValue = js_object_create_null();
        js_object_set(
            err2,
            str_intern("code"),
            jsv_from_string_id(str_intern("ERR_INVALID_ARG_TYPE"))
        );
        return err2;
    }
    next: list[str] = [];
    n: int = js_array_len(servers_val);
    si: int = 0;
    while si < n {
        sv: JSValue = js_array_get(servers_val, si);
        if jsv_is_string_cell(sv) {
            next.append(str_from_id(jsv_to_table_id(sv)));
        }
        si = si + 1;
    }
    _dns_servers = next;
    ok: JSValue = js_object_create_null();
    js_object_set(ok, str_intern("ok"), js_true());
    return ok;
}

def:pub dns_get_servers_js -> JSValue {
    elems: list[JSValue] = [];
    si2: int = 0;
    while si2 < len(_dns_servers) {
        elems.append(jsv_from_string_id(str_intern(_dns_servers[si2])));
        si2 = si2 + 1;
    }
    return js_array_create(elems);
}

def:pub dns_begin_query {
    _dns_query_in_progress = True;
}

def:pub dns_end_query {
    _dns_query_in_progress = False;
}

def:pub dns_query_in_progress -> bool {
    return _dns_query_in_progress;
}

def _dns_int_to_str(n: int) -> str {
    if n == 0 {
        return "0";
    }
    result: str = "";
    rem: int = n;
    while rem > 0 {
        d: int = rem - (rem // 10) * 10;
        if d == 0 {
            result = "0" + result;
        } elif d == 1 {
            result = "1" + result;
        } elif d == 2 {
            result = "2" + result;
        } elif d == 3 {
            result = "3" + result;
        } elif d == 4 {
            result = "4" + result;
        } elif d == 5 {
            result = "5" + result;
        } elif d == 6 {
            result = "6" + result;
        } elif d == 7 {
            result = "7" + result;
        } elif d == 8 {
            result = "8" + result;
        } else {
            result = "9" + result;
        }
        rem = rem // 10;
    }
    return result;
}

def _dns_is_ipv4(host: str) -> bool {
    parts: list[str] = [];
    i: int = 0;
    cur: str = "";
    while i < len(host) {
        c: str = host[i];
        if c == "." {
            parts.append(cur);
            cur = "";
        } else {
            cur = cur + c;
        }
        i = i + 1;
    }
    parts.append(cur);
    if len(parts) != 4 {
        return False;
    }
    pi: int = 0;
    while pi < 4 {
        p: str = parts[pi];
        if len(p) == 0 {
            return False;
        }
        n: int = 0;
        j: int = 0;
        while j < len(p) {
            ch: str = p[j];
            if ch < "0" or ch > "9" {
                return False;
            }
            n = n * 10 + (ord(ch) - 48);
            j = j + 1;
        }
        if n < 0 or n > 255 {
            return False;
        }
        if _dns_int_to_str(n) != p {
            return False;
        }
        pi = pi + 1;
    }
    return True;
}

def _dns_normalize_host(host: str) -> str {
    h: str = host;
    if len(h) >= 2 and h[0] == "[" and h[len(h) - 1] == "]" {
        h = h[1:len(h) - 1];
    }
    return h;
}

def _dns_has_colon(s: str) -> bool {
    i: int = 0;
    while i < len(s) {
        if s[i] == ":" {
            return True;
        }
        i = i + 1;
    }
    return False;
}

def _dns_extract_ip(addr_ptr: int, fam: int) -> str {
    if addr_ptr == 0 {
        return "";
    }
    if fam == AF_INET {
        buf: int = io_alloc(_DNS_INET_STRLEN + 1);
        return inet_ntop(AF_INET, addr_ptr + _DNS_SIN_ADDR, buf, _DNS_INET_STRLEN);
    }
    if fam == AF_INET6 {
        buf6: int = io_alloc(_DNS_INET6_STRLEN + 1);
        return inet_ntop(AF_INET6, addr_ptr + _DNS_SIN6_ADDR, buf6, _DNS_INET6_STRLEN);
    }
    return "";
}

def _dns_collect_getaddrinfo(host: str, ai_family: int, ai_flags: int) -> JSValue {
    hints: int = calloc(1, 48);
    write_i32(hints, _DNS_AI_FLAGS, ai_flags);
    write_i32(hints, _DNS_AI_FAMILY, ai_family);
    write_i32(hints, _DNS_AI_SOCKTYPE, 0);
    write_i32(hints, _DNS_AI_PROTOCOL, 0);

    result_pp: int = calloc(1, 8);
    rc: int = getaddrinfo(host, "", hints, result_pp);
    free(hints);
    if rc != 0 {
        err_obj: JSValue = js_object_create_null();
        js_object_set(
            err_obj, str_intern("code"), jsv_from_string_id(str_intern("ENOTFOUND"))
        );
        js_object_set(err_obj, str_intern("errno"), js_int(0 - 3008));
        js_object_set(
            err_obj,
            str_intern("syscall"),
            jsv_from_string_id(str_intern("getaddrinfo"))
        );
        js_object_set(
            err_obj, str_intern("hostname"), jsv_from_string_id(str_intern(host))
        );
        js_object_set(
            err_obj,
            str_intern("message"),
            jsv_from_string_id(str_intern("getaddrinfo ENOTFOUND " + host))
        );
        return err_obj;
    }

    entries: list[JSValue] = [];
    cur: int = read_ptr(result_pp, 0);
    while cur != 0 {
        fam: int = read_i32(cur, _DNS_AI_FAMILY);
        addr_ptr: int = read_ptr(cur, _DNS_AI_ADDR);
        sa: str = "";
        if addr_ptr != 0 {
            sa = _dns_extract_ip(addr_ptr, fam);
        }
        fam_out: int = 4;
        if fam == AF_INET6 {
            fam_out = 6;
        }
        ent: JSValue = js_object_create_null();
        js_object_set(ent, str_intern("address"), jsv_from_string_id(str_intern(sa)));
        js_object_set(ent, str_intern("family"), js_int(fam_out));
        entries.append(ent);
        cur = read_ptr(cur, _DNS_AI_NEXT);
    }
    freeaddrinfo(read_ptr(result_pp, 0));

    ok: JSValue = js_object_create_null();
    js_object_set(ok, str_intern("ok"), js_true());
    js_object_set(ok, str_intern("entries"), js_array_create(entries));
    return ok;
}

"""Lookup host via getaddrinfo. opts: family (0/4/6), hints (int), order (str)."""
def:pub dns_lookup(host_val: JSValue, family: int, hints: int, order: str) -> JSValue {
    host: str = "";
    if jsv_is_string_cell(host_val) {
        host = str_from_id(jsv_to_table_id(host_val));
    } else {
        err: JSValue = js_object_create_null();
        js_object_set(
            err,
            str_intern("code"),
            jsv_from_string_id(str_intern("ERR_INVALID_ARG_TYPE"))
        );
        return err;
    }
    h: str = _dns_normalize_host(host);
    lower: str = h;
    # fast paths
    if lower == "localhost" {
        entries: list[JSValue] = [];
        if family == 6 {
            ent6: JSValue = js_object_create_null();
            js_object_set(
                ent6, str_intern("address"), jsv_from_string_id(str_intern("::1"))
            );
            js_object_set(ent6, str_intern("family"), js_int(6));
            entries.append(ent6);
        } elif family == 4 {
            ent4: JSValue = js_object_create_null();
            js_object_set(
                ent4, str_intern("address"), jsv_from_string_id(str_intern("127.0.0.1"))
            );
            js_object_set(ent4, str_intern("family"), js_int(4));
            entries.append(ent4);
        } else {
            ent4b: JSValue = js_object_create_null();
            js_object_set(
                ent4b,
                str_intern("address"),
                jsv_from_string_id(str_intern("127.0.0.1"))
            );
            js_object_set(ent4b, str_intern("family"), js_int(4));
            entries.append(ent4b);
            ent6b: JSValue = js_object_create_null();
            js_object_set(
                ent6b, str_intern("address"), jsv_from_string_id(str_intern("::1"))
            );
            js_object_set(ent6b, str_intern("family"), js_int(6));
            entries.append(ent6b);
        }
        ok: JSValue = js_object_create_null();
        js_object_set(ok, str_intern("ok"), js_true());
        js_object_set(ok, str_intern("entries"), js_array_create(entries));
        return ok;
    }
    if _dns_is_ipv4(h) {
        ent2: JSValue = js_object_create_null();
        js_object_set(ent2, str_intern("address"), jsv_from_string_id(str_intern(h)));
        js_object_set(ent2, str_intern("family"), js_int(4));
        ok2: JSValue = js_object_create_null();
        js_object_set(ok2, str_intern("ok"), js_true());
        js_object_set(ok2, str_intern("entries"), js_array_create([ent2]));
        return ok2;
    }
    if lower == "::1" {
        ent3: JSValue = js_object_create_null();
        js_object_set(
            ent3, str_intern("address"), jsv_from_string_id(str_intern("::1"))
        );
        js_object_set(ent3, str_intern("family"), js_int(6));
        ok3: JSValue = js_object_create_null();
        js_object_set(ok3, str_intern("ok"), js_true());
        js_object_set(ok3, str_intern("entries"), js_array_create([ent3]));
        return ok3;
    }

    ai_family: int = 0;
    if family == 4 {
        ai_family = AF_INET;
    } elif family == 6 {
        ai_family = AF_INET6;
    }

    res: JSValue = _dns_collect_getaddrinfo(h, ai_family, hints);
    return res;
}

def:pub dns_reverse(ip_val: JSValue, servers_val: JSValue) -> JSValue {
    wire: JSValue = dns_wire_reverse(ip_val, servers_val);
    return wire;
}

def:pub dns_lookup_service(address_val: JSValue, port_val: JSValue) -> JSValue {
    ip: str = "";
    port: int = 0;
    if jsv_is_string_cell(address_val) {
        ip = str_from_id(jsv_to_table_id(address_val));
    }
    if jsv_is_int32(port_val) {
        port = jsv_to_int32(port_val);
    }
    ip = _dns_normalize_host(ip);
    af: int = AF_INET;
    if _dns_has_colon(ip) {
        af = AF_INET6;
    }
    sa: int = calloc(1, _DNS_SS_SIZE);
    if af == AF_INET {
        inet_pton(AF_INET, ip, sa + 4);
        _dns_write_u16(sa, 0, AF_INET);
        _dns_write_u16(sa, 2, 0);
    } else {
        inet_pton(AF_INET6, ip, sa + 8);
        _dns_write_u16(sa, 0, AF_INET6);
    }
    hostbuf: int = io_alloc(256);
    servbuf: int = io_alloc(32);
    rc: int = getnameinfo(sa, 28, hostbuf, 255, servbuf, 31, _DNS_NI_NUMERICSERV);
    if rc != 0 {
        err: JSValue = js_object_create_null();
        js_object_set(
            err, str_intern("code"), jsv_from_string_id(str_intern("ENOTFOUND"))
        );
        return err;
    }
    ok: JSValue = js_object_create_null();
    js_object_set(ok, str_intern("ok"), js_true());
    js_object_set(ok, str_intern("hostname"), jsv_from_string_id(str_intern(hostbuf)));  # jac:ignore[E1053] pointer reinterpret
    js_object_set(ok, str_intern("service"), jsv_from_string_id(str_intern(servbuf)));  # jac:ignore[E1053] pointer reinterpret
    return ok;
}

def:pub dns_resolve4(host_val: JSValue, servers_val: JSValue) -> JSValue {
    return dns_wire_resolve(host_val, dns_wire_qtype_a(), servers_val);
}

def:pub dns_resolve6(host_val: JSValue, servers_val: JSValue) -> JSValue {
    return dns_wire_resolve(host_val, dns_wire_qtype_aaaa(), servers_val);
}

def:pub dns_wire_reverse(host_val: JSValue, servers_val: JSValue) -> JSValue {
    return dns_wire_resolve(host_val, dns_wire_qtype_ptr(), servers_val);
}
