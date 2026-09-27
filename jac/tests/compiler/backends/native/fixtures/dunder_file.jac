"""`__file__` names the module's source, at module level and inside functions."""
import os;

def here -> str {
    return os.path.basename(__file__);
}

def beside -> str {
    return os.path.join(os.path.dirname(__file__), "data.txt");
}

with entry {
    print(os.path.basename(__file__));
    print(here());
    print(os.path.basename(beside()));
    print(os.path.isabs(__file__));
}
