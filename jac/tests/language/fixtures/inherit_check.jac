node b {}

walker ww {
    can gb with b entry;
}

walker www(ww) {
    can ggb with b entry;
}

node a {
    can go_to_b with ww | www entry {
        print("I am trying to go to b");
        visit [-->](?:b);
    }
}

impl ww.gb{
    print("I am in b");
}

impl www.ggb{
    print("www is also in b");
}

with entry {
    # na = a();
    nb = b();
    # na ++> nb;
    nb spawn ww();
    nb spawn www();
}
