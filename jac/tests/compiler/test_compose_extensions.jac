"""Tests for the ingested Compose type surface on the checker side.

Two halves, both pinned here:

  1. Builtin member extensions — `16.dp`, `14.sp`, `xs.len`. Installed onto the
     prefetched int/float/list *shared* symbol tables so a literal receiver
     (a `clone_with_literal` sharing `_shared`) resolves them. This is the
     load-bearing assumption behind the whole approach: a member written on a
     builtin's shared table is visible from its literal clones.

  2. Widget surface — `parse_signature_text` (metalava) -> `_kotlin_synth_surface`
     installs each @Composable as a typed module-scope symbol, so `Button(...)`
     type-checks as a call returning `Composable`, replacing the hand-written
     ingested metalava/stub-gen types (no hand-written runtime shim).
"""

import os;
import tempfile;
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.compiler.type_system.compose_signatures { parse_signature_text }

def _mk_compose_project(prefix: str) -> str {
    # A snippet dir that is a real Compose project: `[client] framework = "compose"`
    # is the single signal `_is_compose_module` keys on, so the ingested Compose
    # ambient surface (widgets / Modifier / Arrangement / .dp) resolves here. A
    # plain client codespace outside such a project no longer sees Compose names.
    d = tempfile.mkdtemp(prefix=prefix);
    with open(os.path.join(d, "jac.toml"), "w") as f {
        f.write(
            "[project]\nname = \"compose_ext_test\"\n\n[client]\nframework = \"compose\"\n\n"
            "[placement.pins]\n\"snippet_*\" = \"client\"\n"
        );
    }
    return d;
}

glob _tmp: str = _mk_compose_project("jac_test_compose_ext_");

def _mk_plain_client_project(prefix: str) -> str {
    # A client project that is NOT Compose (a plain React surface): no
    # `framework = "compose"`. `_is_compose_module` is False here, so the Compose
    # ambient vocabulary must stay invisible even in a `.jac` client codespace.
    d = tempfile.mkdtemp(prefix=prefix);
    with open(os.path.join(d, "jac.toml"), "w") as f {
        f.write(
            "[project]\nname = \"plain_client_test\"\n\n"
            "[placement.pins]\n\"snippet_*\" = \"client\"\n"
        );
    }
    return d;
}

glob _react_tmp: str = _mk_plain_client_project("jac_test_react_");

def _errors_in(
    dir_: str, code: str, suffix: str = ".jac", framework: str = "compose"
) -> list[str] {
    path = os.path.join(dir_, f"snippet_{abs(hash(code))}{suffix}");
    with open(path, "w") as f {
        f.write(code);
    }
    prog = JacProgram();
    # Force the client surface via CompileOptions (it takes precedence over
    # project-config discovery), so the snippet resolves as a compose (or plain
    # react) client module deterministically under parallel test runs.
    prog.compile(
        path,
        options=CompileOptions(
            type_check=True, no_cgen=True, client_framework=framework
        )
    );
    return [str(e) for e in prog.errors_had];
}

glob FIXTURE: str = "package androidx.compose.material3 {\n"
     "  public final class ButtonKt {\n"
     "    method @androidx.compose.runtime.Composable public static void Button(kotlin.jvm.functions.Function0<kotlin.Unit> onClick, optional androidx.compose.ui.Modifier modifier, optional boolean enabled, kotlin.jvm.functions.Function1<? super androidx.compose.foundation.layout.RowScope,kotlin.Unit> content);\n"
     "  }\n"
     "  public final class SliderKt {\n"
     "    method @androidx.compose.runtime.Composable public static void Slider(float value, kotlin.jvm.functions.Function1<? super java.lang.Float,kotlin.Unit> onValueChange, optional androidx.compose.ui.Modifier modifier, optional boolean enabled);\n"
     "  }\n"
     "  public final class TextKt {\n"
     "    method @androidx.compose.runtime.Composable public static void Text(String text, optional androidx.compose.ui.Modifier modifier, optional long color, optional androidx.compose.ui.text.TextStyle style);\n"
     "  }\n"
     "}\n";

