"""Type checker pass tests -- migrated from test_checker_pass.py."""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures"
     ),
     CHECKER_FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "checker"
     ),
     LANG_FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures"),
     NO_TC = CompileOptions(type_check=False);

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
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_list_assignment.jac"), options=NO_TC
    );
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
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_float.jac"), options=NO_TC
    );
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
    mod = program.compile(
        os.path.join(FIXTURES, "infer_type_assignment.jac"), options=NO_TC
    );
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
        os.path.join(CHECKER_FIXTURES, "checker_bug_return_in_walker_ability.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "return_value_in_ability_warns" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_return_in_ability.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
    w2014_warnings = [
        w
        for w in program.warnings_had
        if w.code and w.code.code == "W2014"
    ];
    assert len(w2014_warnings) == 2 , f"Expected 2 W2014 warnings, got {len(
        w2014_warnings
    )}: {w2014_warnings}";
}

test "explicit_self_in_archetype_errors" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_explicit_self.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    e2015_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E2015"
    ];
    # 4 errors: one each for obj, node, edge, walker bad_method
    # No errors for: good_method (no self), static_method (static), PyClass methods (class)
    assert len(e2015_errors) == 4 , f"Expected 4 E2015 errors, got {len(e2015_errors)}: {e2015_errors}";
}

