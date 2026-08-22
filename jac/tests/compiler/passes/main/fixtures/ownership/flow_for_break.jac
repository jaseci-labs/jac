"""break out of a flow for body is E1313; break of an inner plain loop is fine."""

glob xs = [1, 2, 3];

with entry {
    flow for v in &xs {
        i = 0;
        while i < v {
            i += 1;
            if i > 1 {
                break;
            }
        }
        if v > 2 {
            break;
        }
        print(v);
    }
}
