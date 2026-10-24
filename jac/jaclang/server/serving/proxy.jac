import ipaddress;
import logging;
import threading;

glob logger: logging.Logger = logging.getLogger(__name__),
     _untrusted_warned: threading.Event = threading.Event();


obj ForwardedInfo {
    has client: str = '',
        scheme: str = '',
        host: str = '';
}


def parse_ip(raw: str) -> any;


def _parse_networks(
    entries: list[str]
) -> list[ipaddress.IPv4Network | ipaddress.IPv6Network];


def _forwarded_pairs(headers: Headers) -> list[dict[str, str]];


obj ProxyResolver {
    has trusted: list[str] = [],
        _networks: list[ipaddress.IPv4Network | ipaddress.IPv6Network] = [];

    def postinit;
    def is_trusted(ip: any) -> bool;
    def _warn_once(peer: str, headers: Headers);
    def resolve(peer: str, headers: Headers) -> ForwardedInfo;
}
