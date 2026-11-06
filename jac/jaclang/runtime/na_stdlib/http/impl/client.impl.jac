impl HTTPResponse.read(amt: (int | None) = None) -> bytes {
    start = self._pos;
    end = len(self._body);
    if amt is not None and amt >= 0 and start + amt < end {
        end = start + amt;
    }
    self._pos = end;
    return self._body[start:end];
}


impl HTTPResponse.readline -> str {
    if self._pos >= len(self._body) {
        return "";
    }
    end = self._body.find(b"\n", self._pos);
    if end < 0 {
        end = len(self._body);
    } else {
        end += 1;
    }
    line: bytes = self._body[self._pos:end];
    self._pos = end;
    return line.decode("utf-8", "replace");
}

impl HTTPResponse.getheader(name: str, `default: (str | None) = None) -> (str | None) {
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

impl HTTPResponse.geturl -> str {
    return self._url;
}

impl HTTPResponse.close {
    return;
}
