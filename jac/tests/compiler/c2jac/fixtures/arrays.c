int sum_array(int n) {
    int arr[5];
    arr[0] = 10;
    arr[1] = 20;
    arr[2] = 30;
    arr[3] = 40;
    arr[4] = 50;
    int total = 0;
    int i = 0;
    while (i < n) {
        total += arr[i];
        i += 1;
    }
    return total;
}

int first_elem(int arr[], int n) {
    return arr[0];
}
