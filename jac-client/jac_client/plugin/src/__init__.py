"""Vite client bundle processing modules."""

import jaclang  # noqa: F401 — registers JacMetaImporter for .jac files
from jac_client.plugin.src.asset_processor import AssetProcessor
from jac_client.plugin.src.compiler import ViteCompiler
from jac_client.plugin.src.config_loader import JacClientConfig
from jac_client.plugin.src.import_processor import ImportProcessor
from jac_client.plugin.src.jac_to_js import JacToJSCompiler
from jac_client.plugin.src.package_installer import PackageInstaller
from jac_client.plugin.src.vite_bundler import ViteBundler

__all__ = [
    "AssetProcessor",
    "ViteCompiler",
    "JacClientConfig",
    "ImportProcessor",
    "JacToJSCompiler",
    "ViteBundler",
    "PackageInstaller",
]
