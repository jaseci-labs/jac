"""Shared networking utilities: int-to-string and sockaddr struct offsets."""

# struct addrinfo offsets (x86_64 Linux)
glob:pub AI_FAMILY: int = 4,
     AI_SOCKTYPE: int = 8,
     AI_ADDRLEN: int = 16,
     AI_ADDR: int = 24,
     AI_NEXT: int = 40,
     SIN_FAMILY: int = 0,
     SIN_PORT: int = 2,
     SIN_ADDR: int = 4,
     SIN6_FAMILY: int = 0,
     SIN6_PORT: int = 2,
     SIN6_ADDR: int = 8,
     SS_SIZE: int = 128,
     INET_STRLEN: int = 16,
     INET6_STRLEN: int = 46;

# struct sockaddr_in offsets

# struct sockaddr_in6 offsets

# struct sockaddr_storage size
"""Convert a small non-negative integer to its decimal string (port fast-path)."""
def:pub int_to_str(n: int) -> str {
    if n < 0 {
        return "0";
    }
    if n == 0 {
        return "0";
    }
    if n < 10 {
        if n == 0 {
            return "0";
        }
        if n == 1 {
            return "1";
        }
        if n == 2 {
            return "2";
        }
        if n == 3 {
            return "3";
        }
        if n == 4 {
            return "4";
        }
        if n == 5 {
            return "5";
        }
        if n == 6 {
            return "6";
        }
        if n == 7 {
            return "7";
        }
        if n == 8 {
            return "8";
        }
        return "9";
    }
    # General path for ports and small ints
    digits: list[str] = [];
    rem: int = n;
    while rem > 0 {
        d: int = rem % 10;
        rem = rem // 10;
        if d == 0 {
            digits.append("0");
        } elif d == 1 {
            digits.append("1");
        } elif d == 2 {
            digits.append("2");
        } elif d == 3 {
            digits.append("3");
        } elif d == 4 {
            digits.append("4");
        } elif d == 5 {
            digits.append("5");
        } elif d == 6 {
            digits.append("6");
        } elif d == 7 {
            digits.append("7");
        } elif d == 8 {
            digits.append("8");
        } else {
            digits.append("9");
        }
    }
    result: str = "";
    i: int = len(digits) - 1;
    while i >= 0 {
        result = result + digits[i];
        i = i - 1;
    }
    return result;
}
