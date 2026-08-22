import argparse;
import from jaclang.cli.manifest { ArgMeta, CommandMeta }

glob PARSER_ARG_META_FIELDS: set[str] = {
         "name",
         "kind",
         "typ",
         "default",
         "help",
         "short",
         "choices",
         "required",
         "dest",
         "metavar",

     },
     DISPATCH_ARG_META_FIELDS: set[str] = {"config_key"};

def add_argument(parser: argparse.ArgumentParser, arg: ArgMeta) -> None;
def build_command_parser(meta: CommandMeta) -> argparse.ArgumentParser;
