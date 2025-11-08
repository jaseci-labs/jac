# Jac Grammar Documentation Analysis

## Section 1: Base Module structure

*   **Grammar Rules from `jac.lark`:**
    ```lark
    start: module
    module: (toplevel_stmt (tl_stmt_with_doc | toplevel_stmt)*)?
           | STRING        (tl_stmt_with_doc | toplevel_stmt)*
    tl_stmt_with_doc: STRING toplevel_stmt
    toplevel_stmt: import_stmt
           | archetype
           | impl_def
           | ability
           | global_var
           | free_code
           | py_code_block
           | test
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/base_module_structure.md`
*   **Findings:**
    1.  **Inconsistency in `with entry` requirement:**
        *   **Documentation states:** "Moreover, Jac requires that any standalone, module-level code be encapsulated within a `with entry {}` block."
        *   **Grammar allows:** `toplevel_stmt` (which includes `global_var`, `archetype`, `ability`, `test`, `impl_def`, `import_stmt`, `py_code_block`) to appear directly within a `module` without being wrapped in `free_code` (which is the `with entry {}` construct). The `free_code` rule is just one of the options for a `toplevel_stmt`.
        *   **Issue:** The documentation's statement about `with entry {}` being required for *any* standalone module-level code is an oversimplification and conflicts with the broader capabilities defined in the grammar for `module` and `toplevel_stmt`.

---

## Section 2: Import/Include Statements

*   **Grammar Rules from `jac.lark`:**
    ```lark
    import_stmt: KW_IMPORT KW_FROM from_path LBRACE import_items RBRACE
               | KW_IMPORT import_path (COMMA import_path)* SEMI
               | KW_INCLUDE import_path SEMI

    from_path: (DOT | ELLIPSIS)* import_path
             | (DOT | ELLIPSIS)+

    import_path: dotted_name (KW_AS NAME)?
    import_items: (import_item COMMA)* import_item COMMA?
    import_item: named_ref (KW_AS NAME)?
    dotted_name: named_ref (DOT named_ref)*
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/import_include_statements.md`
*   **Findings:**
    1.  **`from_path` details not fully covered:**
        *   **Grammar allows:** `from_path` to be `(DOT | ELLIPSIS)* import_path` or `(DOT | ELLIPSIS)+`.
        *   **Documentation mentions:** Relative paths but doesn't explicitly detail the syntax using `.` or `ELLIPSIS` (`...`) in the `from_path` for selective imports.
        *   **Issue:** The documentation could be more explicit about using `.` and `...` in `from_path`.
    2.  **`import_items` trailing comma:**
        *   **Grammar allows:** A trailing comma in `import_items`.
        *   **Documentation example:** Does not show an example with a trailing comma.
        *   **Issue:** Minor omission; an example or note about the optional trailing comma would be beneficial.
    3.  **Multiple `import_path` in standard import:**
        *   **Grammar allows:** Importing multiple modules in a single standard `import` statement (e.g., `import mod1, mod2;`).
        *   **Documentation examples:** Show single module imports per statement.
        *   **Issue:** Documentation does not cover importing multiple modules in one standard `import` statement.

---

## Section 3: Archetypes

*   **Grammar Rules from `jac.lark`:**
    ```lark
    archetype: decorators? KW_ASYNC? archetype_decl
             | enum

    archetype_decl: arch_type access_tag? NAME inherited_archs? (member_block | SEMI)
    decorators: (DECOR_OP atomic_chain)+
    access_tag: COLON ( KW_PROT | KW_PUB | KW_PRIV )
    inherited_archs: LPAREN (atomic_chain COMMA)* atomic_chain RPAREN

    arch_type: KW_WALKER
              | KW_OBJECT
              | KW_EDGE
              | KW_NODE
              | KW_CLASS
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/archetypes.md`
*   **Findings:**
    1.  **Omission of Empty/Forward Declaration:**
        *   **Grammar allows:** `archetype_decl` to end with `SEMI` (e.g., `node MyNode;`).
        *   **Documentation:** Does not mention or provide examples for this.
        *   **Issue:** Capability to define archetypes with empty bodies using a semicolon is not documented.
    2.  **Omission of `KW_ASYNC` for Archetypes:**
        *   **Grammar allows:** `archetype` to be `async` (e.g., `async walker MyAsyncWalker {...}`).
        *   **Documentation:** Does not mention `async` archetypes.
        *   **Issue:** The `async` keyword applicability to the archetype declaration itself is not documented.
    3.  **`enum` as an `archetype` form:**
        *   **Grammar states:** `archetype: ... | enum`.
        *   **Documentation:** `archetypes.md` does not mention that `enum` is a type of `archetype`.
        *   **Issue:** Lack of mention or cross-reference to `enum` as a form of `archetype`.

---

## Section 4: Archetype bodies

*   **Grammar Rules from `jac.lark`:**
    ```lark
    member_block: LBRACE member_stmt* RBRACE
    member_stmt: STRING? (py_code_block | ability | archetype | impl_def | has_stmt | free_code)
    has_stmt: KW_STATIC? (KW_LET | KW_HAS) access_tag? has_assign_list SEMI
    has_assign_list: (has_assign_list COMMA)? typed_has_clause
    typed_has_clause: named_ref type_tag (EQ expression | KW_BY KW_POST_INIT)?
    type_tag: COLON expression
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/archetype_bodies.md`
*   **Findings:**
    1.  **`member_stmt` options not fully detailed/exemplified:**
        *   **Grammar for `member_stmt`:** `STRING? (py_code_block | ability | archetype | impl_def | has_stmt | free_code)`
        *   **Documentation (`archetype_bodies.md`):**
            *   Covers `has_stmt` and `ability` well.
            *   Shows docstrings (`STRING?`).
            *   Mentions `impl` blocks but not explicitly that `impl_def` can be nested inside an archetype.
            *   Does not explicitly cover nesting `archetype`, `py_code_block`, or `free_code` within an archetype.
        *   **Issue:** Documentation should list all `member_stmt` types and provide examples/references for nesting `archetype`, `py_code_block`, `impl_def`, and `free_code`.
    2.  **`has_stmt` using `KW_LET`:**
        *   **Grammar for `has_stmt`:** `KW_STATIC? (KW_LET | KW_HAS) ...`.
        *   **Documentation:** Consistently uses `has`. `KW_LET` alternative is not mentioned.
        *   **Issue:** Use of `let` for member declarations is not documented in this file.
    3.  **`typed_has_clause` with `KW_BY KW_POST_INIT`:**
        *   **Grammar:** `... (EQ expression | KW_BY KW_POST_INIT)?`
        *   **Documentation:** Covered in `archetypes.md` (`has id: str by postinit;`).
        *   **Status:** Covered in a related file.
    4.  **`has_assign_list` with multiple assignments:**
        *   **Grammar for `has_assign_list`:** `(has_assign_list COMMA)? typed_has_clause`, implying multiple comma-separated declarations.
        *   **Documentation:** Examples show one variable per `has` statement.
        *   **Issue:** Declaring multiple variables in a single `has` statement (e.g., `has name: str, age: int;`) is not documented.

---

## Section 5: Enumerations

*   **Grammar Rules from `jac.lark`:**
    ```lark
    enum: decorators? enum_decl
    enum_decl: KW_ENUM access_tag? NAME inherited_archs? (enum_block | SEMI)
    enum_block: LBRACE assignment_list COMMA? (py_code_block | free_code)* RBRACE
    // assignment_list: (assignment_list COMMA)? (assignment | named_ref)
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/enumerations.md`
*   **Findings:**
    1.  **`inherited_archs` in `enum_decl`:**
        *   **Grammar allows:** Enums to use `inherited_archs` (e.g., `enum MyEnum(Parent) {...}`).
        *   **Documentation:** Does not mention or exemplify enum inheritance.
        *   **Issue:** Enum inheritance is not documented.
    2.  **Empty Enum Declaration with `SEMI`:**
        *   **Grammar allows:** `enum MyEnum;`.
        *   **Documentation:** Shows `enum Day;` with an `impl Day {}` block.
        *   **Status:** Covered in the context of `impl` blocks.
    3.  **`py_code_block` and `free_code` in `enum_block`:**
        *   **Grammar allows:** `py_code_block` (`::py::...::py::`) or `free_code` (`with entry {}`) within an `enum {}` body.
        *   **Documentation:** Examples focus on assignments in `enum {}` and methods in `impl {}`.
        *   **Issue:** Direct inclusion of `py_code_block` or `free_code` in `enum {}` is not documented.
    4.  **Nature of `assignment_list` in Enums:**
        *   **Grammar uses a general `assignment_list` rule.**
        *   **Documentation shows:** Typical enum assignments (`NAME = value` or `NAME`).
        *   **Question/Potential Minor Issue:** The documentation doesn't clarify if the full range of complex `assignment` syntax is applicable or idiomatic within enums, or if it's restricted to simpler forms.
        *   **Status:** Core enum assignment is covered; scope of complex assignments within enums is not detailed.

---

## Section 6: Functions and Abilities

*   **Grammar Rules from `jac.lark`:**
    ```lark
    ability: decorators? KW_ASYNC? (ability_decl | function_decl)

    function_decl: KW_OVERRIDE? KW_STATIC? KW_DEF access_tag? named_ref func_decl? (block_tail | KW_ABSTRACT? SEMI)
    ability_decl: KW_OVERRIDE? KW_STATIC? KW_CAN access_tag? named_ref event_clause (block_tail | KW_ABSTRACT? SEMI)

    block_tail: code_block | KW_BY atomic_call SEMI

    event_clause: KW_WITH expression? (KW_EXIT | KW_ENTRY) (RETURN_HINT expression)?

    func_decl: (LPAREN func_decl_params? RPAREN) (RETURN_HINT expression)?
             | (RETURN_HINT expression)

    func_decl_params: (param_var COMMA)* param_var COMMA?
    param_var: (STAR_POW | STAR_MUL)? named_ref type_tag (EQ expression)?
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/functions_and_abilities.md`
*   **Findings:**
    1.  **`function_decl` without parentheses:**
        *   **Grammar for `func_decl` allows:** `(RETURN_HINT expression)` directly (e.g., `def my_func -> int { ... }`).
        *   **Documentation:** Examples use parentheses. The variant without `()` for no-parameter functions is not shown.
        *   **Issue:** Undocumented shorthand for no-parameter functions.
    2.  **`block_tail` with `KW_BY atomic_call SEMI` (Delegation):**
        *   **Grammar allows:** Implementation delegation (e.g., `def my_func by other_func;`).
        *   **Documentation:** Does not cover the `by` delegation syntax.
        *   **Issue:** Delegation of implementation is not documented.
    3.  **`event_clause` with return type:**
        *   **Grammar for `event_clause` allows:** `(RETURN_HINT expression)?` (e.g., `can my_ability with node entry -> bool { ... }`).
        *   **Documentation:** Does not show abilities with event clauses having explicit return types.
        *   **Issue:** Return types on event-claused abilities are not documented.
    4.  **`KW_OVERRIDE` for functions/abilities:**
        *   **Grammar allows:** `KW_OVERRIDE?`.
        *   **Documentation:** `override` keyword is not mentioned or exemplified.
        *   **Issue:** `override` keyword is not documented.
    5.  **`KW_ABSTRACT` with `SEMI`:**
        *   **Grammar allows:** `KW_ABSTRACT? SEMI`.
        *   **Documentation:** Shows `def area() -> float abs;`.
        *   **Status:** Covered.
    6.  **`param_var` (parameter definitions):**
        *   **Grammar covers:** `*args`, `**kwargs`, typed params, default values.
        *   **Documentation:** Shows these patterns.
        *   **Status:** Covered.
    7.  **`decorators` on `ability` / `function_decl`:**
        *   **Grammar allows:** Decorators on abilities and functions.
        *   **Documentation:** No specific example in `functions_and_abilities.md`, though decorators are a general feature.
        *   **Issue:** Minor; a direct example would be beneficial for completeness.
    8.  **`KW_STATIC` for abilities:**
        *   **Grammar allows:** `KW_STATIC? KW_CAN ...` (static abilities).
        *   **Documentation:** Examples show `static def`, but not `static can`.
        *   **Issue:** Static abilities are not explicitly documented.

---

## Section 7: Implementations

*   **Grammar Rules from `jac.lark`:**
    ```lark
    impl_def: decorators? KW_IMPL dotted_name impl_spec? impl_tail
    impl_spec: inherited_archs | func_decl | event_clause
    impl_tail: enum_block | block_tail
    // block_tail: code_block | KW_BY atomic_call SEMI
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/implementations.md`
*   **Findings:**
    1.  **Modern `impl` Syntax vs. Grammar `impl_def`:**
        *   **Documentation shows:** `impl foo() -> str { ... }`, `impl vehicle { ... }`, `impl Size { ... }`.
        *   **Grammar:** `KW_IMPL dotted_name impl_spec? impl_tail`.
        *   **Status:** Documented "Modern `impl` Syntax" aligns well with the grammar.

    2.  **Legacy Colon Syntax:**
        *   **Documentation covers:** `:can:foo()`, `:obj:vehicle`, `:enum:Size`, `:test:check_vehicle`.
        *   **Grammar `jac.lark`:** Does not define this colon-prefixed syntax for implementations directly in `impl_def`.
        *   **Issue:** Significant inconsistency. The legacy colon syntax is not in the provided `impl_def` grammar.

    3.  **`impl_spec` with `inherited_archs` or `event_clause`:**
        *   **Grammar for `impl_spec`:** `inherited_archs | func_decl | event_clause`.
        *   **Documentation covers:** `impl_spec` as `func_decl` (e.g., `impl foo() -> str { ... }`).
        *   **Documentation does not cover:** `impl_spec` as `inherited_archs` (e.g., `impl MyType(Parent) { ... }`) or `event_clause` (e.g., `impl MyAbility with node entry { ... }`).
        *   **Issue:** Using `inherited_archs` or `event_clause` in `impl_spec` is not documented.

    4.  **`decorators` on `impl_def`:**
        *   **Grammar allows:** `decorators? KW_IMPL ...`.
        *   **Documentation:** No examples show decorators on `impl` blocks.
        *   **Issue:** Decorating `impl` blocks is not documented.

    5.  **`impl_tail` with `KW_BY atomic_call SEMI` (Delegation):**
        *   **Grammar allows:** `impl_tail` to be `block_tail`, which can delegate (e.g., `impl foo() -> str by other_call;`).
        *   **Documentation:** Does not cover `by` delegation for implementations.
        *   **Issue:** Delegating an entire `impl` block is not documented.

    6.  **Implementing `test`:**
        *   **Documentation shows:** `test check_vehicle;` and `:test:check_vehicle { ... }` (legacy).
        *   **Grammar `test` rule:** `KW_TEST NAME? code_block` (defines test with body).
        *   **Grammar `impl_def` suggests modern form:** `impl check_vehicle { ... }`.
        *   **Issue:** The "Modern `impl` Syntax" for tests (`KW_IMPL test_name`) is not explicitly shown. Clarity is needed on how `test Name;` declaration and `impl Name { ... }` interact versus the direct `test Name { ... }` grammar.

---

## Section 8: Global variables

*   **Grammar Rules from `jac.lark`:**
    ```lark
    global_var: (KW_LET | KW_GLOBAL) access_tag? assignment_list SEMI
    assignment_list: (assignment_list COMMA)? (assignment | named_ref)
    // access_tag: COLON ( KW_PROT | KW_PUB | KW_PRIV )
    // assignment: ... (complex rule)
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/global_variables.md`
*   **Findings:**
    1.  **Keywords `let` and `glob`:**
        *   **Grammar:** `KW_LET`, `KW_GLOBAL`.
        *   **Documentation:** Explains `let` and `glob` with examples.
        *   **Status:** Covered.

    2.  **`access_tag`:**
        *   **Grammar:** `access_tag?` (optional).
        *   **Documentation:** Explains `:priv`, `:pub`, `:protect` and default visibility. Examples provided.
        *   **Status:** Covered.

    3.  **`assignment_list` for multiple declarations:**
        *   **Grammar allows:** Multiple comma-separated assignments (e.g., `glob a = 1, b = 2;`).
        *   **Documentation:** Examples show single declarations per statement.
        *   **Issue:** Declaring multiple global variables in a single statement is not documented.

    4.  **`assignment_list` with `named_ref` only (declaration without assignment):**
        *   **Grammar allows:** Declaration without explicit assignment (e.g., `glob my_var;`).
        *   **Documentation:** Examples show variables with initial assignments.
        *   **Issue:** Declaration of global variables without an initial assignment is not documented.

    5.  **Full complexity of `assignment` rule in `global_var`:**
        *   **Grammar uses a general `assignment` rule.**
        *   **Documentation shows:** Simple `name = expression` form.
        *   **Question/Potential Minor Issue:** Applicability of more complex assignment forms (e.g., with explicit type tags, augmented assignments) within `global_var` is not explored.
        *   **Status:** Basic global variable assignment covered; complex forms not detailed.

---

## Section 9: Free code

*   **Grammar Rules from `jac.lark`:**
    ```lark
    free_code: KW_WITH KW_ENTRY (COLON NAME)? code_block
    // code_block: LBRACE statement* RBRACE
    // statement: ... (very broad rule)
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/free_code.md`
*   **Findings:**
    1.  **Basic Syntax `with entry { ... }`:**
        *   **Grammar:** `KW_WITH KW_ENTRY code_block`.
        *   **Documentation:** Shows `with entry { ... }`.
        *   **Status:** Covered.

    2.  **Named Entry Points `with entry:name { ... }`:**
        *   **Grammar:** `KW_WITH KW_ENTRY COLON NAME code_block`.
        *   **Documentation:** Shows `with entry:name { ... }`.
        *   **Status:** Covered.

    3.  **Content of `code_block` (Statements within `free_code`):**
        *   **Grammar:** `code_block` can contain any `statement*`.
        *   **Documentation:** Focuses on executable statements (assignments, function calls). It does not explicitly discuss or exemplify the use of declarative statements (like defining archetypes, abilities, or imports) *inside* a `with entry` block.
        *   **Issue/Clarification Needed:** The documentation should clarify the intended scope and limitations of statements within `free_code`. While grammatically flexible, practical or idiomatic usage might be more restricted than the grammar implies. For example, is defining an archetype inside `with entry` allowed and meaningful?

---

## Section 10: Inline python

*   **Grammar Rules from `jac.lark`:**
    ```lark
    py_code_block: PYNLINE
    PYNLINE: /::py::(.|\n|\r)*?::py::/ // Terminal
    // py_code_block is a toplevel_stmt, member_stmt, and statement
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/inline_python.md`
*   **Findings:**
    1.  **Syntax `::py:: ... ::py::`:**
        *   **Grammar:** Defines the `PYNLINE` terminal.
        *   **Documentation:** Correctly shows `::py:: ... ::py::`.
        *   **Status:** Covered.

    2.  **Placement of `py_code_block`:**
        *   **Grammar:** Allows `py_code_block` at module level, within archetypes, and within general code blocks (e.g., function bodies).
        *   **Documentation:** Primarily shows module-level `py_code_block`. It does not explicitly exemplify or discuss its use *inside* archetypes or other Jac statement blocks (like function bodies).
        *   **Issue:** The documentation could be more comprehensive by illustrating the use of `py_code_block` in different scopes permitted by the grammar (e.g., inside a `can` block or an `obj` block).

