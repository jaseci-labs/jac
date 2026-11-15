"""Owns a private global with the same name as private_glob_shared's public one."""

glob:priv X_VALUE: int = 1;

def hidden_x -> int {
    return X_VALUE;
}
