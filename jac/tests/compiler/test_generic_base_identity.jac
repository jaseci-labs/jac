import from jaclang.compiler.ir.schema { Module }
import from jaclang.compiler.ir.types.nodes {
    ClassDetailsShared,
    ClassType,
    TypeVarType
}
import from jaclang.compiler.analysis.types.type_utils { specialize_for_base_class }

test "generic specialization recognizes equivalent class graphs" {
    scope = Module.make_stub("generic_identity");
    parameter = TypeVarType(name="T");
    base = ClassType(
        _shared=ClassDetailsShared(
            class_name="Base",
            symbol_table=scope,
            type_params=[parameter],
            declaration_identity=("generic_identity.jac", 1, 0, "Base")
        )
    );
    base.shared.mro = [base];
    reconstructed = ClassType(
        _shared=ClassDetailsShared(
            class_name="Base",
            symbol_table=scope,
            type_params=[parameter],
            declaration_identity=base.shared.canonical_key()
        )
    );
    assert base.shared is not reconstructed.shared;
    integer = ClassType(
        _shared=ClassDetailsShared(class_name="int", symbol_table=scope)
    );
    concrete_base = base.specialize_generics([integer]);
    assert specialize_for_base_class(concrete_base, reconstructed) is concrete_base;
    derived = ClassType(
        _shared=ClassDetailsShared(
            class_name="Derived",
            symbol_table=scope,
            type_params=[parameter],
            base_classes=[base.specialize_generics([parameter])],
            declaration_identity=("generic_identity.jac", 2, 0, "Derived")
        )
    );
    derived.shared.mro = [derived, base];
    child = ClassType(
        _shared=ClassDetailsShared(
            class_name="Child",
            symbol_table=scope,
            base_classes=[derived.specialize_generics([integer])],
            declaration_identity=("generic_identity.jac", 3, 0, "Child")
        )
    );
    child.shared.mro = [child, derived, base];
    specialized = specialize_for_base_class(child, reconstructed);
    assert specialized.private.type_args == [integer];
    unrelated = ClassType(
        _shared=ClassDetailsShared(
            class_name="Base",
            symbol_table=scope,
            type_params=[parameter],
            declaration_identity=("other.jac", 1, 0, "Base")
        )
    );
    assert specialize_for_base_class(child, unrelated) is unrelated;
}

test "class values assign to a reconstructed builtin type annotation" {
    import from jaclang.compiler.session.session { JacProgram }
    import from jaclang.compiler.analysis.types.type_utils { types_equivalent }
    evaluator = JacProgram().get_type_evaluator();
    builtin_type = evaluator.prefetch.type_class;
    integer = evaluator.prefetch.int_class;
    assert builtin_type is not None and integer is not None;
    reconstructed = ClassType(
        flags=builtin_type.flags,
        _shared=ClassDetailsShared(
            class_name="type",
            symbol_table=builtin_type.shared.symbol_table,
            declaration_identity=builtin_type.shared.canonical_key()
        )
    );
    assert reconstructed.shared is not builtin_type.shared;
    assert types_equivalent(builtin_type, reconstructed);
    assert evaluator.assign_type(integer, reconstructed.clone_as_instance());
    unrelated = ClassType(
        flags=builtin_type.flags,
        _shared=ClassDetailsShared(
            class_name="type",
            symbol_table=builtin_type.shared.symbol_table,
            declaration_identity=("user_defined.jac", 1, 0, "type")
        )
    );
    assert not types_equivalent(builtin_type, unrelated);
    assert not evaluator.assign_type(integer, unrelated.clone_as_instance());
}

test "stdlib enum ancestry survives independently loaded class graphs" {
    import from jaclang.compiler.session.session { JacProgram }
    import from jaclang.compiler.session.options { CompileOptions }
    program = JacProgram();
    program.compile(
        file_path="enum_base_identity.jac",
        use_str="import from enum { StrEnum, IntEnum }\n"
            + "import from jaclang.compiler.ir.enums { Constants }\n"
            + "class Label(StrEnum) { with entry { FIRST = 'first'; } }\n"
            + "class Number(IntEnum) { with entry { FIRST = 1; } }\n"
            + "def label -> str { return Label.FIRST.value; }\n"
            + "def number -> int { return Number.FIRST.value; }\n"
            + "def guest -> str { return Constants.GUEST.value; }\n",
        options=CompileOptions(
            no_cgen=True, force_target_program=True, need_full_ast=True
        )
    );
    assert not program.errors_had , str(program.errors_had);
}
