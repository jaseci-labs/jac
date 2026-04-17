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

test "dunder_new_direct_call" {
    path = os.path.join(CHECKER_FIXTURES, "checker_dunder_new_direct.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    # object.__new__(self.__class__) and object.__new__(cls) should NOT error.
    # Only the call with too many args should produce errors (one per extra arg).
    e1051_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1051"
    ];
    assert len(e1051_errors) == 2 , f"Expected 2 E1051 errors, got {len(
        e1051_errors
    )}: " + "\n".join(e.pretty_print() for e in e1051_errors);
    # Both errors should be on the too-many-args line
    for e in e1051_errors {
        assert e.loc and e.loc.first_line == 32 , f"Expected error on line 32, got line {e.loc.first_line
            if e.loc
            else '?'}";
    }
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
    # 6 errors: 'has no attribute name' (obj can't have dynamic attrs),
    # 3 Unknown self in static/classmethod, 2 type mismatches
    assert len(program.errors_had) == 6;
    assert_error_pretty_found(
        """
        alice.age = '909';  # <-- Error
        ^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[5].pretty_print()
    );
}

test "checker_import_missing_module" {
    path = os.path.join(CHECKER_FIXTURES, "checker_import_missing_module.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 6;
}

test "checker_jac_runtime_alias" {
    # `@jac/runtime` is a virtual module resolved by the bundler to
    # jaclang/runtimelib/client_runtime.cl.jac. The type checker must use the
    # same mapping so imported symbols keep their declared types (e.g.
    # jacIsLoggedIn -> bool) instead of decaying to Unknown and producing
    # spurious assignment errors.
    path = os.path.join(CHECKER_FIXTURES, "checker_jac_runtime_alias.cl.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0 , f"unexpected errors: {[
        e.pretty_print() for e in program.errors_had
    ]}";
    assert len(program.warnings_had) == 0 , f"unexpected warnings: {[
        w.pretty_print() for w in program.warnings_had
    ]}";
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
        os.path.join(CHECKER_FIXTURES, "checker_inherit_init_params.jac"), options=NO_TC
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
    # TODO: W1051 (unresolved expression type) currently fires on the
    # `with AgentVisitor entry` event-type reference and on nodes reached
    # inside typeshed stubs. Filtered here until evaluator coverage gaps
    # and the stub-file false positives are addressed in a follow-up PR.
    non_w1051 = [
        w
        for w in program.warnings_had
        if w.code.code != "W1051"
    ];
    assert len(non_w1051) == 0;
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

test "unannotated_reassignment_widens" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_none_sentinel_reassignment.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 2 , f"Expected 2 type errors, but got {len(
        program.errors_had
    )}: " + "\n".join([err.pretty_print() for err in program.errors_had]);
    assert_error_pretty_found(
        """
        typed_binding = 99;  # <-- Error
        ^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
    assert_error_pretty_found(
        """
        strict = 7;  # <-- Error
        ^^^^^^^^^^^
    """,
        program.errors_had[1].pretty_print()
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
    """, add_error
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
        os.path.join(CHECKER_FIXTURES, "checker_union_member_access.jac"), options=NO_TC
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
    # Bare list[Any] indexing yields Any, so len(some[0]) is valid.
    assert len(program.errors_had) == 0;
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

test "property_assignment_type_checking" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_property_assignment.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    # Expected errors (5 total):
    #   1. b.cached_val = 99            — int to str  (@cached_property wrong type)
    #   2. b.cached_num = "not_an_int"  — str to int  (@cached_property wrong type)
    #   3. b.readonly_val = 1           — read-only   (@property no setter)
    #   4. h.base.cached_num = "wrong"  — str to int  (chained @cached_property)
    #   5. h.base.readonly_val = 2      — read-only   (chained @property no setter)
    assert len(program.errors_had) == 5 , f"Expected 5 errors, got " + f"{len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);

    # --- @cached_property wrong-type assignments ---
    # LHS must resolve to the getter return type (str / int), NOT a function type.
    assert_error_pretty_found(
        """
        b.cached_val = 99;                         # <-- Error (int to str)
    """,
        program.errors_had[0].pretty_print()
    );
    assert "str" in program.errors_had[0].pretty_print();
    assert "<function" not in program.errors_had[0].msg;

    assert_error_pretty_found(
        """
        b.cached_num = "not_an_int";               # <-- Error (str to int)
    """,
        program.errors_had[1].pretty_print()
    );
    assert "int" in program.errors_had[1].pretty_print();
    assert "<function" not in program.errors_had[1].msg;

    # --- @property (no setter): dedicated read-only diagnostic (E1005) ---
    assert_error_pretty_found(
        """
        b.readonly_val = 1;                        # <-- Error (read-only)
    """,
        program.errors_had[2].pretty_print()
    );
    assert "read-only" in program.errors_had[2].pretty_print();
    assert "readonly_val" in program.errors_had[2].pretty_print();

    # --- Chained @cached_property wrong-type ---
    assert_error_pretty_found(
        """
        h.base.cached_num = "wrong";               # <-- Error (str to int)
    """,
        program.errors_had[3].pretty_print()
    );
    assert "int" in program.errors_had[3].pretty_print();
    assert "<function" not in program.errors_had[3].msg;

    # --- Chained read-only @property ---
    assert_error_pretty_found(
        """
        h.base.readonly_val = 2;                   # <-- Error (read-only)
    """,
        program.errors_had[4].pretty_print()
    );
    assert "read-only" in program.errors_had[4].pretty_print();
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

test "expr_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_expr_narrowing.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0 , f"Expected no type errors, but got {len(
        program.errors_had
    )}: " + "\n".join([err.pretty_print() for err in program.errors_had]);
}

test "reassign_in_branch" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_reassign_in_branch.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0 , f"Expected no type errors, but got {len(
        program.errors_had
    )}: " + "\n".join([err.pretty_print() for err in program.errors_had]);
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
        "Cannot assign int to str",
        "Cannot assign <Priority.HIGH> to str"
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
        os.path.join(CHECKER_FIXTURES, "checker_type_narrowing_none.jac"), options=NO_TC
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

    # CFG correctly reports x.offspring error after early-exit if-body
    # (line 203: Animal has no offspring — only reachable on false branch).
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

"""Parenthesized BoolExpr conditions wire the short-circuit CFG."""
test "parenthesized_bool_cond" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_parenthesized_bool_cond.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0 , f"Expected 0 type errors, but got " + f"{len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);
}

"""Assignment barrier: strict narrowing, widening reset, in-branch re-narrow."""
test "assignment_barrier" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_assignment_barrier.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    # The widening reassignment in `widen_via_reassign` resets `x` to
    # `int | None`, so `return x` against the `int` return type is the
    # only expected error.
    assert len(program.errors_had) == 1 , f"Expected 1 type error, but got " + f"{len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);
    msg = program.errors_had[0].pretty_print();
    assert 'Cannot return int | NoneType' in msg , f"Expected widening-reset error, got: {msg}";
}

"""Pre-statement narrowing reaches inside expression sub-CFGs."""
test "pre_expr_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_pre_expr_narrowing.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    # All three shapes (early-return guard, OR-inverse guard, if-wrap)
    # must carry the enclosing statement's narrowing into ternary
    # branches so member access on the narrowed type succeeds.
    assert len(program.errors_had) == 0 , f"Expected 0 type errors, but got " + f"{len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);
}

"""Ternary conditions with BoolExpr narrow their branches per-operand."""
test "ternary_bool_cond_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_ternary_bool_cond_narrowing.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    # All four shapes must narrow cleanly: AND-in-true, OR-inverse-in-else
    # (bare and parenthesized), and the plain if/else control.
    assert len(program.errors_had) == 0 , f"Expected 0 type errors, but got " + f"{len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);
}

"""Starred-unpack assignment acts as a narrowing barrier."""
test "starred_unpack_barrier" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_starred_unpack_barrier.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    # After `(head, *rest) = ...` inside `if rest is not None`, rest
    # must reset to list[int] | None. The typed-local assignment then
    # fails because list[int] | None is not assignable to list[int].
    assert len(program.errors_had) == 1 , f"Expected 1 type error, but got " + f"{len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);
    msg = program.errors_had[0].pretty_print();
    assert 'Cannot assign list[int] | NoneType to list[int]' in msg , f"Expected starred-unpack reset error, got: {msg}";
}

"""Tuple-unpacking assignment acts as a narrowing barrier."""
test "tuple_unpack_barrier" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_tuple_unpack_barrier.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    # After `(x, _) = reset_pair()` inside `if x is not None`, x must
    # reset to int | None. `return x` then fails against int.
    assert len(program.errors_had) == 1 , f"Expected 1 type error, but got " + f"{len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);
    msg = program.errors_had[0].pretty_print();
    assert 'Cannot return int | NoneType' in msg , f"Expected widening-reset error, got: {msg}";
}

"""Destructuring assignment narrows by RHS element type when available."""
test "destructure_element_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_destructure_element_narrowing.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    # Four narrowing cases must succeed; only `no_narrow_non_strict`
    # should error because its RHS element type matches the declared
    # type and therefore fails the strict-narrowing check.
    assert len(program.errors_had) == 1 , f"Expected 1 type error, but got " + f"{len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);
    msg = program.errors_had[0].pretty_print();
    assert 'Cannot return int | str' in msg , f"Expected non-strict-narrow error, got: {msg}";
}

"""Match-case narrowing is killed by a later assignment to the subject."""
test "match_case_reassign_reset" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_match_case_reassign_reset.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 4 , f"Expected 4 type errors, but got " + f"{len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);
    assert 'Cannot assign int to Shape' in program.errors_had[0].pretty_print();
    for i in [1, 2, 3] {
        msg = program.errors_had[i].pretty_print();
        assert 'has no attribute "sides"' in msg , f"Expected attribute error at index {i}, got: {msg}";
    }
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

"""Test stdlib star re-export resolution (e.g., asyncio.Queue from asyncio.queues).

Ensures the type checker follows star imports in stub files so that
symbols like Queue, SimpleQueue are not Unknown.
"""
test "stdlib_star_reexport" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_stdlib_star_reexport.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0 , f"Expected no type errors, but got {len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);
    assert mod.sym_tab.lookup("Queue") is not None , "Queue not resolved - asyncio star re-export broken";
    assert mod.sym_tab.lookup("SimpleQueue") is not None , "SimpleQueue not resolved - queue star re-export broken";
}

"""Test relative .pyi re-export resolution (e.g., os.pathsep from os.path).

`os/__init__.pyi` does `from .path import (pathsep as pathsep, ...)` and
the originals live in `posixpath.pyi`. For the relative `from .path`
import to resolve, the module resolver must try `.pyi` extensions (not
just `.py`/`.jac`) when searching sibling files of a stub package.

Regression: before the fix, `os.pathsep` resolved to <Unknown>, so
`str.split(os.pathsep)` failed with a misleading E1054
\"No matching overload found\".
"""
test "stdlib_pyi_relative_reexport" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_stdlib_pyi_relative_reexport.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0 , f"Expected no type errors, but got {len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);
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

"""Self member assignments with TypeVar annotations propagate through inheritance."""
test "generic_self_member_type_propagation" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_generic_self_member.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0 , f"Expected 0 type errors, got {len(
        program.errors_had
    )}:\n" + "\n".join(e.pretty_print() for e in program.errors_had);
}

"""Attribute access on a `Self`-typed value resolves via the enclosing class.

Regression for the E1031 raised on `unloaded.id = self.id;` in
jac/jaclang/jac0core/impl/archetype.impl.jac, where
`object.__new__(self.__class__)` returns Self and the checker treated Self as an
unbounded TypeVar with no member access. After the fix, attribute access on a
Self-typed value resolves via the enclosing class — Pyright behavior.
"""
test "self_typevar_attr_access_via_enclosing_class" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_self_type_attr_access.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);
    user_errors = [
        err
        for err in program.errors_had
        if "vendor" not in err.loc.mod_path and "typeshed" not in err.loc.mod_path
    ];
    assert len(user_errors) == 0 , f"Expected 0 user errors, got {len(
        user_errors
    )}:\n" + "\n".join(e.pretty_print() for e in user_errors);
    # Defensive: even any vendor-side errors must not still claim "type Self"
    # for the user fixture's positions — that would mean the fix didn't take.
    for err in program.errors_had {
        if "checker_self_type_attr_access" in err.loc.mod_path {
            assert "type \"Self\"" not in err.pretty_print() , f"Error should not refer to opaque Self type, got:\n{err.pretty_print()}";
        }
    }
}

# ============================================================================
# Narrowing gap exposure tests
#
# These tests document known type checker narrowing limitations.
# Each test asserts the CURRENT (broken) error count. When a gap is fixed,
# the error count should decrease — update the assertion accordingly.
# The fixture has ok_ functions (should pass) and fail_ functions (currently broken).
# ============================================================================
"""Gap A: Early return narrowing after nested if block join points.

After `if val is None { return; }`, val is narrowed to non-None for the entire
rest of the function. Fixed by propagating affected_symbols through already-linked
internal CFG nodes when sibling-to-sibling edges are created in _link_sequential.
"""
test "narrowing_gap_a_early_return_after_nested_if" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_gaps.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # Gap A errors are on lines 85-129 (fail_early_return_* and fail_truthiness/isinstance variants)
    gap_a_errors = [
        e
        for e in program.errors_had
        if e.loc and 85 <= e.loc.first_line <= 129
    ];
    # FIXED: CFG affected_symbols propagation now reaches internal nodes
    assert len(gap_a_errors) == 0 , f"Gap A should have 0 errors (fixed), got {len(
        gap_a_errors
    )}:\n" + "\n---\n".join(e.pretty_print() for e in gap_a_errors);
}

"""Gap B: Ternary narrowing applied to function arguments in ternary branches.

In `use_foo(val) if isinstance(val, Foo) else 0`, the ternary handler correctly
narrows `val` in the true branch. Fixed by eagerly evaluating the IfElseExpr in
enter_if_else_expr so narrowing scopes are active before children are visited.
"""
test "narrowing_gap_b_ternary_fn_arg" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_gaps.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # Gap B errors are on lines 155-170 (fail_ternary_*_fn_arg functions)
    gap_b_errors = [
        e
        for e in program.errors_had
        if e.loc and 155 <= e.loc.first_line <= 170
    ];
    # FIXED: eagerly evaluating IfElseExpr in enter_if_else_expr caches narrowed
    # types on child nodes before the walker visits them.
    assert len(gap_b_errors) == 0 , f"Gap B should have 0 errors (fixed), got {len(
        gap_b_errors
    )}:\n" + "\n---\n".join(e.pretty_print() for e in gap_b_errors);
}

"""Gap C: Ternary narrowing applied to attribute access on narrowed variable.

In `val.attr if val else 0`, the true branch correctly narrows `val` from T|None
to T. Fixed by eagerly evaluating IfElseExpr (same fix as Gap B).
"""
test "narrowing_gap_c_ternary_attr_access" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_gaps.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # Gap C errors are on lines 180-196 (fail_ternary_attr_* functions)
    gap_c_errors = [
        e
        for e in program.errors_had
        if e.loc and 180 <= e.loc.first_line <= 196
    ];
    # FIXED: same root cause as Gap B — eagerly evaluating IfElseExpr resolves this.
    assert len(gap_c_errors) == 0 , f"Gap C should have 0 errors (fixed), got {len(
        gap_c_errors
    )}:\n" + "\n---\n".join(e.pretty_print() for e in gap_c_errors);
}

"""Verify ok_ functions in narrowing gaps fixture produce no errors.

The ok_ prefixed functions test patterns that DO work correctly and should
never regress. This test ensures they remain error-free.
"""
test "narrowing_gaps_ok_functions_no_errors" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_gaps.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # ok_ functions are on lines 64-82 — these should produce no errors
    ok_errors = [
        e
        for e in program.errors_had
        if e.loc and 64 <= e.loc.first_line <= 82
    ];
    assert len(ok_errors) == 0 , f"ok_ functions should produce no errors, got {len(
        ok_errors
    )}:\n" + "\n---\n".join(e.pretty_print() for e in ok_errors);
}

"""Total error count for narrowing gaps fixture.

When any gap is fixed, this total will decrease. Update accordingly.
"""
test "narrowing_gaps_total_error_count" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_gaps.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # All gaps fixed: Gap A (CFG propagation), Gap B+C (eager IfElseExpr evaluation),
    # Gap D (assignment in if-body narrows after block).
    assert len(program.errors_had) == 0 , f"Expected 0 errors (all gaps fixed), got {len(
        program.errors_had
    )}:\n" + "\n---\n".join(e.pretty_print() for e in program.errors_had);
}

"""Gap D: Assignment in if-body narrows type after the if block."""
test "narrowing_gap_d_assign_in_if_body" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_gaps.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # Gap D ok_ functions: lines 210-300 (includes try/finally pattern)
    gap_d_errors = [
        e
        for e in program.errors_had
        if e.loc and 210 <= e.loc.first_line <= 300
    ];
    assert len(gap_d_errors) == 0 , f"Gap D should have 0 errors (fixed), got {len(
        gap_d_errors
    )}:\n" + "\n---\n".join(e.pretty_print() for e in gap_d_errors);
}

# ============================================================================
# Runtime.impl.jac type checker issues
# These document false positive errors found in runtime.impl.jac.
# ============================================================================
"""Runtime narrowing: truthiness + isinstance on attribute access in `and` chains.

Tests that `obj.attr and isinstance(obj.attr, T)` correctly narrows obj.attr
from a multi-member union through both truthiness and isinstance. Uses AtomTrailer
nodes (attribute access) to match the real runtime.impl.jac patterns.
"""
test "runtime_attr_truthiness_and_isinstance_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_runtime_errors.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # Issue 1 ok_ functions: lines 60-100 (attr truthiness, isinstance, loop patterns)
    i1_errors = [
        e
        for e in program.errors_had
        if e.loc and 60 <= e.loc.first_line <= 100
    ];
    assert len(i1_errors) == 0 , f"Attr truthiness/isinstance narrowing should produce 0 errors, got {len(
        i1_errors
    )}:\n" + "\n---\n".join(e.pretty_print() for e in i1_errors);
}

"""Runtime narrowing: compound `or` guard on attribute access after early exit.

Tests that after `if (not obj or not obj.attr) { raise/return; }`, obj is narrowed
to non-None for subsequent attribute access. Uses AtomTrailer nodes to match the
real runtime.impl.jac `spec` pattern.
"""
test "runtime_compound_or_guard_attr_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_runtime_errors.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # Issue 2 ok_ functions: lines 120-175 (compound or guard patterns)
    i2_errors = [
        e
        for e in program.errors_had
        if e.loc and 120 <= e.loc.first_line <= 175
    ];
    assert len(i2_errors) == 0 , f"Compound or guard narrowing should produce 0 errors, got {len(
        i2_errors
    )}:\n" + "\n---\n".join(e.pretty_print() for e in i2_errors);
}

"""Ternary isinstance narrowing should exclude generic types (list[T]) from union."""
test "runtime_ternary_isinstance_generic_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_runtime_errors.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # Issue 3 ok_ functions: lines 195-230 (ternary isinstance with generic types)
    i3_errors = [
        e
        for e in program.errors_had
        if e.loc and 195 <= e.loc.first_line <= 230
    ];
    assert len(i3_errors) == 0 , f"Ternary isinstance generic narrowing should produce 0 errors, got {len(
        i3_errors
    )}:\n" + "\n---\n".join(e.pretty_print() for e in i3_errors);
}

"""isinstance narrowing should preserve generic type parameters from union members."""
test "runtime_isinstance_preserves_generic_params" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_runtime_errors.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # Issue 4 ok_ functions: lines 240-290 (isinstance preserving generics)
    i4_errors = [
        e
        for e in program.errors_had
        if e.loc and 240 <= e.loc.first_line <= 290
    ];
    assert len(i4_errors) == 0 , f"isinstance generic preservation should produce 0 errors, got {len(
        i4_errors
    )}:\n" + "\n---\n".join(e.pretty_print() for e in i4_errors);
}


"""Total error count for runtime errors fixture — all patterns should pass."""
test "runtime_errors_total" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_runtime_errors.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 0 , f"All runtime patterns should produce 0 errors, got {len(
        program.errors_had
    )}:\n" + "\n---\n".join(e.pretty_print() for e in program.errors_had);
}

# ============================================================================
# Root cause tests for type checker limitations (from runtime.impl.jac)
#
# Each test documents a key type checker root cause with minimal reproduction.
# Tests assert the CURRENT (broken) error count. When a root cause is fixed,
# the error count should drop to 0 — update the assertion accordingly.
# ============================================================================
"""Root Cause 1: No narrowing after `raise`.

After `if obj.attr is None { raise ...; }`, obj.attr should be narrowed from
T|None to T. Currently the type checker doesn't narrow through raise, so
subsequent attribute access on obj.attr produces false positive E1099 errors.

Mirrors: runtime.impl.jac lines 1964-1978 (JacRuntime.program.mtir_map after
raise on None check).
"""
test "root_cause_1_raise_does_not_narrow" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # ok_ function (line 96-101) must produce no errors
    ok_errors = [
        e
        for e in program.errors_had
        if e.loc and 96 <= e.loc.first_line <= 101
    ];
    assert len(ok_errors) == 0 , f"ok_raise_narrowing_simple should have 0 errors, got {len(
        ok_errors
    )}:\n" + "\n---\n".join(e.pretty_print() for e in ok_errors);

    # fail_ functions (lines 105-134) currently produce false positive errors
    rc1_errors = [
        e
        for e in program.errors_had
        if e.loc and 105 <= e.loc.first_line <= 134
    ];
    # FIXED: Raise narrowing now promotes inverted narrowings to parent scope.
    assert len(rc1_errors) == 0 , f"Expected 0 raise-narrowing errors (fixed), got {len(
        rc1_errors
    )}:\n" + "\n---\n".join(e.pretty_print() for e in rc1_errors);
}

"""Root Cause 2: Unknown type cascades into N errors.

When an attribute access resolves to Unknown (e.g., accessing a subclass-only
attribute through a base-class reference), every subsequent access on that
Unknown value produces another E1032 error. One root cause produces N errors.

Mirrors: runtime.impl.jac lines 933-952 (Memory.l3 -> Unknown -> .values()).
"""
test "root_cause_2_unknown_cascade" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # fail_ functions (lines 148-162) — one root E1030 cascades into E1032s
    rc2_errors = [
        e
        for e in program.errors_had
        if e.loc and 148 <= e.loc.first_line <= 162
    ];
    # Cascading E1032 suppressed for chained AtomTrailer/FuncCall targets.
    # Name targets still report: persistence.some_attr, data.values() are first
    # attribute accesses on Unknown variables — each is a real diagnostic.
    # 5: 2 root E1030 + 2 E1032 on Name targets + 1 return mismatch.
    assert len(rc2_errors) == 5 , f"Expected 5 unknown-cascade errors, got {len(
        rc2_errors
    )}:\n" + "\n---\n".join(e.pretty_print() for e in rc2_errors);
}

"""Root Cause 3: Callable type annotation resolves to _SpecialForm.

When a parameter is annotated as `Callable`, the checker resolves the type to
`_SpecialForm` (typing internal) instead of the actual callable protocol. This
means __name__ access fails and passing Callable to Callable[...] fails.

Mirrors: runtime.impl.jac lines 1204-1212 (test_fun: Callable -> __name__),
line 1837 (caller: Callable -> _SpecialForm).
"""
test "root_cause_3_callable_as_special_form" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # fail_ functions (lines 175-193) — Callable resolves to _SpecialForm
    rc3_errors = [
        e
        for e in program.errors_had
        if e.loc and 175 <= e.loc.first_line <= 193
    ];
    # FIXED: Bare Callable now resolves to FunctionType (gradual form).
    assert len(rc3_errors) == 0 , f"Expected 0 callable errors (fixed), got {len(
        rc3_errors
    )}:\n" + "\n---\n".join(e.pretty_print() for e in rc3_errors);
}

"""Root Cause 4: Assignment to narrowed-None field rejected.

Inside `if dest.nd is None { dest.nd = value; }`, the checker narrows dest.nd
to NoneType in the true branch. But reassignment with a valid value should be
accepted — the checker incorrectly rejects it as "Cannot assign T to NoneType".

Mirrors: runtime.impl.jac line 1353 (last.nd = post_filter after `is None` check).
"""
test "root_cause_4_assign_to_narrowed_none" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # fail_ function (lines 208-216) — assign Callable to narrowed-NoneType field
    rc4_errors = [
        e
        for e in program.errors_had
        if e.loc and 208 <= e.loc.first_line <= 216
    ];
    # FIXED: Assignment now uses declared field type, not narrowed type.
    assert len(rc4_errors) == 0 , f"Expected 0 assign-to-narrowed-None errors (fixed), got {len(
        rc4_errors
    )}:\n" + "\n---\n".join(e.pretty_print() for e in rc4_errors);
}

"""Root Cause 5: String slicing loses type information.

When a str is sliced (s[1:], s[:-3]) or indexed (s[0]), the type checker resolves
the result to Unknown instead of str. Subsequent string method calls fail with E1032.

Mirrors: runtime.impl.jac line 1096 (chomp_target = chomp_target[1:] -> .startswith fails).
"""
test "root_cause_5_string_slice_preserves_type" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # Regression guard for the former "string slice loses type" root cause.
    # The pass_ functions exercise the three patterns that used to degrade
    # str to Unknown. They must type-check cleanly. See the fixture header
    # comment above the pass_string_* functions for the full fix summary.
    rc5_errors = [
        e
        for e in program.errors_had
        if e.loc and 239 <= e.loc.first_line <= 258
    ];
    assert len(rc5_errors) == 0 , f"Expected 0 string-slice errors, got {len(
        rc5_errors
    )}:\n" + "\n---\n".join(e.pretty_print() for e in rc5_errors);
}

"""Root Cause 6: Stdlib return types resolve to Unknown.

When calling stdlib functions like importlib.util.spec_from_file_location,
the return type resolves to Unknown instead of ModuleSpec|None. All subsequent
attribute access (.origin, .loader, .submodule_search_locations) cascades.
This is the single largest source of errors in runtime.impl.jac (~20 errors).

Mirrors: runtime.impl.jac lines 1118-1165 (spec_from_file_location chain).
"""
test "root_cause_6_stdlib_returns_unknown" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # fail_ functions (lines 267-305) — importlib.util returns Unknown
    rc6_errors = [
        e
        for e in program.errors_had
        if e.loc and 267 <= e.loc.first_line <= 305
    ];
    # importlib.util resolves to Unknown — each function using it reports errors.
    # Cascade suppression handles chained AtomTrailer accesses but not Name targets.
    assert len(rc6_errors) == 15 , f"Expected 15 stdlib-unknown errors, got {len(
        rc6_errors
    )}:\n" + "\n---\n".join(e.pretty_print() for e in rc6_errors);
}

"""Root Cause 7: Nullable attribute access without raise guard.

When a field is typed as T|None (like user_root: NodeAnchor|None) and code
accesses attributes on it without an explicit None check, or through a ternary
where one branch is nullable, the checker correctly flags it. These are real
bugs in runtime.impl.jac that produce E1099 errors.

Mirrors: runtime.impl.jac lines 930-952 (ranchor from ternary with nullable),
line 961 (user_root.archetype), line 1576 (user_root.id).
"""
test "root_cause_7_nullable_attr_access" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # fail_ functions (lines 316-350) — nullable access without guard
    rc7_errors = [
        e
        for e in program.errors_had
        if e.loc and 316 <= e.loc.first_line <= 350
    ];
    # 8 errors: 4 E1099 (attr missing from NoneType) + 4 E1002 (return Unknown)
    assert len(rc7_errors) == 8 , f"Expected 8 nullable-access errors, got {len(
        rc7_errors
    )}:\n" + "\n---\n".join(e.pretty_print() for e in rc7_errors);
}

"""Root Cause 8: Dynamic / runtime class attributes not recognized.

When code accesses attributes that are set dynamically at runtime (via setattr,
type(), or metaclass magic), the checker doesn't know about them. Also, accessing
attributes on object-typed params fails because object has a minimal interface.

Mirrors: runtime.impl.jac line 1001 (type[Archetype].reports),
line 1947 (JacByLLM._default_llm_instance), line 1888 (object.call_params),
line 2221 (ThreadPoolExecutor.submit).
"""
test "root_cause_8_dynamic_class_attrs" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # fail_ functions (lines 360-390) — dynamic attrs and stdlib methods
    rc8_errors = [
        e
        for e in program.errors_had
        if e.loc and 360 <= e.loc.first_line <= 390
    ];
    # 3 errors: type[Archetype].reports, WalkerArchetype._instance,
    # object.call_params. The former 4th (executor.submit on a then-Unknown
    # ThreadPoolExecutor) went away after the relative .pyi re-export fix
    # loaded concurrent/futures stubs and typing/typing_extensions ParamSpec
    # parity let Callable[_P, _T] accept the lambda gradually.
    assert len(rc8_errors) == 3 , f"Expected 3 dynamic-attr errors, got {len(
        rc8_errors
    )}:\n" + "\n---\n".join(e.pretty_print() for e in rc8_errors);
}

"""Root Cause 9: Union with Any blocks attribute access.

When a type is a union containing Any (e.g., Any | EdgeArchetype), the checker
reports that Any doesn't have the attribute, even though Any should be compatible
with all attribute access by definition.

Mirrors: runtime.impl.jac line ~1400 (__jac__ on Any | EdgeArchetype | GenericEdge).
"""
test "root_cause_9_any_in_union" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # fail_ functions (lines 396-415) — Any in union blocks attr access
    rc9_errors = [
        e
        for e in program.errors_had
        if e.loc and 396 <= e.loc.first_line <= 415
    ];
    # CFG narrowing resolved 1 of 3 any-in-union errors.
    # 4 errors: 2 primary (E1099 attribute missing from Any) + 2 cascading
    # (E1002 unknown return, E1053 unknown->Sized) from improved Any resolution.
    assert len(rc9_errors) == 4 , f"Expected 4 any-in-union errors, got {len(
        rc9_errors
    )}:\n" + "\n---\n".join(e.pretty_print() for e in rc9_errors);
}

"""Root Cause 10: TypeVar in impl blocks.

A TypeVar defined at module level works in standalone def functions, but when
used in an impl block, the checker reports E1065: "Type variable T has no
meaning in this context."

Mirrors: runtime.jac line 76 (glob T = TypeVar('T')) and
runtime.impl.jac line 1506 (impl JacBasics.assign_all(target: list[T])).
"""
test "root_cause_10_typevar_in_impl" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_typevar_impl.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # The impl file should NOT trigger E1065 — module-level TypeVars are valid
    rc10_errors = [
        e
        for e in program.errors_had
        if e.code is not None and e.code.code == "E1065"
    ];
    # FIXED: Module-level TypeVars are now recognized in impl blocks.
    assert len(rc10_errors) == 0 , f"Expected 0 TypeVar-in-impl errors (fixed), got {len(
        rc10_errors
    )}:\n" + "\n---\n".join(e.pretty_print() for e in rc10_errors);
}

"""Baseline: TypeVar in standalone def should produce no E1065 errors."""
test "root_cause_10_typevar_in_def_ok" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # ok_typevar_in_def (lines 420-425) — should have no E1065 errors
    ok_errors = [
        e
        for e in program.errors_had
        if e.loc
        and 420 <= e.loc.first_line <= 425
        and e.code is not None
        and e.code.code == "E1065"
    ];
    assert len(ok_errors) == 0 , f"TypeVar in def should have 0 E1065 errors, got {len(
        ok_errors
    )}:\n" + "\n---\n".join(e.pretty_print() for e in ok_errors);
}

"""Total error count for root causes fixture."""
test "root_causes_total_error_count" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # RC9 now 4 (was 2 before Callable/Any resolution fix), RC5 dropped 2→0.
    # -1 from former 36: line 390 `executor.submit(lambda: None)` now succeeds
    # after typing/typing_extensions ParamSpec parity + ParamSpec.args/.kwargs
    # modelling: `Callable[_P, _T]` is now gradual, accepting the lambda. The
    # fixture comment predicted "E1032 if executor type is Unknown" when
    # `executor` was Unknown (stub unloadable pre-fix); that path is resolved
    # now, and ParamSpec is understood, so no error fires there. Total: 35.
    assert len(program.errors_had) == 35 , f"Expected 35 total errors, got {len(
        program.errors_had
    )}:\n" + "\n---\n".join(e.pretty_print() for e in program.errors_had);
}

"""MRO resolves correctly when base class imported through Python __init__.py re-export."""
test "mro_reexport_through_init" {
    # When a Jac class inherits from a class that's imported through a Python
    # __init__.py re-export, the base class should resolve correctly and the
    # MRO should be properly computed. Previously, the base class resolved to
    # UnknownType because get_type_of_module used wrong index into path_list
    # for relative imports (leading dots create extra segments).
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_mro_reexport.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 0 , f"MRO reexport should produce 0 errors, got {len(
        program.errors_had
    )}:\n" + "\n---\n".join(e.pretty_print() for e in program.errors_had);
}

test "scope_narrowing_isolation_between_impl_bodies" {
    # Regression: guard-pattern narrowings (e.g., `if ctx is not None { return; }`
    # promoting ctx→NoneType) leaked from one impl body into subsequent impl bodies
    # sharing the same variable name.
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_static_method_inherit.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 0 , f"Scope narrowing should not leak between impl bodies, got {len(
        program.errors_had
    )} errors:\n" + "\n---\n".join(e.pretty_print() for e in program.errors_had);
}

test "bare_generic_iteration_yields_any" {
    # Bare generic types like `list` (no type args) should be treated as
    # list[Any] per PEP 484, so iterating yields Any (not Unknown).
    # Only the typed list[int] assignment mismatch should error.
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_bare_generic_iteration.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 1 , f"Expected 1 error (int->str), got {len(
        program.errors_had
    )}:\n" + "\n---\n".join(e.pretty_print() for e in program.errors_had);
    assert_error_pretty_found(
        """
        b: str = t;   # <-- Error (int not assignable to str)
        ^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );

    # Bare generics should produce W1036 warnings nudging toward explicit type args
    bare_generic_warnings = [
        w
        for w in program.warnings_had
        if "W1036" in w.pretty_print()
    ];
    assert len(bare_generic_warnings) == 3 , f"Expected 3 W1036 warnings (list, dict, list), got {len(
        bare_generic_warnings
    )}:\n" + "\n---\n".join(w.pretty_print() for w in bare_generic_warnings);
}

