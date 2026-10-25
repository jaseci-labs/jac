import from c {
    def strchr(text: ptr[u8], character: i32) -> ptr[u8];  def fprintf(
        stream: ptr, format: ptr[u8], *args: any
    ) -> i32;  def jacpy_stdio_stream(stream: i32) -> ptr;  glob _PyOS_opterr:
             i32 = 1; glob _PyOS_optind: i64 = 1; glob _PyOS_optarg: ptr[i32] = ptr[
             i32
         ](); glob:priv opt_ptr: ptr[i32] = ptr[i32](); def _PyOS_ResetGetOpt {
        addressof(_PyOS_opterr).view(1)[0] = 1;
        addressof(_PyOS_optind).view(1)[0] = 1;
        addressof(_PyOS_optarg).view(1)[0] = ptr[i32]();
        addressof(opt_ptr).view(1)[0] = ptr[i32]();
        return;
    }  def _PyOS_GetOpt(argc: i64, argv: ptr[ptr[i32]], longindex: ptr[i32]) -> i32 {
        if opt_at(0) == 0 {
            optind = addressof(_PyOS_optind).view(1)[0];
            if optind >= argc {
                return -1;
            }
            arg = (argv + optind).view(1)[0];
            if arg.view(1)[0] != 45 or arg.view(2)[1] == 0 {
                return -1;
            }
            if wide_is_ascii(arg, ptr[u8]("--")) {
                addressof(_PyOS_optind).view(1)[0] = optind + 1;
                return -1;
            }
            if wide_is_ascii(arg, ptr[u8]("--help")) {
                addressof(_PyOS_optind).view(1)[0] = optind + 1;
                return 104;
            }
            if wide_is_ascii(arg, ptr[u8]("--version")) {
                addressof(_PyOS_optind).view(1)[0] = optind + 1;
                return 86;
            }
            addressof(_PyOS_optind).view(1)[0] = optind + 1;
            addressof(opt_ptr).view(1)[0] = arg + 1;
        }

        option = opt_at(0);
        if option == 0 {
            return -1;
        }
        addressof(opt_ptr).view(1)[0] = addressof(opt_ptr).view(1)[0] + 1;

        if option == 45 {
            return parse_long_option(argc, argv, longindex);
        }

        if option > 127 or not strchr(ptr[u8]("bBc:dEhiIm:OPqRsStuvVW:xX:?"), option) {
            if addressof(_PyOS_opterr).view(1)[0] != 0 {
                fprintf(
                    jacpy_stdio_stream(2),
                    ptr[u8]("Unknown option: -%c\n"),
                    i32(u8.wrap(option))
                );
            }
            return 95;
        }

        spec = strchr(ptr[u8]("bBc:dEhiIm:OPqRsStuvVW:xX:?"), option);
        if (spec + 1).view(1)[0] == u8(58) {
            if opt_at(0) != 0 {
                addressof(_PyOS_optarg).view(1)[0] = addressof(opt_ptr).view(1)[0];
                addressof(opt_ptr).view(1)[0] = ptr[i32]();
            } else {
                optind = addressof(_PyOS_optind).view(1)[0];
                if optind >= argc {
                    if addressof(_PyOS_opterr).view(1)[0] != 0 {
                        fprintf(
                            jacpy_stdio_stream(2),
                            ptr[u8]("Argument expected for the -%c option\n"),
                            i32(u8.wrap(option))
                        );
                    }
                    return 95;
                }
                addressof(_PyOS_optarg).view(1)[0] = (argv + optind).view(1)[0];
                addressof(_PyOS_optind).view(1)[0] = optind + 1;
            }
        }
        return option;
    }
}

def opt_at(index: i64) -> i32;

def wide_is_ascii(wide: ptr[i32], text: ptr[u8]) -> bool;

def long_option(index: i32) -> tuple[ptr[u8], i32, i32];

def parse_long_option(argc: i64, argv: ptr[ptr[i32]], longindex: ptr[i32]) -> i32;

impl opt_at(index: i64) -> i32 {
    current = addressof(opt_ptr).view(1)[0];
    if not current {
        return 0;
    }
    return (current + index).view(1)[0];
}

impl wide_is_ascii(wide: ptr[i32], text: ptr[u8]) -> bool {
    i: i64 = 0;
    while True {
        c = i32((text + i).view(1)[0]);
        if (wide + i).view(1)[0] != c {
            return False;
        }
        if c == 0 {
            return True;
        }
        i += 1;
    }
    return False;
}

impl long_option(index: i32) -> tuple[ptr[u8], i32, i32] {
    if index == 0 {
        return (ptr[u8]("check-hash-based-pycs"), i32(1), i32(0));
    }
    if index == 1 {
        return (ptr[u8]("help-all"), i32(0), i32(1));
    }
    if index == 2 {
        return (ptr[u8]("help-env"), i32(0), i32(2));
    }
    if index == 3 {
        return (ptr[u8]("help-xoptions"), i32(0), i32(3));
    }
    return (ptr[u8](), i32(0), i32(-1));
}

impl parse_long_option(argc: i64, argv: ptr[ptr[i32]], longindex: ptr[i32]) -> i32 {
    if opt_at(0) == 0 {
        if addressof(_PyOS_opterr).view(1)[0] != 0 {
            fprintf(jacpy_stdio_stream(2), ptr[u8]("Expected long option\n"));
        }
        return -1;
    }
    index: i32 = 0;
    longindex.view(1)[0] = index;
    (name, has_arg, val) = long_option(index);
    while name {
        if wide_is_ascii(addressof(opt_ptr).view(1)[0], name) {
            break;
        }
        index += 1;
        longindex.view(1)[0] = index;
        (name, has_arg, val) = long_option(index);
    }
    if not name {
        if addressof(_PyOS_opterr).view(1)[0] != 0 {
            fprintf(
                jacpy_stdio_stream(2),
                ptr[u8]("Unknown option: %ls\n"),
                (argv + (addressof(_PyOS_optind).view(1)[0] - 1)).view(1)[0]
            );
        }
        return 95;
    }
    addressof(opt_ptr).view(1)[0] = ptr[i32]();
    if has_arg == 0 {
        return val;
    }
    optind = addressof(_PyOS_optind).view(1)[0];
    if optind >= argc {
        if addressof(_PyOS_opterr).view(1)[0] != 0 {
            fprintf(
                jacpy_stdio_stream(2),
                ptr[u8]("Argument expected for the %ls options\n"),
                (argv + (optind - 1)).view(1)[0]
            );
        }
        return 95;
    }
    addressof(_PyOS_optarg).view(1)[0] = (argv + optind).view(1)[0];
    addressof(_PyOS_optind).view(1)[0] = optind + 1;
    return val;
}
