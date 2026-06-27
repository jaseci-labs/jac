import os;

glob ir_layer_typed_pointers_enabled: bool = os.environ.get(
         'JAC_LLVM_TYPED_POINTERS',
         os.environ.get('LLVMLITE_ENABLE_IR_LAYER_TYPED_POINTERS', '1')
     ) == '1';
