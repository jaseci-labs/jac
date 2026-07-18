"""Shared harness for npm `.d.ts` type-checker tests (issue #7152).

Materializes synthetic `.jac/client/node_modules` client projects and runs
TypeCheckPass so declaration-ingestion tests stay DRY across modules.
"""

import from pathlib { Path }
import jaclang;
import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
import from jaclang.jac0core.program { JacProgram }

"""Return ``proj_dir/.jac/client/node_modules``."""
def client_node_modules(proj_dir: Path) -> Path {
    return proj_dir / ".jac" / "client" / "node_modules";
}

"""Install one npm package under ``node_modules`` (supports scoped names)."""
def install_npm_pkg(
    node_modules: Path, pkg_name: str, package_json: str, files: dict[str, str]
) -> Path {
    pkg_dir = node_modules;
    for part in pkg_name.split("/") {
        pkg_dir = pkg_dir / part;
    }
    pkg_dir.mkdir(parents=True, exist_ok=True);
    (pkg_dir / "package.json").write_text(package_json);
    for (rel, content) in files.items() {
        f = pkg_dir / rel;
        f.parent.mkdir(parents=True, exist_ok=True);
        f.write_text(content);
    }
    return pkg_dir;
}

"""Write a minimal client ``jac.toml`` plus ``lib/`` for npm-import tests."""
def write_client_jac_project(
    proj_dir: Path,
    project_name: str,
    entry_point: str,
    npm_dep_lines: str,
    strict: bool = False
) -> Path {
    strict_block = '\n[check]\nuntyped-external = "error"\n' if strict else '';
    (proj_dir / "jac.toml").write_text(
        '[project]\nname = "' + project_name + '"\nversion = "0.1.0"\n'
        'entry-point = "' + entry_point + '"\n\n'
        '[dependencies.npm]\n' + npm_dep_lines + strict_block
    );
    (proj_dir / "lib").mkdir(parents=True, exist_ok=True);
    return proj_dir;
}

"""Compile and type-check a client ``.cl.jac`` file; return program + codes."""
def check_npm_file(path: Path) -> tuple[JacProgram, list[str], list[str]] {
    program = JacProgram();
    mod = program.compile(str(path));
    TypeCheckPass(ir_in=mod, prog=program);
    err_codes = [
        e.code.code
        for e in program.errors_had
        if e.code is not None
    ];
    warn_codes = [
        w.code.code
        for w in program.warnings_had
        if w.code is not None
    ];
    return (program, err_codes, warn_codes);
}

def pretty_checker_errors(program: JacProgram) -> str {
    return "\n".join([e.pretty_print() for e in program.errors_had]);
}

"""Materialize a client project with installed npm packages.

- clsx: classic package (main/module + exports with types condition + d.ts)
- tailwind-merge: exports-map-only package (no main/module) with typed d.ts
- untyped-pkg: package with no declarations at all
- @scoped/tool: scoped package, types via @types/scoped__tool

Returns the project root.
"""
def make_npm_client_project(proj_dir: Path, strict: bool = False) -> Path {
    nm = client_node_modules(proj_dir);

    install_npm_pkg(
        nm,
        "clsx",
        '{"name":"clsx","version":"2.1.1",'
        '"exports":{".":{"types":"./clsx.d.mts","import":"./dist/clsx.mjs",'
        '"default":"./dist/clsx.js"}},'
        '"main":"dist/clsx.js","module":"dist/clsx.mjs","types":"clsx.d.mts"}',
        {
            "dist/clsx.mjs": "export function clsx() {}\n",
            "dist/clsx.js": "module.exports.clsx = function () {};\n",
            "clsx.d.mts": (
                "export type ClassValue = ClassArray | ClassDictionary | string | number"
                " | bigint | null | boolean | undefined;\n"
                "export type ClassDictionary = Record<string, any>;\n"
                "export type ClassArray = ClassValue[];\n"
                "export declare function clsx(...inputs: ClassValue[]): string;\n"
                "export default clsx;\n"
            )
        }
    );

    install_npm_pkg(
        nm,
        "tailwind-merge",
        '{"name":"tailwind-merge","version":"2.5.0",'
        '"exports":{".":{"types":"./dist/types.d.ts",'
        '"import":"./dist/bundle-mjs.mjs"}}}',
        {
            "dist/bundle-mjs.mjs": "export function twMerge() {}\n",
            "dist/types.d.ts": (
                "declare const twMerge: (...classLists: Array<string | undefined | null"
                " | false>) => string;\n"
                "export { twMerge };\n"
            )
        }
    );

    install_npm_pkg(
        nm,
        "untyped-pkg",
        '{"name":"untyped-pkg","version":"1.0.0","main":"index.js"}',
        {"index.js": "module.exports.mystery = function () {};\n"}
    );

    install_npm_pkg(
        nm,
        "@scoped/tool",
        '{"name":"@scoped/tool","version":"1.0.0","main":"index.js"}',
        {"index.js": "module.exports.run = function () {};\n"}
    );
    install_npm_pkg(
        nm,
        "@types/scoped__tool",
        '{"name":"@types/scoped__tool","version":"1.0.0"}',
        {"index.d.ts": "export declare function run(cmd: string): number;\n"}
    );

    write_client_jac_project(
        proj_dir,
        "npmfixture",
        "lib/utils.cl.jac",
        'clsx = "^2.1.1"\ntailwind-merge = "^2.5.0"\n',
        strict=strict
    );
    return proj_dir;
}

