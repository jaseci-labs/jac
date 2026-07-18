struct Point { int x; int y; };

void note(const char *msg);

void bubble_sort(int arr[], int n) {
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n - 1; j++) {
            if (arr[j] > arr[j + 1]) {
                int tmp = arr[j];
                arr[j] = arr[j + 1];
                arr[j + 1] = tmp;
            }
        }
    }
}

int sum_array(int arr[], int n) {
    int s = 0;
    for (int i = 0; i < n; i++) {
        s += arr[i];
    }
    return s;
}

void greet(int n) {
    for (int i = 0; i < n; i++) {
        note("hi");
        note("a\tb\n");
    }
}

void index_points(struct Point pts[], int n) {
    for (int i = 0; i < n; i++) {
        pts[i].x = i;
    }
}
