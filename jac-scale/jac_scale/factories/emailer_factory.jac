"""Factory for creating Emailer instances.

Resolution order for the `provider` field of [plugins.scale.emailer]:

1. `'smtp'`: built-in SMTPEmailer.
2. A name registered programmatically via emailer_factory.register(name, cls).
3. A dotted import path of the form `'pkg.module:ClassName'`, imported
   dynamically, validated as a subclass of Emailer, and instantiated with the
   full emailer config dict.

This means user code can ship a custom emailer (e.g. SendGrid) without
modifying jac-scale: drop the class in your project, set `provider =
'myapp.email:SendGridEmailer'` in jac.toml, and it gets picked up at startup.
"""
import importlib;
import logging;
import from typing { Any }
import from jac_scale.abstractions.emailer { Emailer }

glob _registry: dict[str, type] = {},
     logger = logging.getLogger(__name__);

"""Register a custom emailer class under a short name."""
def register(name: str, cls: type) {
    global _registry;
    if not isinstance(cls, type) or not issubclass(cls, Emailer) {
        raise TypeError(
            f"Emailer class for '{name}' must subclass Emailer, got {cls!r}"
        );
    }
    _registry[name] = cls;
}

"""Resolve a `'module.path:ClassName'` import string to a class object.

Raises ImportError if the module can't be imported, AttributeError if the
class isn't found, and TypeError if the resolved class doesn't subclass
Emailer.
"""
def _import_dotted(path: str) -> type {
    if ':' in path {
        (mod_path, cls_name) = path.split(':', 1);
    } else {
        # Fallback: 'pkg.module.ClassName', split on the last dot.
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

"""Instantiate an Emailer subclass, logging and returning None on failure."""
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

"""Build an Emailer instance from a config dict.

The config dict is the full [plugins.scale.emailer] section. Returns None
when no provider is configured or when the provider fails to load /
instantiate (caller should treat this as 'email features disabled').
"""
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
        # Deferred import keeps email/mime deps out of the import graph when
        # the user doesn't configure SMTP.
        import from jac_scale.emailers { SMTPEmailer }
        return _instantiate(SMTPEmailer, provider, config, from_address, enabled);
    }
    if provider in _registry {
        return _instantiate(
            _registry[provider], provider, config, from_address, enabled
        );
    }
    # Dynamic dotted import.
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
