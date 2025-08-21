"""Jac sitecustomize module."""

import sys

from jaclang.runtimelib.meta_importer import JacMetaImporter

if not any(isinstance(f, JacMetaImporter) for f in sys.meta_path):
    sys.meta_path.insert(0, JacMetaImporter())
