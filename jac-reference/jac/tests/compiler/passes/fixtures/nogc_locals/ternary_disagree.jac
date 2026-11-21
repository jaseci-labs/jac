"""Must fail under enforcement (E1401): a conditional whose arms disagree (a
literal against a fresh call) has no single inferable state, so the local
must be written out."""
def build -> own str {
    return "b" + "c";
}

def pick(flag: bool) -> int {
    s = "lit" if flag else build();
    return len(s);
}

with entry {
    print(pick(True));
}
