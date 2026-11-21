"""Fixture: obj with multiple bad fields on known lines for location testing."""

obj MultiFieldBad {
    has good_field: int,
        bad_field1: any,
        bad_field2: any;
}