def _errors_for(code: str, suffix: str = ".jac") -> list[str] {
    # Unique filename per call — a fixed path lets the compiler's by-path cache
    # return a prior snippet's (clean) result, masking a genuine type error.
    return _errors_in(_tmp, code, suffix, "compose");
}

# ── Part 1: builtin member extensions ───────────────────────────────────────

test "integer literal .dp / .sp type-check in client context" {
    assert not _errors_for("def f -> any {\n    return 16.dp;\n}\n", ".jac");
    assert not _errors_for("def f -> any {\n    return 14.sp;\n}\n", ".jac");
}

test "float literal .dp type-checks in client context" {
    assert not _errors_for("def f -> any {\n    return 1.5.dp;\n}\n", ".jac");
}

test "list .len type-checks as int in client context" {
    errs = _errors_for(
        "def f -> int {\n    xs: list[int] = [1, 2, 3];\n    return xs.len;\n}\n",
        ".jac"
    );
    assert not errs , f"xs.len should type-check as int, got: {errs}";
}

test "installed compose members are flagged compose-gated, real builtins are not" {
    # The resolver consults `_is_compose_gated_member` and drops the member when
    # `not expr.in_client_context()`, so `.dp`/`.sp`/`.len` resolve to their
    # Compose types only inside a client codespace. (Builtin member access is
    # permissive — an unknown member on int/list is not an error either way — so
    # the gate is verified on the predicate that drives it, not via diagnostics.)
    ev = JacProgram().get_type_evaluator();
    dp = ev.prefetch.int_class.shared.symbol_table.names_in_scope.get("dp");
    ln = ev.prefetch.list_class.shared.symbol_table.names_in_scope.get("len");
    assert ev._is_compose_gated_member(dp) , "int .dp must be compose-gated";
    assert ev._is_compose_gated_member(ln) , "list .len must be compose-gated";
    # a genuine builtin member (list.append) must NOT be gated
    ap = ev.prefetch.list_class.shared.symbol_table.names_in_scope.get("append");
    assert ap is not None , "list.append should exist as a real builtin member";
    assert not ev._is_compose_gated_member(ap) , "real builtins must not be gated";
}

test "int .dp yields the Dp type, not bare any" {
    ev = JacProgram().get_type_evaluator();
    ext = ev.prefetch.int_class.shared.symbol_table.names_in_scope.get("dp");
    assert ext is not None , "dp extension must be installed on int";
    assert "Dp" in str(ev.get_type_of_symbol(ext));
}

# ── Part 2: ingested widget surface ─────────────────────────────────────────

test "_compose_sig_to_functype carries metalava required-ness, not erasure" {
    ev = JacProgram().get_type_evaluator();
    sigs = parse_signature_text(FIXTURE);
    button = [
        s
        for s in sigs
        if s.name == "Button"
    ][0];
    ft = ev._compose_sig_to_functype(button);
    assert ft.func_name == "Button";
    assert len(ft.parameters) == 4;
    # required-ness is carried through faithfully: onClick (an event) and content
    # (a slot) are both unmarked by metalava, so both stay required. In JSX the
    # content slot is satisfied by children (children-aware validator); modifier
    # and enabled are marked `optional` and so default.
    bydefault = {p.name: p.has_default for p in ft.parameters};
    assert bydefault["onClick"] == False , "onClick is a required event (no `optional` marker)";
    assert bydefault["content"] == False , "content slot is required (no `optional` marker); JSX children fill it";
    assert bydefault["modifier"] == True , "modifier is `optional` -> defaulted";
    assert bydefault["enabled"] == True , "enabled is `optional` -> defaulted";
    bykind = {p.name: str(p.param_type) for p in ft.parameters};
    assert "ModifierChain" in bykind["modifier"];
    # return type is Composable
    assert "Composable" in str(ft.return_type);
}

