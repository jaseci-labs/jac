import hashlib;
import logging;
import os;
import tempfile;

glob OSP_CORE_PARTS: tuple[str, ...] = (
         "runtime/osp_kernel.jac",
         "runtime/osp_graph.jac"
     ),
     _OSP_CORE_JS_MEMO: list[str] = [],
     logger = logging.getLogger(__name__);

def _cache_dirs -> list[str];

def _find_cached(name: str) -> (str | None);

def _write_cached(name: str, text: str) -> (str | None);

def _es_backend_fingerprint -> str;

def _unit_source_path -> tuple[str, str];

def _artifact_name(source_digest: str) -> str;

def _lower(cl_copy: str) -> str;

def osp_core_js -> str;
