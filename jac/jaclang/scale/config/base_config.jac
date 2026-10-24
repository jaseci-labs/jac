obj BaseConfig {
    has app_name: str = 'jaseci',
        namespace: str = 'default';

    def to_dict -> dict[str, any];
    static def from_dict(cls: type, config: dict[str, any]) -> BaseConfig;
}