---

## Section 11: Tests

*   **Grammar Rules from `jac.lark`:**
    ```lark
    test: KW_TEST NAME? code_block
    // NAME is an identifier: /[a-zA-Z_][a-zA-Z0-9_]*/
    // code_block: LBRACE statement* RBRACE
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/tests.md`
*   **Findings:**
    1.  **Anonymous Test `test { ... }`:**
        *   **Grammar:** `KW_TEST code_block` (NAME is absent).
        *   **Documentation:** Shows `test { ... }`.
        *   **Status:** Covered.

    2.  **Named Test Syntax (Identifier vs. String Literal):**
        *   **Grammar:** `KW_TEST NAME code_block` (where `NAME` is an identifier).
        *   **Documentation:** Primarily shows test names as string literals (e.g., `test "descriptive test name" { ... }`).
        *   **Inconsistency/Clarification Needed:** The grammar specifies `NAME` (identifier) for test names, but documentation uses string literals. This needs clarification. If string literals are just descriptions and the actual name is different or optional, this should be explained. The `implementations.md` implies modern form:** `impl check_vehicle { ... }`.
        *   **Issue:** The "Modern `impl` Syntax" for tests (`KW_IMPL test_name`) is not explicitly shown. Clarity is needed on how `test Name;` declaration and `impl Name { ... }` interact versus the direct `test Name { ... }` grammar.

    3.  **Content of `code_block` within `test`:**
        *   **Grammar:** Allows any valid `statement*`.
        *   **Documentation:** Examples show a wide variety of Jac statements, including assignments, calls, assertions, loops, try/except, etc.
        *   **Status:** Well covered through examples.

    4.  **Separation of Test Declaration and Implementation:**
        *   **Grammar `test` rule:** Defines a test with its body directly.
        *   **Documentation (`tests.md`):** Shows tests defined with their bodies.
        *   **Documentation (`implementations.md`):** Discusses declaring tests (e.g., `test my_test_name;`) and implementing them separately.
        *   **Issue (Cross-file Context):** `tests.md` itself does not mention or cross-reference the declaration/implementation separation for tests. A brief note could improve clarity on how the `test Name;` (declaration) relates to `test Name {body}` (direct definition) or `impl Name {body}` (implementation).

---

## Section 12: Codeblocks and Statements

*   **Grammar Rules from `jac.lark`:**
    ```lark
    code_block: LBRACE statement* RBRACE

    statement: import_stmt
           | ability
           | has_stmt
           | archetype
           | impl_def
           | if_stmt
           | while_stmt
           | for_stmt
           | try_stmt
           | match_stmt
           | with_stmt
           | global_ref SEMI
           | nonlocal_ref SEMI
           | typed_ctx_block
           | return_stmt SEMI
           | (yield_expr | KW_YIELD) SEMI
           | raise_stmt SEMI
           | assert_stmt SEMI
           | check_stmt SEMI
           | assignment SEMI
           | delete_stmt SEMI
           | report_stmt SEMI
           | expression SEMI
           | ctrl_stmt SEMI
           | py_code_block
           | spatial_stmt
           | SEMI
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/codeblocks_and_statements.md`
*   **Findings:**
    1.  **`code_block` Structure:**
        *   **Grammar:** `LBRACE statement* RBRACE`.
        *   **Documentation:** Shows `{ ... }` structure.
        *   **Status:** Covered.

    2.  **List of `statement` types (Overview):**
        *   **Grammar:** Provides an exhaustive list of specific statement productions.
        *   **Documentation:** Categorizes statements broadly (Declaration, Expression, Control Flow, Object-Spatial) but does not enumerate all specific types from the grammar in this overview file.
        *   **Issue/Nature of Document:** This overview could be more comprehensive by listing more specific statement types (e.g., `import_stmt`, `archetype` (as a statement), `global_ref`, `nonlocal_ref`, `typed_ctx_block`, `delete_stmt`, `report_stmt`, `ctrl_stmt` variants, `SEMI` (empty statement), `py_code_block` as a statement) or clearly stating that full details are in respective dedicated files. Many specific statement types have their own documentation pages.

    3.  **Statement Termination:**
        *   **Documentation:** States most statements need semicolons, control/block statements usually don't.
        *   **Grammar:** Shows specific `SEMI` usage.
        *   **Status:** Generally covered.

    4.  **Empty Statement `SEMI`:**
        *   **Grammar:** `statement: ... | SEMI` allows empty statements.
        *   **Documentation:** Does not explicitly mention the empty statement.
        *   **Issue:** The empty statement is not documented in this overview.

---

## Section 13: If statements

*   **Grammar Rules from `jac.lark`:**
    ```lark
    if_stmt: KW_IF expression code_block (elif_stmt | else_stmt)?
    elif_stmt: KW_ELIF expression code_block (elif_stmt | else_stmt)?
    else_stmt: KW_ELSE code_block
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/if_statements.md`
*   **Findings:**
    1.  **Basic `if`:** Covered.
    2.  **`if-else`:** Covered.
    3.  **`if-elif`:** Covered.
    4.  **`if-elif-else`:** Covered.
    5.  **Multiple `elif` statements:** Covered.
    6.  **`expression` as condition:** Well covered with diverse examples.
    7.  **Mandatory `code_block`:** Covered and emphasized.

*   **Overall:** The documentation for `if_stmt` appears to be thorough and consistent with the grammar rules.

---

## Section 14: While statements

*   **Grammar Rules from `jac.lark`:**
    ```lark
    while_stmt: KW_WHILE expression code_block
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/while_statements.md`
*   **Findings:**
    1.  **Basic Syntax `while condition { ... }`:** Covered.
    2.  **`expression` as Condition:** Well covered with diverse examples.
    3.  **Mandatory `code_block`:** Covered.
    4.  **Absence of `else` clause:** Consistent with grammar (correctly omitted).

*   **Overall:** The documentation for `while_stmt` is comprehensive and aligns well with the grammar rule.

---

## Section 15: For statements

*   **Grammar Rules from `jac.lark`:**
    ```lark
    for_stmt: KW_ASYNC? KW_FOR assignment KW_TO expression KW_BY assignment code_block else_stmt?
           | KW_ASYNC? KW_FOR atomic_chain KW_IN expression code_block else_stmt?
    // assignment: KW_LET? (atomic_chain EQ)+ (yield_expr | expression) | atomic_chain type_tag (EQ (yield_expr | expression))? | atomic_chain aug_op (yield_expr | expression)
    // atomic_chain: can be a simple name or a de-structuring pattern (e.g., x, y)
    // else_stmt: KW_ELSE code_block
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/for_statements.md`
*   **Findings:**
    1.  **For-In Loop (`for variable in iterable`):**
        *   **Grammar:** `KW_FOR atomic_chain KW_IN expression code_block else_stmt?`.
        *   **Documentation:** Covers simple variables and de-structuring (`for index, value in ...`).
        *   **Status:** Well covered.

    2.  **For-To-By Loop (`for init to condition by increment`):**
        *   **Grammar:** `KW_FOR assignment KW_TO expression KW_BY assignment code_block else_stmt?`.
        *   **Documentation:** Shows examples like `for i=0 to i<10 by i+=1`.
        *   **Status:** Well covered.

    3.  **`KW_ASYNC` for For Loops:**
        *   **Grammar:** Allows `KW_ASYNC?` on both variants.
        *   **Documentation:** Shows `async for ... in ...`. Does not explicitly show `async for ... to ... by ...`.
        *   **Issue:** `async` for the "for-to-by" variant is not exemplified.

    4.  **`else_stmt` for For Loops:**
        *   **Grammar:** Allows `else_stmt?` on both variants.
        *   **Documentation:** No examples show a `for` loop with an `else` clause.
        *   **Issue:** The optional `else` clause for `for` loops is not documented or exemplified.

    5.  **Multi-Variable Assignment in For-To-By Initialization/Increment:**
        *   **Documentation shows:** `for i=0, j=len(array)-1 to i<j by i+=1, j-=1`.
        *   **Grammar `for_stmt` uses `assignment` rule:** The standard `assignment` rule does not directly support multiple comma-separated independent assignments (e.g., `i=0, j=val`). This looks more like an `assignment_list`.
        *   **Issue/Inconsistency:** The multi-variable example suggests the `assignment` parts in `for_stmt` might accept an `assignment_list` or a special comma-separated form not directly evident from the `assignment` rule's definition. This discrepancy needs clarification.

    6.  **Conditional Iteration (filter in for-in):**
        *   **Documentation shows:** `for item in collection if item.is_valid() { ... }`.
        *   **Grammar `for_stmt` (for-in variant):** Does not include syntax for an `if condition` filter as part of the loop definition itself.
        *   **Issue:** The `if condition` filter syntax directly in the `for ... in ...` statement is not represented in the provided `for_stmt` grammar. This might be syntactic sugar or a higher-level feature.

---

## Section 16: Try statements

*   **Grammar Rules from `jac.lark`:**
    ```lark
    try_stmt: KW_TRY code_block except_list? else_stmt? finally_stmt?
    except_list: except_def+
    except_def: KW_EXCEPT expression (KW_AS NAME)? code_block
    finally_stmt: KW_FINALLY code_block
    // else_stmt: KW_ELSE code_block
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/try_statements.md`
*   **Findings:**
    1.  **Basic `try-except` (with specific exceptions):**
        *   **Grammar:** `KW_TRY code_block except_list` where `except_def` is `KW_EXCEPT expression (KW_AS NAME)? code_block`.
        *   **Documentation:** Shows examples like `except ValueError as e` and `except IOError`.
        *   **Status:** Covered.

    2.  **Multiple `except` blocks:**
        *   **Grammar:** `except_list: except_def+`.
        *   **Documentation:** Examples show multiple `except` blocks.
        *   **Status:** Covered.

    3.  **Catch-all `except` (Bare `except` vs. `except Exception`):
        *   **Documentation Syntax Overview shows:** `except { # handle any exception }` (bare except).
        *   **Documentation Example shows:** `except Exception as e { ... }`.
        *   **Grammar `except_def`:** `KW_EXCEPT expression ...` requires an `expression` (exception type).
        *   **Issue/Inconsistency:** The bare `except { ... }` syntax from the documentation overview is inconsistent with the grammar rule `except_def` which mandates an `expression`. To catch all exceptions per the current grammar, `except Exception ...` must be used, which is shown in an example.

    4.  **`else_stmt` (`else` clause for `try`):**
        *   **Grammar:** `try_stmt: ... else_stmt? ...`.
        *   **Documentation:** Explains and exemplifies the `else` clause.
        *   **Status:** Covered.

    5.  **`finally_stmt` (`finally` clause for `try`):**
        *   **Grammar:** `try_stmt: ... finally_stmt?`.
        *   **Documentation:** Explains and exemplifies the `finally` clause.
        *   **Status:** Covered.

    6.  **Combinations (e.g., `try-except-else-finally`):**
        *   **Grammar:** Allows all optional parts.
        *   **Documentation:** Syntax overview implies combinations.
        *   **Status:** Generally covered (with the bare `except` inconsistency noted).

*   **Overall:** Documentation is mostly comprehensive, with the main inconsistency being the syntax for a catch-all `except` block.

---

## Section 17: Match statements

*   **Grammar Rules from `jac.lark`:**
    ```lark
    match_stmt: KW_MATCH expression LBRACE match_case_block+ RBRACE
    match_case_block: KW_CASE pattern_seq (KW_IF expression)? COLON statement+
    // pattern_seq and specific pattern rules are defined in subsequent sections.
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/match_statements.md`
*   **Findings:**
    1.  **Basic `match` statement structure (`match expr { case ... }`):**
        *   **Status:** Covered.

    2.  **`match_case_block` structure (`case pattern: statements`):**
        *   **Status:** Covered.

    3.  **`pattern_seq` (Top-level pattern in a case, e.g., OR, AS patterns):**
        *   **Documentation:** Shows examples of OR patterns (`case "a" | "b":`) and AS patterns (`case [x,y] as p:`).
        *   **Status:** Covered.

    4.  **Guard Condition (`if expression` on a case):**
        *   **Grammar:** `(KW_IF expression)?`.
        *   **Documentation:** Explains and exemplifies guarded cases (`case pattern if condition:`).
        *   **Status:** Covered.

    5.  **Overview of Pattern Types (Literal, Capture, Sequence, Mapping, Class, Singleton):**
        *   **Documentation:** Provides a good overview with examples for these common pattern types.
        *   **Status:** Good overview. Detailed analysis depends on specific pattern grammar sections.

    6.  **Wildcard `_`:**
        *   **Documentation:** Example `case _: ...` shows its use as a wildcard.
        *   **Grammar:** `capture_pattern: NAME`. Assumes `_` is a valid `NAME` with special wildcard semantics.
        *   **Status:** Usage documented.

*   **Overall:** The `match_statements.md` provides a solid introduction to match statements and seems consistent with the primary grammar rules for `match_stmt` and `match_case_block`. Detailed pattern analysis will follow with specific pattern sections.

---

## Section 18: Match patterns (Grammar Details)

*   **Grammar Rules from `jac.lark`:**
    ```lark
    pattern_seq: (or_pattern | as_pattern)
    or_pattern: (pattern BW_OR)* pattern
    as_pattern: or_pattern KW_AS NAME

    pattern: literal_pattern
        | singleton_pattern
        | capture_pattern
        | sequence_pattern
        | mapping_pattern
        | class_pattern
    ```
*   **Corresponding Markdown File:** No dedicated `match_patterns.md`. These rules are covered within `match_statements.md`.
*   **Findings:**
    1.  **`pattern_seq` (overall pattern structure in a `case`):**
        *   Covered in `match_statements.md` via "OR Patterns" and "AS Patterns" examples.
        *   **Status:** Covered.

    2.  **`or_pattern` (`pattern BW_OR pattern ...`):**
        *   Covered in `match_statements.md` ("OR Patterns" section).
        *   **Status:** Covered.

    3.  **`as_pattern` (`or_pattern KW_AS NAME`):**
        *   Covered in `match_statements.md` ("AS Patterns" section, e.g., `case [x, y] as point:`).
        *   The nuance that the LHS of `KW_AS` is an `or_pattern` (e.g., `case (A | B) as C:`) is not explicitly exemplified.
        *   **Issue (Minor):** An example of `as_pattern` with a preceding `or_pattern` involving `|` would offer more clarity.
        *   **Status:** Generally covered; could be more explicit on `or_pattern` interaction.

    4.  **`pattern` (disjunction of specific pattern types):**
        *   The concept that a `pattern` is one of literal, singleton, capture, sequence, mapping, or class pattern is introduced in `match_statements.md` under "Pattern Types".
        *   **Status:** Covered at a high level. Detailed analysis relies on specific `xxx_pattern.md` files.

*   **Overall:** The structural rules for combining patterns (OR, AS) and the main pattern categories are introduced in `match_statements.md`. No separate `match_patterns.md` file seems to exist or be strictly necessary if specific pattern files are comprehensive.

---

## Section 19: Match literal patterns

*   **Grammar Rules from `jac.lark`:**
    ```lark
    literal_pattern: (INT | FLOAT | multistring)
    // multistring: (fstring | STRING)+
    // INT, FLOAT are terminals for various number formats.
    // Note: BOOL and NULL are in singleton_pattern, not literal_pattern.
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/match_literal_patterns.md`
*   **Findings:**
    1.  **Misclassification of `None` and Booleans:**
        *   **Documentation (`match_literal_patterns.md`):** Includes `true`, `false`, and `None` as examples of literal patterns.
        *   **Grammar:** Defines `literal_pattern` as `(INT | FLOAT | multistring)` and `singleton_pattern` as `(NULL | BOOL)`.
        *   **Issue:** Major inconsistency. `None` and booleans are grammatically `singleton_pattern`s and should be documented there, not under literal patterns.

    2.  **Coverage of `INT`, `FLOAT`, `STRING`:**
        *   **Numeric Literals (`INT`, `FLOAT`):** Documented examples cover decimal integers, floats, and different integer bases (hex, binary, octal), aligning with the grammar.
        *   **Status:** Covered.
        *   **String Literals (`multistring`):**
            *   Documentation shows simple string literals (e.g., `case "hello":`).
            *   The grammar `multistring: (fstring | STRING)+` allows for f-strings or concatenated strings. The behavior/validity of f-strings (which usually involve runtime interpolation) or concatenated strings as patterns is not clarified in this document.
            *   **Issue (Minor/Clarification):** The documentation should clarify if `fstring` or concatenated strings are valid in `literal_pattern` and how they are treated (e.g., if f-strings must resolve to constants at compile time).
            *   **Status (Simple Strings):** Covered.

    3.  **Interaction with OR patterns:**
        *   Documentation correctly shows literal patterns used within OR patterns (e.g., `case 400 | 401:`).
        *   **Status:** Covered.

*   **Overall:** The primary issue is the miscategorization of `None` and booleans. Coverage for true literals (numbers, simple strings) is good, but clarity on advanced `multistring` features as patterns is needed.

---

## Section 20: Match singleton patterns

*   **Grammar Rules from `jac.lark`:**
    ```lark
    singleton_pattern: (NULL | BOOL)
    // NULL: "None"
    // BOOL: "True" | "False"
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/match_singleton_patterns.md`
*   **Findings:**
    1.  **Matching `None` (`NULL` token):**
        *   **Grammar:** `NULL` is part of `singleton_pattern`.
        *   **Documentation:** Shows `case None: ...`.
        *   **Status:** Covered.

    2.  **Matching Booleans (`BOOL` token):**
        *   **Grammar:** `BOOL` is part of `singleton_pattern`.
        *   **Documentation:** Shows `case True: ...` and `case False: ...`.
        *   **Status:** Covered.

    3.  **Correct Scope:**
        *   The documentation correctly focuses only on `None`, `True`, and `False` for singleton patterns, aligning with the grammar.
        *   **Status:** Correct.

*   **Overall:** The documentation for `match_singleton_patterns.md` is accurate and consistent with the grammar.

---

## Section 21: Match capture patterns

*   **Grammar Rules from `jac.lark`:**
    ```lark
    capture_pattern: NAME
    // NAME is an identifier (e.g., my_var, _)
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/match_capture_patterns.md`
*   **Findings:**
    1.  **Basic Capture (`NAME` as pattern):**
        *   **Grammar:** `capture_pattern: NAME`.
        *   **Documentation:** Shows examples like `case username: ...` and `case temp: ...` where an identifier captures the matched value.
        *   **Status:** Covered.

    2.  **Wildcard `_` as a Capture Pattern:**
        *   **Documentation (`match_statements.md`):** Shows `case _: ...`.
        *   **Grammar:** If `_` is a valid `NAME` token, this is consistent. `_` as a capture pattern for unused values is a common convention.
        *   **Status:** Covered (assuming `_` is a `NAME`).

    3.  **Role in Complex Patterns:**
        *   `NAME` (as a capture mechanism) is also a fundamental part of `sequence_pattern`, `mapping_pattern`, and `class_pattern` for binding parts of those structures.
        *   **Documentation:** Examples in this file and `match_statements.md` illustrate this (e.g., `case [x,y]:`, `case {"key": val}:`).
        *   **Status:** The broader role of `NAME` in destructuring is implicitly covered by examples of those more complex patterns.

