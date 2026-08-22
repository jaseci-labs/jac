struct S {
    int a;
    int b;
};

static const struct S t[4] = {
    [1] = { 10, 20 },
};

int
get_a(int i)
{
    return t[i].a;
}
