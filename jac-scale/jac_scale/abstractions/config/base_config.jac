"""Base configuration class for jac_scale."""
import from typing { Any }

"""Base configuration class that all target-specific configs should inherit from."""
obj BaseConfig {
    has app_name: str = 'jaseci',
        namespace: str = 'default';

    def to_dict -> dict[str, Any] {
        return {'app_name': self.app_name, 'namespace': self.namespace};
    }

    static def from_dict(cls: type, config: dict[str, Any]) -> BaseConfig {
        return cls(
            app_name=config.get('app_name', 'jaseci'),
            namespace=config.get('namespace', 'default')
        );
    }
}
