let:priv a = 5;

glob:pub X = 10;

glob:protect y = 15;

glob z = 20;

obj:priv Myobj{}

with entry:__main__ {
    print(a, X, y, z);
}
