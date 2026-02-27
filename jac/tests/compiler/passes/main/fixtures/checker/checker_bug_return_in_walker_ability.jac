walker W {
    can do_something with entry {
        # This return statement used to be a bug
        # cause technically entry abilities shouldn't return values
        # however we can allow here to return early with no
        # return value, so this is fine.
        return;  # <-- Ok

    }
}
