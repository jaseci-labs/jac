import from sv_import_kwargs_dup_server { greet }

impl app.load -> None {
    result = await greet("World");
}
