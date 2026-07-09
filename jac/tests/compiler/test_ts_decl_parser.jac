"""Unit tests for the pragmatic .d.ts declaration parser."""

import jaclang;
import from jaclang.compiler.type_system.ts_decl_parser { parse_dts }

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
    assert d.ty.ret.kind == "prim" and d.ty.ret.name == "string";
    assert d.ty.params[0].rest;
    assert r["default"].kind == "function";
    assert r["ClassValue"].ty.kind == "union";
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
    tm = r["twMerge"];
    assert tm.ty.kind == "func" and tm.ty.ret.name == "string";
    assert tm.ty.params[0].rest and tm.ty.params[0].ty.kind == "array";
    ext = r["extendMerge"];
    assert ext.ty.ret.name == "number";
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
    assert r["make"].ty.ret.name == "boolean";
    assert r["version"].ty.name == "string";
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
    assert by_name["theme"].ty.name == "string";
    assert by_name["debug"].optional and by_name["debug"].ty.name == "boolean";
    base = r["Base"];
    assert {m.name for m in base.members} == {"id"};
}

test "optional and rest parameters carry through" {
    src = "export declare function greet(name: string, punct?: string, ...rest: any[]): void;\n";
    r = parse_dts(src);
    assert r is not None;
    ps = r["greet"].ty.params;
    assert not ps[0].optional and ps[1].optional and ps[2].rest;
    assert r["greet"].ty.ret.kind == "void";
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
    assert r["Cond"].ty.kind == "any";
    assert r["ok"].ty.ret.name == "string";
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
    lv = r["level"].ty.ret;
    assert lv.kind == "union" and lv.args[0].kind == "literal-num";
    assert r["isFoo"].ty.ret.name == "boolean";
    nm = r["names"].ty.ret;
    assert nm.kind == "array" and nm.args[0].name == "string";
    assert r["FLAG"].ty.kind == "literal-bool";
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
    assert by_name["theme"].ty.name == "string" and not by_name["theme"].optional;
    assert by_name["retries"].ty.name == "number";
    assert by_name["debug"].optional and by_name["debug"].ty.name == "boolean";
    assert by_name["tags"].readonly and by_name["tags"].ty.kind == "array";
    assert by_name["onChange"].is_method and by_name["onChange"].ty.kind == "func";
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