*   **Overall:** The documentation accurately reflects the use of a simple `NAME` as a capture pattern and its basic behavior. Its role within more complex patterns is also shown through examples.

---

## Section 22: Match sequence patterns

*   **Grammar Rules from `jac.lark`:**
    ```lark
    sequence_pattern: LSQUARE list_inner_pattern (COMMA list_inner_pattern)* RSQUARE
                    | LPAREN list_inner_pattern (COMMA list_inner_pattern)* RPAREN
    list_inner_pattern: (pattern_seq | STAR_MUL NAME)
    // pattern_seq -> or_pattern | as_pattern -> pattern -> specific_patterns
    // STAR_MUL NAME is for *rest type captures.
    ```
*   **Corresponding Markdown File:** No dedicated `match_sequence_patterns.md`. Overview in `match_statements.md` ("Sequence Patterns" section).
*   **Findings (based on `match_statements.md`):**
    1.  **List `[...]` and Tuple `(...)` Patterns:**
        *   **Grammar:** Defines `LSQUARE ... RSQUARE` and `LPAREN ... RPAREN`.
        *   **Documentation (`match_statements.md`):** Shows list patterns (`case [x,y]:`). Tuple patterns are mentioned as similar but not explicitly exemplified with `(...)` in that section.
        *   **Status:** List patterns covered. Tuple patterns implicitly covered but could have a direct example.

    2.  **`list_inner_pattern` (elements within the sequence):**
        *   **Grammar:** Each element can be a `pattern_seq` (complex pattern) or `STAR_MUL NAME` (`*rest`).
        *   **Documentation (`match_statements.md`):** Examples `case [x,y]:` (elements are capture patterns) and `case [first, *rest]:` (capture and star expression) cover basic cases.
        *   The ability for an inner element to be a more complex `pattern_seq` (e.g., `case [val1 | val2, another_val]:` or `case [[a,b], c]:`) is not explicitly shown in the overview.
        *   **Status:** Basic inner elements (captures, star expressions) are covered. Complex nested patterns as elements are not explicitly detailed in the overview.

    3.  **Matching Empty Sequences (`[]`, `()`):**
        *   **Grammar:** `list_inner_pattern (COMMA list_inner_pattern)*` implies at least one item is required in the pattern.
        *   **Documentation (`match_statements.md`):** Examples show patterns with one or more elements. Matching empty lists/tuples (e.g., `case []:`) is not shown or discussed.
        *   **Issue/Clarification Needed:** The grammar seems to require at least one element in sequence patterns. If matching empty sequences like `[]` or `()` is supported, the mechanism (whether by this rule through some interpretation or a different rule) needs to be clarified in grammar or documentation.

*   **Overall:** `match_statements.md` introduces basic list sequence patterns, capture of elements, and star expressions. Tuple patterns are less explicitly shown. The full recursive power of `list_inner_pattern` and matching of empty sequences are areas needing more detailed documentation or clarification against the grammar.

---

## Section 23: Match mapping patterns

*   **Grammar Rules from `jac.lark` (relevant):**
    ```lark
    mapping_pattern: LBRACE (dict_inner_pattern (COMMA dict_inner_pattern)*)? RBRACE
    dict_inner_pattern: (literal_pattern COLON pattern_seq | STAR_POW NAME)
    // literal_pattern for key: (INT | FLOAT | multistring)
    // pattern_seq for value: or_pattern | as_pattern -> pattern -> specific_patterns
    // STAR_POW NAME is for **rest captures.
    ```
    *(Note: A `list_inner_pattern` rule appears under this heading in `jac.lark` but seems misplaced and is ignored for this section.)*

*   **Corresponding Markdown File:** No dedicated `match_mapping_patterns.md`. Overview in `match_statements.md` ("Mapping Patterns" section).
*   **Findings (based on `match_statements.md`):**
    1.  **Dictionary/Mapping Pattern `{...}`:**
        *   **Grammar:** `LBRACE (dict_inner_pattern (COMMA dict_inner_pattern)*)? RBRACE`. The trailing `?` on the group allows for empty mapping patterns (`{}`).
        *   **Documentation (`match_statements.md`):** Shows examples like `case {"host": host, "port": port}:`. Does not explicitly show matching an empty dictionary `case {}:`.
        *   **Status:** Non-empty mapping patterns covered. Empty mapping pattern `{}` is allowed by grammar but not explicitly documented in the overview.

    2.  **`dict_inner_pattern` (key-value or `**rest`):**
        *   **Key-Value Pair (`literal_pattern COLON pattern_seq`):**
            *   Documentation shows simple string literal keys and capture patterns for values (e.g., `{"host": host}`).
            *   The use of more complex `pattern_seq` for values (e.g., `{"data": [x,y]}`) is implied by grammar but not explicitly shown in this section's examples.
            *   **Status:** Basic key-value matching covered.
        *   **Star-Star Expression (`STAR_POW NAME` for `**rest`):**
            *   Documentation shows `case {"url": url, **options}:`.
            *   **Status:** Covered.

    3.  **Multiple Key-Value Pairs / Optional Content:**
        *   **Grammar:** `(dict_inner_pattern (COMMA dict_inner_pattern)*)?` allows zero or more elements.
        *   **Documentation:** Examples show multiple elements. The case of zero elements (empty map `{}`) is not explicitly shown.
        *   **Status:** Covered for non-empty. Empty map matching implied by grammar but not shown.

    4.  **Keys as `literal_pattern` (Non-string keys):**
        *   **Grammar:** Keys are `literal_pattern` (`INT | FLOAT | multistring`).
        *   **Documentation:** All examples use string literal keys.
        *   **Issue (Minor/Clarification):** Use of non-string literal keys (e.g., `case {10: val}:`) is grammatically possible but not documented in the overview. This is a less common case.

*   **Overall:** `match_statements.md` introduces basic mapping patterns well. Matching empty dictionaries and using non-string literal keys are grammatically allowed but not explicitly shown in the overview. The full power of `pattern_seq` for matching values is also implied rather than exhaustively demonstrated in this section.

---

## Section 24: Match class patterns

*   **Grammar Rules from `jac.lark`:**
    ```lark
    class_pattern: NAME (DOT NAME)* LPAREN kw_pattern_list? RPAREN                 // Variant 1: Only keyword patterns
                 | NAME (DOT NAME)* LPAREN pattern_list (COMMA kw_pattern_list)? RPAREN // Variant 2: Positional and optional keyword

    pattern_list: (pattern_list COMMA)? pattern_seq    // For positional argument patterns
    kw_pattern_list: (kw_pattern_list COMMA)? named_ref EQ pattern_seq // For keyword argument patterns (attr_name = value_pattern)
    // NAME (DOT NAME)* is the class type (e.g., MyClass, module.MyClass).
    // pattern_seq for values can be complex.
    ```
*   **Corresponding Markdown File:** No dedicated `match_class_patterns.md`. Overview in `match_statements.md` ("Class Patterns" section).
*   **Findings (based on `match_statements.md`):**
    1.  **Basic Class Pattern Syntax `ClassName(...)`:**
        *   **Documentation (`match_statements.md`):** Shows `case Circle(radius=r):`. Covers simple class names.
        *   Qualified class names (e.g., `module.ClassName`) are allowed by `NAME (DOT NAME)*` in grammar but not explicitly shown in this overview.
        *   **Status:** Basic structure with simple names covered.

    2.  **Keyword Argument Patterns (`attr=pattern`):**
        *   **Grammar:** Covered by `kw_pattern_list`.
        *   **Documentation (`match_statements.md`):** Examples like `Circle(radius=r)` and `Rectangle(width=w, height=h)` clearly demonstrate this.
        *   **Status:** Covered.

    3.  **Positional Argument Patterns:**
        *   **Grammar:** Covered by `pattern_list` in the second variant of `class_pattern`.
        *   **Documentation (`match_statements.md`):** This overview does not show examples of positional patterns (e.g., `case MyClass(pattern_for_arg1, pattern_for_arg2):`).
        *   **Issue:** Positional patterns in class matching are not documented in the overview.

    4.  **Combination of Positional and Keyword Patterns:**
        *   **Grammar:** Allowed by the second variant of `class_pattern`.
        *   **Documentation:** Not shown, as positional patterns themselves are not shown.
        *   **Issue:** Not documented.

    5.  **Matching Type Only (`ClassName()`):**
        *   **Grammar:** Seems possible via the first `class_pattern` variant if `kw_pattern_list` is omitted (due to `?`).
        *   **Documentation (`match_statements.md`):** Does not show an example like `case MyClass():` for type-only matching.
        *   **Issue (Minor/Clarification):** Type-only matching is a common use case and an explicit example would be beneficial.

    6.  **Complex `pattern_seq` for Attribute Values:**
        *   **Grammar:** Allows complex patterns for attribute values (e.g., `radius=(val1 | val2)` or `data=[x,y]`).
        *   **Documentation (`match_statements.md`):** Examples use simple capture patterns (e.g., `radius=r`). Matching attributes against more complex nested patterns is not explicitly shown in the overview.
        *   **Status:** Basic capture of attribute values covered. Complex patterns for attribute values implied by grammar but not detailed in overview.

*   **Overall:** The `match_statements.md` overview introduces class patterns focusing on keyword-based attribute matching. Positional attribute matching, type-only matching, and matching attributes against more complex patterns are not explicitly covered in this overview but are allowed by the grammar.

---

## Section 25: Context managers

*   **Grammar Rules from `jac.lark`:**
    ```lark
    with_stmt: KW_ASYNC? KW_WITH expr_as_list code_block
    expr_as_list: (expr_as COMMA)* expr_as
    expr_as: expression (KW_AS expression)?
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/context_managers.md`
*   **Findings:**
    1.  **Basic `with` statement (`with expr as var` and `with expr`):**
        *   **Grammar:** `KW_WITH expr_as_list code_block`. `expr_as` can optionally have `KW_AS expression`.
        *   **Documentation:** Shows both `with open(...) as file:` and `with self.lock:`. Covers cases with and without `as var`.
        *   **Status:** Covered.

    2.  **`KW_ASYNC` with `with` statement:**
        *   **Grammar:** `KW_ASYNC? KW_WITH ...`.
        *   **Documentation:** Shows `async with ... as ...`.
        *   **Status:** Covered.

    3.  **Multiple context managers (`with expr1 as var1, expr2 as var2`):**
        *   **Grammar:** `expr_as_list: (expr_as COMMA)* expr_as`.
        *   **Documentation:** Shows examples with multiple context managers in one `with` statement.
        *   **Status:** Covered.

    4.  **Variable in `expr_as` (Target of `KW_AS expression`):**
        *   **Grammar:** `KW_AS expression`. Allows the target to be an `expression`.
        *   **Documentation:** All examples show `... as variable_name` (a simple `NAME`).
        *   **Issue/Clarification:** The grammar is broader, potentially allowing targets like `my_obj.attr` or even de-structuring assignments if the `expression` rule and semantic analysis permit. The documentation only shows simple name targets. If only simple names are intended or idiomatic, this could be clarified, or the grammar for the target of `KW_AS` might be more specific in practice.

    5.  **Custom Context Managers (Defining `__enter__`, `__exit__`):**
        *   **Documentation:** Provides good examples of creating custom context manager objects.
        *   **Status:** Well covered.

*   **Overall:** The documentation aligns well with the grammar for common uses. The main point needing potential clarification is the scope of the `expression` allowed as the target variable after `KW_AS`.

---

## Section 26: Global and nonlocal statements

*   **Grammar Rules from `jac.lark`:**
    ```lark
    global_ref: GLOBAL_OP name_list
    nonlocal_ref: NONLOCAL_OP name_list
    name_list: (named_ref COMMA)* named_ref

    GLOBAL_OP: /:g:|:global:/
    NONLOCAL_OP: /:nl:|:nonlocal:/
    // These are used in statement rule as: global_ref SEMI, nonlocal_ref SEMI
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/global_and_nonlocal_statements.md`
*   **Findings:**
    1.  **Global Statement Syntax (`:g:`, `:global:`):**
        *   **Grammar:** `GLOBAL_OP name_list`.
        *   **Documentation:** Shows syntax with `:g:` and `:global:`, and examples with single and multiple variables.
        *   **Status:** Covered.

    2.  **Nonlocal Statement Syntax (`:nl:`, `:nonlocal:`):**
        *   **Grammar:** `NONLOCAL_OP name_list`.
        *   **Documentation:** Shows syntax with `:nl:` and `:nonlocal:`, and examples with single and multiple variables.
        *   **Status:** Covered.

    3.  **`name_list` (List of variables):**
        *   **Grammar:** `(named_ref COMMA)* named_ref`.
        *   **Documentation:** Examples use simple variable names, which is typical.
        *   **Status:** Covered for typical usage.

    4.  **Statement Termination (Semicolon):**
        *   **Grammar:** Requires a `SEMI` as these are statements (`global_ref SEMI`, `nonlocal_ref SEMI`).
        *   **Documentation:** The syntax overview correctly includes semicolons (e.g., `:g: counter, total;`). However, some inline code examples in the text body occasionally omit the semicolon.
        *   **Issue (Minor Inconsistency):** Some examples in the text body should be updated to consistently include the trailing semicolon for these statements.

*   **Overall:** The documentation accurately describes the global and nonlocal statements. The primary minor issue is the inconsistent presence of semicolons in some textual examples, which should be rectified for grammatical accuracy.

---

## Section 27: Data spatial typed context blocks

*   **Grammar Rules from `jac.lark`:**
    ```lark
    typed_ctx_block: RETURN_HINT expression code_block
    // RETURN_HINT is "->"
    // expression is the type expression.
    // code_block is { ... }.
    // This rule is a type of statement.
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/data_spatial_typed_context_blocks.md`
*   **Findings:**
    1.  **Syntax `-> type_expression { ... }`:**
        *   **Grammar:** `RETURN_HINT expression code_block`.
        *   **Documentation:** Correctly shows the syntax `-> type_expression { ... }` and provides examples like `-> dict[str, any] { ... }`.
        *   **Status:** Covered.

    2.  **Purpose and Usage (Type-Constrained Scope):**
        *   **Documentation:** Explains its use for compile-time and runtime type assertions within the block, especially for object-spatial operations (e.g., constraining `here.data`).
        *   **Status:** Well-explained.

    3.  **As a Statement:**
        *   **Grammar:** `typed_ctx_block` is a `statement`.
        *   **Documentation:** Examples show its use within ability bodies. Its ability to be used in other nested contexts (e.g., inside an `if`) is implied by its nature as a statement.
        *   **Status:** Primary usage covered.

    4.  **Interaction with Ability Return Types:**
        *   **Documentation:** The section "Return Type Enforcement" shows a `typed_ctx_block` within an ability that has a return type, with the `return` statement inside the typed block.
        *   **Clarification Needed:** The phrasing about the block "guaranteeing" the return type might be slightly imprecise. The block enforces type constraints on the code *within* it. If a `return` statement is inside this block, the returned value will be checked against the block's type. The block itself isn't a return mechanism but a type-constrained scope.
        *   **Status:** Example is valid; explanation could be more precise about the mechanism of enforcement.

*   **Overall:** The documentation clearly explains the syntax and primary purpose. The explanation of its role in return type enforcement is understandable through the example but could be refined for precision.

---

## Section 28: Return statements

*   **Grammar Rules from `jac.lark`:**
    ```lark
    return_stmt: KW_RETURN expression?
    // Used in statement rule as: return_stmt SEMI
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/return_statements.md`
*   **Findings:**
    1.  **Return with an expression (`return expression;`):**
        *   **Grammar Form:** `KW_RETURN expression SEMI`.
        *   **Documentation:** Shows `return expression;` and provides numerous examples.
        *   **Status:** Covered.

    2.  **Return without an expression (`return;` for void functions/abilities):**
        *   **Grammar Form:** `KW_RETURN SEMI`.
        *   **Documentation:** Shows `return;` and explains it yields `None`.
        *   **Status:** Covered.

    3.  **Statement Termination (Semicolon):**
        *   **Grammar:** Requires a `SEMI` when used as a statement.
        *   **Documentation:** Syntax overview and most examples correctly include the semicolon.
        *   **Status:** Covered.

    4.  **Nature of `expression`:**
        *   **Grammar:** `expression` can be any valid Jac expression.
        *   **Documentation:** Examples show various types of expressions being returned (literals, variables, calculations, tuples, dictionaries).
        *   **Status:** Well covered.

*   **Overall:** The documentation for `return_stmt` is comprehensive and accurately reflects the grammar and common usage patterns.

---

## Section 29: Yield statements

*   **Grammar Rules from `jac.lark`:**
    ```lark
    yield_expr: KW_YIELD KW_FROM? expression
    // Used in statement rule as: (yield_expr | KW_YIELD) SEMI
    // This resolves to three forms for statements:
    // 1. KW_YIELD KW_FROM expression SEMI  (yield from ...)
    // 2. KW_YIELD expression SEMI          (yield ...)
    // 3. KW_YIELD SEMI                     (yield; / yield None)
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/yield_statements.md`
*   **Findings:**
    1.  **Yield an expression (`yield expression;`):**
        *   **Grammar Form:** `KW_YIELD expression SEMI`.
        *   **Documentation:** Shows `yield expression;` and provides numerous examples.
        *   **Status:** Covered.

    2.  **Bare yield / Yield None (`yield;`):**
        *   **Grammar Form:** `KW_YIELD SEMI`.
        *   **Documentation:** Shows `yield;` and explains it yields `None`.
        *   **Status:** Covered.

    3.  **Yield from an iterable (`yield from expression;`):**
        *   **Grammar Form:** `KW_YIELD KW_FROM expression SEMI`.
        *   **Documentation:** Shows `yield from iterable;` and provides examples with other generators and collections.
        *   **Status:** Covered.

    4.  **Statement Termination (Semicolon):**
        *   **Grammar:** All forms require a `SEMI` when used as a statement.
        *   **Documentation:** Syntax overview and most examples correctly include the semicolon.
        *   **Status:** Generally covered.

    5.  **Generator Function Characteristics:**
        *   **Documentation:** Accurately describes how functions with `yield` become generators, their execution model, and state persistence.
        *   **Status:** Well explained.

*   **Overall:** The documentation for yield statements and generator functions is comprehensive and aligns accurately with the grammar rules.

---

## Section 30: Raise statements

