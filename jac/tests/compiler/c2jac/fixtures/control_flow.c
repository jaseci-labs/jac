int classify(int x) {
    if (x > 0 && x < 100) {
        return 1;
    } else if (x == 0) {
        return 0;
    } else {
        return -1;
    }
}

int sum_while(int n) {
    int total = 0;
    int i = 0;
    while (i < n) {
        total += i;
        i += 1;
    }
    return total;
}

int find_first(int arr[], int n, int target) {
    int i = 0;
    while (i < n) {
        if (arr[i] == target) {
            return i;
        }
        if (arr[i] < 0) {
            break;
        }
        i += 1;
        continue;
    }
    return -1;
}
