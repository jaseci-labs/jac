"""Imported helpers that terminate control flow."""

import from typing { Never, NoReturn }

def fail -> Never {
    raise ValueError("failed");
}

def legacy_fail -> NoReturn {
    raise ValueError("failed");
}

def may_return -> None {
    return;
}
