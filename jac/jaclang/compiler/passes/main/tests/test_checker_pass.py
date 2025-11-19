"""Tests for typechecker pass (the pyright implementation)."""

from jaclang.utils.test import TestCase
from jaclang.compiler.passes.main import TypeCheckPass
from jaclang.compiler.program import JacProgram


class TypeCheckerPassTests(TestCase):
    """Test class obviously."""

    def _assert_error_pretty_found(self, needle: str, haystack: str) -> None:
        for line in [line.strip() for line in needle.splitlines() if line.strip()]:
            self.assertIn(
                line, haystack, f"Expected line '{line}' not found in:\n{haystack}"
            )

    def test_explicit_type_annotation_in_assignment(self) -> None:
        """Test explicit type annotation in assignment."""
        program = JacProgram()
        program.build(
            self.fixture_abs_path("type_annotation_assignment.jac"), type_check=True
        )
        self.assertEqual(len(program.errors_had), 2)
        self._assert_error_pretty_found(
            """
            glob should_fail1: int = "foo";
                 ^^^^^^^^^^^^^^^^^^^^^^^^^
        """,
            program.errors_had[0].pretty_print(),
        )

        self._assert_error_pretty_found(
            """
            glob should_fail2: str = 42;
                 ^^^^^^^^^^^^^^^^^^^^^^
        """,
            program.errors_had[1].pretty_print(),
        )

    def test_float_types(self) -> None:
        program = JacProgram()
        mod = program.compile(self.fixture_abs_path("checker_float.jac"))
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 1)
        self._assert_error_pretty_found(
            """
            f: float = pi; # <-- OK
            s: str = pi;   # <-- Error
            ^^^^^^^^^^^
        """,
            program.errors_had[0].pretty_print(),
        )

    def test_infer_type_of_assignment(self) -> None:
        program = JacProgram()
        mod = program.compile(self.fixture_abs_path("infer_type_assignment.jac"))
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 1)

        self._assert_error_pretty_found(
            """
          assigning_to_str: str = some_int_inferred;
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        """,
            program.errors_had[0].pretty_print(),
        )

    def test_member_access_type_resolve(self) -> None:
        program = JacProgram()
        mod = program.compile(self.fixture_abs_path("member_access_type_resolve.jac"))
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 1)
        self._assert_error_pretty_found(
            """
          s: str = f.bar.baz;
          ^^^^^^^^^^^^^^^^^^^
        """,
            program.errors_had[0].pretty_print(),
        )

    def test_imported_sym(self) -> None:
        program = JacProgram()
        mod = program.compile(self.fixture_abs_path("checker/import_sym_test.jac"))
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 1)
        self._assert_error_pretty_found(
            """
          a: str = foo();  # <-- Ok
          b: int = foo();  # <-- Error
          ^^^^^^^^^^^^^^
        """,
            program.errors_had[0].pretty_print(),
        )

    def test_member_access_type_infered(self) -> None:
        program = JacProgram()
        mod = program.compile(self.fixture_abs_path("member_access_type_inferred.jac"))
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 1)
        self._assert_error_pretty_found(
            """
          s = f.bar;
          ^^^^^^^^^
        """,
            program.errors_had[0].pretty_print(),
        )

    def test_inherited_symbol(self) -> None:
        program = JacProgram()
        mod = program.compile(self.fixture_abs_path("checker_sym_inherit.jac"))
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 2)
        self._assert_error_pretty_found(
            """
          c.val = 42;     # <-- Ok
          c.val = "str";  # <-- Error
          ^^^^^^^^^^^^^
        """,
            program.errors_had[0].pretty_print(),
        )
        self._assert_error_pretty_found(
            """
          l.name = "Simba";  # <-- Ok
          l.name = 42;       # <-- Error
          ^^^^^^^^^^^
        """,
            program.errors_had[1].pretty_print(),
        )

    def test_import_symbol_type_infer(self) -> None:
        program = JacProgram()
        mod = program.compile(self.fixture_abs_path("import_symbol_type_infer.jac"))
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 1)
        self._assert_error_pretty_found(
            """
            i: int = m.sys.prefix;
            ^^^^^^^^^^^^^^^^^^^^^
        """,
            program.errors_had[0].pretty_print(),
        )

    def test_from_import(self) -> None:
        path = self.fixture_abs_path("checker_importer.jac")

        program = JacProgram()
        mod = program.compile(path)
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 1)
        self._assert_error_pretty_found(
            """
          glob s: str = alias;
               ^^^^^^^^^^^^^^
        """,
            program.errors_had[0].pretty_print(),
        )

    def test_call_expr(self) -> None:
        path = self.fixture_abs_path("checker_expr_call.jac")
        program = JacProgram()
        mod = program.compile(path)
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 1)
        self._assert_error_pretty_found(
            """
          s: str = foo();
          ^^^^^^^^^^^^^^
        """,
            program.errors_had[0].pretty_print(),
        )

    def test_call_expr_magic(self) -> None:
        path = self.fixture_abs_path("checker_magic_call.jac")
        program = JacProgram()
        mod = program.compile(path)
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 1)
        self._assert_error_pretty_found(
            """
            b: Bar = fn()(); # <-- Ok
            f: Foo = fn()(); # <-- Error
            ^^^^^^^^^^^^^^^^
        """,
            program.errors_had[0].pretty_print(),
        )

    def test_arity(self) -> None:
        path = self.fixture_abs_path("checker_arity.jac")
        program = JacProgram()
        mod = program.compile(path)
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 3)
        self._assert_error_pretty_found(
            """
            f.first_is_self(f); # <-- Error
                            ^
        """,
            program.errors_had[0].pretty_print(),
        )
        self._assert_error_pretty_found(
            """
            f.with_default_args(1, 2, 3); # <-- Error
                                      ^
        """,
            program.errors_had[1].pretty_print(),
        )
        self._assert_error_pretty_found(
            """
            f.with_default_args();        # <-- Error
            ^^^^^^^^^^^^^^^^^^^^^
        """,
            program.errors_had[2].pretty_print(),
        )

    def test_param_types(self) -> None:
        path = self.fixture_abs_path("checker_param_types.jac")
        program = JacProgram()
        mod = program.compile(path)
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 1)
        self._assert_error_pretty_found(
            """
            foo(A()); # <-- Ok
            foo(B()); # <-- Error
                ^^^
        """,
            program.errors_had[0].pretty_print(),
        )

    def test_param_arg_match(self) -> None:
        program = JacProgram()
        path = self.fixture_abs_path("checker_arg_param_match.jac")
        mod = program.compile(path)
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 13)

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
                     foo(1, 2, 3, d=4, e=5, g=7, h=8); # missing argument 'f'
                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
            """,
            """
            Positional only parameter 'b' cannot be matched with a named argument
                     foo(1, 2, 3, d=4, e=5, g=7, h=8); # missing argument 'f'
                     foo(1, b=2, c=3, d=4, e=5, f=6); # b is positional only
                            ^^^
            """,
            """
            Too many positional arguments
                     bar(1, 2, 3, 4, 5, f=6);
                     bar(1, 2, 3, 4, 5, 6, 7, 8, 9); # too many args
                                           ^
            """,
            """
            Too many positional arguments
                     bar(1, 2, 3, 4, 5, f=6);
                     bar(1, 2, 3, 4, 5, 6, 7, 8, 9); # too many args
                                              ^
            """,
            """
            Too many positional arguments
                     bar(1, 2, 3, 4, 5, f=6);
                     bar(1, 2, 3, 4, 5, 6, 7, 8, 9); # too many args
                                                 ^
            """,
            """
            Parameter 'c' already matched
                     bar(1, 2, 3, 4, 5, f=6);
                     bar(1, 2, 3, 4, 5, 6, 7, 8, 9); # too many args
                     bar(1, 2, 3, 4, 5, 6, c=3); # already matched
                                           ^^^
            """,
            """
            Named argument 'h' does not match any parameter
                     bar(1, 2, 3, 4, 5, 6, 7, 8, 9); # too many args
                     bar(1, 2, 3, 4, 5, 6, c=3); # already matched
                     bar(1, 2, 3, 4, 5, 6, h=1); # h is not matched
                                           ^^^
            """,
            """
            Too many positional arguments
                     baz(a=1, b=2);
                     baz(1, b=2); # a can be both positional and keyword
                     baz(1, 2);  # 'b' can only be keyword arg
                            ^
            """,
            """
            Not all required parameters were provided in the function call: 'b'
                     baz(a=1, b=2);
                     baz(1, b=2); # a can be both positional and keyword
                     baz(1, 2);  # 'b' can only be keyword arg
                     ^^^^^^^^^
            """,
        ]

        for i, expected in enumerate(expected_errors):
            self._assert_error_pretty_found(
                expected, program.errors_had[i].pretty_print()
            )

    def test_class_construct(self) -> None:
        program = JacProgram()
        path = self.fixture_abs_path("checker_class_construct.jac")
        mod = program.compile(path)
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 3)

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
            self._assert_error_pretty_found(
                expected, program.errors_had[i].pretty_print()
            )

    def test_self_type_inference(self) -> None:
        path = self.fixture_abs_path("checker_self_type.jac")
        program = JacProgram()
        mod = program.compile(path)
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 1)
        self._assert_error_pretty_found(
            """
          x: str = self.i; # <-- Error
          ^^^^^^^^^^^^^^^
        """,
            program.errors_had[0].pretty_print(),
        )

    def test_binary_op(self) -> None:
        program = JacProgram()
        mod = program.compile(self.fixture_abs_path("checker_binary_op.jac"))
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 2)
        self._assert_error_pretty_found(
            """
            r2: A = a + a;  # <-- Error
            ^^^^^^^^^^^^^
        """,
            program.errors_had[0].pretty_print(),
        )
        self._assert_error_pretty_found(
            """
            r4: str = (a+a) * B(); # <-- Error
            ^^^^^^^^^^^^^^^^^^^^^
        """,
            program.errors_had[1].pretty_print(),
        )

    def test_checker_call_expr_class(self) -> None:
        path = self.fixture_abs_path("checker_call_expr_class.jac")
        program = JacProgram()
        mod = program.compile(path)
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 1)
        self._assert_error_pretty_found(
            """
            inst.i = 'str'; # <-- Error
            ^^^^^^^^^^^^^^
        """,
            program.errors_had[0].pretty_print(),
        )

    def test_checker_mod_path(self) -> None:
        path = self.fixture_abs_path("checker_mod_path.jac")
        program = JacProgram()
        mod = program.compile(path)
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 1)
        self._assert_error_pretty_found(
            """
            a:int = uni.Module; # <-- Error
            ^^^^^^^^^^^^^^
        """,
            program.errors_had[0].pretty_print(),
        )

    def test_checker_cat_is_animal(self) -> None:
        path = self.fixture_abs_path("checker_cat_is_animal.jac")
        program = JacProgram()
        mod = program.compile(path)
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 1)
        self._assert_error_pretty_found(
            """
            animal_func(cat);        # <-- Ok
            animal_func(lion);       # <-- Ok
            animal_func(not_animal); # <-- Error
                        ^^^^^^^^^^
        """,
            program.errors_had[0].pretty_print(),
        )

    def test_checker_member_access(self) -> None:
        path = self.fixture_abs_path("symtab_build.jac")
        program = JacProgram()
        mod = program.compile(path)
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(
            len(mod.sym_tab.names_in_scope.values()),
            2,
        )
        mod_scope_symbols = ["Symbol(alice", "Symbol(Person"]
        for sym in mod_scope_symbols:
            self.assertIn(sym, str(mod.sym_tab.names_in_scope.values()))
        self.assertEqual(
            len(mod.sym_tab.kid_scope[0].names_in_scope.values()),
            5,
        )
        kid_scope_symbols = [
            "Symbol(age",
            "Symbol(greet",
            "Symbol(name,",
            "Symbol(create_person",
            "Symbol(class_info",
        ]
        for sym in kid_scope_symbols:
            self.assertIn(sym, str(mod.sym_tab.kid_scope[0].names_in_scope.values()))
        age_sym = mod.sym_tab.kid_scope[0].lookup("age")
        assert age_sym is not None
        self.assertIn("(NAME, age, 23:11 - 23:14)", str(age_sym.uses))
        self.assertEqual(len(program.errors_had), 1)
        self._assert_error_pretty_found(
            """
            alice.age = '909'; # <-- Error
            ^^^^^^^^^^^^^^^^^^
        """,
            program.errors_had[0].pretty_print(),
        )

    def test_checker_import_missing_module(self) -> None:
        path = self.fixture_abs_path("checker_import_missing_module.jac")
        program = JacProgram()
        mod = program.compile(path)
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 0)

    def test_cyclic_symbol(self) -> None:
        path = self.fixture_abs_path("checker_cyclic_symbol.jac")
        program = JacProgram()
        mod = program.compile(path)
        # This will result in a stack overflow if not handled properly.
        # So the fact that it has 0 errors means it passed.
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 0)

    def test_get_type_of_iife_expression(self) -> None:
        path = self.fixture_abs_path("checker_iife_expression.jac")
        program = JacProgram()
        mod = program.compile(path)
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 0)

    def test_generics(self) -> None:
        program = JacProgram()
        path = self.fixture_abs_path("checker_generics.jac")
        mod = program.compile(path)
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 9)

        expected_errors = [
            """
            Cannot assign <class Foo> to <class str>
                for it in tl {
                    tifoo: Foo = it;
                    tistr: str = it; # <-- Error
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
                    tifoo: Foo = it; # <-- Ok
                    tistr: str = it; # <-- Error
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
                i: int = d[1]; # <-- Error
                ^^^^^^^^^^^^^^

                ht = HashTable[int, str]();
            """,
            """
            Cannot assign <class str> to parameter 'key' of type <class int>
                ht = HashTable[int, str]();
                ht.insert(1, "one");
                ht.insert("one", "one");  # <-- Error
                        ^^^^^
                ht.insert(1, 1);          # <-- Error

            """,
            """
            Cannot assign <class int> to parameter 'value' of type <class str>
                ht.insert(1, "one");
                ht.insert("one", "one");  # <-- Error
                ht.insert(1, 1);          # <-- Error
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
            self._assert_error_pretty_found(
                expected, program.errors_had[i].pretty_print()
            )

    def test_return_type(self) -> None:
        program = JacProgram()
        path = self.fixture_abs_path("checker_return_type.jac")
        mod = program.compile(path)
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 4)

        expected_errors = [
            """
            Cannot return <class int>, expected <class NoneType>
            def foo() {
                return 1;    # <-- Error
                ^^^^^^^^^
                return;      # <-- Ok
                return "";   # <-- Error
            """,
            """
            Cannot return <class str>, expected <class NoneType>
                return 1;    # <-- Error
                return;      # <-- Ok
                return "";   # <-- Error
                ^^^^^^^^^^
                return None; # <-- Ok
            }
            """,
            """
            Cannot return <class str>, expected <class int>

            def bar() -> int {
                return "";  # <-- Error
                ^^^^^^^^^^
                return 1;   # <-- Ok
                return 1.1; # <-- Error
                """,
            """
            Cannot return <class float>, expected <class int>
                return "";  # <-- Error
                return 1;   # <-- Ok
                return 1.1; # <-- Error
                ^^^^^^^^^^^
            }
            """,
        ]

        for i, expected in enumerate(expected_errors):
            self._assert_error_pretty_found(
                expected, program.errors_had[i].pretty_print()
            )

    def test_connect_typed(self) -> None:
        program = JacProgram()
        path = self.fixture_abs_path("checker_connect_typed.jac")
        mod = program.compile(path)
        TypeCheckPass(ir_in=mod, prog=program)
        # Expect three errors: wrong edge type usage and node class operands
        self.assertEqual(len(program.errors_had), 3)

    def test_connect_filter(self) -> None:
        program = JacProgram()
        path = self.fixture_abs_path("checker_connect_filter.jac")
        mod = program.compile(path)
        TypeCheckPass(ir_in=mod, prog=program)
        self.assertEqual(len(program.errors_had), 7)

        expected_errors = [
            """
            Connection type must be an edge instance
                a_inst +>:edge_inst:+> b_inst; # Ok
                a_inst +>:NodeA:+> b_inst;     # Error
                          ^^^^^
            """,
            """
            Connection left operand must be a node instance
                a_inst +>:NodeA:+> b_inst;     # Error
                NodeA +>:MyEdge:+> b_inst;     # Error
                ^^^^^
            """,
            """
            Connection right operand must be a node instance
                NodeA +>:MyEdge:+> b_inst;     # Error
                a_inst +>:MyEdge:+> NodeB;     # Error
                                    ^^^^^
            """,
            """
            Edge type "<class MyEdge>" has no member named "not_mem"
                # Assign compr in edges
                a_inst +>:MyEdge:id=1, not_mem="some":+> b_inst; # Error
                                       ^^^^^^^
            """,
            """
            Member "not_exist not found on type <class Book>"
                lst(=title="Parry Potter", author="K.J. Bowling", year=1997); # Ok
                lst(=not_exist="some");  # Error
                     ^^^^^^^^^
            """,
            """
            Type "<class str> is not assignable to type <class int>"
                lst(=not_exist="some");  # Error
                lst(=year="Type Error"); # Error
                          ^^^^^^^^^^^^
            """,
            """
            Member "not_exists not found on type <class MyEdge>"
                [->:MyEdge:id == 1:->]; # Ok
                [->:MyEdge:not_exists >= 1:->]; # Error
                           ^^^^^^^^^^
            """,
        ]

        for i, expected in enumerate(expected_errors):
            self._assert_error_pretty_found(
                expected, program.errors_had[i].pretty_print()
            )
