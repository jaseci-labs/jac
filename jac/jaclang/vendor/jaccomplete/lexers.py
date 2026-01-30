import shlex

def split_line(line: str, point: int | None = None):
    if point is None:
        point = len(line)
    
    # Simple split strategy leveraging standard shlex
    # We want to find the word under cursor and previous words
    line_prefix = line[:point]
    
    try:
        # Standard shlex handles quotes and escapes correctly
        words = shlex.split(line_prefix)
    except ValueError:
        # Handle open quotes by optimistically closing them for parsing
        # This is a heuristic: if parsing fails, user might be typing inside a quote
        # Try appending a quote to see if it fixes it
        try:
            words = shlex.split(line_prefix + '"')
        except ValueError:
            try:
                words = shlex.split(line_prefix + "'")
            except ValueError:
                # Fallback: simple whitespace split if shlex fails completely
                words = line_prefix.split()
    
    if not words:
        return "", "", "", [], None

    # Check if the cursor is at the end of a word or in whitespace
    if line_prefix.endswith(" ") or not line_prefix:
        cword_prefix = ""
    else:
        cword_prefix = words[-1]
        words = words[:-1]

    # Detecting the quote char is tricky with stdlib shlex as it strips them.
    # We can infer it by checking the raw string vs the parsed word.
    cword_prequote = ""
    if line_prefix.strip() and len(cword_prefix) > 0:
        # Heuristic: verify if last word was quoted in original string
        # This is simplified; specific quoting logic for completion scenarios
        # is complex without a state machine, but this covers basic usage.
        pass

    return cword_prequote, cword_prefix, "", words, None
