import importlib;
import importlib.abc;
import importlib.util;
import logging;
import sys;
import threading;

glob _log: logging.Logger = logging.getLogger(__name__),
     _hooks: dict[str, list[any]] = {},
     _fired: set[str] = set(),
     _lock: any = threading.RLock(),
     _state: dict[str, any] = {"watcher": None};

def is_installed(name: str) -> bool;

def _fire(name: str, module: any) -> None;

class _NotifyingLoader(importlib.abc.Loader) {
    def init(self: any, inner: any, name: str);
    def create_module(self: any, spec: any) -> any;
    def exec_module(self: any, module: any);
    def __getattr__(self: any, attr: str) -> any;
}

class _LoadWatcher(importlib.abc.MetaPathFinder) {
    def find_spec(
        self: any, fullname: str, path: any = None, target: any = None
    ) -> any;
}

def when_loaded(name: str, callback: any) -> None;

def is_loaded(name: str) -> bool;

class DeferredModule {
    def init(self: any, name: str);
    def _deferred_load(self: any) -> any;
    def __getattr__(self: any, attr: str) -> any;
    def __setattr__(self: any, attr: str, value: any);
    def __delattr__(self: any, attr: str);
    def __dir__(self: any) -> list[str];
    def __repr__(self: any) -> str;
}

def _resolve(module_name: str, path: str, load: bool) -> any;

class DeferredClassMeta(type) {
    def __instancecheck__(cls: any, candidate: any) -> bool;
    def __subclasscheck__(cls: any, sub: any) -> bool;
    def __call__(cls: any, *args: any, **kwargs: any) -> any;
}
