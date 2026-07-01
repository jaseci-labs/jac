import from hashlib { blake2s }
import from jaclang.jac0core.bccache { discover_style_annex }

obj ScopedStyleSheet {
    has module_path: str,
        css_path: str,
        source_css: str,
        class_map: dict[str, str] = {},
        scoped_css: str = '';

    def postinit -> None;
    def rewrite_class_value(value: str) -> str;
}

def hash_class_name(module_path: str, class_name: str) -> str;

def scope_selector(selector: str, module_path: str, class_map: dict[str, str]) -> str;

def scope_stylesheet(css: str, module_path: str, class_map: dict[str, str]) -> str;

def load_style_annex(module_path: str) -> (ScopedStyleSheet | None);

def _skip_string(s: str, i: int) -> int;

def _consume_braced_block(css: str, start: int) -> tuple[(str, int)];

def _grouping_at_rule(prelude: str) -> bool;

glob __all__ = [
         'ScopedStyleSheet',
         'load_style_annex',
         'hash_class_name',
         'scope_selector',
         'scope_stylesheet'
     ];