test "value params map to real Jac prims, not bare any" {
    # The headline of the strong-typing pass: SigParam.ptype (the metalava Kotlin
    # type) is mapped through to a Jac prim, exactly as the React .d.ts path maps
    # TS prims. `enabled: boolean` -> bool, `value: float` -> float, `color: long`
    # -> int. A Compose value class we don't model (TextStyle) stays foreign-any.
    ev = JacProgram().get_type_evaluator();
    sigs = parse_signature_text(FIXTURE);
    byname = {s.name: s for s in sigs};

    btn = {
        p.name: str(p.param_type)
        for p in ev._compose_sig_to_functype(byname["Button"]).parameters
    };
    assert "bool" in btn["enabled"] , f"enabled should be bool, got {btn['enabled']}";

    slider = {
        p.name: str(p.param_type)
        for p in ev._compose_sig_to_functype(byname["Slider"]).parameters
    };
    assert "float" in slider["value"] , f"value should be float, got {slider['value']}";

    text = {
        p.name: str(p.param_type)
        for p in ev._compose_sig_to_functype(byname["Text"]).parameters
    };
    assert "str" in text["text"] , f"text should be str, got {text['text']}";
    assert "int" in text["color"] , f"color (long) should be int, got {text['color']}";
    # unmodelled Compose value class -> foreign-any (still name/arity-checked)
    assert "Any" in text["style"] or "any" in text["style"] , f"style (TextStyle) should fall back to any, got {text[
        'style'
    ]}";
}

test "event handlers carry their Kotlin FunctionN argument types" {
    # The onValueChange handler on Slider is `Function1<? super Float, Unit>`, so
    # the synthesized lambda type must take one float arg and return None — the
    # `? super` variance marker and the trailing Unit return are stripped.
    ev = JacProgram().get_type_evaluator();
    sigs = parse_signature_text(FIXTURE);
    byname = {s.name: s for s in sigs};

    slider = {
        p.name: p.param_type
        for p in ev._compose_sig_to_functype(byname["Slider"]).parameters
    };
    ovc = slider["onValueChange"];
    assert len(ovc.parameters) == 1 , f"onValueChange must take 1 arg, got {len(
        ovc.parameters
    )}";
    assert "float" in str(ovc.parameters[0].param_type) , f"arg should be float, got {ovc.parameters[
        0
    ].param_type}";
    assert "None" in str(ovc.return_type) or "none" in str(ovc.return_type);

    # Button.onClick is `Function0<Unit>` — a nullary handler.
    button = {
        p.name: p.param_type
        for p in ev._compose_sig_to_functype(byname["Button"]).parameters
    };
    assert len(button["onClick"].parameters) == 0 , "onClick must be nullary";
}

test "_map_kotlin_lambda parses arity, prims, and variance markers" {
    ev = JacProgram().get_type_evaluator();
    # nullary
    assert len(
        ev._map_kotlin_lambda("kotlin.jvm.functions.Function0<kotlin.Unit>").parameters
    )
        == 0;
    # one float arg behind a `? super` bound
    one = ev._map_kotlin_lambda(
        "kotlin.jvm.functions.Function1<? super java.lang.Float,kotlin.Unit>"
    );
    assert len(one.parameters) == 1;
    assert "float" in str(one.parameters[0].param_type);
    # two args, mixed prims, `? extends` bound
    two = ev._map_kotlin_lambda(
        "kotlin.jvm.functions.Function2<? super java.lang.Boolean,? extends kotlin.Int,kotlin.Unit>"
    );
    assert len(two.parameters) == 2;
    assert "bool" in str(two.parameters[0].param_type);
    assert "int" in str(two.parameters[1].param_type);
    # unmodelled arg type -> foreign-any, still one param
    unk = ev._map_kotlin_lambda(
        "kotlin.jvm.functions.Function1<? super androidx.compose.ui.graphics.Color,kotlin.Unit>"
    );
    assert len(unk.parameters) == 1;
    m = str(unk.parameters[0].param_type);
    assert "Any" in m or "any" in m;
    # empty / non-generic ptype -> nullary handler, no crash
    assert len(ev._map_kotlin_lambda("").parameters) == 0;
}

test "_map_kotlin_type maps scalars and falls back for the rest" {
    ev = JacProgram().get_type_evaluator();
    assert "bool" in str(ev._map_kotlin_type("boolean"));
    assert "int" in str(ev._map_kotlin_type("int"));
    assert "int" in str(ev._map_kotlin_type("long"));
    assert "float" in str(ev._map_kotlin_type("float"));
    assert "float" in str(ev._map_kotlin_type("double"));
    assert "str" in str(ev._map_kotlin_type("java.lang.String"));
    assert "str" in str(ev._map_kotlin_type("kotlin.CharSequence"));
    # annotated / fully-qualified scalars still resolve to the bare type
    assert "int" in str(ev._map_kotlin_type("@IntRange int"));
    # unknown types are foreign-any, not a crash
    m = str(ev._map_kotlin_type("androidx.compose.ui.graphics.Color"));
    assert "Any" in m or "any" in m;
}

