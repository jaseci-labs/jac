import from configparser { ConfigParser }

with entry {
    cp = ConfigParser();
    cp.read_string("[s]\nvalid = 1_000.5\ninvalid = 2.5oops\n");
    print("valid=" + str(cp.getfloat("s", "valid")));
    try {
        cp.getfloat("s", "invalid");
        print("invalid=accepted");
    } except ValueError {
        print("invalid=rejected");
    }
}
