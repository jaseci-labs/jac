import inspect;
import random;
import string;
import sys;
import types;
import from collections { deque }
import from dataclasses { is_dataclass, fields as dc_fields, MISSING }
import from datetime { date, datetime, time, timedelta }
import from decimal { Decimal }
import from typing {
    Annotated,
    Literal,
    Union,
    get_args,
    get_origin,
    get_type_hints,
    TypeVar
}
import from collections.abc { Callable }
import from uuid { UUID, uuid4 }

glob _RAND_STR_ALPH: str = string.ascii_letters + string.digits;

def _rand_str(n: int = 12) -> str;

def _is_typed_dict(tp: any) -> bool;

def _is_namedtuple(tp: any) -> bool;

def _is_enum(tp: any) -> bool;

def _unwrap_annotated(tp: any) -> any;

def _unwrap_newtype(tp: any) -> any;

def _choose_from(seq: any) -> any;

def _random_primitive(tp: any) -> any;

def random_value_for_type(tp: any, *, _depth: int = 0, _max_depth: int = 10) -> any;
