"""Tests for AST serialization and deserialization.
Verifies that the Jac AST can be serialized to disk via pickle and
correctly deserialized at runtime, preserving tree structure, token
data, node types, and all information needed by the TTG (Temporal
Trace Graph) generator pass.
"""
import os;
import pickle;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.unitree {
    UniNode,
    Module,
    Token,
    Name,
    UniScopeNode,
    NameAtom,
    Expr,
    Symbol,
    Archetype,
    Ability,
    EventSignature,
    VisitStmt,
    EdgeOpRef,
    FilterCompr
}
import from jaclang.jac0core.bccache { DiskBytecodeCache, CacheKey }
import from jaclang.jac0core.compiler { _recalculate_parents }
import from jaclang.jac0core.passes.uni_pass { UniPass }
import from jaclang.jac0core.constant { Tokens as Tok }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     EXAMPLES = os.path.join(JAC_ROOT, "examples");

test "basic ast pickle roundtrip" {
    """Test that a compiled AST can be pickled and unpickled."""
    prog = JacProgram();
    prog.compile(os.path.join(EXAMPLES, "micro", "hodge_podge.jac"));
    assert len(prog.errors_had) == 0;
    # Get the main module from hub
    main_mod: (Module | None) = None;
    for (path, mod) in prog.mod.hub.items() {
        if path.endswith("hodge_podge.jac") {
            main_mod = mod;
            break;
        }
    }
    assert main_mod is not None , "hodge_podge module not found in hub";
    # Serialize and deserialize
    data = pickle.dumps(main_mod, protocol=pickle.HIGHEST_PROTOCOL);
    assert data , "pickle data should be non-empty";
    restored: Module = pickle.loads(data);
    # Rebuild parent pointers
    _recalculate_parents(restored);
    # Verify it's a Module
    assert isinstance(restored, Module);
    assert restored.name == main_mod.name;
}

test "tree structure preserved after roundtrip" {
    """Test that the tree structure (kid counts, node types) is preserved."""
    prog = JacProgram();
    code = 'with entry { x = 1 + 2; print(x); }';
    result = prog.compile(use_str=code, file_path="test_tree.jac");
    assert result is not None;
    # result is the Module directly from compile()
    main_mod = result;
    original_kid_count: int = len(main_mod.kid);
    original_flat = main_mod.flatten();
    original_types = [`type(n).__name__ for n in original_flat];
    original_count: int = len(original_flat);
    # Roundtrip
    data = pickle.dumps(main_mod, protocol=pickle.HIGHEST_PROTOCOL);
    restored: Module = pickle.loads(data);
    _recalculate_parents(restored);
    restored_flat = restored.flatten();
    restored_types = [`type(n).__name__ for n in restored_flat];
    restored_count: int = len(restored_flat);
    assert len(restored.kid) == original_kid_count;
    assert restored_count == original_count;
    assert restored_types == original_types;
}

test "token data preserved after roundtrip" {
    """Test that Token values, line numbers, etc. are preserved."""
    prog = JacProgram();
    code = 'glob message = "hello world";';
    result = prog.compile(use_str=code, file_path="test_token.jac");
    assert result is not None;
    main_mod = result;
    # Collect original tokens
    original_tokens = [
        n
        for n in main_mod.flatten()
        if isinstance(n, Token)
    ];
    # Roundtrip
    data = pickle.dumps(main_mod, protocol=pickle.HIGHEST_PROTOCOL);
    restored: Module = pickle.loads(data);
    _recalculate_parents(restored);
    restored_tokens = [
        n
        for n in restored.flatten()
        if isinstance(n, Token)
    ];
    original_token_count: int = len(original_tokens);
    restored_token_count: int = len(restored_tokens);
    assert restored_token_count == original_token_count;
    for (orig, rest) in zip(original_tokens, restored_tokens) {
        assert orig.value == rest.value;
        assert orig.name == rest.name;
        assert orig.line_no == rest.line_no;
    }
}

test "parent pointers rebuilt correctly" {
    """Test that _recalculate_parents correctly rebuilds parent pointers."""
    prog = JacProgram();
    code = 'can foo(x: int) -> int { return x + 1; }';
    result = prog.compile(use_str=code, file_path="test_parents.jac");
    assert result is not None;
    # Use the compiled result directly instead of looking up in hub
    data = pickle.dumps(result, protocol=pickle.HIGHEST_PROTOCOL);
    restored: Module = pickle.loads(data);
    # Before _recalculate_parents, parent should be None (excluded from state)
    for kid in restored.kid {
        assert kid.parent is None;
    }
    # Rebuild parents
    _recalculate_parents(restored);
    # After rebuild, parent should point back correctly
    for kid in restored.kid {
        assert kid.parent is restored;
    }
}

