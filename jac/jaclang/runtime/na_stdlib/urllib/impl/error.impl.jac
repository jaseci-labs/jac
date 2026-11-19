impl HTTPError.read(amt: (int | None)) -> bytes {
    if self.fp is None {
        return b"";
    }
    return self.fp.read(amt);
}


impl HTTPError.geturl -> str {
    return self.url;
}
