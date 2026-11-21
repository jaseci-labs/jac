with entry {
    with open("data.txt", "r") as f {
        content = f.read();
        print(content);
    }
}
