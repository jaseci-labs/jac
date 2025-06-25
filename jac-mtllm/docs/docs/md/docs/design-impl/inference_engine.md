# MTLLM Inference Engine

## 1. Overview

The MTLLM (Meaning-Typed Large Language Model) Inference Engine is a core component of the MTLLM framework. It is responsible for managing the interaction between the application, the semantic registry, and the underlying Large Language Model (LLM). The Inference Engine handles the process of constructing prompts, managing LLM interactions, processing outputs, and implementing error handling and self-correction mechanisms.


> :Mermaid
>
> graph TD
>     A[Jaclang Application] --> B[Compilation]
>     B --> C[SemRegistry]
>     C --> D[Pickle File]
>     A --> E[Runtime]
>     E --> F[MTLLM Inference Engine]
>     F --> G[LLM Model]
>     F --> H[Tool Integration]
>     D -.-> F
>     G --> I[Output Processing]
>     I --> J[Error Handling]
>     J -->|Error| F
>     J -->|Success| K[Final Output]


## 2. Key Components

The MTLLM Inference Engine consists of several key components:

1. Prompt Constructor
2. LLM Interface
3. Output Processor
4. Error Handler
5. Tool Integrator

### 2.1 Prompt Constructor

The Prompt Constructor is responsible for building the input prompt for the LLM. It incorporates semantic information from the SemRegistry, user inputs, and contextual data to create a comprehensive and meaningful prompt.

Key features:
- Semantic enrichment using SemRegistry data
- Dynamic prompt structure based on the chosen method (ReAct, Reason, CoT)
- Integration of type information and constraints
- Inclusion of available tools and their usage instructions

Files involved:
- [`aott.py`](mtllm/aott.py) # aott_raise, get_all_type_explanations
- [`plugin.py`](mtllm/plugin.py) # with_llm method
- [`types.py`](mtllm/types.py) # Information, InputInformation, OutputHint, Tool classes

### 2.2 LLM Interface

The LLM Interface manages the communication between the MTLLM framework and the underlying Large Language Model. It handles sending prompts to the LLM and receiving raw outputs.

Key features:
- Abstraction layer for different LLM providers
- Handling of API communication and error management
- Handling Multi-Modal Inputs if applicable

Files involved:
- [`aott.py`](mtllm/aott.py) # aott_raise
- ['llms/base.py'](mtllm/llms/base.py) # BaseLLM class, __call__, __infer__

### 2.3 Output Processor

The Output Processor is responsible for parsing and validating the raw output from the LLM. It ensures that the output meets the expected format and type constraints.

Key features:
- Extraction of relevant information from LLM output
- Type checking and format validation
- Conversion of string representations to Python objects (when applicable)

> :Mermaid
>
> sequenceDiagram
>     participant A as Application
>     participant M as MTLLM Engine
>     participant S as SemRegistry
>     participant L as LLM Model
>     participant T as Tools
>     participant E as Evaluator
>     A->>M: Call by_llm()
>     M->>S: Fetch Semantic Info
>     M->>M: Construct Prompt
>     M->>L: Send Prompt
>     L->>M: Return Raw Output
>     M->>E: Evaluate Output
>     alt Evaluation Successful
>         E->>M: Return Result
>         M->>A: Return Final Output
>     else Evaluation Failed
>         E->>M: Return Error
>         M->>M: Construct Error Prompt
>         M->>L: Send Error Prompt
>         L->>M: Return Corrected Output
>         M->>E: Re-evaluate Output
>     end
>     opt Tool Usage Required
>         M->>T: Execute Tool
>         T->>M: Return Tool Result
>         M->>L: Include Tool Result in Prompt
>     end

Files involved:
- [`aott.py`](mtllm/aott.py) # aott_raise
- [`llms/base.py`](mtllm/llms/base.py) # BaseLLM class, BaseLLM.resolve_output, BaseLLM._extract_output, BaseLLM.to_object, BaseLLM._fix_output

### 2.4 Error Handler

The Error Handler manages error detection, classification, and the self-correction process. It works closely with the Output Processor to identify issues and initiate corrective actions.

Key features:
- Error detection and classification
- Generation of targeted feedback for the LLM
- Management of the self-correction loop
- Implementation of fallback strategies

> :Mermaid
>
> graph TD
>     A[LLM Output] --> B{Validate Output}
>     B -->|Valid| C[Return Result]
>     B -->|Invalid| D[Classify Error]
>     D --> E[Generate Error Feedback]
>     E --> F[Create Self-Correction Prompt]
>     F --> G[Submit to LLM]
>     G --> H{Check Retry Count}
>     H -->|Max Retries Reached| I[Return Error to Application]
>     H -->|Retries Available| B

Files involved:
- [`llms/base.py`](mtllm/llms/base.py) # BaseLLM._check_output , BaseLLM._extract_output, BaseLLM.to_object, BaseLLM._fix_output


### 2.5 Tool Integrator

The Tool Integrator manages the integration and execution of external tools within the inference process. It allows the LLM to leverage additional capabilities when needed.

Key features:
- Integration of tool results into the LLM prompt
- Error handling for tool execution in ReAct mode

> :Mermaid
>
> sequenceDiagram
>     participant A as Application
>     participant M as MTLLM Engine
>     participant L as LLM Model
>     participant T as Tools
>     A->>M: Call by_llm()
>     M->>L: Send Prompt
>     L->>M: Return Tool Usage Request
>     M->>T: Execute Tool
>     T->>M: Return Tool Result
>     M->>L: Include Tool Result in Prompt
>     L->>M: Return Final Output
>     M->>A: Return Final Output

