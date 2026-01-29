from . import completers
from .completers import ChoicesCompleter, DirectoriesCompleter, EnvironCompleter, FilesCompleter, SuppressCompleter
from .exceptions import ArgcompleteException
from .finders import CompletionFinder, ExclusiveCompletionFinder, safe_actions
from .io import debug, mute_stderr, warn
from .lexers import split_line
from .shell_integration import shellcode

autocomplete = CompletionFinder()
autocomplete.__doc__ = """ Use this to access jaccomplete. See :meth:`jaccomplete.CompletionFinder.__call__()`. """
