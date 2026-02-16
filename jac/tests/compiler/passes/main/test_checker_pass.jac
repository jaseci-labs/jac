"""Type checker pass tests -- migrated from test_checker_pass.py."""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.passes.main { TypeCheckPass }
import from jaclang.jac0core.program { JacProgram }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures"
     ),
     LANG_FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures");

def assert_error_pretty_found(needle: str, haystack: str) {
    for line in [
        line.strip()
        for line in needle.splitlines()
        if line.strip()
    ] {
        assert line in haystack , f"Expected line '{line}' not found in:\n{haystack}";
    }
}

test "explicit_type_annotation_in_assignment" {
    program = JacProgram();
    program.compile(
        os.path.join(FIXTURES, "type_annotation_assignment.jac"), type_check=True
    );
    assert len(program.errors_had) == 2;
    assert_error_pretty_found(
        """
        glob should_fail1: int = "foo";
             ^^^^^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );

    assert_error_pretty_found(
        """
        glob should_fail2: str = 42;
             ^^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[1].pretty_print()
    );
}

test "list_assignment_to_int" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_list_assignment.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
    assert_error_pretty_found(
        """
        foo = [1,2,3];  # <-- Error
        ^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "float_types" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_float.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
    assert_error_pretty_found(
        """
        f: float = pi;  # <-- OK
        s: str = pi;  # <-- Error
        ^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "infer_type_of_assignment" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "infer_type_assignment.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;

    assert_error_pretty_found(
        """
      assigning_to_str: str = some_int_inferred;
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "bug_in_walker_ability" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(FIXTURES, "checker_bug_return_in_walker_ability.jac")
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "member_access_type_resolve" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "member_access_type_resolve.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
    assert_error_pretty_found(
        """
      s: str = f.bar.baz;
      ^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "imported_sym" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker", "import_sym_test.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
    assert_error_pretty_found(
        """
      a: str = foo();  # <-- Ok
      b: int = foo();  # <-- Error
      ^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "member_access_type_infered" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "member_access_type_inferred.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
    assert_error_pretty_found(
        """
      s = f.bar;
      ^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "inherited_symbol" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_sym_inherit.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
    assert_error_pretty_found(
        """
      c.val = 42;  # <-- Ok
      c.val = "str";  # <-- Error
      ^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "import_symbol_type_infer" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "import_symbol_type_infer.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
    assert_error_pretty_found(
        """
        i: int = m.sys.prefix;
        ^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "from_import" {
    path = os.path.join(FIXTURES, "checker_importer.jac");

    program = JacProgram();
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
    assert_error_pretty_found(
        """
      glob s: str = alias;
           ^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "call_expr" {
    path = os.path.join(FIXTURES, "checker_expr_call.jac");
    program = JacProgram();
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
    assert_error_pretty_found(
        """
      s: str = foo();
      ^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "call_expr_magic" {
    path = os.path.join(FIXTURES, "checker_magic_call.jac");
    program = JacProgram();
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
    assert_error_pretty_found(
        """
        b: Bar = fn()();  # <-- Ok
        f: Foo = fn()();  # <-- Error
        ^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "arity" {
    path = os.path.join(FIXTURES, "checker_arity.jac");
    program = JacProgram();
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 3;
    assert_error_pretty_found(
        """
        f.first_is_self(f);  # <-- Error
                        ^
    """,
        program.errors_had[0].pretty_print()
    );
    assert_error_pretty_found(
        """
        f.with_default_args(1, 2, 3);  # <-- Error
                                  ^
    """,
        program.errors_had[1].pretty_print()
    );
    assert_error_pretty_found(
        """
        f.with_default_args();  # <-- Error
        ^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[2].pretty_print()
    );
}

test "param_types" {
    path = os.path.join(FIXTURES, "checker_param_types.jac");
    program = JacProgram();
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
    assert_error_pretty_found(
        """
        foo(A());  # <-- Ok
        foo(B());  # <-- Error
            ^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "param_arg_match" {
    program = JacProgram();
    path = os.path.join(FIXTURES, "checker_arg_param_match.jac");
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 13;

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
        """
    ];

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

test "class_construct" {
    program = JacProgram();
    path = os.path.join(FIXTURES, "checker_class_construct.jac");
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 3;

    square_sym = mod.sym_tab.lookup("Square");
    assert square_sym is not None;
    assert square_sym.decl is not None;
    assert square_sym.decl.type is not None;
    assert square_sym.decl.type.shared is not None;
    mro_class_names = [
        cls.shared.class_name
        for cls in square_sym.decl.type.shared.mro
        if cls.shared is not None
    ];
    assert "object" in mro_class_names , f"Expected 'object' in MRO, got: {mro_class_names}";

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
        """
    ];

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

test "self_type_inference" {
    path = os.path.join(FIXTURES, "checker_self_type.jac");
    program = JacProgram();
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
    assert_error_pretty_found(
        """
      x: str = self.i;  # <-- Error
      ^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "binary_op" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_binary_op.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 2;
    assert_error_pretty_found(
        """
        r2: A = a + a,  # <-- Error
        ^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
    assert_error_pretty_found(
        """
        r4: str = (a + a) * B(),  # <-- Error
        ^^^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[1].pretty_print()
    );
}

test "checker_call_expr_class" {
    path = os.path.join(FIXTURES, "checker_call_expr_class.jac");
    program = JacProgram();
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
    assert_error_pretty_found(
        """
        inst.i = 'str';  # <-- Error
        ^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "type_ref_resolution" {
    path = os.path.join(FIXTURES, "checker_type_ref.jac");
    program = JacProgram();
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "checker_mod_path" {
    path = os.path.join(FIXTURES, "checker_mod_path.jac");
    program = JacProgram();
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
    assert_error_pretty_found(
        """
        a: int = os.path;  # <-- Error
        ^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "checker_cat_is_animal" {
    path = os.path.join(FIXTURES, "checker_cat_is_animal.jac");
    program = JacProgram();
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
    assert_error_pretty_found(
        """
        animal_func(cat);  # <-- Ok
        animal_func(lion);  # <-- Ok
        animal_func(not_animal);  # <-- Error
                    ^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "checker_member_access" {
    path = os.path.join(FIXTURES, "symtab_build.jac");
    program = JacProgram();
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(mod.sym_tab.names_in_scope.values()) == 2;
    mod_scope_symbols = ["Symbol(alice", "Symbol(Person"];
    for sym in mod_scope_symbols {
        assert sym in str(mod.sym_tab.names_in_scope.values());
    }
    assert len(mod.sym_tab.kid_scope[0].names_in_scope.values()) == 5;
    kid_scope_symbols = [
        "Symbol(age",
        "Symbol(greet",
        "Symbol(name,",
        "Symbol(create_person",
        "Symbol(class_info"
    ];
    for sym in kid_scope_symbols {
        assert sym in str(mod.sym_tab.kid_scope[0].names_in_scope.values());
    }
    age_sym = mod.sym_tab.kid_scope[0].lookup("age");
    assert age_sym is not None;
    assert "(NAME, age, 22:11 - 22:14)" in str(age_sym.uses);
    assert len(program.errors_had) == 1;
    assert_error_pretty_found(
        """
        alice.age = '909';  # <-- Error
        ^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "checker_import_missing_module" {
    path = os.path.join(FIXTURES, "checker_import_missing_module.jac");
    program = JacProgram();
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "cyclic_symbol" {
    path = os.path.join(FIXTURES, "checker_cyclic_symbol.jac");
    program = JacProgram();
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "get_type_of_iife_expression" {
    path = os.path.join(FIXTURES, "checker_iife_expression.jac");
    program = JacProgram();
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "generics" {
    program = JacProgram();
    path = os.path.join(FIXTURES, "checker_generics.jac");
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 9;

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
        """
    ];

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

test "return_type" {
    program = JacProgram();
    path = os.path.join(FIXTURES, "checker_return_type.jac");
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 4;

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
        """
    ];

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

test "connect_typed" {
    program = JacProgram();
    path = os.path.join(FIXTURES, "checker_connect_typed.jac");
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 3;
}

test "connect_filter" {
    program = JacProgram();
    path = os.path.join(FIXTURES, "checker_connect_filter.jac");
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 7;

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
        """
    ];

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

test "connect_any_type" {
    program = JacProgram();
    path = os.path.join(FIXTURES, "checker_connect_any_type.jac");
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "connect_node_collection" {
    program = JacProgram();
    path = os.path.join(FIXTURES, "checker_connect_node_collection.jac");
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "root_type" {
    program = JacProgram();
    path = os.path.join(FIXTURES, "checker_root_type.jac");
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
    expected_error = """
            root ++> c;
            x: str = root;  # <- error
            ^^^^^^^^^^^^^^
            """;
    assert_error_pretty_found(expected_error, program.errors_had[0].pretty_print());
}

test "inherit_method_lookup" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_inherit_method_lookup.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    user_errors = [
        e
        for e in program.errors_had
        if "/site-packages/" not in e.loc.mod_path
        and "/lib/python" not in e.loc.mod_path
        and "/Lib/python" not in e.loc.mod_path
    ];
    assert len(user_errors) == 0;
}

test "inherit_init_params" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_inherit_init_params.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 2;

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
        """
    ];

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

test "agentvisitor_connect_no_errors" {
    program = JacProgram();
    path = os.path.join(FIXTURES, "connect_agentvisitor.jac");
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
    assert len(program.warnings_had) == 0;
}

test "union_reassignment" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_union_reassignment.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 3;
    assert_error_pretty_found(
        """
        fb = 42;  # <-- Error
        ^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
    assert_error_pretty_found(
        """
        a = "";  # <-- Error
        ^^^^^^^
    """,
        program.errors_had[1].pretty_print()
    );
    assert_error_pretty_found(
        """
        a = Foo();  # <-- Error
        ^^^^^^^^^^
    """,
        program.errors_had[2].pretty_print()
    );
}

test "protocol" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_protocol.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 2;
    assert_error_pretty_found(
        """
        len(Foo());  # <-- Error
            ^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
    assert_error_pretty_found(
        """
        run(Foo());  # <-- Error
            ^^^^^
    """,
        program.errors_had[1].pretty_print()
    );
}

test "classmethod" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_classmethod.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
}

test "datetime_now" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_datetime_now.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "any_type_works_with_any_type" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_any_type_works.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "dict_pop" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_dict_pop.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 3;
    assert_error_pretty_found(
        """
        d.pop(); # <-- Error: Missing argument
        ^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
    assert_error_pretty_found(
        """
        d.pop(1); # <-- Error: Key type mismatch
              ^
    """,
        program.errors_had[1].pretty_print()
    );
    assert_error_pretty_found(
        """
        d.pop("key", 1, 2); # <-- Error: Too many arguments
        ^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[2].pretty_print()
    );
}

test "final_type_checking" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_final.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
    assert_error_pretty_found(
        """
        z: str = x; # <-- Error: incompatible types
        ^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "list_iteration_type_checking" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_list_iteration.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
    assert_error_pretty_found(
        """
        y: str = i;  # <-- Error
        ^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "overload_decorator" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_overload.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 2;

    error_messages = [err.pretty_print() for err in program.errors_had];

    do_something_error = next(
        (
            err
            for err in error_messages
            if "do_something" in err and "hello" in err
        ),
        None
    );
    assert do_something_error is not None , 'Expected error for foo.do_something("hello")';
    assert_error_pretty_found(
        """
        foo.do_something("hello");  # <-- Error
        ^^^^^^^^^^^^^^^^^^^^^^^^^
    """,
        do_something_error
    );

    add_error = next(
        (
            err
            for err in error_messages
            if "__add__" in err and "hello" in err
        ),
        None
    );
    assert add_error is not None , 'Expected error for foo + "hello"';
    assert_error_pretty_found(
        """
        foo + "hello";  # <-- Error
        ^^^^^^^^^^^^^
    """,
        add_error
    );
}

test "function_overload_decorator" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_function_overload.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;

    error_messages = [err.pretty_print() for err in program.errors_had];

    cast_error = next(
        (
            err
            for err in error_messages
            if "cast" in err and "hello" in err
        ),
        None
    );
    assert cast_error is not None , 'Expected error for cast("hello")';
    assert_error_pretty_found(
        """
        z: str = cast("hello");  # <-- Error
              ^^^^^^^^^^^^^
    """,
        cast_error
    );
}

test "object_type_assignment" {
    program = JacProgram();
    mod = program.compile(os.path.join(LANG_FIXTURES, "object_type_assignment.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "walrus_operator" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_walrus_operator.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 5;

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
        """
    ];

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

test "builtin_constructors" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_builtin_constructors.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "union_type_annotation" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_union_type_annotation.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
    assert_error_pretty_found(
        """
        a: int | None = get_int_or_str();  # <-- Error: int | str is not subset of int | None
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "list_indexing" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_list_indexing.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "range_function" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_range.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "varargs_type_checking" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_varargs_type.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 4;

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
        """
    ];

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

test "slice_type_checking" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_slice.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;

    assert_error_pretty_found(
        """
        z: int = x[0:2];  # <-- Error
        ^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "numeric_type_promotion" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_numeric_promotion.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 3;

    assert_error_pretty_found(
        """
        err1: int = 1 + 2.0;  # <-- Error: float cannot be assigned to int
        ^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );

    assert_error_pretty_found(
        """
        err2: int = 4 / 2;    # <-- Error: division always returns float
        ^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[1].pretty_print()
    );

    assert_error_pretty_found(
        """
        err3: int = 2.0 * 3;  # <-- Error: float cannot be assigned to int
        ^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[2].pretty_print()
    );
}

test "property_type_checking" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_property.jac"));
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 4;

    assert_error_pretty_found(
        """
        wrong: str = foo.bar;  # <-- Error (int assigned to str)
    """,
        program.errors_had[0].pretty_print()
    );

    assert_error_pretty_found(
        """
        wrong_name: int = foo.name;  # <-- Error (str assigned to int)
    """,
        program.errors_had[1].pretty_print()
    );

    assert_error_pretty_found(
        """
        method: int = foo.regular_method;  # <-- Error (FunctionType assigned to int)
    """,
        program.errors_had[2].pretty_print()
    );

    assert_error_pretty_found(
        """
        wrong_val: str = bar_obj.value;  # <-- Error (int assigned to str)
    """,
        program.errors_had[3].pretty_print()
    );
}

test "type_narrowing" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_type_narrowing.jac"));
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 1 , f"Expected exactly 1 type error (join-point in test 5), but got " + f"{len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);

    assert_error_pretty_found(
        """
        fail: Dog = animal;            # <-- Error (Dog | Cat cannot assign to Dog)
    """,
        program.errors_had[0].pretty_print()
    );
}

test "postinit_fields_not_required_in_constructor" {
    program = JacProgram();
    path = os.path.join(FIXTURES, "checker_postinit_fields.jac");
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0 , f"Expected no type checking errors, but got {len(
        program.errors_had
    )}: " + "\n".join([err.pretty_print() for err in program.errors_had]);
}

test "impl_body_type_checking" {
    program = JacProgram();
    path = os.path.join(FIXTURES, "checker_impl_body.jac");
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 3 , f"Expected 3 type errors, but got {len(
        program.errors_had
    )}: " + "\n".join([err.pretty_print() for err in program.errors_had]);
    assert_error_pretty_found(
        """x = "wrong";  # <-- Error: Cannot assign str to int
        ^^^^^^^^^^^^""",
        program.errors_had[0].pretty_print()
    );
    assert "checker_impl_body.impl.jac" in program.errors_had[0].loc.mod_path;
    assert_error_pretty_found(
        """result = "wrong";  # <-- Error: Cannot assign str to int
        ^^^^^^^^^^^^^^^^^""",
        program.errors_had[1].pretty_print()
    );
    assert "checker_impl_body.impl.jac" in program.errors_had[1].loc.mod_path;
    assert_error_pretty_found(
        """PENDING: int = "wrong",  # <-- Error: Cannot assign str to int
        ^^^^^^^^^^^^^^^^^^^^^^""",
        program.errors_had[2].pretty_print()
    );
    assert "checker_impl_body.impl.jac" in program.errors_had[2].loc.mod_path;
}

test "super_init_with_has_vars" {
    program = JacProgram();
    path = os.path.join(FIXTURES, "checker_super_init_has_vars.jac");
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 3 , f"Expected 3 type errors, but got {len(
        program.errors_had
    )}: " + "\n".join([err.pretty_print() for err in program.errors_had]);

    assert_error_pretty_found(
        """Cannot assign <class int> to parameter 'shape_type' of type <class str>""",
        program.errors_had[0].pretty_print()
    );

    assert_error_pretty_found(
        """Too many positional arguments""", program.errors_had[1].pretty_print()
    );

    assert_error_pretty_found(
        """Not all required parameters were provided in the function call: 'shape_type'""",
        program.errors_had[2].pretty_print()
    );
}

test "super_init_with_explicit_init" {
    program = JacProgram();
    path = os.path.join(FIXTURES, "checker_super_init_explicit.jac");
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 4 , f"Expected 4 type errors, but got {len(
        program.errors_had
    )}: " + "\n".join([err.pretty_print() for err in program.errors_had]);

    assert_error_pretty_found(
        """Cannot assign <class int> to parameter 'name' of type <class str>""",
        program.errors_had[0].pretty_print()
    );

    assert_error_pretty_found(
        """Cannot assign <class str> to parameter 'age' of type <class int>""",
        program.errors_had[1].pretty_print()
    );

    assert_error_pretty_found(
        """Not all required parameters were provided in the function call: 'skill'""",
        program.errors_had[2].pretty_print()
    );

    assert_error_pretty_found(
        """Cannot assign <class int> to parameter 'owner' of type <class str>""",
        program.errors_had[3].pretty_print()
    );
}

test "enum_type_checking" {
    program = JacProgram();
    mod = program.compile(os.path.join(FIXTURES, "checker_enum.jac"));
    TypeCheckPass(ir_in=mod, prog=program);

    expected_errors = [
        "Cannot assign <class str> to enum member 'B' of type <class int>",
        "name_err: int = Color.RED.name",
        "value_err: str = Color.BLUE.value",
        "value_status_val_err: int = Status.ACTIVE.value",
        "auto_val_err: str = AutoValueTest.THIRD.value",
        "impl_shape_name_err: int = ShapeType.SQUARE.name",
        'func_wrong_type: str = process_color("not a color")'
    ];

    assert len(program.errors_had) == len(expected_errors) , f"Expected {len(
        expected_errors
    )} errors, got {len(program.errors_had)}: " + "\n".join(
        [err.pretty_print() for err in program.errors_had]
    );

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

test "nested_functions_in_impl_blocks" {
    program = JacProgram();
    path = os.path.join(FIXTURES, "check_nested_impldef.jac");
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 0 , f"Expected no type checking errors, but got {len(
        program.errors_had
    )}: " + "\n".join([err.pretty_print() for err in program.errors_had]);
}

test "callable_type_annotation" {
    program = JacProgram();
    path = os.path.join(FIXTURES, "checker_callable.jac");
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 8 , f"Expected 8 type errors, but got {len(
        program.errors_had
    )}: " + "\n".join([err.pretty_print() for err in program.errors_had]);

    assert_error_pretty_found(
        """
        e1: Callable[[int], str] = str_to_str;  # Error: expects int, got str
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
    assert_error_pretty_found(
        """
        e2: int = takes_callback(int_to_str);  # Error: returns str, not int
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[1].pretty_print()
    );
    assert_error_pretty_found(
        """
        e3: Callable[[int, int], int] = wrong_order;  # Error: [str,int] vs [int,int]
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[2].pretty_print()
    );
    assert_error_pretty_found(
        """
        e4: Callable[[int, int], str] = add_two;  # Error: returns int, not str
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[3].pretty_print()
    );
    assert_error_pretty_found(
        """
        e5: Callable[[int], str] = calc.double;  # Error: returns int, not str
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[4].pretty_print()
    );
    assert_error_pretty_found(
        """
        e6: Callable[[str], int] = Calculator.class_double;  # Error: expects int
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[5].pretty_print()
    );
    assert_error_pretty_found(
        """
        e7: Callable[[Animal], str] = handle_dog;  # Error: Dog doesn't accept Cat
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[6].pretty_print()
    );
    assert_error_pretty_found(
        """
        e8: Callable[[int, int], int] = without_default;  # Error: c has no default
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[7].pretty_print()
    );
}
