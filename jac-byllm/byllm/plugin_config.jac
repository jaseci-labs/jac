"""Plugin configuration hooks for jac-byllm.

This module implements JacPluginConfig hooks to integrate with core's
configuration system, registering:
- Plugin metadata (name, version)
- Config schema for [plugins.byllm] section
"""

import from typing { Any }
import from jaclang.pycore.runtime { hookimpl }

"""Plugin configuration hooks for jac-byllm."""
class JacByllmPluginConfig {
    """Return plugin metadata."""
    @hookimpl
    static def get_plugin_metadata -> dict[str, Any] {
        return {
            "name": "byllm",
            "version": "0.4.8",
            "description": "byLLM - Easy to use APIs for LLM providers with Jaclang"
        };
    }

    """Return the plugin's configuration schema for [plugins.byllm]."""
    @hookimpl
    static def get_config_schema -> dict[str, Any] {
        return {
            "section": "byllm",
            "options": {
                "model": {
                    "type": "dict",
                    "default": {},
                    "description": "Default model configuration",
                    "nested": {
                        "default_model": {
                            "type": "string",
                            "default": "gpt-4o-mini",
                            "description": "Default model name (e.g., 'gpt-4o', 'gpt-4o-mini', 'claude-3-sonnet')"
                        },
                        "api_key": {
                            "type": "string",
                            "default": "",
                            "description": "API key for the LLM provider (can also use OPENAI_API_KEY, ANTHROPIC_API_KEY env vars)"
                        },
                        "base_url": {
                            "type": "string",
                            "default": "",
                            "description": "Custom API endpoint URL (for proxy or self-hosted models)"
                        },
                        "proxy": {
                            "type": "bool",
                            "default": False,
                            "description": "Enable proxy mode (uses OpenAI client instead of LiteLLM)"
                        },
                        "verbose": {
                            "type": "bool",
                            "default": False,
                            "description": "Enable verbose logging of LLM calls"
                        }
                    }
                },
                "call_params": {
                    "type": "dict",
                    "default": {},
                    "description": "Default call parameters for LLM invocations",
                    "nested": {
                        "temperature": {
                            "type": "float",
                            "default": 0.7,
                            "description": "Model creativity/randomness (0.0-2.0, lower is more deterministic)"
                        },
                        "max_tokens": {
                            "type": "int",
                            "default": 0,
                            "description": "Maximum response tokens (0 means no limit/model default)"
                        }
                    }
                },
                "litellm": {
                    "type": "dict",
                    "default": {},
                    "description": "LiteLLM-specific configuration",
                    "nested": {
                        "local_cost_map": {
                            "type": "bool",
                            "default": True,
                            "description": "Use local cost map instead of fetching from remote"
                        },
                        "drop_params": {
                            "type": "bool",
                            "default": True,
                            "description": "Drop unsupported parameters for different providers"
                        }
                    }
                },
                "system_prompt": {
                    "type": "string",
                    "default": "",
                    "description": "Override the default system prompt for LLM interactions. Leave empty to use built-in default."
                }
            }
        };
    }
}
