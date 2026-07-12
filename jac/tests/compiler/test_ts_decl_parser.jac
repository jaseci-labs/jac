"""Unit tests for the pragmatic .d.ts declaration parser."""

import jaclang;
import from jaclang.compiler.type_system.ts_decl_parser {
    parse_dts,
    TsDecl,
    TsType,
    TsTypeKind,
    TsDeclKind,
    TsAccess
}

def _decl_ty(decl: TsDecl) -> TsType {
    assert decl.ty is not None;
    return decl.ty;
}

test "parses the real clsx declaration shape" {
    src = (
        "export type ClassValue = ClassArray | ClassDictionary | string | number"
        " | bigint | null | boolean | undefined;\n"
        "export type ClassDictionary = Record<string, any>;\n"
        "export type ClassArray = ClassValue[];\n"
        "export declare function clsx(...inputs: ClassValue[]): string;\n"
        "export default clsx;\n"
    );
    r = parse_dts(src);
    assert r is not None;
    d = r["clsx"];
    assert d.kind == TsDeclKind.FUNCTION;
    ty = _decl_ty(d);
    ret = ty.ret;
    assert ret is not None;
    assert ret.kind == TsTypeKind.PRIM and ret.name == "string";
    assert ty.params[0].rest;
    assert r["default"].kind == TsDeclKind.FUNCTION;
    class_value_ty = _decl_ty(r["ClassValue"]);
    assert class_value_ty.kind == TsTypeKind.UNION;
}

test "parses const function types and export lists" {
    src = (
        "declare const twMerge: (...classLists: Array<string | undefined>) =>"
        " string;\n"
        "declare function extend<T extends string>(config: T): number;\n"
        "export { twMerge, extend as extendMerge };\n"
    );
    r = parse_dts(src);
    assert r is not None;
    assert sorted(r.keys()) == ["extendMerge", "twMerge"];
    tm_ty = _decl_ty(r["twMerge"]);
    assert tm_ty.kind == TsTypeKind.FUNC;
    tm_ret = tm_ty.ret;
    assert tm_ret is not None and tm_ret.name == "string";
    assert tm_ty.params[0].rest;
    p0_ty = tm_ty.params[0].ty;
    assert p0_ty is not None and p0_ty.kind == TsTypeKind.ARRAY;
    ext_ret = _decl_ty(r["extendMerge"]).ret;
    assert ext_ret is not None and ext_ret.name == "number";
}

test "namespace with export-equals promotes members" {
    src = (
        "declare namespace Lib {\n"
        "    function make(kind: string): boolean;\n"
        "    const version: string;\n"
        "    type Mode = 'a' | 'b';\n"
        "}\n"
        "export = Lib;\n"
    );
    r = parse_dts(src);
    assert r is not None;
    assert "make" in r and "version" in r;
    make_ret = _decl_ty(r["make"]).ret;
    assert make_ret is not None and make_ret.name == "boolean";
    version_ty = _decl_ty(r["version"]);
    assert version_ty.name == "string";
}

test "namespace interface members parse with heritage" {
    src = (
        "declare namespace Lib {\n"
        "    export interface Base { id: string; }\n"
        "    export interface Config extends Base {\n"
        "        theme: string;\n"
        "        debug?: boolean;\n"
        "    }\n"
        "}\n"
        "export = Lib;\n"
    );
    r = parse_dts(src);
    assert r is not None;
    cfg = r["Config"];
    assert cfg.kind == TsDeclKind.INTERFACE;
    assert cfg.heritage == ["Base"];
    by_name = {m.name: m for m in cfg.members};
    assert set(by_name.keys()) == {"theme", "debug"};
    theme_ty = by_name["theme"].ty;
    assert theme_ty is not None
    and theme_ty.name == "string"
    and not by_name["theme"].optional;
    debug_ty = by_name["debug"].ty;
    assert by_name["debug"].optional
    and debug_ty is not None
    and debug_ty.name == "boolean";
    base = r["Base"];
    assert {m.name for m in base.members} == {"id"};
}

test "optional and rest parameters carry through" {
    src = "export declare function greet(name: string, punct?: string, ...rest: any[]): void;\n";
    r = parse_dts(src);
    assert r is not None;
    greet_ty = _decl_ty(r["greet"]);
    ps = greet_ty.params;
    assert not ps[0].optional and ps[1].optional and ps[2].rest;
    greet_ret = greet_ty.ret;
    assert greet_ret is not None and greet_ret.kind == TsTypeKind.VOID;
}

