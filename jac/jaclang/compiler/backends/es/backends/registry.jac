glob _BACKENDS: dict[str, FrameworkBackend] = {};

def resolve_framework_backend(framework: str) -> FrameworkBackend;

def active_framework -> str;

def resolve_active_backend -> FrameworkBackend;
