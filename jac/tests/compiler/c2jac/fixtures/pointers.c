void *malloc(unsigned int size);
void free(void *ptr);

typedef struct {
    int x;
    int y;
} Point;

Point *make_point(int x, int y) {
    Point *p = malloc(sizeof(Point));
    p->x = x;
    p->y = y;
    return p;
}

void destroy_point(Point *p) {
    free(p);
}

int get_x(Point *p) {
    return p->x;
}

void set_xy(Point *p, int x, int y) {
    p->x = x;
    p->y = y;
}
