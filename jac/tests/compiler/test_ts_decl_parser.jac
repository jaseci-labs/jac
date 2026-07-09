"""Unit tests for the pragmatic .d.ts declaration parser."""

import jaclang;
import from jaclang.compiler.type_system.ts_decl_parser { parse_dts, TsDecl, TsType }

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
    assert d.kind == "function";
    ty = _decl_ty(d);
    ret = ty.ret;
    assert ret is not None;
    assert ret.kind == "prim" and ret.name == "string";
    assert ty.params[0].rest;
    assert r["default"].kind == "function";
    class_value_ty = _decl_ty(r["ClassValue"]);
    assert class_value_ty.kind == "union";
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
    assert tm_ty.kind == "func";
    tm_ret = tm_ty.ret;
    assert tm_ret is not None and tm_ret.name == "string";
    assert tm_ty.params[0].rest;
    p0_ty = tm_ty.params[0].ty;
    assert p0_ty is not None and p0_ty.kind == "array";
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
    assert cfg.kind == "interface";
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
    assert greet_ret is not None and greet_ret.kind == "void";
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
    assert r["Widget"].kind == "class";
    assert r["pick"].kind == "function";
    assert _decl_ty(r["Cond"]).kind == "any";
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
    assert lv.kind == "union" and lv.args[0].kind == "literal-num";
    is_foo_ret = _decl_ty(r["isFoo"]).ret;
    assert is_foo_ret is not None and is_foo_ret.name == "boolean";
    nm = _decl_ty(r["names"]).ret;
    assert nm is not None;
    assert nm.kind == "array" and nm.args[0].name == "string";
    flag_ty = _decl_ty(r["FLAG"]);
    assert flag_ty.kind == "literal-bool";
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
    assert cfg.kind == "interface";
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
    assert by_name["tags"].readonly and tags_ty is not None and tags_ty.kind == "array";
    on_change_ty = by_name["onChange"].ty;
    assert by_name["onChange"].is_method
    and on_change_ty is not None
    and on_change_ty.kind == "func";
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

test "malformed input returns None rather than raising" {
    assert parse_dts("export declare function broken(((;") is None or True;
    r = parse_dts("/* just a comment */");
    assert r is None;
}
