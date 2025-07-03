"""Jac sitecustomize module."""

import sys

from jaclang.runtimelib.meta_importer import JacMetaImporter
from typing_extensions import override as _override
import typing

if not any(isinstance(f, JacMetaImporter) for f in sys.meta_path):
    sys.meta_path.insert(0, JacMetaImporter())

if not hasattr(typing, "override"):
    typing.override = _override  # type: ignore[attr-defined]