test "member_access_type_resolve" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(FIXTURES, "member_access_type_resolve.jac"), options=NO_TC
    );
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
    mod = program.compile(
        os.path.join(FIXTURES, "checker", "import_sym_test.jac"), options=NO_TC
    );
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
    mod = program.compile(
        os.path.join(FIXTURES, "member_access_type_inferred.jac"), options=NO_TC
    );
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
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_sym_inherit.jac"), options=NO_TC
    );
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
    mod = program.compile(
        os.path.join(FIXTURES, "import_symbol_type_infer.jac"), options=NO_TC
    );
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
    path = os.path.join(CHECKER_FIXTURES, "checker_importer.jac");

    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
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
    path = os.path.join(CHECKER_FIXTURES, "checker_expr_call.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
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
    path = os.path.join(CHECKER_FIXTURES, "checker_magic_call.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
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
    path = os.path.join(CHECKER_FIXTURES, "checker_arity.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
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
    path = os.path.join(CHECKER_FIXTURES, "checker_param_types.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
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
    path = os.path.join(CHECKER_FIXTURES, "checker_arg_param_match.jac");
    mod = program.compile(path, options=NO_TC);
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
    path = os.path.join(CHECKER_FIXTURES, "checker_class_construct.jac");
    mod = program.compile(path, options=NO_TC);
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
        Cannot assign float to parameter 'color' of type str
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
    path = os.path.join(CHECKER_FIXTURES, "checker_self_type.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
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
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_binary_op.jac"), options=NO_TC
    );
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
    path = os.path.join(CHECKER_FIXTURES, "checker_call_expr_class.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
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
    path = os.path.join(CHECKER_FIXTURES, "checker_type_ref.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "checker_mod_path" {
    path = os.path.join(CHECKER_FIXTURES, "checker_mod_path.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
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
    path = os.path.join(CHECKER_FIXTURES, "checker_cat_is_animal.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
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
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(mod.sym_tab.names_in_scope.values()) == 2;
    mod_scope_symbols = ["Symbol(alice", "Symbol(Person"];
    for sym in mod_scope_symbols {
        assert sym in str(mod.sym_tab.names_in_scope.values());
    }
    # obj archetypes only have declared 'has' fields and abilities in scope —
    # dynamic self.attr assignments (self.name in greet) are NOT added.
    assert len(mod.sym_tab.kid_scope[0].names_in_scope.values()) == 4;
    kid_scope_symbols = [
        "Symbol(age",
        "Symbol(greet",
        "Symbol(create_person",
        "Symbol(class_info"
    ];
    for sym in kid_scope_symbols {
        assert sym in str(mod.sym_tab.kid_scope[0].names_in_scope.values());
    }
    age_sym = mod.sym_tab.kid_scope[0].lookup("age");
    assert age_sym is not None;
    assert "(NAME, age, 22:11 - 22:14)" in str(age_sym.uses);
    # 5 errors: 'has no attribute name' (obj can't have dynamic attrs),
    # 3 Unknown self in static/classmethod, 1 type mismatch
    assert len(program.errors_had) == 5;
    assert_error_pretty_found(
        """
        alice.age = '909';  # <-- Error
        ^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[4].pretty_print()
    );
}

test "checker_import_missing_module" {
    path = os.path.join(CHECKER_FIXTURES, "checker_import_missing_module.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 8;
}

test "cyclic_symbol" {
    path = os.path.join(CHECKER_FIXTURES, "checker_cyclic_symbol.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "get_type_of_iife_expression" {
    path = os.path.join(CHECKER_FIXTURES, "checker_iife_expression.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
}

test "generics" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_generics.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 9;

    expected_errors = [
        """
        Cannot assign Foo to str
            for it in tl {
                tifoo: Foo = it;
                tistr: str = it;  # <-- Error
                ^^^^^^^^^^^^^^^^
            }
        }
        """,
        """
        Cannot assign Foo to str
            lst: list[Foo] = [Foo(), Foo()];
            f: Foo = lst[0];  # <-- Ok
            s: str = lst[0];  # <-- Error
            ^^^^^^^^^^^^^^^^

            for it in lst {
        """,
        """
        Cannot assign Foo to str
            for it in lst {
                tifoo: Foo = it;  # <-- Ok
                tistr: str = it;  # <-- Error
                ^^^^^^^^^^^^^^^^
            }

        """,
        """
        Cannot assign int to str
            m: list[int] = [1, 2, 3];
            n: int = m[0];
            p: str = m[0];  # <-- Error
            ^^^^^^^^^^^^^^

            x: list[str] = ["a", "b", "c"];
        """,
        """
        Cannot assign str to int
            x: list[str] = ["a", "b", "c"];
            y: str = x[1];
            z: int = x[1];  # <-- Error
            ^^^^^^^^^^^^^^

            d: dict[int, str] = {1: "one", 2: "two"};
        """,
        """
        Cannot assign str to int
            d: dict[int, str] = {1: "one", 2: "two"};
            s: str = d[1];
            i: int = d[1];  # <-- Error
            ^^^^^^^^^^^^^^

            ht = HashTable[int, str]();
        """,
        """
        Cannot assign Literal["one"] to parameter 'key' of type int
            ht = HashTable[int, str]();
            ht.insert(1, "one");
            ht.insert("one", "one");  # <-- Error
                    ^^^^^
            ht.insert(1, 1);  # <-- Error

        """,
        """
        Cannot assign int to parameter 'value' of type str
            ht.insert(1, "one");
            ht.insert("one", "one");  # <-- Error
            ht.insert(1, 1);  # <-- Error
                        ^

            hv1: str = ht.get(1);
        """,
        """
        Cannot assign str to int

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
    path = os.path.join(CHECKER_FIXTURES, "checker_return_type.jac");
    mod = program.compile(path, options=NO_TC);
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
        Cannot return Literal[""], expected int

        def bar()  -> int {
            return "";  # <-- Error
            ^^^^^^^^^^
        """,
        """
        Cannot return float, expected int
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
    path = os.path.join(CHECKER_FIXTURES, "checker_connect_typed.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 3;
}

test "connect_filter" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_connect_filter.jac");
    mod = program.compile(path, options=NO_TC);
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
        Member "not_mem" not found on type "MyEdge"
            # Assign compr in edges
            a_inst +>: MyEdge : id=1,not_mem="some" :+> b_inst;  # Error
                                     ^^^^^^^
        """,
        """
        Member "not_exist" not found on type "Book"
            lst(=title="Parry Potter",author="K.J. Bowling",year=1997);  # Ok
            lst(=not_exist="some");  # Error
                 ^^^^^^^^^
        """,
        """
        Type "Literal["Type Error"]" is not assignable to type "int"
            lst(=not_exist="some");  # Error
            lst(=year="Type Error");  # Error
                      ^^^^^^^^^^^^
        """,
        """
        Member "not_exists" not found on type "MyEdge"
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
    path = os.path.join(CHECKER_FIXTURES, "checker_connect_any_type.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "connect_node_collection" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_connect_node_collection.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "root_type" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_root_type.jac");
    mod = program.compile(path, options=NO_TC);
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
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_inherit_method_lookup.jac"),
        options=NO_TC
    );
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
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_inherit_init_params.jac"),
        options=NO_TC
    );
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
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
    assert len(program.warnings_had) == 0;
}

test "union_reassignment" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_union_reassignment.jac"), options=NO_TC
    );
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
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_protocol.jac"), options=NO_TC
    );
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
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_classmethod.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
}

test "datetime_now" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_datetime_now.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "any_type_works_with_any_type" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_any_type_works.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "dict_pop" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_dict_pop.jac"), options=NO_TC
    );
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
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_final.jac"), options=NO_TC
    );
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
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_list_iteration.jac"), options=NO_TC
    );
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
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_overload.jac"), options=NO_TC
    );
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
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_function_overload.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 2;

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
    mod = program.compile(
        os.path.join(LANG_FIXTURES, "object_type_assignment.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "walrus_operator" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_walrus_operator.jac"), options=NO_TC
    );
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
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_builtin_constructors.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "union_type_annotation" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_union_type_annotation.jac"),
        options=NO_TC
    );
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

