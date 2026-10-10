obj:pub HTTPResponse {
    has status: int,
        reason: str,
        _url: str,
        _body: bytes,
        _header_names: list[str],
        _header_values: list[str];

    def read -> bytes {
        return self._body;
    }

    def getheader(name: str, `default: (str | None) = None) -> (str | None) {
        wanted = name.lower();
        i: int = 0;
        while i < len(self._header_names) {
            if self._header_names[i] == wanted {
                return self._header_values[i];
            }
            i += 1;
        }
        return `default;
    }

    def geturl -> str {
        return self._url;
    }

    def close {
        return;
    }
}
