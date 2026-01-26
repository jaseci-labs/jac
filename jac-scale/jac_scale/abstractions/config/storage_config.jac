"""Storage configuration classes for jac_scale."""
import from typing { Any }
import os;

"""Base storage configuration."""
class BaseStorageConfig {
    has storage_type: str = 'local';

    def init(self: BaseStorageConfig, storage_type: str = 'local') -> None {
        self.storage_type = storage_type;
    }

    def to_dict(self: BaseStorageConfig) -> dict[str, Any] {
        return {'storage_type': self.storage_type};
    }

    static def from_dict(cls: type, config: dict[str, Any]) -> BaseStorageConfig {
        return cls(storage_type=config.get('storage_type', 'local'));
    }
}

"""Local filesystem storage configuration."""
class LocalStorageConfig(BaseStorageConfig) {
    has base_path: str = './storage',
        create_dirs: bool = True;

    def init(
        self: LocalStorageConfig,
        base_path: str = './storage',
        create_dirs: bool = True
    ) -> None {
        super.init('local');
        self.base_path = base_path;
        self.create_dirs = create_dirs;
    }

    override def to_dict(self: LocalStorageConfig) -> dict[str, Any] {
        return {
            'storage_type': self.storage_type,
            'base_path': self.base_path,
            'create_dirs': self.create_dirs
        };
    }

    static def from_dict(cls: type, config: dict[str, Any]) -> LocalStorageConfig {
        base_path = config.get('base_path', './storage');
        create_dirs_val = config.get('create_dirs', True);
        return LocalStorageConfig(
            base_path=base_path if base_path else './storage',
            create_dirs=create_dirs_val if create_dirs_val is not None else True
        );
    }

    static def from_env(cls: type) -> LocalStorageConfig {
        return LocalStorageConfig(
            base_path=os.environ.get('JAC_STORAGE_LOCAL_PATH', './storage'),
            create_dirs=os.environ.get('JAC_STORAGE_CREATE_DIRS', 'true').lower() == 'true'
        );
    }
}
