import from logging { getLogger, basicConfig, INFO }

with entry {
    quiet = getLogger("quiet.one");
    quiet.debug("dropped-debug");
    quiet.info("dropped-info");
    quiet.warning("kept-warning");
    quiet.error("kept-error");

    basicConfig(level=INFO, format="%(levelname)s - %(name)s - %(message)s");

    lg = getLogger("jac.probe");
    lg.debug("still-dropped");
    lg.info("now-kept");
    lg.warning("warn-line");
    lg.error("error-line");

    top = getLogger();
    top.info("root-line");
}
