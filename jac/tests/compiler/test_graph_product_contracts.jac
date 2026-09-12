"""Compiler graph permissions, canonical relations and product commit boundaries."""

import gc;
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.ir.schema {
    Module,
    Name,
    Int,
    Symbol,
    ScopeBinding,
    NameRole
}
import from jaclang.compiler.ir.identity {
    MutationPermit,
    MutationScope,
    RelationFamily
}
import from jaclang.compiler.ir.mutation { validate_connection, validate_graph }
import from jaclang.compiler.pipeline.products { ProductStore, product_path }
import from jaclang.compiler.pipeline.keys { SPACES }
import from jaclang.compiler.pipeline.contracts {
    CompilationProduct,
    ProductTask,
    TaskState,
    ProductUnavailable
}
import from jaclang.compiler.analysis.placement.products { PlacementSpaces }
import from jaclang.compiler.session.modules { ModuleHub }
import from jaclang.compiler.session.cache.keys { module_revision }


test "failed tasks never expose their staged product" {
    store = ProductStore();
    module = Module.make_stub(inject_name='failed');
    record = store.module(module);
    address = (record.identity, CompilationProduct.SPACES, '');
    task = ProductTask(CompilationProduct.SPACES, TaskState.RUNNING);
    record.tasks[(CompilationProduct.SPACES, '')] = task;
    store.active.append(address);
    value = PlacementSpaces();
    store.publish(product_path(module), SPACES, value);
    assert store.lookup(product_path(module), SPACES) is value;
    store.active.pop();
    assert store.lookup(product_path(module), SPACES) is None;
    task.state = TaskState.FAILED;
    store.finish(address, task, product_path(module));
    assert store.lookup(product_path(module), SPACES) is None;
}


test "successful tasks commit one version and readers record that version" {
    store = ProductStore();
    module = Module.make_stub(inject_name='committed');
    record = store.module(module);
    address = (record.identity, CompilationProduct.SPACES, '');
    task = ProductTask(CompilationProduct.SPACES, TaskState.RUNNING);
    record.tasks[(CompilationProduct.SPACES, '')] = task;
    store.active.append(address);
    value = PlacementSpaces();
    store.publish(product_path(module), SPACES, value);
    store.active.pop();
    task.state = TaskState.SUCCEEDED;
    store.finish(address, task, product_path(module));
    assert task.version == 1;
    assert store.result(product_path(module), SPACES) is value;
    reader = ProductTask(CompilationProduct.SERVING, TaskState.RUNNING);
    record.tasks[(CompilationProduct.SERVING, '')] = reader;
    store.active.append((record.identity, CompilationProduct.SERVING, ''));
    assert store.result(product_path(module), SPACES) is value;
    store.active.pop();
    assert reader.dependencies[(product_path(module), CompilationProduct.SPACES, '')]
        == 1;
}


test "contextual graphs cannot acquire a second context's mutation permit" {
    module = Module.make_stub(inject_name='isolated');
    first = ProductStore();
    second = ProductStore();
    first.module(module);
    rejected = False;
    try {
        second.module(module);
    } except ValueError {
        rejected = True;
    }
    assert rejected;
    assert module.mutation_permit is first.mutations;
}


test "relation writes require the declared family and restore permissions" {
    module = Module.make_stub(inject_name='permissions');
    permit = MutationPermit();
    module.attach_permit(permit);
    before = module.relation_generation;
    denied = False;
    try {
        module.changed_relations(RelationFamily.TYPES);
    } except PermissionError {
        denied = True;
    }
    assert denied;
    assert module.relation_generation == before;
    with MutationScope(permit, 4) {
        module.changed_relations(RelationFamily.TYPES);
        with MutationScope(permit, 2) {
            assert permit.mask == 2;
        }
        assert permit.mask == 4;
    }
    assert permit.mask == 0;
    assert module.relation_generation == before + 1;
}


test "source content and annex membership determine module revision" {
    with TemporaryDirectory() as tmp {
        path = Path(tmp) / 'main.jac';
        path.write_text('def value -> int { return 1; }');
        initial = module_revision(str(path));
        stat = path.stat();
        path.write_text('def value -> int { return 2; }');
        os.utime(path, ns=(stat.st_atime_ns, stat.st_mtime_ns));
        changed = module_revision(str(path));
        assert changed != initial;
        annex = Path(tmp) / 'main.impl.jac';
        annex.write_text('# annex');
        assert module_revision(str(path)) != changed;
        annex.unlink();
        assert module_revision(str(path)) == changed;
    }
}

