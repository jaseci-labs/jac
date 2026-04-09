"""Implementation for TTG Generator constructs."""

import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.archetype { VisitType }
import from jaclang.jac0core.constant { Tokens as Tok }

"""Resolve a VisitType field (type or string name) to a type name string."""
@classmethod
impl JacTTGGenerator._resolve_type_name(
    cls: type[JacTTGGenerator], ref: (type | str | None)
) -> (str | None) {
    if ref is None {
        return None;
    }
    if isinstance(ref, str) {
        return ref;
    }
    return ref.__name__;
}

"""Find the AST Archetype node for a walker class.

Looks up the AST Module from the program hub first. On a hub miss,
deserializes the module's JIR cache via JirReader and stores the result
in the hub so subsequent calls are free.
"""
@classmethod
impl JacTTGGenerator._find_walker_ast_node(
    cls: type[JacTTGGenerator], warch_cls: type
) -> (uni.Archetype | None) {
    import from jaclang.jac0core.runtime { JacRuntime }
    program = JacRuntime.get_program();
    module_name = warch_cls.__module__;
    class_name = warch_cls.__name__;
    # Get the Python module to find its file path.
    py_module = JacRuntime.loaded_modules.get(module_name);
    if py_module is None {
        import sys;
        py_module = sys.modules.get(module_name);
    }
    if py_module is None {
        return None;
    }
    file_path = getattr(py_module, '__file__', None);
    if file_path is None {
        return None;
    }
    # Look up the AST Module from the program hub.
    ast_module = program.mod.hub.get(file_path);
    if ast_module is None {
        # Hub miss — deserialize from JIR cache.
        try {
            import from jaclang.jac0core.jir {
                get_module_cache_path,
                is_module_cache_valid
            }
            import from jaclang.jac0core.jir_passes { JirReader }
            cache_path = get_module_cache_path(file_path);
            if is_module_cache_valid(file_path, cache_path) {
                reader = JirReader(_source_path=file_path);
                ast_module = reader.read_module(cache_path.read_bytes());
                if ast_module is not None {
                    program.mod.hub[file_path] = ast_module;
                }
            }
        } except Exception {
            ;
        }
    }
    if ast_module is None {
        return None;
    }
    # Search for the walker archetype in this module.
    for arch in ast_module.get_all_sub_nodes(uni.Archetype) {
        if (arch.arch_type.name == Tok.KW_WALKER and arch.name.value == class_name) {
            return arch;
        }
    }
    return None;
}

"""Resolve a name to an Archetype AST node via symbol table lookup."""
@classmethod
impl JacTTGGenerator._resolve_archetype(
    cls: type[JacTTGGenerator], scope_src: uni.UniNode, name: str
) -> (uni.Archetype | None) {
    scope = scope_src.find_parent_of_type(uni.UniScopeNode);
    if scope is None {
        return None;
    }
    result = scope.lookup(name);
    if result is None {
        return None;
    }
    return result.decl.find_parent_of_type(uni.Archetype);
}

"""Extract edge type and optional node filter from an EdgeOpRef or FilterCompr."""
@classmethod
impl JacTTGGenerator._extract_edge_step(
    cls: type[JacTTGGenerator], scope: uni.UniNode, item: uni.UniNode
) -> tuple[str | None, str | None, int] {
    edge_type_name: (str | None) = None;
    node_filter_name: (str | None) = None;
    direction = 2;  # Default: outgoing
    # Check if this is an EdgeOpRef
    if isinstance(item, uni.EdgeOpRef) {
        fc = getattr(item, 'filter_cond', None);
        if fc is not None {
            # Extract edge type from f_type
            ft = getattr(fc, 'f_type', None);
            if ft is not None {
                # Check if f_type is already a Name/Token directly
                type_name: (str | None) = None;
                if isinstance(ft, uni.Name) {
                    type_name = ft.value;
                } else {
                    # Search for Name sub_nodes
                    names = ft.get_all_sub_nodes(uni.Name);
                    if (len(names) > 0) {
                        type_name = names[0].value;
                    }
                }
                if type_name is not None {
                    edge_arch = cls._resolve_archetype(scope, type_name);
                    if edge_arch is not None {
                        edge_type_name = edge_arch.name.value;
                    }
                }
            }
        }
        # Extract direction
        edge_dir = getattr(item, 'edge_dir', None);
        if edge_dir is not None {
            dir_name = getattr(edge_dir, 'name', '');
            if 'IN' in str(dir_name) {
                direction = 1;
            } elif 'OUT' in str(dir_name) {
                direction = 2;
            } else {
                direction = 3;  # Both
            }
        }
    } elif isinstance(item, uni.FilterCompr) {
        # This is a node filter like [?:Profile]
        ft = getattr(item, 'f_type', None);
        if ft is not None {
            # Check if f_type is already a Name/Token directly
            type_name: (str | None) = None;
            if isinstance(ft, uni.Name) {
                type_name = ft.value;
            } else {
                names = ft.get_all_sub_nodes(uni.Name);
                if (len(names) > 0) {
                    type_name = names[0].value;
                }
            }
            if type_name is not None {
                node_arch = cls._resolve_archetype(scope, type_name);
                if node_arch is not None {
                    node_filter_name = node_arch.name.value;
                }
            }
        }
    }
    return (edge_type_name, node_filter_name, direction);
}

