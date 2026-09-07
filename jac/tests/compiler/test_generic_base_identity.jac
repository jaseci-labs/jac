import from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.types.types { ClassDetailsShared, ClassType, TypeVarType }
import from jaclang.compiler.types.type_utils { specialize_for_base_class }

test "generic specialization recognizes equivalent class graphs" {
    scope = Module.make_stub("generic_identity");
    parameter = TypeVarType(name="T");
    base = ClassType(
        _shared=ClassDetailsShared(
            class_name="Base",
            symbol_table=scope,
            type_params=[parameter],
            _identity_key=("generic_identity.jac", 1, 0, "Base")
        )
    );
    base.shared.mro = [base];
    reconstructed = ClassType(
        _shared=ClassDetailsShared(
            class_name="Base",
            symbol_table=scope,
            type_params=[parameter],
            _identity_key=base.shared.canonical_key()
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
            _identity_key=("generic_identity.jac", 2, 0, "Derived")
        )
    );
    derived.shared.mro = [derived, base];
    child = ClassType(
        _shared=ClassDetailsShared(
            class_name="Child",
            symbol_table=scope,
            base_classes=[derived.specialize_generics([integer])],
            _identity_key=("generic_identity.jac", 3, 0, "Child")
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
            _identity_key=("other.jac", 1, 0, "Base")
        )
    );
    assert specialize_for_base_class(child, unrelated) is unrelated;
}
