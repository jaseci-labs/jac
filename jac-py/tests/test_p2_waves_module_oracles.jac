"""Consolidated differential oracles for P2 waves 2-11."""

import json;
import os;
import from tests.support { JAC_ROOT }
import from tests.compiler.c2jac.lift_oracle {
    assert_lift_matches_c,
    assert_staged_jac_matches_c
}

glob REPO_ROOT: str = os.path.dirname(JAC_ROOT),
     MODULES: str = os.path.join(REPO_ROOT, "jac-py", "Modules"),
     TESTS: str = os.path.join(REPO_ROOT, "jac-py", "tests");


def _oracle(c_name: str, driver: str, jac_entry: str) {
    c_path = os.path.join(MODULES, c_name);
    assert_lift_matches_c(c_path, driver, jac_entry, include_dirs=[MODULES]);
}


def _staged_oracle(c_name: str, driver: str, jac_entry: str) {
    base = os.path.splitext(c_name)[0];
    c_path = os.path.join(MODULES, c_name);
    jac_path = os.path.join(MODULES, f"{base}.jac");
    assert_staged_jac_matches_c(
        c_path, jac_path, driver, jac_entry, include_dirs=[MODULES]
    );
}


def _wave_number(path: str) -> int {
    name = os.path.basename(path);
    return int(name.split("wave")[1].split(".")[0]);
}


def _manifest_paths() -> list {
    paths: list = [];
    for name in os.listdir(TESTS) {
        if name.startswith("conformance_manifest_wave") and name.endswith(".json") {
            paths.append(os.path.join(TESTS, name));
        }
    }
    # os.listdir order is not a contract. Sort numerically, not lexically
    # (wave10 must follow wave9).
    for i in range(len(paths)) {
        min_i = i;
        for j in range(i + 1, len(paths)) {
            if _wave_number(paths[j]) < _wave_number(paths[min_i]) {
                min_i = j;
            }
        }
        if min_i != i {
            tmp = paths[i];
            paths[i] = paths[min_i];
            paths[min_i] = tmp;
        }
    }
    return paths;
}


def _load_json(path: str) -> dict {
    with open(path) as f {
        return json.load(f);
    }
}


def _expected_stems(wave: int) -> list {
    if wave == 2 {
        return ["_opcode", "_stat", "math_gcd", "pystrnicmp"];
    }
    if wave == 3 {
        return ["math_count_bits", "math_lcm_long", "pyctype_digit", "strhex_byte"];
    }
    if wave == 4 {
        return ["math_factorial_small", "pyctype_alpha", "pyctype_space", "pystricmp"];
    }
    if wave == 5 {
        return ["math_isqrt_small", "pyctype_alnum", "pyctype_lower", "pyctype_xdigit"];
    }
    if wave == 6 {
        return ["math_pow2_check", "pyctype_print", "pyctype_punct", "pyctype_upper"];
    }
    if wave == 7 {
        return ["math_ilog2_small", "pyctype_blank", "pyctype_cntrl", "pyctype_graph"];
    }
    if wave == 8 {
        return ["math_abs_diff", "math_clz32_small", "math_ctz_small", "math_min_u"];
    }
    if wave == 9 {
        return ["math_max_u", "pystr_count_char", "pystr_find_char", "pystr_len_c"];
    }
    if wave == 10 {
        return ["math_gcd_iter", "math_lcm_u", "pystr_endswith_c", "pystr_startswith_c"];
    }
    if wave == 11 {
        return ["math_popcount_u", "math_pow_mod", "pystr_cmp_c", "pystr_contains_c"];
    }
    return [];
}


