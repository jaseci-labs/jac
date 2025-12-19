"""Vite client bundle processing modules."""

# JacMetaImporter handles loading from .jac files
from jac_client.plugin.src.asset_processor import AssetProcessor
from jac_client.plugin.src.babel_processor import BabelProcessor
from jac_client.plugin.src.compiler import ViteCompiler
from jac_client.plugin.src.config_loader import JacClientConfig
from jac_client.plugin.src.import_processor import ImportProcessor
from jac_client.plugin.src.jac_to_js import JacToJSCompiler
from jac_client.plugin.src.package_installer import PackageInstaller
from jac_client.plugin.src.vite_bundler import ViteBundler

__all__ = [
    "AssetProcessor",
    "BabelProcessor",
    "ViteCompiler",
    "JacClientConfig",
    "ImportProcessor",
    "JacToJSCompiler",
    "ViteBundler",
    "PackageInstaller",
]
