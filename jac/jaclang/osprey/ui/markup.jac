obj MarkupError {
    has path: str,
        message: str;
}


obj LowerResult {
    has graph_root: UiNode | None = None,
        errors: list[MarkupError] = [],
        generated_jac: str = "";
}


obj TagRegistry {
    has tags: dict[str, any] = {};
}


obj _MarkupElem {
    has tag: str = "",
        attrs: dict[str, str] = {},
        children: list[_MarkupElem] = [],
        path: str = "";
}


obj _MarkupMatch {
    has _groups: list[str | None] = [],
        _end: int = 0;

    def group(i: int) -> str | None;
    def end -> int;
}


def _is_name_start(c: str) -> bool;


def _is_name_cont(c: str) -> bool;


def _is_space(c: str) -> bool;


def _skip_ws(text: str, i: int) -> int;


def _read_name(text: str, i: int) -> tuple[str, int] | None;


def _match_tag_open(text: str, i: int) -> _MarkupMatch | None;


def _match_tag_close(text: str, i: int) -> _MarkupMatch | None;


def _match_attr(text: str, i: int) -> _MarkupMatch | None;


def _iter_attrs(text: str, end: int) -> list[_MarkupMatch];


def create_tag_registry -> TagRegistry;


def register_tag(registry: TagRegistry, tag: str, archetype: any);


def default_shell_registry -> TagRegistry;


def _allowed_props(tag: str) -> set[str];


def _parse_attrs(raw: str) -> dict[str, str];


def _parse_markup(source: str) -> (list[_MarkupElem], list[MarkupError]);


def _coerce_value(raw: str, field: str) -> any;


def _field_name(attr: str) -> str;


def _apply_attrs(
    ui_node: UiNode,
    tag: str,
    attrs: dict[str, str],
    path: str,
    errors: list[MarkupError],
);


def _ctor_args(tag: str, attrs: dict[str, str]) -> str;


def _instantiate_tracked(
    elem: _MarkupElem,
    registry: TagRegistry,
    errors: list[MarkupError],
    gen_lines: list[str],
    var_counter: list[int],
) -> (UiNode | None, str);


def lower_markup(
    source: str, registry: TagRegistry | None = None, print_generated: bool = False,
) -> LowerResult;


def print_generated(source: str, registry: TagRegistry | None = None) -> str;
