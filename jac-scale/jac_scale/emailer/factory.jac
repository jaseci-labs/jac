import importlib;
import logging;
import from typing { Any }
import from jac_scale.emailer.emailer { Emailer }

glob _registry: dict[str, type] = {},
     logger = logging.getLogger(__name__);

def register(name: str, cls: type) {
    global _registry;
    if not isinstance(cls, type) or not issubclass(cls, Emailer) {
        raise TypeError(
            f"Emailer class for '{name}' must subclass Emailer, got {cls!r}"
        );
    }
    _registry[name] = cls;
}

def _import_dotted(path: str) -> type {
    if ':' in path {
        (mod_path, cls_name) = path.split(':', 1);
    } else {
        if '.' not in path {
            raise ValueError(
                f"Emailer provider '{path}' must be 'module.path:ClassName' or "
                "a registered name like 'smtp'"
            );
        }
        (mod_path, cls_name) = path.rsplit('.', 1);
    }
    module = importlib.import_module(mod_path);
    cls = getattr(module, cls_name);
    if not isinstance(cls, type) or not issubclass(cls, Emailer) {
        raise TypeError(f"{path} resolved to {cls!r}, which does not subclass Emailer");
    }
    return cls;
}

def _instantiate(
    cls: type, provider: str, config: dict[str, Any], from_address: str, enabled: bool
) -> Emailer | None {
    try {
        return cls(config=config, from_address=from_address, enabled=enabled);
    } except Exception as e {
        logger.error(
            "Failed to instantiate emailer provider '%s' (%s): %s. "
            "Email features disabled.",
            provider,
            cls.__name__,
            e
        );
        return None;
    }
}

def create(config: dict[str, Any]) -> Emailer | None {
    global _registry;
    provider = (config.get('provider') or '').strip();
    if not provider {
        logger.info(
            "No emailer provider configured - email features disabled. "
            "Set [plugins.scale.emailer] provider = 'smtp' (or a custom "
            "'module.path:ClassName') in jac.toml to enable."
        );
        return None;
    }
    from_address = str(config.get('from_address', '') or '');
    enabled = bool(config.get('enabled', True));
    if provider == 'smtp' {
        import from jac_scale.emailer.emailers { SMTPEmailer }
        return _instantiate(SMTPEmailer, provider, config, from_address, enabled);
    }
    if provider in _registry {
        return _instantiate(
            _registry[provider], provider, config, from_address, enabled
        );
    }

    try {
        cls = _import_dotted(provider);
    } except (ImportError, AttributeError, TypeError, ValueError) as e {
        logger.error(
            "Failed to load emailer provider '%s': %s. Email features disabled.",
            provider,
            e
        );
        return None;
    }
    return _instantiate(cls, provider, config, from_address, enabled);
}
