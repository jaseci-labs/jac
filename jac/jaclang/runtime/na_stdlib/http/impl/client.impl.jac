impl HTTPHeaders.add(name: str, value: str) {
    normalized = name.lower();
    if normalized not in self._data {
        self._keys.append(name);
    }
    self._data[normalized] = value;
}

impl HTTPHeaders.get(name: str, `default: (str | None) = None) -> (str | None) {
    return self._data.get(name.lower(), `default);
}

impl HTTPHeaders.__getitem__(name: str) -> str {
    normalized = name.lower();
    if normalized not in self._data {
        raise KeyError(name);
    }
    return self._data[normalized];
}

impl HTTPHeaders.__contains__(name: str) -> bool {
    return name.lower() in self._data;
}

impl HTTPHeaders.keys -> list[str] {
    return list(self._keys);
}

impl HTTPHeaders.values -> list[str] {
    return [self._data[name.lower()] for name in self._keys];
}

impl HTTPHeaders.items -> list[tuple[str, str]] {
    return [(name, self._data[name.lower()]) for name in self._keys];
}

impl HTTPHeaders.__iter__ -> Iterator[str] {
    return iter(self._keys);
}

impl HTTPHeaders.__len__ -> int {
    return len(self._keys);
}


impl HTTPResponse.read(amt: (int | None) = None) -> bytes {
    start = self._pos;
    end = len(self._body);
    if amt is not None and amt >= 0 and start + amt < end {
        end = start + amt;
    }
    self._pos = end;
    return self._body[start:end];
}


impl HTTPResponse.readline(limit: int = -1) -> bytes {
    if self._pos >= len(self._body) {
        return b"";
    }
    end = self._body.find(b"\n", self._pos);
    if end < 0 {
        end = len(self._body);
    } else {
        end += 1;
    }
    if limit >= 0 and self._pos + limit < end {
        end = self._pos + limit;
    }
    line: bytes = self._body[self._pos:end];
    self._pos = end;
    return line;
}

impl HTTPResponse.getheader(name: str, `default: (str | None) = None) -> (str | None) {
    wanted = name.lower();
    i: int = 0;
    while i < len(self._header_names) {
        if self._header_names[i].lower() == wanted {
            return self._header_values[i];
        }
        i += 1;
    }
    return `default;
}

impl HTTPResponse.geturl -> str {
    return self._url;
}

impl HTTPResponse.close {
    return;
}
