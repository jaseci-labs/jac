"""Client test whose mock is found by the tests/__mocks__ convention."""

import from "fake-widgets" { widget, helper }

test "a mock loads, and its own helper file was staged with it" {
    # "w1" comes from ./support/ids, so this passes only if it was staged.
    assert widget.id() == "w1";
}

test "a name re-exported from an unmapped package lands on the proxy" {
    helper();
    assert 1 + 1 == 2;
}
