
"""Test API fixture for restspec decorator tests."""

import from jaclang.runtimelib.builtin { restspec }
import from http { HTTPMethod }

# ============================================================================
# RestSpec Decorator Tests
# ============================================================================

"""Walker with GET method via restspec decorator."""
@restspec(method=HTTPMethod.GET)
walker : pub GetWalker {
    can get_data with `root entry {
        report {"message": "GetWalker executed", "method": "GET"};
    }
}

"""Walker with custom path."""
@restspec(method=HTTPMethod.GET, path="/custom/walker")
walker : pub CustomPathWalker {
    can get_data with `root entry {
        report {"message": "CustomPathWalker executed", "path": "/custom/walker"};
    }
}

"""Function with GET method via restspec decorator."""
@restspec(method=HTTPMethod.GET)
def get_func() -> dict {
    return {"message": "get_func executed", "method": "GET"};
}

"""Function with custom path."""
@restspec(method=HTTPMethod.GET, path="/custom/func")
def custom_path_func() -> dict {
    return {"message": "custom_path_func executed", "path": "/custom/func"};
}
