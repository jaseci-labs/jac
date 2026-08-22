import from nadefault_transchain_b { fb }

def fa -> int {
    return fb() + 1;
}

with entry {
    print("fa:", fa());
}
