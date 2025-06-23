import from mtllm.llms {Gemini, OpenAI}

glob llm = OpenAI(verbose = False, model_name = 'gpt-4o-mini', temperature = 0.4);

glob guide =  "Explain why this assert triggered."
                                "Give details about what the root cause can be in the code."
                                "Try to explain in depth and pinpoint to exact line numbers."
                                "Output should be consise and poitwise explanation and possible actionables to the developer.";

def smart_assert_explanation(
        condition:str,
        traceback:str,
        call_stack:str,
        msg:str = '',
        variable_context:list[dict],
        use_def_chain:str = ''
    ) -> str by llm(incl_info = (guide));

def help_func() {
    return 'Helper function called' ;
}