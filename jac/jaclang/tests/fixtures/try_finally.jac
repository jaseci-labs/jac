with entry{

    # try and finally stmt
    try{
        print("try block");
    }finally{
        print("finally block");
    }



    #  try except else finally
    try{
        print("try block");
    }
    # except{
    #     print("except block");
    # }

    # except_def: KW_EXCEPT expression (KW_AS NAME)? code_block
    # is there any intention why here we compulsorily need to write type of exception in

    except exception{
        print("except block");
    }
    else{
        print("else block");
    }
    finally{
        print("finally block");
    }


}
