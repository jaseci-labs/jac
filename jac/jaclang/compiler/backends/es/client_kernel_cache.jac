import hashlib;
import os;

glob OSP_CORE_PARTS: tuple[str, ...] = (
         "runtime/osp_kernel.jac",
         "runtime/osp_graph.jac"
     ),
     _OSP_CORE_JS_MEMO: list[str] = [];

def _cache_dir -> str;

def _es_backend_fingerprint -> str;

def _unit_source_path -> tuple[str, str];

def _artifact_path(source_digest: str) -> str;

def _lower(cl_copy: str) -> str;

def osp_core_js -> str;
