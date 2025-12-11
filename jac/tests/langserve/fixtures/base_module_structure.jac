"""A Docstring can be added the head of any module.

Any element in the module can also have a docstring.
If there is only one docstring before the first element,
it is assumed to be a module docstring.
"""

"""A docstring for add function"""
def add(a: int, b: int) -> int {
    return a + b;
}
# No docstring for subtract function
def subtract(a: int, b: int) -> int {
    return a - b;
}

with entry:__main__ {
    print(add(1, subtract(3, 1)));
}

glob x: int = 10;

enum Colorenum { RED, GREEN, BLUE }

obj Colour1 {
    has color1: Colorenum,
        point1: int;

    def get_color1 -> Colorenum;
}

impl Colour1.get_color1 -> Colorenum {
    return self.color1;
}

obj red(Colour1) {
    has base_colorred: Colorenum = Colorenum.RED,
        pointred: int = 10;

    obj inner_red {
        has color22: enum_red = enum_red.BLUE22,
            doublepoint22: doubleinner.double = 2,
            point22: int = 20;

        def apply_inner_red -> enum_red {
            return self.color22;
        }

        enum enum_red { RED22, GREEN22, BLUE22 }
    }

    class doubleinner {
        has double: int = 2;
    }

    def apply_red -> int {
        x = self.inner_red.color22.GREEN22;
        return self.point1 + self.pointred;
    }
}

with entry:__main__ {
    r = red(color1=Colorenum.GREEN, point1=20);
    print(r.get_color1());
    print(r.inner_red);
}
