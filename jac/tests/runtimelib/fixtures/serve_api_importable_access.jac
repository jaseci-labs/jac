"""Module with walkers and functions having different access levels to be imported for serve testing."""

# Public function (no authentication required) - marked with :pub
def :pub publicImportedFunc -> dict {
    return {"message": "Hello from imported public function!", "auth_required": False};
}

def :protect protectedImportedFunc -> dict {
    return {"message": "Hello from imported protected function!", "auth_required": True};
}

# Default function (no access modifier - requires auth by default)
def defaultImportedFunc -> dict {
    return {"message": "Hello from imported default function!", "auth_required": True};
}

# Public walker (no authentication required) - marked with :pub
walker :pub PublicImportedWalker {
    has message: str = "hello from public imported walker";

    can greet with Root entry {
        report {"message": self.message, "type": "public_imported"};
    }
}

# Protected walker (authentication required) - marked with :protect
walker :protect ProtectedImportedWalker {
    has data: str = "protected data";

    can process with Root entry {
        report {"data": self.data, "type": "protected_imported"};
    }
}

# Default walker (no access modifier - should require auth by default)
walker DefaultImportedWalker {
    has value: int = 42;

    can compute with Root entry {
        report {"value": self.value, "type": "default_imported"};
    }
}
