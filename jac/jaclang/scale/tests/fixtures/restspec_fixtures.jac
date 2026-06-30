"""Test API fixture for restspec decorator tests."""

import from jaclang.runtimelib.builtin { restspec }
import from http { HTTPMethod }

# ============================================================================
# RestSpec Decorator Tests
# ============================================================================
"""Walker with GET method via restspec decorator."""
@restspec(method=HTTPMethod.GET)
walker:pub GetWalker {
    can get_data with Root entry {
        report {"message": "GetWalker executed", "method": "GET"};
    }
}

"""Walker with custom path."""
@restspec(method=HTTPMethod.GET, path="/custom/walker")
walker:pub CustomPathWalker {
    can get_data with Root entry {
        report {"message": "CustomPathWalker executed", "path": "/custom/walker"};
    }
}

"""Function with GET method via restspec decorator."""
@restspec(method=HTTPMethod.GET)
def get_func -> dict {
    return {"message": "get_func executed", "method": "GET"};
}

"""Function with custom path."""
@restspec(method=HTTPMethod.GET, path="/custom/func")
def custom_path_func -> dict {
    return {"message": "custom_path_func executed", "path": "/custom/func"};
}

"""Walker with POST method via restspec decorator."""
@restspec(method=HTTPMethod.POST)
walker:pub PostWalker {
    can post_data with Root entry {
        report {"message": "PostWalker executed", "method": "POST"};
    }
}

"""Walker with default method (POST)."""
walker:pub DefaultWalker {
    can post_data with Root entry {
        report {"message": "DefaultWalker executed", "method": "DEFAULT"};
    }
}

"""Function with POST method via restspec decorator."""
@restspec(method=HTTPMethod.POST)
def post_func -> dict {
    return {"message": "post_func executed", "method": "POST"};
}

"""Function with default method (POST)."""
def default_func -> dict {
    return {"message": "default_func executed", "method": "DEFAULT"};
}