test "unmodelable constructs degrade to any instead of failing" {
    src = (
        "import { X } from './x';\n"
        "export * from './base';\n"
        "export declare class Widget<T> extends Base { render(): void; }\n"
        "export declare function pick<T, K extends keyof T>(o: T, k: K[]): Pick<T, K>;\n"
        "export type Cond<T> = T extends string ? T : never;\n"
        "export declare function ok(): string;\n"
    );
    r = parse_dts(src);
    assert r is not None;
    assert r["Widget"].kind == TsDeclKind.CLASS;
    assert r["pick"].kind == TsDeclKind.FUNCTION;
    assert _decl_ty(r["Cond"]).kind == TsTypeKind.ANY;
    ok_ret = _decl_ty(r["ok"]).ret;
    assert ok_ret is not None and ok_ret.name == "string";
}

test "literal types, type predicates, and readonly arrays" {
    src = (
        "export declare function level(): 1 | 2 | 3;\n"
        "export declare function isFoo(x: unknown): x is Foo;\n"
        "export declare function names(): readonly string[];\n"
        "export declare const FLAG: true;\n"
    );
    r = parse_dts(src);
    assert r is not None;
    lv = _decl_ty(r["level"]).ret;
    assert lv is not None;
    assert lv.kind == TsTypeKind.UNION and lv.args[0].kind == TsTypeKind.LITERAL_NUM;
    is_foo_ret = _decl_ty(r["isFoo"]).ret;
    assert is_foo_ret is not None and is_foo_ret.name == "boolean";
    nm = _decl_ty(r["names"]).ret;
    assert nm is not None;
    assert nm.kind == TsTypeKind.ARRAY and nm.args[0].name == "string";
    flag_ty = _decl_ty(r["FLAG"]);
    assert flag_ty.kind == TsTypeKind.LITERAL_BOOL;
}

test "interface captures property members with types and optionality" {
    src = (
        "export interface Config {\n"
        "    theme: string;\n"
        "    retries: number;\n"
        "    debug?: boolean;\n"
        "    readonly tags: string[];\n"
        "    onChange(v: string): void;\n"
        "}\n"
    );
    r = parse_dts(src);
    assert r is not None;
    cfg = r["Config"];
    assert cfg.kind == TsDeclKind.INTERFACE;
    by_name = {m.name: m for m in cfg.members};
    assert set(by_name.keys()) == {"theme", "retries", "debug", "tags", "onChange"};
    theme_ty = by_name["theme"].ty;
    assert theme_ty is not None
    and theme_ty.name == "string"
    and not by_name["theme"].optional;
    retries_ty = by_name["retries"].ty;
    assert retries_ty is not None and retries_ty.name == "number";
    debug_ty = by_name["debug"].ty;
    assert by_name["debug"].optional
    and debug_ty is not None
    and debug_ty.name == "boolean";
    tags_ty = by_name["tags"].ty;
    assert by_name["tags"].readonly
    and tags_ty is not None
    and tags_ty.kind == TsTypeKind.ARRAY;
    on_change_ty = by_name["onChange"].ty;
    assert by_name["onChange"].is_method
    and on_change_ty is not None
    and on_change_ty.kind == TsTypeKind.FUNC;
}

test "interface captures extends heritage" {
    src = (
        "export interface Base { id: string; }\n"
        "export interface Derived extends Base { extra: number; }\n"
    );
    r = parse_dts(src);
    assert r is not None;
    assert r["Derived"].heritage == ["Base"];
    assert {m.name for m in r["Derived"].members} == {"extra"};
}

test "qualified and generic heritage is preserved as full name" {
    # Regression: parse_heritage previously recorded only the first identifier,
    # so `extends React.HTMLAttributes<HTMLDivElement>` became ["React"] instead
    # of the fully-qualified base name. Generic args are consumed and dropped;
    # local single-name bases are unchanged.
    src = (
        "export interface Props extends React.HTMLAttributes<HTMLDivElement> {\n"
        "    className?: string;\n"
        "}\n"
        "export interface Plain extends Base { ok: boolean; }\n"
        "export interface Base { id: string; }\n"
    );
    r = parse_dts(src);
    assert r is not None;
    assert r["Props"].heritage == ["React.HTMLAttributes"];
    assert r["Plain"].heritage == ["Base"];
    assert {m.name for m in r["Props"].members} == {"className"};
}

