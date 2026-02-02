
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

"""Walker with POST method via restspec decorator."""
@restspec(method=HTTPMethod.POST)
walker : pub PostWalker {
    can post_data with `root entry {
        report {"message": "PostWalker executed", "method": "POST"};
    }
}

"""Walker with default method (POST)."""
walker : pub DefaultWalker {
    can post_data with `root entry {
        report {"message": "DefaultWalker executed", "method": "DEFAULT"};
    }
}

"""Function with POST method via restspec decorator."""
@restspec(method=HTTPMethod.POST)
def post_func() -> dict {
    return {"message": "post_func executed", "method": "POST"};
}

"""Function with default method (POST)."""
def default_func() -> dict {
    return {"message": "default_func executed", "method": "DEFAULT"};
}

"""Walker with GET method and parameters."""
@restspec(method=HTTPMethod.GET)
walker : pub GetWalkerWithParams {
    has name: str;
    has age: int;

    can get_data with `root entry {
        report {
            "message": "GetWalkerWithParams executed",
            "name": self.name,
            "age": self.age
        };
    }
}

"""Function with GET method and parameters."""
@restspec(method=HTTPMethod.GET)
def get_func_with_params(name: str, age: int) -> dict {
    return {
        "message": "get_func_with_params executed",
        "name": name,
        "age": age
    };
}