*   **Grammar Rules from `jac.lark`:**
    ```lark
    raise_stmt: KW_RAISE (expression (KW_FROM expression)?)?
    // Used in statement rule as: raise_stmt SEMI
    // This resolves to three forms for statements:
    // 1. KW_RAISE expression SEMI                 (raise new/specific exception)
    // 2. KW_RAISE SEMI                            (re-raise current exception)
    // 3. KW_RAISE expression KW_FROM expression SEMI (raise new with cause)
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/raise_statements.md`
*   **Findings:**
    1.  **Raise a specific exception (`raise expression;`):**
        *   **Grammar Form:** `KW_RAISE expression SEMI`.
        *   **Documentation:** Shows `raise exception_expression;` and provides examples like `raise ValueError(...)`.
        *   **Status:** Covered.

    2.  **Re-raise current exception (`raise;`):**
        *   **Grammar Form:** `KW_RAISE SEMI`.
        *   **Documentation:** Shows `raise;` and explains its use in `except` blocks.
        *   **Status:** Covered.

    3.  **Raise with cause (`raise expression from cause_expression;`):**
        *   **Grammar Form:** `KW_RAISE expression KW_FROM expression SEMI`.
        *   **Documentation:** Shows `raise exception_expression from cause;` and examples with an exception variable or `None` as the cause.
        *   **Status:** Covered.

    4.  **Statement Termination (Semicolon):**
        *   **Grammar:** All forms require a `SEMI` when used as a statement.
        *   **Documentation:** Syntax overview and most examples correctly include the semicolon.
        *   **Status:** Generally covered.

    5.  **Nature of `expression` for exception/cause:**
        *   **Documentation:** Examples show instantiation of exception classes or existing exception variables, which is standard.
        *   **Status:** Well covered.

*   **Overall:** The documentation for raise statements is comprehensive and accurately reflects the grammar and common usage patterns for all three forms of the raise statement.

---

## Section 31: Assert statements

*   **Grammar Rules from `jac.lark`:**
    ```lark
    assert_stmt: KW_ASSERT expression (COMMA expression)?
    // Used in statement rule as: assert_stmt SEMI
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/assert_statements.md`
*   **Findings:**
    1.  **Assert with condition only (`assert condition;`):**
        *   **Grammar Form:** `KW_ASSERT expression SEMI`.
        *   **Documentation:** Shows `assert condition;`.
        *   **Status:** Covered.

    2.  **Assert with condition and message (`assert condition, message_expr;`):**
        *   **Grammar Form:** `KW_ASSERT expression COMMA expression SEMI`.
        *   **Documentation:** Shows `assert condition, "Custom error message";`.
        *   **Status:** Covered.

    3.  **Statement Termination (Semicolon):**
        *   **Grammar:** Requires a `SEMI` when used as a statement.
        *   **Documentation:** Syntax examples correctly include the semicolon.
        *   **Status:** Covered.

    4.  **Nature of `expression` for condition and message:**
        *   **Documentation:** Condition is shown as a boolean expression; message is shown as a string literal. This is typical.
        *   **Status:** Covered for typical usage.

*   **Overall:** The documentation for assert statements is clear, concise, and accurately aligns with the grammar and common usage.

---

## Section 32: Check statements

*   **Grammar Rules from `jac.lark`:**
    ```lark
    check_stmt: KW_CHECK expression
    // Used in statement rule as: check_stmt SEMI
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/check_statements.md`
*   **Findings:**
    1.  **Basic Syntax (`check expression;`):**
        *   **Grammar Form:** `KW_CHECK expression SEMI`.
        *   **Documentation:** Shows `check expression;`.
        *   **Status:** Covered.

    2.  **Nature of `expression`:**
        *   **Documentation:** Explains the expression should be truthy. Examples show various boolean conditions.
        *   **Status:** Well covered.

    3.  **Integration with Test Blocks:**
        *   **Documentation:** Emphasizes use within `test` blocks.
        *   **Status:** Contextual usage well explained.

    4.  **Statement Termination (Semicolon):**
        *   **Grammar:** Requires a `SEMI`.
        *   **Documentation:** Syntax and examples correctly include the semicolon.
        *   **Status:** Covered.

*   **Overall:** The documentation for `check_stmt` is clear and aligns well with the grammar, properly explaining its use in testing.

---

## Section 33: Delete statements

*   **Grammar Rules from `jac.lark`:**
    ```lark
    delete_stmt: KW_DELETE expression
    // Used in statement rule as: delete_stmt SEMI
    // expression can be various things like variable names, attributes, list/dict elements.
    // Separately, there's disconnect_op: KW_DELETE edge_op_ref for specific edge deletions in expressions.
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/delete_statements.md`
*   **Findings:**
    1.  **Basic Syntax (`del expression;`):**
        *   **Grammar:** `KW_DELETE expression SEMI`.
        *   **Documentation:** Shows `del expression;`.
        *   **Status:** Covered.

    2.  **Nature of `expression` (What can be deleted):**
        *   **Documentation:** Provides good examples for deleting variables, object properties, list elements/slices, dictionary entries, and nodes.
        *   **Status:** Well covered for many common cases.

    3.  **Deleting Multiple Variables (`del a, b, c;`):**
        *   **Documentation shows:** `del a, b, c;`.
        *   **Grammar `delete_stmt`:** `KW_DELETE expression` expects a single expression.
        *   **Issue/Inconsistency:** The example `del a, b, c;` doesn't directly map to `KW_DELETE expression` if `expression` doesn't support a top-level comma-separated list of deletable items. Python's `del` does support this. This might imply `expression` can be a tuple of references or a special parsing for `del`.

    4.  **Deleting Edges (Specific Syntaxes):**
        *   **Documentation shows:** `del source_node -->:EdgeType:--> target_node;` and `del node [-->];`.
        *   **Grammar:** These edge specifications are forms of `edge_ref_chain` (an expression). So `del <edge_ref_chain_expr>;` would fit the `delete_stmt` rule.
        *   The grammar also has `disconnect_op: KW_DELETE edge_op_ref` used within `connect` expressions, which is different. The documentation examples appear to be standalone statements, fitting `delete_stmt`.
        *   **Status:** Likely covered by `delete_stmt` if the edge specification is a valid `expression` yielding the edge(s) to delete. Clarity on whether these specific syntaxes always resolve to an expression suitable for the general `del expression` statement would be good.

    5.  **Statement Termination (Semicolon):**
        *   **Grammar:** Requires `SEMI`.
        *   **Documentation:** Syntax overview and most examples include the semicolon.
        *   **Status:** Generally covered.

*   **Overall:** The documentation covers many uses of `del`. The main ambiguity lies in the `del a, b, c;` syntax relative to the grammar and how specific edge deletion syntaxes are parsed as the `expression` in `del expression`.

---

## Section 35: Control statements

*   **Grammar Rules from `jac.lark`:**
    ```lark
    ctrl_stmt: KW_SKIP | KW_BREAK | KW_CONTINUE
    // Used in statement rule as: ctrl_stmt SEMI
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/control_statements.md`
*   **Findings:**
    1.  **`KW_BREAK` (break statement):**
        *   **Grammar:** `KW_BREAK SEMI`.
        *   **Documentation:** Explains usage and provides examples.
        *   **Status:** Covered.

    2.  **`KW_CONTINUE` (continue statement):**
        *   **Grammar:** `KW_CONTINUE SEMI`.
        *   **Documentation:** Explains usage and provides examples.
        *   **Status:** Covered.

    3.  **`KW_SKIP` (skip statement):**
        *   **Grammar:** `KW_SKIP SEMI`. Listed as a general `ctrl_stmt`.
        *   **Documentation (`control_statements.md`):** States `skip` is a "Data spatial equivalent for walker traversal control (covered in walker statements documentation)" and does not detail it further in this file.
        *   **Issue/Clarification Needed:** If `KW_SKIP` is a general control statement (like `break`/`continue`), its documentation is missing here. If it's exclusively for walker contexts, its placement in the grammar under the general `ctrl_stmt` (rather than a more walker-specific rule) could be refined for clarity. The current documentation defers its explanation.

    4.  **Statement Termination (Semicolon):**
        *   **Grammar:** Requires `SEMI` for `ctrl_stmt`.
        *   **Documentation:** Examples for `break;` and `continue;` correctly include the semicolon.
        *   **Status:** Covered for `break` and `continue`.

*   **Overall:** `break` and `continue` are well-documented. The documentation for `skip` is deferred. The main point is ensuring its grammatical classification aligns with its intended scope of use (general control flow vs. walker-specific).

---

## Section 36: Data spatial Walker statements

*   **Grammar Rules from `jac.lark`:**
    ```lark
    spatial_stmt: visit_stmt | ignore_stmt | disenage_stmt // Likely typo for disengage_stmt
    // These are then defined as:
    // visit_stmt: KW_VISIT (COLON expression COLON)? expression (else_stmt | SEMI)
    // ignore_stmt: KW_IGNORE expression SEMI
    // disenage_stmt: KW_DISENGAGE SEMI // KW_DISENGAGE is "disengage"
    // spatial_stmt is a type of statement, implying it uses SEMI if not ending in a block.
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/data_spatial_walker_statements.md`
*   **Findings:**
    1.  **General Overview:** The document correctly introduces `visit`, `ignore`, and `disengage` as key walker control statements.

    2.  **`visit_stmt`:**
        *   **Grammar:** `KW_VISIT (COLON expression COLON)? expression (else_stmt | SEMI)`.
        *   **Documentation Syntax shows:**
            *   `visit expression;` (matches grammar: no filter, with `SEMI`).
            *   `visit :expression: expression;` (matches grammar: with filter, with `SEMI`).
            *   `visit expression else { ... }` (matches grammar: no filter, with `else_stmt`).
        *   **Missing Combination:** An example combining the edge filter and an `else` clause (e.g., `visit :filter_expr: target_expr else { ... };`) is not explicitly shown, though allowed by grammar.
        *   **Status:** Mostly covered. Semicolons should be explicit in syntax definitions.

    3.  **`ignore_stmt`:**
        *   **Grammar:** `KW_IGNORE expression SEMI`.
        *   **Documentation Syntax:** `ignore expression;` (semicolon is appropriate).
        *   **Status:** Covered.

    4.  **`disengage_stmt` (Grammar typo `disenage_stmt`):**
        *   **Grammar:** `disenage_stmt: KW_DISENGAGE SEMI`. Assuming `disenage_stmt` is a typo for `disengage_stmt`.
        *   **Documentation Syntax:** `disengage;` (semicolon is appropriate).
        *   **Keyword:** Documentation `disengage` matches `KW_DISENGAGE` token.
        *   **Status:** Covered (assuming grammar rule name typo is fixed).

    5.  **Statement Termination (Semicolon):**
        *   The individual grammar rules for `ignore_stmt` and `disengage_stmt` correctly include `SEMI`. `visit_stmt` can end in `SEMI` or an `else_stmt` (block).
        *   **Documentation:** Generally reflects this, though syntax summaries could be more explicit about semicolons for `ignore` and filtered `visit` if not ending in `else`.
        *   **Status:** Generally correct.

*   **Overall:** The documentation aligns well with the individual grammar rules for `visit`, `ignore`, and `disengage` (assuming the `disenage_stmt` typo correction). The purpose of these statements in walker control is clearly explained.

---

## Section 37: Visit statements

*   **Grammar Rule:** `visit_stmt: KW_VISIT (COLON expression COLON)? expression (else_stmt | SEMI)`
*   **Corresponding Markdown File:** `jac/examples/reference/visit_statements.md`
*   **Findings:**
    *   This statement was analyzed as part of **Section 36: Data spatial Walker statements**.
    *   The `visit_statements.md` file reiterates the common forms: `visit expression;` and `visit expression else { ... }`.
    *   It mentions edge filtering but does not prominently feature the `visit :filter_expr: target_expr;` syntax in its own syntax block, nor the combination of filtering with an `else` clause.
    *   **Overall:** The specific documentation is consistent with the broader points made in Section 36. The primary uncovered grammatical combination is `visit :filter: target else { ... };`.

---

## Section 38: Ignore statements

*   **Grammar Rule:** `ignore_stmt: KW_IGNORE expression SEMI`
*   **Corresponding Markdown File:** `jac/examples/reference/ignore_statements.md`
*   **Findings:**
    *   This statement was analyzed as part of **Section 36: Data spatial Walker statements**.
    *   The `ignore_statements.md` file is consistent with the grammar, showing `ignore expression;`.
    *   **Overall:** Consistent with Section 36 and the grammar.

---

## Section 39: Disengage statements

*   **Grammar Rule:** `disenage_stmt: KW_DISENGAGE SEMI` (Assuming `disenage_stmt` is a typo for `disengage_stmt`)
*   **Corresponding Markdown File:** `jac/examples/reference/disengage_statements.md`
*   **Findings:**
    *   This statement was analyzed as part of **Section 36: Data spatial Walker statements**.
    *   The `disengage_statements.md` file is consistent with the grammar (assuming typo fix), showing `disengage;`.
    *   **Overall:** Consistent with Section 36 and the grammar (with typo assumption).

---

## Section 40: Assignments

*   **Grammar Rules from `jac.lark`:**
    ```lark
    assignment: KW_LET? (atomic_chain EQ)+ (yield_expr | expression)  // Form 1
              | atomic_chain type_tag (EQ (yield_expr | expression))? // Form 2
              | atomic_chain aug_op (yield_expr | expression)          // Form 3

    aug_op: RSHIFT_EQ | LSHIFT_EQ | BW_NOT_EQ | BW_XOR_EQ | BW_OR_EQ | BW_AND_EQ | MOD_EQ | DIV_EQ | FLOOR_DIV_EQ | MUL_EQ | SUB_EQ | ADD_EQ | MATMUL_EQ | STAR_POW_EQ
    // Used in statement rule as: assignment SEMI
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/assignments.md`
*   **Findings:**
    1.  **Form 1 (Basic/Chained Assignment `[let] x = y = z = value`):**
        *   Basic assignment (`value = 42;`): Covered.
        *   Chained assignment (`x = y = z = 0;`): Covered.
        *   `let` with basic assignment (`let counter = 0;`): Covered.
        *   `let` with chained assignment (e.g., `let x = y = 0;`): Not explicitly shown, though grammatically allowed. Minor omission.

    2.  **Form 2 (Typed Assignment/Declaration `x: type [= value]`):**
        *   Typed assignment with initialization (`let count: int = 0;`): Covered.
        *   Typed declaration without immediate initialization (`let my_var: str;`): Not explicitly exemplified, though grammatically allowed by `(EQ ...)?`.
        *   **Issue:** Typed declaration without init is not shown.

    3.  **Form 3 (Augmented Assignment `x += value`):**
        *   **Documentation:** Covers Arithmetic, Bitwise, and Matrix augmented assignments with examples.
        *   **Status:** Well covered.

    4.  **`yield_expr` on RHS of Assignment:**
        *   **Grammar:** Allows `yield_expr` (e.g., `x = yield val;`).
        *   **Documentation:** Does not show examples of assigning `yield` or `yield from` expressions.
        *   **Issue:** Assignment of `yield_expr` is not documented.

    5.  **Destructuring Assignment:**
        *   **Documentation shows:** `let (x, y) = coordinates;` and `let (first, *rest) = items;`. These are standard and likely parsable by `atomic_chain` on LHS.
        *   **Documentation also shows:** `let (name=user, age=years) = user_data;`. This syntax for LHS destructuring is highly unconventional for assignment and resembles keyword argument patterns in calls or match cases. Its parsing via `atomic_chain` as an LHS target is unclear.
        *   **Issue/Inconsistency:** The `(name=user, age=years) = ...` destructuring syntax is problematic for assignment and needs clarification or correction in the documentation to align with typical LHS assignment capabilities or Jac-specific rules if it is indeed valid.

    6.  **Statement Termination (Semicolon):**
        *   **Grammar:** `assignment SEMI`.
        *   **Documentation:** Examples correctly include semicolons.
        *   **Status:** Covered.

*   **Overall:** Common assignments are well-documented. Areas for improvement include: `let` with chained assignment, typed declaration without init, assignment of `yield_expr`, and significant clarification/correction for the `(name=user, age=years)` destructuring assignment example.

---

## Section 41: Expressions (Top-Level Rule)

*   **Grammar Rules from `jac.lark`:**
    ```lark
    expression: concurrent_expr (KW_IF expression KW_ELSE expression)?
              | lambda_expr
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/expressions.md`
*   **Findings:**
    1.  **Conditional Expression (Ternary `... if ... else ...`):**
        *   **Grammar:** `concurrent_expr (KW_IF expression KW_ELSE expression)?`.
        *   **Documentation:** Lists and exemplifies conditional expressions (`result = value if condition else alternative;`).
        *   **Status:** Covered.

    2.  **Lambda Expression (`lambda_expr`):**
        *   **Grammar:** `lambda_expr` is an alternative for `expression`.
        *   **Documentation:** Mentions lambda expressions. The example syntax `lambda n: Node : n.is_active()` needs to be compared with the specific `lambda_expr` grammar rule and its documentation.
        *   **Status:** Mentioned; specific syntax example needs cross-verification.

    3.  **Delegation to `concurrent_expr` and Hierarchy:**
        *   **Grammar:** If not a conditional or lambda, an `expression` is a `concurrent_expr`, which then cascades to other expression types.
        *   **Documentation:** The "Expression Hierarchy" list correctly reflects this delegation to more specific expression forms.
        *   **Status:** Hierarchical nature outlined.

    4.  **Nature of `expressions.md` Document:**
        *   Provides a high-level overview, lists precedence categories, and gives basic examples. It defers detailed explanations of specific expression types to their own sections/documents.
        *   **Status:** Serves as a suitable introduction.

*   **Overall:** The `expressions.md` file correctly introduces the top-level structure of Jac expressions and the hierarchy. Detailed analysis of each expression type will follow in subsequent sections based on their specific grammar rules and documentation.

---

## Section 42: Concurrent expressions

*   **Grammar Rules from `jac.lark`:**
    ```lark
    concurrent_expr: (KW_FLOW | KW_WAIT)? walrus_assign
    // KW_FLOW: "flow"
    // KW_WAIT: "wait"
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/concurrent_expressions.md`
*   **Findings:**
    1.  **`KW_FLOW` modifier (`flow expression`):**
        *   **Grammar:** `KW_FLOW walrus_assign`.
        *   **Documentation:** Explains and shows `flow` used to initiate parallel execution of expressions (typically function calls or `spawn`).
        *   **Status:** Covered.

    2.  **`KW_WAIT` modifier (`wait expression` or `var = wait expression`):**
        *   **Grammar:** `KW_WAIT walrus_assign`.
        *   **Documentation:** Explains and shows `wait` used to synchronize and retrieve results from parallel operations/futures.
        *   **Status:** Covered.

    3.  **No modifier (plain `walrus_assign`):**
        *   **Grammar:** `concurrent_expr` defaults to `walrus_assign` if no keyword is present.
        *   **Documentation:** This is the standard non-concurrent expression path, implicitly covered as the base.
        *   **Status:** Implicitly covered.

    4.  **Nature of `walrus_assign` with `flow`/`wait`:**
        *   **Documentation:** Examples focus on applying `flow` and `wait` to operations like function calls, `spawn`, or variables holding task/future references, which are sensible uses.
        *   **Status:** Aligns with practical usage.

*   **Overall:** The documentation for `concurrent_expr`, particularly the `flow` and `wait` keywords, effectively explains their purpose and usage in enabling concurrency, and is consistent with the grammar.

---

