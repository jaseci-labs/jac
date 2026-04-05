"""Test: JS-specific globals should produce portability warnings."""

def use_console() -> None {
    console.log("hello");
    console.warn("warning");
}

def use_math() -> None {
    x = Math.floor(3.5);
    y = Math.ceil(2.1);
}

def use_json() -> None {
    data = JSON.parse('{"a": 1}');
    text = JSON.stringify(data);
}

def use_constructors() -> None {
    arr = Array(1, 2, 3);
    o = Object();
    m = Map();
    s = Set();
}

def use_async_globals() -> None {
    setTimeout(callback, 1000);
    setInterval(callback, 500);
}
