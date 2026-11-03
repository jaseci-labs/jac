glob SCALAR_KINDS: dict[str, str] = {
         "bool": "bool",
         "int": "int",
         "float": "float",
         "str": "str",
         "any": "any",
         "Any": "any",
         "typing.Any": "any",
         "object": "any"
     },
     SCHEMA_KINDS: dict[str, str] = {
         "string": "str",
         "int": "int",
         "bool": "bool",
         "float": "float",
         "list": "list",
         "dict": "dict"
     },
     KIND_WORDS: dict[str, tuple[str, str]] = {
         "bool": ("true or false", "true/false values"),
         "int": ("an integer", "integers"),
         "float": ("a number", "numbers"),
         "str": ("a string", "strings")
     };

obj TableRule {
    has kind: str,
        optional: bool = False,
        item: TableRule | None = None,
        keys: dict[str, TableRule] | None = None;

    def accepts(value: any) -> bool;
}

obj TableProblem {
    has section: str,
        key: str = "",
        detail: str = "",
        known: list[str] | None = None;

    def describe -> str;
}

def rules_from_record(record: object) -> dict[str, TableRule];

def rule_from_type(annotation: any, owner: object, label: str) -> TableRule;

def rules_from_schema(options: dict[str, any]) -> dict[str, TableRule];

def check_table(
    table: dict[str, any],
    rules: dict[str, TableRule],
    section: str,
    moved: dict[str, str],
    types: bool = True
) -> list[TableProblem];

def validate_against_schema(
    raw: dict[str, any] | None, options: dict[str, any], section: str
) -> list[str];

def report_schema_findings(
    findings: list[str], section: str, strict_env: str = ""
) -> None;

def schema_strict_enabled(strict_env: str) -> bool;

def _type_text(annotation: any) -> str;

def _split_top(text: str, sep: str) -> list[str];

def _named_rule(text: str, owner: object, label: str) -> TableRule;

def _schema_rule(spec: any) -> TableRule;

def _walk_table(
    table: dict[str, any],
    rules: dict[str, TableRule],
    section: str,
    moved: dict[str, str],
    types: bool,
    problems: list[TableProblem]
) -> None;

def _check_value(
    rule: TableRule,
    raw: any,
    section: str,
    key: str,
    types: bool,
    problems: list[TableProblem]
) -> None;

def _expects(rule: TableRule, raw: any) -> str;

def _unknown_key_message(path: str, key: str, known: list[str]) -> str;