test "a wrong-typed value arg is a Jac error; a right-typed one is not" {
    # End-to-end proof via the real JSX form: because `enabled` carries a real bool
    # type, passing a string is caught at Jac compile time (before Kotlin), while a
    # bool is clean. Children fill the required content slot in both cases.
    bad = _errors_for(
        "def f -> Composable {\n    return <Button onClick={lambda -> None { }} enabled=\"yes\">\"x\"</Button>;\n}\n",
        ".jac"
    );
    assert bad , "<Button enabled=\"yes\"> must be a Jac type error";
    good = _errors_for(
        "def f -> Composable {\n    return <Button onClick={lambda -> None { }} enabled={True}>\"x\"</Button>;\n}\n",
        ".jac"
    );
    assert not good , f"<Button enabled={{True}}> must type-check, got: {good}";
}

test "a required event handler is enforced in plain widget calls" {
    # The correctness win of carrying required-ness: a call missing the required
    # onClick handler is a Jac error (previously erased — every param defaulted).
    missing = _errors_for(
        "def f -> any {\n    return Button(enabled=True);\n}\n", ".jac"
    );
    assert missing , "Button() without the required onClick must be a Jac error";
    # A plain call is now faithful to Kotlin: the unmarked content slot is required,
    # so even with the handler present a bare call is flagged (JSX fills it from
    # children — see the children-awareness tests below).
    no_content = _errors_for(
        "def f -> any {\n    return Button(onClick=lambda -> None { });\n}\n", ".jac"
    );
    assert no_content , f"Button(onClick=..) with no content must be flagged in a plain call, got: {no_content}";
    # Slider's required onValueChange event is enforced too.
    no_handler = _errors_for(
        "def f -> any {\n    return Slider(value=0.5);\n}\n", ".jac"
    );
    assert no_handler , "Slider() without the required onValueChange must be a Jac error";
    # A required value param (Text's text) is now enforced in a plain call as well.
    text_missing = _errors_for(
        "def f -> any {\n    return Text(color=0);\n}\n", ".jac"
    );
    assert text_missing , f"Text(color=0) must be flagged on the missing required text, got: {text_missing}";
}

test "JSX children satisfy a required content slot" {
    # A widget's trailing content slot is filled by children, mirroring the emitter.
    # <Button onClick=..>..</Button> supplies content via children -> clean, but a
    # self-closing <Button onClick=.. /> supplies neither an attribute nor children
    # for the required content -> E1102.
    with_children = _errors_for(
        "def f -> Composable {\n    return <Button onClick={lambda -> None { }}>\"Go\"</Button>;\n}\n",
        ".jac"
    );
    assert not with_children , f"<Button>..children..</Button> must type-check, got: {with_children}";
    childless = _errors_for(
        "def f -> Composable {\n    return <Button onClick={lambda -> None { }} />;\n}\n",
        ".jac"
    );
    assert childless , "<Button onClick=.. /> with no content children must flag the required content slot";
    # A missing required *event* is still flagged even when children are present —
    # children only satisfy the primary content, never an event handler.
    no_handler = _errors_for(
        "def f -> Composable {\n    return <Button>\"Go\"</Button>;\n}\n", ".jac"
    );
    assert no_handler , "<Button>..</Button> without onClick must still flag the required handler";
}

test "JSX children satisfy Text's required text value" {
    # Text routes children into its required `text` value param (Text(text=..)).
    with_text = _errors_for(
        "def f -> Composable {\n    return <Text>\"Hi\"</Text>;\n}\n", ".jac"
    );
    assert not with_text , f"<Text>\"Hi\"</Text> must type-check, got: {with_text}";
    # A dynamic child expression counts as content too.
    dynamic = _errors_for(
        "def f -> Composable {\n    n = 1;\n    return <Text>{n}</Text>;\n}\n", ".jac"
    );
    assert not dynamic , f"<Text>{{n}}</Text> must type-check, got: {dynamic}";
    # A self-closing Text supplies neither the text attribute nor children -> flagged.
    childless = _errors_for(
        "def f -> Composable {\n    return <Text color={0} />;\n}\n", ".jac"
    );
    assert childless , "<Text color={0} /> with no text children must flag the required text value";
}

