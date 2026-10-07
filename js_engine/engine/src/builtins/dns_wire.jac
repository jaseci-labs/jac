"""
DNS wire-format queries (UDP port 53) for node:dns resolve* / reverse parity.
"""

import from engine.src.ffi.libc { fopen, fread, fclose, calloc, setsockopt, recv }
import from engine.src.net.udp_socket {
    udp_create,
    udp_send_bytes,
    udp_recv,
    udp_close,
    UDPSocket
}
import from engine.src.net.tcp_socket {
    tcp_connect,
    tcp_write_bytes,
    tcp_close,
    TCPSocket
}
import from engine.src.net.constants { SOL_SOCKET, SO_RCVTIMEO }
import from engine.src.runtime.mem {
    io_alloc,
    read_byte,
    write_byte,
    write_i32,
    write_i64,
    byte_chr
}
import from engine.src.runtime.jsvalue {
    JSValue,
    js_true,
    js_false,
    js_int,
    jsv_from_string_id,
    jsv_is_string_cell,
    jsv_to_table_id
}
import from engine.src.runtime.jsobject { js_object_create_null, js_object_set }
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.builtins.array { js_array_create }

glob:priv _QTYPE_A: int = 1,
     _QTYPE_NS: int = 2,
     _QTYPE_CNAME: int = 5,
     _QTYPE_SOA: int = 6,
     _QTYPE_PTR: int = 12,
     _QTYPE_MX: int = 15,
     _QTYPE_TXT: int = 16,
     _QTYPE_AAAA: int = 28,
     _QTYPE_SRV: int = 33,
     _QTYPE_NAPTR: int = 35,
     _QTYPE_CAA: int = 257,
     _DNS_CLASS_IN: int = 1;

glob _wire_query_id: int = 1;
glob:priv _dw_query_pkt_ptr: int = 0,
     _dw_query_pkt_len: int = 0,
     _dw_resp_ptr: int = 0,
     _dw_resp_len: int = 0,
     _dw_dbg: str = "";

def _dw_byte(off: int) -> int {
    if _dw_resp_ptr == 0 or off >= _dw_resp_len {
        return 0;
    }
    return read_byte(_dw_resp_ptr, off);
}

def _dw_u16_be(off: int) -> int {
    return _dw_byte(off) * 256 + _dw_byte(off + 1);
}

def _dw_u32_be(off: int) -> int {
    return _dw_u16_be(off) * 65536 + _dw_u16_be(off + 2);
}

def _dw_chr(b: int) -> str {
    if b < 0 {
        b = 0;
    }
    if b > 255 {
        b = 255;
    }
    return byte_chr(b);
}

