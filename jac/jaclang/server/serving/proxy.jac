import ipaddress;
import logging;
import threading;
import from jaclang.server.serving.datatypes { Headers }

glob logger: logging.Logger = logging.getLogger(__name__),
     _untrusted_warned: threading.Event = threading.Event();


obj ForwardedInfo {
    has client: str = '',
        scheme: str = '',
        host: str = '';
}


def parse_ip(raw: str) -> any {
    s: str = raw.strip();
    if s.startswith('[') {
        s = s[1:].split(']')[0];
    } elif s.count(':') == 1 and '.' in s {
        s = s.split(':')[0];
    }
    if s.startswith('"') and s.endswith('"') and len(s) >= 2 {
        s = s[1:-1];
    }
    try {
        return ipaddress.ip_address(s);
    } except ValueError {
        return None;
    }
}


def _parse_networks(entries: list[str]) -> list {
    networks: list = [];
    for item in entries {
        try {
            networks.append(ipaddress.ip_network(str(item).strip(), strict=False));
        } except ValueError {
            logger.warning(
                f"Ignoring invalid [serve.proxy] trusted entry {item!r}; expected "
                "an IP address or CIDR network."
            );
        }
    }
    return networks;
}


def _forwarded_pairs(headers: Headers) -> list[dict[str, str]] {
    hops: list[dict[str, str]] = [];
    for raw in headers.getlist('Forwarded') {
        for element in str(raw).split(',') {
            pairs: dict[str, str] = {};
            for piece in element.split(';') {
                if '=' not in piece {
                    continue;
                }
                (name, _, value) = piece.partition('=');
                pairs[name.strip().lower()] = value.strip().strip('"');
            }
            if pairs {
                hops.append(pairs);
            }
        }
    }
    return hops;
}


obj ProxyResolver {
    has trusted: list[str] = [],
        _networks: list = [];

    def postinit {
        self._networks = _parse_networks(self.trusted);
    }

    def is_trusted(ip: any) -> bool {
        return ip is not None and any(ip in net for net in self._networks);
    }

    def _warn_once(peer: str, headers: Headers) {
        if _untrusted_warned.is_set() {
            return;
        }
        if headers.get('X-Forwarded-For') is None
            and headers.get('Forwarded') is None {
            return;
        }
        _untrusted_warned.set();
        logger.warning(
            f"Ignoring forwarded headers from peer {peer!r}: no [serve.proxy] "
            "trusted proxies are configured, so the TCP peer is the client. If a "
            "proxy or ingress fronts this server, list its address there."
        );
    }

    def resolve(peer: str, headers: Headers) -> ForwardedInfo {
        info = ForwardedInfo(client=peer);
        if not self._networks {
            self._warn_once(peer, headers);
            return info;
        }
        peer_ip = parse_ip(peer);
        if not self.is_trusted(peer_ip) {
            return info;
        }
        hops: list[str] = [];
        for value in headers.getlist('X-Forwarded-For') {
            for part in str(value).split(',') {
                if part.strip() {
                    hops.append(part.strip());
                }
            }
        }
        forwarded = _forwarded_pairs(headers);
        if not hops {
            hops = [
                pairs['for']
                for pairs in forwarded
                if pairs.get('for')
            ];
        }
        for hop in reversed(hops) {
            hop_ip = parse_ip(hop);
            if hop_ip is None {
                break;
            }
            if not self.is_trusted(hop_ip) {
                info.client = str(hop_ip);
                break;
            }
        }
        proto = (headers.get('X-Forwarded-Proto') or '').split(',')[0].strip().lower();
        if not proto {
            for pairs in forwarded {
                if pairs.get('proto') {
                    proto = pairs['proto'].lower();
                    break;
                }
            }
        }
        if proto in ('http', 'https') {
            info.scheme = proto;
        }
        host = (headers.get('X-Forwarded-Host') or '').split(',')[0].strip();
        if not host {
            for pairs in forwarded {
                if pairs.get('host') {
                    host = pairs['host'];
                    break;
                }
            }
        }
        if host {
            info.host = host;
        }
        return info;
    }
}
