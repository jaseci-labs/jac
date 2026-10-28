import json;
import sys;

import threading;
import from weakref { WeakValueDictionary, finalize, ref }
import from contextlib { contextmanager }
import from contextvars { ContextVar }

class TypeResolutionError(ValueError) {}
class ForeignType(TypeResolutionError) {}
class UnavailableType(TypeResolutionError) {}

obj ResolutionScope {
    has application: PreparedApplication | None = None;
}

glob _scope: ContextVar[ResolutionScope | None] = ContextVar(
         'jac_persistence_scope', `default=None
     ),
     _types: dict[str, WeakValueDictionary[str, type]] = {},
     _resolved: dict[int, tuple[any, WeakValueDictionary[str, type]]] = {},
     _lock: threading.RLock = threading.RLock();

def module_identity(facts: tuple[str, ...]) -> str;

def class_facts(cls: type) -> tuple[str, ...];

def type_module(cls: type) -> str;

def register_type(cls: type);

@contextmanager
def resolution_scope(application: PreparedApplication | None) -> Iterator[None];

def _cached_type(
    application: PreparedApplication, key: str, name: str
) -> (type | None);

def _forget_resolved(application_id: int);

def _remember_type(application: PreparedApplication, key: str, cls: type);

def resolve_type(module_name: str, name: str) -> type;

def storage_type(cls: type) -> str;

def schema_type(value: object) -> str;


def resolution_required -> bool;


def identity_namespace(module_name: str) -> str;

def index_application(application: PreparedApplication);
