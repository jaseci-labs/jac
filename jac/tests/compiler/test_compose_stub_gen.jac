"""Tests for compose_stub_gen — AndroidX signature files → typed widget stubs.

The fixture mirrors the metalava API-signature format AndroidX publishes for
androidx.compose.material3 (one @Composable method per line, `optional` marking
defaulted params, `Function0/1<...,kotlin.Unit>` for lambdas). Real material3
current.txt is wired in at build time; this pins the parse + classification.
"""

import from jaclang.compiler.type_system.compose_signatures {
    ComposeParamKind,
    parse_signature_text,
    parse_modifier_text,
    parse_const_text,
    slot_table
}
import from jaclang.compiler.passes.compose.compose_stub_gen { generate }

glob CONST_FIXTURE: str = "package androidx.compose.foundation.layout {\n"
     "  public final class Arrangement {\n"
     "    field public static final androidx.compose.foundation.layout.Arrangement INSTANCE;\n"
     "    property public final androidx.compose.foundation.layout.Arrangement.HorizontalOrVertical Center;\n"
     "    property public final androidx.compose.foundation.layout.Arrangement.Horizontal Start;\n"
     "    method public androidx.compose.foundation.layout.Arrangement.Horizontal getEnd();\n"
     "  }\n"
     "}\n"
     "package androidx.compose.ui {\n"
     "  public static final class Alignment.Companion {\n"
     "    property public final androidx.compose.ui.Alignment Center;\n"
     "    property public final androidx.compose.ui.Alignment.Vertical CenterVertically;\n"
     "  }\n"
     "}\n"
     "package androidx.compose.ui.graphics {\n"
     "  public static final class Color.Companion {\n"
     "    property public final long Red;\n"
     "    property public final long Blue;\n"
     "  }\n"
     "}\n",
     MOD_FIXTURE: str = "package androidx.compose.foundation.layout {\n"
     "  public final class SizeKt {\n"
     "    method public static androidx.compose.ui.Modifier fillMaxWidth(androidx.compose.ui.Modifier, optional float fraction);\n"
     "    method public static androidx.compose.ui.Modifier size(androidx.compose.ui.Modifier, androidx.compose.ui.unit.Dp size);\n"
     "    method public static androidx.compose.ui.Modifier padding(androidx.compose.ui.Modifier, optional androidx.compose.ui.unit.Dp all);\n"
     "    method public static androidx.compose.ui.Modifier padding(androidx.compose.ui.Modifier, optional androidx.compose.ui.unit.Dp horizontal, optional androidx.compose.ui.unit.Dp vertical);\n"
     "  }\n"
     "  public final class ClickableKt {\n"
     "    method public static androidx.compose.ui.Modifier clickable(androidx.compose.ui.Modifier, optional boolean enabled, kotlin.jvm.functions.Function0<kotlin.Unit> onClick);\n"
     "  }\n"
     "  public final class WidgetKt {\n"
     "    method @androidx.compose.runtime.Composable public static void Button(kotlin.jvm.functions.Function0<kotlin.Unit> onClick);\n"
     "  }\n"
     "}\n",
     FIXTURE: str = "package androidx.compose.material3 {\n"
     "  public final class ButtonKt {\n"
     "    method @androidx.compose.runtime.Composable public static void Button(kotlin.jvm.functions.Function0<kotlin.Unit> onClick, optional androidx.compose.ui.Modifier modifier, optional boolean enabled, kotlin.jvm.functions.Function1<? super androidx.compose.foundation.layout.RowScope,kotlin.Unit> content);\n"
     "    method @androidx.compose.runtime.Composable public static void Button(kotlin.jvm.functions.Function0<kotlin.Unit> onClick, optional androidx.compose.ui.Modifier modifier);\n"
     "  }\n"
     "  public final class SliderKt {\n"
     "    method @androidx.compose.runtime.Composable public static void Slider(float value, kotlin.jvm.functions.Function1<? super java.lang.Float,kotlin.Unit> onValueChange, optional androidx.compose.ui.Modifier modifier, optional boolean enabled);\n"
     "  }\n"
     "  public final class TextKt {\n"
     "    method @androidx.compose.runtime.Composable public static void Text(String text, optional androidx.compose.ui.Modifier modifier, optional long color);\n"
     "  }\n"
     "  public final class ScaffoldKt {\n"
     "    method @androidx.compose.runtime.Composable public static void Scaffold(optional androidx.compose.ui.Modifier modifier, optional kotlin.jvm.functions.Function0<kotlin.Unit> topBar, optional kotlin.jvm.functions.Function0<kotlin.Unit> bottomBar, kotlin.jvm.functions.Function1<? super androidx.compose.foundation.layout.PaddingValues,kotlin.Unit> content);\n"
     "    method @androidx.compose.runtime.Composable public static androidx.compose.material3.ScaffoldState rememberScaffoldState();\n"
     "  }\n"
     "  public final class AlertDialogKt {\n"
     "    method @androidx.compose.runtime.Composable public static void AlertDialog(kotlin.jvm.functions.Function0<kotlin.Unit> onDismissRequest, kotlin.jvm.functions.Function0<kotlin.Unit> confirmButton, optional androidx.compose.ui.Modifier modifier, optional kotlin.jvm.functions.Function0<kotlin.Unit> dismissButton, optional kotlin.jvm.functions.Function0<kotlin.Unit> title, optional kotlin.jvm.functions.Function0<kotlin.Unit> text);\n"
     "  }\n"
     "}\n";

