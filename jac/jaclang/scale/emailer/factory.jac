import importlib;
import logging;

glob _registry: dict[str, type] = {},
     logger = logging.getLogger(__name__);

def register(name: str, cls: type);

def _import_dotted(path: str) -> type;

def _instantiate(
    cls: type, provider: str, config: dict[str, any], from_address: str, enabled: bool
) -> Emailer | None;

def create(config: dict[str, any]) -> Emailer | None;

def configured -> Emailer | None;
