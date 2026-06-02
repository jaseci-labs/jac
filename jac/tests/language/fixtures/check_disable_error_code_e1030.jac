"""Fixture with a deterministic E1030 for jac check disable-error-code tests."""

walker W {
    can run with entry {
        params: dict = {"id": "abc"};
        print(params.id);
    }
}
