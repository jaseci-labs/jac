import from c {
    glob:priv strtoul_smallmax: list[u64] = [
             u64(0),
             u64(0),
             u64(9223372036854775807),
             u64(6148914691236517205),
             u64(4611686018427387903),
             u64(3689348814741910323),
             u64(3074457345618258602),
             u64(2635249153387078802),
             u64(2305843009213693951),
             u64(2049638230412172401),
             u64(1844674407370955161),
             u64(1676976733973595601),
             u64(1537228672809129301),
             u64(1418980313362273201),
             u64(1317624576693539401),
             u64(1229782938247303441),
             u64(1152921504606846975),
             u64(1085102592571150095),
             u64(1024819115206086200),
             u64(970881267037344821),
             u64(922337203685477580),
             u64(878416384462359600),
             u64(838488366986797800),
             u64(802032351030850070),
             u64(768614336404564650),
             u64(737869762948382064),
             u64(709490156681136600),
             u64(683212743470724133),
             u64(658812288346769700),
             u64(636094623231363848),
             u64(614891469123651720),
             u64(595056260442243600),
             u64(576460752303423487),
             u64(558992244657865200),
             u64(542551296285575047),
             u64(527049830677415760),
             u64(512409557603043100)
         ],
         strtoul_digitlimit: list[i32] = [
             i32(0),
             i32(0),
             i32(64),
             i32(40),
             i32(32),
             i32(27),
             i32(24),
             i32(22),
             i32(21),
             i32(20),
             i32(19),
             i32(18),
             i32(17),
             i32(17),
             i32(16),
             i32(16),
             i32(16),
             i32(15),
             i32(15),
             i32(15),
             i32(14),
             i32(14),
             i32(14),
             i32(14),
             i32(13),
             i32(13),
             i32(13),
             i32(13),
             i32(13),
             i32(13),
             i32(13),
             i32(12),
             i32(12),
             i32(12),
             i32(12),
             i32(12),
             i32(12)
         ]; def PyOS_strtoul(str_: ptr[u8], ptr_: ptr[ptr[u8]], base: i32) -> u64 {
        result: u64 = u64(0);
        s = str_;

        while s.view(1)[0] != u8(0) and py_isspace(s.view(1)[0]) {
            s = s + 1;
        }

        b = base;
        if b == 0 {
            if s.view(1)[0] == CH_0 {
                s = s + 1;
                ch = s.view(1)[0];
                if ch == CH_LOWER_X or ch == CH_UPPER_X {
                    if digit_value((s + 1).view(1)[0]) >= 16 {
                        if ptr_ {
                            ptr_.view(1)[0] = s;
                        }
                        return u64(0);
                    }
                    s = s + 1;
                    b = 16;
                } elif ch == CH_LOWER_O or ch == CH_UPPER_O {
                    if digit_value((s + 1).view(1)[0]) >= 8 {
                        if ptr_ {
                            ptr_.view(1)[0] = s;
                        }
                        return u64(0);
                    }
                    s = s + 1;
                    b = 8;
                } elif ch == CH_LOWER_B or ch == CH_UPPER_B {
                    if digit_value((s + 1).view(1)[0]) >= 2 {
                        if ptr_ {
                            ptr_.view(1)[0] = s;
                        }
                        return u64(0);
                    }
                    s = s + 1;
                    b = 2;
                } else {
                    while s.view(1)[0] == CH_0 {
                        s = s + 1;
                    }
                    while py_isspace(s.view(1)[0]) {
                        s = s + 1;
                    }
                    if ptr_ {
                        ptr_.view(1)[0] = s;
                    }
                    return u64(0);
                }
            } else {
                b = 10;
            }
        } elif b == 16 {
            if s.view(1)[0] == CH_0 {
                s = s + 1;
                ch = s.view(1)[0];
                if ch == CH_LOWER_X or ch == CH_UPPER_X {
                    if digit_value((s + 1).view(1)[0]) >= 16 {
                        if ptr_ {
                            ptr_.view(1)[0] = s;
                        }
                        return u64(0);
                    }
                    s = s + 1;
                }
            }
        } elif b == 8 {
            if s.view(1)[0] == CH_0 {
                s = s + 1;
                ch = s.view(1)[0];
                if ch == CH_LOWER_O or ch == CH_UPPER_O {
                    if digit_value((s + 1).view(1)[0]) >= 8 {
                        if ptr_ {
                            ptr_.view(1)[0] = s;
                        }
                        return u64(0);
                    }
                    s = s + 1;
                }
            }
        } elif b == 2 {
            if s.view(1)[0] == CH_0 {
                s = s + 1;
                ch = s.view(1)[0];
                if ch == CH_LOWER_B or ch == CH_UPPER_B {
                    if digit_value((s + 1).view(1)[0]) >= 2 {
                        if ptr_ {
                            ptr_.view(1)[0] = s;
                        }
                        return u64(0);
                    }
                    s = s + 1;
                }
            }
        }

        if b < 2 or b > 36 {
            if ptr_ {
                ptr_.view(1)[0] = s;
            }
            return u64(0);
        }

        while s.view(1)[0] == CH_0 {
            s = s + 1;
        }

        wide = i64(b);
        ovlimit = (addressof(strtoul_digitlimit) + wide).view(1)[0];
        overflowed = False;
        while True {
            c = digit_value(s.view(1)[0]);
            if c >= wide {
                break;
            }
            if ovlimit > 0 {
                result = result * u64(wide) + u64(c);
            } else {
                if ovlimit < 0 {
                    overflowed = True;
                    break;
                }
                if result > (addressof(strtoul_smallmax) + wide).view(1)[0] {
                    overflowed = True;
                    break;
                }
                result = result * u64(wide);
                temp_result = wrapping_add(result, u64(c));
                if temp_result < result {
                    overflowed = True;
                    break;
                }
                result = temp_result;
            }
            s = s + 1;
            ovlimit -= 1;
        }

        if overflowed {
            if ptr_ {
                while digit_value(s.view(1)[0]) < wide {
                    s = s + 1;
                }
                ptr_.view(1)[0] = s;
            }
            jacpy_set_errno(ERANGE);
            return ULONG_MAX;
        }

        if ptr_ {
            ptr_.view(1)[0] = s;
        }
        return result;
    }  def PyOS_strtol(str_: ptr[u8], ptr_: ptr[ptr[u8]], base: i32) -> i64 {
        result: i64 = 0;
        s = str_;
        while s.view(1)[0] != u8(0) and py_isspace(s.view(1)[0]) {
            s = s + 1;
        }

        sign = s.view(1)[0];
        if sign == CH_PLUS or sign == CH_MINUS {
            s = s + 1;
        }

        uresult = PyOS_strtoul(s, ptr_, base);

        if uresult <= u64(LONG_MAX) {
            result = i64(uresult);
            if sign == CH_MINUS {
                result = -result;
            }
        } elif sign == CH_MINUS and uresult == PY_ABS_LONG_MIN {
            result = LONG_MIN;
        } else {
            jacpy_set_errno(ERANGE);
            result = LONG_MAX;
        }
        return result;
    }
}

glob:priv CH_0: Final[u8] = u8(48),
     CH_PLUS: Final[u8] = u8(43),
     CH_MINUS: Final[u8] = u8(45),
     CH_LOWER_X: Final[u8] = u8(120),
     CH_UPPER_X: Final[u8] = u8(88),
     CH_LOWER_O: Final[u8] = u8(111),
     CH_UPPER_O: Final[u8] = u8(79),
     CH_LOWER_B: Final[u8] = u8(98),
     CH_UPPER_B: Final[u8] = u8(66),
     ULONG_MAX: Final[u64] = u64(0xffffffffffffffff),
     LONG_MAX: Final[i64] = 0x7fffffffffffffff,
     LONG_MIN: Final[i64] = -0x7fffffffffffffff - 1,
     PY_ABS_LONG_MIN: Final[u64] = u64(0x8000000000000000);
