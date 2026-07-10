import from typing { Callable }

enum ArgKind {
    POSITIONAL = 1,
    OPTION = 2,
    FLAG = 3,
    MULTI = 4,
    REMAINDER = 5,
    APPEND = 6,
}

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
        metavar: str | None = None;

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
        hidden: bool = False,
        handler: Callable | None = None;

    def get_all_args -> list[Arg];
}
