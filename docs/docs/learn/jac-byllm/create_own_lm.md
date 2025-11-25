# Create Your Own Language Model

This guide will help you to bring your own language model to be used with byLLM. This is helpful if you have a self-hosted Language Model or you are using a different service that is not currently supported by LiteLLM. This example explores this feature, taking OpenAI SDK as an example.

> **IMPORTANT**
>
> This assumes that you have a proper understanding on how to inference with your language model. If you are not sure about this, please refer to the documentation of your language model.

## Steps

- Create a new class that inherits from `BaseModel` class.

=== "Python"
    ```python linenums="1"
from byllm.llm import BaseLLM
from openai import OpenAI

class MyOpenAIModel(BaseLLM):
    def __init__(self, model_name: str, **kwargs: object) -> None:
        """Initialize the MockLLM connector."""
        super().__init__(model_name, **kwargs)

    def model_call_no_stream(self, params):
        client = OpenAI(api_key=self.api_key)
        response = client.chat.completions.create(**params)
        return response

    def model_call_with_stream(self, params):
        client = OpenAI(api_key=self.api_key)
        response = client.chat.completions.create(stream=True, **params)
        return response
    ```
=== "Jac"
    ```jac linenums="1"
import from byllm.llm { BaseLLM }
import from openai { OpenAI }

obj  MyOpenAIModel(BaseLLM){
    has model_name: str;
    has config: dict = {};

    def post_init() {
        super().__init__(model_name=self.model_name, **kwargs);
    }

    def model_call_no_stream(params: dict) {
        client = OpenAI(api_key=self.api_key);
        response = client.chat.completions.create(**params);
        return response;
    }

    def model_call_with_stream(params: dict) {
        client = OpenAI(api_key=self.api_key);
        response = client.chat.completions.create(stream=True, **params);
        return response;
    }
}
    ```

- Initialize your model with the required parameters.

```jac
# Initialize as global variable
glob llm = MyLLM(model_name="gpt-4o");
```

Thats it! You have successfully created your own Language Model to be used with byLLM.

>  **NOTICE**
>
> This feature is under development and if you face an incompatibility, please open an issue [here](https://github.com/Jaseci-Labs/Jaseci/issues).