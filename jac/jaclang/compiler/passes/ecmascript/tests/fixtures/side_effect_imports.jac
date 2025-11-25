"""Fixture for testing side effect imports in Jac language."""

cl {
    # norrmal import
    import 'mytest/side_effects';

    # style injection import
    import '.styles/side_effects.css';
    import 'bootstrap/dist/css/bootstrap.min.css';
}