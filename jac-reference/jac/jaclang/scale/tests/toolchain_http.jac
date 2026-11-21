import from unittest.mock { patch }

obj DownloadResponse {
    has data: bytes,
        url: str,
        offset: int = 0,
        headers: dict[str, str] postinit;

    def postinit {
        self.headers = {"Content-Length": str(len(self.data))};
    }

    def __enter__ -> DownloadResponse {
        return self;
    }

    def __exit__(_kind: object, _value: object, _trace: object) {}
    def geturl -> str {
        return self.url;
    }

    def read(size: int) -> bytes {
        chunk = self.data[self.offset:self.offset + size];
        self.offset += len(chunk);
        return chunk;
    }
}

def mock_downloads(reader: Callable[[str], bytes]) -> any {
    def respond(request: any, timeout: int = 60) -> DownloadResponse {
        url = str(request.full_url);
        return DownloadResponse(reader(url), url);
    }
    return patch("jaclang.toolchains.store.urlopen", side_effect=respond);
}
