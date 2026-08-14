"""Fixture with a deterministic E1030 for jac check disable-error-code tests."""

walker W {
    can run with entry {
        params: dict[str, str] = {"id": "abc"};
        print(params.id);
    }
}