test "_kotlin_synth_surface installs each composable as a typed callable symbol" {
    ev = JacProgram().get_type_evaluator();
    ev._kotlin_synth_surface(parse_signature_text(FIXTURE), ev.js_globals_module);
    sym = ev.js_globals_module.names_in_scope.get("Button");
    assert sym is not None , "Button must be installed as an ambient client global";
    ft = ev.get_type_of_symbol(sym);
    # resolves to the ingested FunctionType returning Composable
    assert "Composable" in str(ft.return_type);
    assert len(ft.parameters) == 4;
}

test "bundled compose_widgets.txt is ingested live at checker init" {
    # The wiring end-to-end: postinit reads the bundled metalava file and installs
    # every @Composable as a client-scoped typed symbol — no hand-written stub, no
    # explicit call. A fresh evaluator must already carry the widget surface.
    ev = JacProgram().get_type_evaluator();
    assert os.path.exists(ev._COMPOSE_WIDGETS_FILE_PATH) , (
        "the bundled widget signature file must ship next to the .pyi stubs"
    );
    g = ev.js_globals_module.names_in_scope;
    for name in ("Button", "Text", "Column", "Row", "Scaffold", "TextField") {
        assert name in g , f"{name} should be installed from compose_widgets.txt";
    }
    # types survive the file round-trip: Button keeps its Composable return and
    # its modifier param is a ModifierChain.
    ft = ev.get_type_of_symbol(g.get("Button"));
    assert "Composable" in str(ft.return_type);
    bykind = {p.name: str(p.param_type) for p in ft.parameters};
    assert "ModifierChain" in bykind["modifier"];
    assert "None" in str(bykind["onClick"]) , "onClick is an event: () -> None";
}

# ── Part 3: ingested Modifier surface ────────────────────────────────────────

test "bundled Modifier chain type-checks and chains in client context" {
    # Real names from compose_modifiers.txt resolve on the `Modifier` glob, each
    # returns a ModifierChain so calls chain, and prim args are checked.
    assert not _errors_for(
        "def f -> any {\n    return Modifier.padding(8.dp).fillMaxWidth().clickable(enabled=True);\n}\n",
        ".jac"
    );
    assert not _errors_for(
        "def f -> any {\n    return Modifier.size(24.dp).background(0);\n}\n", ".jac"
    );
}

test "unknown Modifier method is a type error" {
    # A misspelled/absent modifier must NOT resolve — the surface is closed to
    # exactly the ingested names (guards the fillMaxSize typo test in gen_pass).
    assert _errors_for(
        "def f -> any {\n    return Modifier.filMaxWidth();\n}\n", ".jac"
    );
}

test "Modifier methods are ingested live at checker init" {
    ev = JacProgram().get_type_evaluator();
    assert os.path.exists(ev._COMPOSE_MODIFIERS_FILE_PATH) , (
        "the bundled modifier signature file must ship next to the .pyi stubs"
    );
    mc = ev._get_type_from_module(ev.js_globals_module, "ModifierChain");
    members = mc.shared.symbol_table.names_in_scope;
    for name in (
        "padding",
        "fillMaxWidth",
        "clickable",
        "offset",
        "weight",
        "zIndex"
    ) {
        assert name in members , f"{name} should be installed from compose_modifiers.txt";
    }
}

# ── Part 4: ingested const namespaces (Arrangement / Alignment / Color) ───────

test "const namespaces resolve their members in client context" {
    # Real names from compose_consts.txt resolve off the `Arrangement`/`Alignment`/
    # `Color` client globals; previously these were an Unknown-type member error.
    assert not _errors_for(
        "def f -> any {\n    return Arrangement.Center;\n}\n", ".jac"
    );
    assert not _errors_for(
        "def f -> any {\n    return Alignment.CenterVertically;\n}\n", ".jac"
    );
    assert not _errors_for("def f -> any {\n    return Color.Red;\n}\n", ".jac");
}

