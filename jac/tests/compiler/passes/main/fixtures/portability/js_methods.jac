"""Test: JS-idiomatic methods should produce portability warnings."""

def use_array_methods() -> None {
    items: list = [1, 2, 3];
    items.push(4);
    items.forEach(print);
    idx = items.indexOf(2);
    items.splice(1, 1);
    items.unshift(0);
    items.shift();
    items.includes(3);
}

def use_string_methods() -> None {
    s = "hello world";
    c = s.charAt(0);
    code = s.charCodeAt(0);
    sub = s.substring(0, 5);
    padded = s.padStart(20, " ");
    trimmed = s.trim();
}

def use_functional_methods() -> None {
    items: list = [1, 2, 3];
    items.every(check);
    items.some(check);
    items.find(check);
    items.findIndex(check);
}

def use_object_methods() -> None {
    d: dict = {"a": 1};
    d.hasOwnProperty("a");
    d.assign(d);
    d.freeze();
}

def use_conversion_methods() -> None {
    n = 3.14159;
    s = n.toFixed(2);
    s2 = n.toPrecision(4);
    s3 = n.toString();
}
