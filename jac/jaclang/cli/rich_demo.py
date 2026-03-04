#!/usr/bin/env python3
"""Comprehensive Rich Mini Demo - All Features in One File."""

from jacpretty import Console, Style, print, get_console, render_markup

console = Console()

# ═══════════════════════════════════════════════════════════════════════════════
# TEXT STYLES
# ═══════════════════════════════════════════════════════════════════════════════
console.rule("Text Styles", style="bold cyan")

print("[bold]Bold[/] [dim]Dim[/] [italic]Italic[/] [underline]Underline[/] [strike]Strike[/] [reverse]Reverse[/] [blink]Blink[/]")
print("[b]B[/] [d]D[/] [i]I[/] [u]U[/] [s]S[/] [r]R[/] [c]Conceal[/]  ← shortcuts")
print("[bold italic underline]Combined styles[/]")

# ═══════════════════════════════════════════════════════════════════════════════
# NAMED COLORS (16 colors)
# ═══════════════════════════════════════════════════════════════════════════════
console.rule("Named Colors", style="bold cyan")

print("[black]■[/][red]■[/][green]■[/][yellow]■[/][blue]■[/][magenta]■[/][cyan]■[/][white]■[/] base")
print("[bright_black]■[/][bright_red]■[/][bright_green]■[/][bright_yellow]■[/][bright_blue]■[/][bright_magenta]■[/][bright_cyan]■[/][bright_white]■[/] bright")

# ═══════════════════════════════════════════════════════════════════════════════
# ADVANCED COLORS (Hex, RGB, 256)
# ═══════════════════════════════════════════════════════════════════════════════
console.rule("Advanced Colors", style="bold cyan")

print("[#ff5500]Hex #ff5500[/]  [#00ff88]#00ff88[/]  [#9933ff]#9933ff[/]")
print("[rgb(255,85,0)]RGB(255,85,0)[/]  [rgb(0,255,136)]RGB(0,255,136)[/]")
print("[color(196)]color(196)[/]  [color(46)]color(46)[/]  [color(201)]color(201)[/]  ← 256 palette")

# ═══════════════════════════════════════════════════════════════════════════════
# BACKGROUND COLORS
# ═══════════════════════════════════════════════════════════════════════════════
console.rule("Background Colors", style="bold cyan")

print("[on red] on red [/] [on blue] on blue [/] [on #333333] on #333333 [/]")
print("[white on blue]White on Blue[/]  [bold yellow on #333333]Bold Yellow on Dark[/]")

# ═══════════════════════════════════════════════════════════════════════════════
# NESTING & CLOSING TAGS
# ═══════════════════════════════════════════════════════════════════════════════
console.rule("Nesting & Closing", style="bold cyan")

print("[bold]Bold [red]+ Red[/red] still bold[/bold] normal")
print("[bold]Bold [italic]+ Italic [green]+ Green[/] back[/] done[/]")

# ═══════════════════════════════════════════════════════════════════════════════
# ESCAPING BRACKETS
# ═══════════════════════════════════════════════════════════════════════════════
console.rule("Escaping", style="bold cyan")

print("Escaped: \\[not markup\\] vs [red]actual markup[/]")

# ═══════════════════════════════════════════════════════════════════════════════
# CONSOLE.PRINT() OPTIONS
# ═══════════════════════════════════════════════════════════════════════════════
console.rule("Console.print() Options", style="bold cyan")

console.print("one", "two", "three", sep=" | ")          # Custom separator
console.print("No newline →", end="")                     # No newline
console.print(" ← same line")
console.print("Base style applied", style="bold green")  # Base style
console.print("[not parsed]", markup=False)              # Disable markup

# ═══════════════════════════════════════════════════════════════════════════════
# CONSOLE.RULE() VARIANTS
# ═══════════════════════════════════════════════════════════════════════════════
console.rule("Rule Variants", style="bold cyan")

console.rule()                                # Default
console.rule("Titled")                        # With title
console.rule("Custom Char", char="═")         # Custom character
console.rule("Styled", style="bold red")      # Styled rule

# ═══════════════════════════════════════════════════════════════════════════════
# CONSOLE.LOG() - Timestamped
# ═══════════════════════════════════════════════════════════════════════════════
console.rule("Logging", style="bold cyan")

console.log("Server started")
console.log("[green]Success:[/]", "Connected to database")

# ═══════════════════════════════════════════════════════════════════════════════
# CONSOLE PROPERTIES
# ═══════════════════════════════════════════════════════════════════════════════
console.rule("Console Properties", style="bold cyan")

print(f"Width: [cyan]{console.width}[/] | Is Terminal: [cyan]{console.is_terminal}[/]")

# ═══════════════════════════════════════════════════════════════════════════════
# STYLE CLASS
# ═══════════════════════════════════════════════════════════════════════════════
console.rule("Style Class", style="bold cyan")

s1 = Style("bold red")
s2 = Style("underline")
combined = s1 + s2

print(s1.render("Rendered with Style"))
print(combined.render("Combined: bold + red + underline"))
print(f"Style is truthy: {bool(s1)}, empty is falsy: {bool(Style())}")

# ═══════════════════════════════════════════════════════════════════════════════
# GLOBAL FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════
console.rule("Global Functions", style="bold cyan")

global_console = get_console()
print(f"get_console() returns Console: {type(global_console).__name__}")

ansi = render_markup("[bold]Raw ANSI[/]")
print(f"render_markup() → {repr(ansi[:20])}...")

# ═══════════════════════════════════════════════════════════════════════════════
# CONSOLE OPTIONS DEMO
# ═══════════════════════════════════════════════════════════════════════════════
console.rule("Console Options", style="bold cyan")

fixed = Console(width=40)
print(f"Console(width=40) → width={fixed.width}")

forced = Console(force_terminal=True)
print(f"Console(force_terminal=True) → is_terminal={forced.is_terminal}")

no_color = Console(no_color=True)
no_color.print("[red]No color mode[/] - tags stripped")

# ═══════════════════════════════════════════════════════════════════════════════
# PRACTICAL EXAMPLE: STATUS MESSAGES
# ═══════════════════════════════════════════════════════════════════════════════
console.rule("Practical: Status Messages", style="bold cyan")

print("[bold green]✓[/] Task completed")
print("[bold red]✗[/] Connection failed")
print("[bold yellow]⚠[/] Disk space low")
print("[bold blue]ℹ[/] Starting process...")

# ═══════════════════════════════════════════════════════════════════════════════
console.rule("Demo Complete!", style="bold green")
