"""Application configuration model."""
import from typing { Any }

"""Application deployment configuration."""
class AppConfig {
    has name: str;
    has image: str;
    has env_vars: list[dict[str, Any]] = [];
    has resources: (dict[str, Any] | None) = None;
    has health_check: (dict[str, Any] | None) = None;
}