"""Test member access on union types."""
test "union_member_access" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_union_member_access.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 2 , f"Expected 2 errors, got {len(
        program.errors_had
    )}: " + "\n".join([err.pretty_print() for err in program.errors_had]);
    assert_error_pretty_found(
        """
        return x.legs;  # <-- Error: Bird doesn't have .legs
                 ^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

test "list_indexing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_list_indexing.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
}

test "range_function" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_range.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
}

test "varargs_type_checking" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_varargs_type.jac"), options=NO_TC
    );
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
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_slice.jac"), options=NO_TC
    );
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
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_numeric_promotion.jac"), options=NO_TC
    );
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
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_property.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 6;

    # @property errors
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

    # @cached_property error
    assert_error_pretty_found(
        """
        wrong_cached: int = foo.cached_val;  # <-- Error (str assigned to int)
    """,
        program.errors_had[2].pretty_print()
    );

    # Regular method still returns FunctionType
    assert_error_pretty_found(
        """
        method: int = foo.regular_method;  # <-- Error (FunctionType assigned to int)
    """,
        program.errors_had[3].pretty_print()
    );

    # @property in Bar
    assert_error_pretty_found(
        """
        wrong_val: str = bar_obj.value;  # <-- Error (int assigned to str)
    """,
        program.errors_had[4].pretty_print()
    );

    # @cached_property in Bar
    assert_error_pretty_found(
        """
        wrong_cached_num: str = bar_obj.cached_num;  # <-- Error (int assigned to str)
    """,
        program.errors_had[5].pretty_print()
    );
}

test "property_self_return_type_resolution" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_property_self_return.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    # Only 2 errors: assigning Path to int
    assert len(program.errors_had) == 2;

    assert_error_pretty_found(
        """
        wrong: int = p.parent;  # <-- Error (Path assigned to int)
    """,
        program.errors_had[0].pretty_print()
    );

    assert_error_pretty_found(
        """
        wrong_chained: int = p.parent.parent;  # <-- Error (Path assigned to int)
    """,
        program.errors_had[1].pretty_print()
    );
}

test "type_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_type_narrowing.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 14 , f"Expected exactly 14 type errors, but got " + f"{len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);

    expected_errors = [
        """
        fail: Dog = animal;  # <-- Error (Dog | Cat cannot assign to Dog)
        ^^^^^^^^^^^^^^^^^^^
        """,
        """
        c: Cat = animal;  # <-- Error: Dog cannot be assigned to Cat
        ^^^^^^^^^^^^^^^^
        """,
        """
        wrong: Dog = animal;  # <-- Error: Dog | Cat cannot assign to Dog
        ^^^^^^^^^^^^^^^^^^^^
        """,
        """
        d: Dog = animal;  # <-- Error: Cat cannot assign to Dog
        ^^^^^^^^^^^^^^^^
        """,
        """
        d: Dog = animal;  # <-- Error: Cat cannot assign to Dog
        ^^^^^^^^^^^^^^^^
        """,
        """
        s: str = val;  # <-- Error: str | int cannot assign to str
        ^^^^^^^^^^^^^
        """,
        """
        d: Dog = animal;  # <-- Error: Dog | Cat cannot assign to Dog
        ^^^^^^^^^^^^^^^^
        """,
        """
        d: Dog = animal;  # <-- Error: Dog | Cat cannot assign to Dog
        ^^^^^^^^^^^^^^^^
        """,
        """
        d: Dog = animal;  # <-- Error: Cat cannot assign to Dog
        ^^^^^^^^^^^^^^^^
        """,
        """
        r: Reptile = creature;  # <-- Error: Lion cannot assign to Reptile
        ^^^^^^^^^^^^^^^^^^^^^^
        """,
        """
        to_connect.append(nd);  # <-- Error: BaseNode cannot assign to CFGNode
                          ^^
        """,
        """
        return x.bark();  # <-- Error: x is still Dog | None here
               ^^^^
        """,
        """
        return x.bark();  # <-- Error: x is still Dog | None here
        ^^^^^^^^^^^^^^^^
        """,
        """
        result: Dog = x if (x is None) else Dog(name="d");  # <-- Error: x is NoneType in true branch
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        """
    ];

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

test "postinit_fields_not_required_in_constructor" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_postinit_fields.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0 , f"Expected no type checking errors, but got {len(
        program.errors_had
    )}: " + "\n".join([err.pretty_print() for err in program.errors_had]);
}

test "impl_body_type_checking" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_impl_body.jac");
    mod = program.compile(path, options=NO_TC);
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

"""Test that self.x = value in impl files creates valid archetype attributes."""
test "impl_self_member_assignment" {
    program = JacProgram();
    path = os.path.join(FIXTURES, "checker_impl", "checker_impl_self_member.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 0 , f"Expected 0 type errors, but got {len(
        program.errors_had
    )}: " + "\n".join([err.pretty_print() for err in program.errors_had]);
}

test "super_init_with_has_vars" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_super_init_has_vars.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 3 , f"Expected 3 type errors, but got {len(
        program.errors_had
    )}: " + "\n".join([err.pretty_print() for err in program.errors_had]);

    assert_error_pretty_found(
        """Cannot assign int to parameter 'shape_type' of type str""",
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
    path = os.path.join(CHECKER_FIXTURES, "checker_super_init_explicit.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 4 , f"Expected 4 type errors, but got {len(
        program.errors_had
    )}: " + "\n".join([err.pretty_print() for err in program.errors_had]);

    assert_error_pretty_found(
        """Cannot assign int to parameter 'name' of type str""",
        program.errors_had[0].pretty_print()
    );

    assert_error_pretty_found(
        """Cannot assign Literal["five"] to parameter 'age' of type int""",
        program.errors_had[1].pretty_print()
    );

    assert_error_pretty_found(
        """Not all required parameters were provided in the function call: 'skill'""",
        program.errors_had[2].pretty_print()
    );

    assert_error_pretty_found(
        """Cannot assign int to parameter 'owner' of type str""",
        program.errors_had[3].pretty_print()
    );
}

test "enum_type_checking" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_enum.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    expected_errors = [
        "B = \"jac\"",
        "name_err: int = Color.RED.name",
        "value_err: str = Color.BLUE.value",
        "value_status_val_err: int = Status.ACTIVE.value",
        "auto_val_err: str = AutoValueTest.THIRD.value",
        "impl_shape_name_err: int = ShapeType.SQUARE.name",
        "func_wrong_type: str = process_color"
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

test "class_based_enum_type_checking" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_class_enum.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    expected_errors = [
        "Cannot assign <Tokens.FLOAT> to int",
        "Cannot assign Literal[\"1\"] to int",
        "Cannot assign Literal[\"LSQUARE\"] to int",
        "Cannot assign Literal[\"RSQUARE\"] to int",
        "Cannot assign <AccessLevel.READ> to str",
        "Cannot assign AccessLevel | NoneType to int",
        "Cannot assign int to str"
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
    path = os.path.join(CHECKER_FIXTURES, "checker_nested_impldef.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 0 , f"Expected no type checking errors, but got {len(
        program.errors_had
    )}: " + "\n".join([err.pretty_print() for err in program.errors_had]);
}

test "callable_type_annotation" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_callable.jac");
    mod = program.compile(path, options=NO_TC);
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

"""Test unbound method call type checking (ParentClass.init(self, ...))."""
test "unbound_method_call" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_unbound_method_call.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 2 , f"Expected 2 type errors, but got {len(
        program.errors_had
    )}: " + "\n".join([err.pretty_print() for err in program.errors_had]);

    assert_error_pretty_found(
        """Cannot assign int to parameter 'name' of type str""",
        program.errors_had[0].pretty_print()
    );
    assert_error_pretty_found(
        """Not all required parameters were provided in the function call: 'name'""",
        program.errors_had[1].pretty_print()
    );
}

"""Test that passing args to a parameterless init produces errors."""
test "parameterless_init_with_args" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(FIXTURES, "checker_parameterless_init.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    # 3 errors: 'has no attribute nickname' (obj can't have undeclared self-attrs),
    # 'Named argument does not match', 'Too many positional arguments'
    assert len(program.errors_had) == 3;
    assert_error_pretty_found(
        """Named argument 'name' does not match any parameter""",
        program.errors_had[1].pretty_print()
    );
    assert_error_pretty_found(
        """Too many positional arguments""", program.errors_had[2].pretty_print()
    );
}

"""Test bare `type` parameter accepts classes but rejects instances."""
test "type_param_assignment" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_type_param.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);

    # Should have 1 error for the instance case (e1)
    assert len(program.errors_had) == 1 , f"Expected 1 type error, but got {len(
        program.errors_had
    )}: " + "\n".join([err.pretty_print() for err in program.errors_had]);

    assert_error_pretty_found(
        """Cannot assign Animal to parameter 'cls' of type type""",
        program.errors_had[0].pretty_print()
    );
}

"""Test bare-dot relative import (from . import x) resolves sibling module and catches type errors."""
test "bare_dot_relative_import" {
    path = os.path.join(CHECKER_FIXTURES, "checker_bare_dot_import.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 1;
    assert_error_pretty_found(
        """
      err: str = checker_imported.some_int;
    """,
        program.errors_had[0].pretty_print()
    );
}

"""Test type narrowing detects None assignment to non-None type in else branches."""
test "type_narrowing_none_assignment_errors" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_type_narrowing_none.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 2 , f"Expected 2 errors, got {len(
        program.errors_had
    )}";

    assert_error_pretty_found(
        """
        y: int = value;  # <-- Error: None cannot be assigned to int
    """,
        program.errors_had[0].pretty_print()
    );

    assert_error_pretty_found(
        """
        b: str = data;  # <-- Error: None cannot be assigned to str
    """,
        program.errors_had[1].pretty_print()
    );
}

"""Test match case type narrowing - validates type narrowing inside match cases."""
test "match_type_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_match_type_narrowing.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # Should have exactly 2 errors (E1 and E2 in the test file)
    assert len(program.errors_had) == 2 , f"Expected exactly 2 type errors, but got " + f"{len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);

    assert_error_pretty_found(
        """
        i: IntVal = val;  # <-- Error: StringVal cannot assign to IntVal
    """,
        program.errors_had[0].pretty_print()
    );

    assert_error_pretty_found(
        """
        s: StringVal = val;  # <-- Error: StringVal | IntVal cannot assign to StringVal
    """,
        program.errors_had[1].pretty_print()
    );
}

"""Test union of subclasses assignable to base class (match narrowing support)."""
test "union_subclass_to_base_assignment" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_match_narrowing.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # Should have exactly 1 error (E1 - wrong type inside match case)
    assert len(program.errors_had) == 1 , f"Expected exactly 1 type error, but got " + f"{len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);

    assert_error_pretty_found(
        """
        c: Cat = animal;  # <-- Error: Dog cannot assign to Cat
    """,
        program.errors_had[0].pretty_print()
    );
}

"""Test compound AND narrowing picks most specific type."""
test "compound_and_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_and_narrowing.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # E1 (attribute error after if block) is correctly reported: after narrowing
    # expires, Animal type doesn't have the narrowed-only attribute.
    assert len(program.errors_had) == 2 , f"Expected 2 type errors, but got " + f"{len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);
}

"""Test assert isinstance type narrowing."""
test "assert_isinstance_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_assert_narrowing.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # Expect exactly 1 error: the failure case where truthy assert doesn't narrow union
    assert len(program.errors_had) == 1 , f"Expected 1 type error (truthy assert failure case), but got " + f"{len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);

    # Verify the error is about accessing .value on a string literal type
    err_msg = program.errors_had[0].pretty_print();
    assert 'has no attribute "value"' in err_msg , f"Expected attribute error, got: {err_msg}";
}

"""Test assignment-based type narrowing."""
test "assignment_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_assignment_narrowing.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # All cases should pass - assignment narrows union types appropriately
    assert len(program.errors_had) == 0 , f"Expected 0 type errors, but got " + f"{len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);
}

"""Test truthiness guard narrowing for member access."""
test "guard_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_guard_narrowing.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # All cases should pass - if guard narrows T|None to T
    assert len(program.errors_had) == 0 , f"Expected 0 type errors, but got " + f"{len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);
}

"""Test impl files can access imports from their parent .jac file."""
test "impl_imports_from_parent" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_impl_imports.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);

    # Should have 3 errors for type mismatches with jaclang types (not Python stdlib)
    assert len(program.errors_had) == 3 , f"Expected 3 type errors, but got {len(
        program.errors_had
    )}: " + "\n".join([err.pretty_print() for err in program.errors_had]);

    # Verify errors reference jaclang types (ClassType, FunctionType), not Python stdlib
    assert_error_pretty_found(
        """x: types.ClassType = 90;  # <-- Error: Cannot assign int to ClassType""",
        program.errors_had[0].pretty_print()
    );
    assert "checker_impl_imports.impl.jac" in program.errors_had[0].loc.mod_path;

    assert_error_pretty_found(
        """y: types.FunctionType = "wrong";  # <-- Error: Cannot assign str to FunctionType""",
        program.errors_had[1].pretty_print()
    );
    assert "checker_impl_imports.impl.jac" in program.errors_had[1].loc.mod_path;
}

