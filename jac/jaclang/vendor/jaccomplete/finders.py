import argparse
import os
import sys
from typing import Callable, Dict, List, Optional, Sequence, TextIO, Union, Any

from . import io as _io
from .completers import FilesCompleter
from .io import mute_stderr
from .lexers import split_line


def default_validator(completion: str, prefix: str) -> bool:
    return completion.startswith(prefix)


class CompletionFinder:
    """
    Main autocompletion class for Jaccomplete.
    Uses standard argparse to parse arguments and find the appropriate completer.
    """

    def __init__(
        self,
        argument_parser: Optional[argparse.ArgumentParser] = None,
        always_complete_options: Union[bool, str] = True,
        exclude: Optional[Sequence[str]] = None,
        validator: Optional[Callable] = None,
        print_suppressed: bool = False,
        default_completer: FilesCompleter = FilesCompleter(),
        append_space: Optional[bool] = None,
    ):
        self._parser = argument_parser
        self._formatter: Optional[argparse.HelpFormatter] = None
        self.always_complete_options = always_complete_options
        self.exclude = exclude if exclude else []
        self.validator = validator if validator else default_validator
        self.print_suppressed = print_suppressed
        self._display_completions: Dict[str, str] = {}
        self.default_completer = default_completer
        if append_space is None:
            self.append_space = os.environ.get("_JAC_COMPLETE_SUPPRESS_SPACE") != "1"
        else:
            self.append_space = append_space

    def __call__(
        self,
        argument_parser: argparse.ArgumentParser,
        always_complete_options: Union[bool, str] = True,
        exit_method: Callable = os._exit,
        output_stream: Optional[TextIO] = None,
        exclude: Optional[Sequence[str]] = None,
        validator: Optional[Callable] = None,
        print_suppressed: bool = False,
        append_space: Optional[bool] = None,
        default_completer: FilesCompleter = FilesCompleter(),
    ) -> None:
        self.__init__(
            argument_parser,
            always_complete_options=always_complete_options,
            exclude=exclude,
            validator=validator,
            print_suppressed=print_suppressed,
            append_space=append_space,
            default_completer=default_completer,
        )

        if "_JAC_COMPLETE" not in os.environ:
            return

        if output_stream is None:
            filename = os.environ.get("_JAC_COMPLETE_STDOUT_FILENAME")
            if filename is not None:
                output_stream = open(filename, "w")
            else:
                try:
                    output_stream = os.fdopen(8, "w")
                except Exception:
                    exit_method(1)

        assert output_stream is not None

        ifs = os.environ.get("_JAC_COMPLETE_IFS", "\013")
        comp_line = os.environ.get("COMP_LINE", "")
        comp_point = int(os.environ.get("COMP_POINT", "0"))

        cword_prequote, cword_prefix, cword_suffix, comp_words, last_wordbreak_pos = (
            split_line(comp_line, comp_point)
        )

        start = int(os.environ.get("_JAC_COMPLETE", "1")) - 1
        comp_words = comp_words[start:]

        # Run completion logic
        completions = self._get_completions(
            comp_words, cword_prefix, cword_prequote, last_wordbreak_pos
        )

        # Formatting for ZSH or others
        if os.environ.get("_JAC_COMPLETE_SHELL") == "zsh":
            formatted_completions = []
            for c in completions:
                desc = self._display_completions.get(c, "")
                # Zsh format: value:description
                formatted_completions.append(f"{c}:{desc}")
            completions = formatted_completions

        output_stream.write(ifs.join(completions))
        output_stream.flush()
        exit_method(0)

    def _get_completions(
        self,
        comp_words: List[str],
        cword_prefix: str,
        cword_prequote: str,
        last_wordbreak_pos: Optional[int],
    ) -> List[str]:
        # Parse arguments up to the current word to find the active parser context

        active_parser = self._parser
        parsed_args = argparse.Namespace()
        remaining_args = comp_words[1:]  # Skip script name

        # Traverse subparsers
        # We try to match known subcommands to descend into subparsers

        def find_subparser(
            parser: argparse.ArgumentParser, args: List[str]
        ) -> tuple[argparse.ArgumentParser, List[str]]:
            # Simple greedy traversal for subparsers
            if not args:
                return parser, args

            # Look for subparser actions
            subparsers_actions = [
                a for a in parser._actions if isinstance(a, argparse._SubParsersAction)
            ]

            for sp_action in subparsers_actions:
                if args[0] in sp_action.choices:
                    next_parser = sp_action.choices[args[0]]
                    return find_subparser(next_parser, args[1:])

            return parser, args

        # This is a simplification; a full argparse emulation is complex.
        # We assume the user structure is relatively clean.
        # We try to parse everything to populate the namespace, suppressing stderr
        try:
            with mute_stderr():
                # We relax requirements to allow partial parsing
                active_parser.parse_known_args(remaining_args, namespace=parsed_args)
        except Exception:
            pass

        active_parser, _ = find_subparser(self._parser, remaining_args)

        # Now we have the active parser. Collect completions.
        completions = []

        # 1. Option completions (flags)
        for action in active_parser._actions:
            if action.option_strings:  # It's an option (flag)
                if self.print_suppressed or action.help != argparse.SUPPRESS:
                    completions.extend(
                        [
                            opt
                            for opt in action.option_strings
                            if opt.startswith(cword_prefix)
                        ]
                    )
                    for opt in action.option_strings:
                        if opt.startswith(cword_prefix):
                            self._display_completions[opt] = (
                                action.help if action.help else ""
                            )

        # 2. Subcommand completions
        subparsers_actions = [
            a
            for a in active_parser._actions
            if isinstance(a, argparse._SubParsersAction)
        ]
        for sp_action in subparsers_actions:
            for choice, helper in sp_action.choices.items():
                if choice.startswith(cword_prefix):
                    completions.append(choice)
                    # Try to get help from the subparser
                    self._display_completions[choice] = (
                        helper.description if helper.description else ""
                    )

        # 3. Completer logic for values
        # We assume if it's not a flag, it might be a value for an action
        # Finding *which* action is expecting a value is the hard part without full introspection.
        # For this reduced version, we will only run completers if explicitly attached,
        # or fall back to file completion if it looks like a file path.

        # Heuristic: verify if previous word was a flag that expects an argument
        prev_word = comp_words[-2] if len(comp_words) >= 2 else None

        active_action = None
        if prev_word and prev_word.startswith("-"):
            for action in active_parser._actions:
                if prev_word in action.option_strings and action.nargs != 0:
                    active_action = action
                    break

        if active_action:
            # Run specific completer for this action
            completer = getattr(active_action, "completer", self.default_completer)
            if completer:
                # Helper to run completer
                c_results = self._run_completer(
                    completer, cword_prefix, active_action, active_parser, parsed_args
                )
                completions.extend(c_results)
        else:
            # Positional arguments
            pass

        return list(set(completions))

    def _run_completer(self, completer, prefix, action, parser, parsed_args):
        try:
            if callable(completer):
                res = completer(
                    prefix=prefix, action=action, parser=parser, parsed_args=parsed_args
                )
                if isinstance(res, dict):
                    for k, v in res.items():
                        self._display_completions[k] = v
                    return list(res.keys())
                return res
            # Handle class-based instances
            elif hasattr(completer, "complete"):
                return [c for c in completer.complete(prefix, 0)]  # type: ignore
        except Exception:
            return []
        return []

    def get_display_completions(self):
        return self._display_completions
