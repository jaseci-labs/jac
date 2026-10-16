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
pinned as "<ClassName>: " + str(e) via exact-class arms with a WRONG-TYPE
fallback so a mistyped raise shows as a value diff, not a lane abort, and a
drifted message shows as a value diff too. The two builtin ValueError arms
stay fixed strings: their messages are concatenated at the raise site, and
the na runtime does not yet keep such a message alive reliably across
unwinding (same pin as prim_base64).
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
    cpm: ConfigParser = ConfigParser();
    cpm.read_string("[s]\na = 1\n");
    cpm.read_string("[s]\nb = 2\n[t]\nc = 3\n");
    out["reread_a"] = cpm.get("s", "a");
    out["reread_b"] = cpm.get("s", "b");
    out["reread_n"] = len(cpm.options("s"));
    out["reread_secs"] = len(cpm.sections());
    try {
        cpm.read_string("[s]\nd = 4\n[s]\ne = 5\n");
        out["reread_dup"] = "NO-RAISE";
    } except DuplicateSectionError {
        out["reread_dup"] = "DuplicateSectionError";
    } except Exception {
        out["reread_dup"] = "WRONG-TYPE";
    }
    cpw: ConfigParser = ConfigParser();
    cpw.read_string("[s]\nb = multi\n\tline2\n");
    try {
        ConfigParser().get("nope", "k");
    } except NoSectionError as e {
        out["e_ns"] = "NoSectionError: " + str(e);
    } except Exception {
        out["e_ns"] = "WRONG-TYPE";
    }
    cpn: ConfigParser = ConfigParser();
    cpn.read_string("[s]\na = 1\n");
    try {
        cpn.get("s", "zz");
    } except NoOptionError as e {
        out["e_no"] = "NoOptionError: " + str(e);
    } except Exception {
        out["e_no"] = "WRONG-TYPE";
    }
    try {
        ConfigParser().read_string("key=val\n");
    } except MissingSectionHeaderError as e {
        out["e_mh"] = "MissingSectionHeaderError: " + str(e);
    } except Exception {
        out["e_mh"] = "WRONG-TYPE";
    }
    try {
        ConfigParser().read_string("[s]\na = 1\n[s]\nb = 2\n");
    } except DuplicateSectionError as e {
        out["e_ds"] = "DuplicateSectionError: " + str(e);
    } except Exception {
        out["e_ds"] = "WRONG-TYPE";
    }
    try {
        ConfigParser().read_string("[s]\na = 1\na = 2\n");
    } except DuplicateOptionError as e {
        out["e_do"] = "DuplicateOptionError: " + str(e);
    } except Exception {
        out["e_do"] = "WRONG-TYPE";
    }
    cpi: ConfigParser = ConfigParser();
    cpi.read_string(
        "[DEFAULT]\nv0 = %(v1)s\nv1 = %(v0)s\n[s]\na = %(zz)s\npct = 50% off\n"
    );
    try {
        cpi.get("s", "a");
    } except InterpolationMissingOptionError as e {
        out["e_im"] = "InterpolationMissingOptionError: " + str(e);
    } except Exception {
        out["e_im"] = "WRONG-TYPE";
    }
    try {
        cpi.get("s", "v0");
    } except InterpolationDepthError as e {
        out["e_id"] = "InterpolationDepthError: " + str(e);
    } except Exception {
        out["e_id"] = "WRONG-TYPE";
    }
    try {
        cpi.get("s", "pct");
    } except InterpolationSyntaxError as e {
        out["e_is"] = "InterpolationSyntaxError: " + str(e);
    } except Exception {
        out["e_is"] = "WRONG-TYPE";
    }
    try {
        ConfigParser().read_string("[s]\nok\nbad2\n");
    } except ParsingError as e {
        out["e_pe"] = "ParsingError: " + str(e);
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
    cpf: ConfigParser = ConfigParser();
    cpf.read_string("[s]\na = 1\n");
    fb1: any = cpf.get("s", "zz", fallback=None);
    out["fb_opt_none"] = "None" if fb1 is None else str(fb1);
    fb2: any = cpf.get("nope", "k", fallback=None);
    out["fb_sect_none"] = "None" if fb2 is None else str(fb2);
    fb3: any = cpf.get("s", "zz", fallback="FB");
    out["fb_opt_val"] = "None" if fb3 is None else str(fb3);
    fb4: any = cpf.get("nope", "k", fallback="FB");
    out["fb_sect_val"] = "None" if fb4 is None else str(fb4);
    gi1: any = cpf.getint("s", "zz", fallback=7);
    out["gi_fb_val"] = "None" if gi1 is None else str(gi1);
    gi2: any = cpf.getint("nope", "k", fallback=None);
    out["gi_fb_none"] = "None" if gi2 is None else str(gi2);
    gf1: any = cpf.getfloat("s", "zz", fallback=2.5);
    out["gf_fb_val"] = "None" if gf1 is None else str(gf1);
    gb1: any = cpf.getboolean("s", "zz", fallback=True);
    out["gb_fb_val"] = "None" if gb1 is None else str(gb1);
    gb2: any = cpf.getboolean("s", "zz", fallback="yes");
    out["gb_fb_raw"] = "None" if gb2 is None else str(gb2);
    try {
        cpf.getint("s", "zz");
    } except NoOptionError as e {
        out["e_gi_nofb"] = "NoOptionError: " + str(e);
    } except Exception {
        out["e_gi_nofb"] = "WRONG-TYPE";
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
    cpm: ConfigParser = ConfigParser();
    cpm.read_string("[s]\na = 1\n");
    cpm.read_string("[s]\nb = 2\n[t]\nc = 3\n");
    out["reread_a"] = cpm.get("s", "a");
    out["reread_b"] = cpm.get("s", "b");
    out["reread_n"] = len(cpm.options("s"));
    out["reread_secs"] = len(cpm.sections());
    try {
        cpm.read_string("[s]\nd = 4\n[s]\ne = 5\n");
        out["reread_dup"] = "NO-RAISE";
    } except DuplicateSectionError {
        out["reread_dup"] = "DuplicateSectionError";
    } except Exception {
        out["reread_dup"] = "WRONG-TYPE";
    }
    cpw: ConfigParser = ConfigParser();
    cpw.read_string("[s]\nb = multi\n\tline2\n");
    try {
        ConfigParser().get("nope", "k");
    } except NoSectionError as e {
        out["e_ns"] = "NoSectionError: " + str(e);
    } except Exception {
        out["e_ns"] = "WRONG-TYPE";
    }
    cpn: ConfigParser = ConfigParser();
    cpn.read_string("[s]\na = 1\n");
    try {
        cpn.get("s", "zz");
    } except NoOptionError as e {
        out["e_no"] = "NoOptionError: " + str(e);
    } except Exception {
        out["e_no"] = "WRONG-TYPE";
    }
    try {
        ConfigParser().read_string("key=val\n");
    } except MissingSectionHeaderError as e {
        out["e_mh"] = "MissingSectionHeaderError: " + str(e);
    } except Exception {
        out["e_mh"] = "WRONG-TYPE";
    }
    try {
        ConfigParser().read_string("[s]\na = 1\n[s]\nb = 2\n");
    } except DuplicateSectionError as e {
        out["e_ds"] = "DuplicateSectionError: " + str(e);
    } except Exception {
        out["e_ds"] = "WRONG-TYPE";
    }
    try {
        ConfigParser().read_string("[s]\na = 1\na = 2\n");
    } except DuplicateOptionError as e {
        out["e_do"] = "DuplicateOptionError: " + str(e);
    } except Exception {
        out["e_do"] = "WRONG-TYPE";
    }
    cpi: ConfigParser = ConfigParser();
    cpi.read_string(
        "[DEFAULT]\nv0 = %(v1)s\nv1 = %(v0)s\n[s]\na = %(zz)s\npct = 50% off\n"
    );
    try {
        cpi.get("s", "a");
    } except InterpolationMissingOptionError as e {
        out["e_im"] = "InterpolationMissingOptionError: " + str(e);
    } except Exception {
        out["e_im"] = "WRONG-TYPE";
    }
    try {
        cpi.get("s", "v0");
    } except InterpolationDepthError as e {
        out["e_id"] = "InterpolationDepthError: " + str(e);
    } except Exception {
        out["e_id"] = "WRONG-TYPE";
    }
    try {
        cpi.get("s", "pct");
    } except InterpolationSyntaxError as e {
        out["e_is"] = "InterpolationSyntaxError: " + str(e);
    } except Exception {
        out["e_is"] = "WRONG-TYPE";
    }
    try {
        ConfigParser().read_string("[s]\nok\nbad2\n");
    } except ParsingError as e {
        out["e_pe"] = "ParsingError: " + str(e);
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
    cpf: ConfigParser = ConfigParser();
    cpf.read_string("[s]\na = 1\n");
    fb1: any = cpf.get("s", "zz", fallback=None);
    out["fb_opt_none"] = "None" if fb1 is None else str(fb1);
    fb2: any = cpf.get("nope", "k", fallback=None);
    out["fb_sect_none"] = "None" if fb2 is None else str(fb2);
    fb3: any = cpf.get("s", "zz", fallback="FB");
    out["fb_opt_val"] = "None" if fb3 is None else str(fb3);
    fb4: any = cpf.get("nope", "k", fallback="FB");
    out["fb_sect_val"] = "None" if fb4 is None else str(fb4);
    gi1: any = cpf.getint("s", "zz", fallback=7);
    out["gi_fb_val"] = "None" if gi1 is None else str(gi1);
    gi2: any = cpf.getint("nope", "k", fallback=None);
    out["gi_fb_none"] = "None" if gi2 is None else str(gi2);
    gf1: any = cpf.getfloat("s", "zz", fallback=2.5);
    out["gf_fb_val"] = "None" if gf1 is None else str(gf1);
    gb1: any = cpf.getboolean("s", "zz", fallback=True);
    out["gb_fb_val"] = "None" if gb1 is None else str(gb1);
    gb2: any = cpf.getboolean("s", "zz", fallback="yes");
    out["gb_fb_raw"] = "None" if gb2 is None else str(gb2);
    try {
        cpf.getint("s", "zz");
    } except NoOptionError as e {
        out["e_gi_nofb"] = "NoOptionError: " + str(e);
    } except Exception {
        out["e_gi_nofb"] = "WRONG-TYPE";
    }
    return out;
}