test "union_and_optional_special_forms" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_union_special_form.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    # 3 errors: Union[int,str]->int, pipe int|str->int, Optional[str]->int
    assert len(program.errors_had) == 3 , f"Expected 3 errors, got {len(
        program.errors_had
    )}: " + "\n".join([err.pretty_print() for err in program.errors_had]);

    # Union[int, str] produces same type as int | str
    assert_error_pretty_found(
        """
        y: int = x;  # <-- Error: int | str not assignable to int
        ^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
    assert_error_pretty_found(
        """
        z: int = x;  # <-- Error: int | str not assignable to int
        ^^^^^^^^^^^
    """,
        program.errors_had[1].pretty_print()
    );

    # Optional[str] resolves to str | None
    assert_error_pretty_found(
        """
        y: int = x;  # <-- Error: str | None not assignable to int
        ^^^^^^^^^^^
    """,
        program.errors_had[2].pretty_print()
    );
}

"""Test __getattr__ support: dynamic attrs use __getattr__ return type."""
test "getattr_support" {
    program = JacProgram();
    path = os.path.join(FIXTURES, "checker_getattr_support.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);

    user_errors = [
        err
        for err in program.errors_had
        if "vendor" not in err.loc.mod_path and "typeshed" not in err.loc.mod_path
    ];

    # Expect 2 errors:
    # 1. assigning str to int (proves __getattr__ return type is enforced)
    # 2. NoGetAttr.nonexistent (correct: class has no __getattr__ and no such attribute)
    assert len(user_errors) == 2 , f"Expected 2 errors, got {len(user_errors)}";
    assert "Cannot assign" in user_errors[0].pretty_print();
    assert "has no attribute" in user_errors[1].pretty_print();
}

"""Test NamedTuple type checking: constructor accepts positional arguments for fields."""
test "namedtuple_constructor" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_namedtuple.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);

    user_errors = [
        err
        for err in program.errors_had
        if "vendor" not in err.loc.mod_path and "typeshed" not in err.loc.mod_path
    ];

    # NamedTuple should accept positional arguments for fields - no errors expected
    assert len(user_errors) == 0 , f"Expected 0 errors for NamedTuple, got {len(
        user_errors
    )}: " + "\n".join([err.pretty_print() for err in user_errors]);
}

"""Test overload resolution prefers concrete types over Unknown in type_args.

When a method has multiple overloads (e.g., str.split), and one returns
list[LiteralString] (Unknown) and another returns list[str], the type
checker should prefer the concrete list[str] overload.
"""
test "overload_resolution_concrete_types" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_overload_resolution.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);

    user_errors = [
        err
        for err in program.errors_had
        if "vendor" not in err.loc.mod_path and "typeshed" not in err.loc.mod_path
    ];

    # str.split() -> list[str], list[str][0] -> str, str + str -> str
    # No errors expected when overload resolution picks concrete types
    assert len(user_errors) == 0 , f"Expected 0 errors, got {len(user_errors)}: " + "\n".join(
        [err.pretty_print() for err in user_errors]
    );
}

test "literal_string_type_checking" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_literal_string.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);

    user_errors = [
        err
        for err in program.errors_had
        if "vendor" not in err.loc.mod_path and "typeshed" not in err.loc.mod_path
    ];

    assert len(user_errors) == 2 , f"Expected 2 errors, got {len(user_errors)}: " + "\n".join(
        [err.pretty_print() for err in user_errors]
    );

    assert_error_pretty_found(
        """Cannot assign Literal["not an int"] to int""", user_errors[0].pretty_print()
    );
    assert_error_pretty_found(
        """Cannot assign Literal["wrong"] to parameter 'n' of type int""",
        user_errors[1].pretty_print()
    );
}

"""Test module-level function overload resolution.

Module-level functions like math.floor have multiple @overload signatures.
The type checker must collect all overloads and try each one when checking
argument compatibility. This ensures that math.floor(3.7) resolves to the
_SupportsFloatOrIndex overload (returning int) rather than failing on the
_SupportsFloor protocol overload.
"""
test "module_level_overload" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_module_level_overload.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);

    user_errors = [
        err
        for err in program.errors_had
        if "vendor" not in err.loc.mod_path and "typeshed" not in err.loc.mod_path
    ];

    # Expect 1 error: assigning math.sin(float) -> float to int
    assert len(user_errors) == 1 , f"Expected 1 error, got {len(user_errors)}: " + "\n".join(
        [err.pretty_print() for err in user_errors]
    );

    assert_error_pretty_found(
        """Cannot assign float to int""", user_errors[0].pretty_print()
    );
}

"""Verifies two import resolution fixes:
- MyClass: arrived via star re-export chain fix (modresolver local-first for relative imports)
- subpkg: resolved as ModuleType fix (subpackage __init__.py treated correctly)
"""
test "py_pkg_imports" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_py_pkg_imports.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0;
    assert mod.sym_tab.lookup("MyClass") is not None , "MyClass not in sym_tab - star re-export chain broken";
    assert mod.sym_tab.lookup("subpkg") is not None , "subpkg not in sym_tab - subpackage resolution broken";
}

"""Test ClassVar[T] type annotation unwraps to T correctly."""
test "classvar_type_annotation" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_classvar.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0 , f"Expected no type errors, but got {len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);
}

"""Test Final[UnionType] does not crash with 'UnionType has no attribute shared'.
When unwrapping Final[T], if T is a UnionType, we must delegate to assign_type
instead of accessing .shared directly.
"""
test "final_union_type_no_crash" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_final_union_type.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    # Should complete without crashing - no errors expected
    assert len(program.errors_had) == 0;
}

# =============================================================================
# Generic Type Inference Tests (Pyright-style)
# =============================================================================
test "enumerate_type_inference" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_gap_enumerate_type.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 2 , f"Expected 2 type errors, got {len(
        program.errors_had
    )}";
    errors_str = "\n".join(e.pretty_print() for e in program.errors_had);
    assert "Cannot assign int to str" in errors_str;
    assert "Cannot assign Item to int" in errors_str;
}

test "generic_call_inference" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_gap_generic_call_inference.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 2 , f"Expected 2 type errors, got {len(
        program.errors_had
    )}";
    errors_str = "\n".join(e.pretty_print() for e in program.errors_had);
    assert "Cannot assign Item to str" in errors_str;
    assert "Cannot assign Item to int" in errors_str;
}

"""Test bidirectional type inference for container literals and type[X] covariance."""
test "bidirectional_container_inference" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_bidirectional_container.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    # 5 errors: bad_list return, bad_dict return, bad_set return,
    # bad list assignment, bad type[int] assignment
    assert len(program.errors_had) == 5 , f"Expected 5 type errors, got {len(
        program.errors_had
    )}:\n" + "\n".join(e.pretty_print() for e in program.errors_had);

    errors_str = "\n".join(e.pretty_print() for e in program.errors_had);
    # Container literal mismatches show parameterized types in error messages
    assert "list[Dog | Cat], expected list[int]" in errors_str , "Expected parameterized list error";
    assert "dict[" in errors_str and "expected dict[str, int]" in errors_str , "Expected parameterized dict error";
    assert "set[Dog], expected set[int]" in errors_str , "Expected parameterized set error";
    # Assignment mismatch with parameterized types
    assert "list[Dog] to list[int]" in errors_str , "Expected parameterized list assign error";
    # type[X] covariance: Dog is not subclass of int
    assert "Dog to type[int]" in errors_str , "Expected type[int] covariance error";
}

"""Test Self type resolution in method return types."""
test "self_type_resolution" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_gap_self_type.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    # Should have 3 errors for enumerate, list, and dict Self returns
    assert len(program.errors_had) == 3 , f"Expected 3 type errors, got {len(
        program.errors_had
    )}";

    errors_str = "\n".join(e.pretty_print() for e in program.errors_had);
    assert "Cannot assign enumerate to int" in errors_str , "Expected error for enumerate.__iter__() Self return";
    assert "Cannot assign list" in errors_str and "to int" in errors_str , "Expected error for list.copy() Self return";
    assert "Cannot assign dict" in errors_str and "to str" in errors_str , "Expected error for dict.copy() Self return";
}

"""Test walrus operator (:=) type narrowing with is not None."""
test "walrus_operator_narrowing" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_walrus_narrowing.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0 , f"Expected 0 type errors, got {len(
        program.errors_had
    )}:\n" + "\n".join(e.pretty_print() for e in program.errors_had);
}

"""Test type[T] subscript member access resolves to T's class members."""
test "type_subscript_member_access" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_type_subscript_member.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0 , f"Expected 0 type errors, got {len(
        program.errors_had
    )}:\n" + "\n".join(e.pretty_print() for e in program.errors_had);
}

