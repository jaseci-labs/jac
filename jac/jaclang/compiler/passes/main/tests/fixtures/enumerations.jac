import from enum { unique }

@ unique
enum Color;

impl Color{
    RED = 1,
    GREEN = 2
}

with entry {
    print(Color.RED.value);
}
