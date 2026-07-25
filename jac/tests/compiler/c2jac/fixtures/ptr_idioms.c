void *malloc(unsigned int size);
void *realloc(void *ptr, unsigned int size);
void free(void *ptr);
void set_field(int *slot, int v);

typedef struct {
    int x;
    int y;
} Point;

Point *make_points(int n) {
    Point *arr = malloc(n * sizeof(Point));
    arr = realloc(arr, 2 * n * sizeof(Point));
    return arr;
}

int sum_via_ref(Point *p) {
    Point copy = *p;
    int total = (*p).x + p->y;
    return total;
}

void fill(Point *p, int v) {
    set_field(&p->x, v);
}
