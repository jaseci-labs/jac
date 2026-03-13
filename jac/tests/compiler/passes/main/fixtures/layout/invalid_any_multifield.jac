"""Fixture: obj with multiple bad fields on known lines for location testing."""

import from typing { Any }

obj MultiFieldBad {
    has good_field: int,
        bad_field1: Any,
        bad_field2: Any;
}
