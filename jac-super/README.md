# Jac Super

Enhanced console output plugin for Jac CLI with Rich formatting.

## Installation

```bash
pip install jac-super
```

Once installed, the plugin automatically registers and enhances all Jac CLI command output.

## Usage

No configuration required. After installation, jac-super automatically enhances output for all Jac commands:

- `jac create` - Enhanced project creation messages
- `jac start` - Server startup and status messages
- `jac run` - Formatted execution output
- `jac config` - Styled configuration display

## Environment Variables

| Variable | Effect |
|----------|--------|
| `NO_COLOR` | Disables colors (fallback to base console) |
| `NO_EMOJI` | Disables emojis (uses text labels) |
| `TERM=dumb` | Disables both colors and emojis |