def _wave_2_cases(errors: list) {
    try {
        _staged_oracle(
        "_stat.c",
        "#include <stdio.h>\n"
        "unsigned long stat_S_IMODE(long omode);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", (int)stat_S_IMODE(0x81a4));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(stat_S_IMODE(0x81a4));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 2 jac-py _stat: cc vs staged jac agree on S_IMODE: {e}");
    }

    try {
        _staged_oracle(
        "_stat.c",
        "#include <stdio.h>\n"
        "unsigned long stat_S_IFMT(long omode);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", (int)stat_S_IFMT(0x81a4));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(stat_S_IFMT(0x81a4));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 2 jac-py _stat: cc vs staged jac agree on S_IFMT: {e}");
    }

    try {
        _staged_oracle(
        "_opcode.c",
        "#include <stdio.h>\n"
        "int opcode_is_valid(int opcode);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", opcode_is_valid(84));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(opcode_is_valid(84));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 2 jac-py _opcode: cc vs staged jac agree on is_valid(84): {e}");
    }

    try {
        _staged_oracle(
        "_opcode.c",
        "#include <stdio.h>\n"
        "int opcode_has_arg(int opcode);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", opcode_has_arg(84));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(opcode_has_arg(84));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 2 jac-py _opcode: cc vs staged jac agree on has_arg(84): {e}");
    }

    try {
        _oracle(
        "math_gcd.c",
        "#include <stdio.h>\n"
        "long math_gcd_long(long a, long b);\n"
        "int main(void) {\n"
        "    printf(\"%ld\\n\", math_gcd_long(48, 18));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(math_gcd_long(48, 18));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 2 jac-py math_gcd: cc vs lifted jac agree on gcd(48, 18): {e}");
    }

    try {
        _oracle(
        "pystrnicmp.c",
        "#include <stdio.h>\n"
        "int PyOS_mystrnicmp(const char *s1, const char *s2, long size);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", PyOS_mystrnicmp(\"AbC\", \"abd\", 3));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(PyOS_mystrnicmp(\"AbC\", \"abd\", 3));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 2 jac-py pystrnicmp: cc vs lifted jac agree on prefix compare: {e}");
    }

}


def _wave_3_cases(errors: list) {
    try {
        _staged_oracle(
        "math_count_bits.c",
        "#include <stdio.h>\n"
        "unsigned long math_count_set_bits(unsigned long n);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", math_count_set_bits(0x0f0ful));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(math_count_set_bits(0x0f0f));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 3 jac-py math_count_bits: cc vs staged jac agree on popcount(0x0f0f): {e}");
    }

    try {
        _staged_oracle(
        "math_lcm_long.c",
        "#include <stdio.h>\n"
        "long math_lcm_long(long a, long b);\n"
        "int main(void) {\n"
        "    printf(\"%ld\\n\", math_lcm_long(12, 18));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(math_lcm_long(12, 18));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 3 jac-py math_lcm_long: cc vs staged jac agree on lcm(12, 18): {e}");
    }

    try {
        _staged_oracle(
        "strhex_byte.c",
        "#include <stdio.h>\n"
        "unsigned int strhex_pack_byte(unsigned char value);\n"
        "int main(void) {\n"
        "    printf(\"%u\\n\", strhex_pack_byte(0xab));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(strhex_pack_byte(0xab));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 3 jac-py strhex_byte: cc vs staged jac agree on pack(0xab): {e}");
    }

    try {
        _staged_oracle(
        "pyctype_digit.c",
        "#include <stdio.h>\n"
        "int pyctype_isdigit(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_isdigit(57));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_isdigit(57));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 3 jac-py pyctype_digit: cc vs staged jac agree on isdigit(57): {e}");
    }

}


def _wave_4_cases(errors: list) {
    try {
        _staged_oracle(
        "pystricmp.c",
        "#include <stdio.h>\n"
        "int PyOS_mystricmp(const char *s1, const char *s2);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", PyOS_mystricmp(\"ABC\", \"abc\"));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(PyOS_mystricmp(\"ABC\", \"abc\"));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 4 jac-py pystricmp: cc vs staged jac agree on ABC vs abc: {e}");
    }

    try {
        _staged_oracle(
        "pystricmp.c",
        "#include <stdio.h>\n"
        "int PyOS_mystricmp(const char *s1, const char *s2);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", PyOS_mystricmp(\"\", \"\"));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(PyOS_mystricmp(\"\", \"\"));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 4 jac-py pystricmp: cc vs staged jac agree on empty strings: {e}");
    }

    try {
        _staged_oracle(
        "pystricmp.c",
        "#include <stdio.h>\n"
        "int PyOS_mystricmp(const char *s1, const char *s2);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", PyOS_mystricmp(\"ab\", \"abc\"));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(PyOS_mystricmp(\"ab\", \"abc\"));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 4 jac-py pystricmp: cc vs staged jac agree on prefix mismatch: {e}");
    }

    try {
        _staged_oracle(
        "pyctype_space.c",
        "#include <stdio.h>\n"
        "int pyctype_isspace(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_isspace(32));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_isspace(32));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 4 jac-py pyctype_space: cc vs staged jac agree on isspace(32): {e}");
    }

    try {
        _staged_oracle(
        "pyctype_alpha.c",
        "#include <stdio.h>\n"
        "int pyctype_isalpha(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_isalpha(65));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_isalpha(65));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 4 jac-py pyctype_alpha: cc vs staged jac agree on isalpha(65): {e}");
    }

    try {
        _staged_oracle(
        "math_factorial_small.c",
        "#include <stdio.h>\n"
        "unsigned long math_factorial_small(unsigned long n);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", math_factorial_small(5));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(math_factorial_small(5));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 4 jac-py math_factorial_small: cc vs staged jac agree on fact(5): {e}");
    }

}


def _wave_5_cases(errors: list) {
    try {
        _staged_oracle(
        "pyctype_xdigit.c",
        "#include <stdio.h>\n"
        "int pyctype_isxdigit(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_isxdigit(65));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_isxdigit(65));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 5 jac-py pyctype_xdigit: cc vs staged jac agree on isxdigit(65): {e}");
    }

    try {
        _staged_oracle(
        "pyctype_alnum.c",
        "#include <stdio.h>\n"
        "int pyctype_isalnum(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_isalnum(97));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_isalnum(97));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 5 jac-py pyctype_alnum: cc vs staged jac agree on isalnum(97): {e}");
    }

    try {
        _staged_oracle(
        "pyctype_lower.c",
        "#include <stdio.h>\n"
        "int pyctype_islower(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_islower(97));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_islower(97));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 5 jac-py pyctype_lower: cc vs staged jac agree on islower(97): {e}");
    }

    try {
        _staged_oracle(
        "math_isqrt_small.c",
        "#include <stdio.h>\n"
        "unsigned long math_isqrt_small(unsigned long n);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", math_isqrt_small(16));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(math_isqrt_small(16));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 5 jac-py math_isqrt_small: cc vs staged jac agree on isqrt(16): {e}");
    }

}


def _wave_6_cases(errors: list) {
    try {
        _staged_oracle(
        "pyctype_upper.c",
        "#include <stdio.h>\n"
        "int pyctype_isupper(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_isupper(65));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_isupper(65));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 6 jac-py pyctype_upper: cc vs staged jac agree on isupper(65): {e}");
    }

    try {
        _staged_oracle(
        "pyctype_print.c",
        "#include <stdio.h>\n"
        "int pyctype_isprint(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_isprint(65));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_isprint(65));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 6 jac-py pyctype_print: cc vs staged jac agree on isprint(65): {e}");
    }

    try {
        _staged_oracle(
        "pyctype_punct.c",
        "#include <stdio.h>\n"
        "int pyctype_ispunct(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_ispunct(33));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_ispunct(33));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 6 jac-py pyctype_punct: cc vs staged jac agree on ispunct(33): {e}");
    }

    try {
        _staged_oracle(
        "math_pow2_check.c",
        "#include <stdio.h>\n"
        "int math_pow2_check(unsigned long n);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", math_pow2_check(16));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(math_pow2_check(16));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 6 jac-py math_pow2_check: cc vs staged jac agree on pow2(16): {e}");
    }

}


def _wave_7_cases(errors: list) {
    try {
        _staged_oracle(
        "pyctype_graph.c",
        "#include <stdio.h>\n"
        "int pyctype_isgraph(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_isgraph(65));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_isgraph(65));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 7 jac-py pyctype_graph: cc vs staged jac agree on isgraph(65): {e}");
    }

    try {
        _staged_oracle(
        "pyctype_cntrl.c",
        "#include <stdio.h>\n"
        "int pyctype_iscntrl(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_iscntrl(7));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_iscntrl(7));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 7 jac-py pyctype_cntrl: cc vs staged jac agree on iscntrl(7): {e}");
    }

    try {
        _staged_oracle(
        "pyctype_blank.c",
        "#include <stdio.h>\n"
        "int pyctype_isblank(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_isblank(9));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_isblank(9));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 7 jac-py pyctype_blank: cc vs staged jac agree on isblank(9): {e}");
    }

    try {
        _staged_oracle(
        "math_ilog2_small.c",
        "#include <stdio.h>\n"
        "int math_ilog2_small(unsigned long n);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", math_ilog2_small(16));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(math_ilog2_small(16));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 7 jac-py math_ilog2_small: cc vs staged jac agree on ilog2(16): {e}");
    }

}


def _wave_8_cases(errors: list) {
    try {
        _staged_oracle(
        "math_ctz_small.c",
        "#include <stdio.h>\n"
        "int math_ctz_small(unsigned long n);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", math_ctz_small(8));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(math_ctz_small(8));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 8 jac-py math_ctz_small: cc vs staged jac agree on ctz(8): {e}");
    }

    try {
        _staged_oracle(
        "math_clz32_small.c",
        "#include <stdio.h>\n"
        "int math_clz32_small(unsigned long n);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", math_clz32_small(1));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(math_clz32_small(1));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 8 jac-py math_clz32_small: cc vs staged jac agree on clz32(1): {e}");
    }

    try {
        _staged_oracle(
        "math_abs_diff.c",
        "#include <stdio.h>\n"
        "unsigned long math_abs_diff(unsigned long a, unsigned long b);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", math_abs_diff(10, 7));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(math_abs_diff(10, 7));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 8 jac-py math_abs_diff: cc vs staged jac agree on abs_diff(10,7): {e}");
    }

    try {
        _staged_oracle(
        "math_min_u.c",
        "#include <stdio.h>\n"
        "unsigned long math_min_u(unsigned long a, unsigned long b);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", math_min_u(3, 9));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(math_min_u(3, 9));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 8 jac-py math_min_u: cc vs staged jac agree on min_u(3,9): {e}");
    }

}


def _wave_9_cases(errors: list) {
    try {
        _staged_oracle(
        "math_max_u.c",
        "#include <stdio.h>\n"
        "unsigned long math_max_u(unsigned long a, unsigned long b);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", math_max_u(3, 9));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(math_max_u(3, 9));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 9 jac-py math_max_u: cc vs staged jac agree on max_u(3,9): {e}");
    }

    try {
        _staged_oracle(
        "pystr_len_c.c",
        "#include <stdio.h>\n"
        "unsigned long pystr_len_c(const char *s);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", pystr_len_c(\"abc\"));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pystr_len_c(\"abc\"));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 9 jac-py pystr_len_c: cc vs staged jac agree on len(abc): {e}");
    }

    try {
        _staged_oracle(
        "pystr_find_char.c",
        "#include <stdio.h>\n"
        "int pystr_find_char(const char *s, int ch);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pystr_find_char(\"abc\", 'b'));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pystr_find_char(\"abc\", 98));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 9 jac-py pystr_find_char: cc vs staged jac agree on find(b): {e}");
    }

    try {
        _staged_oracle(
        "pystr_count_char.c",
        "#include <stdio.h>\n"
        "unsigned long pystr_count_char(const char *s, int ch);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", pystr_count_char(\"abaca\", 'a'));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pystr_count_char(\"abaca\", 97));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 9 jac-py pystr_count_char: cc vs staged jac agree on count(a): {e}");
    }

}


def _wave_10_cases(errors: list) {
    try {
        _staged_oracle(
        "math_gcd_iter.c",
        "#include <stdio.h>\n"
        "unsigned long math_gcd_iter(unsigned long a, unsigned long b);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", math_gcd_iter(12, 18));\n"
        "    return 0;\n"
"}\n",
        "with entry {\n" "    print(math_gcd_iter(12, 18));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 10 jac-py math_gcd_iter: cc vs staged jac agree on gcd(12,18): {e}");
    }

    try {
        _staged_oracle(
        "math_lcm_u.c",
        "#include <stdio.h>\n"
        "unsigned long math_lcm_u(unsigned long a, unsigned long b);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", math_lcm_u(4, 6));\n"
        "    return 0;\n"
"}\n",
        "with entry {\n" "    print(math_lcm_u(4, 6));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 10 jac-py math_lcm_u: cc vs staged jac agree on lcm(4,6): {e}");
    }

    try {
        _staged_oracle(
        "pystr_startswith_c.c",
        "#include <stdio.h>\n"
        "int pystr_startswith_c(const char *s, const char *prefix);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pystr_startswith_c(\"abcdef\", \"abc\"));\n"
        "    return 0;\n"
"}\n",
        "with entry {\n" "    print(pystr_startswith_c(\"abcdef\", \"abc\"));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 10 jac-py pystr_startswith_c: cc vs staged jac agree on startswith abc: {e}");
    }

    try {
        _staged_oracle(
        "pystr_endswith_c.c",
        "#include <stdio.h>\n"
        "int pystr_endswith_c(const char *s, const char *suffix);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pystr_endswith_c(\"abcdef\", \"def\"));\n"
        "    return 0;\n"
"}\n",
        "with entry {\n" "    print(pystr_endswith_c(\"abcdef\", \"def\"));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 10 jac-py pystr_endswith_c: cc vs staged jac agree on endswith def: {e}");
    }

}


def _wave_11_cases(errors: list) {
    try {
        _staged_oracle(
        "math_pow_mod.c",
        "#include <stdio.h>\n"
        "unsigned long math_pow_mod(unsigned long base, unsigned long exp, unsigned long mod);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", math_pow_mod(2, 10, 1000));\n"
        "    return 0;\n"
"}\n",
        "with entry {\n" "    print(math_pow_mod(2, 10, 1000));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 11 jac-py math_pow_mod: cc vs staged jac agree on powmod(2,10,1000): {e}");
    }

    try {
        _staged_oracle(
        "math_popcount_u.c",
        "#include <stdio.h>\n"
        "unsigned long math_popcount_u(unsigned long n);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", math_popcount_u(15));\n"
        "    return 0;\n"
"}\n",
        "with entry {\n" "    print(math_popcount_u(15));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 11 jac-py math_popcount_u: cc vs staged jac agree on popcount(15): {e}");
    }

    try {
        _staged_oracle(
        "pystr_contains_c.c",
        "#include <stdio.h>\n"
        "int pystr_contains_c(const char *hay, const char *needle);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pystr_contains_c(\"abcdef\", \"cd\"));\n"
        "    return 0;\n"
"}\n",
        "with entry {\n" "    print(pystr_contains_c(\"abcdef\", \"cd\"));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 11 jac-py pystr_contains_c: cc vs staged jac agree on contains cd: {e}");
    }

    try {
        _staged_oracle(
        "pystr_cmp_c.c",
        "#include <stdio.h>\n"
        "int pystr_cmp_c(const char *a, const char *b);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pystr_cmp_c(\"abc\", \"abd\"));\n"
        "    return 0;\n"
"}\n",
        "with entry {\n" "    print(pystr_cmp_c(\"abc\", \"abd\"));\n" "}\n"
    );
    } except Exception as e {
        errors.append(f"wave 11 jac-py pystr_cmp_c: cc vs staged jac agree on cmp abc abd: {e}");
    }

}


def _run_wave_cases(wave: int) -> list {
    errors: list = [];
    if wave == 2 {
        _wave_2_cases(errors);
        return errors;
    }
    if wave == 3 {
        _wave_3_cases(errors);
        return errors;
    }
    if wave == 4 {
        _wave_4_cases(errors);
        return errors;
    }
    if wave == 5 {
        _wave_5_cases(errors);
        return errors;
    }
    if wave == 6 {
        _wave_6_cases(errors);
        return errors;
    }
    if wave == 7 {
        _wave_7_cases(errors);
        return errors;
    }
    if wave == 8 {
        _wave_8_cases(errors);
        return errors;
    }
    if wave == 9 {
        _wave_9_cases(errors);
        return errors;
    }
    if wave == 10 {
        _wave_10_cases(errors);
        return errors;
    }
    if wave == 11 {
        _wave_11_cases(errors);
        return errors;
    }
    errors.append(f"wave {wave}: no oracle cases");
    return errors;
}


test "P2 waves 2-11 module oracles" {
    failures: list = [];
    paths = _manifest_paths();
    assert len(paths) > 0, "no conformance wave manifests found";
    for path in paths {
        wave = _wave_number(path);
        manifest = _load_json(path);
        modules = manifest["modules"] as list;
        expected = _expected_stems(wave);
        actual = sorted([row["stem"] for row in modules]);
        if len(modules) != len(expected) or actual != expected {
            failures.append(
                f"wave {wave}: manifest modules {actual} != expected {expected}"
            );
            continue;
        }
        errors = _run_wave_cases(wave);
        if len(errors) > 0 {
            print(f"wave {wave}: FAIL ({len(errors)} oracle cases)");
            failures.extend(errors);
        } else {
            print(f"wave {wave}: PASS ({len(expected)} modules)");
        }
    }
    assert not failures, "\n".join(failures);
}
