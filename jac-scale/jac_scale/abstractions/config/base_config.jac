"""Base configuration class for jac_scale."""
import from typing { Any }

"""Base configuration class that all target-specific configs should inherit from."""
class BaseConfig {
    has app_name: str,
        namespace: str = 'default';

    def init(
        self: BaseConfig, app_name: str = 'jaseci', namespace: str = 'default'
    ) -> None {
        self.app_name = app_name;
        self.namespace = namespace;
    }

    def to_dict(self: BaseConfig) -> dict[str, Any] {
        return {'app_name': self.app_name, 'namespace': self.namespace};
    }

    static def from_dict(cls: type, config: dict[str, Any]) -> BaseConfig {
        return cls(
            app_name=config.get('app_name', 'jaseci'),
            namespace=config.get('namespace', 'default')
        );
    }
}