test "disk cache ast roundtrip" {
    """Test AST save/load through DiskBytecodeCache."""
    import tempfile;
    # Create a real temp .jac file so _is_valid can check mtime
    tmp_dir = tempfile.mkdtemp();
    tmp_file = os.path.join(tmp_dir, "test_cache.jac");
    with open(tmp_file, 'w') as f {
        f.write('with entry { print("cache test"); }');
    }
    prog = JacProgram();
    result = prog.compile(file_path=tmp_file);
    assert result is not None;
    assert len(prog.errors_had) == 0;
    main_mod: (Module | None) = None;
    for (path, mod) in prog.mod.hub.items() {
        if "test_cache" in path {
            main_mod = mod;
            break;
        }
    }
    assert main_mod is not None;
    # Create a cache and test put/get
    cache = DiskBytecodeCache();
    cache_key = CacheKey.for_source(tmp_file);
    # First store the bytecode so _is_valid has a reference for mtime comparison
    cache.put(cache_key, main_mod.gen.py_bytecode);
    # Now store and retrieve AST
    cache.put_ast(cache_key, main_mod);
    loaded_raw = cache.get_ast(cache_key);
    assert loaded_raw is not None;
    assert isinstance(loaded_raw, Module);
    if loaded_raw is not None {
        _recalculate_parents(loaded_raw);
        # Verify tree matches
        original_flat = main_mod.flatten();
        loaded_flat = loaded_raw.flatten();
        original_flat_count: int = len(original_flat);
        loaded_flat_count: int = len(loaded_flat);
        assert loaded_flat_count == original_flat_count;
    }
    # Cleanup
    import shutil;
    shutil.rmtree(tmp_dir, ignore_errors=True);
}

test "default fields restored after deserialization" {
    """Test that excluded fields get proper defaults and symtab fields are preserved."""
    prog = JacProgram();
    code = 'can bar() { pass; }';
    result = prog.compile(use_str=code, file_path="test_defaults.jac");
    assert result is not None;
    main_mod = result;
    data = pickle.dumps(main_mod, protocol=pickle.HIGHEST_PROTOCOL);
    restored: Module = pickle.loads(data);
    # Check UniNode defaults for transient fields
    assert restored._gen is None;
    assert restored._in_mod_nodes == [];
    # Check UniScopeNode — symtab fields are now PRESERVED (not reset)
    assert isinstance(restored, UniScopeNode);
    # Module has no parent_scope (top-level)
    assert restored.parent_scope is None;
    # Symbol table should be preserved — 'bar' was defined in this module
    assert len(restored.names_in_scope) > 0 , "names_in_scope should be preserved";
    assert 'bar' in restored.names_in_scope , "'bar' should be in names_in_scope";
    # kid_scope should have at least the Ability scope for 'bar'
    assert len(restored.kid_scope) > 0 , "kid_scope should be preserved";
}

test "symbol table preserved after roundtrip" {
    """Test that symbol tables and symbol references survive serialization."""
    prog = JacProgram();
    code = 'glob greeting = "hello";\ncan add(x: int, y: int) -> int { return x + y; }';
    result = prog.compile(use_str=code, file_path="test_symtab.jac");
    assert result is not None;
    main_mod = result;
    # Verify original has symbols before roundtrip
    assert len(main_mod.names_in_scope) > 0 , "pre-roundtrip: names_in_scope empty";
    # Roundtrip
    data = pickle.dumps(main_mod, protocol=pickle.HIGHEST_PROTOCOL);
    restored: Module = pickle.loads(data);
    _recalculate_parents(restored);
    # 1. names_in_scope preserved
    assert len(restored.names_in_scope) > 0 , "names_in_scope should be non-empty";
    assert 'greeting' in restored.names_in_scope , "'greeting' should be in scope";
    assert 'add' in restored.names_in_scope , "'add' should be in scope";
    # 2. lookup returns a Symbol
    sym = restored.lookup('add', deep=False);
    assert sym is not None , "lookup('add') should return a Symbol";
    assert isinstance(sym, Symbol);
    assert sym.sym_name == 'add';
    # 3. Symbol.defn points to a NameAtom with correct _sym back-reference
    assert len(sym.defn) > 0 , "Symbol should have at least one defn";
    defn_node = sym.defn[0];
    assert isinstance(defn_node, NameAtom);
    assert defn_node._sym is sym , "NameAtom._sym should point back to the Symbol";
    # 4. Symbol.parent_tab points back to the module scope
    assert sym.parent_tab is restored , "Symbol.parent_tab should reference the module";
    # 5. kid_scope chain — 'add' ability should have its own scope
    assert len(restored.kid_scope) > 0 , "Module should have kid scopes";
    ability_scope = None;
    for ks in restored.kid_scope {
        if ks?.scope_name and 'add' in str(ks.scope_name) {
            ability_scope = ks;
            break;
        }
    }
    if ability_scope is not None {
        assert ability_scope.parent_scope is restored , "Ability scope parent should be module";
        # Parameters should be in the ability's scope
        assert len(ability_scope.names_in_scope) > 0 , "Ability scope should have params";
    }
}

