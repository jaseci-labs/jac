obj: HTTPHeaders {
    has _keys: list[str] = [],
        _data: dict[str, str] = {};

    def add(name: str, value: str);
    def get(name: str, `default: (str | None) = None) -> (str | None);
    def __getitem__(name: str) -> str;
    def __contains__(name: str) -> bool;
    def keys -> list[str];
    def values -> list[str];
    def items -> list[tuple[str, str]];
    def __iter__ -> Iterator[str];
    def __len__ -> int;
}


obj:pub HTTPResponse {
    has status: int,
        reason: str,
        _url: str,
        _body: bytes,
        _header_names: list[str],
        _header_values: list[str],
        headers: HTTPHeaders = HTTPHeaders(),
        _pos: int = 0;

    def read(amt: (int | None) = None) -> bytes;
    def readline(limit: int = -1) -> bytes;
    def getheader(name: str, `default: (str | None) = None) -> (str | None);
    def geturl -> str;
    def close;
}
