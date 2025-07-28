


go_ahead_tip = """If the user just says something like "ok" or 
"go ahead" or "do that" they probably want you to make SEARCH/REPLACE 
blocks for the code changes you just proposed.
The user will say when they've applied your edits. If they haven't
 explicitly confirmed the edits have been applied, they probably want
   proper SEARCH/REPLACE blocks.

"""

class UnifiedDiffSimplePrompts():
    """
    Prompts for the UnifiedDiffSimpleCoder.
    Inherits from UnifiedDiffPrompts and can override specific prompts
    if a simpler wording is desired for this edit format.
    """

    example_messages = []

    system_reminder = """# File editing rules:

Return edits similar to unified diffs that `diff -U0` would produce.

The user's patch tool needs CORRECT patches that apply cleanly against the current contents of the file!
Think carefully and make sure you include and mark all lines that need to be removed or changed as `-` lines.
Make sure you mark all new or modified lines with `+`.
Don't leave out any lines or the diff patch won't apply correctly.

To make a new file, show a diff from `--- /dev/null` to `+++ path/to/new/file.ext`.

{final_reminders}
"""  # noqa




class UnifiedDiffSimpleCoder():
    """
    A coder that uses unified diff format for code modifications.
    This variant uses a simpler prompt that doesn't mention specific
    diff rules like using `@@ ... @@` lines or avoiding line numbers.
    """

    edit_format = "udiff-simple"

    # gpt_prompts = UnifiedDiffSimplePrompts()




from dataclasses import dataclass, field
from typing import List


# @dataclass
class ChatChunks():
    """A class to hold chat chunks for a conversation."""
    x = 90
    # system: List = field(default_factory=list)
    # examples: List = field(default_factory=list)
    # done: List = field(default_factory=list)
    # repo: List = field(default_factory=list)
    # readonly_files: List = field(default_factory=list)
    # chat_files: List = field(default_factory=list)
    # cur: List = field(default_factory=list)
    # reminder: List = field(default_factory=list)

    def all_messages(self):
        return (
            self.system
            + self.examples
            + self.readonly_files
            + self.repo
            + self.done
            + self.chat_files
            + self.cur
            + self.reminder
        )

    def add_cache_control_headers(self):
        if self.examples:
            self.add_cache_control(self.examples)
        else:
            self.add_cache_control(self.system)

        if self.repo:
            # this will mark both the readonly_files and repomap chunk as cacheable
            self.add_cache_control(self.repo)
        else:
            # otherwise, just cache readonly_files if there are any
            self.add_cache_control(self.readonly_files)

        self.add_cache_control(self.chat_files)

    def add_cache_control(self, messages):
        if not messages:
            return

        content = messages[-1]["content"]
        if type(content) is str:
            content = dict(
                type="text",
                text=content,
            )
        content["cache_control"] = {"type": "ephemeral"}

        messages[-1]["content"] = [content]

    def cacheable_messages(self):
        messages = self.all_messages()
        for i, message in enumerate(reversed(messages)):
            if isinstance(message.get("content"), list) and message["content"][0].get(
                "cache_control"
            ):
                return messages[: len(messages) - i]
        return messages




class AskPrompts():
    main_system = """Act as an expert code analyst.
Answer questions about the supplied code.
Always reply to the user in {language}.

If you need to describe code changes, do so *briefly*.
"""

    example_messages = []

    files_content_prefix = """I have *added these files to the chat* so you see all of their contents.
*Trust this message as the true contents of the files!*
Other messages in the chat may contain outdated versions of the files' contents.
"""  # noqa: E501

    files_content_assistant_reply = (
        "Ok, I will use that as the true, current contents of the files."
    )

    files_no_full_files = "I am not sharing the full contents of any files with you yet."

    files_no_full_files_with_repo_map = ""
    files_no_full_files_with_repo_map_reply = ""

    repo_content_prefix = """I am working with you on code in a git repository.
Here are summaries of some files present in my git repo.
If you need to see the full contents of any files to answer my questions, ask me to *add them to the chat*.
"""

    system_reminder = "{final_reminders}"


