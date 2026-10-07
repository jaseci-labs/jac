// Tests for ECMAScript string-to-number coercion.
// Covers: unary +, Number(), arithmetic operators, parseInt/parseFloat,
// Math methods with string args, and all edge cases in str_to_float.

var _passed = 0, _failed = 0;

function check(label, got, expected) {
    var ok;
    if (typeof expected === "number" && isNaN(expected)) {
        ok = isNaN(got);
    } else {
        ok = (got === expected);
    }
    if (ok) {
        console.log("OK  " + label);
        _passed++;
    } else {
        console.log("FAIL " + label + "  got=" + got + "  expected=" + expected);
        _failed++;
    }
}

// ── Unary + ──────────────────────────────────────────────────────────────────

check("unary + integer string",    +"42",        42);
check("unary + negative",          +"-7",        -7);
check("unary + positive sign",     +"+3",         3);
check("unary + decimal",           +"3.14",      3.14);
check("unary + exponent lower",    +"1e3",       1000);
check("unary + exponent upper",    +"2E2",       200);
check("unary + neg exponent",      +"5e-1",      0.5);
check("unary + hex lower",         +"0xff",      255);
check("unary + hex upper",         +"0XFF",      255);
check("unary + empty string",      +"",           0);
check("unary + whitespace only",   +"   ",        0);
check("unary + leading space",     +" 42 ",      42);
check("unary + tab whitespace",    +"\t8\t",      8);
check("unary + newline",           +"\n9\n",      9);
check("unary + NaN string",        +"NaN",       NaN);
check("unary + Infinity",          +"Infinity",  Infinity);
check("unary + +Infinity",         +"+Infinity", Infinity);
check("unary + -Infinity",         +"-Infinity", -Infinity);
check("unary + alpha",             +"abc",       NaN);
check("unary + mixed",             +"12x",       NaN);
check("unary + lone dot",          +".",         NaN);
check("unary + decimal only",      +".5",        0.5);
check("unary + zero",              +"0",          0);
check("unary + negative zero",     +"-0",        -0);
check("unary + leading zeros",     +"007",        7);
check("unary + lone sign +",       +"+",         NaN);
check("unary + lone sign -",       +"-",         NaN);
check("unary + 0x no digits",      +"0x",        NaN);
check("unary + large int",         +"9007199254740992", 9007199254740992);

// ── Numeric arithmetic on strings ────────────────────────────────────────────

check("subtraction coerces",  "10" - 3,    7);
check("multiply coerces",     "4"  * "3", 12);
check("divide coerces",       "9"  / "3",  3);
check("modulo coerces",       "10" % "3",  1);
check("exponent coerces",     "2"  ** "8", 256);

// ── Number() ─────────────────────────────────────────────────────────────────

check("Number('') === 0",          Number(""),        0);
check("Number('42') === 42",       Number("42"),      42);
check("Number('3.14')",            Number("3.14"),    3.14);
check("Number('0xff')",            Number("0xff"),    255);
check("Number('Infinity')",        Number("Infinity"),    Infinity);
check("Number('-Infinity')",       Number("-Infinity"),   -Infinity);
check("Number('NaN') isNaN",       Number("NaN"),     NaN);
check("Number('abc') isNaN",       Number("abc"),     NaN);
check("Number(' 7 ') === 7",       Number(" 7 "),     7);

// ── parseInt / parseFloat ────────────────────────────────────────────────────

check("parseInt('42')",            parseInt("42"),       42);
check("parseInt('   10   ')",      parseInt("   10   "), 10);
check("parseInt('0xff', 16)",      parseInt("0xff", 16), 255);
check("parseInt('10', 2)",         parseInt("10", 2),     2);
check("parseInt('07')",            parseInt("07"),        7);
check("parseInt('3.9')",           parseInt("3.9"),       3);
check("parseInt('abc') isNaN",     parseInt("abc"),      NaN);
check("parseInt('')  isNaN",       parseInt(""),         NaN);
check("parseInt('12abc')",         parseInt("12abc"),    12);

check("parseFloat('3.14')",        parseFloat("3.14"),   3.14);
check("parseFloat('1e3')",         parseFloat("1e3"),    1000);
check("parseFloat('  -2.5  ')",    parseFloat("  -2.5  "), -2.5);
check("parseFloat('0.5abc')",      parseFloat("0.5abc"), 0.5);
check("parseFloat('abc') isNaN",   parseFloat("abc"),    NaN);
check("parseFloat('')  isNaN",     parseFloat(""),       NaN);

// ── Math methods with string arguments ───────────────────────────────────────

check("Math.abs('-3.5')",          Math.abs("-3.5"),     3.5);
check("Math.ceil('1.1')",          Math.ceil("1.1"),     2);
check("Math.floor('1.9')",         Math.floor("1.9"),    1);
check("Math.round('1.5')",         Math.round("1.5"),    2);
check("Math.trunc('3.7')",         Math.trunc("3.7"),    3);
check("Math.sqrt('9')",            Math.sqrt("9"),       3);
check("Math.pow('2','8')",         Math.pow("2", "8"),   256);
check("Math.max('3','1','2')",     Math.max("3","1","2"), 3);
check("Math.min('3','1','2')",     Math.min("3","1","2"), 1);
check("Math.log('1')",             Math.log("1"),        0);
check("Math.sin('0')",             Math.sin("0"),        0);
check("Math.abs('abc') isNaN",     Math.abs("abc"),      NaN);

// ── util.format %d with string input ─────────────────────────────────────────

var util = require("util");
check("util.format('%d','42') === '42'",   util.format('%d', '42'),   '42');
check("util.format('%d','3.7') === '3'",   util.format('%d', '3.7'),  '3');
check("util.format('%f','1.5') === '1.5'", util.format('%f', '1.5'), '1.5');

// ─────────────────────────────────────────────────────────────────────────────

console.log("");
console.log("=== string-to-number tests: " + _passed + " passed, " + _failed + " failed ===");
if (_failed > 0) {
    process.exit(1);
}
