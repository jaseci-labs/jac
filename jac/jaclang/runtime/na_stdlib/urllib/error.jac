"""Native urllib error types shared by the request and app surfaces."""

import from http.client { HTTPResponse }


obj:pub URLError(Exception) {
    has reason: any = None;
}


obj:pub HTTPError(URLError) {
    has url: str = "",
        code: int = 0,
        msg: str = "",
        hdrs: dict[str, str] = {},
        fp: HTTPResponse | None = None;

    def read(amt: (int | None) = None) -> bytes;
    def geturl -> str;
}


impl HTTPError.read(amt: (int | None)) -> bytes {
    if self.fp is None {
        return b"";
    }
    return self.fp.read(amt);
}


impl HTTPError.geturl -> str {
    return self.url;
}
