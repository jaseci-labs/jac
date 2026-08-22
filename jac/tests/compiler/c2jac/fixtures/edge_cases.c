typedef struct {
    int x;
    int y;
} Point;

typedef struct {
    Point origin;
    Point size;
} Rect;

typedef int (*comparator)(const void *, const void *);

int bitops(int a, int b) {
    return (a & b) | (a ^ b) & (~a);
}

int comma_for(int n) {
    int sum = 0;
    int i, j;
    for (i = 0, j = n; i < j; i++, j--) {
        sum += i + j;
    }
    return sum;
}

int nested_ternary(int x) {
    return x > 0 ? (x > 100 ? 100 : x) : 0;
}

int goto_test(int n) {
    int i = 0;
    int sum = 0;

    loop:
    if (i < n) {
        sum += i;
        i++;
        goto loop;
    }
    return sum;
}

int switch_fallthrough(int x) {
    int result = 0;
    switch (x) {
        case 1:
            result += 1;
        case 2:
            result += 2;
            break;
        case 3:
            result += 3;
        default:
            result += 10;
    }
    return result;
}

int pointer_arithmetic(int *arr, int n) {
    int *end = arr + n;
    int *p = arr;
    int sum = 0;
    while (p < end) {
        sum += *p++;
    }
    return sum;
}

int complex_conditions(int a, int b, int c) {
    if ((a > 0 && b > 0) || (c > 0 && a + b > 0)) {
        return 1;
    } else if (a < 0 && (b < 0 || c < 0)) {
        return -1;
    } else if (a == 0 && b == 0 && c == 0) {
        return 0;
    }
    return -2;
}

typedef struct {
    int count;
    int data[];
} FlexArray;

int matrix_sum(int mat[3][3]) {
    int sum = 0;
    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
            sum += mat[i][j];
        }
    }
    return sum;
}

int complex_for(int n) {
    int sum = 0;
    for (int i = 0, j = n - 1; i <= j; i++, j--) {
        sum += i + j;
    }
    return sum;
}

int nested_switch(int x, int y) {
    int result = 0;
    switch (x) {
        case 1:
            switch (y) {
                case 1: result = 11; break;
                case 2: result = 12; break;
                default: result = 10; break;
            }
            break;
        case 2:
            result = 20;
            break;
        default:
            result = 0;
    }
    return result;
}

int multiple_returns(int x, int y) {
    if (x < 0) return -1;
    if (y < 0) return -2;
    if (x > y) return 1;
    if (x < y) return -1;
    return 0;
}

void chained_assign(int *a, int *b, int *c) {
    *a = *b = *c = 0;
}
