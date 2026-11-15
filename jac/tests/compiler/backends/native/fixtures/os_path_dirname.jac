import os;

with entry {
    for path in [
        "/home",
        "/",
        "//",
        "//srv",
        "/usr/lib",
        "/usr//lib",
        "usr//lib",
        "usr/lib/",
        "usr",
        ""
    ] {
        print(path + "|" + os.path.dirname(path));
    }
}
