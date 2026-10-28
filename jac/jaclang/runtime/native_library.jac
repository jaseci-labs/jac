import ctypes;
import os;
import sys;

glob SHARED_INIT_SYMBOL: str = "__jac_shared_init",
     _LOADED: dict[str, SharedNativeEngine] = {};

class SharedNativeEngine {
    def init(self: SharedNativeEngine, lib_path: str, record: dict[str, any]);
    def _address_of(self: SharedNativeEngine, name: str) -> int;
    def run_static_init(self: SharedNativeEngine) -> None;
    def get_function_address(self: SharedNativeEngine, name: str) -> int;
    def get_global_value_address(self: SharedNativeEngine, name: str) -> int;
    def enable_jit_events(self: SharedNativeEngine);
}

def shared_engine_for(lib_path: str, record: dict[str, any]) -> SharedNativeEngine;