test "get_ast loads on demand from disk cache" {
    """Test that JacProgram.get_ast() lazily loads AST from disk cache."""
    import tempfile;
    tmp_dir = tempfile.mkdtemp();
    tmp_file = os.path.join(tmp_dir, "test_lazy.jac");
    with open(tmp_file, 'w') as f {
        f.write('with entry { print("lazy load"); }');
    }
    resolved = os.path.realpath(tmp_file);
    # Use get_bytecode to trigger compilation + disk cache write (put_ast).
    prog = JacProgram();
    bc = prog.get_bytecode(resolved);
    assert bc is not None;
    # The module should now be in the hub from compilation.
    assert resolved in prog.mod.hub;
    # Remove from hub to simulate a fresh process.
    del prog.mod.hub[resolved];
    assert resolved not in prog.mod.hub;
    # get_ast should load it from disk cache on demand.
    loaded = prog.get_ast(resolved);
    assert loaded is not None;
    assert isinstance(loaded, Module);
    # Now it should be back in the hub.
    assert resolved in prog.mod.hub;
    # Cleanup
    import shutil;
    shutil.rmtree(tmp_dir, ignore_errors=True);
}

# --- TTG-relevant Jac source for roundtrip tests ---
# This mimics the constructs TTG needs: walkers, nodes, edges,
# event signatures, visit statements with edge type filters.
# These tests use DiskBytecodeCache (the real production code path)
# to serialize/deserialize ASTs via disk rather than in-memory pickle.
import tempfile;
import shutil;

def _compile_ttg_source -> tuple {
    """Compile a TTG-like source from a temp file and return (Module, tmp_dir, tmp_file)."""
    ttg_code = (
        "edge BasicEdge {}\n"
        "edge SpecialEdge {}\n"
        "node TypeA { has val: int; }\n"
        "node TypeB { has val: int; }\n"
        "walker TTGWalker {\n"
        "    has visited: list[int] = [];\n"
        "    can enter_root with Root entry { visit [->:BasicEdge:->]; }\n"
        "    can run with TypeA entry {\n"
        "        self.visited.append(here.val);\n"
        "        visit [->:BasicEdge:->];\n"
        "    }\n"
        "}\n"
    );
    tmp_dir = tempfile.mkdtemp();
    tmp_file = os.path.join(tmp_dir, "test_ttg.jac");
    with open(tmp_file, 'w') as f {
        f.write(ttg_code);
    }
    prog = JacProgram();
    result = prog.compile(file_path=tmp_file);
    assert result is not None , "TTG source should compile without errors";
    # Find the module from hub
    main_mod: (Module | None) = None;
    for (path, mod) in prog.mod.hub.items() {
        if "test_ttg" in path {
            main_mod = mod;
            break;
        }
    }
    assert main_mod is not None , "test_ttg module not found in hub";
    return (main_mod, tmp_dir, tmp_file);
}

def _roundtrip_via_disk_cache(main_mod: Module, tmp_file: str) -> Module {
    """Roundtrip an AST through DiskBytecodeCache (the production code path)."""
    cache = DiskBytecodeCache();
    cache_key = CacheKey.for_source(tmp_file);
    # Store bytecode first so _is_valid has a reference for mtime comparison
    cache.put(cache_key, main_mod.gen.py_bytecode);
    # Store AST to disk
    cache.put_ast(cache_key, main_mod);
    # Load AST from disk
    loaded = cache.get_ast(cache_key);
    assert loaded is not None , "DiskBytecodeCache.get_ast should return the cached AST";
    assert isinstance(loaded, Module);
    _recalculate_parents(loaded);
    return loaded;
}

