"""Test Jac program that imports walkers with different access levels.

This tests the fix for GitHub issue #4145:
`:pub` access modifier should be recognized on imported walkers.
"""

# Import walkers and functions with different access levels
import from serve_api_importable_access {
    publicImportedFunc,
    protectedImportedFunc,
    defaultImportedFunc,
    PublicImportedWalker,
    ProtectedImportedWalker,
    DefaultImportedWalker
}

# Local public walker for comparison
walker :pub LocalPublicWalker {
    has msg: str = "local public";

    can run with Root entry {
        report {"message": self.msg, "type": "local_public"};
    }
}

# Local default walker for comparison
walker LocalDefaultWalker {
    has msg: str = "local default";

    can run with Root entry {
        report {"message": self.msg, "type": "local_default"};
    }
}

# Local public function for comparison
def :pub localPublicFunc -> dict {
    return {"message": "Hello from local public function!", "type": "local_public"};
}

# Local default function (no access modifier - requires auth by default)
def localDefaultFunc -> dict {
    return {"message": "Hello from local default function!", "type": "local_default"};
}
