



def foo():
    def bar():
        print("bar")
    bar()



    class Lambda:
        def __init__(self):
            print("Lambda initialized")
        
        def __call__(self):
            print("lambda called")
    lambda_instance = Lambda()
    lambda_instance()
    lambda_instance.__call__()
    
    pass