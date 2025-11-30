with entry {
    node_export = {"blah": "blah"};
    big_export = {"blah": node_export};
    del big_export["blah"] ;

    print(big_export);
}
