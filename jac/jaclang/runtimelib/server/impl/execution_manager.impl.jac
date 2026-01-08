"""ExecutionManager implementations."""
import from collections.abc { Callable }
import from typing { Any }
import from jaclang.runtimelib.server.execution_manager { ExecutionManager }
import from jaclang.runtimelib.server.serializer { JacSerializer }
import from jaclang.runtimelib.server.types { JsonValue }
import from jaclang { JacRuntime as Jac }

with entry {
    import from jaclang.pycore.constructs { WalkerArchetype }
}

"""Execute a function in user's context."""
impl ExecutionManager.execute_function(
    func: Callable[(..., Any)], args: dict[(str, Any)], username: str
) -> dict[str, JsonValue] {
    root_id = self.user_manager.get_root_id(username);
    if not root_id {
        return {'error': 'User not found'};
    }
    # Use existing context and set entry node to user's root (avoids shelf locking issues)
    ctx = Jac.get_context();
    ctx.set_entry_node(root_id);
    ctx.reports = [];  # Clear reports for this request
    try {
        result = func(**args);
        Jac.commit();
        return {
            'result': JacSerializer.serialize(result),
            'reports': JacSerializer.serialize(ctx.reports)
        };
    } except Exception as e {
        return {'error': str(e)};
    }
}

"""Spawn a walker in user's context."""
impl ExecutionManager.spawn_walker(
    walker_cls: type[WalkerArchetype], fields: dict[(str, Any)], username: str
) -> dict[str, JsonValue] {
    import from jaclang.pycore.constructs { NodeArchetype }
    root_id = self.user_manager.get_root_id(username);
    if not root_id {
        return {'error': 'User not found'};
    }
    target_node_id = fields.pop('_jac_spawn_node', None);
    # Use existing context and set entry node to user's root (avoids shelf locking issues)
    ctx = Jac.get_context();
    ctx.set_entry_node(root_id);
    ctx.reports = [];  # Clear reports for this request
    try {
        <>walker = walker_cls(**fields);
        if target_node_id {
            target_node = Jac.get_object(target_node_id);
            if not isinstance(target_node, NodeArchetype) {
                return {'error': f"Invalid target node: {target_node_id}"};
            }
        } else {
            target_node = ctx.get_root();
        }
        Jac.spawn(<>walker, target_node);
        return {
            'result': JacSerializer.serialize(<>walker),
            'reports': JacSerializer.serialize(ctx.reports)
        };
    } except Exception as e {
        import traceback;
        return {'error': str(e), 'traceback': traceback.format_exc()};
    }
}

