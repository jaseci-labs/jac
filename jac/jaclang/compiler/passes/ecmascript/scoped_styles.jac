"""Scoped-style annex support for the `cl` (client) target.

A `.style.css` file that shares a base name with a `.cl.jac` module
(e.g. `card.style.css` alongside `card.cl.jac`) forms one logical module
with auto-scoped CSS classes. The compiler:

  1. Hashes every class selector declared in the annex with a per-module
     digest (`blake2s(module_path + class_name)`, truncated to 8 hex
     chars), producing names like `card-1a2b3c4d`.
  2. Rewrites the annex CSS so each declared selector uses the hashed
     form, leaving `:global(...)` selectors verbatim (the wrapper is
     stripped, the inner selector preserved).
  3. Exposes the hashed names so the ECMAScript pass can rewrite JSX
     `className`/`class` literals in the module that reference a declared
     class to the same hashed form.

The rewritten CSS is emitted as a sidecar artifact (`Module.gen.css`) and
a side-effect `import "./<base>.css";` is injected into the compiled JS so
the styles load with the component -- framework-neutral, no bundler config.

This subsystem is self-contained: annex discovery + CSS parse + selector
hashing all live here; the ECMAScript pass only consumes the resulting
`class_map` and `scoped_css`.
"""

import from hashlib { blake2s }
import from jaclang.jac0core.bccache { discover_style_annex }

"""A loaded, scoped `.style.css` annex for one client module.

    Construct via `load_style_annex`; `postinit` parses `source_css`,
    populating `class_map` (bare name -> hashed name) and `scoped_css`
    (the selector-rewritten stylesheet).
    """
obj ScopedStyleSheet {
    has module_path: str,
        css_path: str,
        source_css: str,
        class_map: dict[str, str] = {},
        scoped_css: str = '';

    def postinit -> None;
    """Rewrite a JSX `className`/`class` value, hashing each declared token.

        The value is split on whitespace; tokens that name a class declared
        in the annex are replaced with their hashed form, others are kept
        verbatim. Original inter-token spacing is collapsed to single
        spaces (semantically irrelevant for a class list).
        """
    def rewrite_class_value(value: str) -> str;
}

"""Hash a single class name with the module-scoped digest.

    Returns the scoped name `<class_name>-<8 hex>`. Deterministic for a
    given (module_path, class_name) pair, so the CSS selector rewrite and
    the JSX `className` rewrite agree.
    """
def hash_class_name(module_path: str, class_name: str) -> str;

"""Rewrite a CSS selector prelude, hashing declared class tokens.

    Class tokens (`.name`) are replaced with `.name-<hash>` and recorded in
    `class_map`; `:global(...)` regions are unwrapped and preserved
    verbatim; comments, strings, and attribute selectors are passed through
    untouched.
    """
def scope_selector(selector: str, module_path: str, class_map: dict[str, str]) -> str;

"""Rewrite a full stylesheet, scoping the class selectors of style rules.

    Walks rules with brace tracking: style-rule preludes are scoped via
    `scope_selector`; grouping at-rules (`@media`, `@supports`,
    `@container`, `@layer`, `@scope`) are descended into; other at-rules
    (`@keyframes`, `@font-face`, ...) and all declaration blocks are copied
    verbatim. Mutates `class_map` in place and returns the rewritten CSS.
    """
def scope_stylesheet(css: str, module_path: str, class_map: dict[str, str]) -> str;

"""Load and scope the `.style.css` annex for a module, or None if absent.

    `module_path` is the head module's source path (variant suffix is
    handled by `discover_style_annex`).
    """
def load_style_annex(module_path: str) -> (ScopedStyleSheet | None);

"""Advance past a CSS string literal. `i` is the opening quote; returns the
    index just after the matching close quote (backslash escapes honored)."""
def _skip_string(s: str, i: int) -> int;

"""Consume a brace-delimited block verbatim. `start` indexes the opening
    `{`; returns the block text (braces included) and the index after the
    matching `}`. Strings and comments inside are not brace-counted."""
def _consume_braced_block(css: str, start: int) -> tuple[(str, int)];

"""True if a rule prelude is a grouping at-rule whose block holds nested
    rules (`@media`, `@supports`, `@container`, `@layer`, `@scope`) rather
    than declarations."""
def _grouping_at_rule(prelude: str) -> bool;

glob __all__ = [
         'ScopedStyleSheet',
         'load_style_annex',
         'hash_class_name',
         'scope_selector',
         'scope_stylesheet'
     ];
