# impl definition inside a function body
def plan {
    def say_hi(m: str);

    print("Hello, world!");
    say_hi("I'm a ninja Myca!");

    impl plan.say_hi(m: str) {
        print(m);
    }
}

with entry {
    plan();
}
