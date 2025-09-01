"""byLLM Package - MTLLM Deprecation."""

import warnings

warnings.warn(
    "The 'mtllm' package is deprecated. Please import and use 'byllm' instead. "
    "See https://www.jac-lang.org for documentation.",
    DeprecationWarning,
    stacklevel=2,
)