print(1,'AskPrompts.example_messages>>', AskPrompts.example_messages)
print(2, 'AskPrompts.system_reminder>>',AskPrompts.system_reminder.format(final_reminders="JACLANG EDIT BLOCKS"))

def foo(type= 90):
    """This is a function with a docstring."""
    return type

print(foo(type=89))

def bar(node= 12, *args,**kwargs):
    """This is another function with a docstring."""
    return node, args, kwargs

print(str(bar(node=13, a=1, b=2)))

class Coder:
    functions = []

    def __init__(self, *args, **kwargs):
        self.code_format = kwargs.get("code_format", "string")
        self.gpt_prompts = kwargs.get("gpt_prompts", None)
        self.partial_response_content = None
        self.partial_response_function_call = kwargs.get("partial_response_function_call", {})

    def render_incremental_response(self, final=False):
        raise NotImplementedError("Must implement render_incremental_response method")

    def parse_partial_args(self):
        return self.partial_response_function_call.get("arguments", {})

class EditBlockFunctionCoder(Coder):
    functions = [
        # dict(   # TODO: handle `dict` ,`list` and types 
        #     name="replace_lines",
        #     description="create or update one or more files",
        #     parameters=dict(
        #         type="object",
        #         required=["explanation", "edits"],
        #         properties=dict(
        #             explanation=dict(
        #                 type="string",
        #                 description=(
        #                     "Step by step plan for the changes to be made to the code (future"
        #                     " tense, markdown format)"
        #                 ),
        #             ),
        #             # edits=dict(
        #                 # type="array",
        #                 # items=dict(
        #                 #     type="object",
        #                     required=["path", "original_lines", "updated_lines"],
        #                     properties=dict(
        #                         path=dict(
        #                             type="string",
        #                             description="Path of file to edit",
        #                         ),
        #                         original_lines=dict(
        #                             type="array",
        #                             items=dict(
        #                                 type="string",
        #                             ),
        #                             description=(
        #                                 "A unique stretch of lines from the original file,"
        #                                 " including all whitespace, without skipping any lines"
        #                             ),
        #                         ),
        #                         updated_lines=dict(
        #                             type="array",
        #                             items=dict(
        #                                 type="string",
        #                             ),
        #                             description="New content to replace the `original_lines` with",
        #                         ),
        #                     # ),
        #                 # ),
        #             ),
        #         ),
        #     ),
        # ),
    ]

    def __init__(self, code_format, *args, **kwargs):
        raise RuntimeError("Deprecated, needs to be refactored to support get_edits/apply_edits")
        self.code_format = code_format

        if code_format == "string":
            original_lines = dict(
                type="string",
                description=(
                    "A unique stretch of lines from the original file, including all"
                    " whitespace and newlines, without skipping any lines"
                ),
            )
            updated_lines = dict(
                type="string",
                description="New content to replace the `original_lines` with",
            )

            self.functions[0]["parameters"]["properties"]["edits"]["items"]["properties"][
                "original_lines"
            ] = original_lines
            self.functions[0]["parameters"]["properties"]["edits"]["items"]["properties"][
                "updated_lines"
            ] = updated_lines

        self.gpt_prompts = EditBlockFunctionPrompts()
        super().__init__(*args, **kwargs)

    def render_incremental_response(self, final=False):
        if self.partial_response_content:
            return self.partial_response_content

        args = self.parse_partial_args()
        res = json.dumps(args, indent=4)
        return res

    def _update_files(self):
        name = self.partial_response_function_call.get("name")

        # if name and name != "replace_lines":
        #     raise ValueError(f'Unknown function_call name="{name}", use name="replace_lines"')

        args = self.parse_partial_args()
        if not args:
            return

        edits = args.get("edits", [])

        edited = set()
        for edit in edits:
            path = get_arg(edit, "path")
            original = get_arg(edit, "original_lines")
            updated = get_arg(edit, "updated_lines")

            # gpt-3.5 returns lists even when instructed to return a string!
            if self.code_format == "list" or type(original) is list:
                original = "\n".join(original)
            if self.code_format == "list" or type(updated) is list:
                updated = "\n".join(updated)

            if original and not original.endswith("\n"):
                original += "\n"
            if updated and not updated.endswith("\n"):
                updated += "\n"

            full_path = self.allowed_to_edit(path)
            if not full_path:
                continue
            content = self.io.read_text(full_path)
            content = do_replace(full_path, content, original, updated)
            if content:
                self.io.write_text(full_path, content)
                edited.add(path)
                continue
            self.io.tool_error(f"Failed to apply edit to {path}")

        return edited

