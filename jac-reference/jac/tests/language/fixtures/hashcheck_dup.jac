obj SomeObj {
    has a: int = 5;
}

with entry {
    ob = SomeObj();
    a = {ob: "check"};
    print(a[ob]);
    ob.a = 10;
    ob_dyn: any = ob;
    ob_dyn.b = 20;
    print(a[ob]);
}
