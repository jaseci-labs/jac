def inner(**kw: any) -> str {
    out = "";
    for (k, v) in kw.items() {
        out = out + str(k) + "=" + str(v) + ";";
    }
    return out;
}

def outer(**kw: any) -> str {
    return inner(**kw);
}

with entry {
    print(outer(keyword="break"));
    print(inner(keyword="break", n=3));
}
