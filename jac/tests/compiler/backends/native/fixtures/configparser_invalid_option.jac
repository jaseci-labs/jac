import from configparser { ConfigParser }

with entry {
    cp: ConfigParser = ConfigParser();
    cp.add_section("s");
    cp.set("s", "[abc", "1");
    text = cp.write();
    roundtrip: ConfigParser = ConfigParser();
    roundtrip.read_string(text);
    assert roundtrip.get("s", "[abc") == "1";
    print("valid bracket option round-trips");

    cp.set("s", "a=b", "1");
    try {
        cp.write();
        print("invalid option name accepted");
    } except ValueError {
        print("invalid option name rejected");
    }

    cpv: ConfigParser = ConfigParser();
    cpv.add_section("s");
    cpv.set("s", "[abc", "x]");
    try {
        cpv.write();
        print("value-completed header accepted");
    } except ValueError {
        print("value-completed header rejected");
    }
}
