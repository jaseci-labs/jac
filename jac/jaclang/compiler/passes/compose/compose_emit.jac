import from pathlib { Path }
import from jaclang.compiler.passes.compose.compose_model { ComposeModule }

glob HOME_SCREEN_NAME: str = "HomeScreen";

obj ComposeEmit {
    has model: ComposeModule,
        out_dir: Path,
        dev: bool = False,
        _plan: any = None;

    def write -> list[Path];
    def emit_screens -> str;
    def emit_jac_app -> str;
    def route_plan -> any;
}

def normalize_route_segment(segment: str) -> str;
def route_to_screen_name(path: str) -> str;
def component_screen_name(comp_name: str) -> str;
def screen_name_for(
    path: (str | None), comp_name: (str | None), is_home: bool = False
) -> str;
