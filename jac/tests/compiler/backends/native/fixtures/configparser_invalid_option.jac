import from configparser { ConfigParser }

with entry {
    cp: any = ConfigParser();
    cp.add_section("s");
    cp.set("s", "a=b", "1");
    try {
        cp.write();
        print("invalid option name accepted");
    } except ValueError {
        print("invalid option name rejected");
    }
}
