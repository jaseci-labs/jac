import os;

def jac_js_path(path: str) -> str;

def client_output_path(source_path: str, source_root: str) -> str;

def relative_js_specifier(
    target_path: str, importer_path: str, source_root: str = ""
) -> str;
