import from pathlib { Path }
import from typing { Optional }

obj WebTarget(ClientTarget) {
    has name: str = "web",
        requires_setup: bool = False,
        config_section: str = "plugin.client",
        output_dir: Path = Path(".jac/client/dist");

    override def setup(project_dir: Path) -> None;
    override def build(
        entry_file: Path, project_dir: Path, platform: Optional[str] = None
    ) -> Path;

    override def dev(
        entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
    ) -> None;

    override def start(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;
}

impl _generate_index_html(
    bundle_path: Path,
    bundler: ViteBundler,
    loaded_mod: types.ModuleType,
    function_name: str,
    project_dir: Path
) {
    import html;
    import json;

    module_name = loaded_mod.__name__;
    dist_dir = Path(bundler.output_dir);
    css_link = _build_css_link(bundler);
    meta_data = _get_app_meta_data();
    head_builder = HeaderBuilder(meta_data, function_name);
    head_content = head_builder.build_head();
    if css_link {
        head_content += f"\n            {css_link}";
    }
    init_payload = {
        "module": module_name,
        "function": function_name,
        "args": {},
        "argOrder": [],
        "globals": {}
    };

    init_json = json.dumps(init_payload).replace('</', '<\\/');
    bundle_filename = bundle_path.name;
    base_path = bundler.config_loader.get_base_path();

    html_content = f'''<!DOCTYPE html>
<html lang="en">
  <head>
{head_content}
  </head>
  <body>
    <div id="root"></div>
    <script id="__jac_init__" type="application/json">{init_json}</script>
    <script type="module" src="{base_path}{bundle_filename}"></script>
  </body>
</html>''';
    index_html = dist_dir / 'index.html';
    index_html.write_text(html_content, encoding='utf-8');
}
