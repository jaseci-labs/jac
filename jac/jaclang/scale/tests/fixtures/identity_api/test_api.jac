"""Placeholder entrypoint - tests hit auth endpoints registered by jac-scale itself."""
walker:protect hello {
    can run with Root entry {
        report {"hello": "world"};
    }
}
