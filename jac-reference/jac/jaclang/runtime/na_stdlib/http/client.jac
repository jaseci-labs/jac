obj:pub HTTPResponse {
    has status: int,
        reason: str,
        _url: str,
        _body: bytes,
        _header_names: list[str],
        _header_values: list[str],
        _pos: int = 0;

    def read(amt: (int | None) = None) -> bytes;
    def getheader(name: str, `default: (str | None) = None) -> (str | None);
    def geturl -> str;
    def close;
}