"""Test callable() type narrowing - validates narrowing unions by callability."""
test "callable_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_callable_narrowing.jac"), options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 4 , f"Expected exactly 4 type errors, but got " + f"{len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);

    # E1: No callable guard — full union assigned to Callable
    assert_error_pretty_found(
        """
        fail: Callable[[int], str] = handler;  # <-- Error (union cannot assign to Callable)
    """,
        program.errors_had[0].pretty_print()
    );

    # E2: No callable guard — full union assigned to str
    assert_error_pretty_found(
        """
        fail: str = handler;  # <-- Error (union cannot assign to str)
    """,
        program.errors_had[1].pretty_print()
    );

    # E3: Wrong type in callable branch — str assigned but handler is Callable
    assert_error_pretty_found(
        """
        s: str = handler;  # <-- Error: handler is Callable here, not str
    """,
        program.errors_had[2].pretty_print()
    );

    # E4: Wrong type in else branch — Callable assigned but handler is str
    assert_error_pretty_found(
        """
        cb: Callable[[int], str] = handler;  # <-- Error: handler is str here
    """,
        program.errors_had[3].pretty_print()
    );
}

"""Test type narrowing through TypeAlias definitions - isinstance, callable, and None checks."""
test "type_alias_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_type_alias_narrowing.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 2 , f"Expected exactly 2 type errors, but got " + f"{len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);

    # E1: No isinstance guard — TypeAlias'd union assigned to component type
    assert_error_pretty_found(
        """
        f: Foo = val;  # Error: Foo | None cannot assign to Foo
    """,
        program.errors_had[0].pretty_print()
    );

    # E2: No callable guard — TypeAlias'd union assigned to Callable
    assert_error_pretty_found(
        """
        fail: Callable[[int], str] = handler;  # Error: union cannot assign to Callable
    """,
        program.errors_had[1].pretty_print()
    );
}

