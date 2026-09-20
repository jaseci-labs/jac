import from .foreign_alias_api { strlen as byte_count, abs as absolute }
import foreign_alias_api as api;

def alias_calls -> bool {
    return byte_count("λ🦀") == 6
        and int(absolute(i32(-17))) == 17
        and api.strlen("hello") == 5;
}
