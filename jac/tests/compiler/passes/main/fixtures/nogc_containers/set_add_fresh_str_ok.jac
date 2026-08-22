"""Move-in: freshly-built strings add into an owned set."""
def run -> int {
    st: set[str] = set();
    i = 0;
    while i < 3 {
        st.add(f"k{i}");
        i += 1;
    }
    return len(st);
}

with entry {
    print(run());
}
