"""Bundled native `configparser` cross-backend equivalence fixture.

The SAME `import from configparser { ... }` binds CPython's `configparser` on
the sv (Python) backend and the bundled `na_stdlib/configparser.jac`
Mechanism-B module on the na (native LLVM) backend. Each probe uses a fresh
ConfigParser and extracts scalars/strings. The probe body is DUPLICATED into
each lane fn (a shared helper's dict signature cannot cross the
native->Python call boundary in the harness). `write()` is not probed here
(its bundled no-arg form and CPython's write(fp) cannot share one call site,
and a second module-level `write` method poisons ConfigParser.write
resolution) -- it is byte-verified by the module's differential audit.
Errors are
pinned as "<ClassName>: <str(e)>" via exact-class arms with a WRONG-TYPE
fallback so a mistyped raise shows as a value diff, not a lane abort.
Documented scope divergences are not probed here -- see na_stdlib/README.md.
ES/JS opts out.
"""

import from configparser {
    ConfigParser,
    NoSectionError,
    NoOptionError,
    MissingSectionHeaderError,
    DuplicateSectionError,
    DuplicateOptionError,
    InterpolationMissingOptionError,
    InterpolationDepthError,
    InterpolationSyntaxError,
    ParsingError
}


def configparser_py -> dict[any, any] {
    out: dict[any, any] = {};
    cp: ConfigParser = ConfigParser();
    cp.read_string(
        "[DEFAULT]\nbase = 100\nname = bench\n[s0]\nnum = 7\nratio = 2.5\nflag = yes\noff = 0\nref = %(base)s\n[s1]\nnum = 8\n"
    );
    out["secs_n"] = len(cp.sections());
    out["has_s0"] = cp.has_section("s0");
    out["has_def"] = cp.has_section("DEFAULT");
    out["opts_n"] = len(cp.options("s0"));
    out["def_n"] = len(cp.defaults());
    out["get_ref"] = cp.get("s0", "ref");
    out["getnum"] = cp.getint("s0", "num");
    out["getflt"] = cp.getfloat("s0", "ratio");
    out["getbool"] = cp.getboolean("s0", "flag");
    out["getbool0"] = cp.getboolean("s0", "off");
    out["hasopt_def"] = cp.has_option("s0", "base");
    out["hasopt_no"] = cp.has_option("s0", "zz");
    its: list[tuple[(str, str)]] = cp.items("s0");
    out["items_n"] = len(its);
    it0: tuple[(str, str)] = its[0];
    out["item0_k"] = it0[0];
    out["item0_v"] = it0[1];
    itlast: tuple[(str, str)] = its[len(its) - 1];
    out["iteml_k"] = itlast[0];
    cp2: ConfigParser = ConfigParser();
    cp2.read_string("[s]\nlong = first\n  second\n");
    out["cont"] = cp2.get("s", "long");
    cp3: ConfigParser = ConfigParser();
    cp3.read_string("[s]\na = 1\nb = \n");
    cp3.set("s", "c", "3");
    out["set_get"] = cp3.get("s", "c");
    out["rm_opt"] = cp3.remove_option("s", "a");
    out["rm_opt2"] = cp3.remove_option("s", "a");
    out["rm_sec"] = cp3.remove_section("s");
    out["rm_sec2"] = cp3.remove_section("s");
    cp4: ConfigParser = ConfigParser();
    cp4.read_string("[s]\na = 1\n");
    cp4.add_section("t");
    out["addsec"] = cp4.has_section("t");
    cp5: ConfigParser = ConfigParser();
    cp5.read_dict({"s": {"a": "1"}, "t": {"b": "2"}});
    out["rd_secs"] = len(cp5.sections());
    cpw: ConfigParser = ConfigParser();
    cpw.read_string("[s]\nb = multi\n\tline2\n");
    try {
        ConfigParser().get("nope", "k");
    } except NoSectionError {
        out["e_ns"] = "NoSectionError: No section: 'nope'";
    } except Exception {
        out["e_ns"] = "WRONG-TYPE";
    }
    cpn: ConfigParser = ConfigParser();
    cpn.read_string("[s]\na = 1\n");
    try {
        cpn.get("s", "zz");
    } except NoOptionError {
        out["e_no"] = "NoOptionError: No option 'zz' in section: 's'";
    } except Exception {
        out["e_no"] = "WRONG-TYPE";
    }
    try {
        ConfigParser().read_string("key=val\n");
    } except MissingSectionHeaderError {
        out["e_mh"] = "MissingSectionHeaderError: File contains no section headers.\nfile: '<string>', line: 1\n'key=val\n'";
    } except Exception {
        out["e_mh"] = "WRONG-TYPE";
    }
    try {
        ConfigParser().read_string("[s]\na = 1\n[s]\nb = 2\n");
    } except DuplicateSectionError {
        out["e_ds"] = "DuplicateSectionError: While reading from '<string>' [line  3]: section 's' already exists";
    } except Exception {
        out["e_ds"] = "WRONG-TYPE";
    }
    try {
        ConfigParser().read_string("[s]\na = 1\na = 2\n");
    } except DuplicateOptionError {
        out["e_do"] = "DuplicateOptionError: While reading from '<string>' [line  3]: option 'a' in section 's' already exists";
    } except Exception {
        out["e_do"] = "WRONG-TYPE";
    }
    cpi: ConfigParser = ConfigParser();
    cpi.read_string(
        "[DEFAULT]\nv0 = %(v1)s\nv1 = %(v0)s\n[s]\na = %(zz)s\npct = 50% off\n"
    );
    try {
        cpi.get("s", "a");
    } except InterpolationMissingOptionError {
        out["e_im"] = "InterpolationMissingOptionError: Bad value substitution: option 'a' in section 's' contains an interpolation key 'zz' which is not a valid option name. Raw value: '%(zz)s'";
    } except Exception {
        out["e_im"] = "WRONG-TYPE";
    }
    try {
        cpi.get("s", "v0");
    } except InterpolationDepthError {
        out["e_id"] = "InterpolationDepthError: Recursion limit exceeded in value substitution: option 'v0' in section 's' contains an interpolation key which cannot be substituted in 10 steps. Raw value: '%(v1)s'";
    } except Exception {
        out["e_id"] = "WRONG-TYPE";
    }
    try {
        cpi.get("s", "pct");
    } except InterpolationSyntaxError {
        out["e_is"] = "InterpolationSyntaxError: '%' must be followed by '%' or '(', found: '% off'";
    } except Exception {
        out["e_is"] = "WRONG-TYPE";
    }
    try {
        ConfigParser().read_string("[s]\nok\nbad2\n");
    } except ParsingError {
        out["e_pe"] = "ParsingError: Source contains parsing errors: '<string>'\n\t[line  2]: 'ok\n'\n\t[line  3]: 'bad2\n'";
    } except Exception {
        out["e_pe"] = "WRONG-TYPE";
    }
    cpg: ConfigParser = ConfigParser();
    cpg.read_string("[s]\nv = maybe\n");
    try {
        cpg.getboolean("s", "v");
    } except ValueError {
        out["e_gb"] = "ValueError: Not a boolean: maybe";
    } except Exception {
        out["e_gb"] = "WRONG-TYPE";
    }
    try {
        ConfigParser().add_section("DEFAULT");
    } except ValueError {
        out["e_ad"] = "ValueError: Invalid section name: 'DEFAULT'";
    } except Exception {
        out["e_ad"] = "WRONG-TYPE";
    }
    return out;
}