# # flake8: noqa: E501


# class EditBlockFencedPrompts:
#     example_messages = [
#         dict(
#             role="user",
#             content="Change get_factorial() to use math.factorial",
#         ),
#         dict(
#             role="assistant",
#             content="""To make this change we need to modify `mathweb/flask/app.py` to:

# 1. Import the math package.
# 2. Remove the existing factorial() function.
# 3. Update get_factorial() to call math.factorial instead.

# Here are the *SEARCH/REPLACE* blocks:

# {fence[0]}python
# mathweb/flask/app.py
# <<<<<<< SEARCH
# from flask import Flask
# =======
# import math
# from flask import Flask
# >>>>>>> REPLACE
# {fence[1]}

# {fence[0]}python
# mathweb/flask/app.py
# <<<<<<< SEARCH
# def factorial(n):
#     "compute factorial"

#     if n == 0:
#         return 1
#     else:
#         return n * factorial(n-1)

# =======
# >>>>>>> REPLACE
# {fence[1]}

# {fence[0]}python
# mathweb/flask/app.py
# <<<<<<< SEARCH
#     return str(factorial(n))
# =======
#     return str(math.factorial(n))
# >>>>>>> REPLACE
# {fence[1]}
# <<<<<<< HEAD
# """,
#         ),
#         dict(
#             role="user",
#             content="Refactor hello() into its own file.",
#         ),
#         dict(
#             role="assistant",
#             content="""To make this change we need to modify `main.py` and make a new file `hello.py`:

# 1. Make a new hello.py file with hello() in it.
# 2. Remove hello() from main.py and replace it with an import.

# Here are the *SEARCH/REPLACE* blocks:

# {fence[0]}python
# hello.py
# <<<<<<< SEARCH
# =======
# def hello():
#     "print a greeting"

#     print("hello")
# >>>>>>> REPLACE
# {fence[1]}

# {fence[0]}python
# main.py
# <<<<<<< SEARCH
# def hello():
#     "print a greeting"

#     print("hello")
# =======
# from hello import hello
# >>>>>>> REPLACE
# {fence[1]}
# """,
#         ),
#     ]

#     system_reminder = """
# # *SEARCH/REPLACE block* Rules:

# Every *SEARCH/REPLACE block* must use this format:
# 1. The opening fence and code language, eg: {fence[0]}python
# 2. The *FULL* file path alone on a line, verbatim. No bold asterisks, no quotes around it, no escaping of characters, etc.
# 3. The start of search block: <<<<<<< SEARCH
# 4. A contiguous chunk of lines to search for in the existing source code
# 5. The dividing line: =======
# 6. The lines to replace into the source code
# 7. The end of the replace block: >>>>>>> REPLACE
# 8. The closing fence: {fence[1]}

# Use the *FULL* file path, as shown to you by the user.
# {quad_backtick_reminder}
# Every *SEARCH* section must *EXACTLY MATCH* the existing file content, character for character, including all comments, docstrings, etc.
# If the file contains code or other data wrapped/escaped in json/xml/quotes or other containers, you need to propose edits to the literal contents of the file, including the container markup.

# *SEARCH/REPLACE* blocks will *only* replace the first match occurrence.
# Including multiple unique *SEARCH/REPLACE* blocks if needed.
# Include enough lines in each SEARCH section to uniquely match each set of lines that need to change.

