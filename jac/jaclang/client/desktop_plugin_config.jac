import os;

import from importlib.metadata { version as pkg_version }


obj PluginMetadata {
    has name: str,
        version: str,
        description: str;

    def to_dict -> dict[str, str];
}


def desktop_sdk_path -> str;


def desktop_sdk_exports -> list[str];

obj ConfigOptionSpec {
    has type: str,
        description: str,
        value_str: str = "",
        value_int: int = 0,
        value_bool: bool = False,
        value_list: list[str] = [],
        value_is_int: bool = False,
        value_is_bool: bool = False,
        value_is_list: bool = False,
        value_is_empty_dict: bool = False,
        nested: dict[str, ConfigOptionSpec] = {};

    def _default_value -> object;
    def to_dict -> dict[str, object];
}

obj PluginConfigSchema {
    has section: str,
        options: dict[str, ConfigOptionSpec];

    def to_dict -> dict[str, object];
}

def schema_str_option(value: str, description: str) -> ConfigOptionSpec;

def schema_int_option(value: int, description: str) -> ConfigOptionSpec;

def schema_bool_option(value: bool, description: str) -> ConfigOptionSpec;

def schema_list_option(value: list[str], description: str) -> ConfigOptionSpec;

def schema_dict_option(
    description: str, nested: dict[str, ConfigOptionSpec] | None = None
) -> ConfigOptionSpec;

def _desktop_config_schema -> PluginConfigSchema;

class JacDesktopPluginConfig {
    static def get_plugin_metadata -> dict[str, str];
    static def get_config_schema -> dict[str, object];
    static def desktop_project_template -> dict[str, object] | None;
}

def _load_desktop_template -> dict[str, object] | None;