def _dw_append_u16_be(s: str, v: int) -> str {
    return s + _dw_chr((v // 256) & 255) + _dw_chr(v & 255);
}

def _dw_encode_qname(host: str) -> str {
    out: str = "";
    label: str = "";
    i: int = 0;
    while i <= len(host) {
        c: str = ".";
        if i < len(host) {
            c = host[i];
        }
        if c == "." or i == len(host) {
            if len(label) > 0 {
                out = out + _dw_chr(len(label)) + label;
                label = "";
            }
        } else {
            label = label + c;
        }
        i = i + 1;
    }
    return out + _dw_chr(0);
}

def _dw_write_u16_be_buf(ptr: int, off: int, v: int) -> int {
    write_byte(ptr, off, (v // 256) & 255);
    write_byte(ptr, off + 1, v & 255);
    return off + 2;
}

def _dw_write_name_buf(ptr: int, off: int, host: str) -> int {
    label: str = "";
    i: int = 0;
    while i <= len(host) {
        c: str = ".";
        if i < len(host) {
            c = host[i];
        }
        if c == "." or i == len(host) {
            if len(label) > 0 {
                write_byte(ptr, off, len(label));
                off = off + 1;
                li: int = 0;
                while li < len(label) {
                    write_byte(ptr, off, ord(label[li]));
                    off = off + 1;
                    li = li + 1;
                }
                label = "";
            }
        } else {
            label = label + c;
        }
        i = i + 1;
    }
    write_byte(ptr, off, 0);
    return off + 1;
}

def _dw_build_query_buf(name: str, qtype: int) {
    _wire_query_id = _wire_query_id + 1;
    if _wire_query_id > 65535 {
        _wire_query_id = 1;
    }
    buf: int = io_alloc(512);
    off: int = 0;
    off = _dw_write_u16_be_buf(buf, off, _wire_query_id);
    write_byte(buf, off, 1);
    off = off + 1;
    write_byte(buf, off, 0);
    off = off + 1;
    off = _dw_write_u16_be_buf(buf, off, 1);
    off = _dw_write_u16_be_buf(buf, off, 0);
    off = _dw_write_u16_be_buf(buf, off, 0);
    off = _dw_write_u16_be_buf(buf, off, 0);
    off = _dw_write_name_buf(buf, off, name);
    off = _dw_write_u16_be_buf(buf, off, qtype);
    off = _dw_write_u16_be_buf(buf, off, _DNS_CLASS_IN);
    _dw_query_pkt_ptr = buf;
    _dw_query_pkt_len = off;
}

def _dw_skip_name(off: int) -> int {
    while off < _dw_resp_len {
        ln: int = _dw_byte(off);
        if ln == 0 {
            return off + 1;
        }
        if ln >= 192 {
            return off + 2;
        }
        off = off + 1 + ln;
    }
    return off;
}

def _dw_read_name(off: int) -> str {
    parts: list[str] = [];
    jumped: bool = False;
    max_hops: int = 20;
    hops: int = 0;
    while off < _dw_resp_len and hops < max_hops {
        ln: int = _dw_byte(off);
        if ln == 0 {
            if not jumped {
                off = off + 1;
            }
            break;
        }
        if ln >= 192 {
            ptr: int = (ln - 192) * 256 + _dw_byte(off + 1);
            if not jumped {
                off = off + 2;
                jumped = True;
            }
            off = ptr;
            hops = hops + 1;
            continue;
        }
        label: str = "";
        off = off + 1;
        li: int = 0;
        while li < ln and off < _dw_resp_len {
            label = label + _dw_chr(_dw_byte(off));
            off = off + 1;
            li = li + 1;
        }
        parts.append(label);
        hops = hops + 1;
    }
    out: str = "";
    pi: int = 0;
    while pi < len(parts) {
        if pi > 0 {
            out = out + ".";
        }
        out = out + parts[pi];
        pi = pi + 1;
    }
    return out;
}

def _dw_ipv4_from_rdata(off: int, rdlen: int) -> str {
    if rdlen != 4 {
        return "";
    }
    p0: int = _dw_byte(off);
    p1: int = _dw_byte(off + 1);
    p2: int = _dw_byte(off + 2);
    p3: int = _dw_byte(off + 3);
    return _dns_wire_int_to_str(p0)
        + "."
        + _dns_wire_int_to_str(p1)
        + "."
        + _dns_wire_int_to_str(p2)
        + "."
        + _dns_wire_int_to_str(p3);
}

def _dns_wire_int_to_str(n: int) -> str {
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

def _dw_ptr_name_from_ip(ip: str) -> str {
    parts: list[str] = [];
    cur: str = "";
    i: int = 0;
    while i <= len(ip) {
        c: str = ".";
        if i < len(ip) {
            c = ip[i];
        }
        if c == "." or i == len(ip) {
            if len(cur) > 0 {
                parts.append(cur);
                cur = "";
            }
        } else {
            cur = cur + c;
        }
        i = i + 1;
    }
    if len(parts) != 4 {
        return "";
    }
    return parts[3]
        + "."
        + parts[2]
        + "."
        + parts[1]
        + "."
        + parts[0]
        + ".in-addr.arpa";
}

def:pub dns_wire_load_resolv_conf -> list[str] {
    out: list[str] = [];
    fp: int = fopen("/etc/resolv.conf", "r");
    if fp == 0 {
        out.append("127.0.0.53");
        return out;
    }
    buf: int = io_alloc(4096);
    n: int = fread(buf, 1, 4095, fp);
    fclose(fp);
    if n <= 0 {
        out.append("127.0.0.53");
        return out;
    }
    text: str = buf;  # jac:ignore[E1001] pointer reinterpret
    line: str = "";
    i: int = 0;
    while i < n {
        ch: str = text[i];
        if ch == "\n" or ch == "\r" {
            if _dw_line_prefix(line, "nameserver") {
                rest: str = line[10:];
                j: int = 0;
                while j < len(rest) and rest[j] == " " {
                    j = j + 1;
                }
                ip: str = rest[j:];
                if len(ip) > 0 {
                    out.append(ip);
                }
            }
            line = "";
        } else {
            line = line + ch;
        }
        i = i + 1;
    }
    if len(out) == 0 {
        out.append("127.0.0.53");
    }
    return out;
}

def _dw_line_prefix(line: str, prefix: str) -> bool {
    if len(line) < len(prefix) {
        return False;
    }
    pi: int = 0;
    while pi < len(prefix) {
        if line[pi] != prefix[pi] {
            return False;
        }
        pi = pi + 1;
    }
    return True;
}

def _dw_str_from_ptr(ptr: int, n: int) -> str {
    out: str = "";
    i: int = 0;
    while i < n {
        out = out + _dw_chr(read_byte(ptr, i));
        i = i + 1;
    }
    return out;
}

def _dw_set_rcv_timeout(fd: int, sec: int) {
    tv: int = calloc(1, 16);
    write_i64(tv, 0, sec);
    write_i32(tv, 8, 0);
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, tv, 16);
}

def _dw_parse_port_digits(ps: str) -> int {
    pi: int = 0;
    pv: int = 0;
    while pi < len(ps) {
        pch: str = ps[pi];
        if pch >= "0" and pch <= "9" {
            pv = pv * 10 + (ord(pch) - 48);
        } else {
            return 0;
        }
        pi = pi + 1;
    }
    return pv;
}

def _dw_parse_host_port(server: str) -> list[str] {
    host: str = server;
    port: int = 53;
    slen: int = len(server);
    if slen >= 2 and server[0] == "[" {
        bi: int = 1;
        while bi < slen and server[bi] != "]" {
            bi = bi + 1;
        }
        if bi < slen {
            host = server[1:bi];
            if bi + 1 < slen and server[bi + 1] == ":" {
                pv: int = _dw_parse_port_digits(server[bi + 2:]);
                if pv > 0 {
                    port = pv;
                }
            }
        }
        return [host, _dns_wire_int_to_str(port)];
    }
    colon_count: int = 0;
    last_colon: int = -1;
    ci: int = 0;
    while ci < slen {
        if server[ci] == ":" {
            colon_count = colon_count + 1;
            last_colon = ci;
        }
        ci = ci + 1;
    }
    if colon_count == 1 and last_colon >= 0 {
        host = server[0:last_colon];
        pv2: int = _dw_parse_port_digits(server[last_colon + 1:]);
        if pv2 > 0 {
            port = pv2;
        }
    }
    return [host, _dns_wire_int_to_str(port)];
}

def _dw_tcp_read_into(sock: TCPSocket, buf: int, n: int) -> int {
    if sock.fd == 0 or n <= 0 or buf == 0 {
        return 0;
    }
    got: int = 0;
    while got < n {
        tmp: int = io_alloc(n - got);
        nr: int = recv(sock.fd, tmp, n - got, 0);
        if nr <= 0 {
            return 0;
        }
        ti: int = 0;
        while ti < nr {
            write_byte(buf, got + ti, read_byte(tmp, ti));
            ti = ti + 1;
        }
        got = got + nr;
    }
    return got;
}

def _dw_query_tcp(server: str) -> int {
    hp2: list[str] = _dw_parse_host_port(server);
    host2: str = hp2[0];
    port2: int = 53;
    if len(hp2[1]) > 0 {
        port2 = 0;
        pi4: int = 0;
        while pi4 < len(hp2[1]) {
            pch4: str = hp2[1][pi4];
            if pch4 >= "0" and pch4 <= "9" {
                port2 = port2 * 10 + (ord(pch4) - 48);
            }
            pi4 = pi4 + 1;
        }
    }
    sock = tcp_connect(host2, port2);
    if not sock.connected {
        return 0;
    }
    _dw_set_rcv_timeout(sock.fd, 5);
    plen: int = _dw_query_pkt_len;
    frame: int = io_alloc(plen + 2);
    _dw_write_u16_be_buf(frame, 0, plen);
    fi: int = 0;
    while fi < plen {
        write_byte(frame, 2 + fi, read_byte(_dw_query_pkt_ptr, fi));
        fi = fi + 1;
    }
    want: int = plen + 2;
    wrc: int = tcp_write_bytes(sock, frame, want);
    if wrc < want {
        _dw_dbg = "wrc=" + _dns_wire_int_to_str(wrc) + "/" + _dns_wire_int_to_str(want);
        tcp_close(sock);
        return 0;
    }
    hdr_buf: int = io_alloc(2);
    if _dw_tcp_read_into(sock, hdr_buf, 2) < 2 {
        _dw_dbg = "hdr";
        tcp_close(sock);
        return 0;
    }
    rlen: int = read_byte(hdr_buf, 0) * 256 + read_byte(hdr_buf, 1);
    if rlen <= 0 or rlen > 65535 {
        tcp_close(sock);
        return 0;
    }
    body_buf: int = io_alloc(rlen);
    if _dw_tcp_read_into(sock, body_buf, rlen) < rlen {
        _dw_dbg = "body";
        tcp_close(sock);
        return 0;
    }
    tcp_close(sock);
    _dw_resp_ptr = body_buf;
    _dw_resp_len = rlen;
    return rlen;
}

def _dw_query_udp(server: str) -> int {
    hp: list[str] = _dw_parse_host_port(server);
    host: str = hp[0];
    port: int = 53;
    if len(hp[1]) > 0 {
        port = 0;
        pi3: int = 0;
        while pi3 < len(hp[1]) {
            pch3: str = hp[1][pi3];
            if pch3 >= "0" and pch3 <= "9" {
                port = port * 10 + (ord(pch3) - 48);
            }
            pi3 = pi3 + 1;
        }
    }
    sock: UDPSocket = udp_create("", 0);
    if sock.fd == 0 {
        return 0;
    }
    _dw_set_rcv_timeout(sock.fd, 5);
    sent: int = udp_send_bytes(sock, _dw_query_pkt_ptr, _dw_query_pkt_len, host, port);
    if sent < 0 {
        udp_close(sock);
        return 0;
    }
    msg = udp_recv(sock, 4096);
    udp_close(sock);
    if msg.length < 12 {
        return 0;
    }
    _dw_resp_ptr = msg.data_ptr;
    _dw_resp_len = msg.length;
    return msg.length;
}

def _dw_query_transport(server: str) -> int {
    got: int = _dw_query_tcp(server);
    if got >= 12 {
        return got;
    }
    return _dw_query_udp(server);
}

def _dw_err(code: str, host: str) -> JSValue {
    err: JSValue = js_object_create_null();
    js_object_set(err, str_intern("code"), jsv_from_string_id(str_intern(code)));
    js_object_set(err, str_intern("hostname"), jsv_from_string_id(str_intern(host)));
    return err;
}

def _dw_ok_records(recs: list[JSValue]) -> JSValue {
    ok: JSValue = js_object_create_null();
    js_object_set(ok, str_intern("ok"), js_true());
    js_object_set(ok, str_intern("records"), js_array_create(recs));
    return ok;
}

"""Wire DNS query. servers empty => use caller-provided default list."""
def:pub dns_wire_query(host: str, qtype: int, servers: list[str]) -> JSValue {
    if len(servers) == 0 {
        return _dw_err("ENOTFOUND", host);
    }
    lower: str = host;
    if qtype == _QTYPE_A and lower == "localhost" {
        entl: JSValue = js_object_create_null();
        js_object_set(entl, str_intern("kind"), jsv_from_string_id(str_intern("A")));
        js_object_set(
            entl, str_intern("address"), jsv_from_string_id(str_intern("127.0.0.1"))
        );
        return _dw_ok_records([entl]);
    }
    if qtype == _QTYPE_AAAA and lower == "localhost" {
        ent6l: JSValue = js_object_create_null();
        js_object_set(
            ent6l, str_intern("kind"), jsv_from_string_id(str_intern("AAAA"))
        );
        js_object_set(
            ent6l, str_intern("address"), jsv_from_string_id(str_intern("::1"))
        );
        return _dw_ok_records([ent6l]);
    }
    if qtype == _QTYPE_PTR and host == "127.0.0.1" {
        entp: JSValue = js_object_create_null();
        js_object_set(entp, str_intern("kind"), jsv_from_string_id(str_intern("PTR")));
        js_object_set(
            entp, str_intern("value"), jsv_from_string_id(str_intern("localhost"))
        );
        return _dw_ok_records([entp]);
    }
    qname: str = host;
    if qtype == _QTYPE_PTR {
        qname = _dw_ptr_name_from_ip(host);
        if len(qname) == 0 {
            ok_empty: JSValue = js_object_create_null();
            js_object_set(ok_empty, str_intern("ok"), js_true());
            js_object_set(ok_empty, str_intern("records"), js_array_create([]));
            return ok_empty;
        }
    }
    _dw_build_query_buf(qname, qtype);
    si: int = 0;
    while si < len(servers) {
        resp_len: int = _dw_query_transport(servers[si]);
        if resp_len < 12 {
            si = si + 1;
            continue;
        }
        # Parse answer + authority + additional sections.
        rcode: int = _dw_byte(3) & 15;
        if rcode == 3 {
            return _dw_err("ENOTFOUND", host);
        }
        if rcode != 0 {
            si = si + 1;
            continue;
        }
        qdcount: int = _dw_u16_be(4);
        ancount: int = _dw_u16_be(6);
        nscount: int = _dw_u16_be(8);
        arcount: int = _dw_u16_be(10);
        off: int = 12;
        qi: int = 0;
        while qi < qdcount and off < _dw_resp_len {
            off = _dw_skip_name(off);
            off = off + 4;
            qi = qi + 1;
        }
        recs: list[JSValue] = [];
        off = _dw_parse_rr_section(off, ancount, qtype, recs);
        off = _dw_parse_rr_section(off, nscount, qtype, recs);
        off = _dw_parse_rr_section(off, arcount, qtype, recs);
        if len(recs) == 0 and qtype != _QTYPE_PTR {
            return _dw_err("ENODATA", host);
        }
        return _dw_ok_records(recs);
    }
    if len(_dw_dbg) > 0 {
        return _dw_err("ENOTFOUND", host + ":" + _dw_dbg);
    }
    return _dw_err("ENOTFOUND", host);
}

def _dw_parse_rr_section(off: int, count: int, qtype: int, recs: list[JSValue]) -> int {
    ai: int = 0;
    while ai < count and off + 10 < _dw_resp_len {
        off = _dw_skip_name(off);
        rtype: int = _dw_u16_be(off);
        off = off + 2;
        off = off + 6;
        rdlen: int = _dw_u16_be(off);
        off = off + 2;
        rdata_off: int = off;
        if rtype == _QTYPE_A and qtype == _QTYPE_A {
            addr: str = _dw_ipv4_from_rdata(rdata_off, rdlen);
            if len(addr) > 0 {
                ent: JSValue = js_object_create_null();
                js_object_set(
                    ent, str_intern("kind"), jsv_from_string_id(str_intern("A"))
                );
                js_object_set(
                    ent, str_intern("address"), jsv_from_string_id(str_intern(addr))
                );
                recs.append(ent);
            }
        } elif rtype == _QTYPE_AAAA and qtype == _QTYPE_AAAA {
            if rdlen == 16 {
                hex: str = "";
                bi: int = 0;
                while bi < 16 {
                    b: int = _dw_byte(rdata_off + bi);
                    hi: int = (b // 16) & 15;
                    lo: int = b & 15;
                    hex = hex + _dw_hex_digit(hi) + _dw_hex_digit(lo);
                    if bi == 1
                        or bi == 3
                        or bi == 5
                        or bi == 7
                        or bi == 9
                        or bi == 11 {
                        hex = hex + ":";
                    }
                    bi = bi + 1;
                }
                ent6: JSValue = js_object_create_null();
                js_object_set(
                    ent6, str_intern("kind"), jsv_from_string_id(str_intern("AAAA"))
                );
                js_object_set(
                    ent6, str_intern("address"), jsv_from_string_id(str_intern(hex))
                );
                recs.append(ent6);
            }
        } elif rtype == _QTYPE_CNAME and qtype == _QTYPE_CNAME {
            nm: str = _dw_read_name(rdata_off);
            entc: JSValue = js_object_create_null();
            js_object_set(
                entc, str_intern("kind"), jsv_from_string_id(str_intern("CNAME"))
            );
            js_object_set(
                entc, str_intern("value"), jsv_from_string_id(str_intern(nm))
            );
            recs.append(entc);
        } elif rtype == _QTYPE_NS and qtype == _QTYPE_NS {
            nm2: str = _dw_read_name(rdata_off);
            entn: JSValue = js_object_create_null();
            js_object_set(
                entn, str_intern("kind"), jsv_from_string_id(str_intern("NS"))
            );
            js_object_set(
                entn, str_intern("value"), jsv_from_string_id(str_intern(nm2))
            );
            recs.append(entn);
        } elif rtype == _QTYPE_PTR and qtype == _QTYPE_PTR {
            nm3: str = _dw_read_name(rdata_off);
            entp: JSValue = js_object_create_null();
            js_object_set(
                entp, str_intern("kind"), jsv_from_string_id(str_intern("PTR"))
            );
            js_object_set(
                entp, str_intern("value"), jsv_from_string_id(str_intern(nm3))
            );
            recs.append(entp);
        } elif rtype == _QTYPE_MX and qtype == _QTYPE_MX {
            if rdlen >= 3 {
                pri: int = _dw_u16_be(rdata_off);
                ex: str = _dw_read_name(rdata_off + 2);
                entm: JSValue = js_object_create_null();
                js_object_set(
                    entm, str_intern("kind"), jsv_from_string_id(str_intern("MX"))
                );
                js_object_set(entm, str_intern("priority"), js_int(pri));
                js_object_set(
                    entm, str_intern("exchange"), jsv_from_string_id(str_intern(ex))
                );
                recs.append(entm);
            }
        } elif rtype == _QTYPE_TXT and qtype == _QTYPE_TXT {
            txt: str = "";
            toff: int = rdata_off;
            tend: int = rdata_off + rdlen;
            while toff < tend {
                slen: int = _dw_byte(toff);
                toff = toff + 1;
                si2: int = 0;
                while si2 < slen and toff < tend {
                    txt = txt + _dw_chr(_dw_byte(toff));
                    toff = toff + 1;
                    si2 = si2 + 1;
                }
            }
            entt: JSValue = js_object_create_null();
            js_object_set(
                entt, str_intern("kind"), jsv_from_string_id(str_intern("TXT"))
            );
            js_object_set(
                entt, str_intern("value"), jsv_from_string_id(str_intern(txt))
            );
            recs.append(entt);
        } elif rtype == _QTYPE_SOA and qtype == _QTYPE_SOA {
            if rdlen >= 20 {
                mname: str = _dw_read_name(rdata_off);
                off2: int = rdata_off;
                off2 = _dw_skip_name(rdata_off);
                rname: str = _dw_read_name(off2);
                off3: int = _dw_skip_name(off2);
                serial: int = _dw_u32_be(off3);
                refresh: int = _dw_u32_be(off3 + 4);
                retry: int = _dw_u32_be(off3 + 8);
                expire: int = _dw_u32_be(off3 + 12);
                minimum: int = _dw_u32_be(off3 + 16);
                entsoa: JSValue = js_object_create_null();
                js_object_set(
                    entsoa, str_intern("kind"), jsv_from_string_id(str_intern("SOA"))
                );
                js_object_set(
                    entsoa, str_intern("nsname"), jsv_from_string_id(str_intern(mname))
                );
                js_object_set(
                    entsoa,
                    str_intern("hostmaster"),
                    jsv_from_string_id(str_intern(rname))
                );
                js_object_set(entsoa, str_intern("serial"), js_int(serial));
                js_object_set(entsoa, str_intern("refresh"), js_int(refresh));
                js_object_set(entsoa, str_intern("retry"), js_int(retry));
                js_object_set(entsoa, str_intern("expire"), js_int(expire));
                js_object_set(entsoa, str_intern("minttl"), js_int(minimum));
                recs.append(entsoa);
            }
        } elif rtype == _QTYPE_SRV and qtype == _QTYPE_SRV {
            if rdlen >= 6 {
                pri2: int = _dw_u16_be(rdata_off);
                weight: int = _dw_u16_be(rdata_off + 2);
                sport: int = _dw_u16_be(rdata_off + 4);
                target: str = _dw_read_name(rdata_off + 6);
                entsrv: JSValue = js_object_create_null();
                js_object_set(
                    entsrv, str_intern("kind"), jsv_from_string_id(str_intern("SRV"))
                );
                js_object_set(entsrv, str_intern("priority"), js_int(pri2));
                js_object_set(entsrv, str_intern("weight"), js_int(weight));
                js_object_set(entsrv, str_intern("port"), js_int(sport));
                js_object_set(
                    entsrv, str_intern("name"), jsv_from_string_id(str_intern(target))
                );
                recs.append(entsrv);
            }
        } elif rtype == _QTYPE_NAPTR and qtype == _QTYPE_NAPTR {
            if rdlen >= 4 {
                order: int = _dw_u16_be(rdata_off);
                pref: int = _dw_u16_be(rdata_off + 2);
                noff: int = rdata_off + 4;
                fl: int = _dw_byte(noff);
                noff = noff + 1;
                flags: str = "";
                fi: int = 0;
                while fi < fl and noff < rdata_off + rdlen {
                    flags = flags + _dw_chr(_dw_byte(noff));
                    noff = noff + 1;
                    fi = fi + 1;
                }
                sl: int = _dw_byte(noff);
                noff = noff + 1;
                services: str = "";
                fi2: int = 0;
                while fi2 < sl and noff < rdata_off + rdlen {
                    services = services + _dw_chr(_dw_byte(noff));
                    noff = noff + 1;
                    fi2 = fi2 + 1;
                }
                rl: int = _dw_byte(noff);
                noff = noff + 1;
                regexp: str = "";
                fi3: int = 0;
                while fi3 < rl and noff < rdata_off + rdlen {
                    regexp = regexp + _dw_chr(_dw_byte(noff));
                    noff = noff + 1;
                    fi3 = fi3 + 1;
                }
                repl: str = _dw_read_name(noff);
                entnap: JSValue = js_object_create_null();
                js_object_set(
                    entnap, str_intern("kind"), jsv_from_string_id(str_intern("NAPTR"))
                );
                js_object_set(entnap, str_intern("order"), js_int(order));
                js_object_set(entnap, str_intern("preference"), js_int(pref));
                js_object_set(
                    entnap, str_intern("flags"), jsv_from_string_id(str_intern(flags))
                );
                js_object_set(
                    entnap,
                    str_intern("services"),
                    jsv_from_string_id(str_intern(services))
                );
                js_object_set(
                    entnap, str_intern("regexp"), jsv_from_string_id(str_intern(regexp))
                );
                js_object_set(
                    entnap,
                    str_intern("replacement"),
                    jsv_from_string_id(str_intern(repl))
                );
                recs.append(entnap);
            }
        } elif rtype == _QTYPE_CAA and qtype == _QTYPE_CAA {
            if rdlen >= 3 {
                cflags: int = _dw_byte(rdata_off);
                taglen: int = _dw_byte(rdata_off + 1);
                tag: str = "";
                ti: int = 0;
                while ti < taglen and rdata_off + 2 + ti < rdata_off + rdlen {
                    tag = tag + _dw_chr(_dw_byte(rdata_off + 2 + ti));
                    ti = ti + 1;
                }
                voff: int = rdata_off + 2 + taglen;
                val: str = "";
                while voff < rdata_off + rdlen {
                    val = val + _dw_chr(_dw_byte(voff));
                    voff = voff + 1;
                }
                entcaa: JSValue = js_object_create_null();
                js_object_set(
                    entcaa, str_intern("kind"), jsv_from_string_id(str_intern("CAA"))
                );
                js_object_set(entcaa, str_intern("critical"), js_int(cflags));
                js_object_set(
                    entcaa, str_intern("issue"), jsv_from_string_id(str_intern(tag))
                );
                js_object_set(
                    entcaa, str_intern("value"), jsv_from_string_id(str_intern(val))
                );
                recs.append(entcaa);
            }
        }
        off = rdata_off + rdlen;
        ai = ai + 1;
    }
    return off;
}

def _dw_hex_digit(v: int) -> str {
    if v < 10 {
        return _dns_wire_int_to_str(v);
    }
    if v == 10 {
        return "a";
    }
    if v == 11 {
        return "b";
    }
    if v == 12 {
        return "c";
    }
    if v == 13 {
        return "d";
    }
    if v == 14 {
        return "e";
    }
    return "f";
}

def:pub dns_wire_qtype_a -> int {
    return _QTYPE_A;
}
def:pub dns_wire_qtype_aaaa -> int {
    return _QTYPE_AAAA;
}
def:pub dns_wire_qtype_ptr -> int {
    return _QTYPE_PTR;
}
def:pub dns_wire_qtype_cname -> int {
    return _QTYPE_CNAME;
}
def:pub dns_wire_qtype_mx -> int {
    return _QTYPE_MX;
}
def:pub dns_wire_qtype_ns -> int {
    return _QTYPE_NS;
}
def:pub dns_wire_qtype_txt -> int {
    return _QTYPE_TXT;
}
def:pub dns_wire_qtype_soa -> int {
    return _QTYPE_SOA;
}
def:pub dns_wire_qtype_srv -> int {
    return _QTYPE_SRV;
}
def:pub dns_wire_qtype_naptr -> int {
    return _QTYPE_NAPTR;
}
def:pub dns_wire_qtype_caa -> int {
    return _QTYPE_CAA;
}
