import from typing { Callable }

enum ArgKind {
    POSITIONAL = 1,
    OPTION = 2,
    FLAG = 3,
    MULTI = 4,
    REMAINDER = 5,
    APPEND = 6,
}

enum CommandPriority { CORE = 100, PLUGIN = 200, USER = 300, }

obj Arg {
    has name: str,
        kind: ArgKind = ArgKind.OPTION,
        typ: any = str,
        `default: any = None,
        help: str = "",
        short: str | None = None,
        choices: list[any] | None = None,
        required: bool = False,
        dest: str | None = None,
        metavar: str | None = None,
        source: str = "jaclang";

    static def create(
        name: str,
        kind: ArgKind = ArgKind.OPTION,
        typ: any = str,
        `default: any = None,
        help: str = "",
        short: str | None = None,
        choices: list[any] | None = None,
        required: bool = False,
        metavar: str | None = None,
        dest: str | None = None
    ) -> Arg;
}

obj CommandSpec {
    has name: str,
        help: str,
        description: str = "",
        args: list[Arg] = [],
        examples: list[tuple[str, str]] = [],
        group: str = "general",
        tier: str = "",
        priority: CommandPriority = CommandPriority.CORE,
        source: str = "jaclang",
        handler: Callable | None = None,
        extra_args: list[Arg] = [],
        pre_hooks: list[tuple[Callable, str]] = [],
        post_hooks: list[tuple[Callable, str]] = [];

    def get_all_args -> list[Arg];
    def add_extension_arg(arg: Arg, source: str) -> None;
    def add_pre_hook(hook: Callable, source: str) -> None;
    def add_post_hook(hook: Callable, source: str) -> None;
}

obj HookContext {
    has command_name: str,
        args: dict[str, any],
        data: dict[str, any] = {};

    def get_arg(name: str, `default: any = None) -> any;
    def set_data(key: str, value: any) -> None;
    def get_data(key: str, `default: any = None) -> any;
}