def _check_edge_filter(vs: VisitStmt) {
    """Validate that a VisitStmt has EdgeOpRef with FilterCompr containing BasicEdge."""
    edge_refs = UniPass.get_all_sub_nodes(vs, EdgeOpRef);
    assert len(edge_refs) > 0 , "VisitStmt should have EdgeOpRef children";
    edge_ref = edge_refs[0];
    fc = getattr(edge_ref, 'filter_cond', None);
    assert fc is not None , "EdgeOpRef should have filter_cond for typed edge";
    assert isinstance(fc, FilterCompr) , "filter_cond should be a FilterCompr";
    names = UniPass.get_all_sub_nodes(fc, Name);
    assert len(names) > 0 , "FilterCompr should have Name children for edge type";
    assert names[0].value == "BasicEdge" , "Edge type name should be BasicEdge";
}

def _resolve_archetype_from_name(name_node: Name) -> (Archetype | None) {
    """Resolve a Name node to its Archetype via symbol table (mimics TTG _resolve_archetype)."""
    scope = UniPass.find_parent_of_type(name_node, UniScopeNode);
    if scope is None {
        return None;
    }
    sym = scope.lookup(name_node.value);
    if sym is None or len(sym.defn) == 0 {
        return None;
    }
    return UniPass.find_parent_of_type(sym.defn[0], Archetype);
}

