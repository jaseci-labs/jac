import hashlib;
import os;
import sys;
import from pathlib { Path }
glob LINKED_SOURCE_FILE: str = "jac_linked_source";

import from jaclang.dist.fused.trailer {
    MAGIC,
    OVERLAY_MAGIC,
    REGION_DESC_LEN,
    TRAILER_LEN,
    Region,
    Trailer,
    build_trailer,
    parse_region_desc,
    parse_trailer,
    region_start,
    rt_key
}

def fused_base_length(data: bytes) -> int;

def has_runtime(path: str = "") -> bool;

def append_overlay(base_path: str, jab_path: str, out_path: str) -> bool;

def graft_runtime(self_path: str, host_path: str) -> bool;


def _runtime_tail(exe: str) -> (tuple[int, Trailer] | None);


def runtime_trailer(exe: str) -> (Trailer | None);


def stubcat_region(exe: str = "") -> (Region | None);


def running_executable -> str;


def jac_binary -> str;


def running_runtime_key(path: str = "") -> str;


def interpreter_runtime_dir -> (str | None);


def _runtime_dir_for_key(key: str) -> (str | None);


def materialized_runtime_dir(path: str = "") -> (str | None);


def running_runtime_entries -> set[str];

def linked_source_dir(runtime_dir: str) -> str;
