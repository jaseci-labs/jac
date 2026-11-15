import from sv_import_kwargs { greet }

impl app.load -> None {
    result = await greet("World");
}
