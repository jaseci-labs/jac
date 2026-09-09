import json;
import from abc { abstractmethod }
import from collections.abc { Callable }
import from enum { StrEnum }
import from typing { ClassVar, NoReturn, `override }
import type from enum { IntEnum }
import type from jaclang.runtime.constructs { AccessLevel, NodeArchetype }
import type from jaclang.runtime.runtime { LLMModel }
import type from jaclang { JacRuntimeInterface }

enum APIProtocol(StrEnum) {
    HTTP = 'http',
    WEBHOOK = 'webhook',
    WEBSOCKET = 'websocket'
}

enum ScheduleTrigger(StrEnum) { STATIC = 'static', DYNAMIC = 'dynamic' }

def _get_jac -> type[JacRuntimeInterface];

def _get_access_level -> type[AccessLevel];

def _get_jid -> Callable[..., any];

def _get_jobj -> Callable[..., any];

def jref(id_or_obj: any) -> any;

def _get_jref -> Callable[..., any];

def _get_grant -> Callable[..., any];

def _get_revoke -> Callable[..., any];

def _get_allroots -> Callable[..., any];

def _get_save -> Callable[..., any];

def _get_commit -> Callable[..., any];

def _get_on_commit -> Callable[..., any];

def _get_store -> Callable[..., any];

def _get_llm -> LLMModel;

def _get_archetype_alias -> Callable[..., any];

def _get_schema_builder(name: str) -> Callable[..., any];

def __getattr__(name: str) -> object;

def printgraph(
    nd: (NodeArchetype | None) = None,
    depth: int = -1,
    traverse: bool = False,
    edge_type: (list[str] | None) = None,
    bfs: bool = True,
    edge_limit: int = 512,
    node_limit: int = 512,
    file: (str | None) = None,
    format: str = 'dot'
) -> str;

def _jac_graph_json(file: (str | None) = None) -> str;

def restspec(**specs: any) -> Callable;

def schedule(**kwargs: any) -> Callable;

def new(cls: any, *args: any) -> any;

def unsafe_html(html: any) -> dict;

def managed(x: any) -> any;

def testskip(reason: str = "") -> NoReturn;

def testfail(reason: str = "") -> NoReturn;

def testraises(*excs: type, `match: (str | None) = None) -> RaisesContext;

obj RaisesContext {
    has excs: tuple[type, ...],
        pattern: (str | None) = None,
        value: (BaseException | None) = None;

    def __enter__ -> RaisesContext;
    def __exit__(exc_type: any, exc: any, tb: any) -> bool;
    def `match(regexp: str) -> bool;
}

obj JacListView {
    has backing: any = None,
        start: int = 0,
        stop: int = 0;

    def __len__ -> int;
    def __getitem__(i: any) -> any;
    def __setitem__(i: any, v: any) -> None;
    def __iter__ -> any;
}

def _jac_chunks(xs: any, n: int) -> list;

def _jac_take_attr(owner: any, name: str) -> any;

def _jac_take_item(seq: any, key: any) -> any;

def _jac_replace_attr(owner: any, name: str, value: any) -> any;

def _jac_replace_item(seq: any, key: any, value: any) -> any;

def _jac_swap_places(
    owner_a: any, key_a: any, attr_a: bool, owner_b: any, key_b: any, attr_b: bool
) -> None;


glob __all__ = [
         'printgraph',
         'jid',
         'jobj',
         'jref',
         'grant',
         'revoke',
         'allroots',
         'save',
         'commit',
         'on_commit',
         'store',
         'llm',
         'new',
         'AccessLevel',
         'restspec',
         'schedule',
         'ScheduleTrigger',
         'APIProtocol',
         'archetype_alias',
         'schema_was',
         'schema_alias',
         'schema_drop',
         'schema_upgrade',
         'unsafe_html',
         'managed',
         'testskip',
         'testfail',
         'testraises',
         'RaisesContext',
         'i8',
         'u8',
         'i16',
         'u16',
         'i32',
         'u32',
         'i64',
         'u64',
         'f32',
         'f64',
         'wrapping_add',
         'wrapping_sub',
         'wrapping_mul',
         'wrapping_shl',
         'wrapping_neg',
         'JacListView',
         '_jac_chunks',
         '_jac_take_attr',
         '_jac_take_item',
         '_jac_replace_attr',
         '_jac_replace_item',
         '_jac_swap_places',
         'Region',
         'region_of',
         '_jac_region_open',
         '_jac_region_close',
         '_jac_region_register',
         '_jac_region_instrument'
     ];
