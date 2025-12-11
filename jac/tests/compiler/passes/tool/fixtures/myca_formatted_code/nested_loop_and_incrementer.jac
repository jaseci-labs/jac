with entry {
    # find the token to delete
    tokens = [];
    token = "xx";
    idx = 0;
    for token_tup in tokens {
        if token_tup == token {
            break;
        }
        idx += 1;
    }
    tokens.pop(idx);
}
