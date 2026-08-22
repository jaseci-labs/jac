typedef int (*comparator)(const void *a, const void *b);

int invoke(comparator cmp, int x, int y) {
    return cmp((void *)&x, (void *)&y);
}
