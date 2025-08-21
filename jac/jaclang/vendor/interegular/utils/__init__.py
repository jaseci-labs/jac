import logging
from typing import Iterable

logger = logging.getLogger('interegular')
logger.addHandler(logging.StreamHandler())
logger.setLevel(logging.CRITICAL)


def soft_repr(s: str):
    """
    joins together the repr of each char in the string, while throwing away the repr
    This for example turns `"'\""` into `'"` instead of `\'"` like the normal repr
    would do.
    """
    return ''.join(repr(c)[1:-1] for c in str(s))