"""Materialize a client project with one npm package shipping interface d.ts."""
def make_iface_npm_project(proj_dir: Path) -> Path {
    nm = client_node_modules(proj_dir);
    install_npm_pkg(
        nm,
        "cfgpkg",
        '{"name":"cfgpkg","version":"1.0.0",'
        '"exports":{".":{"types":"./dist/index.d.ts",'
        '"import":"./dist/index.mjs"}}}',
        {
            "dist/index.mjs": (
                "export function getConfig() {}\nexport function getDerived() {}\n"
            ),
            "dist/index.d.ts": (
                "export interface Config {\n"
                "    theme: string;\n"
                "    retries: number;\n"
                "    debug?: boolean;\n"
                "    tags: string[];\n"
                "    payload: any;\n"
                "    onChange(v: string): void;\n"
                "    greet(name: string): string;\n"
                "    over(v: number): string;\n"
                "}\n"
                "export interface Base { id: string; }\n"
                "export interface Derived extends Base { extra: number; }\n"
                "export declare function getConfig(): Config;\n"
                "export declare function getDerived(): Derived;\n"
            )
        }
    );
    write_client_jac_project(
        proj_dir, "ifacefixture", "lib/app.cl.jac", 'cfgpkg = "^1.0.0"\n'
    );
    return proj_dir;
}

"""Materialize a client project with cross/recursive interface d.ts (issue #7319).

Exercises the cross-interface, recursive, array-of-interface, and
interface-via-typealias shapes that previously collapsed to foreign `any`
because shell-driven synthesis re-entered the cache while the sentinel was
still `None`. Returns the project root.
"""
def make_relational_npm_project(proj_dir: Path) -> Path {
    nm = client_node_modules(proj_dir);
    install_npm_pkg(
        nm,
        "relpkg",
        '{"name":"relpkg","version":"1.0.0",'
        '"exports":{".":{"types":"./dist/index.d.ts",'
        '"import":"./dist/index.mjs"}}}',
        {
            "dist/index.mjs": (
                "export function getParent() {}\n"
                "export function getHead() {}\n"
                "export function getHolder() {}\n"
            ),
            "dist/index.d.ts": (
                "export interface Child { name: string; }\n"
                "export interface Parent { child: Child; children: Child[]; }\n"
                "export interface Node { value: number; next: Node; parent?: Node; }\n"
                "export type Wrapped = Child;\n"
                "export interface Holder { wrapped: Wrapped; }\n"
                "export declare function getParent(): Parent;\n"
                "export declare function getHead(): Node;\n"
                "export declare function getHolder(): Holder;\n"
            )
        }
    );
    write_client_jac_project(
        proj_dir, "relfixture", "lib/app.cl.jac", 'relpkg = "^1.0.0"\n'
    );
    return proj_dir;
}

"""Materialize a client project with generic interface heritage (issue #7319).

Exercises `Derived extends Base<string>` -- the type argument is dropped by
the parser/synthesizer, so the inherited `id: T` member degrades to gradual
`any` while the derived class's own members stay precise. Used to document
that degradation rather than silently collapse the whole interface.
"""
def make_generic_npm_project(proj_dir: Path) -> Path {
    nm = client_node_modules(proj_dir);
    install_npm_pkg(
        nm,
        "genpkg",
        '{"name":"genpkg","version":"1.0.0",'
        '"exports":{".":{"types":"./dist/index.d.ts",'
        '"import":"./dist/index.mjs"}}}',
        {
            "dist/index.mjs": "export function getDerived() {}\n",
            "dist/index.d.ts": (
                "export interface Base<T> { id: T; }\n"
                "export interface Derived extends Base<string> { extra: number; }\n"
                "export declare function getDerived(): Derived;\n"
            )
        }
    );
    write_client_jac_project(
        proj_dir, "genfixture", "lib/app.cl.jac", 'genpkg = "^1.0.0"\n'
    );
    return proj_dir;
}

