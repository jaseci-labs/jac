import from pathlib { Path }

def suffix_matches -> bool {
    return Path("/tmp/anything.txt").suffix == ".txt";
}

with entry {
    print(Path("/tmp/anything.txt").suffix);
}
