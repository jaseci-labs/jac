"""Calls into `math`, directly and through a separately compiled module."""
import math;
import from libm_names_lib { Arrow, heading, curve }

with entry {
    print(Arrow(x=3.0, y=4.0).length(), round(heading(0.5), 9), round(curve(0.25), 9));
    print(math.sqrt(16.0), round(math.cos(0.0), 9), round(math.atan2(1.0, 1.0), 9));
    try {
        math.sqrt(-1.0);
    } except ValueError as err {
        print("sqrt:", err);
    }
}
