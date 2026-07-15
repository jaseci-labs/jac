"""byLLM local-model serving subpackage.

Houses the manifest registry, the `llama-server` runner supervisor, and
the `jac model serve` daemon that exposes an OpenAI-compatible API on
localhost. Kept out of the `byllm.llm` hot import path.
"""