test "malformed input returns None rather than raising" {
    # parse_dts must swallow parse errors and return None for anything it
    # cannot model, rather than raising out of the type checker. Previously
    # the first case asserted `... is None or True`, which is a tautology
    # and never exercised the degrade-gracefully contract.
    for malformed in [
        "export declare function broken(((;",  # malformed params
        "/* just a comment */",  # no declarations
        "",  # empty input
        "export declare const x: 'unterminated;",  # unterminated string
        "export declare const x: /* unterminated",  # unterminated block
        "export = Foo;",  # export-eq to unknown name
        "@#$%^&*",  # garbage tokens

    ] {
        assert parse_dts(malformed) is None , (
            f"Expected None for malformed input {malformed!r}"
        );
    }
}

test "default exported class preserves members" {
    # Regression: _parse_export_default previously skipped the class body and
    # emitted an empty TsDecl(name='default', kind=CLASS), losing every member.
    # A named exported class with the same body returned 2 members, so default
    # classes must now go through the same struct/class path.
    src = (
        "export default class Widget {\n"
        "    value: string;\n"
        "    run(x: number): boolean;\n"
        "}\n"
    );
    r = parse_dts(src);
    assert r is not None;
    d = r["default"];
    assert d.kind == TsDeclKind.CLASS;
    by_name = {m.name: m for m in d.members};
    assert set(by_name.keys()) == {"value", "run"};
    value_ty = by_name["value"].ty;
    assert value_ty is not None and value_ty.name == "string";
    assert by_name["run"].is_method;
    run_ty = by_name["run"].ty;
    assert run_ty is not None and run_ty.kind == TsTypeKind.FUNC;
}

test "default exported class preserves name, heritage, and members" {
    src = (
        "export interface Base { id: string; }\n"
        "export default class Widget extends Base { extra: number; }\n"
    );
    r = parse_dts(src);
    assert r is not None;
    d = r["default"];
    assert d.kind == TsDeclKind.CLASS;
    assert d.heritage == ["Base"];
    assert {m.name for m in d.members} == {"extra"};
    # The class name is local to the module; only "default" is exported.
    assert "default" in r and "Base" in r and "Widget" not in r;
}

test "anonymous default class preserves members" {
    src = "export default class {\n" "    value: string;\n" "}\n";
    r = parse_dts(src);
    assert r is not None;
    d = r["default"];
    assert d.kind == TsDeclKind.CLASS;
    assert {m.name for m in d.members} == {"value"};
}

test "class modifiers are captured on members" {
    # Regression: parse_members used to skip public/private/protected/static
    # and emit every member as a public instance field, so static and private
    # members were mis-modeled. Modifiers are now recorded as metadata.
    src = (
        "export declare class Widget {\n"
        "    static version: string;\n"
        "    private secret: string;\n"
        "    protected internal: number;\n"
        "    value: string;\n"
        "}\n"
    );
    r = parse_dts(src);
    assert r is not None;
    d = r["Widget"];
    by_name = {m.name: m for m in d.members};
    assert set(by_name.keys()) == {"version", "secret", "internal", "value"};
    assert by_name["version"].is_static;
    assert by_name["secret"].access == TsAccess.PRIVATE;
    assert by_name["internal"].access == TsAccess.PROTECTED;
    assert (
        not by_name["value"].is_static and by_name["value"].access == TsAccess.PUBLIC
    );
}

test "overloaded methods are kept as separate members" {
    # Regression: duplicate method/property names overwrote each other during
    # synthesis, collapsing overloads to a single (wrong) signature. The
    # parser must retain every signature so synthesis can degrade duplicates
    # to foreign any instead of silently picking the last one.
    src = (
        "export interface Api {\n"
        "    get(x: string): string;\n"
        "    get(x: number): number;\n"
        "}\n"
    );
    r = parse_dts(src);
    assert r is not None;
    gets = [
        m
        for m in r["Api"].members
        if m.name == "get"
    ];
    assert len(gets) == 2;
    assert all(m.is_method for m in gets);
}

