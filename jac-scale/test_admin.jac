"""Simple test app for admin portal."""
import from jaclang.cli.console { console }

walker hello {
    can enter with `root entry {
        console.print("Hello from test app!");
    }
}
