import from inline_owned_model { State, make_state }
def run {
    s = make_state();
    swap(&mut s.first, &mut s.second);
    for i in range(20) {
        assert s.second.values[i + 1].value == i;
        assert s.second.values[i + 1].g == 7.0;
    }
    print(s.first.values[0].value, s.second.values[0].value, s.counter.value);
}

with entry {
    run();
    print("released");
}
