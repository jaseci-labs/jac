glob PYTHON_NATIVE_WIRE: tuple[str, ...] = ('int', 'float', 'bool', 'str'),
     JSON_SCALARS: tuple[str, ...] = (
         'str',
         'int',
         'float',
         'bool',
         'bytes',
         'None',
         'NoneType',
         'any',
         'Any',
         'object',
         'UUID'
     ),
     JSON_SEQUENCES: tuple[str, ...] = (
         'list',
         'tuple',
         'set',
         'frozenset',
         'Sequence'
     ),
     JSON_MAPPINGS: tuple[str, ...] = ('dict', 'Mapping'),
     REQUEST_PARTS: tuple[str, ...] = ('UploadFile', ),
     STREAMED_RESULTS: tuple[str, ...] = (
         'Generator',
         'Iterator',
         'Iterable',
         'AsyncGenerator',
         'AsyncIterator',
         'AsyncIterable'
     ),
     NOT_DATA: tuple[str, ...] = (
         'Callable',
         'Awaitable',
         'Coroutine',
         'TextIO',
         'BinaryIO',
         'IO',
         'Region',
         'type',
         'ModuleType'
     );

def python_native_wire -> set[str];

def crossing_refusal(
    type_name: str, src: str, dst: str, is_return: bool = False, placing: bool = False
) -> (str | None);

def signature_crossings(
    param_names: list[str],
    param_types: list[str],
    ret_type: str,
    src: str,
    dst: str,
    placing: bool = False
) -> list[tuple[str, str, str]];

def annotation_shape(tag: (UniNode | None)) -> tuple[str, list[UniNode]];

def declared_type(scope: (Module | None), name: str) -> (Archetype | Enum | None);

def alias_value(scope: (Module | None), name: str) -> (UniNode | None);

def non_string_key(
    tag: (UniNode | None), scope: (Module | None), depth: int
) -> (str | None);

def json_refusal(
    tag: (UniNode | None),
    scope: (Module | None),
    is_return: bool,
    to_server: bool,
    seen: set[str]
) -> (tuple[str, str] | None);

def signature_refusals(
    decl: Ability, src: str, dst: str, placing: bool = False
) -> list[tuple[str, str, str]];

def archetype_refusals(
    decl: Archetype, src: str, dst: str
) -> list[tuple[str, str, str]];

def archetype_fields(decl: Archetype) -> list[tuple[HasVar, (Module | None)]];

def ability_crossing(decl: Ability, src: str, dst: str) -> (str | None);