test "deep syntax lookup preserves postorder without populating every descendant index" {
    import from jaclang.compiler.ir.schema { Module }
    leaf = Module.make_stub(inject_name='leaf');
    top = leaf;
    for index in range(2500) {
        parent = Module.make_stub(inject_name='parent');
        parent.set_kids([top], pos_update=False);
        top = parent;
    }
    descendants = top.get_all_sub_nodes(Module);
    assert len(descendants) == 2500;
    assert descendants[0] is leaf;
    assert getattr(leaf, '_UniNode__sub_node_tab') is None;
}


test "a typed accessor rebuilds its cache and rejects replacement before deletion" {
    import from jaclang.compiler.ir.types.nodes { TypeVarType, UnknownType }
    variable = TypeVarType(name='T');
    bound = UnknownType();
    variable.bound = bound;
    assert variable.bound is bound;
    variable._cached_bound = None;
    assert variable.bound is bound;
    rejected = False;
    try {
        setattr(variable, 'bound', Module.make_stub());
    } except TypeError {
        rejected = True;
    }
    assert rejected;
    assert variable.bound is bound;
}


test "dynamic relation writes enforce endpoint bounds and active authority" {
    import from jaclang.jac0core.osp0 { connect0 }
    import from jaclang.compiler.ir.schema { ScopeParent, BindingTarget }
    source = Module.make_stub(inject_name='source');
    target = Module.make_stub(inject_name='target');
    rejected = False;
    try {
        connect0(source, target, BindingTarget);
    } except TypeError {
        rejected = True;
    }
    assert rejected;
    permit = MutationPermit();
    source.attach_permit(permit);
    rejected = False;
    try {
        connect0(source, target, ScopeParent);
    } except PermissionError {
        rejected = True;
    }
    assert rejected;
    with MutationScope(permit, 2) {
        connect0(source, target, ScopeParent);
    }
    assert source.parent_scope is target;
    rejected = False;
    with MutationScope(permit, 2) {
        try {
            connect0(source, target, ScopeParent);
        } except ValueError {
            rejected = True;
        }
    }
    assert rejected;
    assert source.parent_scope is target;
}


test "an optional compile-time pass without markers does not initialize type services" {
    import from unittest.mock { patch }
    import from jaclang.compiler.session.session { JacProgram }
    import from jaclang.compiler.pipeline.executor { run_pass }
    import from jaclang.compiler.pipeline.contracts { PassIdentity }
    program = JacProgram();
    module = program.parse_str('with entry { print(1); }', 'no_comptime.jac');
    with patch.object(
        JacProgram,
        'get_type_evaluator',
        side_effect=AssertionError('unexpected type initialization')
    ) {
        run_pass(PassIdentity.ComptimeResolvePass, module, program);
    }
}

test "a failed context claim does not claim an earlier unassigned node" {
    parent = Module.make_stub(inject_name='unclaimed');
    child = Module.make_stub(inject_name='claimed');
    parent.set_kids([child], pos_update=False);
    first = MutationPermit();
    second = MutationPermit();
    child.attach_permit(first);
    rejected = False;
    try {
        parent.attach_permit(second);
    } except ValueError {
        rejected = True;
    }
    assert rejected;
    assert parent.mutation_permit is None;
    assert child.mutation_permit is first;
}

test "a cross-context replacement preserves the previous type and scope" {
    import from jaclang.compiler.ir.types.nodes { TypeVarType, UnknownType }
    variable = TypeVarType(name='T');
    original = UnknownType();
    variable.bound = original;
    first = MutationPermit();
    variable.attach_permit(first);
    foreign = UnknownType();
    foreign.attach_permit(MutationPermit());
    generation = variable.relation_generation;
    rejected = False;
    with MutationScope(first, 4) {
        try {
            variable.bound = foreign;
        } except ValueError {
            rejected = True;
        }
    }
    assert rejected;
    assert variable.bound is original;
    assert variable.relation_generation == generation;
    local = Module.make_stub();
    original_scope = Module.make_stub();
    local.parent_scope = original_scope;
    local.attach_permit(first);
    foreign_scope = Module.make_stub();
    foreign_scope.attach_permit(MutationPermit());
    rejected = False;
    with MutationScope(first, 2) {
        try {
            local.parent_scope = foreign_scope;
        } except ValueError {
            rejected = True;
        }
    }
    assert rejected;
    assert local.parent_scope is original_scope;
}

test "decoded singular roles cannot silently lose their only target" {
    import from jaclang.compiler.ir.schema { BodyRole }
    module = Module.make_stub();
    module._role_shapes = {BodyRole: 'one'};
    rejected = False;
    try {
        validate_graph(module);
    } except ValueError {
        rejected = True;
    }
    assert rejected;
}

test "an untyped connection cannot bypass the compiler relation schema" {
    import from jaclang.jac0core.osp0 { connect0 }
    rejected = False;
    try {
        connect0(Module.make_stub(), Module.make_stub());
    } except ValueError {
        rejected = True;
    }
    assert rejected;
}

