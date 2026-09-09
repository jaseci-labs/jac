import from jaclang.runtime.scalars { sized_scalar_names }

glob JCIR_BUILTIN_NAMES: frozenset = frozenset(
         {
             "APIProtocol",
             "AccessLevel",
             "JacListView",
             "RaisesContext",
             "Region",
             "region_of",
             "ScheduleTrigger",
             "_jac_chunks",
             "_jac_take_attr",
             "_jac_take_item",
             "_jac_replace_attr",
             "_jac_replace_item",
             "_jac_swap_places",
             "_jac_region_close",
             "_jac_region_instrument",
             "_jac_region_open",
             "_jac_region_register",
             "allroots",
             "archetype_alias",
             "commit",
             "grant",
             "jid",
             "jobj",
             "jref",
             "llm",
             "managed",
             "new",
             "on_commit",
             "printgraph",
             "restspec",
             "revoke",
             "save",
             "schedule",
             "schema_alias",
             "schema_drop",
             "schema_upgrade",
             "schema_was",
             "store",
             "testfail",
             "testraises",
             "testskip",
             "unsafe_html",
             "wrapping_add",
             "wrapping_mul",
             "wrapping_neg",
             "wrapping_shl",
             "wrapping_sub"
         }
             | set(sized_scalar_names())
     ),
     JCIR_AMBIENT_TYPING_NAMES: frozenset = frozenset(
         {
             "Annotated",
             "AsyncIterable",
             "AsyncIterator",
             "Awaitable",
             "Callable",
             "ClassVar",
             "Coroutine",
             "Generic",
             "Iterable",
             "Iterator",
             "Literal",
             "Mapping",
             "MutableMapping",
             "MutableSequence",
             "Protocol",
             "Sequence",
             "TypeVar"
         }
     );

glob JCIR_PYTHON_MAJOR: int = 3,
     JCIR_PYTHON_MINOR: int = 14;

def jcir_is_test_path(path: str) -> bool {
    return path.endswith(".test.jac");
}

def jcir_python_version -> int {
    return (JCIR_PYTHON_MAJOR << 8) | JCIR_PYTHON_MINOR;
}