Files involved:
- [`plugin.py`](mtllm/plugin.py) # callable_to_tool
- [`types.py`](mtllm/types.py) # Tool class
- [`tools/base.py`](mtllm/tools/base.py) # Tool class
- [`tools/<serper.py/wikipedia.py>](mtllm/tools) # Predefined tools

## 3. Inference Process

The MTLLM Inference Engine follows a structured process for each inference request:

1. **Initialization**: The inference process begins when the `with_llm` function is called from the application.

2. **Semantic Information Retrieval**: The engine queries the SemRegistry to retrieve relevant semantic information based on the current context and input parameters.

3. **Prompt Construction**: The Prompt Constructor builds the initial prompt, incorporating semantic information, input data, and any relevant type constraints or tool descriptions.

4. **LLM Interaction**: The constructed prompt is sent to the LLM via the LLM Interface. The raw output is received and passed to the Output Processor.

5. **Output Processing**: The Output Processor parses the LLM's response, extracting the relevant information and performing initial validation.

6. **Error Checking**: The processed output is checked for errors or inconsistencies. If issues are detected, the Error Handler is invoked to manage the self-correction process.

7. **Tool Execution (if required)**: If the LLM's response indicates the need for tool usage, the Tool Integrator manages the execution of the required tool and integration of its results.

8. **Iteration (if necessary)**: Steps 4-7 may be repeated if error correction or additional tool usage is required.

9. **Final Output**: Once a valid output is obtained, it is returned to the calling application.

> :Mermaid
>
> sequenceDiagram
>     participant App as Application
>     participant IE as Inference Engine
>     participant PC as Prompt Constructor
>     participant SR as Semantic Registry
>     participant LLM as LLM Interface
>     participant OP as Output Processor
>     participant EH as Error Handler
>     participant TI as Tool Integrator
>     App->>IE: Call by_llm()
>     IE->>SR: Retrieve semantic info
>     SR-->>IE: Return semantic info
>     IE->>PC: Construct prompt
>     PC-->>IE: Return initial prompt
>     loop Until valid output or max iterations
>         IE->>LLM: Send prompt
>         LLM-->>IE: Return raw output
>         IE->>OP: Process output
>         OP-->>IE: Return processed output
>         IE->>EH: Check for errors
>         alt Error detected
>             EH-->>IE: Return correction prompt
>             IE->>PC: Update prompt
>         else Tool required
>             IE->>TI: Execute tool
>             TI-->>IE: Return tool result
>             IE->>PC: Add tool result to prompt
>         else Valid output
>             IE->>App: Return final output
>         end
>     end


## 4. Implementation Details

### 4.1 `with_llm` Function

The `with_llm` function serves as the main entry point for the MTLLM Inference Engine. It orchestrates the entire inference process, initializing the necessary components, managing the flow of information, and handling the iterative process of obtaining a valid output from the LLM.

### 4.2 Error Handling and Self-Correction

The Error Handler implements a sophisticated mechanism for detecting and correcting errors in the LLM's output. It maintains a count of correction attempts, generates targeted prompts for error correction, and determines when to terminate the correction process.

### 4.3 Tool Integration

The Tool Integrator manages the execution of external tools and the integration of their results into the inference process. It converts normal functions to tools and executes them in the context of the inference engine.

## 5. Extensibility and Customization

The MTLLM Inference Engine is designed with extensibility in mind. Key areas for customization include:

1. **Prompting Strategies**: New prompting methods can be added by extending the Model class or changing the MTLLM_PROMPTs
2. **LLM Providers**: Support for new LLM providers can be added by implementing the BaseLLM interface.
3. **Tool Integration**: New tools can be easily registered and integrated into the inference process.
4. **Error Handling**: Custom error detection and correction strategies can be implemented by simple prompting changes.

## 6. Performance Considerations

The MTLLM Inference Engine is designed to balance performance and flexibility. Key performance considerations include:

1. **Caching**: Implement caching mechanisms for frequently used prompts or intermediate results.
2. **Asynchronous Processing**: Utilize asynchronous programming techniques for non-blocking I/O operations, especially in LLM interactions.
3. **Batching**: Implement batching strategies for processing multiple inference requests efficiently.
4. **Resource Management**: Carefully manage memory usage/ token usage, especially when dealing with large prompts or outputs.

## 7. Security Considerations

Security is a critical aspect of the MTLLM Inference Engine design:

1. **Input Sanitization**: Implement robust input sanitization to prevent injection attacks.
2. **Tool Execution Sandboxing**: Execute external tools in a controlled environment to prevent unauthorized actions.
3. **Output Validation**: Implement thorough output validation to ensure the LLM's responses don't contain harmful content.
4. **API Key Management**: Securely manage and rotate API keys for LLM providers.

## 8. Future Improvements

Potential areas for future improvement of the MTLLM Inference Engine include:

1. **Advanced Caching Strategies**: Implement more sophisticated caching mechanisms to improve performance.
2. **Multi-Model Support**: Enable the use of multiple LLMs within a single inference process for enhanced capabilities.
3. **Federated Learning Integration**: Explore the integration of federated learning techniques for privacy-preserving model updates.
4. **Explainability Features**: Develop features to provide explanations for the LLM's decision-making process.
5. **Adaptive Prompting**: Implement adaptive prompting strategies that evolve based on the success rates of different prompt structures.

This documentation provides a comprehensive overview of the MTLLM Inference Engine's design and implementation. It covers the key components, the inference process, implementation details, extensibility options, and important considerations for performance and security.