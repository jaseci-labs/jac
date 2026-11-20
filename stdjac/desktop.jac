"""A desktop app: a browser space in a webview window. The app serves its
bundle on a loopback port only it knows, and goes on to the spaces it reaches through
that, as a served app does. The window runs in a copy of the program, since the
server's event loop and a window's can't share a thread here."""

import os;
import signal;
import subprocess;
import sys;

"""In the copy that is the window, show it and exit; otherwise nothing."""
def:pub run_asked_window(title: str, width: int, height: int, min_width: int, min_height: int) {
    if len(sys.argv) != 3 or sys.argv[1] != "--window" {
        return;
    }
    code = run_window(sys.argv[2], title, width, height, min_width, min_height);
    if code == -1 {
        print("jac has no webview for this platform yet", file=sys.stderr);
    } elif code == -2 {
        print("this app's window needs GTK 3 and WebKitGTK 4.1", file=sys.stderr);
    }
    sys.exit(0 if code == 0 else 1);
}

obj:pub WindowProcess {
    has proc: subprocess.Popen | None = None;

    def open(port: int) {
        # The page its own server serves, at `port`; or, under `jac dev`,
        # the page its bundler's dev server does (JAC_DEV_PAGE).
        page = os.environ.get("JAC_DEV_PAGE", "");
        self.proc = subprocess.Popen([
            sys.executable,
            "--window",
            page if page != "" else "http://127.0.0.1:" + str(port) + "/",
        ]);
        # The window ends with its app, too: asked to stop, the app closes it.
        # (`jac dev` starts the app again when its code changes, each time
        # with a window of its own.)
        signal.signal(signal.SIGTERM, close_window);
        signal.signal(signal.SIGINT, close_window);
    }

    """The app ends with its window, and as its window did: with a failure
    when the window was not shown (its copy says why) or did not close of
    itself."""
    def watch {
        p = self.proc;
        if p is None {
            return;
        }
        ended = p.poll();
        if ended is not None {
            sys.exit(0 if ended == 0 else 1);
        }
    }
}

"""Close the window and start the program again in its place, as it was
started: its plan is read anew, so it is the arrangement its user chose."""
def relaunch {
    p = _window.proc;
    if p is not None and p.poll() is None {
        p.terminate();
        p.wait();
    }
    sys.stdout.flush();
    os.execv(sys.executable, [sys.executable] + sys.argv[1:len(sys.argv)]);
}

"""The app was asked to stop, by signal `number`: its window with it."""
def close_window(number: int, frame: any) {
    p = _window.proc;
    if p is not None and p.poll() is None {
        p.terminate();
    }
    sys.exit(128 + number);
}

glob _window: WindowProcess = WindowProcess(),
     # What stdjac.app shows a window with, in a program the build makes
     # this module part of (an app that runs a browser space).
     _window_host: bool = register_window_host(
         WindowHost(
             run_asked=run_asked_window,
             open=lambda (port: int) { _window.open(port) },
             watch=lambda { _window.watch() },
             relaunch=lambda { relaunch() },
         ),
     );
