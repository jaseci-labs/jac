"""Minimal fixture for the dev-mode HMR refresh test: one walker, one route."""

walker:pub Base {
    can hello with Root entry {
        report {"message": "base"};
    }
}
