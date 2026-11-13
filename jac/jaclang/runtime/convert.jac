import inspect;
import typing;

import from datetime { date, datetime, time }
import from enum { Enum }
import from types { NoneType, UnionType }
import from typing { Union, get_args, get_origin, get_type_hints }
import from uuid { UUID }

enum ConvertMode { STRICT = 'strict', TEXT = 'text', LENIENT = 'lenient' }

glob TRUE_WORDS: frozenset[str] = frozenset({'1', 'true', 'yes', 'on', 'y'}),
     FALSE_WORDS: frozenset[str] = frozenset({'0', 'false', 'no', 'off', 'n', ''}),
     STRING_FORMATS: dict[type, str] = {
         datetime: 'date-time',
         date: 'date',
         time: 'time',
         UUID: 'uuid'
     },
     _CONTAINERS: tuple[type, ...] = (list, tuple, set, dict),
     _SHAPES: dict[int, tuple[any, any, tuple[any, ...]]] = {},
     _SHAPES_LIMIT: int = 4096;

def type_shape(target: object) -> tuple[object, tuple[object, ...]];

def convert(value: any, target: any, mode: ConvertMode = ConvertMode.STRICT) -> any;

def _mismatch(expected: str, value: any) -> ValueError;

def _convert_union(value: any, members: tuple[any, ...], mode: ConvertMode) -> any;

def _convert_container(
    value: any, base: type, args: tuple[any, ...], mode: ConvertMode
) -> any;

def _convert_class(value: any, target: type, mode: ConvertMode) -> any;

def _to_bool(value: any, mode: ConvertMode) -> bool;

def _to_int(value: any, mode: ConvertMode) -> int;

def _to_float(value: any, mode: ConvertMode) -> float;

def _to_sized(value: any, target: type, name: str, mode: ConvertMode) -> any;

def _to_enum(value: any, target: type[Enum], mode: ConvertMode) -> any;

def _construct(value: any, target: any, mode: ConvertMode) -> any;