## Section 43: Walrus assignments

*   **Grammar Rules from `jac.lark`:**
    ```lark
    walrus_assign: (named_ref WALRUS_EQ)? pipe
    // WALRUS_EQ: ":="
    // named_ref is typically a simple variable name.
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/walrus_assignments.md`
*   **Findings:**
    1.  **With `named_ref WALRUS_EQ` (e.g., `(name := expression)`):**
        *   **Grammar:** `named_ref WALRUS_EQ pipe`.
        *   **Documentation:** Clearly shows and explains usage like `if (count := len(items)) > 0 { ... }`.
        *   **Status:** Covered.

    2.  **Without `named_ref WALRUS_EQ` (plain `pipe` expression):**
        *   **Grammar:** `walrus_assign` defaults to `pipe` if `(named_ref WALRUS_EQ)?` is absent.
        *   **Documentation:** This is the standard expression path, implicitly covered as the base for walrus assignment.
        *   **Status:** Implicitly covered.

    3.  **`named_ref` as target:**
        *   **Grammar:** Target is `named_ref`.
        *   **Documentation:** Examples use simple variable names, which is typical.
        *   **Status:** Covered for typical usage.

    4.  **Scope of Walrus-Assigned Variable:**
        *   **Documentation:** Correctly states variables extend beyond the immediate expression scope, following standard scoping rules.
        *   **Status:** Behavior explained.

*   **Overall:** The documentation for walrus assignments (`:=`) is clear, consistent with the grammar, and accurately explains its common use cases and scoping rules.

---

## Section 44: Lambda expressions

