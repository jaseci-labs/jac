int STATUS_OK(void) {
    return 0;
}

enum { STATUS_OK = 1, STATUS_ERR = 2 } g_state;

int use_state(void) {
    return STATUS_ERR;
}
