with entry {
    hello_world_bytes = b"\x48\x65\x6C\x6C\x6F\x20\x57\x6F\x72\x6C\x64";
    print(hello_world_bytes);
    print(type(hello_world_bytes));

    ret_str = r"Hello\\nWorld";
    print(ret_str);

    br = br"Hello\\nWorld";
    print(br);
    print(type(br));

    rb = rb"Hello\\nWorld";
    print(rb);
    print(type(rb));
}