*   **Grammar Rules from `jac.lark`:**
    ```lark
    lambda_expr: KW_LAMBDA func_decl_params? (RETURN_HINT expression)? COLON expression
    func_decl_params: (param_var COMMA)* param_var COMMA?
    param_var: (STAR_POW | STAR_MUL)? named_ref type_tag (EQ expression)?
    // type_tag: COLON expression (e.g., : int)
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/lambda_expressions.md`
*   **Findings:**
    1.  **Basic Syntax (`lambda params : expression`):**
        *   **Documentation:** Shows `lambda a: int, b: int : b + a;`. This aligns with the grammar where parameters require type annotations (`named_ref type_tag`).
        *   **Status:** Covered.

    2.  **Advanced Parameter Features (`func_decl_params?`):**
        *   **Grammar:** `func_decl_params?` (and `param_var` details) allow for:
            *   No parameters (e.g., `lambda : "value"`).
            *   `*args`, `**kwargs`.
            *   Default parameter values (e.g., `lambda x: int = 5 : x`).
        *   **Documentation (`lambda_expressions.md`):** Does not exemplify these variations for lambdas. It emphasizes mandatory type annotations for named parameters shown.
        *   **Issue:** Undocumented features for lambda parameters (no-params, *args/**kwargs, default values) if they are intended to be supported as per the shared `func_decl_params` rule.

    3.  **Explicit Return Type Annotation (`(RETURN_HINT expression)?`):**
        *   **Grammar:** Allows an optional explicit return type (e.g., `lambda x: int -> int : x * 2`).
        *   **Documentation (`lambda_expressions.md`):** States return types are inferred and does not show the syntax for explicit return type annotation on lambdas.
        *   **Issue:** Explicit return type annotation for lambdas is not documented.

    4.  **Lambda Body (Single `expression`):**
        *   **Grammar:** `COLON expression`.
        *   **Documentation:** Correctly states and shows that the lambda body is limited to a single expression.
        *   **Status:** Covered.

    5.  **Inconsistent Lambda Example in `expressions.md`:**
        *   The example `lambda n: Node : n.is_active()` from `expressions.md` uses a syntax (`param_name : param_type_name : body`) that is inconsistent with the `param_var` rule (`named_ref type_tag`, where `type_tag` is `: type_expr`) and the examples in `lambda_expressions.md` (which correctly show `lambda name: type : body`).
        *   **Issue:** The lambda example in `expressions.md` needs correction to align with the formal grammar and the dedicated lambda documentation.

*   **Overall:** `lambda_expressions.md` covers basic lambdas with typed parameters. However, it omits several parameter features and explicit return types that the grammar seems to permit. The example in `expressions.md` is also inconsistent.

---

## Section 45: Pipe expressions

*   **Grammar Rules from `jac.lark`:**
    ```lark
    pipe: (pipe PIPE_FWD)? pipe_back
    // PIPE_FWD: "|>"
    // pipe_back is the next level of precedence (or can involve PIPE_BKWD).
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/pipe_expressions.md`
*   **Findings:**
    1.  **Forward Pipe Operator `|>` (`PIPE_FWD`):**
        *   **Grammar:** `pipe PIPE_FWD pipe_back` (left-recursive structure).
        *   **Documentation:** Explains it passes the left expression's result as the first argument to the right expression. Numerous examples show chaining `expr |> func1 |> func2`.
        *   **Status:** Covered.

    2.  **Base of the Pipe (`pipe_back`):**
        *   **Grammar:** If no `PIPE_FWD` is used, `pipe` resolves to `pipe_back`.
        *   **Documentation:** The initial data/expression in a pipe chain, or expressions not using pipes, are implicitly this base case.
        *   **Status:** Implicitly covered.

    3.  **Associativity and Structure:**
        *   The grammar implies left-associativity for `|>` (e.g., `(a |> b) |> c`).
        *   **Documentation:** Examples and textual descriptions align with this left-to-right flow.
        *   **Status:** Consistent.

    4.  **Operands of `|>`:**
        *   **Documentation:** Shows piping into named functions, lambdas, and object methods.
        *   **Status:** Common use cases well demonstrated.

*   **Overall:** The documentation for the forward pipe operator `|>` is excellent, clearly explaining its syntax, semantics, and benefits with diverse examples. It aligns well with the grammar.

---

## Section 46: Pipe back expressions

*   **Grammar Rules from `jac.lark`:**
    ```lark
    pipe_back: (pipe_back PIPE_BKWD)? bitwise_or
    // PIPE_BKWD: "<|"
    // bitwise_or is the next level of precedence.
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/pipe_back_expressions.md`
*   **Findings:**
    1.  **Backward Pipe Operator `<|` (`PIPE_BKWD`):**
        *   **Grammar:** `pipe_back PIPE_BKWD bitwise_or` (left-recursive structure for the operator itself).
        *   **Documentation:** Explains it passes the right expression's result as an argument (conventionally the last) to the left expression/function. Examples show right-to-left data flow: `result = format <| process <| data;`.
        *   **Status:** Covered.

    2.  **Base of the Pipe Back (`bitwise_or`):**
        *   **Grammar:** If no `PIPE_BKWD` is used, `pipe_back` resolves to `bitwise_or`.
        *   **Documentation:** The rightmost data/expression in a `<|` chain is implicitly this base case.
        *   **Status:** Implicitly covered.

    3.  **Associativity and Data Flow:**
        *   The grammar implies left-associativity for the `<|` operator: `( (c <| b) <| a )`.
        *   The documented data flow is right-to-left, which is achieved by how the arguments are passed. This is consistent.
        *   **Status:** Consistent.

    4.  **Operands of `<|`:**
        *   **Documentation:** Examples show callables (functions/methods) on the left and data/results on the right.
        *   **Status:** Common use cases demonstrated.

    5.  **Combining with Forward Pipes `|>`:**
        *   **Documentation:** Shows examples of combining `<|` and `|>` using parentheses for grouping, e.g., `formatter <| (data |> clean |> transform)`.
        *   **Status:** Covered.

*   **Overall:** The documentation for the backward pipe operator `<|` effectively explains its syntax, right-to-left data flow semantics, and contrasts it with the forward pipe. It aligns well with the grammar.

---

## Section 47: Bitwise expressions

*   **Grammar Rules from `jac.lark`:**
    ```lark
    bitwise_or: (bitwise_or BW_OR)? bitwise_xor
    bitwise_xor: (bitwise_xor BW_XOR)? bitwise_and
    bitwise_and: (bitwise_and BW_AND)? shift
    shift: (shift (RSHIFT | LSHIFT))? logical_or // `logical_or` here is likely a placeholder for a higher precedence numerical term.
    // Unary BW_NOT is in `factor`: (BW_NOT | MINUS | PLUS) factor | connect
    // BW_OR: "|", BW_XOR: "^", BW_AND: "&", RSHIFT: ">>", LSHIFT: "<<", BW_NOT: "~"
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/bitwise_expressions.md`
*   **Findings:**
    1.  **Binary Bitwise Operators (`&`, `|`, `^`, `<<`, `>>`):**
        *   **Grammar:** Defines rules giving precedence: `shift` > `&` > `^` > `|`.
        *   **Documentation:** Covers all these operators with examples and correct precedence.
        *   **Status:** Covered and consistent.

    2.  **Unary Bitwise NOT (`~`):**
        *   **Grammar:** Defined in `factor` rule, giving it high precedence.
        *   **Documentation:** Covers `~` with an example and places it highest in bitwise precedence.
        *   **Status:** Covered and consistent.

    3.  **Operand for Shift Operators (Grammar's `logical_or`):**
        *   **Grammar:** `shift: (shift (RSHIFT | LSHIFT))? logical_or`.
        *   The use of `logical_or` as the operand for `shift` is unusual if it refers to the boolean logical OR operation, due to precedence. It likely refers to a higher-precedence term that evaluates to a number.
        *   **Documentation:** Examples use integer literals as operands for shifts (e.g., `5 << 1`), which is standard.
        *   **Issue (Potential Grammar Ambiguity/Typo):** The term `logical_or` in the `shift` rule definition in the provided grammar snippet is potentially misleading. Assuming it correctly resolves to a numerical operand in the full grammar, the documentation is fine.

*   **Overall:** The documentation accurately describes the standard bitwise operators and their precedence. The primary point of concern is the potentially misnamed `logical_or` rule in the `shift` production in the grammar, but the documented examples use typical numerical operands.

---

## Section 48: Logical and compare expressions

*   **Grammar Rules from `jac.lark`:**
    ```lark
    logical_or: logical_and (KW_OR logical_and)*
    logical_and: logical_not (KW_AND logical_not)*
    logical_not: NOT logical_not | compare
    compare: (arithmetic cmp_op)* arithmetic // For chained comparisons like a < b < c

    cmp_op: KW_ISN | KW_IS | KW_NIN | KW_IN | NE | GTE | LTE | GT | LT | EE
    // KW_OR: /\|\||or/, KW_AND: /&&|and/, NOT: "not"
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/logical_and_compare_expressions.md`
*   **Findings:**
    1.  **Logical OR (`or`, `||`):** Covered.
    2.  **Logical AND (`and`, `&&`):** Covered.
    3.  **Logical NOT (`not`):** Covered.

    4.  **Comparison Operators (`cmp_op`):**
        *   **Documentation lists:** `==`, `!=`, `<`, `<=`, `>`, `>=`, `is`, `in`.
        *   **Grammar also includes:** `KW_ISN` (is not) and `KW_NIN` (not in).
        *   **Issue:** `is not` and `not in` are not explicitly listed as comparison operators in the documentation's summary, though they are in the grammar.

    5.  **Chained Comparisons (e.g., `0 <= value <= 100`):**
        *   **Grammar:** `(arithmetic cmp_op)* arithmetic` supports this.
        *   **Documentation:** Explains and exemplifies chained comparisons.
        *   **Status:** Covered.

    6.  **Precedence:**
        *   Grammar implies standard precedence: `compare` > `NOT` > `AND` > `OR`.
        *   **Documentation:** Does not explicitly state precedence but examples are consistent.
        *   **Status (Minor):** Explicit precedence table could be useful.

    7.  **Short-Circuit Evaluation:**
        *   **Documentation:** Correctly explains for `and` and `or`.
        *   **Status:** Behavior explained.

*   **Overall:** The documentation covers most logical and comparison operations well. The main omission is the explicit listing of `is not` and `not in` in the comparison operator summary.

---

## Section 49: Arithmetic expressions

*   **Grammar Rules from `jac.lark`:**
    ```lark
    arithmetic: (arithmetic (MINUS | PLUS))? term
    term: (term (MOD | DIV | FLOOR_DIV | STAR_MUL | DECOR_OP))? power
    power: (power STAR_POW)? factor
    factor: (BW_NOT | MINUS | PLUS) factor | connect
    // DECOR_OP is "@"
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/arithmetic_expressions.md`
*   **Findings:**
    1.  **Binary Arithmetic Operators (`+`, `-`, `*`, `/`, `//`, `%`, `**`):**
        *   **Grammar:** Defines these with standard precedence: `**` > (`*`,`/`,`//`,`%`,`@`) > (`+`,`-`).
        *   **Documentation:** Covers all these (except `@`) with correct relative precedence.
        *   **Status:** Covered (except for `@`).

    2.  **Unary Plus/Minus (`+x`, `-x`):**
        *   **Grammar (`factor` rule):** Places unary `+`/`-` (and `~`) at a very high precedence, effectively making them part of the `factor` before `power` (`**`) is applied.
        *   **Documentation:** States unary `+`/`-` have precedence *below* `**` but above `*`/`/`.
        *   **Issue/Inconsistency:** Discrepancy in precedence of unary `+`/`-` relative to `**`. Grammar implies `(-2)**4`, documentation implies `-(2**4)`. Standard behavior is usually `-(2**4)`.

    3.  **`DECOR_OP` (`@`) - Matrix Multiplication:**
        *   **Grammar:** Includes `DECOR_OP` (`@`) in the `term` rule, at same precedence as `*`, `/`.
        *   **Documentation (`arithmetic_expressions.md`):** Does not list or exemplify the `@` operator.
        *   **Issue:** The `@` (matrix multiplication) operator is not documented in this file.

    4.  **Parentheses for Grouping:**
        *   **Documentation:** Correctly states parentheses have the highest precedence and can be used to override defaults.
        *   **Status:** Covered.

*   **Overall:** Common binary arithmetic operators are well-documented. Key issues are the precedence of unary minus/plus with respect to exponentiation, and the omission of the `@` (matrix multiplication) operator from the documentation.

---

## Section 50: Connect expressions

*   **Grammar Rules from `jac.lark`:**
    ```lark
    connect: (connect (connect_op | disconnect_op))? atomic_pipe
    connect_op: connect_from | connect_to | connect_any // Uses CARROW variants like ++>, +>:, etc.
    disconnect_op: KW_DELETE edge_op_ref // Uses ARROW variants like -->, <-:, etc.
    // atomic_pipe is the operand.
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/connect_expressions.md`
*   **Findings:**
    1.  **Basic Connection (`source ++> destination`):**
        *   **Grammar:** `atomic_pipe connect_op atomic_pipe` (where `connect_op` is `connect_to` using `CARROW_R`).
        *   **Documentation:** Covers simple connections like `source ++> destination`.
        *   **Status:** Covered.

    2.  **Typed/Property Connections (`source +>:Type:prop=val:+> dest`):**
        *   **Grammar:** Uses detailed forms of `connect_op` (e.g., `CARROW_R_P1 expression (COLON kw_expr_list)? CARROW_R_P2`).
        *   **Documentation:** Explains and exemplifies creating typed edges with properties.
        *   **Status:** Covered.

    3.  **Directionality of Connections (`++>`, `<++`, `<++>`):**
        *   **Grammar:** Handled by `connect_to`, `connect_from`, `connect_any` using `CARROW_R`, `CARROW_L`, `CARROW_BI`.
        *   **Documentation:** Lists these directionalities.
        *   **Status:** Covered.

    4.  **`disconnect_op` (`KW_DELETE edge_op_ref`) within `connect` expressions:**
        *   **Grammar:** `disconnect_op` is an alternative to `connect_op` in the `connect` rule, suggesting expressions like `node1 ++> node2 del node2 --> node3` might be possible if `connect` expressions can be chained and have results.
        *   **Documentation (`connect_expressions.md`):** Focuses on creating connections. Does not cover `disconnect_op` or using `del` with edge syntax as part of a connect *expression*.
        *   **Documentation (`delete_statements.md`):** Covers `del <edge_spec>;` as a standalone statement.
        *   **Issue/Clarification Needed:** The role and behavior of `disconnect_op` as part of the `connect` expression rule is undocumented and potentially confusing given `del` for edges is also a standalone statement. It's unclear how an expression like `KW_DELETE edge_op_ref` would evaluate or chain within a `connect` expression sequence.

    5.  **Chaining of Connect/Disconnect Operations:**
        *   **Grammar:** `connect: (connect (connect_op | disconnect_op))? atomic_pipe` implies left-associative chaining.
        *   **Documentation:** Shows sequential construction of chains (e.g., in loops) rather than single complex chained expressions involving multiple different operators.
        *   **Status:** Basic connection chaining is implicitly shown; complex mixed chains are not detailed.

*   **Overall:** Documentation for creating connections (`connect_op`) is thorough. The `disconnect_op` part of the `connect` expression grammar is not covered in this file and its interaction as an expression component versus a standalone delete statement needs clarification.

---

## Section 51: Atomic expressions (Atomic Pipe Forward :>)

*   **Grammar Rules from `jac.lark`:**
    ```lark
    // The heading is "Atomic expressions", but the rule immediately following is atomic_pipe.
    atomic_pipe: (atomic_pipe A_PIPE_FWD)? atomic_pipe_back
    // A_PIPE_FWD: ":>"
    // atomic_pipe_back is the next level of precedence.
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/atomic_expressions.md`
*   **Findings:**
    1.  **Atomic Pipe Forward Operator `:>` (`A_PIPE_FWD`):**
        *   **Grammar:** `atomic_pipe A_PIPE_FWD atomic_pipe_back` (left-recursive structure).
        *   **Documentation:** Explains and shows the `:>` operator for chaining operations, e.g., `"Hello world!" :> print;`. The semantics (passing LHS as argument to RHS callable) are similar to `|>`.
        *   **Status:** Covered.

    2.  **Base of the Atomic Pipe (`atomic_pipe_back`):**
        *   **Grammar:** `atomic_pipe` resolves to `atomic_pipe_back` if no `:>` is used.
        *   **Documentation:** Initial elements in a `:>` chain are implicitly this base.
        *   **Status:** Implicitly covered.

    3.  **Associativity:**
        *   Grammar implies left-associativity for `:>`.
        *   **Documentation:** Examples like `"Welcome" :> type :> print;` are consistent.
        *   **Status:** Consistent.

    4.  **Documentation Scope vs. Title ("Atomic expressions")**:
        *   **Documentation File Title:** `atomic_expressions.md`.
        *   **Content:** Primarily describes the `atomic_pipe` (`:>`) operator.
        *   **Grammar:** The true "atomic" units (literals, names, `(...)`) are defined under the `atom` rule much later in the grammar. The heading "Atomic expressions" in `jac.lark` is immediately followed by the `atomic_pipe` rule, not rules for literals/variables directly.
        *   **Issue (Documentation Scope/Naming):** The file `atomic_expressions.md` documents the `:>` operator. The general intro in the doc about "fundamental and indivisible units ... literals, identifiers" better describes what the grammar calls `atom`. This file focuses on a specific pipe operator rather than the broad category of all atomic/primary expressions.

*   **Overall:** The `:>` operator (atomic pipe forward) is well-documented and aligns with its grammar rule (`atomic_pipe`). The main point of note is that the documentation file titled "Atomic expressions" describes this specific pipe operator, not the broader category of fundamental atoms like literals or variable names, which appear under a different grammar heading ("Atom").

---

## Section 52: Atomic pipe back expressions

*   **Grammar Rules from `jac.lark`:**
    ```lark
    atomic_pipe_back: (atomic_pipe_back A_PIPE_BKWD)? ds_spawn
    // A_PIPE_BKWD: "<:"
    // ds_spawn is the next level of precedence.
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/atomic_pipe_back_expressions.md`
*   **Findings:**
    1.  **Atomic Pipe Back Operator `<:` (`A_PIPE_BKWD`):**
        *   **Grammar:** `atomic_pipe_back A_PIPE_BKWD ds_spawn` (left-recursive structure for the operator).
        *   **Documentation:** Explains it passes the RHS data as an argument to the LHS callable, with right-to-left data flow (e.g., `print <: "Hello world!";`).
        *   **Status:** Covered.

    2.  **Base of the Atomic Pipe Back (`ds_spawn`):**
        *   **Grammar:** `atomic_pipe_back` resolves to `ds_spawn` if no `<:` is used.
        *   **Documentation:** The rightmost data/expression in a `<:` chain is implicitly this base.
        *   **Status:** Implicitly covered.

    3.  **Associativity and Data Flow:**
        *   Grammar implies left-associativity for the `<:` operator: `(func2 <: func1) <: data`.
        *   Documented data flow is right-to-left, which is consistent with evaluation order.
        *   **Status:** Consistent.

    4.  **Combining with Atomic Pipe Forward (`:>`):**
        *   **Documentation:** Shows examples like `len <: a + b :> len;` and `result = function1 <: data :> function2;`.
        *   The grammar `atomic_pipe: ... atomic_pipe_back` and `atomic_pipe_back: ... ds_spawn` implies `<:` (in `atomic_pipe_back`) binds tighter than `:>` (in `atomic_pipe`). This precedence is consistent with how the examples are likely intended to be parsed.
        *   **Status:** Covered and consistent with grammar precedence.

*   **Overall:** The documentation for the atomic pipe back operator `<:` clearly explains its syntax and right-to-left data flow, and its interaction with the atomic pipe forward operator. It aligns well with the grammar.

---

## Section 53: Data spatial spawn expressions

*   **Grammar Rules from `jac.lark`:**
    ```lark
    ds_spawn: (ds_spawn KW_SPAWN)? unpack
    // KW_SPAWN: "spawn"
    // unpack is the next level of precedence.
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/data_spatial_spawn_expressions.md`
*   **Findings:**
    1.  **`KW_SPAWN` Operator:**
        *   **Grammar:** `ds_spawn KW_SPAWN unpack` (left-recursive structure for the operator).
        *   **Documentation:** Explains `spawn` for activating walkers. Shows both `walker_instance spawn location;` and `location spawn walker_instance;`, stating they achieve the same result. This is consistent with `KW_SPAWN` as a binary operator.
        *   **Status:** Covered.

    2.  **Base of Spawn (`unpack`):**
        *   **Grammar:** `ds_spawn` resolves to `unpack` if no `KW_SPAWN` is used.
        *   **Documentation:** Operands of `spawn` (walker instances, locations) are implicitly `unpack` expressions.
        *   **Status:** Implicitly covered.

    3.  **Chaining `spawn` Operations:**
        *   **Grammar:** The left-recursive structure `(ds_spawn KW_SPAWN)? unpack` allows for chaining (e.g., `a spawn b spawn c`).
        *   **Documentation:** Does not show examples of chaining multiple `spawn` keywords in a single expression. It shows multiple separate spawn statements.
        *   **Clarification Needed:** The semantic meaning of a chained spawn expression like `(walker1 spawn node1) spawn walker2` is not obvious or documented. While grammatically parsable, its practical use is unclear. The `spawn` operation primarily has side effects, and its direct result (if any as an expression) is usually related to collecting reports, not further spawning.

*   **Overall:** The documentation effectively explains the `spawn` operation for activating walkers with either operand order (walker or location first), which aligns with the grammar. The practical application of chained `spawn` operators within a single expression remains undocumented and unclear.

---

## Section 54: Unpack expressions

*   **Grammar Rules from `jac.lark`:**
    ```lark
    unpack: STAR_MUL? ref
    // STAR_MUL is "*"
    // ref is the next level of precedence.
    // This rule specifically covers *iterable unpacking.
    // **mapping unpacking is handled by other rules (e.g., kw_expr, kv_pair using STAR_POW).
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/unpack_expressions.md`
*   **Findings:**
    1.  **Iterable Unpacking (`*iterable`):**
        *   **Grammar:** `unpack: STAR_MUL? ref` correctly defines `*ref`.
        *   **Documentation:** Explains and shows examples like `[*items]` or `func(*args)`.
        *   **Status:** Covered and consistent with the grammar rule.

    2.  **Mapping Unpacking (`**mapping`):**
        *   **Documentation (`unpack_expressions.md`):** Describes and exemplifies mapping unpacking using `**` (e.g., `{**dict1, **dict2}` or `func(**kwargs)`).
        *   **Grammar (`unpack` rule):** The rule `unpack: STAR_MUL? ref` does **not** include syntax for `**` (mapping unpacking). Mapping unpacking with `STAR_POW` is defined in other specific grammar rules: `kw_expr` (for function call keyword arguments) and `kv_pair` (for dictionary literals).
        *   **Issue (Major Documentation/Grammar Rule Mismatch):** The documentation file `unpack_expressions.md` is titled broadly and includes `**` mapping unpacking. However, the specific grammar rule `unpack` presented under the same heading in `jac.lark` only covers `*` iterable unpacking. This creates a mismatch: the doc is broader than this particular rule.
        *   **Clarification:** The documentation should clarify that while `*` is handled by the `unpack` expression rule (which then becomes part of general expressions), `**` unpacking occurs in specific contexts like dictionary literals and function call arguments, governed by different grammar rules (`kv_pair`, `kw_expr`).

    3.  **Base of Unpack (`ref`):**
        *   **Grammar:** If `STAR_MUL?` is absent, `unpack` is `ref`.
        *   **Documentation:** Operands of `*` are `ref` expressions. This is implicit.
        *   **Status:** Implicitly covered.

*   **Overall:** The grammar rule `unpack: STAR_MUL? ref` correctly defines `*iterable` unpacking. The documentation file `unpack_expressions.md` accurately describes `*iterable` unpacking. However, this documentation also covers `**mapping` unpacking, which is grammatically handled by different rules (`kv_pair`, `kw_expr`) using `STAR_POW`, not by this specific `unpack` rule. This makes the scope of the `unpack` rule versus the `unpack_expressions.md` document inconsistent regarding `**`.

---

## Section 55: References (unused)

*   **Grammar Rules from `jac.lark`:**
    ```lark
    ref: BW_AND? pipe_call
    // BW_AND is "&"
    // pipe_call is the next level of precedence.
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/references_(unused).md`
*   **Findings:**
    1.  **`ref` Rule and `BW_AND` (`&`) Operator:**
        *   **Grammar:** Defines `ref` as an optional `&` followed by a `pipe_call`.
        *   **Documentation:** Explicitly states that this `ref` rule, particularly the `&` operator for creating references (e.g., `&value`), is **"currently defined but not actively utilized in the language implementation"** and is **"unused"**.
        *   **Status:** This is a direct statement about a non-operational grammar feature. This is not an inconsistency but important documentation of the language's current state.

    2.  **Passthrough to `pipe_call`:**
        *   **Grammar:** If the optional `BW_AND?` is not used, `ref` simply becomes `pipe_call`.
        *   **Documentation:** States, "Current implementation uses `pipe_call` directly."
        *   **Status:** Consistent with the `&` part being unused. In the expression hierarchy, `ref` effectively serves as a direct link to `pipe_call`.

*   **Overall:** The documentation clearly indicates that the `&` (address-of/reference) operator, though defined in the `ref` grammar rule, is an unused feature in the current Jac language. This is a crucial piece of information for understanding the effective grammar.

---

## Section 56: Data spatial calls

*   **Grammar Rules from `jac.lark`:**
    ```lark
    pipe_call: (PIPE_FWD | A_PIPE_FWD | KW_SPAWN | KW_AWAIT)? atomic_chain
    // PIPE_FWD: "|>", A_PIPE_FWD: ":>", KW_SPAWN: "spawn", KW_AWAIT: "await"
    // atomic_chain is the next level of precedence (function calls, attribute access, etc.)
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/data_spatial_calls.md`
*   **Findings:**
    This `pipe_call` grammar rule presents significant inconsistencies with how `|>` (pipe fwd), `:>` (atomic pipe fwd), and `spawn` are defined and used elsewhere in the grammar and documentation.

    1.  **Unary Prefix Interpretation vs. Binary Operator Nature:**
        *   **`pipe_call` Grammar:** Suggests `|>` `atomic_chain`, `:>` `atomic_chain`, and `spawn` `atomic_chain` are valid (treating them as optional unary prefixes).
        *   **Contradictory Grammar Rules:**
            *   `pipe: (pipe PIPE_FWD)? pipe_back` (defines `|>` as binary).
            *   `atomic_pipe: (atomic_pipe A_PIPE_FWD)? atomic_pipe_back` (defines `:>` as binary).
            *   `ds_spawn: (ds_spawn KW_SPAWN)? unpack` (defines `spawn` as binary).
        *   **Documentation (`data_spatial_calls.md` and others):** Consistently shows `|>` , `:>`, and `spawn` used as binary operators (e.g., `data |> func`, `walker spawn node`).
        *   **Issue (Major Grammar Inconsistency):** The `pipe_call` rule treating `|>` , `:>`, and `spawn` as optional unary prefixes is fundamentally inconsistent with their established binary operator nature in other parts of the grammar and all documentation examples.

    2.  **`KW_AWAIT` (`await`):**
        *   **`pipe_call` Grammar:** `(KW_AWAIT)? atomic_chain` is plausible, as `await` is a unary prefix operator.
        *   **Documentation:** Standard `await expression` usage is documented elsewhere (e.g., `functions_and_abilities.md`). `data_spatial_calls.md` mentions `await` for synchronization but provides no specific syntax example itself for this rule.
        *   **Status for `await`:** The `await atomic_chain` part aligns with `await` being unary. This is the only part of the optional prefixes in `pipe_call` that seems grammatically sound in isolation.

    3.  **`atomic_chain` as the base:**
        *   If no prefix is used, `pipe_call` resolves to `atomic_chain`. This is standard.
        *   **Status:** Base case is fine.

*   **Overall (Major Issues with `pipe_call` rule):**
    *   The `pipe_call` grammar rule, as written, is largely incorrect or misleading for `PIPE_FWD`, `A_PIPE_FWD`, and `KW_SPAWN` by suggesting they can be unary prefixes to `atomic_chain`.
    *   This rule seems to be in conflict with the primary definitions and documented usage of these operators.
    *   The `KW_AWAIT` prefix is the only one that aligns with standard operator behavior (unary prefix).
    *   The documentation in `data_spatial_calls.md` itself describes `|>` and `spawn` in their correct binary operator sense, further highlighting the problem with the `pipe_call` grammar rule.
    *   This rule likely needs significant revision or clarification on its intended purpose, as it does not reflect the actual usage of these operators.

---

## Section 57: Subscripted and dotted expressions (atomic_chain)

*   **Grammar Rules from `jac.lark`:**
    ```lark
    atomic_chain: atomic_chain NULL_OK? (filter_compr | assign_compr | index_slice) // Form 1: obj?[...] or obj?(filter/assign)
                | atomic_chain NULL_OK? (DOT_BKWD | DOT_FWD | DOT) named_ref      // Form 2: obj?.attr, obj?.<attr, obj?.>attr
                | (atomic_call | atom | edge_ref_chain)                            // Form 3: Base cases (call, primary, edge_ref)
    // NULL_OK: "?", DOT: ".", DOT_BKWD: "<.", DOT_FWD: ".>"
    // index_slice involves [...] for indexing/slicing.
    // filter_compr and assign_compr are specific (...) forms.
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/subscripted_and_dotted_expressions.md`
*   **Findings:**
    1.  **Dotted Expressions (Attribute Access - Form 2):**
        *   **Standard Dot (`.`):** Covered, including null-safe `?.` (e.g., `car.model`, `user?.address`).
        *   **Directional Dots (`.>`, `.<`):** Mentioned for forward/backward piping attribute access, but not deeply exemplified in this document.
        *   **Status:** Standard dot access well covered. Directional dots mentioned.

    2.  **Subscripted Expressions (`index_slice` - Form 1 part):**
        *   **Grammar:** `atomic_chain NULL_OK? index_slice`. `index_slice` includes `LSQUARE ... RSQUARE` for indexing/slicing and also `list_val`.
        *   **Documentation:** Covers standard indexing (`letters[0]`) and slicing (`letters[1:3]`, `letters[::2]`) well, including null-safe `?.[]`.
        *   The `list_val` alternative within `index_slice` (e.g., potentially for `obj[[1,2]]` style indexing) is not documented.
        *   **Issue (Minor):** `list_val` as an `index_slice` form is not covered.
        *   **Status:** Standard indexing/slicing well covered.

    3.  **Special Comprehensions (`filter_compr`, `assign_compr` - Form 1 part):**
        *   **Grammar:** `atomic_chain NULL_OK? (filter_compr | assign_compr)`. These are `(...)` forms distinct from function calls.
        *   **Documentation (`subscripted_and_dotted_expressions.md`):** Does not cover these. They are expected to be documented under the "Special Comprehensions" grammar heading.
        *   **Status:** Not covered in this document (deferred).

    4.  **Base Cases (Form 3 - `atomic_call | atom | edge_ref_chain`):**
        *   These are the starting points of an `atomic_chain` (e.g., a function call, a literal, a variable name, an edge reference).
        *   **Documentation:** This document focuses on the chaining operators (`.` `[]`) rather than exhaustively detailing the base forms, which have their own grammar sections/documentation.
        *   **Status:** Implicitly handled as the operands for dot/subscript operations.

*   **Overall:** This document effectively covers standard attribute access and list/dictionary subscripting, including their null-safe versions. Directional dot operators are mentioned. The special `filter_compr` and `assign_compr` syntaxes, and the `list_val` form of `index_slice`, are not covered here.

---

## Section 58: Index slice (details of the rule)

*   **Grammar Rule from `jac.lark`:**
    ```lark
    index_slice: LSQUARE                                                             \
                         expression? COLON expression? (COLON expression?)?          \
                         (COMMA expression? COLON expression? (COLON expression?)?)* \
                  RSQUARE
               | list_val
    // list_val is a list literal, e.g., [a, b, c]
    ```
*   **Corresponding Markdown File:** No dedicated file. Discussed under `subscripted_and_dotted_expressions.md`.
*   **Findings (Detailed analysis of the `index_slice` rule):**
    1.  **Basic Indexing and Slicing (Single component):**
        *   The grammar `expression? COLON expression? (COLON expression?)?` supports forms like `[index]`, `[start:stop]`, `[:stop]`, `[start:]`, `[start:stop:step]`, `[::step]`, `[:]`.
        *   **Documentation (`subscripted_and_dotted_expressions.md`):** Covers these 1D indexing and slicing forms well with examples.
        *   **Status:** Covered.

    2.  **Comma-Separated Multi-Dimensional Indexing/Slicing:**
        *   The grammar part `(COMMA expression? COLON expression? (COLON expression?)?)*` allows for multiple comma-separated index/slice components within a single `[]` pair (e.g., `matrix[row_idx, col_idx]`, `tensor[slice1, slice2, index3]`).
        *   **Documentation (`subscripted_and_dotted_expressions.md`):** Does not show or discuss this multi-dimensional access syntax using commas within a single `[]`.
        *   **Issue:** Comma-separated multi-dimensional indexing/slicing is a significant capability of the `index_slice` grammar rule that is not documented.

    3.  **`list_val` as an Index (Fancy Indexing):**
        *   **Grammar:** `index_slice: ... | list_val`. Allows a list literal (e.g., `[idx1, idx2]`) to be used as the index itself, e.g., `data[[idx1, idx2, idx3]]`.
        *   **Documentation (`subscripted_and_dotted_expressions.md`):** Does not show or discuss using a list literal directly within the square brackets for indexing (often called "fancy indexing" or "advanced indexing").
        *   **Issue:** The `list_val` alternative for `index_slice`, enabling list-based fancy indexing, is not documented.

*   **Overall:** While basic 1D indexing and slicing are documented, the `index_slice` grammar rule supports more advanced features like comma-separated multi-dimensional access and list-based fancy indexing, which are currently not covered in the documentation.

---

## Section 59: Function calls (atomic_call)

*   **Grammar Rules from `jac.lark`:**
    ```lark
    atomic_call: atomic_chain LPAREN param_list? (KW_BY atomic_call)? RPAREN

    param_list: expr_list COMMA kw_expr_list COMMA?  // Positional, then keyword
              | kw_expr_list COMMA?                  // Only keyword
              | expr_list COMMA?                     // Only positional

    expr_list: (expr_list COMMA)? expression
    kw_expr_list: (kw_expr_list COMMA)? kw_expr
    kw_expr: named_ref EQ expression | STAR_POW expression // kw=val or **kwargs
    // `expression` in `expr_list` can be `unpack` for *args.
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/function_calls.md`
*   **Findings:**
    1.  **Basic Syntax and Callables (`atomic_chain(...)`):**
        *   Covers calls to simple functions, methods (`obj.method()`), and chained calls (`obj.meth1().meth2()`).
        *   **Status:** Covered.

    2.  **Parameter Lists (`param_list?`):**
        *   **Positional Arguments (`expr_list`):** Documented, including `*args` unpacking (though `*args` example often cited from `unpack_expressions.md`).
        *   **Keyword Arguments (`kw_expr_list`):** Documented (`name=value`), including `**kwargs` unpacking (example often from `unpack_expressions.md`).
        *   **Mixed Arguments:** Documented.
        *   **Trailing Commas:** Grammar allows optional trailing commas in `param_list` variants. Not explicitly shown in documentation examples.
        *   **Issue (Minor):** Optional trailing commas in argument lists are not explicitly documented.
        *   **Status:** Argument types (positional, keyword, *args, **kwargs) well covered.

    3.  **`KW_BY atomic_call` Suffix:**
        *   **Grammar:** `atomic_call` can end with `(KW_BY atomic_call)? RPAREN`. This suggests a syntax like `func1(args) by func2(other_args)`.
        *   **Documentation (`function_calls.md`):** Does not document or exemplify this `by <another_call>` feature within a function call.
        *   **Issue:** The `KW_BY atomic_call` part of the function call syntax is not documented. Its purpose and semantics in this context are unknown from the docs.

*   **Overall:** Standard function call mechanisms are thoroughly documented. The main omissions are the optional trailing comma in argument lists and the entire `KW_BY atomic_call` feature, which was also seen undocumented in `block_tail` for function/ability definitions.

---

## Section 60: Atom

*   **Grammar Rules from `jac.lark`:**
    ```lark
    atom: named_ref
        | LPAREN (expression | yield_expr) RPAREN  // Parenthesized expr/yield
        | atom_collection                           // List, dict, set, tuple literals/compr
        | atom_literal                              // Numeric, string, bool, null, ellipsis literals
        | type_ref                                  // `type_name or `builtin_type

    atom_literal: builtin_type | NULL | BOOL | multistring | ELLIPSIS | FLOAT | OCT | BIN | HEX | INT
    type_ref: TYPE_OP (named_ref | builtin_type) // TYPE_OP is "`"
    // multistring includes fstring and STRING.
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/atom.md`
*   **Findings:**
    1.  **`named_ref` (Identifiers):** Covered.
    2.  **Parenthesized Expressions:** Covered.
    3.  **`atom_collection` (Collection Literals - basic):** Basic list/tuple literals mentioned. Full scope deferred.
        *   **Status:** Partially covered (overview).
    4.  **`atom_literal` (Literals - This has several issues in the doc):**
        *   **String literals & F-strings (`multistring`):** Covered.
        *   **Boolean literals (`BOOL`):** Covered (`True`, `False`).
        *   **Numeric literals (`INT`, `FLOAT`, `HEX`, `BIN`, `OCT`):**
            *   **Documentation Error:** `atom.md` shows `bin(12)` and `hex(78)` (function calls) for binary/hex literals instead of the correct literal syntax (e.g., `0b1100`, `0x4E`).
            *   Decimal `INT` and `FLOAT` are mentioned generally but not with specific syntax examples in this section.
            *   `OCT` (octal literals, e.g., `0o...`) not explicitly shown.
            *   **Issue:** Major errors and omissions in documenting numeric literal syntax.
        *   **`NULL` (None):** Not explicitly listed as a literal in `atom.md`'s literal section, though it's part of `atom_literal` grammar. (Covered elsewhere under singleton patterns).
        *   **`ELLIPSIS` (`...`):** Not mentioned in `atom.md`, though part of `atom_literal` grammar.
            *   **Issue:** `ELLIPSIS` literal missing.
        *   **`builtin_type` (e.g., `int`, `str` as values):** Part of `atom_literal` grammar but not clearly explained as a literal value an atom can be in `atom.md`.
            *   **Issue:** `builtin_type` as a literal value unclear.

    5.  **`type_ref` (`` `type ``):**
        *   **Grammar:** `atom: type_ref`.
        *   **Documentation:** Mentions "Type References ... using the backtick operator (`)", but provides no concrete example (e.g., `` `MyType` `` or `` `int` ``).
        *   **Issue (Minor):** Lacks an explicit example.

    6.  **Misplaced Complex Examples in `atom.md`:**
        *   The document includes examples of string concatenation (`"a" + f"b"`) and chained attribute access (`x.y.value`), which are compound expressions (e.g., `arithmetic`, `atomic_chain`), not just `atom`s. This can be confusing for a document titled "Atom".
        *   **Issue:** Document scope seems to exceed the strict definition of an `atom`.

*   **Overall:** `atom.md` correctly identifies some atomic elements like names, parenthesized expressions, and basic collections. However, its coverage of `atom_literal` is poor, with incorrect syntax for some numeric literals and omission of others like `ELLIPSIS`. The document also mixes in examples of more complex expressions, blurring the definition of an "atom".

---

## Section 61: Multistring and F-string definitions (within atom_literal)

*   **Grammar Rules from `jac.lark`:**
    ```lark
    multistring: (fstring | STRING)+

    fstring: FSTR_START fstr_parts FSTR_END
           | FSTR_SQ_START fstr_sq_parts FSTR_SQ_END

    fstr_parts: (FSTR_PIECE | FSTR_BESC | LBRACE expression RBRACE )*
    fstr_sq_parts: (FSTR_SQ_PIECE | FSTR_BESC | LBRACE expression RBRACE )*

    // STRING terminal: covers '...', "...", '''...''', """...""", with r/b prefixes.
    // FSTR_START/END etc. are for f"..." and f'...' parts.
    ```
*   **Corresponding Markdown File:** No dedicated file. Mentioned in `atom.md`.
*   **Findings:**
    1.  **`STRING` (Regular String Literals):**
        *   **Grammar:** The `STRING` terminal supports various quoting and prefix styles.
        *   **Documentation (`atom.md`):** Shows basic double-quoted strings. Does not detail triple quotes or `r`/`b` prefixes, but these are standard Python features usually assumed.
        *   **Status:** Basic strings covered; advanced forms assumed standard.

    2.  **`fstring` (Formatted String Literals):**
        *   **Grammar:** Defines `f"..."` and `f'...'` with embedded expressions `{expression}`.
        *   **Documentation (`atom.md`):** Mentions f-strings and shows a simple example: `f"b{aa}bbcc"`.
        *   The full power of embedded `expression`s or format specifiers (e.g., `{val:.2f}`) is not detailed in `atom.md` but often inherited from Python f-string behavior.
        *   **Status:** Basic f-strings covered.

    3.  **`multistring: (fstring | STRING)+` (Implicit Concatenation):**
        *   **Grammar:** This rule allows implicit concatenation of adjacent string or f-string literals (e.g., `"abc" "def"` or `f"a" "b"`).
        *   **Documentation (`atom.md`):** Does not document this implicit concatenation feature. It shows explicit concatenation using the `+` operator (`"aaa" + f"b{aa}bbcc"`), which is an arithmetic expression, not an atomic `multistring` literal itself.
        *   **Issue:** Implicit string/f-string literal concatenation via adjacency, as defined by `multistring`, is not documented.

*   **Overall:** `atom.md` covers the existence of basic string literals and f-strings. The implicit concatenation feature of `multistring` is a notable omission from the documentation. Full details of `STRING` prefixes/quoting and f-string capabilities are also not in `atom.md` but are often standard language assumptions.

---

## Section 62: Collection values (atom_collection)

*   **Grammar Rules from `jac.lark` (overview):**
    ```lark
    atom_collection: dict_compr | set_compr | gen_compr | list_compr
                   | dict_val | set_val | tuple_val | list_val

    // Comprehensions generally: TARGET_EXPR (KW_ASYNC? KW_FOR ... KW_IN ... (KW_IF ...)*)+
    // Literals generally: BRACKET (elements COMMA?)? BRACKET_END
    // dict_compr: LBRACE kv_pair inner_compr+ RBRACE // Grammar has RSQUARE, likely typo
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/collection_values.md`
*   **Findings:**
    **Literal Collections (`dict_val`, `set_val`, `tuple_val`, `list_val`):**
    1.  **Dictionary Literal (`dict_val`):** Doc shows `{"a": "b"}`. Grammar allows empty `{}`, unpacking `**expr`, and trailing comma; these aren't shown in this specific doc.
        *   **Status:** Basic covered.
    2.  **Set Literal (`set_val`):** Doc shows `{"a"}`. Grammar `LBRACE expr_list COMMA? RBRACE` doesn't easily make empty set `{}` (that's dict) or distinguish `{"a"}` from a dict without parser context. Python uses `set()` for empty. Single item sets usually `{ "a" }` not `{"a":}`.
        *   **Issue:** Syntax for set literals (esp. empty, single-element) and potential ambiguity with dict literals needs clarification in docs and grammar robustness.
        *   **Status:** Basic concept mentioned; syntax clarity needed.
    3.  **Tuple Literal (`tuple_val`):** Doc shows `("a", )` (single element with comma). Grammar allows empty `()` and multi-element.
        *   **Status:** Single-element covered; others implied.
    4.  **List Literal (`list_val`):** Doc shows `['a']`. Grammar allows empty `[]`, multi-element, and trailing comma.
        *   **Status:** Basic covered; others implied.

    **Comprehensions (`..._compr` rules):**
    5.  **General Structure:** Docs show `TARGET for item in iterable if condition`.
        *   **Grammar (`inner_compr+` and `KW_ASYNC?`):** Allows multiple `for`/`if` clauses (e.g., `for x in X for y in Y if cond1 if cond2`) and `async` comprehensions.
        *   **Issue:** Advanced comprehension features (multiple `for`/`if` clauses, `async` comprehensions) are not documented in `collection_values.md`.
        *   **Status:** Basic comprehensions covered; advanced features undocumented.
    6.  **Dictionary Comprehension Grammar Typo:** `dict_compr` rule ends with `RSQUARE` in `jac.lark`, should be `RBRACE`.
        *   **Issue:** Grammar typo.

*   **Overall:** Basic collection literals and comprehensions are introduced. Key areas for improvement: robust syntax/examples for set literals (empty, single-element), documentation for advanced comprehension features (multiple `for`/`if`, `async`), and showing features like unpacking in dict literals and trailing commas. Grammar typo in `dict_compr` needs fixing.

---

## Section 63: Supporting rules for Collection Values (kv_pair, expr_list)

*   **Grammar Rules from `jac.lark`:**
    ```lark
    kv_pair: expression COLON expression | STAR_POW expression
    expr_list: (expr_list COMMA)? expression
    ```
*   **Corresponding Markdown File:** No dedicated file; these are components of collection literal rules discussed in `collection_values.md`.
*   **Analysis:**
    1.  **`kv_pair` (for Dictionary Literals):**
        *   **Grammar:** Defines `expression : expression` for key-value items and `STAR_POW expression` for dictionary unpacking (`**mapping`).
        *   **Documentation (`collection_values.md`):** Examples show `"key": "value"`. Dictionary unpacking (`**mapping`) within literals is not explicitly shown in this document but is a standard feature documented elsewhere (e.g., `unpack_expressions.md`).
        *   **Status:** Standard key-value covered. `**unpacking` as a `kv_pair` type is valid per grammar but not shown in `collection_values.md` examples of dictionary literals.

    2.  **`expr_list` (for List/Set Literals, Function Arguments):**
        *   **Grammar:** Defines a comma-separated list of one or more `expression`s.
        *   **Documentation (`collection_values.md`):** Examples like `['a']` use `expr_list`. Multi-element lists/sets are implied.
        *   Iterable unpacking (`*iterable`) within list/set literals: An `expression` in `expr_list` can be an `unpack` (e.g., `*my_items`). This specific syntax is not shown in `collection_values.md` examples for list/set literals but is documented in `unpack_expressions.md`.
        *   **Status:** Basic `expr_list` covered. `*unpacking` as part of `expr_list` for literals is valid per grammar but not shown in `collection_values.md` examples.

*   **Overall:** These grammar rules are fundamental for constructing collection literals. The `collection_values.md` illustrates basic usage but could be more comprehensive by showing how `STAR_POW expression` (for `kv_pair`) and `unpack` expressions (for `expr_list`) integrate into dictionary and list/set literals respectively, to fully reflect the grammar capabilities.

---

## Section 64: Tuples and Jac Tuples (tuple_list, kw_expr_list, kw_expr)

*   **Grammar Rules from `jac.lark`:**
    ```lark
    // These rules define the contents within LPAREN ... RPAREN for tuple_val.
    tuple_list: expression COMMA expr_list COMMA kw_expr_list COMMA?  // e.g., (p1, p2, kw1=v1)
              | expression COMMA kw_expr_list COMMA?                 // e.g., (p1, kw1=v1)
              | expression COMMA expr_list COMMA?                    // e.g., (p1, p2, p3)
              | expression COMMA                                     // e.g., (p1,)
              | kw_expr_list COMMA?                                  // e.g., (kw1=v1, kw2=v2)

    kw_expr_list: (kw_expr_list COMMA)? kw_expr
    kw_expr: named_ref EQ expression | STAR_POW expression // kw=val or **mapping
    // expr_list for positional elements is defined elsewhere.
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/tuples_and_jac_tuples.md`
*   **Findings:**
    1.  **Positional Tuples (elements are `expression` or from `expr_list`):**
        *   **Documentation:** Covers multi-element positional tuples (e.g., `(10, 20)`) and single-element tuples with a trailing comma (e.g., `(42,)`).
        *   **Grammar:** Supported by `expression COMMA expr_list?` and `expression COMMA`.
        *   **Status:** Covered.

    2.  **Keyword Tuples (Jac-specific, elements from `kw_expr_list`):**
        *   **Documentation:** Shows keyword tuples like `(x=3, y=4)` using `named_ref EQ expression`.
        *   **Grammar:** `kw_expr_list` is built from `kw_expr`, which includes `named_ref EQ expression` and `STAR_POW expression` (`**mapping`).
        *   The documentation does not explicitly show `**mapping` unpacking within keyword tuple literals (e.g., `config = (**common, port=80);`).
        *   **Issue (Minor):** `**mapping` unpacking in keyword tuple literals is not exemplified.
        *   **Status:** Basic keyword tuples covered.

    3.  **Mixed Positional and Keyword Tuples:**
        *   **Documentation:** Shows `("header", version=2, timestamp=now())` and states positional elements must precede keyword elements.
        *   **Grammar:** Supported by productions like `expression COMMA expr_list COMMA kw_expr_list ...` and `expression COMMA kw_expr_list ...`.
        *   **Status:** Covered.

    4.  **Trailing Commas (`COMMA?`):**
        *   **Grammar:** Allows optional trailing commas in most `tuple_list` variants and in `kw_expr_list`.
        *   **Documentation:** Notes for single-element positional tuples. Not emphasized for other cases but grammatically allowed.
        *   **Status:** Partially noted; broadly allowed by grammar.

    5.  **Empty Tuple `()`:**
        *   This is formed by `tuple_val: LPAREN tuple_list? RPAREN` when `tuple_list` is absent.
        *   **Documentation:** Not explicitly shown in this document, but is a standard construct.
        *   **Status:** Standard, implied by grammar for `tuple_val`.

*   **Overall:** The documentation effectively explains positional, keyword, and mixed tuples. The primary minor omission is an example of `**mapping` unpacking within keyword tuple literals. The grammar for these components is also fundamental to function call arguments.

---

## Section 65: Object-Spatial References (edge_ref_chain)

*   **Grammar Rules from `jac.lark` (overview):**
    ```lark
    edge_ref_chain: LSQUARE (KW_NODE| KW_EDGE)? expression? (edge_op_ref (filter_compr | expression)?)+ RSQUARE

    edge_op_ref: edge_any | edge_from | edge_to // Defines arrow types
    // edge_to/from/any can be simple (e.g., "-->") or detailed (e.g., "->:EdgeType:filter:->")
    // (filter_compr | expression)? is an optional filter after an edge operation.
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/data_spatial_references.md`
*   **Findings:**
    1.  **Basic Structure `LSQUARE ... RSQUARE`:** Covered.

    2.  **Initial Context `(KW_NODE| KW_EDGE)? expression?`:**
        *   **Grammar:** Allows an optional `node`/`edge` keyword and an optional starting `expression`.
        *   **Documentation:** Examples often implicitly use `here` as context. The role of this explicit initial part is not clearly explained or extensively exemplified (e.g., how `[node_expr --> ...]` differs from `[-->]` from `node_expr`'s context).
        *   **Issue (Clarification Needed):** Documentation for this initial context specifier is sparse.

    3.  **Edge Operations (`edge_op_ref`):**
        *   **Simple Arrows (`-->`, `<--`, `<-->`):** Documented for directional navigation.
        *   **Detailed/Typed Arrows (e.g., `->:EdgeType:prop_filter:->`):** Documented, showing typed edge traversal (e.g., `[-->:EdgeType:]`). The property filtering part within the detailed arrow syntax (`prop_filter`) is implicitly part of `typed_filter_compare_list`.
        *   **Status:** Core arrow operations covered.

    4.  **Optional Filter `(filter_compr | expression)?` after `edge_op_ref`:**
        *   **Grammar:** Allows a filter to be applied to the result of an edge operation.
        *   **Documentation:** "Filtered References" section shows examples like `[-->(weight > threshold)]` (expression filter) and `[-->(?name.startswith("test"))]` (filter comprehension).
        *   **Status:** Covered.

    5.  **Chaining of Edge Operations `(edge_op_ref ...)+`:**
        *   **Grammar:** Requires at least one, allows multiple chained edge operations within a single `[...]` block (e.g., `[--> --> some_prop < 10]` if intermediate steps yield nodes).
        *   **Documentation:** Does not show complex examples of deeply chaining multiple `edge_op_ref` within one `edge_ref_chain`. Focuses on single operations or iteration over results of one operation.
        *   **Issue (Minor):** Deeply chained edge operations within one reference are not exemplified.

    6.  **Inclusion of Connection/Disconnection Ops in the Document:**
        *   The document `data_spatial_references.md` also describes connection (`++>`) and disconnection (`del node-->edge`) operations.
        *   These are grammatically distinct from `edge_ref_chain` (which is for querying/traversing).
        *   **Issue (Documentation Structure):** Including creation/deletion operations in a document about "references" can be confusing. These belong more to `connect_expressions.md` or `delete_statements.md` respectively.

*   **Overall:** The document covers the basics of using `edge_ref_chain` for simple traversals and filtering. However, the initial context specifier and advanced chaining within a single reference need more documentation. The inclusion of connection/disconnection syntax in this particular document also blurs its focus.

---

## Section 66: Special Comprehensions

*   **Grammar Rules from `jac.lark`:**
    ```lark
    // Used in atomic_chain like: atomic_chain NULL_OK? (filter_compr | assign_compr)
    filter_compr: LPAREN NULL_OK filter_compare_list RPAREN
                | LPAREN TYPE_OP NULL_OK typed_filter_compare_list RPAREN
    assign_compr: LPAREN EQ kw_expr_list RPAREN // e.g., (= prop1=val1, prop2=val2)

    filter_compare_list: (filter_compare_list COMMA)? filter_compare_item
    typed_filter_compare_list: expression (COLON filter_compare_list)? // expression is TypeName
    filter_compare_item: named_ref cmp_op expression // e.g., age > 18

    // kw_expr_list uses kw_expr: named_ref EQ expression | STAR_POW expression
    // NULL_OK: "?", TYPE_OP: "`", EQ: "="
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/special_comprehensions.md`
*   **Findings:**
    1.  **Filter Comprehensions (`filter_compr`):**
        *   **Non-Typed `(? filter_conditions)`:** Documented with examples like `(?score > 0.5)` and `(age > 18, status == "active")`. Aligns with `LPAREN NULL_OK filter_compare_list RPAREN`.
            *   **Status:** Covered.
        *   **Typed ``( `TypeName : ? filter_conditions )``:** Documented with examples like `` (`Connection: weight > 10) `` and `` `UserNode: (active == True) ``. Aligns with `LPAREN TYPE_OP NULL_OK typed_filter_compare_list RPAREN`.
            *   **Status:** Covered.

    2.  **Assignment Comprehensions (`assign_compr`):**
        *   **Grammar:** `LPAREN EQ kw_expr_list RPAREN`. `kw_expr_list` uses `named_ref EQ expression` for items (e.g., `(=prop1=val1, prop2=val2)`).
        *   **Documentation:** Shows syntax like `(=property: new_value)` and `(=x: 10, y: 20)`. Uses colons `:` instead of equals `=` for assignments within the comprehension.
        *   **Issue (Syntax Mismatch):** Documentation for assignment items (e.g., `prop:value`) uses colons, while the grammar (via `kw_expr_list` -> `kw_expr`) specifies equals signs (`prop=value`). This needs reconciliation.
        *   **Status:** Concept covered; syntax detail for assignment items mismatched.

    3.  **Structure of Filter Conditions (`filter_compare_list`, `typed_filter_compare_list`, `filter_compare_item`):**
        *   These grammar rules correctly define how multiple filter conditions (`name op value`) are formed and combined, optionally typed with a leading `TypeName:`.
        *   **Documentation:** Examples for these list structures align with the grammar.
        *   **Status:** Covered.

    4.  **Usage Context (Applied to an `atomic_chain`, often `edge_ref_chain`):**
        *   **Documentation:** Clearly shows these comprehensions applied to edge references, e.g., `[-->(?score > 0.5)];` or `[-->](=visited: True);`. Also shows null-safe application `[-->(?nested?.property > 0)]`.
        *   **Status:** Covered.

*   **Overall:** Filter comprehensions are well-documented and align with the grammar. Assignment comprehensions are conceptually covered, but there is a syntax mismatch (colon vs. equals) for the assignment items within them compared to the underlying `kw_expr_list` grammar. The application of these comprehensions to edge references is well illustrated.

---

## Section 67: Names and references (named_ref, special_ref)

*   **Grammar Rules from `jac.lark`:**
    ```lark
    named_ref: special_ref | KWESC_NAME | NAME

    special_ref: KW_INIT | KW_POST_INIT | KW_ROOT | KW_SUPER | KW_SELF | KW_HERE | KW_VISITOR

    NAME: /[a-zA-Z_][a-zA-Z0-9_]*/
    KWESC_NAME: /<>[a-zA-Z_][a-zA-Z0-9_]*/
    // KW_SELF is "self", KW_HERE is "here", etc.
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/names_and_references.md`
*   **Findings:**
    1.  **`NAME` (Standard Identifiers):**
        *   **Grammar:** `NAME: /[a-zA-Z_][a-zA-Z0-9_]*/`.
        *   **Documentation:** Correctly describes standard identifier rules and provides valid/invalid examples.
        *   **Status:** Covered.

    2.  **`KWESC_NAME` (Keyword Escaping):**
        *   **Grammar:** `KWESC_NAME: /<>[a-zA-Z_][a-zA-Z0-9_]*/` (e.g., `<>myvar`).
        *   **Documentation:** Explains escaping keywords by wrapping with angle brackets, example `_<>with = 10;`.
        *   **Clarification on example:** The example `_<>with` might be slightly confusing. If `with` is the keyword to be used as an identifier, the syntax would likely be `<>with` if the lexer/parser handles `<>keyword` as a special token, or `<>somename` if `somename` is a valid identifier that isn't a keyword but needs escaping for other reasons (less common). The regex `/<>[a-zA-Z_][a-zA-Z0-9_]*/` suggests `<>` followed by a standard identifier sequence.
        *   **Status:** Concept covered. Exact tokenization of example `_<>with` vs. regex needs to be precise.

    3.  **`special_ref` (Special References):**
        *   **Grammar:** Lists `KW_INIT`, `KW_POST_INIT`, `KW_ROOT`, `KW_SUPER`, `KW_SELF`, `KW_HERE`, `KW_VISITOR`.
        *   **Documentation:** Provides a table and explanations for `self`, `here`, `visitor`, `super`, `root`, `init`/`postinit`. All match the grammar keywords.
        *   **Status:** Covered.

*   **Overall:** The documentation accurately covers the types of named references: standard identifiers, special built-in references, and the mechanism for escaping keywords. The usage context, especially for special references, is well explained. Minor clarification on the `KWESC_NAME` example could be useful.

---

## Section 68: Builtin types

*   **Grammar Rules from `jac.lark`:**
    ```lark
    builtin_type: TYP_TYPE | TYP_ANY | TYP_BOOL | TYP_DICT | TYP_SET | TYP_TUPLE |
                  TYP_LIST | TYP_FLOAT | TYP_INT | TYP_BYTES | TYP_STRING
    // These TYP_ tokens are keywords like "int", "str", etc.
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/builtin_types.md`
*   **Findings:**
    1.  **List of Built-in Type Keywords:**
        *   **Grammar:** Defines tokens for `type`, `any`, `bool`, `dict`, `set`, `tuple`, `list`, `float`, `int`, `bytes`, `string`.
        *   **Documentation:** Lists all these types, categorizing them (Primitive, Collection, Meta).
        *   **Status:** Covered and consistent.

    2.  **Usage in Type Annotations:**
        *   **Documentation:** Shows examples like `name: str`, `data: list`, `-> dict`. This is the primary use case for these keywords representing types.
        *   **Grammar:** This usage fits into rules like `type_tag: COLON expression` where `expression` can be a `named_ref` that is one of these `builtin_type` keywords.
        *   **Status:** Primary usage context covered.

    3.  **Other Grammatical Roles:**
        *   The `builtin_type` rule is also part of `atom_literal` (allowing `x = int` if `int` is treated as a value) and `type_ref` (allowing `` `int ``).
        *   **Documentation (`builtin_types.md`):** Focuses on their use as type specifiers in annotations rather than these other roles.
        *   **Status:** These specific grammatical roles are not detailed in this document but are part of other grammar rules (`atom_literal`, `type_ref`).