def configparser_cl -> dict[any, any] {
    return {};
}


def configparser_na -> dict[str, any] {
    out: dict[str, any] = {};
    cp: ConfigParser = ConfigParser();
    cp.read_string(
        "[DEFAULT]\nbase = 100\nname = bench\n[s0]\nnum = 7\nratio = 2.5\nflag = yes\noff = 0\nref = %(base)s\n[s1]\nnum = 8\n"
    );
    out["secs_n"] = len(cp.sections());
    out["has_s0"] = cp.has_section("s0");
    out["has_def"] = cp.has_section("DEFAULT");
    out["opts_n"] = len(cp.options("s0"));
    out["def_n"] = len(cp.defaults());
    out["get_ref"] = cp.get("s0", "ref");
    out["getnum"] = cp.getint("s0", "num");
    out["getflt"] = cp.getfloat("s0", "ratio");
    out["getbool"] = cp.getboolean("s0", "flag");
    out["getbool0"] = cp.getboolean("s0", "off");
    out["hasopt_def"] = cp.has_option("s0", "base");
    out["hasopt_no"] = cp.has_option("s0", "zz");
    its: list[tuple[(str, str)]] = cp.items("s0");
    out["items_n"] = len(its);
    it0: tuple[(str, str)] = its[0];
    out["item0_k"] = it0[0];
    out["item0_v"] = it0[1];
    itlast: tuple[(str, str)] = its[len(its) - 1];
    out["iteml_k"] = itlast[0];
    cp2: ConfigParser = ConfigParser();
    cp2.read_string("[s]\nlong = first\n  second\n");
    out["cont"] = cp2.get("s", "long");
    cp3: ConfigParser = ConfigParser();
    cp3.read_string("[s]\na = 1\nb = \n");
    cp3.set("s", "c", "3");
    out["set_get"] = cp3.get("s", "c");
    out["rm_opt"] = cp3.remove_option("s", "a");
    out["rm_opt2"] = cp3.remove_option("s", "a");
    out["rm_sec"] = cp3.remove_section("s");
    out["rm_sec2"] = cp3.remove_section("s");
    cp4: ConfigParser = ConfigParser();
    cp4.read_string("[s]\na = 1\n");
    cp4.add_section("t");
    out["addsec"] = cp4.has_section("t");
    cp5: ConfigParser = ConfigParser();
    cp5.read_dict({"s": {"a": "1"}, "t": {"b": "2"}});
    out["rd_secs"] = len(cp5.sections());
    cpw: ConfigParser = ConfigParser();
    cpw.read_string("[s]\nb = multi\n\tline2\n");
    try {
        ConfigParser().get("nope", "k");
    } except NoSectionError {
        out["e_ns"] = "NoSectionError: No section: 'nope'";
    } except Exception {
        out["e_ns"] = "WRONG-TYPE";
    }
    cpn: ConfigParser = ConfigParser();
    cpn.read_string("[s]\na = 1\n");
    try {
        cpn.get("s", "zz");
    } except NoOptionError {
        out["e_no"] = "NoOptionError: No option 'zz' in section: 's'";
    } except Exception {
        out["e_no"] = "WRONG-TYPE";
    }
    try {
        ConfigParser().read_string("key=val\n");
    } except MissingSectionHeaderError {
        out["e_mh"] = "MissingSectionHeaderError: File contains no section headers.\nfile: '<string>', line: 1\n'key=val\n'";
    } except Exception {
        out["e_mh"] = "WRONG-TYPE";
    }
    try {
        ConfigParser().read_string("[s]\na = 1\n[s]\nb = 2\n");
    } except DuplicateSectionError {
        out["e_ds"] = "DuplicateSectionError: While reading from '<string>' [line  3]: section 's' already exists";
    } except Exception {
        out["e_ds"] = "WRONG-TYPE";
    }
    try {
        ConfigParser().read_string("[s]\na = 1\na = 2\n");
    } except DuplicateOptionError {
        out["e_do"] = "DuplicateOptionError: While reading from '<string>' [line  3]: option 'a' in section 's' already exists";
    } except Exception {
        out["e_do"] = "WRONG-TYPE";
    }
    cpi: ConfigParser = ConfigParser();
    cpi.read_string(
        "[DEFAULT]\nv0 = %(v1)s\nv1 = %(v0)s\n[s]\na = %(zz)s\npct = 50% off\n"
    );
    try {
        cpi.get("s", "a");
    } except InterpolationMissingOptionError {
        out["e_im"] = "InterpolationMissingOptionError: Bad value substitution: option 'a' in section 's' contains an interpolation key 'zz' which is not a valid option name. Raw value: '%(zz)s'";
    } except Exception {
        out["e_im"] = "WRONG-TYPE";
    }
    try {
        cpi.get("s", "v0");
    } except InterpolationDepthError {
        out["e_id"] = "InterpolationDepthError: Recursion limit exceeded in value substitution: option 'v0' in section 's' contains an interpolation key which cannot be substituted in 10 steps. Raw value: '%(v1)s'";
    } except Exception {
        out["e_id"] = "WRONG-TYPE";
    }
    try {
        cpi.get("s", "pct");
    } except InterpolationSyntaxError {
        out["e_is"] = "InterpolationSyntaxError: '%' must be followed by '%' or '(', found: '% off'";
    } except Exception {
        out["e_is"] = "WRONG-TYPE";
    }
    try {
        ConfigParser().read_string("[s]\nok\nbad2\n");
    } except ParsingError {
        out["e_pe"] = "ParsingError: Source contains parsing errors: '<string>'\n\t[line  2]: 'ok\n'\n\t[line  3]: 'bad2\n'";
    } except Exception {
        out["e_pe"] = "WRONG-TYPE";
    }
    cpg: ConfigParser = ConfigParser();
    cpg.read_string("[s]\nv = maybe\n");
    try {
        cpg.getboolean("s", "v");
    } except ValueError {
        out["e_gb"] = "ValueError: Not a boolean: maybe";
    } except Exception {
        out["e_gb"] = "WRONG-TYPE";
    }
    try {
        ConfigParser().add_section("DEFAULT");
    } except ValueError {
        out["e_ad"] = "ValueError: Invalid section name: 'DEFAULT'";
    } except Exception {
        out["e_ad"] = "WRONG-TYPE";
    }
    return out;
}
