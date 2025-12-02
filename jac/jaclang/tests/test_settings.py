"""Test Jac settings module."""

import os
from unittest.mock import mock_open, patch

from jaclang.settings import settings


def test_settings_config() -> None:
    """Basic settings for pass."""
    config_content = "[settings]\npass_timer = True"
    with patch("builtins.open", mock_open(read_data=config_content)):
        settings.load_config_file()
        assert settings.pass_timer is True
    config_content = "[settings]\npass_timer = False"
    with patch("builtins.open", mock_open(read_data=config_content)):
        settings.load_config_file()
        assert settings.pass_timer is False


def test_settings_env_vars() -> None:
    """Basic settings for pass."""
    os.environ["JACLANG_PASS_TIMER"] = "True"
    settings.load_env_vars()
    assert settings.pass_timer is True
    os.environ["JACLANG_PASS_TIMER"] = "False"
    settings.load_env_vars()
    assert settings.pass_timer is False
    os.unsetenv("JACLANG_PASS_TIMER")


def test_settings_precedence() -> None:
    """Basic settings for pass."""
    os.environ["JACLANG_PASS_TIMER"] = "True"
    config_content = "[settings]\npass_timer = False"
    with patch("builtins.open", mock_open(read_data=config_content)):
        settings.load_all()
        assert settings.pass_timer is True
    config_content = "[settings]\npass_timer = True"
    os.environ["JACLANG_PASS_TIMER"] = "False"
    with patch("builtins.open", mock_open(read_data=config_content)):
        settings.load_all()
        assert settings.pass_timer is False
    os.unsetenv("JACLANG_PASS_TIMER")
