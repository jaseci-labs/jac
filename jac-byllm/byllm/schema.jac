"""Schema generation for OpenAI compatible APIs.

This module provides functionality to generate JSON schemas for classes and types
and to validate instances against these schemas.
"""

import from dataclasses { is_dataclass }
import from enum { Enum }
import from types { FunctionType, MethodType, UnionType }
import from typing { Callable, Union, get_args, get_origin, get_type_hints }
import from pydantic { TypeAdapter }
import from jaclang.pycore.mtp { Info, FieldInfo, ClassInfo, ParamInfo, EnumInfo }

glob _SCHEMA_OBJECT_WRAPPER = "schema_object_wrapper",
     _SCHEMA_DICT_WRAPPER = "schema_dict_wrapper";

def _type_to_schema(
    ty: type, title: str = "", desc: str = "", info: Info = None
) -> dict;

def _name_of_type(ty: type, info: Info) -> str;
def _convert_dict_to_schema(ty_dict: type) -> dict;
def _decode_dict(json_obj: dict) -> dict;
def _wrap_to_object(schema: dict[str, object]) -> dict[str, object];
def _unwrap_from_object(json_obj: dict) -> dict;
def type_to_schema(resp_type: type, info: Info) -> dict[str, object];
def tool_to_schema(
    func: Callable, description: str, params_desc: dict[str, str], info: Info
) -> dict[str, object];

def json_to_instance(json_obj: dict, ty: type) -> object;