test "walker archetype findable in deserialized AST" {
    # TTG pass needs to find walker archetypes via arch_type.name == KW_WALKER.
    (result, tmp_dir, tmp_file) = _compile_ttg_source();
    try {
        restored = _roundtrip_via_disk_cache(result, tmp_file);
        # Find all Archetype nodes in the deserialized AST
        archetypes = UniPass.get_all_sub_nodes(restored, Archetype);
        assert len(archetypes) > 0 , "Should find at least one Archetype after roundtrip";
        # Find walker archetypes specifically (how TTG enter_archetype filters)
        walkers = [
            a
            for a in archetypes
            if a.arch_type.name == Tok.KW_WALKER
        ];
        assert len(walkers) == 1 , "Should find exactly 1 walker archetype";
        assert walkers[0].sym_name == "TTGWalker";
        # Verify node and edge archetypes are also present
        nodes = [
            a
            for a in archetypes
            if a.arch_type.name == Tok.KW_NODE
        ];
        edges = [
            a
            for a in archetypes
            if a.arch_type.name == Tok.KW_EDGE
        ];
        assert len(nodes) == 2 , "Should find TypeA and TypeB nodes";
        assert len(edges) == 2 , "Should find BasicEdge and SpecialEdge";
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "walker abilities with event signatures preserved" {
    # TTG pass extracts Ability + EventSignature from walker archetypes.
    (result, tmp_dir, tmp_file) = _compile_ttg_source();
    try {
        restored = _roundtrip_via_disk_cache(result, tmp_file);
        # Find the walker archetype
        archetypes = UniPass.get_all_sub_nodes(restored, Archetype);
        walkers_list = [
            a
            for a in archetypes
            if a.arch_type.name == Tok.KW_WALKER
        ];
        warch_node = walkers_list[0];
        # TTG pass: get_all_sub_nodes(warch_node, Ability)
        abilities = UniPass.get_all_sub_nodes(warch_node, Ability);
        assert len(abilities) == 2 , "TTGWalker should have 2 abilities (enter_root, run)";
        # TTG pass: for each ability, get EventSignature
        event_count = 0;
        for ability in abilities {
            event_sigs = UniPass.get_all_sub_nodes(ability, EventSignature);
            if len(event_sigs) > 0 {
                event_count += 1;
                esig = event_sigs[0];
                assert esig.event is not None , "EventSignature.event should exist";
            }
        }
        assert event_count == 2 , "Both abilities should have EventSignatures";
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "visit statements with edge type filters preserved" {
    # TTG pass extracts VisitStmt + EdgeOpRef + FilterCompr from abilities.
    (result, tmp_dir, tmp_file) = _compile_ttg_source();
    try {
        restored = _roundtrip_via_disk_cache(result, tmp_file);
        # Find walker abilities
        archetypes = UniPass.get_all_sub_nodes(restored, Archetype);
        walkers_list = [
            a
            for a in archetypes
            if a.arch_type.name == Tok.KW_WALKER
        ];
        warch_node = walkers_list[0];
        abilities = UniPass.get_all_sub_nodes(warch_node, Ability);
        # Collect all visit stmts across abilities
        all_visit_stmts: list = [];
        for ability in abilities {
            visit_stmts = UniPass.get_all_sub_nodes(ability, VisitStmt);
            all_visit_stmts.extend(visit_stmts);
        }
        assert len(all_visit_stmts) == 2 , "Should find 2 visit statements total across abilities";
        # Validate each visit statement's edge filter via helper
        for vs in all_visit_stmts {
            _check_edge_filter(vs);
        }
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "symbol table lookup resolves archetypes after roundtrip" {
    # TTG _resolve_archetype does scope.lookup(name) then find_parent_of_type(Archetype)
    # to the actual Archetype AST node via preserved symbol tables.
    (result, tmp_dir, tmp_file) = _compile_ttg_source();
    try {
        restored = _roundtrip_via_disk_cache(result, tmp_file);
        # Module-level symbol table should contain all archetypes
        for name in ["BasicEdge", "SpecialEdge", "TypeA", "TypeB", "TTGWalker"] {
            sym = restored.lookup(name, deep=False);
            assert sym is not None , f"lookup('{name}') should succeed on deserialized module";
            assert isinstance(sym, Symbol);
            assert sym.sym_name == name;
            # TTG: find_parent_of_type(sym.decl, Archetype) should return the archetype
            assert len(sym.defn) > 0 , f"Symbol '{name}' should have defn";
            arch = UniPass.find_parent_of_type(sym.defn[0], Archetype);
            assert arch is not None , f"Should resolve '{name}' to an Archetype via parent chain";
            assert isinstance(arch, Archetype);
            assert arch.sym_name == name;
        }
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "TTG full pipeline simulation on deserialized AST" {
    # Simulate the complete JacTTGPass pipeline on deserialized AST.
    # Performs: find walkers, extract abilities, get event signatures for
    # node types, find visit statements, extract edge types from filters,
    # resolve all type names to Archetype nodes via symbol table.
    (result, tmp_dir, tmp_file) = _compile_ttg_source();
    try {
        restored = _roundtrip_via_disk_cache(result, tmp_file);
        # Step 1: Find walker archetypes (enter_archetype)
        archetypes = UniPass.get_all_sub_nodes(restored, Archetype);
        walkers = [
            a
            for a in archetypes
            if a.arch_type.name == Tok.KW_WALKER
        ];
        assert len(walkers) == 1;
        warch = walkers[0];
        # Step 2: Extract abilities (_get_visits_for_walker)
        abilities = UniPass.get_all_sub_nodes(warch, Ability);
        assert len(abilities) == 2;
        # Step 3: For each ability, extract (from_node_type, edge_type) pairs
        ttg_visits: list = [];
        for ability in abilities {
            # Get event signature for node type
            event_sigs = UniPass.get_all_sub_nodes(ability, EventSignature);
            node_archetype: (Archetype | None) = None;
            if len(event_sigs) > 0 {
                node_type_names = UniPass.get_all_sub_nodes(event_sigs[0], Name);
                if len(node_type_names) > 0 {
                    node_archetype = _resolve_archetype_from_name(node_type_names[0]);
                }
            }
            # Get visit stmts for edge types
            visit_stmts = UniPass.get_all_sub_nodes(ability, VisitStmt);
            for vs in visit_stmts {
                edge_archetype: (Archetype | None) = None;
                edge_refs = UniPass.get_all_sub_nodes(vs, EdgeOpRef);
                if len(edge_refs) > 0 {
                    fc = getattr(edge_refs[0], 'filter_cond', None);
                    if fc is not None {
                        names = UniPass.get_all_sub_nodes(fc, Name);
                        if len(names) > 0 {
                            edge_archetype = _resolve_archetype_from_name(names[0]);
                        }
                    }
                }
                ttg_visits.append((node_archetype, edge_archetype));
            }
        }
        # Verify results: should have 2 visit entries
        assert len(ttg_visits) == 2 , f"Expected 2 TTG visit entries, got {len(
            ttg_visits
        )}";
        # At least one should have edge_archetype resolved to BasicEdge
        edge_names: list = [];
        for pair in ttg_visits {
            e = pair[1];
            edge_names.append(e.sym_name if e is not None else None);
        }
        assert "BasicEdge" in edge_names , f"Should resolve BasicEdge archetype, got {edge_names}";
        # The TypeA node type should resolve for the 'run with TypeA entry' ability
        node_names: list = [];
        for pair in ttg_visits {
            n = pair[0];
            node_names.append(n.sym_name if n is not None else None);
        }
        assert "TypeA" in node_names , f"Should resolve TypeA archetype, got {node_names}";
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}
