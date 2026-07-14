import logging;
import os;
import threading;
import from collections.abc { Callable }
import from dataclasses { fields, is_dataclass }

glob logger = logging.getLogger(__name__),
     ATTIC_KEY: str = '__jac_attic__',
     REPAIRS_ATTR: str = '__jac_schema_repairs__',
     SCHEMA_HOOK: str = '__jac_schema__';

obj AliasRule {
    has new_name: str,
        stored_name: str;
}

obj DropRule {
    has field_name: str,
        until: (str | None) = None;
}

obj UpgradeRule {
    has fn: Callable,
        when: (Callable | None) = None;
}

obj SchemaRules {
    has owner: str,
        was_names: list[str] = [],
        aliases: list[AliasRule] = [],
        drops: list[DropRule] = [],
        upgrades: list[UpgradeRule] = [];

    def add_was(old_fqn: str) -> None;
    def add_alias(new_name: str, stored_name: str) -> None;
    def add_drop(field_name: str, until: (str | None) = None) -> None;
    def add_upgrade(fn: Callable, when: (Callable | None) = None) -> None;
    def is_empty -> bool;
}

def schema_was(old_fqn: str) -> None;

def schema_alias(new_name: str, stored: str) -> None;

def schema_drop(field_name: str, until: (str | None) = None) -> None;

def schema_upgrade(fn: Callable, when: (Callable | None) = None) -> None;

def collect_rules(cls: type) -> (SchemaRules | None);

def merged_rules_for(cls: type) -> (SchemaRules | None);

def validate_rules(rules: SchemaRules, cls: type) -> None;

def repair_mode -> str;

def apply_rules(data: dict, rules: SchemaRules) -> tuple;

def _require_collector -> SchemaRules;
def _owner_key(cls: type) -> str;
