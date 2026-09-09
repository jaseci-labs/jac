def stable_osp_tag(name: str) -> int {
    _h = 5239054864098085;
    for _c in name {
        _h = _h ^ ord(_c);
        low = (_h & 67108863) * 435;
        high = ((_h >> 26) * 435 + (_h & 67108863) * 16384 + (low >> 26)) & 134217727;
        _h = (high << 26) | (low & 67108863);
    }
    return _h & 9007199254740991;
}
