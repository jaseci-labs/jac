import from jaclang.project.capabilities { missing_capability_error }

def require_optional(package: str, capability: str) {
    try {
        __import__(package);
    } except (ImportError, ValueError) {
        raise ImportError(
            f"'{package}' is required for this feature. "
            f"{missing_capability_error(capability)}"
        );
    }
}

def is_optional_available(package: str) -> bool {
    try {
        __import__(package);
        return True;
    } except (ImportError, ValueError) {
        return False;
    }
}