test "parses composable widgets and skips helpers and non-Unit methods" {
    sigs = parse_signature_text(FIXTURE);
    names = {s.name for s in sigs};
    assert "Button" in names;
    assert "Slider" in names;
    assert "Text" in names;
    assert "Scaffold" in names;
    assert "AlertDialog" in names;
    # rememberScaffoldState returns a value (not void) → not a UI widget.
    assert "rememberScaffoldState" not in names;
    assert "ScaffoldState" not in names;
}

test "overloads collapse to the richest signature" {
    sigs = parse_signature_text(FIXTURE);
    byname = {s.name: s for s in sigs};
    # Button has a 2-param and a 4-param overload; keep the 4-param one.
    assert len(byname["Button"].params) == 4;
}

test "parameters classify as modifier / event / slot / value" {
    sigs = parse_signature_text(FIXTURE);
    byname = {s.name: s for s in sigs};
    btn = {p.name: p.kind for p in byname["Button"].params};
    assert btn["onClick"] == ComposeParamKind.EVENT;
    assert btn["modifier"] == ComposeParamKind.MODIFIER;
    assert btn["enabled"] == ComposeParamKind.VALUE;
    assert btn["content"] == ComposeParamKind.SLOT;

    slider = {p.name: p.kind for p in byname["Slider"].params};
    assert slider["value"] == ComposeParamKind.VALUE;
    assert slider["onValueChange"] == ComposeParamKind.EVENT;

    dialog = {p.name: p.kind for p in byname["AlertDialog"].params};
    assert dialog["onDismissRequest"] == ComposeParamKind.EVENT;
    assert dialog["confirmButton"] == ComposeParamKind.SLOT;
    assert dialog["title"] == ComposeParamKind.SLOT;
}

test "slot_table surfaces content slots per widget" {
    table = slot_table(parse_signature_text(FIXTURE));
    assert "content" in table["Scaffold"];
    assert "topBar" in table["Scaffold"];
    assert "bottomBar" in table["Scaffold"];
    # modifier is not a slot
    assert "modifier" not in table["Scaffold"];
    assert "confirmButton" in table["AlertDialog"];
}

test "parse_modifier_text ingests Modifier extensions and drops the receiver" {
    sigs = parse_modifier_text(MOD_FIXTURE);
    names = {s.name for s in sigs};
    assert "fillMaxWidth" in names;
    assert "size" in names;
    assert "padding" in names;
    assert "clickable" in names;
    # the @Composable widget is NOT a modifier extension
    assert "Button" not in names;
    byname = {s.name: s for s in sigs};
    # the unnamed `Modifier` receiver is dropped — only addressable args remain
    assert [p.name for p in byname["fillMaxWidth"].params] == ["fraction"];
    assert [p.name for p in byname["size"].params] == ["size"];
}

test "modifier overloads collapse to the richest signature" {
    byname = {s.name: s for s in parse_modifier_text(MOD_FIXTURE)};
    # padding has a 1-arg and a 2-arg overload; keep the 2-arg one.
    assert len(byname["padding"].params) == 2;
}

test "modifier params classify value vs event lambda" {
    byname = {s.name: s for s in parse_modifier_text(MOD_FIXTURE)};
    clk = {p.name: p.kind for p in byname["clickable"].params};
    assert clk["enabled"] == ComposeParamKind.VALUE;
    assert clk["onClick"] == ComposeParamKind.EVENT;
}

test "emits valid def:pub stub declarations with typed params" {
    out = generate(FIXTURE);
    assert "def:pub Slider(" in out;
    assert "def:pub AlertDialog(" in out;
    assert "-> Composable;" in out;
    # typed param shapes
    assert "modifier: (ModifierChain | None) = None" in out;
    assert "content: (any | None) = None" in out;
    assert "enabled: any = None" in out;
    # generated marker for the ingested widget surface
    assert "GENERATED WIDGETS" in out;
}

# ── const namespaces (Arrangement / Alignment / Color) ───────────────────────

test "parse_const_text groups members by namespace, stripping .Companion" {
    ns = parse_const_text(CONST_FIXTURE);
    # keyed by the simple class name; `Alignment.Companion` / `Color.Companion`
    # collapse to `Alignment` / `Color` (Kotlin reads them off the type).
    assert set(ns.keys()) == {"Arrangement", "Alignment", "Color"} , f"unexpected namespaces: {set(
        ns.keys()
    )}";

    arr = {m.name for m in ns["Arrangement"]};
    assert "Center" in arr and "Start" in arr;
    # a `field ... INSTANCE` self-reference and a `method getEnd()` getter are
    # not addressable constants and must be dropped.
    assert "INSTANCE" not in arr , "INSTANCE self-ref must be skipped";
    assert "End" not in arr and "getEnd" not in arr , "getter methods are not constants";

    al = {m.name for m in ns["Alignment"]};
    assert al == {"Center", "CenterVertically"};

    col = {m.name for m in ns["Color"]};
    assert col == {"Red", "Blue"};
}

test "const members carry their Kotlin type on ptype" {
    ns = parse_const_text(CONST_FIXTURE);
    red = [
        m
        for m in ns["Color"]
        if m.name == "Red"
    ][0];
    assert red.ptype == "long" , f"Color.Red ptype should be long, got {red.ptype}";
}

test "bundled compose_consts.txt parses the shipped namespaces" {
    import os;
    path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
        "jaclang",
        "compiler",
        "type_system",
        "compose_consts.txt"
    );
    assert os.path.exists(path) , f"bundled const file must ship: {path}";
    with open(path) as f {
        ns = parse_const_text(f.read());
    }
    for name in ("Arrangement", "Alignment", "Color") {
        assert name in ns , f"{name} namespace missing from bundled file";
    }
    assert "Center" in {m.name for m in ns["Arrangement"]};
    assert "CenterVertically" in {m.name for m in ns["Alignment"]};
    assert "Red" in {m.name for m in ns["Color"]};
}