test "callable interface records call signature and named members" {
    # Regression: call/construct signatures were parsed then discarded, so a
    # callable interface silently lost its callability. The first call
    # signature is now recorded on the decl; named members are preserved.
    src = (
        "export interface Fn {\n"
        "    (x: string): number;\n"
        "    label: string;\n"
        "}\n"
    );
    r = parse_dts(src);
    assert r is not None;
    d = r["Fn"];
    assert {m.name for m in d.members} == {"label"};
    assert d.call_sig is not None;
    assert d.call_sig.kind == TsTypeKind.FUNC;
    cs_ret = d.call_sig.ret;
    assert cs_ret is not None and cs_ret.name == "number";
}

test "construct signatures are not recorded as call signatures" {
    src = (
        "export interface Ctor {\n"
        "    new (x: string): Ctor;\n"
        "    label: string;\n"
        "}\n"
    );
    r = parse_dts(src);
    assert r is not None;
    d = r["Ctor"];
    assert {m.name for m in d.members} == {"label"};
    # Construct signatures are not modeled; call_sig stays None.
    assert d.call_sig is None;
}

test "declare type keyword parses like a bare type alias" {
    # Both the bare `type` and the ambient `declare type` spellings must parse
    # to a TYPEALIAS. Only the bare form was previously exercised.
    src = "type Foo = number;\ndeclare type Bar = string;\n";
    r = parse_dts(src);
    assert r is not None;
    assert r["Foo"].kind == TsDeclKind.TYPEALIAS;
    assert r["Bar"].kind == TsDeclKind.TYPEALIAS;
    foo_ty = _decl_ty(r["Foo"]);
    bar_ty = _decl_ty(r["Bar"]);
    assert foo_ty.kind == TsTypeKind.PRIM and foo_ty.name == "number";
    assert bar_ty.kind == TsTypeKind.PRIM and bar_ty.name == "string";
}

test "abstract classes and members parse transparently" {
    # `abstract` (on the class and on members) is a modifier the parser eats
    # without dropping the declaration: the class is a CLASS, both members are
    # retained, and a subclass records its heritage.
    src = (
        "declare abstract class A {\n"
        "    abstract foo(): void;\n"
        "    bar: string;\n"
        "}\n"
        "declare class C extends A {}\n"
    );
    r = parse_dts(src);
    assert r is not None;
    assert r["A"].kind == TsDeclKind.CLASS;
    assert {m.name for m in r["A"].members} == {"foo", "bar"};
    assert r["C"].heritage == ["A"];
}

test "index signatures are dropped, leaving no named members" {
    # An index signature `[key: string]: T` is not modeled: the interface
    # parses with zero named members rather than raising. (Documents the
    # degradation exercised at the checker level.)
    src = "export interface Dict { [key: string]: number; }\n";
    r = parse_dts(src);
    assert r is not None;
    assert r["Dict"].kind == TsDeclKind.INTERFACE;
    assert {m.name for m in r["Dict"].members} == set();
}

test "implicit-any members parse with no type" {
    # A member with no type annotation (implicit any) parses with ty None; an
    # un-annotated method still parses as a FUNC method. Neither crashes the
    # parser.
    src = "declare class C {\n" "    publicMember;\n" "    publicFunction(x);\n" "}\n";
    r = parse_dts(src);
    assert r is not None;
    by_name = {m.name: m for m in r["C"].members};
    assert set(by_name.keys()) == {"publicMember", "publicFunction"};
    assert by_name["publicMember"].ty is None;
    assert not by_name["publicMember"].is_method;
    assert by_name["publicFunction"].is_method;
    pf_ty = by_name["publicFunction"].ty;
    assert pf_ty is not None and pf_ty.kind == TsTypeKind.FUNC;
}

test "export as namespace UMD line is ignored, siblings survive" {
    # A UMD `export as namespace N` global-binding line has no structural
    # meaning here; it is skipped gracefully while other exports remain.
    src = "export var X;\nexport interface A { b: number; }\nexport as namespace N;\n";
    r = parse_dts(src);
    assert r is not None;
    assert "X" in r and "A" in r;
    assert "N" not in r;
    assert {m.name for m in r["A"].members} == {"b"};
}
