impl load_counts -> dict[str, int] {
    global _counts_cache;
    if _counts_cache is None {
        _counts_cache = json.loads("{}");
    }
    return _counts_cache;
}


impl Response.json -> dict[str, int] {
    if self._json_cache is None {
        self._json_cache = json.loads(self.text);
    }
    return self._json_cache;
}