"""Walker with GET method and parameters."""
@restspec(method=HTTPMethod.GET)
walker:pub GetWalkerWithParams {
    has name: str,
        age: int;

    can get_data with Root entry {
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
    return {"message": "get_func_with_params executed", "name": name, "age": age};
}

# ============================================================================
# Path Parameter Tests (regression for @restspec path param bug)
# ============================================================================
"""Function with a single path parameter."""
@restspec(method=HTTPMethod.GET, path="/items/{item_id}")
def get_item(item_id: str) -> dict {
    return {"message": "get_item executed", "item_id": item_id};
}

"""Function with a path parameter plus additional query parameters."""
@restspec(method=HTTPMethod.GET, path="/users/{user_id}/orders")
def get_user_orders(user_id: str, status: str = "all") -> dict {
    return {
        "message": "get_user_orders executed",
        "user_id": user_id,
        "status": status
    };
}

"""Function with multiple path parameters."""
@restspec(method=HTTPMethod.GET, path="/orgs/{org_id}/repos/{repo_id}")
def get_org_repo(org_id: str, repo_id: str) -> dict {
    return {"message": "get_org_repo executed", "org_id": org_id, "repo_id": repo_id};
}

"""POST function with a path parameter and body parameters."""
@restspec(method=HTTPMethod.POST, path="/resources/{resource_id}/update")
def update_resource(resource_id: str, name: str, value: int) -> dict {
    return {
        "message": "update_resource executed",
        "resource_id": resource_id,
        "name": name,
        "value": value
    };
}

"""Walker with a path parameter in its restspec path."""
@restspec(method=HTTPMethod.GET, path="/nodes/{node_id}")
walker:pub GetNodeWalker {
    has node_id: str;

    can get_data with Root entry {
        report {"message": "GetNodeWalker executed", "node_id": self.node_id};
    }
}

"""Walker with multiple path parameters in its restspec path."""
@restspec(method=HTTPMethod.GET, path="/projects/{project_id}/tasks/{task_id}")
walker:pub GetProjectTaskWalker {
    has project_id: str,
        task_id: str;

    can get_data with Root entry {
        report {
            "message": "GetProjectTaskWalker executed",
            "project_id": self.project_id,
            "task_id": self.task_id
        };
    }
}

node UserProfile {
    has user_id: str = "",
        name: str = "";
}

"""Walker to create a UserProfile node for testing."""
walker:pub CreateUserProfile {
    has user_id: str,
        name: str;

    can create_node with Root entry {
        profile = UserProfile(user_id=self.user_id, name=self.name);
        here ++> profile;
        report {
            "message": "UserProfile created",
            "node_id": str(profile.__jac__.id),
            "user_id": profile.user_id,
            "name": profile.name
        };
    }
}

walker:pub LoadUserProfile {
    can load_profile with UserProfile entry {
        report {
            "message": "LoadUserProfile executed on node",
            "node_id": str(here.__jac__.id),
            "user_id": here.user_id,
            "name": here.name
        };
    }
}

# ============================================================================
# Custom Object Body Parameter Tests
# ============================================================================
obj Address {
    has street: str,
        city: str;
}

obj UserBody {
    has name: str,
        age: int;
}

obj UserWithAddress {
    has name: str,
        address: Address;
}

"""Walker with a custom obj as a body parameter."""
walker:pub CreateUser {
    has user: UserBody;

    can create with Root entry {
        report {
            "message": "CreateUser executed",
            "name": self.user.name,
            "age": self.user.age,
            "user_type": type(self.user).__name__
        };
    }
}

"""Walker with a nested custom obj body parameter."""
walker:pub CreateUserWithAddress {
    has user: UserWithAddress;

    can create with Root entry {
        report {
            "message": "CreateUserWithAddress executed",
            "name": self.user.name,
            "street": self.user.address.street,
            "city": self.user.address.city,
            "address_type": type(self.user.address).__name__
        };
    }
}

"""Walker with a list of custom objs."""
walker:pub CreateUsers {
    has users: list[UserBody];

    can create with Root entry {
        report {
            "message": "CreateUsers executed",
            "count": len(self.users),
            "names": [u.name for u in self.users],
            "first_type": type(self.users[0]).__name__ if self.users else None
        };
    }
}

# ============================================================================
# Custom Object Body Parameter Tests — Functions
# ============================================================================
"""Function with a custom obj body parameter."""
@restspec(method=HTTPMethod.POST, path="/func/create_user")
def create_user_func(user: UserBody) -> dict {
    return {
        "message": "create_user_func executed",
        "name": user.name,
        "age": user.age,
        "user_type": type(user).__name__
    };
}

"""Function with a nested custom obj body parameter."""
@restspec(method=HTTPMethod.POST, path="/func/create_user_with_address")
def create_user_with_address_func(user: UserWithAddress) -> dict {
    return {
        "message": "create_user_with_address_func executed",
        "name": user.name,
        "street": user.address.street,
        "city": user.address.city,
        "address_type": type(user.address).__name__
    };
}

"""Function with a list of custom objs."""
@restspec(method=HTTPMethod.POST, path="/func/create_users")
def create_users_func(users: list[UserBody]) -> dict {
    return {
        "message": "create_users_func executed",
        "count": len(users),
        "names": [u.name for u in users],
        "first_type": type(users[0]).__name__ if users else None
    };
}

# ============================================================================
# Recursive Type Tests — self-referential obj via list[Self]
# ============================================================================
obj TreeNode {
    has name: str,
        children: list[TreeNode] = [];
}

def _tree_depth(n: TreeNode) -> int {
    return 1 + max([_tree_depth(c) for c in n.children], default=0);
}

def _tree_count(n: TreeNode) -> int {
    return 1 + sum([_tree_count(c) for c in n.children]);
}

"""Walker taking a recursive tree as a body parameter."""
walker:pub CreateTreeWalker {
    has `root: TreeNode;

    can create with Root entry {
        report {
            "message": "CreateTreeWalker executed",
            "root_name": self.root.name,
            "root_type": type(self.root).__name__,
            "child_type": type(self.root.children[0]).__name__
                if self.root.children
                else None,
            "depth": _tree_depth(self.root),
            "node_count": _tree_count(self.root)
        };
    }
}

"""Function taking a recursive tree as a body parameter."""
@restspec(method=HTTPMethod.POST, path="/func/create_tree")
def create_tree_func(`root: TreeNode) -> dict {
    return {
        "message": "create_tree_func executed",
        "root_name": `root.name,
        "root_type": type(`root).__name__,
        "child_type": type(`root.children[0]).__name__ if `root.children else None,
        "depth": _tree_depth(`root),
        "node_count": _tree_count(`root)
    };
}