test "param_isinstance_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_param_isinstance_narrowing.jac"),
        options=NO_TC
    );
    TypeCheckPass(ir_in=mod, prog=program);

    # Only the unguarded access (test_no_guard) should produce errors.
    # The guarded cases should all pass thanks to isinstance narrowing.
    # Error 1: attribute "bark" not found on object
    # Error 2: cascade — return type Unknown vs expected str
    assert len(program.errors_had) == 2 , f"Expected exactly 2 type errors, but got " + f"{len(
        program.errors_had
    )}:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);

    assert_error_pretty_found(
        """
        return other.bark();  # <-- Error: object has no attribute "bark"
                     ^^^^
    """,
        program.errors_had[0].pretty_print()
    );
    assert_error_pretty_found(
        """
        return other.bark();  # <-- Error: object has no attribute "bark"
        ^^^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[1].pretty_print()
    );
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# JSX type safety tests (Steps 1-6)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test "jsx_step1_callable_annotation" {
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_step1_callable_annotation.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);

    e1053_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1053"
    ];
    assert len(e1053_errors) >= 1 , f"Expected E1053 for int->Callable mismatch, got {len(
        e1053_errors
    )} errors:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);
}

test "jsx_step2_handler_aliases" {
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_step2_handler_aliases.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);

    e1053_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1053"
    ];
    assert len(e1053_errors) >= 1 , f"Expected E1053 for bad_handler->MouseEventHandler mismatch, got {len(
        e1053_errors
    )} errors:\n" + "\n---\n".join(err.pretty_print() for err in program.errors_had);
}

test "jsx_step3_jsx_prop_check" {
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_step3_jsx_prop_check.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);

    e1100_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1100"
    ];
    assert len(e1100_errors) >= 1 , f"Expected E1100 for JSX prop type mismatch, got {len(
        e1100_errors
    )} E1100 errors. All errors:\n" + "\n---\n".join(
        f"{err.code.code if err.code else '?'}: {err.pretty_print()}"
        for err in program.errors_had
    );
}

test "jsx_step4_lambda_inference" {
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_step4_lambda_inference.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);

    e1032_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1032"
    ];
    assert len(e1032_errors) >= 1 , f"Expected E1032 for e.nonexistent on inferred MouseEvent, got {len(
        e1032_errors
    )} E1032 errors. All errors:\n" + "\n---\n".join(
        f"{err.code.code if err.code else '?'}: {err.pretty_print()}"
        for err in program.errors_had
    );
}

test "jsx_step5_intrinsic_props" {
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_step5_intrinsic_props.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);

    e1103_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1103"
    ];
    assert len(e1103_errors) >= 1 , f"Expected E1103 for intrinsic prop type mismatch, got {len(
        e1103_errors
    )} E1103 errors. All errors:\n" + "\n---\n".join(
        f"{err.code.code if err.code else '?'}: {err.pretty_print()}"
        for err in program.errors_had
    );
}

test "jsx_step6_spread_props" {
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_step6_spread_props.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);

    e1104_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1104"
    ];
    assert len(e1104_errors) >= 1 , f"Expected E1104 for non-dict spread, got {len(
        e1104_errors
    )} E1104 errors. All errors:\n" + "\n---\n".join(
        f"{err.code.code if err.code else '?'}: {err.pretty_print()}"
        for err in program.errors_had
    );
}

test "jsx_reserved_props_key_ref" {
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_reserved_props.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);

    e1101_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1101"
    ];
    # Only 'bogus' should trigger E1101. key and ref must be silently accepted.
    assert len(e1101_errors) == 1 , f"Expected exactly 1 E1101 (for 'bogus'), got {len(
        e1101_errors
    )}:\n" + "\n---\n".join(
        f"{err.code.code if err.code else '?'}: {err.pretty_print()}"
        for err in e1101_errors
    );
    # Verify it's specifically the 'bogus' prop.
    assert "bogus" in e1101_errors[0].pretty_print() , f"Expected E1101 for 'bogus', got: {e1101_errors[
        0
    ].pretty_print()}";
}

test "lambda_block_body_return_type_inference" {
    path = os.path.join(CHECKER_FIXTURES, "checker_lambda_block_body_return.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);

    all_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code.startswith("E")
    ];
    # Cases 1-5 should produce NO errors.
    # Case 6 should produce exactly 1 error (return type mismatch).
    assert len(all_errors) == 1 , f"Expected exactly 1 type error (Case 6: int vs str mismatch), got {len(
        all_errors
    )} errors:\n" + "\n---\n".join(
        f"{err.code.code if err.code else '?'}: {err.pretty_print()}"
        for err in all_errors
    );
}

test "walker_reports_attribute_resolves" {
    # Walker types should have .reports visible (inherited from builtin Walker).
    # Both typed (has reports: list[T]) and untyped walkers should pass.
    path = os.path.join(CHECKER_FIXTURES, "checker_walker_reports.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    TypeCheckPass(ir_in=mod, prog=program);
    assert len(program.errors_had) == 0 , f"Expected 0 errors for walker .reports access, got {len(
        program.errors_had
    )}:\n" + "\n---\n".join(e.pretty_print() for e in program.errors_had);
}
