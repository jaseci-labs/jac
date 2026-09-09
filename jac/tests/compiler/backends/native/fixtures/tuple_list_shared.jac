"""A converted list shares tuple elements in reference-counted profiles."""
import from .tuple_list_conversion { items, drops }

def borrowed_objects -> int {
    pair = items();
    values = list(pair);
    values[0].value = 10;
    return pair[0].value + values[1].value;
}

def shared_drops -> int {
    return drops();
}
