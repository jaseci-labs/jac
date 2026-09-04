obj Helper {
    def run -> int {
        report 1;
        return 1;
    }
}

with entry {
    print(Helper().run());
}
