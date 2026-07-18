typedef struct {
    unsigned int flag1 : 1;
    unsigned int flag2 : 1;
    unsigned int value : 6;
} BitFields;

int nested_array(void) {
    int arr[2][3] = {{1, 2, 3}, {4, 5, 6}};
    return arr[0][0] + arr[1][2];
}

int pointer_array(void) {
    int arr[] = {1, 2, 3, 4, 5};
    int *p = arr;
    int sum = 0;
    for (int i = 0; i < 5; i++) {
        sum += *(p + i);
    }
    return sum;
}

typedef struct {
    int data[4];
    int count;
} IntArray;

typedef struct {
    IntArray arrays[2];
    int total;
} MultiArray;

typedef struct {
    int x;
    int y;
} Point;

Point make_point(int x, int y) {
    Point p;
    p.x = x;
    p.y = y;
    return p;
}

int conditional_chain(int x) {
    if (x < 0) {
        return -1;
    } else if (x == 0) {
        return 0;
    } else if (x < 10) {
        return 1;
    } else if (x < 100) {
        return 2;
    } else if (x < 1000) {
        return 3;
    } else {
        return 4;
    }
}

int nested_complex(int n) {
    int count = 0;
    for (int i = 0; i < n; i++) {
        for (int j = 0; j <= i; j++) {
            if (i * j > n) {
                break;
            }
            if (i + j < n / 2) {
                count++;
            }
        }
    }
    return count;
}

int switch_multiple(int x) {
    int result = 0;
    switch (x) {
        case 1:
        case 2:
        case 3:
            result = 1;
            break;
        case 4:
        case 5:
            result = 2;
            break;
        case 6:
        case 7:
        case 8:
        case 9:
            result = 3;
            break;
        default:
            result = 0;
    }
    return result;
}

int pointer_chain(int **pp) {
    int *p = *pp;
    return **pp;
}

int side_effect_chain(int *counter) {
    (*counter)++;
    return *counter;
}

int use_side_effects(int *c) {
    return side_effect_chain(c) + side_effect_chain(c);
}

int array_patterns(void) {
    int arr[10] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};
    int sum = 0;
    sum += arr[0];
    sum += arr[4];
    sum += arr[9];
    return sum;
}

typedef struct {
    int a;
    int b;
    int c;
} Triple;

Triple make_triple(int a, int b, int c) {
    Triple t;
    t.a = a;
    t.b = b;
    t.c = c;
    return t;
}

int nested_ternary_complex(int a, int b, int c, int d) {
    return (a > b) ?
           ((c > d) ? c : d) :
           ((a > 0) ? a : ((b > 0) ? b : 0));
}

int for_multiple_updates(int n) {
    int sum = 0;
    int i = 0;
    int j = n;
    while (i < j) {
        sum += i + j;
        i++;
        j--;
    }
    return sum;
}

int complex_logical(int a, int b, int c, int d) {
    if ((a > 0 && b > 0) || (c > 0 && d > 0) || (a + b + c + d > 100)) {
        return 1;
    } else if ((a < 0 && b < 0) || (c < 0 && d < 0)) {
        return -1;
    }
    return 0;
}
