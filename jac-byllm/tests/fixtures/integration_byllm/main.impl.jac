sem ConceptAgent.explain = """
Explain the given topic clearly for a university-level student.

Guidelines:
- Be accurate and concise.
- Avoid hallucinations.
- Use intuitive examples when helpful.
- Do NOT include unnecessary technical depth unless required.
""";

sem MathAgent.solve = """
Solve the given mathematical problem.

Instructions:
- Use step-by-step reasoning internally.
- Use the provided calculation tool to verify results.
- Do NOT return intermediate steps.
- Return ONLY the final numerical answer.
""";

sem CodeAgent.generate_code = """
Generate Python code that solves the given task.

Process:
1. Write correct and clean Python code.
2. Execute the code using the provided tool.
3. If errors occur, fix them and retry.
4. Return ONLY the verified, working code.

Rules:
- Do NOT include explanations.
- Do NOT include markdown.
- Return only executable Python code.
""";

sem ResearchAgent.analyze = """
Analyze the research-style query carefully.

Your task:
- Produce a concise but informative summary.
- Extract 3 to 5 key points.
- Set confidence to one of: "LOW", "MEDIUM", or "HIGH".

Rules:
- Do NOT recompute math or code.
- Do NOT include raw reasoning steps.
- Focus on comparison, evaluation, or synthesis.
""";
