"""Attributes and Subscript expressions: Index access, slicing, and member access."""

obj Sample {
    has items: list = [10, 20, 30, 40, 50],
        data: dict = {"name": "Alice", "age": 30},
        value: int = 42;
}

glob s = Sample(),
     val = s.value,
     item1 = s.items[0],
     item2 = s.items[-1],
     name = s.data["name"],
     slice1 = s.items[1:4],
     slice2 = s.items[:3],
     slice3 = s.items[2:],
     first_char = s.data["name"][0],
     safe_val = s?.value,
     optional_obj = None,
     null_safe1 = optional_obj?.value,
     null_safe2 = optional_obj?.items,
     obj_with_data = Sample(),
     nested_val = obj_with_data?.data,
     another_none = None,
     safe_chain = another_none?.value?.items,
     valid_obj = Sample(),
     safe_on_valid = valid_obj?.items;

with entry {
    print(val, item1, item2, name, slice1, slice2, slice3, first_char, safe_val);
    print("Null-safe:", null_safe1, null_safe2, nested_val, safe_chain, safe_on_valid);
}
# Dot notation for member access

# Subscripted access for lists and dicts

# Slicing

# Chained access

# Null-safe access with ?

# More null-safe access examples

# Returns None instead of error
# Returns None instead of error

# Chained null-safe access

# Safe access returns the dict

# Multiple null-safe operators in a chain

# Returns None at first ?

# Null-safe on valid object

# Returns [10, 20, 30, 40, 50]
