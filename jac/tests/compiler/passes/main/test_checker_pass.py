"""Tests for typechecker pass (the pyright implementation)."""

from collections.abc import Callable

from jaclang.compiler.passes.main import TypeCheckPass
from jaclang.jac0core.program import JacProgram


def _assert_error_pretty_found(needle: str, haystack: str) -> None:
    for line in [line.strip() for line in needle.splitlines() if line.strip()]:
        assert line in haystack, f"Expected line '{line}' not found in:\n{haystack}"


def test_explicit_type_annotation_in_assignment(
    fixture_path: Callable[[str], str],
) -> None:
    """Test explicit type annotation in assignment."""
    program = JacProgram()
    program.compile(fixture_path("type_annotation_assignment.jac"), type_check=True)
    assert len(program.errors_had) == 2
    _assert_error_pretty_found(
        """
        glob should_fail1: int = "foo";
             ^^^^^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )

    _assert_error_pretty_found(
        """
        glob should_fail2: str = 42;
             ^^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[1].pretty_print(),
    )


def test_list_assignment_to_int(fixture_path: Callable[[str], str]) -> None:
    """Test that assigning a list to an int variable produces an error."""
    program = JacProgram()
    mod = program.compile(fixture_path("checker_list_assignment.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 1
    _assert_error_pretty_found(
        """
        foo = [1,2,3];  # <-- Error
        ^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )


def test_float_types(fixture_path: Callable[[str], str]) -> None:
    program = JacProgram()
    mod = program.compile(fixture_path("checker_float.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 1
    _assert_error_pretty_found(
        """
        f: float = pi;  # <-- OK
        s: str = pi;  # <-- Error
        ^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )


def test_infer_type_of_assignment(fixture_path: Callable[[str], str]) -> None:
    program = JacProgram()
    mod = program.compile(fixture_path("infer_type_assignment.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 1

    _assert_error_pretty_found(
        """
      assigning_to_str: str = some_int_inferred;
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )


def test_bug_in_walker_ability(fixture_path: Callable[[str], str]) -> None:
    program = JacProgram()
    mod = program.compile(fixture_path("checker_bug_return_in_walker_ability.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    # There shouln't be any errors in this file
    assert len(program.errors_had) == 0


def test_member_access_type_resolve(fixture_path: Callable[[str], str]) -> None:
    program = JacProgram()
    mod = program.compile(fixture_path("member_access_type_resolve.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 1
    _assert_error_pretty_found(
        """
      s: str = f.bar.baz;
      ^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )


def test_imported_sym(fixture_path: Callable[[str], str]) -> None:
    program = JacProgram()
    mod = program.compile(fixture_path("checker/import_sym_test.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 1
    _assert_error_pretty_found(
        """
      a: str = foo();  # <-- Ok
      b: int = foo();  # <-- Error
      ^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )


def test_member_access_type_infered(fixture_path: Callable[[str], str]) -> None:
    program = JacProgram()
    mod = program.compile(fixture_path("member_access_type_inferred.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 1
    _assert_error_pretty_found(
        """
      s = f.bar;
      ^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )


def test_inherited_symbol(fixture_path: Callable[[str], str]) -> None:
    program = JacProgram()
    mod = program.compile(fixture_path("checker_sym_inherit.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 1
    _assert_error_pretty_found(
        """
      c.val = 42;  # <-- Ok
      c.val = "str";  # <-- Error
      ^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )


def test_import_symbol_type_infer(fixture_path: Callable[[str], str]) -> None:
    program = JacProgram()
    mod = program.compile(fixture_path("import_symbol_type_infer.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 1
    _assert_error_pretty_found(
        """
        i: int = m.sys.prefix;
        ^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )


def test_from_import(fixture_path: Callable[[str], str]) -> None:
    path = fixture_path("checker_importer.jac")

    program = JacProgram()
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 1
    _assert_error_pretty_found(
        """
      glob s: str = alias;
           ^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )


def test_call_expr(fixture_path: Callable[[str], str]) -> None:
    path = fixture_path("checker_expr_call.jac")
    program = JacProgram()
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 1
    _assert_error_pretty_found(
        """
      s: str = foo();
      ^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )


def test_call_expr_magic(fixture_path: Callable[[str], str]) -> None:
    path = fixture_path("checker_magic_call.jac")
    program = JacProgram()
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 1
    _assert_error_pretty_found(
        """
        b: Bar = fn()();  # <-- Ok
        f: Foo = fn()();  # <-- Error
        ^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )


def test_arity(fixture_path: Callable[[str], str]) -> None:
    path = fixture_path("checker_arity.jac")
    program = JacProgram()
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 3
    _assert_error_pretty_found(
        """
        f.first_is_self(f);  # <-- Error
                        ^
    """,
        program.errors_had[0].pretty_print(),
    )
    _assert_error_pretty_found(
        """
        f.with_default_args(1, 2, 3);  # <-- Error
                                  ^
    """,
        program.errors_had[1].pretty_print(),
    )
    _assert_error_pretty_found(
        """
        f.with_default_args();  # <-- Error
        ^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[2].pretty_print(),
    )


def test_param_types(fixture_path: Callable[[str], str]) -> None:
    path = fixture_path("checker_param_types.jac")
    program = JacProgram()
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 1
    _assert_error_pretty_found(
        """
        foo(A());  # <-- Ok
        foo(B());  # <-- Error
            ^^^
    """,
        program.errors_had[0].pretty_print(),
    )


def test_param_arg_match(fixture_path: Callable[[str], str]) -> None:
    program = JacProgram()
    path = fixture_path("checker_arg_param_match.jac")
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 13

    expected_errors = [
        """
        Not all required parameters were provided in the function call: 'a'
                 f = Foo();
                 f.bar();
                 ^^^^^^^
        """,
        """
        Too many positional arguments
                 f.bar();
                 f.bar(1);
                 f.bar(1, 2);
                          ^
        """,
        """
        Not all required parameters were provided in the function call: 'self', 'a'
                 f.bar(1, 2);
                 f.baz();
                 ^^^^^^^
        """,
        """
        Not all required parameters were provided in the function call: 'a'
                 f.baz();
                 f.baz(1);
                 ^^^^^^^^
        """,
        """
        Not all required parameters were provided in the function call: 'f'
                 foo(1, 2, d=3, e=4, f=5, c=4);  # order does not matter for named
                 foo(1, 2, 3, d=4, e=5, g=7, h=8);  # missing argument 'f'
                 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        """,
        """
        Positional only parameter 'b' cannot be matched with a named argument
                 foo(1, 2, 3, d=4, e=5, g=7, h=8);  # missing argument 'f'
                 foo(1, b=2, c=3, d=4, e=5, f=6);  # b is positional only
                        ^^^
        """,
        """
        Too many positional arguments
                 bar(1, 2, 3, 4, 5, f=6);
                 bar(1, 2, 3, 4, 5, 6, 7, 8, 9);  # too many args
                                       ^
        """,
        """
        Too many positional arguments
                 bar(1, 2, 3, 4, 5, f=6);
                 bar(1, 2, 3, 4, 5, 6, 7, 8, 9);  # too many args
                                          ^
        """,
        """
        Too many positional arguments
                 bar(1, 2, 3, 4, 5, f=6);
                 bar(1, 2, 3, 4, 5, 6, 7, 8, 9);  # too many args
                                             ^
        """,
        """
        Parameter 'c' already matched
                 bar(1, 2, 3, 4, 5, f=6);
                 bar(1, 2, 3, 4, 5, 6, 7, 8, 9);  # too many args
                 bar(1, 2, 3, 4, 5, 6, c=3);  # already matched
                                       ^^^
        """,
        """
        Named argument 'h' does not match any parameter
                 bar(1, 2, 3, 4, 5, 6, 7, 8, 9);  # too many args
                 bar(1, 2, 3, 4, 5, 6, c=3);  # already matched
                 bar(1, 2, 3, 4, 5, 6, h=1);  # h is not matched
                                       ^^^
        """,
        """
        Too many positional arguments
                 baz(a=1, b=2);
                 baz(1, b=2);  # a can be both positional and keyword
                 baz(1, 2);  # 'b' can only be keyword arg
                        ^
        """,
        """
        Not all required parameters were provided in the function call: 'b'
                 baz(a=1, b=2);
                 baz(1, b=2);  # a can be both positional and keyword
                 baz(1, 2);  # 'b' can only be keyword arg
                 ^^^^^^^^^
        """,
    ]

    for i, expected in enumerate(expected_errors):
        _assert_error_pretty_found(expected, program.errors_had[i].pretty_print())


def test_class_construct(fixture_path: Callable[[str], str]) -> None:
    program = JacProgram()
    path = fixture_path("checker_class_construct.jac")
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 3

    square_sym = mod.sym_tab.lookup("Square")
    assert square_sym is not None
    assert square_sym.decl is not None
    assert square_sym.decl.type is not None
    assert square_sym.decl.type.shared is not None
    mro_class_names = [
        cls.shared.class_name
        for cls in square_sym.decl.type.shared.mro
        if cls.shared is not None
    ]
    assert "object" in mro_class_names, (
        f"Expected 'object' in MRO, got: {mro_class_names}"
    )

    expected_errors = [
        """
        Cannot assign <class float> to parameter 'color' of type <class str>
                with entry {
                    c1 = Circle1(RAD);
                                ^^^
        """,
        """
        Not all required parameters were provided in the function call: 'age'
                with entry {
                c2 = Square(length);
                     ^^^^^^^^^^^^^^
        """,
        """
        Not all required parameters were provided in the function call: 'name'
                c = Person(name=name, age=25);
                c = Person();
                    ^^^^^^^^
        """,
    ]

    for i, expected in enumerate(expected_errors):
        _assert_error_pretty_found(expected, program.errors_had[i].pretty_print())


def test_self_type_inference(fixture_path: Callable[[str], str]) -> None:
    path = fixture_path("checker_self_type.jac")
    program = JacProgram()
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 1
    _assert_error_pretty_found(
        """
      x: str = self.i;  # <-- Error
      ^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )


def test_binary_op(fixture_path: Callable[[str], str]) -> None:
    program = JacProgram()
    mod = program.compile(fixture_path("checker_binary_op.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 2
    _assert_error_pretty_found(
        """
        r2: A = a + a;  # <-- Error
        ^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )
    _assert_error_pretty_found(
        """
        r4: str = (a + a) * B();  # <-- Error
        ^^^^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[1].pretty_print(),
    )


def test_checker_call_expr_class(fixture_path: Callable[[str], str]) -> None:
    path = fixture_path("checker_call_expr_class.jac")
    program = JacProgram()
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 1
    _assert_error_pretty_found(
        """
        inst.i = 'str';  # <-- Error
        ^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )


def test_type_ref_resolution(fixture_path: Callable[[str], str]) -> None:
    path = fixture_path("checker_type_ref.jac")
    program = JacProgram()
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 0


def test_checker_mod_path(fixture_path: Callable[[str], str]) -> None:
    path = fixture_path("checker_mod_path.jac")
    program = JacProgram()
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 1
    _assert_error_pretty_found(
        """
        a: int = os.path;  # <-- Error
        ^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )


def test_checker_cat_is_animal(fixture_path: Callable[[str], str]) -> None:
    path = fixture_path("checker_cat_is_animal.jac")
    program = JacProgram()
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 1
    _assert_error_pretty_found(
        """
        animal_func(cat);  # <-- Ok
        animal_func(lion);  # <-- Ok
        animal_func(not_animal);  # <-- Error
                    ^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )


def test_checker_member_access(fixture_path: Callable[[str], str]) -> None:
    path = fixture_path("symtab_build.jac")
    program = JacProgram()
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(mod.sym_tab.names_in_scope.values()) == 2
    mod_scope_symbols = ["Symbol(alice", "Symbol(Person"]
    for sym in mod_scope_symbols:
        assert sym in str(mod.sym_tab.names_in_scope.values())
    assert len(mod.sym_tab.kid_scope[0].names_in_scope.values()) == 5
    kid_scope_symbols = [
        "Symbol(age",
        "Symbol(greet",
        "Symbol(name,",
        "Symbol(create_person",
        "Symbol(class_info",
    ]
    for sym in kid_scope_symbols:
        assert sym in str(mod.sym_tab.kid_scope[0].names_in_scope.values())
    age_sym = mod.sym_tab.kid_scope[0].lookup("age")
    assert age_sym is not None
    assert "(NAME, age, 22:11 - 22:14)" in str(age_sym.uses)
    assert len(program.errors_had) == 1
    _assert_error_pretty_found(
        """
        alice.age = '909';  # <-- Error
        ^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )


def test_checker_import_missing_module(fixture_path: Callable[[str], str]) -> None:
    path = fixture_path("checker_import_missing_module.jac")
    program = JacProgram()
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 0


def test_cyclic_symbol(fixture_path: Callable[[str], str]) -> None:
    path = fixture_path("checker_cyclic_symbol.jac")
    program = JacProgram()
    mod = program.compile(path)
    # This will result in a stack overflow if not handled properly.
    # So the fact that it has 0 errors means it passed.
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 0


def test_get_type_of_iife_expression(fixture_path: Callable[[str], str]) -> None:
    path = fixture_path("checker_iife_expression.jac")
    program = JacProgram()
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 0


def test_generics(fixture_path: Callable[[str], str]) -> None:
    program = JacProgram()
    path = fixture_path("checker_generics.jac")
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 9

    expected_errors = [
        """
        Cannot assign <class Foo> to <class str>
            for it in tl {
                tifoo: Foo = it;
                tistr: str = it;  # <-- Error
                ^^^^^^^^^^^^^^^^
            }
        }
        """,
        """
        Cannot assign <class Foo> to <class str>
            lst: list[Foo] = [Foo(), Foo()];
            f: Foo = lst[0];  # <-- Ok
            s: str = lst[0];  # <-- Error
            ^^^^^^^^^^^^^^^^

            for it in lst {
        """,
        """
        Cannot assign <class Foo> to <class str>
            for it in lst {
                tifoo: Foo = it;  # <-- Ok
                tistr: str = it;  # <-- Error
                ^^^^^^^^^^^^^^^^
            }

        """,
        """
        Cannot assign <class int> to <class str>
            m: list[int] = [1, 2, 3];
            n: int = m[0];
            p: str = m[0];  # <-- Error
            ^^^^^^^^^^^^^^

            x: list[str] = ["a", "b", "c"];
        """,
        """
        Cannot assign <class str> to <class int>
            x: list[str] = ["a", "b", "c"];
            y: str = x[1];
            z: int = x[1];  # <-- Error
            ^^^^^^^^^^^^^^

            d: dict[int, str] = {1: "one", 2: "two"};
        """,
        """
        Cannot assign <class str> to <class int>
            d: dict[int, str] = {1: "one", 2: "two"};
            s: str = d[1];
            i: int = d[1];  # <-- Error
            ^^^^^^^^^^^^^^

            ht = HashTable[int, str]();
        """,
        """
        Cannot assign <class str> to parameter 'key' of type <class int>
            ht = HashTable[int, str]();
            ht.insert(1, "one");
            ht.insert("one", "one");  # <-- Error
                    ^^^^^
            ht.insert(1, 1);  # <-- Error

        """,
        """
        Cannot assign <class int> to parameter 'value' of type <class str>
            ht.insert(1, "one");
            ht.insert("one", "one");  # <-- Error
            ht.insert(1, 1);  # <-- Error
                        ^

            hv1: str = ht.get(1);
        """,
        """
        Cannot assign <class str> to <class int>

            hv1: str = ht.get(1);
            hv2: int = ht.get(1);  # <-- Error
            ^^^^^^^^^^^^^^^^^^^^^

        }
        """,
    ]

    for i, expected in enumerate(expected_errors):
        _assert_error_pretty_found(expected, program.errors_had[i].pretty_print())


def test_return_type(fixture_path: Callable[[str], str]) -> None:
    program = JacProgram()
    path = fixture_path("checker_return_type.jac")
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    # foo() has no annotation: 2 errors for returning values without annotation.
    # bar() -> int: 2 errors for type mismatches ("" and 1.1).
    assert len(program.errors_had) == 4

    expected_errors = [
        """
        Return type annotation required when function returns a value
            return 1;  # <-- Error (no return annotation, but returning a value)
            ^^^^^^^^^
        """,
        """
        Return type annotation required when function returns a value
            return "";  # <-- Error (no return annotation, but returning a value)
            ^^^^^^^^^^
        """,
        """
        Cannot return <class str>, expected <class int>

        def bar()  -> int {
            return "";  # <-- Error
            ^^^^^^^^^^
        """,
        """
        Cannot return <class float>, expected <class int>
            return 1.1;  # <-- Error
            ^^^^^^^^^^
        """,
    ]

    for i, expected in enumerate(expected_errors):
        _assert_error_pretty_found(expected, program.errors_had[i].pretty_print())


def test_connect_typed(fixture_path: Callable[[str], str]) -> None:
    program = JacProgram()
    path = fixture_path("checker_connect_typed.jac")
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    # Expect three errors: wrong edge type usage and node class operands
    assert len(program.errors_had) == 3


def test_connect_filter(fixture_path: Callable[[str], str]) -> None:
    program = JacProgram()
    path = fixture_path("checker_connect_filter.jac")
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 7

    expected_errors = [
        """
        Connection type must be an edge instance
            a_inst +>: edge_inst :+> b_inst;  # Ok
            a_inst +>: NodeA :+> b_inst;  # Error
                       ^^^^^
        """,
        """
        Connection left operand must be a node instance
            a_inst +>: NodeA :+> b_inst;  # Error
            NodeA +>: MyEdge :+> b_inst;  # Error
            ^^^^^
        """,
        """
        Connection right operand must be a node instance
            NodeA +>: MyEdge :+> b_inst;  # Error
            a_inst +>: MyEdge :+> NodeB;  # Error
                                  ^^^^^
        """,
        """
        Edge type "<class MyEdge>" has no member named "not_mem"
            # Assign compr in edges
            a_inst +>: MyEdge : id=1,not_mem="some" :+> b_inst;  # Error
                                     ^^^^^^^
        """,
        """
        Member "not_exist not found on type <class Book>"
            lst(=title="Parry Potter",author="K.J. Bowling",year=1997);  # Ok
            lst(=not_exist="some");  # Error
                 ^^^^^^^^^
        """,
        """
        Type "<class str> is not assignable to type <class int>"
            lst(=not_exist="some");  # Error
            lst(=year="Type Error");  # Error
                      ^^^^^^^^^^^^
        """,
        """
        Member "not_exists not found on type <class MyEdge>"
            [->:MyEdge:id==1:->];  # Ok
            [->:MyEdge:not_exists>=1:->];  # Error
                       ^^^^^^^^^^
        """,
    ]

    for i, expected in enumerate(expected_errors):
        _assert_error_pretty_found(expected, program.errors_had[i].pretty_print())


def test_connect_any_type(fixture_path: Callable[[str], str]) -> None:
    """Test that connection operations with any type (from untyped list) don't produce errors."""
    program = JacProgram()
    path = fixture_path("checker_connect_any_type.jac")
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    # Should have no errors - any type in connection operations is allowed (for now)
    # TODO: In strict mode, this should produce an error
    assert len(program.errors_had) == 0


def test_connect_node_collection(fixture_path: Callable[[str], str]) -> None:
    """Test that connection operations accept collections (list, tuple) of nodes."""
    program = JacProgram()
    path = fixture_path("checker_connect_node_collection.jac")
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    # Should have no errors - collections of nodes are valid connection operands
    assert len(program.errors_had) == 0


def test_root_type(fixture_path: Callable[[str], str]) -> None:
    program = JacProgram()
    path = fixture_path("checker_root_type.jac")
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 1
    expected_error = """
            root ++> c;
            x: str = root;  # <- error
            ^^^^^^^^^^^^^^
            """
    _assert_error_pretty_found(expected_error, program.errors_had[0].pretty_print())


def test_inherit_method_lookup(fixture_path: Callable[[str], str]) -> None:
    """Test that inherited methods are properly resolved through MRO."""
    program = JacProgram()
    mod = program.compile(fixture_path("checker_inherit_method_lookup.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    # Filter out errors from external modules (stdlib, site-packages)
    user_errors = [
        e
        for e in program.errors_had
        if "/site-packages/" not in e.loc.mod_path
        and "/lib/python" not in e.loc.mod_path
        and "/Lib/python" not in e.loc.mod_path
    ]
    assert len(user_errors) == 0


def test_inherit_init_params(fixture_path: Callable[[str], str]) -> None:
    """Test that synthesized __init__ collects parameters from base classes."""
    program = JacProgram()
    mod = program.compile(fixture_path("checker_inherit_init_params.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 2

    expected_errors = [
        """
        Not all required parameters were provided in the function call: 'age'
            c0 = Child("Alice", 30);  # <-- Ok
            c1 = Child(name="Alice", age=30);  # <-- Ok
            c2 = Child("Bob");  # <-- Error: missing age
                 ^^^^^^^^^^^^
        """,
        """
        Not all required parameters were provided in the function call: 'name'
            c2 = Child("Bob");  # <-- Error: missing age
            c3 = Child(age=25);  # <-- Error: missing name
                 ^^^^^^^^^^^^^
        """,
    ]

    for i, expected in enumerate(expected_errors):
        _assert_error_pretty_found(expected, program.errors_had[i].pretty_print())


def test_agentvisitor_connect_no_errors(fixture_path: Callable[[str], str]) -> None:
    """Ensure the AgentVisitor connect snippet type-checks with no errors."""
    program = JacProgram()
    path = fixture_path("connect_agentvisitor.jac")
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 0
    assert len(program.warnings_had) == 0


def test_union_reassignment(fixture_path: Callable[[str], str]) -> None:
    """Test union type reassignment checking."""
    program = JacProgram()
    mod = program.compile(fixture_path("checker_union_reassignment.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 3
    _assert_error_pretty_found(
        """
        fb = 42;  # <-- Error
        ^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )
    _assert_error_pretty_found(
        """
        a = "";  # <-- Error
        ^^^^^^^
    """,
        program.errors_had[1].pretty_print(),
    )
    _assert_error_pretty_found(
        """
        a = Foo();  # <-- Error
        ^^^^^^^^^^
    """,
        program.errors_had[2].pretty_print(),
    )


def test_protocol(fixture_path: Callable[[str], str]) -> None:
    """Test protocol type checking (structural subtyping)."""
    program = JacProgram()
    mod = program.compile(fixture_path("checker_protocol.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 2
    _assert_error_pretty_found(
        """
        len(Foo());  # <-- Error
            ^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )
    _assert_error_pretty_found(
        """
        run(Foo());  # <-- Error
            ^^^^^
    """,
        program.errors_had[1].pretty_print(),
    )


def test_classmethod(fixture_path: Callable[[str], str]) -> None:
    """Test classmethod type checking."""
    program = JacProgram()
    mod = program.compile(fixture_path("checker_classmethod.jac"))
    TypeCheckPass(ir_in=mod, prog=program)


def test_datetime_now(fixture_path: Callable[[str], str]) -> None:
    """Test datetime.now() classmethod - cls parameter should be skipped for parameter check."""
    program = JacProgram()
    mod = program.compile(fixture_path("checker_datetime_now.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    # Should have no errors - datetime.now() is a classmethod and cls parameter should be skipped
    assert len(program.errors_had) == 0


def test_any_type_works_with_any_type(fixture_path: Callable[[str], str]) -> None:
    """Test stdlib typing module imports and Any type work correctly."""
    program = JacProgram()
    mod = program.compile(fixture_path("checker_any_type_works.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    # There shouldn't be any errors - Any type accepts any value
    assert len(program.errors_had) == 0


def test_dict_pop(fixture_path: Callable[[str], str]) -> None:
    program = JacProgram()
    mod = program.compile(fixture_path("checker_dict_pop.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 3
    _assert_error_pretty_found(
        """
        d.pop(); # <-- Error: Missing argument
        ^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )
    _assert_error_pretty_found(
        """
        d.pop(1); # <-- Error: Key type mismatch
              ^
    """,
        program.errors_had[1].pretty_print(),
    )
    _assert_error_pretty_found(
        """
        d.pop("key", 1, 2); # <-- Error: Too many arguments
        ^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[2].pretty_print(),
    )


def test_final_type_checking(fixture_path: Callable[[str], str]) -> None:
    program = JacProgram()
    mod = program.compile(fixture_path("checker_final.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 1
    _assert_error_pretty_found(
        """
        z: str = x; # <-- Error: incompatible types
        ^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )


def test_list_iteration_type_checking(fixture_path: Callable[[str], str]) -> None:
    """Test that list iteration correctly types the loop variable."""
    program = JacProgram()
    mod = program.compile(fixture_path("checker_list_iteration.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    assert len(program.errors_had) == 1
    _assert_error_pretty_found(
        """
        y: str = i;  # <-- Error
        ^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )


def test_overload_decorator(fixture_path: Callable[[str], str]) -> None:
    """Test that @overload decorator works correctly for method and magic method overloads."""
    program = JacProgram()
    mod = program.compile(fixture_path("checker_overload.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    # Expect 2 errors: do_something with str, and __add__ with str
    assert len(program.errors_had) == 2

    # Find the specific errors we care about
    error_messages = [err.pretty_print() for err in program.errors_had]

    # Check for do_something("hello") error
    do_something_error = next(
        (err for err in error_messages if "do_something" in err and "hello" in err),
        None,
    )
    assert do_something_error is not None, (
        'Expected error for foo.do_something("hello")'
    )
    _assert_error_pretty_found(
        """
        foo.do_something("hello");  # <-- Error
        ^^^^^^^^^^^^^^^^^^^^^^^^^
    """,
        do_something_error,
    )

    # Check for __add__("hello") error
    add_error = next(
        (err for err in error_messages if "__add__" in err and "hello" in err),
        None,
    )
    assert add_error is not None, 'Expected error for foo + "hello"'
    _assert_error_pretty_found(
        """
        foo + "hello";  # <-- Error
        ^^^^^^^^^^^^^
    """,
        add_error,
    )


def test_function_overload_decorator(fixture_path: Callable[[str], str]) -> None:
    """Test that @overload decorator works correctly for top-level function overloads."""
    program = JacProgram()
    mod = program.compile(fixture_path("checker_function_overload.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    # Expect 1 error: cast("hello") with no matching overload
    assert len(program.errors_had) == 1

    # Find the specific error we care about
    error_messages = [err.pretty_print() for err in program.errors_had]

    # Check for cast("hello") error
    cast_error = next(
        (err for err in error_messages if "cast" in err and "hello" in err),
        None,
    )
    assert cast_error is not None, 'Expected error for cast("hello")'
    _assert_error_pretty_found(
        """
        z: str = cast("hello");  # <-- Error
              ^^^^^^^^^^^^^
    """,
        cast_error,
    )


def test_object_type_assignment(fixture_path: Callable[[str], str]) -> None:
    """Test that assigning node types and instances to object type works correctly."""
    program = JacProgram()
    mod = program.compile(fixture_path("object_type_assignment.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    # Should have no errors - both node class and node instance should be assignable to object
    assert len(program.errors_had) == 0


def test_walrus_operator(fixture_path: Callable[[str], str]) -> None:
    """Test walrus operator (:=) type checking."""
    program = JacProgram()
    mod = program.compile(fixture_path("checker_walrus_operator.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    # Expect 5 errors: multiple type assignment errors with walrus operator
    assert len(program.errors_had) == 5

    expected_errors = [
        """
        glob result3: str = result1;
        ^^^^^^^^^^^^^^^^^^^^^^
        """,
        """
        glob result4: str = z;
        ^^^^^^^^^^^^^^^^
        """,
        """
        y = "hello";
        ^^^^^^^^^^^^
        """,
        """
        p: AnotherNode = n;
        ^^^^^^^^^^^^^^^^^^^
        """,
        """
        a = AnotherNode();
        ^^^^^^^^^^^^^^^^^^
        """,
    ]

    for i, expected in enumerate(expected_errors):
        _assert_error_pretty_found(expected, program.errors_had[i].pretty_print())


def test_builtin_constructors(fixture_path: Callable[[str], str]) -> None:
    """Test that builtin constructors (set(), list(), dict()) work correctly."""
    program = JacProgram()
    mod = program.compile(fixture_path("checker_builtin_constructors.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    # All constructors should work without errors
    assert len(program.errors_had) == 0


def test_union_type_annotation(fixture_path: Callable[[str], str]) -> None:
    """Test union type annotation with None (e.g., int | None) and union subset checking."""
    program = JacProgram()
    mod = program.compile(fixture_path("checker_union_type_annotation.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    # Should have 1 error - int | str is not subset of int | None
    assert len(program.errors_had) == 1
    _assert_error_pretty_found(
        """
        a: int | None = get_int_or_str();  # <-- Error: int | str is not subset of int | None
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )


def test_list_indexing(fixture_path: Callable[[str], str]) -> None:
    """Test that list indexing works correctly and can be used with len()."""
    program = JacProgram()
    mod = program.compile(fixture_path("checker_list_indexing.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    # Should have no errors - len(some[0]) should work correctly
    assert len(program.errors_had) == 0


def test_range_function(fixture_path: Callable[[str], str]) -> None:
    """Test that range() function works correctly with different argument counts."""
    program = JacProgram()
    mod = program.compile(fixture_path("checker_range.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    # Should have no errors - range() should work with 1 or 2 arguments
    assert len(program.errors_had) == 0


def test_varargs_type_checking(fixture_path: Callable[[str], str]) -> None:
    """Test type checking for variadic parameters (*args, **kwargs)."""
    program = JacProgram()
    mod = program.compile(fixture_path("checker_varargs_type.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    # Expect 4 errors:
    # 1. y: int = b; (b is tuple, not int)
    # 2. z: str = c; (c is dict, not str)
    # 3. i: str = b[1]; (b[1] is int, not str)
    # 4. k: int = c["a"]; (c["a"] is str, not int)
    assert len(program.errors_had) == 4

    expected_errors = [
        """
        y: int = b;  # <-- Error
        ^^^^^^^^^^^
        """,
        """
        z: str = c;  # <-- Error
        ^^^^^^^^^^^
        """,
        """
        i: str = b[1]; # <-- Error
        ^^^^^^^^^^^^^
        """,
        """
        k: int = c["a"]; # <-- Error
        ^^^^^^^^^^^^^^^
        """,
    ]

    for i, expected in enumerate(expected_errors):
        _assert_error_pretty_found(expected, program.errors_had[i].pretty_print())


def test_slice_type_checking(fixture_path: Callable[[str], str]) -> None:
    """Test type checking for slice expressions."""
    program = JacProgram()
    mod = program.compile(fixture_path("checker_slice.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    # Expect 1 error: z: int = x[0:2] (slice returns list[int], not int)
    assert len(program.errors_had) == 1

    _assert_error_pretty_found(
        """
        z: int = x[0:2];  # <-- Error
        ^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )


def test_numeric_type_promotion(fixture_path: Callable[[str], str]) -> None:
    """Test numeric type promotion for arithmetic operations (int -> float)."""
    program = JacProgram()
    mod = program.compile(fixture_path("checker_numeric_promotion.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    # Expect 3 errors: assigning float results to int variables
    assert len(program.errors_had) == 3

    # Error 1: int + float assigned to int
    _assert_error_pretty_found(
        """
        err1: int = 1 + 2.0;  # <-- Error: float cannot be assigned to int
        ^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print(),
    )

    # Error 2: division always returns float
    _assert_error_pretty_found(
        """
        err2: int = 4 / 2;    # <-- Error: division always returns float
        ^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[1].pretty_print(),
    )

    # Error 3: float * int assigned to int
    _assert_error_pretty_found(
        """
        err3: int = 2.0 * 3;  # <-- Error: float cannot be assigned to int
        ^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[2].pretty_print(),
    )


def test_property_type_checking(fixture_path: Callable[[str], str]) -> None:
    """Test that property access returns the property's return type, not FunctionType."""
    program = JacProgram()
    mod = program.compile(fixture_path("checker_property.jac"))
    TypeCheckPass(ir_in=mod, prog=program)
    # Expect 4 errors:
    # 1. wrong: str = foo.bar (int assigned to str)
    # 2. wrong_name: int = foo.name (str assigned to int)
    # 3. method: int = foo.regular_method (FunctionType assigned to int)
    # 4. wrong_val: str = bar_obj.value (int assigned to str)
    assert len(program.errors_had) == 4

    _assert_error_pretty_found(
        """
        wrong: str = foo.bar;  # <-- Error (int assigned to str)
    """,
        program.errors_had[0].pretty_print(),
    )

    _assert_error_pretty_found(
        """
        wrong_name: int = foo.name;  # <-- Error (str assigned to int)
    """,
        program.errors_had[1].pretty_print(),
    )

    _assert_error_pretty_found(
        """
        method: int = foo.regular_method;  # <-- Error (FunctionType assigned to int)
    """,
        program.errors_had[2].pretty_print(),
    )

    _assert_error_pretty_found(
        """
        wrong_val: str = bar_obj.value;  # <-- Error (int assigned to str)
    """,
        program.errors_had[3].pretty_print(),
    )


def test_type_narrowing(fixture_path: Callable[[str], str]) -> None:
    """Test CFG-based type narrowing for isinstance and None checks.

    The fixture checker_type_narrowing.jac defines 6 functions that exercise
    flow-sensitive type narrowing:

      1. isinstance narrowing in if-branch        (1 assignment inside branch)
      2. isinstance narrowing with else            (2 assignments, one per branch)
      3. None narrowing with `is not None`         (1 assignment inside branch)
      4. None narrowing with `is None` + return    (1 assignment after early return)
      5. Narrowing expires at join point           (2 assignments in branches + 1 at join)
      6. Chained isinstance narrowing in elif      (3 assignments, one per branch)

    With CFG-based narrowing implemented, every assignment inside a narrowed
    branch should succeed because the checker sees the narrowed type.  Only
    the join-point assignment in function 5 should fail because the full
    union type is restored after the if/else.

    Expected after narrowing: exactly 1 error (the join-point assignment).
    """
    program = JacProgram()
    mod = program.compile(fixture_path("checker_type_narrowing.jac"))
    TypeCheckPass(ir_in=mod, prog=program)

    # With narrowing: only the join-point assignment at line 95 should error.
    # (fail: Dog = animal; where animal is Dog | Cat after the if/else)
    assert len(program.errors_had) == 1, (
        f"Expected exactly 1 type error (join-point in test 5), but got "
        f"{len(program.errors_had)}:\n"
        + "\n---\n".join(err.pretty_print() for err in program.errors_had)
    )

    _assert_error_pretty_found(
        """
        fail: Dog = animal;            # <-- Error (Dog | Cat cannot assign to Dog)
    """,
        program.errors_had[0].pretty_print(),
    )


def test_postinit_fields_not_required_in_constructor(
    fixture_path: Callable[[str], str],
) -> None:
    """Test that fields marked with 'by postinit' are not required as constructor arguments."""
    program = JacProgram()
    path = fixture_path("checker_postinit_fields.jac")
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)
    # Should have no errors - postinit fields should not be required in constructor
    assert len(program.errors_had) == 0, (
        f"Expected no type checking errors, but got {len(program.errors_had)}: "
        + "\n".join([err.pretty_print() for err in program.errors_had])
    )


def test_impl_body_type_checking(fixture_path: Callable[[str], str]) -> None:
    """Test that type errors in impl bodies."""
    program = JacProgram()
    path = fixture_path("checker_impl_body.jac")
    mod = program.compile(path)
    TypeCheckPass(ir_in=mod, prog=program)

    # Expect 3 errors from the impl file (function, archetype method, enum)
    assert len(program.errors_had) == 3, (
        f"Expected 3 type errors, but got {len(program.errors_had)}: "
        + "\n".join([err.pretty_print() for err in program.errors_had])
    )
    _assert_error_pretty_found(
        """x = "wrong";  # <-- Error: Cannot assign str to int
        ^^^^^^^^^^^^""",
        program.errors_had[0].pretty_print(),
    )
    assert "checker_impl_body.impl.jac" in program.errors_had[0].loc.mod_path
    _assert_error_pretty_found(
        """result = "wrong";  # <-- Error: Cannot assign str to int
        ^^^^^^^^^^^^^^^^^""",
        program.errors_had[1].pretty_print(),
    )
    assert "checker_impl_body.impl.jac" in program.errors_had[1].loc.mod_path
    _assert_error_pretty_found(
        """PENDING: int = "wrong",  # <-- Error: Cannot assign str to int
        ^^^^^^^^^^^^^^^^^^^^^^""",
        program.errors_had[2].pretty_print(),
    )
    assert "checker_impl_body.impl.jac" in program.errors_had[2].loc.mod_path
