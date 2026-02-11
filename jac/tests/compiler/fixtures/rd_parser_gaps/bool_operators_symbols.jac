# && and || as synonyms for and/or
with entry {
    a = True;
    b = False;
    c = a && b;
    d = a || b;
    e = (a && b) || (c && d);
}
