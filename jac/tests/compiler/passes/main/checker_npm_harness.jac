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
                "export interface Node { value: number; next: Node; }\n"
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
