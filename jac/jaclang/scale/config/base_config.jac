obj BaseConfig {
    has app_name: str = 'jaseci',
        namespace: str = 'default';

    def to_dict -> dict[str, any] {
        out: dict[str, any] = {};
        comptime for f in fields(BaseConfig) {
            out[f.name] = get_field(self, f.name);
        }
        return out;
    }

    static def from_dict(cls: type, config: dict[str, any]) -> BaseConfig {
        kw: dict[str, any] = {};
        comptime for f in fields(BaseConfig) {
            kw[f.name] = config.get(f.name, f.`default);
        }
        return cls(**kw);
    }
}
