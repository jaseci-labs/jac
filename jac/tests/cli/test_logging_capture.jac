"""Logging handlers created during capture must remain usable afterwards."""
import io;
import logging;
import sys;
import from jaclang.testing.test_runner { _capture_begin, _capture_end }


test "capture restores surviving log handlers without redirecting explicit sinks" {
    logger = logging.getLogger('jac.tests.capture_lifetime');
    logger.propagate = False;
    logger.setLevel(int(logging.INFO));
    external = io.StringIO();
    explicit = logging.StreamHandler(external);
    logger.addHandler(explicit);
    state = _capture_begin();
    output = logging.StreamHandler(sys.stdout);
    errors = logging.StreamHandler(sys.stderr);
    try {
        logger.addHandler(output);
        logger.addHandler(errors);
        logger.info('during capture');
    } finally {
        captured = _capture_end(state);
    }
    try {
        assert 'during capture' in captured;
        assert output.stream is sys.stdout;
        assert errors.stream is sys.stderr;
        assert explicit.stream is external;
        logger.info('after capture');
        assert 'after capture' in external.getvalue();
    } finally {
        for handler in [output, errors, explicit] {
            logger.removeHandler(handler);
            handler.close();
        }
    }
}
