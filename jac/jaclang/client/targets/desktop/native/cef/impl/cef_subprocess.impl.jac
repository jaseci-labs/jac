impl _subprocess_bootstrap {
    setenv("NO_AT_BRIDGE", "1", 0);
    buf: int = calloc(1, 4096);
    n: int = readlink("/proc/self/exe", buf, 4095);
    if n <= 0 {
        free(buf);
        return;
    }
    memset(buf + n, 0, 1);
    slash: int = strrchr(buf, 47);
    if slash == 0 {
        free(buf);
        return;
    }
    memset(slash, 0, 1);
    fc_buf: int = calloc(1, 4096);
    strcpy(fc_buf, buf);
    strcat(fc_buf, "/minimal-fonts.conf");
    if access(fc_buf, 4) == 0 {
        setenv("FONTCONFIG_FILE", fc_buf, 0);
    }
    free(fc_buf);
    free(buf);
}

impl _subprocess_main {
    _assert_cef_abi();
    _subprocess_bootstrap();
    args: int = cef_main_args_create();
    code: i32 = cef_execute_process(args, g_app, 0);
    if code >= 0 {
        sys.`exit(code);
    }
}
