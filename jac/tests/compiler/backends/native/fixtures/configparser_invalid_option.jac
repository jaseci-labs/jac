import from configparser { ConfigParser }

with entry {
    cp: any = ConfigParser();
    cp.add_section("s");
    cp.set("s", "[abc", "1");
    text = cp.write();
    roundtrip: any = ConfigParser();
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
}
