int variadic_sum(int count, ...) {
    return 0;
}

int macro_pattern(int x) {
    return x > 0 ? x : -x;
}

typedef struct Inner {
    int value;
    struct Inner *next;
} Inner;

typedef struct Outer {
    Inner *head;
    int count;
} Outer;

int apply_func(int (*func)(int), int x) {
    return func(x);
}

int complex_conditional(int a, int b, int c, int d) {
    return (a > b) ? (c > d ? c : d) : (a > 0 ? a : 0);
}

int nested_loops(int n) {
    int sum = 0;
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            if (i == j) continue;
            if (i + j > n) break;
            sum++;
        }
    }
    return sum;
}

int array_init(void) {
    int arr[5] = {1, 2, 3, 4, 5};
    int sum = 0;
    for (int i = 0; i < 5; i++) {
        sum += arr[i];
    }
    return sum;
}

int side_effects(int *counter) {
    (*counter)++;
    return *counter;
}

int use_side_effects(int *c) {
    return side_effects(c) + side_effects(c) + side_effects(c);
}

int pointer_complex(int **pp) {
    int *p = *pp;
    return **pp + *p;
}

int switch_complex(int x) {
    int result = 0;
    switch (x) {
        case 1 + 1:
            result = 2;
            break;
        case 3 * 2:
            result = 6;
            break;
        case 10 / 2:
            result = 5;
            break;
        default:
            result = -1;
    }
    return result;
}

int nested_ternary_assign(int x, int y) {
    int a, b;
    a = x > 0 ? x : 0;
    b = y > 0 ? y : 0;
    return a + b;
}

int complex_for_cond(int n) {
    int sum = 0;
    for (int i = 0; i < n && sum < 100; i++) {
        sum += i;
    }
    return sum;
}

void multi_decl(int *a, int *b, int *c) {
    int x, y, z;
    x = *a;
    y = *b;
    z = *c;
    *a = x + y + z;
}

typedef struct {
    int x;
    int y;
    int z;
} Vec3;

Vec3 vec_add(Vec3 a, Vec3 b) {
    Vec3 result;
    result.x = a.x + b.x;
    result.y = a.y + b.y;
    result.z = a.z + b.z;
    return result;
}

int complex_func_calls(int a, int b, int c) {
    int result = 0;
    result += (a > 0 ? a : 0) + (b > 0 ? b : 0);
    result += c > 0 ? c : 0;
    return result;
}
