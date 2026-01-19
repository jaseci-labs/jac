"""Test Jac program that imports walkers with different access levels.

This tests the fix for GitHub issue #4145:
`:pub` access modifier should be recognized on imported walkers.
"""

# Import walkers with different access levels
import from serve_api_importable_access {
    PublicImportedWalker,
    ProtectedImportedWalker,
    DefaultImportedWalker
}

# Local public walker for comparison
walker :pub LocalPublicWalker {
    has msg: str = "local public";

    can run with `root entry {
        report {"message": self.msg, "type": "local_public"};
    }
}

# Local default walker for comparison
walker LocalDefaultWalker {
    has msg: str = "local default";

    can run with `root entry {
        report {"message": self.msg, "type": "local_default"};
    }
}
