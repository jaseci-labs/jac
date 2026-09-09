import from jaclang.cli.command { Arg, ArgKind, CommandSpec }
import from jaclang.comptime { module_of }

comptime import from jaclang.cli.commands.analysis {
    SPEC_CHECK,
    SPEC_EXPLAIN,
    SPEC_FORMAT,
    SPEC_GEN_PARSER,
    SPEC_PRECOMMIT,
    SPEC_TEST
}
comptime import from jaclang.cli.commands.browse { SPEC_BROWSE }
comptime import from jaclang.cli.commands.build { SPEC_BUILD }
comptime import from jaclang.cli.commands.code { SPEC_CODE }
comptime import from jaclang.cli.commands.config { SPEC_CONFIG }
comptime import from jaclang.cli.commands.db { SPEC_DB }
comptime import from jaclang.cli.commands.execution { SPEC_RUN, SPEC_X }
comptime import from jaclang.cli.commands.fix { SPEC_FIX }
comptime import from jaclang.cli.commands.guide { SPEC_GUIDE }
comptime import from jaclang.cli.commands.mcp { SPEC_MCP_CMD }
comptime import from jaclang.cli.commands.precompile { SPEC_PRECOMPILE }
comptime import from jaclang.cli.commands.project {
    SPEC_CLEAN,
    SPEC_CREATE,
    SPEC_INSTALL,
    SPEC_REMOVE,
    SPEC_UPDATE
}
comptime import from jaclang.cli.commands.tools {
    SPEC_COMPLETIONS,
    SPEC_DOT,
    SPEC_LSP,
    SPEC_TOOL
}
comptime import from jaclang.byllm.cli { SPEC_MODEL }
comptime import from jaclang.cli.shadcn.cli { SPEC_RETHEME }
comptime import from jaclang.client.cli { SPEC_SETUP }
comptime import from jaclang.scale.plugin { SPEC_SCALE_CMD }

comptime VERB_BUDGET: int = 26,
     TOMBSTONED_VERBS: dict[str, str] = {
         "add": "jac install <pkg>",
         "format": "jac fmt",
         "lint": "jac check --lint",
         "deps": "jac install --plan",
         "script": "jac x <name>",
         "jacpack": "jac create --pack <dir>",
         "enter": "jac run --entry <name> <file>",
         "debug": "jac run --debug <file>",
         "start": "jac run --serve [--port N] <file>",
         "dev": "jac run --dev",
         "bundle": "jac build [--as jab|sealed|binary|wheel|npm]",
         "eject": "jac build --as source",
         "nacompile": "jac build <file.jac> --native [--memory managed|rc|nogc] [--lib]",
         "js": "jac tool jac2js <file>",
         "jac2py": "jac tool jac2py <file>",
         "py2jac": "jac tool py2jac <file>",
         "jac2js": "jac tool jac2js <file>",
         "grammar": "jac tool grammar",
         "destroy": "jac scale destroy <file.jac>",
         "status": "jac scale status <file.jac>"
     },
     GROUP_DISPLAY: dict[str, str] = {
         "execution": "Program Execution",
         "analysis": "Code Analysis",
         "transform": "Code Transformation",
         "project": "Project Management",
         "tools": "Development Tools",
         "config": "Configuration",
         "build": "Build",
         "db": "Database",
         "fleet": "Microservices",
         "general": "General"
     },
     GROUP_ORDER: list[str] = [
         "execution",
         "analysis",
         "transform",
         "project",
         "tools",
         "config",
         "build",
         "db",
         "fleet",
         "general"
     ],
     TIER_SECTIONS: dict[str, str] = {
         "core": "Common commands",
         "learn": "Learn & build with AI"
     },
     TIER_ORDER: list[str] = ["core", "learn"];

comptime def _route(spec: CommandSpec) -> CommandSpec {
    spec.handler_module = module_of(spec);
    return spec;
}

comptime ROUTES: list[CommandSpec] = [
         _route(SPEC_BROWSE),
         _route(SPEC_BUILD),
         _route(SPEC_CHECK),
         _route(SPEC_CLEAN),
         _route(SPEC_CODE),
         _route(SPEC_COMPLETIONS),
         _route(SPEC_CONFIG),
         _route(SPEC_CREATE),
         _route(SPEC_DB),
         _route(SPEC_DOT),
         _route(SPEC_EXPLAIN),
         _route(SPEC_FIX),
         _route(SPEC_FORMAT),
         _route(SPEC_GEN_PARSER),
         _route(SPEC_GUIDE),
         _route(SPEC_INSTALL),
         _route(SPEC_LSP),
         _route(SPEC_MCP_CMD),
         _route(SPEC_MODEL),
         _route(SPEC_PRECOMMIT),
         _route(SPEC_PRECOMPILE),
         _route(SPEC_REMOVE),
         _route(SPEC_RETHEME),
         _route(SPEC_RUN),
         _route(SPEC_SCALE_CMD),
         _route(SPEC_SETUP),
         _route(SPEC_TEST),
         _route(SPEC_TOOL),
         _route(SPEC_UPDATE),
         _route(SPEC_X)
     ];

with entry {
    comptime assert len({r.name for r in ROUTES}) == len(ROUTES) , "duplicate command names in the manifest";
    comptime assert len(
        [
            r
            for r in ROUTES
            if not r.hidden
        ]
    )
        <= VERB_BUDGET , f"visible verbs exceed the budget of {VERB_BUDGET}; fold the new capability into an existing verb or remove one";
    comptime assert not [
        r.name
        for r in ROUTES
        if r.name in TOMBSTONED_VERBS
    ] , "a tombstoned verb is registered again; the tombstone table is authoritative";
    comptime assert all(
        [
            r.tier in TIER_SECTIONS
            for r in ROUTES
            if r.tier
        ]
    ) , "a command names a tier that TIER_SECTIONS does not know";
    comptime assert all([r.group in GROUP_DISPLAY for r in ROUTES]) , "a command names a group that GROUP_DISPLAY does not know";
    comptime assert all([r.handler_module and r.handler_name for r in ROUTES]) , "a command spec has no handler";
    comptime assert not [
        r.name
        for r in ROUTES
        if len({a.dest or a.name for a in r.args}) != len(r.args)
    ] , "a command declares two arguments that bind the same name.";
}

def get_command_meta(name: str) -> CommandSpec | None;
def iter_command_meta(include_hidden: bool = False) -> list[CommandSpec];
def known_command_names(include_hidden: bool = False) -> set[str];
def get_groups -> list[str];
