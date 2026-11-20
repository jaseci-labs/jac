import from nadefault_capchain_b { fb }
import from nadefault_capchain_c { fc }

def fa -> int {
    return fb() + fc() + 1;
}

with entry {
    print("fa:", fa());
}
