enum Permissions {
    PERM_READ = 1,
    PERM_WRITE = 2,
    PERM_EXEC = 4,
    PERM_ALL = 7
};

int has_read(int p) {
    return p;
}
