import hashlib;
import logging;
import os;
import secrets;
import stat;
import tempfile;

glob OSP_CORE_PARTS: tuple[str, ...] = (
         "runtime/osp_kernel.jac",
         "runtime/osp_graph.jac"
     ),
     _OSP_CORE_JS_MEMO: list[str] = [],
     logger = logging.getLogger(__name__);

def _primary_dir -> str;

def _trusted_dir(path: str) -> bool;

def _fallback_dir(create: bool) -> (str | None);

def _write_one(folder: str, name: str, text: str) -> (str | None);

def _find_cached(name: str) -> (str | None);

def _write_cached(name: str, text: str) -> (str | None);

def _es_backend_fingerprint -> str;

def _unit_source_path -> tuple[str, str];

def _artifact_name(source_digest: str) -> str;

def _lower(cl_copy: str) -> str;

def osp_core_js -> str;
