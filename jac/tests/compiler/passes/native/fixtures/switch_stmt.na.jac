na {
    enum Color {
        RED = 0,
        GREEN = 1,
        BLUE = 2
    }

    def switch_int(x: int) -> int {
        result = 0;
        switch x {
            case 1:
                result = 10;
            case 2:
                result = 20;
            case 3:
                result = 30;
            default:
                result = -1;
        }
        return result;
    }

    def switch_enum(c: Color) -> int {
        switch c {
            case Color.RED:
                return 100;
            case Color.GREEN:
                return 200;
            case Color.BLUE:
                return 300;
            default:
                return -1;
        }
    }

    def switch_str(s: str) -> int {
        switch s {
            case "(":
                return 1;
            case ")":
                return 2;
            case "{":
                return 3;
            case "}":
                return 4;
            default:
                return 0;
        }
    }

    def switch_no_default(x: int) -> int {
        result = -1;
        switch x {
            case 10:
                result = 100;
            case 20:
                result = 200;
        }
        return result;
    }

    with entry {
        x = 0;
    }
}
