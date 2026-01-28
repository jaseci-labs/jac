"""Utilities for Jac language server tests."""


def load_jac_template(template_file: str, code: str = "") -> str:
    """Load a Jac template file and inject code into placeholder."""
    with open(template_file) as f:
        jac_template = f.read()
    return jac_template.replace("#{{INJECT_CODE}}", code)
