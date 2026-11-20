"""
This test file is to ensure the valid syntax of jac lang.
Add new jac syntax here to test if it compile without any issue.
"""

# Import statement without trailing comma.
import from time { sleep, timezone, tzname }
# Import statement with trailing comma.
import from os { path, getenv, getpid, }

enum WithoutTrailComma { FOO = "FOO", BAR = "BAR" }

enum WithTrailComma { FOO = "FOO", BAR = "BAR", }

def without_trail_comma(a: int, b: int) { }

def with_trail_comma(a: int, b: int, c: int,) { }

with entry {
    dict_without_trail_comma = {"key": "value"};
    dict_with_trail_comma = {"key": "val",};

    list_without_trail_comma = ["foo", "bar"];
    list_with_trail_comma = ["foo", "bar", ];

    set_without_trail_comma = {"foo","bar"};
    set_with_trail_comma = {"foo","bar"};
    obj foo11 {
        has val: int,
            val2: int = 9,
            val3: int = 8,
            val4: int = 8,
            val5: int = 8;
    }
    empty_tuple = ();
    single_tuple = ('single', );

    tuple_without_trail_comma = ("foo", "bar");
    tuple_with_trail_comma = ("foo", "bar", );

    mixed_tuple = (1, 'two', 3.0, False);
    mixed_tuple_with_trail_comma = (1, 'two', 3.0, False, );

    nested_tuple = (1, (2, 3), 'four');
    nested_tuple_with_trail_comma = (1, (2, 3), 'four', );

    deeply_nested_tuple = (1, (2, (3, (4, 5))));
    deeply_nested_tuple_with_trail_comma = (1, (2, (3, (4, 5))), );

    tuple1 = ("foo", );
    tuple1_2 = ("foo", "bar", "baz");
    tuple_2_2 = ("foo", "bar", "baz", );

    foo_instance1 = foo11(val=90);
    foo_instance1_2 = foo11(val=90,);

    foo_instance3 = foo11(2, 34, val3=90);
    foo_instance3_2 = foo11(2, 34, val3=90,);

    foo_instance4 = foo11(2, 34, val3=90, val4=90);
    foo_instance4_2 = foo11(2, 34, val3=90, val4=90,);

    func_tuple = (foo_instance1, foo_instance3_2, len(tuple1_2));
    func_tuple_with_trail_comma = (foo_instance1, foo_instance3_2, len(tuple1_2), );

    unpack_tuple = (1, 2, 3);
    (a, b, c, ) = unpack_tuple;
    values = (a, b, c);

    (1, 2);
    (1, 2, );
    (1, 2, 3, 4);
    (1, 2, 3, 4, );

    val_f = (foo_instance3_2.val, foo_instance3_2.val2, foo_instance3_2.val3);
    expression_tuple = (1 + 2, len("abc"), foo_instance1.val * 2);
    tuple_with_list = (1, [2, 3], 4);
    print("Code compiled and ran successfully!");
}
