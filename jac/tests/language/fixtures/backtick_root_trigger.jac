walker BtickRootProbe {
    has reports: list[str] = [];
    can g with `root entry {
        report "hit";
    }
}

with entry {
    result = root spawn BtickRootProbe();
    print(result.reports);
}
