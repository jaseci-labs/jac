class X:
    a_b = 67
    y = "aaa" + f"b{a_b}bbcc"


c = (3, 4, 5)
l_1 = [2, 3, 4, 5]


def entry():
    x = X

    a = "abcde...."
    b = True
    c = bin(12)
    d = hex(78)
    # e = 0x4E
    print(l_1, a, b, c, d)
    print(x.y)


# Run the entry block
entry()
