"""Simple test app for admin portal."""

walker hello {
    can enter with `root entry {
        print("Hello from test app!");
    }
}
