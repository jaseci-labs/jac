"""Module with walkers having different access levels to be imported for serve testing."""

# Public walker (no authentication required) - marked with :pub
walker :pub PublicImportedWalker {
    has message: str = "hello from public imported walker";

    can greet with `root entry {
        report {"message": self.message, "type": "public_imported"};
    }
}

# Protected walker (authentication required) - marked with :protect
walker :protect ProtectedImportedWalker {
    has data: str = "protected data";

    can process with `root entry {
        report {"data": self.data, "type": "protected_imported"};
    }
}

# Default walker (no access modifier - should require auth by default)
walker DefaultImportedWalker {
    has value: int = 42;

    can compute with `root entry {
        report {"value": self.value, "type": "default_imported"};
    }
}