test "a typo'd const member is a type error" {
    # The surface is closed to exactly the ingested names — a misspelling is caught
    # before Gradle (the whole point of ingesting them under type_check).
    assert _errors_for("def f -> any {\n    return Arrangement.Centre;\n}\n", ".jac");
    assert _errors_for("def f -> any {\n    return Color.Puce;\n}\n", ".jac");
}

test "Color stays callable — the numeric ULong constructor is not regressed" {
    # A2 upgrades Color to a real value class; until then `Color(0xFF..)` must keep
    # type-checking via ColorNamespace.__call__ so named + numeric forms coexist.
    assert not _errors_for(
        "def f -> any {\n    return Color(4294901760);\n}\n", ".jac"
    );
}

test "const members flow into widget props" {
    # The DX payoff: a named color / alignment passes through a real JSX prop.
    assert not _errors_for(
        "def f -> Composable {\n    return <Text color={Color.Red}>\"hi\"</Text>;\n}\n",
        ".jac"
    );
    assert not _errors_for(
        "def f -> Composable {\n    return <Box contentAlignment={Alignment.Center}>\"x\"</Box>;\n}\n",
        ".jac"
    );
}

test "const namespaces are ingested live at checker init" {
    ev = JacProgram().get_type_evaluator();
    assert os.path.exists(ev._COMPOSE_CONSTS_FILE_PATH) , (
        "the bundled const signature file must ship next to the .pyi stubs"
    );
    for (ns, member) in {
        "ArrangementNamespace": "Center",
        "AlignmentNamespace": "CenterVertically",
        "ColorNamespace": "Red"
    }.items() {
        cls = ev._get_type_from_module(ev.js_globals_module, ns);
        members = cls.shared.symbol_table.names_in_scope;
        assert member in members , f"{member} should be installed on {ns}";
    }
}

# ── Part 5: default-on safety net (A4) ───────────────────────────────────────
# type_check now defaults ON for [client.android]. That is only safe if a page
# written in idiomatic Compose Jac — every Kotlin-ism the checker was taught —
# type-checks with zero false errors. This is the whole-surface regression gate.

test "a full idiomatic Compose page type-checks with no false errors" {
    page = "def HomeScreen -> Composable {\n"
    "    items = [1, 2, 3];\n"
    "    return <Column\n"
    "        modifier={Modifier.padding(16.dp).fillMaxWidth()}\n"
    "        verticalArrangement={Arrangement.Center}\n"
    "        horizontalAlignment={Alignment.CenterHorizontally}\n"
    "    >\n"
    "        <Text color={Color.Red}>\"Count: \" + str(items.len)</Text>\n"
    "        <Button onClick={lambda -> None { print(\"hi\"); }}>\n"
    "            <Text>\"Press\"</Text>\n"
    "        </Button>\n"
    "    </Column>;\n"
    "}\n";
    assert not _errors_for(page, ".jac");
}

test "a typo'd modifier in a page is still caught under default-on checking" {
    page = "def f -> any {\n    return Modifier.paddng(16.dp);\n}\n";
    assert _errors_for(page, ".jac");
}

# ── Part 6: Lazy list + scope-receiver surface (A3) ──────────────────────────
# LazyColumn/LazyRow carry the same arrangement/alignment layout props as their
# eager Column/Row counterparts, and their `items {}` DSL is expressed in this
# dialect as a JSX list-comprehension child. Scope-receiver-only Modifier
# extensions (`weight`, `align`) are flattened onto ModifierChain, so an
# idiomatic Lazy page type-checks while typos in either surface are still caught.

test "an idiomatic LazyColumn page with arrangement + comprehension children is clean" {
    page = "def Feed -> Composable {\n"
    "    rows = [\"a\", \"b\", \"c\"];\n"
    "    return <LazyColumn\n"
    "        modifier={Modifier.fillMaxSize().padding(8.dp)}\n"
    "        verticalArrangement={Arrangement.SpaceBetween}\n"
    "        horizontalAlignment={Alignment.CenterHorizontally}\n"
    "    >\n"
    "        {[<Row modifier={Modifier.fillMaxWidth().weight(1.0)}>\n"
    "            <Text color={Color.Red}>{r}</Text>\n"
    "        </Row> for r in rows]}\n"
    "    </LazyColumn>;\n"
    "}\n";
    assert not _errors_for(page, ".jac");
}

