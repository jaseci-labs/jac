"""Arbitrary-precision compiler constants in Jac-owned base-2**15 storage."""
import from jaclang.runtime.python.objects { PyObj, PyInt, PyStr }

obj PyBigInt(PyObj) {
    has digits: list[int],
        negative: bool = False;

    def tp_bool -> bool {
        return bool(self.digits);
    }

    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="n:" + integer_decimal(self));
    }
}

def integer_from_digits(digits: list[int], negative: bool) -> PyObj {
    normalized = digits.copy();
    while normalized and normalized[-1] == 0 {
        normalized.pop();
    }
    if not normalized {
        return PyInt(t="int", val=0);
    }
    count = len(normalized);
    if count > 5 or (count == 5 and normalized[4] >= 8) {
        if negative
            and count == 5
            and normalized[4] == 8
            and normalized[0] == 0
            and normalized[1] == 0
            and normalized[2] == 0
            and normalized[3] == 0 {
            return PyInt(t="int", val=-9223372036854775807 - 1);
        }
        return PyBigInt(t="int", digits=normalized, negative=negative);
    }
    value = 0;
    for index in range(count - 1, -1, -1) {
        value = value * 32768 + normalized[index];
    }
    return PyInt(t="int", val=-value if negative else value);
}

def integer_decimal(value: PyBigInt) -> str {
    remaining = value.digits.copy();
    decimal: list[str] = [];
    while remaining {
        carry = 0;
        for index in range(len(remaining) - 1, -1, -1) {
            current = carry * 32768 + remaining[index];
            remaining[index] = current // 10;
            carry = current % 10;
        }
        decimal.append(str(carry));
        while remaining and remaining[-1] == 0 {
            remaining.pop();
        }
    }
    result = "-" if value.negative and decimal else "";
    for index in range(len(decimal) - 1, -1, -1) {
        result += decimal[index];
    }
    return result if decimal else "0";
}

def integer_from_marshal(data: list[int]) -> PyObj {
    # The retained numeric runtime supplies a single marshal v4 integer.
    # Decode into Jac-owned storage before releasing its Python byte buffer.
    if len(data) < 5 {
        raise ValueError("Truncated integer constant");
    }
    word = data[1] | (data[2] << 8) | (data[3] << 16) | (data[4] << 24);
    if word & 2147483648 {
        word -= 4294967296;
    }
    tag = data[0] & 127;
    if tag == 105 {
        if len(data) != 5 {
            raise ValueError("Invalid integer constant size");
        }
        return PyInt(t="int", val=word);
    }
    if tag != 108 {
        raise ValueError("Expected an integer constant");
    }
    negative = word < 0;
    count = -word if negative else word;
    if count != (len(data) - 5) // 2 or (len(data) - 5) % 2 {
        raise ValueError("Invalid integer constant size");
    }
    digits: list[int] = [];
    for index in range(count) {
        offset = 5 + 2 * index;
        digit = data[offset] | (data[offset + 1] << 8);
        if digit >= 32768 {
            raise ValueError("Invalid integer constant digit");
        }
        digits.append(digit);
    }
    return integer_from_digits(digits, negative);
}

def integer_digits(value: PyObj) -> list[int] {
    if isinstance(value, PyBigInt) {
        return value.digits;
    }
    if not isinstance(value, PyInt) {
        raise TypeError("Expected an integer constant");
    }
    negative = value.val < 0;
    remaining = -(value.val + 1) if negative else value.val;
    carry = 1 if negative else 0;
    digits: list[int] = [];
    while remaining > 0 or carry > 0 {
        digit = (remaining & 32767) + carry;
        digits.append(digit & 32767);
        carry = digit >> 15;
        remaining >>= 15;
    }
    return digits;
}

def integer_negative(value: PyObj) -> bool {
    if isinstance(value, PyBigInt) {
        return value.negative;
    }
    if not isinstance(value, PyInt) {
        raise TypeError("Expected an integer constant");
    }
    return value.val < 0;
}

def integer_negate(value: PyObj) -> PyObj {
    return integer_from_digits(integer_digits(value), not integer_negative(value));
}

def integer_add(left: PyObj, right: PyObj, subtract: bool = False) -> PyObj {
    a = integer_digits(left);
    b = integer_digits(right);
    a_negative = integer_negative(left);
    b_negative = integer_negative(right) != subtract;
    digits: list[int] = [];
    if a_negative == b_negative {
        carry = 0;
        for index in range(max(len(a), len(b))) {
            digit = (a[index] if index < len(a) else 0)
                + (b[index] if index < len(b) else 0)
                + carry;
            digits.append(digit & 32767);
            carry = digit >> 15;
        }
        if carry {
            digits.append(carry);
        }
        return integer_from_digits(digits, a_negative);
    }
    comparison = len(a) - len(b);
    if comparison == 0 {
        for index in range(len(a) - 1, -1, -1) {
            if a[index] != b[index] {
                comparison = a[index] - b[index];
                break;
            }
        }
    }
    if comparison == 0 {
        return PyInt(t="int", val=0);
    }
    larger = a if comparison > 0 else b;
    smaller = b if comparison > 0 else a;
    borrow = 0;
    for index in range(len(larger)) {
        digit = larger[index]
            - (smaller[index] if index < len(smaller) else 0)
            - borrow;
        borrow = 1 if digit < 0 else 0;
        digits.append(digit + 32768 if borrow else digit);
    }
    return integer_from_digits(digits, a_negative if comparison > 0 else b_negative);
}

def integer_to_float(value: PyObj) -> float {
    if isinstance(value, PyInt) {
        return float(value.val);
    }
    digits = integer_digits(value);
    if not digits {
        return 0.0;
    }
    bits = (len(digits) - 1) * 15;
    top = digits[-1];
    while top {
        bits += 1;
        top >>= 1;
    }
    if bits > 1024 {
        raise OverflowError("int too large to convert to float");
    }
    shift = max(0, bits - 53);
    mantissa = 0;
    for index in range(bits - 1, shift - 1, -1) {
        mantissa = (mantissa << 1) | ((digits[index // 15] >> (index % 15)) & 1);
    }
    if shift {
        guard_index = shift - 1;
        guard = (digits[guard_index // 15] >> (guard_index % 15)) & 1;
        sticky = False;
        for index in range(guard_index // 15) {
            if digits[index] {
                sticky = True;
                break;
            }
        }
        mask = (1 << (guard_index % 15)) - 1;
        sticky = sticky or bool(digits[guard_index // 15] & mask);
        if guard and (sticky or bool(mantissa & 1)) {
            mantissa += 1;
        }
    }
    result = float(mantissa);
    for index in range(shift) {
        result *= 2.0;
    }
    if result * 0.0 != 0.0 {
        raise OverflowError("int too large to convert to float");
    }
    return -result if integer_negative(value) else result;
}