*   **Overall:** The `builtin_types.md` correctly lists the available built-in type keywords and illustrates their main function in type annotations. It does not exhaustively cover every grammatical context where these type names might appear, but those are better suited for the sections defining those contexts (e.g., `atom.md` for literals).

---

## Section 69: f-string tokens

*   **Grammar Rules for f-string structure (from "Atom" section) and its terminals:**
    ```lark
    // Structure rule (uses these terminals)
    fstring: FSTR_START fstr_parts FSTR_END
           | FSTR_SQ_START fstr_sq_parts FSTR_SQ_END
    fstr_parts: (FSTR_PIECE | FSTR_BESC | LBRACE expression RBRACE )*
    fstr_sq_parts: (FSTR_SQ_PIECE | FSTR_BESC | LBRACE expression RBRACE )*

    // Terminal definitions for f-string components
    FSTR_START.1: "f\""
    FSTR_END: "\""
    FSTR_SQ_START.1: "f'"
    FSTR_SQ_END: "'"
    FSTR_PIECE.-1: /[^\{\}\"]+/
    FSTR_SQ_PIECE.-1: /[^\{\}\']+/
    FSTR_BESC.1: /{{|}}/
    ```
*   **Corresponding Markdown File:** `jac/examples/reference/f_string_tokens.md`
*   **Findings:**
    1.  **Basic F-String Syntax (`f"..."`, `f'..."`):**
        *   **Grammar:** `FSTR_START...FSTR_END` and `FSTR_SQ_START...FSTR_SQ_END` along with `fstr_parts` define this.
        *   **Documentation:** Shows `f"Hello, {name}!";`. Single-quoted `f'...'` version implied by grammar but not explicitly shown as alternative in this doc.
        *   **Status:** Covered (double-quoted shown).

    2.  **Embedded Expressions (`{expression}`):**
        *   **Grammar:** `LBRACE expression RBRACE` within `fstr_parts`.
        *   **Documentation:** Well covered with various examples of embedded expressions.
        *   **Status:** Covered.

    3.  **Format Specifications (e.g., `{value:.2f}`):**
        *   **Documentation:** Shows examples like `f"Pi: {value:.2f}"`.
        *   **Grammar:** Handled by the `expression` within `{...}` if it includes formatting, relying on Python-like f-string capabilities.
        *   **Status:** Documented.

    4.  **Escaped Braces (`{{`, `}}`):**
        *   **Grammar:** `FSTR_BESC.1: /{{|}}/`.
        *   **Documentation (`f_string_tokens.md`):** Does not show examples of escaped braces.
        *   **Issue:** Undocumented feature.

    5.  **Multi-Line F-Strings (e.g., `f"""..."""`):**
        *   **Documentation:** Shows an example using `f"""..."""`.
        *   **Grammar (Terminals):** The `FSTR_START`/`END` terminals are defined only for `f"` and `f'`. They do not include `f"""` or `f'''`.
        *   **Issue (Grammar/Doc Mismatch):** Documented multi-line f-strings (`f"""..."""`) are not supported by the provided `FSTR_START`/`END` terminal definitions. The grammar for f-string delimiters needs to be extended or use the general `STRING` terminal (which supports triple quotes) if an `f` prefix on it is handled differently by the lexer.

