typedef struct {
    int x;
    int y;
    float z;
} Point;

typedef struct {
    int id;
    float score;
    int active;
} Record;

struct Node {
    int value;
    int left;
    int right;
};

int point_sum(void) {
    Point p;
    p.x = 3;
    p.y = 4;
    return p.x + p.y;
}

/* Positional + designated compound inits → Point(field=…) ctors. */
int point_init_sum(void) {
    Point p = {3, 4, 0};
    return p.x + p.y;
}

int point_desig_sum(void) {
    Point p = {.y = 4, .x = 3};
    return p.x + p.y;
}