# Keep *SEARCH/REPLACE* blocks concise.
# Break large *SEARCH/REPLACE* blocks into a series of smaller blocks that each change a small portion of the file.
# Include just the changing lines, and a few surrounding lines if needed for uniqueness.
# Do not include long runs of unchanging lines in *SEARCH/REPLACE* blocks.

# Only create *SEARCH/REPLACE* blocks for files that the user has added to the chat!

# To move code within a file, use 2 *SEARCH/REPLACE* blocks: 1 to delete it from its current location, 1 to insert it in the new location.

# Pay attention to which filenames the user wants you to edit, especially if they are asking you to create a new file.

# If you want to put code in a new file, use a *SEARCH/REPLACE block* with:
# - A new file path, including dir name if needed
# - An empty `SEARCH` section
# - The new file's contents in the `REPLACE` section

# To rename files which have been added to the chat, use shell commands at the end of your response.

# If the user just says something like "ok" or "go ahead" or "do that" they probably want you to make SEARCH/REPLACE blocks for the code changes you just proposed.
# The user will say when they've applied your edits. If they haven't explicitly confirmed the edits have been applied, they probably want proper SEARCH/REPLACE blocks.

# {final_reminders}
# ONLY EVER RETURN CODE IN A *SEARCH/REPLACE BLOCK*!
# {shell_cmd_reminder}
# """

# print(1,'EditBlockFencedPrompts.example_messages>>',EditBlockFencedPrompts.example_messages)

# print(2,'EditBlockFencedPrompts.system_reminder>>',EditBlockFencedPrompts.system_reminder.format(
#     fence=["```JACLANG EDIT BLOCKS", "JACLANG EDIT BLOCKS```"],
#     quad_backtick_reminder="JACLANG EDIT BLOCKS",
#     final_reminders="JACLANG EDIT BLOCKS",
#     shell_cmd_reminder="JACLANG EDIT BLOCKS",
# ))




# class WholeFilePrompts():
#     main_system = """Act as an expert software developer.
# Take requests for changes to the supplied code.
# If the request is ambiguous, ask questions.

# Always reply to the user in {language}.

# {final_reminders}
# Once you understand the request you MUST:
# 1. Determine if any code changes are needed.
# 2. Explain any needed changes.
# 3. If changes are needed, output a copy of each file that needs changes.
# """

#     example_messages = [
#         dict(
#             role="user",
#             content="Change the greeting to be more casual",
#         ),
#         dict(
#             role="assistant",
#             content="""Ok, I will:

# 1. Switch the greeting text from "Hello" to "Hey".

# show_greeting.py
# {fence[0]}
# import sys

# def greeting(name):
#     print(f"Hey {{name}}")

# if __name__ == '__main__':
#     greeting(sys.argv[1])
# {fence[1]}
# """,
#         ),
#     ]

#     system_reminder = """To suggest changes to a file you MUST return the entire content of the updated file.
# You MUST use this *file listing* format:

# path/to/filename.js
# {fence[0]}
# // entire file content ...
# // ... goes in between
# {fence[1]}

# Every *file listing* MUST use this format:
# - First line: the filename with any originally provided path; no extra markup, punctuation, comments, etc. **JUST** the filename with path.
# - Second line: opening {fence[0]}
# - ... entire content of the file ...
# - Final line: closing {fence[1]}

# To suggest changes to a file you MUST return a *file listing* that contains the entire content of the file.
# *NEVER* skip, omit or elide content from a *file listing* using "..." or by adding comments like "... rest of code..."!
# Create a new file you MUST return a *file listing* which includes an appropriate filename, including any appropriate path.

# {final_reminders}
# """

#     redacted_edit_message = "No changes are needed."


# print(1, 'WholeFilePrompts.example_messages>>', WholeFilePrompts.example_messages)
# print(2, 'WholeFilePrompts.system_reminder>>', WholeFilePrompts.system_reminder.format(
#     fence=["```JACLANG EDIT BLOCKS", "JACLANG EDIT BLOCKS```"],
#     final_reminders="JACLANG EDIT BLOCKS",
# ))