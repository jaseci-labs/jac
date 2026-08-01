import argparse;
import from jaclang.cli.command { ArgKind, arg_consumes_value, resolve_arg_typ }
import from jaclang.cli.manifest { ArgMeta, CommandMeta }

impl add_argument(parser: argparse.ArgumentParser, arg: ArgMeta) -> None {
    kind = arg.kind;
    typ = resolve_arg_typ(arg.typ);
    kwargs: dict = {"help": arg.help};
    if arg.choices {
        kwargs["choices"] = arg.choices;
    }
    if arg.metavar {
        kwargs["metavar"] = arg.metavar;
    }
    if arg.dest {
        kwargs["dest"] = arg.dest;
    }

    if kind == ArgKind.POSITIONAL {
        if arg.default is not None {
            kwargs["nargs"] = "?";
            kwargs["default"] = arg.default;
        }
        parser.add_argument(arg.name, **kwargs);
    } elif kind == ArgKind.MULTI_POSITIONAL {
        kwargs["nargs"] = "+";
        if arg.default is not None {
            kwargs["default"] = arg.default;
            kwargs["nargs"] = "*";
        }
        parser.add_argument(arg.name, **kwargs);
    } elif kind == ArgKind.MULTI_OPTION {
        kwargs["nargs"] = "*";
        if arg.default is not None {
            kwargs["default"] = arg.default;
        }
        if arg.short {
            parser.add_argument(f"-{arg.short}", f"--{arg.name}", **kwargs);
        } else {
            parser.add_argument(f"--{arg.name}", **kwargs);
        }
    } elif kind == ArgKind.APPEND {
        kwargs["action"] = "append";
        kwargs["nargs"] = "+";
        kwargs["default"] = None;
        if arg.short {
            parser.add_argument(f"-{arg.short}", f"--{arg.name}", **kwargs);
        } else {
            parser.add_argument(f"--{arg.name}", **kwargs);
        }
    } elif kind == ArgKind.REMAINDER {
        kwargs["nargs"] = argparse.REMAINDER;
        parser.add_argument(arg.name, **kwargs);
    } elif not arg_consumes_value(kind, arg.typ) {
        kwargs["action"] = "store_true";
        kwargs["default"] = arg.default if arg.default is not None else False;
        shared_dest: str = kwargs.get("dest") or arg.name.replace("-", "_");
        kwargs["dest"] = shared_dest;
        if arg.short {
            parser.add_argument(f"-{arg.short}", f"--{arg.name}", **kwargs);
        } else {
            parser.add_argument(f"--{arg.name}", **kwargs);
        }
        no_kwargs = {
            "action": "store_false",
            "dest": shared_dest,
            "help": f"Disable {arg.name}"
        };
        parser.add_argument(f"--no-{arg.name}", **no_kwargs);
    } else {
        kwargs["type"] = typ;
        kwargs["default"] = arg.default;
        if arg.required {
            kwargs["required"] = True;
        }
        if arg.short {
            parser.add_argument(f"-{arg.short}", f"--{arg.name}", **kwargs);
        } else {
            parser.add_argument(f"--{arg.name}", **kwargs);
        }
    }
}

impl build_command_parser(meta: CommandMeta) -> argparse.ArgumentParser {
    description = meta.description or meta.help;
    if meta.examples {
        description += "\n\nExamples:\n";
        for (cmd, desc) in meta.examples {
            description += f"  {cmd}\n";
            if desc {
                description += f"      {desc}\n";
            }
        }
    }
    parser = argparse.ArgumentParser(
        prog=f"jac {meta.name}",
        description=description,
        formatter_class=argparse.RawDescriptionHelpFormatter,
        add_help=True
    );
    for arg in meta.args {
        add_argument(parser, arg);
    }
    return parser;
}
