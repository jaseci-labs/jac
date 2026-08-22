struct Buf { int len; };

int fill(struct Buf *b, int n);

int build(struct Buf *b, int n) {
    int rc = fill(b, n);
    if (rc < 0) goto error;
    rc = fill(b, n + 1);
    if (rc < 0) goto error;
    return rc;
error:
    b->len = 0;
    return -1;
}
