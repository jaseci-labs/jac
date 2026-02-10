"""Factory for creating client build targets.

This module provides a factory function to create target instances based on
the ClientTargetType enum. It centralizes target instantiation and provides
a clean API for the CLI to use.
"""
import from .types { ClientTargetType }
import from .base { ClientTarget }

# Target cache for singleton pattern
glob _target_cache: dict[ClientTargetType, ClientTarget] = {},
     ERR_UNKNOWN_TARGET = "Unknown target: '{}'. Valid targets: {}";

"""Create a target instance for the given target type.

Uses a singleton pattern - each target type is instantiated once and cached.
This ensures consistent state across multiple calls.

Args:
    target_type: The type of target to create

Returns:
    A ClientTarget instance for the given type

Raises:
    ValueError: If the target type is not implemented
"""
def create_target(target_type: ClientTargetType) -> ClientTarget {
    global _target_cache;

    # Return cached instance if available
    if target_type in _target_cache {
        return _target_cache[target_type];
    }

    # Create new instance based on type
    target: ClientTarget;

    if target_type == ClientTargetType.WEB {
        import from .web.target { WebTarget }
        target = WebTarget();
    } elif target_type == ClientTargetType.PWA {
        import from .pwa.target { PWATarget }
        target = PWATarget();
    } elif target_type == ClientTargetType.DESKTOP {
        import from .desktop.target { DesktopTarget }
        target = DesktopTarget();
    } else {
        raise ValueError(f"Unknown target type: {target_type}");
    }

    # Cache and return
    _target_cache[target_type] = target;
    return target;
}

"""Get a target by string name.

Convenience function that parses a string name into ClientTargetType
and creates the target.

Args:
    name: Target name as string (e.g., "web", "pwa", "desktop")

Returns:
    A ClientTarget instance

Raises:
    ValueError: If the name is not a valid target type
"""
def get_target(name: str) -> ClientTarget {
    try {
        target_type = ClientTargetType(name);
        return create_target(target_type);
    } except ValueError {
        valid_targets = ', '.join(t.value for t in ClientTargetType);
        raise ValueError(ERR_UNKNOWN_TARGET.format(name, valid_targets));
    }
}

"""Get all available target types."""
def get_available_targets -> list[ClientTargetType] {
    return [
        ClientTargetType.WEB,
        ClientTargetType.PWA,
        ClientTargetType.DESKTOP
    ];
}

"""Get all available target names as strings."""
def get_available_target_names -> list[str] {
    return [t.value for t in get_available_targets()];
}

"""Clear the target cache (for testing)."""
def clear_target_cache -> None {
    global _target_cache;
    _target_cache = {};
}
