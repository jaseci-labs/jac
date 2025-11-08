glob a = 9.2;

glob b = 44;

glob c = [2, 4, 6, 10];

glob d = {'name':'john', 'age':28 };

glob e = ("jaseci", 5, 4, 14);

glob f = True;

glob g = "Jaseci";

glob h = {5, 8, 12, "unique"};

with entry {
    print(type(a), '\n', type(b), '\n', type(c), '\n', type(d), '\n', type(e));
    print(type(f), '\n', type(g), '\n', type(h));
}
