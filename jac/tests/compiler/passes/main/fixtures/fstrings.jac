"""Small test for fstrings."""

glob apple = 2;
glob a = f"hello {40 + 2}   wor{apple}ld  ";

with entry {
    a = 9;
    s_2 = "'''hello'''";
    s_3 = "'''hello  '''";
    s_4 = "''' hello'''";
    s_5 = '""" hello"""';
    s_6 = '"""hello"""';
    s_7 = '"""hello"" "';
    s_8 = '"""hello""" ';
    print(len(s_2), len(s_3), len(s_4), len(s_5), len(s_6), len(s_7), len(s_8));
    b1 = f"{"'''hello''' "}";
    b_2 = f"{'"""hello""" '}";
    f_1 = f"{'hello '}{a}{'"""hello"""'}";
    f_2 = f"{'hello '}{a}{"'''hello'''"}";
    print(len(b1), len(b_2), b_2, len(f_1), len(f_2));
    f_3 = f"{'"""again"""'}";
    f_4 = f"{'"""again""" '}";
    f_5 = f"{"'''again'''"}";
    f_6 = f"{"'''again''' "}";
    f_7 = f"{'"""again"""'}";
    f_s1 = f"{'hello '}{a}{'"""hello"""'}";
    f_s2 = f"{'hello '}{a}{"'''hello'''"}{'kklkl'}";
    print(len(f_3), len(f_4), len(f_5), len(f_6), len(f_7), len(f_s1), len(f_s2));
    """sdfsdf\nsdfsdfsdfsd dffgdfgd.""";
    c1 = '''hello klkl"""''';
    print(c1);
}

def func() {
    ;
}
