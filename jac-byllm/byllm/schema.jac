"""Schema generation for OpenAI compatible APIs.

This module provides functionality to generate JSON schemas for classes and types
and to validate instances against these schemas.
"""

import from dataclasses { is_dataclass }
import from enum { Enum }
import from types { FunctionType, MethodType, UnionType }
import from typing { Callable, Union, get_args, get_origin, get_type_hints }
import from pydantic { TypeAdapter }
import from jaclang.jac0core.mtp { Info, FieldInfo, ClassInfo, ParamInfo, EnumInfo }
import from byllm.exceptions { ConfigurationError }

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

# ---------------------------------------------------------------------------
# Schema-side prompt augmentation
# ---------------------------------------------------------------------------
# Frontier cloud providers (OpenAI, Anthropic, Gemini) inject the
# response_format schema's description into the model's prompt
# server-side, so prose-style hints like
#   "the names are [WORK, PERSONAL, SHOPPING, ...]"
# reach the model. Local-style backends -- Ollama, vLLM, custom
# OpenAI-compatible servers, and our own in-process llama.cpp route --
# treat response_format as a grammar/format constraint only and do not
# touch the prompt. Without an explicit hint, small open-weight models
# default to the first allowed enum integer for every input.
#
# These helpers extract a human-readable hint from the schema (handling
# both `json_schema` and `json_object` response_format shapes) and append
# it to the last user message. `BaseLLM.make_model_params` calls
# `inject_schema_hint(params)` so every backend benefits without the
# normalisation having to live inside any one connector.
"""Pretty-print enum-typed schema property as `1=WORK, 2=PERSONAL, ...`.

Pairs up to the shorter of values vs. names when they disagree (byllm's
schema-gen can over-emit names if its MTIR snapshot drifts).
"""
def _format_enum_hint(values: list, names: list) -> str;

"""Recursively pull bullet-style hint lines out of a JSON-Schema property."""
def _hints_from_schema(name: str, prop: dict) -> list[str];

"""Build a human-readable hint block from a response_format dict.

Accepts both shapes:
  - `{type: "json_schema", json_schema: {schema: {...}}}` (OpenAI / byllm output)
  - `{type: "json_object", schema: {...}}` (llama.cpp / Ollama)

Returns "" when there is nothing useful to surface.
"""
def schema_to_hint_text(rf: dict | None) -> str;

"""Append the schema-derived hint to the last user message in `messages`.

Returns a new list (the caller's input is not mutated). When the last
user message holds OpenAI multimodal content (a list of `{type:text,...}`
parts), the hint is appended as a final text part so multimodal-aware
backends still work.
"""
def attach_schema_hint(messages: list, rf: dict | None) -> list;

"""Universal request-side schema-hint injection.

Called from `BaseLLM.make_model_params` so every backend (cloud,
Ollama, in-process `local:*`, ...) sees the same explicit
name-to-value mapping in the prompt.
"""
def inject_schema_hint(params: dict) -> dict;
