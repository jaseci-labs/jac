import from jaclang.compiler.session.compiler { JacCompiler }
import from jaclang.compiler.ir.schema { Name }
import from jaclang.compiler.ir.identity { MutationPermit }
import from jaclang.compiler.ir.mutation { validate_graph }
import from jaclang.compiler.ir.types.nodes { ClassType }
import from jaclang.compiler.analysis.types.builtin_extensions {
    install_builtin_extensions
}

test "a catalog lookup materializes only the requested declaration" {
    catalog = JacCompiler().stub_catalog();
    assert catalog is not None;
    isolated = catalog.fork();
    module = isolated.module('builtins');
    assert module is not None;
    assert not isolated._sym_memo;
    integer = module.lookup_local('int');
    assert integer is not None and integer.name == 'int';
    assert len(isolated._sym_memo) == 1;
    assert module.lookup_local('__missing_catalog_name__') is None;
    assert len(isolated._sym_memo) == 1;
    assert module.lookup_local('int') is integer;
    names = module.names_in_scope;
    assert isinstance(names, dict);
    assert names['int'] is integer and 'str' in names and 'dict' in names;
    assert len(names) > 100;
}

test "catalog contexts isolate declarations and namespace replacement" {
    catalog = JacCompiler().stub_catalog();
    assert catalog is not None;
    first = catalog.fork().module('builtins');
    second = catalog.fork().module('builtins');
    assert first is not None and second is not None;
    left = first.lookup_local('int');
    right = second.lookup_local('int');
    assert left is not None and right is not None;
    assert left is not right and left.decl is not right.decl;
    left_decl = left.decl;
    right_decl = right.decl;
    assert isinstance(left_decl, Name) and isinstance(right_decl, Name);
    left_decl.value = 'changed';
    assert right_decl.value == 'int';
    first.set_primary_names({});
    assert not first.names_in_scope;
    assert first.lookup_local('str') is None;
    assert second.lookup_local('str') is not None;
}

test "overload additions preserve existing catalog declarations" {
    catalog = JacCompiler().stub_catalog();
    assert catalog is not None;
    module = catalog.fork().module('builtins');
    assert module is not None;
    integer = module.lookup_local('int');
    assert integer is not None;
    initial = list(module.lookup_overloads('int'));
    module.adopt_overload(integer, 'int');
    assert module.lookup_all('int', deep=False) == [integer, *initial, integer];
    assert module.names_in_scope['int'] is integer;
    assert module.names_in_scope_overload['int'] == [*initial, integer];
}

test "lazy catalog declarations join their compilation graph" {
    catalog = JacCompiler().stub_catalog();
    assert catalog is not None;
    module = catalog.fork().module('builtins');
    assert module is not None;
    permit = MutationPermit();
    module.attach_permit(permit);
    integer = module.lookup_local('int');
    assert integer is not None;
    assert integer.mutation_permit is permit;
    assert integer.decl.mutation_permit is permit;
    assert permit.mask == 0;
    validate_graph(module);
    assert module.lookup_local('int') is integer;
}

test "installing builtin extensions leaves unrelated list methods unloaded" {
    catalog = JacCompiler().stub_catalog();
    assert catalog is not None;
    isolated = catalog.fork();
    module = isolated.module('builtins');
    assert module is not None;
    lists = module.lookup_local('list');
    integers = module.lookup_local('int');
    assert lists is not None and integers is not None;
    assert lists.provider is not None and integers.provider is not None;
    list_type = lists.provider.resolve_type(lists);
    int_type = integers.provider.resolve_type(integers);
    assert isinstance(list_type, ClassType) and isinstance(int_type, ClassType);
    scope = list_type.shared.symbol_table;
    assert scope is not None;
    append_id = isolated._pending_scopes[scope].members['append'];
    assert append_id not in isolated._sym_memo;
    install_builtin_extensions(list_type, int_type);
    assert scope.lookup_local('chunks') is not None;
    assert append_id not in isolated._sym_memo;
}