"""Materialize a client project with class modifiers and method overloads.

Exercises the member-modifier and overload-degradation synthesis paths:
- ``Widget`` mixes static/private/protected/public members; only the public
  instance member should be synthesized onto the instance.
- ``Api`` declares two ``get`` overloads; duplicate signatures must degrade
  to foreign any rather than collapse to the last (wrong) signature.
"""
def make_modifiers_npm_project(proj_dir: Path) -> Path {
    nm = client_node_modules(proj_dir);
    install_npm_pkg(
        nm,
        "modpkg",
        '{"name":"modpkg","version":"1.0.0",'
        '"exports":{".":{"types":"./dist/index.d.ts",'
        '"import":"./dist/index.mjs"}}}',
        {
            "dist/index.mjs": (
                "export function getWidget() {}\nexport function getApi() {}\n"
            ),
            "dist/index.d.ts": (
                "export declare class Widget {\n"
                "    static version: string;\n"
                "    private secret: string;\n"
                "    protected internal: number;\n"
                "    value: string;\n"
                "}\n"
                "export interface Api {\n"
                "    get(x: string): string;\n"
                "    get(x: number): number;\n"
                "}\n"
                "export declare function getWidget(): Widget;\n"
                "export declare function getApi(): Api;\n"
            )
        }
    );
    write_client_jac_project(
        proj_dir, "modfixture", "lib/app.cl.jac", 'modpkg = "^1.0.0"\n'
    );
    return proj_dir;
}

"""Materialize a client project with cyclic interface heritage (issue #7319).

`CycA extends CycB` while `CycB extends CycA` forms a heritage cycle, which
is impossible in real Jac archetypes but reachable from arbitrary ``.d.ts``
input. The synthesizer must break the cycle so C3 linearization terminates
(previously: ``RecursionError``) and own members still resolve.
"""
def make_cyclic_npm_project(proj_dir: Path) -> Path {
    nm = client_node_modules(proj_dir);
    install_npm_pkg(
        nm,
        "cycpkg",
        '{"name":"cycpkg","version":"1.0.0",'
        '"exports":{".":{"types":"./dist/index.d.ts",'
        '"import":"./dist/index.mjs"}}}',
        {
            "dist/index.mjs": (
                "export function getCycA() {}\nexport function getCycB() {}\n"
            ),
            "dist/index.d.ts": (
                "export interface CycA extends CycB { a: number; }\n"
                "export interface CycB extends CycA { b: string; }\n"
                "export declare function getCycA(): CycA;\n"
                "export declare function getCycB(): CycB;\n"
            )
        }
    );
    write_client_jac_project(
        proj_dir, "cycfixture", "lib/app.cl.jac", 'cycpkg = "^1.0.0"\n'
    );
    return proj_dir;
}

"""Materialize a client project with a callable interface d.ts.

``Handler`` carries a call signature plus a named member. The call signature
is synthesized as a ``__call__`` method so the instance is callable with a
typed return, while ``label`` stays a precise ``str`` field.
"""
def make_callable_npm_project(proj_dir: Path) -> Path {
    nm = client_node_modules(proj_dir);
    install_npm_pkg(
        nm,
        "callpkg",
        '{"name":"callpkg","version":"1.0.0",'
        '"exports":{".":{"types":"./dist/index.d.ts",'
        '"import":"./dist/index.mjs"}}}',
        {
            "dist/index.mjs": "export function getHandler() {}\n",
            "dist/index.d.ts": (
                "export interface Handler {\n"
                "    (x: string): number;\n"
                "    label: string;\n"
                "}\n"
                "export declare function getHandler(): Handler;\n"
            )
        }
    );
    write_client_jac_project(
        proj_dir, "callfixture", "lib/app.cl.jac", 'callpkg = "^1.0.0"\n'
    );
    return proj_dir;
}

"""Materialize a client project exercising documented synthesis degradations.

Shapes the parser/synthesizer models leniently rather than precisely:
- ``Dict`` has only an index signature -- it synthesizes with no named
  members, so any keyed access reports E1030.
- ``Cfg.loose`` has no type annotation (implicit any) -- it degrades to a
  foreign any and flows gradually, while ``theme`` stays a precise str.
- ``Base`` is an ``abstract`` class -- ``abstract`` is transparent to
  synthesis, so it behaves like a normal structural class.
- ``Merged`` is declared twice -- TS declaration merging is unsupported, so
  only one block's members survive.
Returns the project root.
"""
def make_degrade_npm_project(proj_dir: Path) -> Path {
    nm = client_node_modules(proj_dir);
    install_npm_pkg(
        nm,
        "degpkg",
        '{"name":"degpkg","version":"1.0.0",'
        '"exports":{".":{"types":"./dist/index.d.ts",'
        '"import":"./dist/index.mjs"}}}',
        {
            "dist/index.mjs": (
                "export function getDict() {}\n"
                "export function getCfg() {}\n"
                "export function getBase() {}\n"
                "export function getMerged() {}\n"
            ),
            "dist/index.d.ts": (
                "export interface Dict { [key: string]: number; }\n"
                "export interface Cfg { loose; theme: string; }\n"
                "export declare abstract class Base {\n"
                "    name: string;\n"
                "    abstract run(): void;\n"
                "}\n"
                "export interface Merged { a: string; }\n"
                "export interface Merged { b: number; }\n"
                "export declare function getDict(): Dict;\n"
                "export declare function getCfg(): Cfg;\n"
                "export declare function getBase(): Base;\n"
                "export declare function getMerged(): Merged;\n"
            )
        }
    );
    write_client_jac_project(
        proj_dir, "degfixture", "lib/app.cl.jac", 'degpkg = "^1.0.0"\n'
    );
    return proj_dir;
}