"""Extract visit types from a walker's AST at runtime.

Finds the walker's AST Archetype node, then for each ability with an
EventSignature extracts the from-node type, and for each VisitStmt
extracts the full edge chain from EdgeRefTrailer. Results are
returned as VisitType instances and cached on the walker class.
"""
@classmethod
impl JacTTGGenerator._extract_visits_from_ast(
    cls: type[JacTTGGenerator], warch: Any
) -> list[VisitType] {
    warch_cls = `type(warch);
    # Check cache first.
    cached = getattr(warch_cls, '__jac_ttg_visits__', None);
    if (cached is not None and len(cached) > 0) {
        return cached;
    }
    # Find the AST node for this walker.
    ast_node = cls._find_walker_ast_node(warch_cls);
    if ast_node is None {
        return [];
    }
    # Extract visits using the same logic as the old JacTTGPass.
    result: list[VisitType] = [];
    abilities = ast_node.get_all_sub_nodes(uni.Ability);
    for ability in abilities {
        event_sigs = ability.get_all_sub_nodes(uni.EventSignature);
        if (len(event_sigs) == 0) {
            continue;
        }
        # Determine the from-node type from the event signature.
        node_type_name: (str | None) = None;
        node_type_names = event_sigs[0].get_all_sub_nodes(uni.Name);
        if (len(node_type_names) > 0) {
            node_arch = cls._resolve_archetype(
                node_type_names[0], node_type_names[0].value
            );
            if node_arch is not None {
                node_type_name = node_arch.name.value;
            }
        }
        # Collect visit statements within this ability.
        visit_stmts = ability.get_all_sub_nodes(uni.VisitStmt);
        for visit_stmt in visit_stmts {
            # Build the edge chain from EdgeRefTrailer or EdgeOpRef nodes
            edge_chain: list[tuple[str | None, str | None, int]] = [];
            # First, try to get EdgeRefTrailer which contains the full chain
            edge_trailers = visit_stmt.get_all_sub_nodes(uni.EdgeRefTrailer);
            if (len(edge_trailers) > 0) {
                trailer = edge_trailers[0];
                chain_items = getattr(trailer, 'chain', []);
                for item in chain_items {
                    step = cls._extract_edge_step(visit_stmt, item);
                    # Only add if it has edge type (skip pure node filters for now)
                    if step[0] is not None {
                        edge_chain.append(step);
                    } elif step[1] is not None {
                        # Node filter - attach to previous step if exists
                        if (len(edge_chain) > 0) {
                            prev = edge_chain[-1];
                            edge_chain[-1] = (prev[0], step[1], prev[2]);
                        }
                    }
                }
            }
            # Fallback: extract from EdgeOpRef nodes directly
            if (len(edge_chain) == 0) {
                edge_refs = visit_stmt.get_all_sub_nodes(uni.EdgeOpRef);
                for edge_ref in edge_refs {
                    step = cls._extract_edge_step(visit_stmt, edge_ref);
                    if step[0] is not None {
                        edge_chain.append(step);
                    }
                }
            }
            # Create VisitType with edge_chain
            # For backwards compatibility, also set edge_type to first edge
            first_edge = edge_chain[0][0] if (len(edge_chain) > 0) else None;
            result.append(
                VisitType(
                    from_node_type=node_type_name,
                    edge_type=first_edge,
                    edge_chain=edge_chain if (len(edge_chain) > 0) else None
                )
            );
        }
    }
    # Cache on the class for subsequent calls.
    warch_cls.__jac_ttg_visits__ = result;
    return result;
}

"""Build a prefetch list by BFS over the topology index.

Single-pass BFS that resolves neighbors via resolve_chain() and collects
UUIDs for cache prefetching. Stops as soon as max_length nodes are found,
avoiding full graph traversal.

Supports multihop patterns: for visit [->:Follow:->->:Post:->], the full
chain is resolved in one call to resolve_chain(), directly reaching the
target nodes without intermediate BFS steps.
"""
@classmethod
impl JacTTGGenerator.get_ttg_prefetch_list(
    cls: type[JacTTGGenerator],
    warch: Any,
    start_id: UUID,
    topology_index: Any,
    max_length: int = 200
) -> list[UUID] {
    visits = cls._extract_visits_from_ast(warch);
    prefetch: list[UUID] = [start_id];
    seen: set[UUID] = {start_id};
    queue: list[UUID] = [start_id];
    while queue {
        if (len(prefetch) >= max_length) {
            break;
        }
        cur = queue.pop(0);
        # Resolve the type name of cur for from_node_type filtering.
        cur_lid = topology_index.node_to_lid.get(cur);
        cur_type = topology_index.type_table[topology_index.node_table[cur_lid][1]]
            if cur_lid is not None
            else None;
        for v in visits {
            # Skip if this visit only applies to a different node type.
            from_type = cls._resolve_type_name(v.from_node_type)
                if isinstance(v, VisitType)
                else None;
            if from_type is not None and cur_type != from_type {
                continue;
            }
            # Build the chain from edge_chain if available, else fallback to edge_type
            if isinstance(v, VisitType) and v.edge_chain is not None {
                # Use full multihop chain
                chain = v.edge_chain;
            } elif isinstance(v, VisitType) {
                edge_name = cls._resolve_type_name(v.edge_type);
                chain = [(edge_name, None, 2)];
            } else {
                chain = [(None, None, 2)];
            }
            for tgt in topology_index.resolve_chain({cur}, chain) {
                if tgt not in seen {
                    seen.add(tgt);
                    prefetch.append(tgt);
                    queue.append(tgt);
                    if (len(prefetch) >= max_length) {
                        break;
                    }
                }
            }
            if (len(prefetch) >= max_length) {
                break;
            }
        }
    }
    return prefetch;
}
