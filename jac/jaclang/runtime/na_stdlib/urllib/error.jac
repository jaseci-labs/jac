import from http.client { HTTPResponse }


obj:pub URLError(OSError) {
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
