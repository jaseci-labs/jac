import os;
import sys;

def _human_bytes(n: int) -> str;

def _cmd_model(action: str = "list", alias: str = "") -> int;

comptime SPEC_MODEL: CommandSpec = CommandSpec(
         name="model",
         help="Manage byllm local-model weights (Gemma 4 and friends)",
         args=[
             Arg.create(
                 "action",
                 kind=ArgKind.POSITIONAL,
                 `default="list",
                 help="Action: list, pull, rm"
             ),
             Arg.create(
                 "alias",
                 kind=ArgKind.POSITIONAL,
                 `default="",
                 help="Local-model alias (e.g. gemma-4-e4b). Omit for `list`."
             ),

         ],
         examples=[
             ("jac model list", "Show bundled aliases and download status"),
             ("jac model pull gemma-4-e4b", "Download Gemma 4 E4B GGUF weights"),
             ("jac model rm gemma-4-e4b", "Delete cached weights for an alias"),

         ],
         group="config",
         handler_name=ct_name(model)
     );

def model(action: str = "list", alias: str = "") -> int;
