# 1. Test initialization order.
obj Test1 {
    has var1: int;
    has var2: int = 42;
    has var3: int;  # <-- This should be syntax error.
}

# 2. Test if postinit is needed but not provided.
obj Test2 {
    has var1: str;
    has var2: int by postinit;
}

# 3. Postinit should be considered as has default initialization.
obj Test3 {
    has var1: int;
    has var2: int = 42;
    has var3: int by postinit;  # <-- This is fine.
    has var4: int;  # <-- This should be syntax error.

    def postinit() {
        self.var3 = 3;
    }
}
