"""Minimal CLI autocompletion for argparse-based commands."""

import argparse
import contextlib
import os
import shlex
import subprocess
import sys
from typing import Optional, TextIO

from .shell_integration import shellcode  # noqa: F401


def _mute_stderr():
    """Context manager to suppress stderr during argparse parsing."""
    @contextlib.contextmanager
    def _ctx():
        old = sys.stderr
        sys.stderr = open(os.devnull, "w")
        try:
            yield
        finally:
            sys.stderr.close()
            sys.stderr = old
    return _ctx()


def _split_line(line: str, point: int | None = None):
    """Split command line at cursor position into words using shlex."""
    if point is None:
        point = len(line)
    prefix = line[:point]
    try:
        words = shlex.split(prefix)
    except ValueError:
        try:
            words = shlex.split(prefix + '"')
        except ValueError:
            try:
                words = shlex.split(prefix + "'")
            except ValueError:
                words = prefix.split()
    if not words:
        return "", [], None
    if prefix.endswith(" ") or not prefix:
        return "", words, None
    return words[-1], words[:-1], None


def _compgen(prefix: str, flag: str, extra: str = ""):
    """Run bash compgen for filesystem completion."""
    cmd = f"compgen -A {flag} {extra} -- '{prefix}'"
    try:
        return subprocess.check_output(
            ["bash", "-c", cmd], text=True, stderr=subprocess.DEVNULL
        ).splitlines()
    except subprocess.CalledProcessError:
        return []


def _file_completions(prefix: str, extensions=(), directories=True):
    """Complete filesystem paths, optionally filtered by extension."""
    if extensions:
        result = []
        if directories:
            result += [f + "/" for f in _compgen(prefix, "directory")]
        for ext in extensions:
            ext = ext.lstrip("*").lstrip(".")
            result += _compgen(prefix, "file", f"-X '!*.{ext}'")
        return result
    files = set(_compgen(prefix, "file"))
    dirs = set(_compgen(prefix, "directory"))
    result = list(files - dirs)
    if directories:
        result += [d + "/" for d in dirs]
    return result


class CompletionFinder:
    """Argparse-based shell completion finder."""

    def __call__(
        self,
        parser: argparse.ArgumentParser,
        exit_method=os._exit,
        output_stream: Optional[TextIO] = None,
    ) -> None:
        if "_JAC_COMPLETE" not in os.environ:
            return
        self._parser = parser
        self._descs: dict[str, str] = {}

        if output_stream is None:
            fname = os.environ.get("_JAC_COMPLETE_STDOUT_FILENAME")
            if fname:
                output_stream = open(fname, "w")
            else:
                try:
                    output_stream = os.fdopen(8, "w")
                except Exception:
                    exit_method(1)

        ifs = os.environ.get("_JAC_COMPLETE_IFS", "\013")
        comp_line = os.environ.get("COMP_LINE", "")
        comp_point = int(os.environ.get("COMP_POINT", "0"))
        cword_prefix, comp_words, _ = _split_line(comp_line, comp_point)

        start = int(os.environ.get("_JAC_COMPLETE", "1")) - 1
        comp_words = comp_words[start:]

        completions = self._get_completions(comp_words, cword_prefix)

        if os.environ.get("_JAC_COMPLETE_SHELL") == "zsh":
            completions = [f"{c}:{self._descs.get(c, '')}" for c in completions]

        output_stream.write(ifs.join(completions))
        output_stream.flush()
        exit_method(0)

    def _find_active_parser(self, parser, args):
        """Walk subparser tree to find the deepest matching parser."""
        if not args:
            return parser
        for action in parser._actions:
            if isinstance(action, argparse._SubParsersAction) and args[0] in action.choices:
                return self._find_active_parser(action.choices[args[0]], args[1:])
        return parser

    def _get_completions(self, comp_words, cword_prefix):
        remaining = comp_words[1:]  # skip script name
        try:
            with _mute_stderr():
                self._parser.parse_known_args(remaining, namespace=argparse.Namespace())
        except Exception:
            pass

        active = self._find_active_parser(self._parser, remaining)
        completions = []

        # Option/flag completions
        for action in active._actions:
            if action.option_strings and action.help != argparse.SUPPRESS:
                for opt in action.option_strings:
                    if opt.startswith(cword_prefix):
                        completions.append(opt)
                        self._descs[opt] = action.help or ""

        # Subcommand completions
        for action in active._actions:
            if isinstance(action, argparse._SubParsersAction):
                for name, sub in action.choices.items():
                    if name.startswith(cword_prefix):
                        completions.append(name)
                        self._descs[name] = sub.description or ""

        # Value completions for flag arguments
        prev = comp_words[-2] if len(comp_words) >= 2 else None
        if prev and prev.startswith("-"):
            for action in active._actions:
                if prev in action.option_strings and action.nargs != 0:
                    completer = getattr(action, "completer", None)
                    if completer and callable(completer):
                        try:
                            res = completer(
                                prefix=cword_prefix, action=action,
                                parser=active, parsed_args=argparse.Namespace(),
                            )
                            if isinstance(res, dict):
                                self._descs.update(res)
                                completions.extend(res.keys())
                            else:
                                completions.extend(res)
                        except Exception:
                            pass
                    else:
                        completions.extend(_file_completions(cword_prefix))
                    break

        return list(set(completions))


autocomplete = CompletionFinder()