test "changing the target selects a fresh analyzed graph and shares parsed source" {
    import from pathlib { Path }
    import from tempfile { TemporaryDirectory }
    import from jaclang.compiler.session.session { JacProgram }
    import from jaclang.compiler.session.options { CompileOptions }
    import from jaclang.compiler.api { module_spaces }
    with TemporaryDirectory() as tmp {
        path = Path(tmp) / 'main.jac';
        path.write_text('def answer -> int { return 42; }');
        program = JacProgram();
        server = program.compile(
            str(path),
            options=CompileOptions(
                symtab_ir_only=True,
                default_codespace='server',
                force_target_program=True
            )
        );
        native = program.compile(
            str(path),
            options=CompileOptions(
                symtab_ir_only=True,
                default_codespace='native',
                force_target_program=True
            )
        );
        assert not program.errors_had , [str(error) for error in program.errors_had];
        assert native is not server;
        assert native.mutation_permit is not server.mutation_permit;
        assert program.source_store.parses == 1;
        assert not module_spaces(program, server).native_module;
        assert module_spaces(program, native).native_module;
    }
}


test "a role replacement validates every target before changing the graph" {
    import from jaclang.compiler.ir.schema { DocRole, String }
    module = Module.make_stub(inject_name="role-replacement");
    original = String(module.source, "STRING", "before", 1, 1, 0, 6, 0, 6);
    replacement = String(module.source, "STRING", "after", 1, 1, 0, 5, 0, 5);
    module._role_set(DocRole, original);
    generation = module.relation_generation;
    rejected = False;
    try {
        module._role_set(DocRole, [replacement, Module.make_stub()]);
    } except TypeError {
        rejected = True;
    }
    assert rejected;
    assert [module->:DocRole:->] == [original];
    assert module.relation_generation == generation;
    assert module._role_shapes[DocRole] == "one";
}


test "one typed connection commits one generation and claims its target" {
    import from jaclang.compiler.ir.symbols.edges { ScopeParent }
    source = Module.make_stub(inject_name='source');
    target = Module.make_stub(inject_name='target');
    permit = MutationPermit();
    source.attach_permit(permit);
    before = source.relation_generation;
    generation = permit.generation;
    with MutationScope(permit, 2) {
        source +>:ScopeParent:+> target;
    }
    assert source.relation_generation == before + 1;
    assert permit.generation == generation + 1;
    assert target.mutation_permit is permit;
}


test "graph walkers terminate on cycles and reject foreign descendants atomically" {
    import from jaclang.compiler.ir.symbols.edges { ScopeParent }
    first = Module.make_stub(inject_name='first');
    second = Module.make_stub(inject_name='second');
    first +>:ScopeParent:+> second;
    second +>:ScopeParent:+> first;
    validate_graph(first);
    permit = MutationPermit();
    first.attach_permit(permit);
    assert second.mutation_permit is permit;
    other = MutationPermit();
    before = other.generation;
    rejected = False;
    try {
        second.attach_permit(other);
    } except ValueError {
        rejected = True;
    }
    assert rejected;
    assert first.mutation_permit is permit;
    assert second.mutation_permit is permit;
    assert other.generation == before;
}


test "syntax copies preserve typed edges while isolating context and locations" {
    import copy;
    import from jaclang.compiler.session.session { JacProgram }
    import from jaclang.compiler.session.sources { SourceStore }
    import from jaclang.compiler.ir.syntax.edges { Kid }
    store = SourceStore();
    left = JacProgram();
    right = JacProgram();
    code = 'def value -> int { return 1; }';
    (first, failed) = store.parse(code, 'copy.jac', left, []);
    assert not failed;
    (second, failed) = store.parse(code, 'copy.jac', right, []);
    assert not failed;
    assert store.parses == 1;
    assert first.mutation_permit is left.analysis.mutations;
    assert second.mutation_permit is right.analysis.mutations;
    assert not first._struct_frozen and not second._struct_frozen;
    first_body = first.body[0];
    second_body = second.body[0];
    assert first_body is not second_body;
    assert first_body.parent is first;
    assert second_body.parent is second;
    assert first_body.loc is not second_body.loc;
    assert first_body.loc.first_tok is not second_body.loc.first_tok;
    assert first_body.mutation_permit is left.analysis.mutations;
    assert second_body.mutation_permit is right.analysis.mutations;
    validate_graph(first);
    validate_graph(second);
    detached = copy.deepcopy(first);
    assert detached.mutation_permit is None;
    assert detached.body[0].mutation_permit is None;
    assert detached.body[0].parent is detached;
    with MutationScope(left.analysis.mutations, 1) {
        first.set_kids([], pos_update=False);
    }
    assert not [first->:Kid:->];
    assert [second->:Kid:->];
}
