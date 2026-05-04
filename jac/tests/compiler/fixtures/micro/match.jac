obj Outer {
    obj Inner {
        obj Point {
            has x: float,
                y: float;
        }
    }
}

def match_example(data: dict) {
    match data {
        # MatchValue
        case 42:
            print("Matched the value 42.");

        # MatchSingleton
        case True:
            print("Matched the singleton True.");

        case None:
            print("Matched the singleton None.");

        # MatchSequence
        case [ 1 , 2 , 3 ]:
            print("Matched a specific sequence [1, 2, 3].");

        # MatchStar
        case [ 1 , * rest , 3 ]:
            print(
                f"Matched a sequence starting with 1 and ending with 3. Middle: {rest}"
            );

        # MatchMapping
        case { "key1" : 1 , "key2" : 2 , ** rest }:
            print(f"Matched a mapping with key1 and key2. Rest: {rest}");

        # MatchClass
        case Outer.Inner.Point(int(a), y = 0):
            print(f"Point with x={a} and y=0");

        # MatchAs
        case [ 1 , 2 , rest_val as value ]:
            print(f"Matched a sequence and captured the last value: {value}");

        # MatchOr
        case [ 1 , 2 ] | [ 3 , 4 ]:
            print("Matched either the sequence [1, 2] or [3, 4].");

        case _:
            print("No match found.");

    }
}
