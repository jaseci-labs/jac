"""Fixture: obj with Any field (should trigger layout warning)."""

import from typing { Any }

obj BadObj {
    has data: Any;
}
