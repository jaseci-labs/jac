def build_gradle_scaffold(
    package_name: str,
    app_name: str,
    backend_url: str,
    routes: list[str],
    dev: bool = False
) -> dict[str, str];

def package_to_path(package_name: str) -> str;
def android_color_literal(hex: str) -> str;
def escape_kotlin(value: str) -> str;
def escape_android_xml(value: str) -> str;
def emit_jac_design -> str;