"""Test isinstance type narrowing in ternary expressions."""
test "isinstance_ternary_narrowing" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_isinstance_ternary.jac");
    mod = program.compile(path);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0 , f"Expected 0 type errors, got {len(
        program.errors_had
    )}:\n" + "\n".join(e.pretty_print() for e in program.errors_had);
}

"""Test list(Generator[T, _, _]) returns list[T]."""
test "list_generator_type_inference" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_list_generator_inference.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0 , f"Expected 0 type errors, got {len(
        program.errors_had
    )}:\n" + "\n".join(e.pretty_print() for e in program.errors_had);
}

"""Test that return inside lambda checks against lambda's return type, not enclosing function's."""
test "bug_lambda_return_type_checks_against_enclosing_function" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_bug_lambda_return_type.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    # Case 1 and 2 should pass (valid returns), Case 3 should produce exactly 1 error
    # (str returned from lambda declared -> int).
    assert len(program.errors_had) == 1 , f"Expected 1 type error (lambda return mismatch), got {len(
        program.errors_had
    )}:\n" + "\n".join(e.pretty_print() for e in program.errors_had);
}

"""Test function type attribute access (__code__, __name__, etc.)."""
test "function_type_attrs" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_function_attrs.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0 , f"Expected 0 type errors, got {len(
        program.errors_had
    )}:\n" + "\n".join(e.pretty_print() for e in program.errors_had);
}

