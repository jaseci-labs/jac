test test1 {
    assert almostEqual(4.99999, 4.99999);
}

test test2 {
    assert 5 == 5;
}

test test3 {
    assert "e" in "qwerty";
}

with entry:__main__ {
    import subprocess;
    result = subprocess.run(
        ["jac", "test", f"{__file__}"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    );
    print(result.stderr);
}
