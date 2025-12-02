obj TYPE {
    def init() {
        DICT: dict = {};
        DICT[self] = 1;
    }
}

obj TASK(TYPE) {
    def init() {
        TYPE.init(self);
    }
}

with entry {
    TASK();
    print('Test Passed');
}
