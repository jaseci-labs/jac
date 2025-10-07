"""Hook metadata for jac-cloud plugins."""


def get_cli_hooks():
    """Return list of hooks implemented by JacCmd plugin."""
    return ["create_cmd"]


def get_serve_hooks():
    """Return list of hooks implemented by JacPlugin (serve) plugin."""
    return [
        "setup",
        "get_context",
        "build_edge",
        "destroy",
        "detach",
        "edges_to_nodes",
        "get_edges",
        "get_object",
        "object_ref",
        "reset_graph",
        "root",
        "spawn",
        "allow_root",
        "disallow_root",
        "perm_grant",
        "perm_revoke",
        "check_access_level",
    ]
