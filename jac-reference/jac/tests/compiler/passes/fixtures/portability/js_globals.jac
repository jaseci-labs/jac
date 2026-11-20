"""Test: JS-specific globals should produce portability warnings.

The os import anchors this module server-side: browser-global seeding only
relocates declarations in unanchored modules, so every use below stays
server-placed and the portability lint keeps firing.
"""
import os;

def use_pid -> int {
    return os.getpid();
}

def use_console {
    console.log("hello");
    console.warn("warning");
}

def use_math {
    x = Math.floor(3.5);
    y = Math.ceil(2.1);
}

def use_json {
    data = JSON.parse('{"a": 1}');
    text = JSON.stringify(data);
}

def use_constructors {
    arr = Array(1, 2, 3);
    o = Object();
    m = Map();
    s = Set();
}

def use_async_globals {
    setTimeout(callback, 1000);
    setInterval(callback, 500);
}