*   **Overall:** Core f-string functionality (embedded expressions, format specs) is documented. Escaped braces are an undocumented feature. There's a significant mismatch for multi-line f-strings between documentation and the specific f-string delimiter terminals in the grammar.

---

## Section 70: Lexer Tokens (TYP_... terminals for builtin types)

*   **Grammar Rules from `jac.lark` (under this specific heading):**
    ```lark
    TYP_STRING: "str"
    TYP_INT: "int"
    TYP_FLOAT: "float"
    TYP_LIST: "list"
    TYP_TUPLE: "tuple"
    TYP_SET: "set"
    TYP_DICT: "dict"
    TYP_BOOL: "bool"
    TYP_BYTES: "bytes"
    TYP_ANY: "any"
    TYP_TYPE: "type"
    ```
    *(These terminals are used in the `builtin_type` rule, see Section 68).*

*   **Corresponding Markdown File:** `jac/examples/reference/lexer_tokens.md`
*   **Findings:**
    1.  **Documentation of `TYP_...` Tokens:**
        *   The `lexer_tokens.md` file, in its "Built-in type tokens" subsection, lists: `str int float list tuple set dict bool bytes any type`.
        *   This list accurately matches the keywords defined as `TYP_...` terminals in the grammar.
        *   **Status:** Covered and consistent.

    2.  **Scope of `lexer_tokens.md` Document:**
        *   The markdown file `lexer_tokens.md` is a broad overview of many Jac token categories (keywords, operators, literals, delimiters), not limited to just the `TYP_...` built-in type tokens.
        *   This is a general informational document. The `TYP_...` tokens are just one part of it.

*   **Overall:** For the specific grammar section covering `TYP_...` terminals, the `lexer_tokens.md` file is consistent. The broader content of `lexer_tokens.md` covers many other terminal types defined elsewhere in the `jac.lark` grammar.

---

## Section 71: Remaining Terminal Definitions (Keywords, Literals, Operators, etc.)

*   **Grammar Sections in `jac.lark`:** This covers various terminal definitions typically found at the end of a Lark file, including Keywords (e.g., `KW_IF: "if"`), Literal tokens (e.g., `INT`, `STRING`), Identifier tokens (`NAME`), Operator tokens (e.g., `PLUS: "+"`, `ARROW_R: "-->"`), and directives for Comments/Whitespace.
*   **Corresponding Markdown Files:** No single, dedicated markdown files for these broad terminal categories. `lexer_tokens.md` provides a partial overview. Specific terminals are best understood in the context of the grammar rules that use them.
*   **Findings & Overall Status:**
    1.  **Keywords (e.g., `KW_LET`, `KW_IF`):**
        *   Most keywords are defined as simple string literals (e.g., `KW_IF: "if"`). Their usage and meaning are covered by the documentation of the statements/expressions they introduce (e.g., `if_stmt` for `KW_IF`).
        *   Regex-based keywords like `KW_NIN` (`not in`) and `KW_ISN` (`is not`) were noted as missing from explicit lists in `logical_and_compare_expressions.md` but are present in `cmp_op` grammar.
        *   **Status:** Implicitly and contextually covered. Definitions are standard.

    2.  **Literals (Terminals: `STRING`, `NULL`, `BOOL`, `FLOAT`, `HEX`, `BIN`, `OCT`, `INT`):**
        *   These define the lexical representation of literal values.
        *   Their interpretation and usage were discussed under `atom_literal` (Section 60) and `multistring`/`fstring` (Section 61).
        *   Key issue previously noted: documentation for numeric base literals (`HEX`, `BIN`, `OCT`) in `atom.md` was incorrect or missing. The terminal definitions themselves (e.g., `HEX.1: /0[xX][0-9a-fA-F_]+/`) are standard.
        *   **Status:** Terminal definitions are standard. Documentation consistency for their use (especially numeric bases) is the main concern.

    3.  **Identifier (Terminals: `KWESC_NAME`, `NAME`):**
        *   Covered in detail under "Names and references" (Section 67).
        *   **Status:** Covered.

    4.  **Operators (Object-Spatial, Assignment, Arithmetic, Other - e.g., `ARROW_R`, `EQ`, `PLUS`, `PIPE_FWD`):**
        *   These terminals define the symbols for various operations.
        *   Their meaning and usage are tied to the expression rules that employ them (e.g., `connect_op` for `ARROW_R`, `assignment` for `EQ`, `arithmetic` for `PLUS`, `pipe` for `PIPE_FWD`). These were covered in their respective expression sections.
        *   The `@` operator (`DECOR_OP`) was noted as missing from arithmetic expression documentation.
        *   **Status:** Implicitly and contextually covered. Definitions are standard.

    5.  **Punctuation Terminals (e.g., `COLON: ":"`, `LPAREN: "("`):**
        *   These are fundamental syntactic markers.
        *   Their role is defined by their use in all other grammar rules.
        *   Special punctuation like `TYPE_OP: "`"` (for type references) and `NULL_OK: "?"` (null-safe operator) were discussed in context (e.g., `atom`, `atomic_chain`).
        *   **Status:** Covered by overall grammar structure.

    6.  **Comments and Whitespace (`COMMENT`, `WS`, `%ignore` directives):**
        *   Standard lexer directives and definitions for ignoring comments and whitespace.
        *   No specific documentation file is typically needed for these beyond standard language behavior.
        *   **Status:** Standard, no issues.

*   **Final Overall Summary on Terminals:** The terminal definitions in `jac.lark` are, for the most part, standard and serve as the building blocks for the parser. Most are self-explanatory or their meaning is derived from the higher-level grammar rules and the associated documentation for those rules. The consistency issues previously noted (e.g., documentation of numeric literals, specific operators like `@`, `is not`, `not in`) are the primary points of concern related to how these terminals manifest in the language features.

---

## Overall Summary of Findings

This analysis compared the `jac.lark` grammar file against the Markdown documentation in `jac/examples/reference/`. Numerous sections were analyzed, and the findings have been detailed in the preceding sections of this document.

The major themes of inconsistencies and areas for improvement include:

1.  **Outdated/Incorrect Documentation Examples or Explanations:**
    *   `atom.md`: Incorrect syntax for binary/hex literals (showed function calls).
    *   `match_literal_patterns.md`: Miscategorized `None` and booleans (which are `singleton_pattern`s).
    *   `expressions.md`: Contained a lambda example with syntax inconsistent with `lambda_expr` grammar.
    *   `assignments.md`: Showed an unconventional destructuring assignment syntax `(name=user, age=years) = ...` that needs clarification or correction.
    *   `base_module_structure.md`: Overstated requirement for `with entry {}` for all module-level code.

2.  **Grammar Features Not Documented or Under-exemplified:**
    *   **Common Patterns:** Trailing commas in lists/arguments; `let` with chained assignments; typed declarations without init; assigning `yield_expr` results.
    *   **Import Statements:** Using `.` or `...` in `from_path`; multiple modules in one standard `import`.
    *   **Archetypes/Enums:** `async` archetypes; empty archetype/enum bodies with `SEMI`; nesting various statements (`py_code_block`, other archetypes, `impl_def`, `free_code`) inside archetype bodies; `KW_LET` for `has_stmt`; multiple vars in one `has`; enum inheritance.
    *   **Abilities/Functions:** `KW_OVERRIDE` keyword; `KW_BY` delegation (for implementation and in calls); return types on `event_clause`; `static can` abilities; no-parenthesis `func_decl` for no-arg functions.
    *   **Implementations (`impl`):** `KW_BY` delegation; decorators on `impl`; `impl_spec` as `inherited_archs` or `event_clause`; modern `impl` syntax for `test`.
    *   **Global Variables:** Multiple declarations in one statement; declaration without initial assignment.
    *   **Python Integration:** `py_code_block` usage within archetypes or function bodies.
    *   **Testing:** String literals for test names vs. `NAME` token in grammar; separation of test declaration/implementation in `tests.md`.
    *   **Statements:** Empty statement (`SEMI`); comprehensive list in `codeblocks_and_statements.md`.
    *   **Loops:** `else` clause for `for` loops; `async for ... to ... by ...`; multi-variable assignment syntax in `for i=0,j=0...`; `if filter` in `for...in` loop.
    *   **Error Handling:** Bare `except:` syntax in `try_stmt` docs inconsistent with grammar.
    *   **Pattern Matching:** Positional argument patterns in `match_class_pattern`; type-only `ClassName()` match; `list_val` for fancy indexing in `index_slice`; comma-separated multi-dim indexing; `as_pattern` with `or_pattern` on LHS; `assign_compr` syntax (`:` vs. `=`).
    *   **String Literals:** Implicit concatenation of adjacent string/f-string literals; escaped braces `{{ }}` in f-strings; multi-line `f"""..."""` support in grammar vs. f-string tokens.
    *   **Lambda Expressions:** No-param lambdas; `*args`/`**kwargs`; default parameter values; explicit return type annotation.
    *   **Object-Spatial:** Initial context `(KW_NODE|KW_EDGE)? expr?` in `edge_ref_chain`; deep chaining of `edge_op_ref`; `disconnect_op` as part of `connect` expression; semantic meaning of chained `spawn` expressions.
    *   **Operators:** `@` (matrix multiplication) operator in arithmetic expressions; `is not`/`not in` in comparison operator lists.

3.  **Potential Grammar Issues, Typos, or Ambiguities:**
    *   `pipe_call` rule: Its definition treating `|>`, `:>`, `spawn` as optional unary prefixes is largely inconsistent with their binary nature defined elsewhere. Needs significant review.
    *   `shift` rule: Uses `logical_or` as operand name, likely a placeholder/typo.
    *   `disenage_stmt`: Typo for `disengage_stmt` in rule name.
    *   `dict_compr`: Ends with `RSQUARE` instead of `RBRACE`.
    *   `KWESC_NAME`: Regex vs. example (`_<>with`) could be clarified.
    *   Clarity on whether `KW_SKIP` is a general `ctrl_stmt` or walker-specific based on its grammar placement.
    *   `delete_stmt`: `del a,b,c;` syntax needs clarification against `KW_DELETE expression`.

4.  **Documentation Structure/Scope Concerns:**
    *   `atomic_expressions.md` describes `atomic_pipe` (`:>`) not general language atoms.
    *   `data_spatial_references.md` includes connection/disconnection operations (which are not strictly "references").
    *   `lexer_tokens.md` is a very broad token overview.

5.  **Unused Features Confirmed:**
    *   The `&` operator for explicit references (`ref: BW_AND? pipe_call`) is documented as unused.

This detailed analysis, available in `notes.md`, should serve as a comprehensive guide for synchronizing the Jac language grammar with its documentation, enhancing clarity, accuracy, and completeness for developers.

---