"""Test Any allows arbitrary attr access, but object does not."""
test "any_vs_object_attr_access" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_bug_typing_any_attr.jac");
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    # Any allows arbitrary access (no errors), but object.nonexistent should error
    assert len(program.errors_had) == 1 , f"Expected 1 type error, got {len(
        program.errors_had
    )}:\n" + "\n".join(e.pretty_print() for e in program.errors_had);
    assert_error_pretty_found(
        """
        val.nonexistent;  # <-- Error: object has no attribute "nonexistent"
            ^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

"""B2: TypeVar | union return types resolve correctly (not Unknown)."""
test "typevar_union_return_types" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_typevar_union_return.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0 , f"Expected 0 type errors, got {len(
        program.errors_had
    )}:\n" + "\n".join(e.pretty_print() for e in program.errors_had);
}

"""B2c: Method-level TypeVar inference in overload resolution."""
test "typevar_overload_inference" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_typevar_overload_inference.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0 , f"Expected 0 type errors, got {len(
        program.errors_had
    )}:\n" + "\n".join(e.pretty_print() for e in program.errors_had);
}

"""B1: typing.cast() returns the target type."""
test "typing_cast_special_form" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_typing_cast.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0 , f"Expected 0 type errors, got {len(
        program.errors_had
    )}:\n" + "\n".join(e.pretty_print() for e in program.errors_had);
}

"""B3: match/case narrows the match subject inside case bodies."""
test "match_case_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_match_case_narrowing.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0 , f"Expected 0 type errors, got {len(
        program.errors_had
    )}:\n" + "\n".join(e.pretty_print() for e in program.errors_had);
}

"""Enum static methods resolve correctly (not treated as enum members)."""
test "enum_static_method" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_enum_static_method.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0 , f"Expected 0 type errors, got {len(
        program.errors_had
    )}:\n" + "\n".join(e.pretty_print() for e in program.errors_had);
}