test "LazyRow carries horizontalArrangement + verticalAlignment layout props" {
    page = "def f -> Composable {\n"
    "    xs = [1, 2];\n"
    "    return <LazyRow\n"
    "        horizontalArrangement={Arrangement.SpaceEvenly}\n"
    "        verticalAlignment={Alignment.CenterVertically}\n"
    "    >{[<Text>{str(x)}</Text> for x in xs]}</LazyRow>;\n"
    "}\n";
    assert not _errors_for(page, ".jac");
}

test "an unknown prop on a Lazy list is still flagged" {
    page = "def f -> Composable {\n"
    "    xs = [1];\n"
    "    return <LazyColumn verticalArrangment={Arrangement.Center}>"
    "{[<Text>{str(x)}</Text> for x in xs]}</LazyColumn>;\n"
    "}\n";
    assert _errors_for(page, ".jac");
}

test "a bad primitive prop value on a Lazy list is still flagged" {
    page = "def f -> Composable {\n"
    "    xs = [1];\n"
    "    return <LazyColumn userScrollEnabled=\"yes\">"
    "{[<Text>{str(x)}</Text> for x in xs]}</LazyColumn>;\n"
    "}\n";
    assert _errors_for(page, ".jac");
}

test "scope-receiver Modifier extensions resolve, and a typo is caught" {
    assert not _errors_for(
        "def f -> any {\n    return Modifier.weight(1.0).align(Alignment.CenterHorizontally);\n}\n",
        ".jac"
    );
    assert _errors_for("def f -> any {\n    return Modifier.wieght(1.0);\n}\n", ".jac");
}

# ── Part 5: target isolation (P0 #1) ─────────────────────────────────────────
# The Compose ambient vocabulary is gated on the Compose *target*, not on generic
# client codespace: a plain React `.jac` (client, but not a Compose project)
# must not see Compose names, even though it is `in_client_context()`.

test "Compose widgets do not leak into a plain (non-Compose) client module" {
    # A wrong-typed prop is a type error only when `Button` resolves to the typed
    # Compose widget. In a plain client project (client codespace, but not a
    # Compose target) `Button` does not resolve, so the same snippet is clean —
    # proving the Compose surface is gated on the target, not on client context.
    # (Unknown ambient names are permissive in client code, so isolation shows up
    # as the *absence* of the Compose-specific type error, not a new one.)
    snippet = "def f -> any {\n    return <Button onClick={lambda -> None { }} enabled=\"yes\">\"x\"</Button>;\n}\n";
    assert not _errors_in(_react_tmp, snippet, ".jac", "react") , "the typed-Button error must NOT fire outside a Compose project";
    assert _errors_in(_tmp, snippet) , "the same wrong-typed prop must be flagged inside a Compose project";
}

test "Modifier namespace does not leak into a plain client module" {
    # A *valid* Modifier chain type-checks clean only when `Modifier` resolves to
    # the ingested ModifierChain. In a plain client project `Modifier` resolves to
    # Unknown, so even a well-formed chain errors ("cannot access attribute on
    # Unknown") — the mirror image of the Compose case, proving Modifier is gated
    # on the target.
    chain = "def f -> any {\n    return Modifier.padding(8.dp).fillMaxWidth();\n}\n";
    assert not _errors_in(_tmp, chain) , f"a valid Modifier chain must type-check inside a Compose project";
    assert _errors_in(_react_tmp, chain, ".jac", "react") , "Modifier must NOT resolve to ModifierChain outside a Compose project";
}

test ".dp / .sp extensions are Compose-target-only, permissive elsewhere" {
    # Builtin member access is permissive, so `.dp` outside a Compose project is
    # not an error — but it must not resolve to the Compose `Dp` type either.
    ev = JacProgram().get_type_evaluator();
    ext = ev.prefetch.int_class.shared.symbol_table.names_in_scope.get("dp");
    assert ext is not None and "Dp" in str(ev.get_type_of_symbol(ext)) , "the .dp extension is still installed on int (resolution is gated, not the install)";
}
