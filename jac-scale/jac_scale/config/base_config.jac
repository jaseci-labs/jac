obj BaseConfig {
    has app_name: str = 'jaseci',
        namespace: str = 'default';

    def to_dict -> dict[str, any] {
        return {'app_name': self.app_name, 'namespace': self.namespace};
    }

    static def from_dict(cls: type, config: dict[str, any]) -> BaseConfig {
        return cls(
            app_name=config.get('app_name', 'jaseci'),
            namespace=config.get('namespace', 'default')
        );
    }
}
