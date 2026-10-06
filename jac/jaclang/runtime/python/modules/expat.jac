"""The Expat library as pyexpat and _elementtree see it.

Derived from CPython 3.14.6 Include/pyexpat.h and the parts of expat.h the
two modules use; see ../LICENSE.cpython. pyexpat calls the vendored libexpat
directly and exports the PyExpat_CAPI record; _elementtree reaches Expat only
through that record, as CPython's does.
"""

import from jaclang.runtime.python.cpython_api {
    PyMem_Free,
    PyMem_Malloc,
    PyMem_Realloc
}

import from c {
    # XML_Content: one node of an element declaration's content model.
    obj XML_Content {
        has content_type: i32,
            quant: i32,
            name: ptr[u8],
            numchildren: u32,
            children: ptr[XML_Content];
    }
    # XML_Feature: one entry of XML_GetFeatureList(), ended by feature 0.
    obj XML_Feature {
        has feature: i32,
            name: ptr[u8],
            value: i64;
    }  obj XML_Memory_Handling_Suite {
        has malloc_fcn: Callable[[u64], ptr] = 0,
            realloc_fcn: Callable[[ptr, u64], ptr] = 0,
            free_fcn: Callable[[ptr], None] = 0;
    }
    # struct PyExpat_CAPI (Include/pyexpat.h): new entries go at the end.
    obj PyExpat_CAPI {
        has magic: ptr[u8] = ptr[u8](),
            size: i32 = 0,
            MAJOR_VERSION: i32 = 0,
            MINOR_VERSION: i32 = 0,
            MICRO_VERSION: i32 = 0,
            ErrorString: Callable[[i32], ptr[u8]] = 0,
            GetErrorCode: Callable[[ptr], i32] = 0,
            GetErrorColumnNumber: Callable[[ptr], u64] = 0,
            GetErrorLineNumber: Callable[[ptr], u64] = 0,
            Parse: Callable[[ptr, ptr[u8], i32, i32], i32] = 0,
            ParserCreate_MM:
                Callable[[ptr[u8], ptr[XML_Memory_Handling_Suite], ptr[u8]], ptr] = 0,
            ParserFree: Callable[[ptr], None] = 0,
            SetCharacterDataHandler:
                Callable[[ptr, Callable[[ptr, ptr[u8], i32], None]], None] = 0,
            SetCommentHandler:
                Callable[[ptr, Callable[[ptr, ptr[u8]], None]], None] = 0,
            SetDefaultHandlerExpand:
                Callable[[ptr, Callable[[ptr, ptr[u8], i32], None]], None] = 0,
            SetElementHandler:
                Callable[
                    [
                        ptr,
                        Callable[[ptr, ptr[u8], ptr[ptr[u8]]], None],
                        Callable[[ptr, ptr[u8]], None]
                    ],
                    None
                ] = 0,
            SetNamespaceDeclHandler:
                Callable[
                    [
                        ptr,
                        Callable[[ptr, ptr[u8], ptr[u8]], None],
                        Callable[[ptr, ptr[u8]], None]
                    ],
                    None
                ] = 0,
            SetProcessingInstructionHandler:
                Callable[[ptr, Callable[[ptr, ptr[u8], ptr[u8]], None]], None] = 0,
            SetUnknownEncodingHandler:
                Callable[[ptr, Callable[[ptr, ptr[u8], ptr[i32]], i32], ptr], None] = 0,
            SetUserData: Callable[[ptr, ptr], None] = 0,
            SetStartDoctypeDeclHandler:
                Callable[
                    [ptr, Callable[[ptr, ptr[u8], ptr[u8], ptr[u8], i32], None]],
                    None
                ] = 0,
            SetEncoding: Callable[[ptr, ptr[u8]], i32] = 0,
            DefaultUnknownEncodingHandler: Callable[[ptr, ptr[u8], ptr[i32]], i32] = 0,
            SetHashSalt: Callable[[ptr, u64], i32] = 0,
            SetReparseDeferralEnabled: Callable[[ptr, u8], u8] = 0,
            SetAllocTrackerActivationThreshold: Callable[[ptr, u64], u8] = 0,
            SetAllocTrackerMaximumAmplification: Callable[[ptr, f32], u8] = 0,
            SetBillionLaughsAttackProtectionActivationThreshold:
                Callable[[ptr, u64], u8] = 0,
            SetBillionLaughsAttackProtectionMaximumAmplification:
                Callable[[ptr, f32], u8] = 0,
            SetHashSalt16Bytes: Callable[[ptr, ptr[u8]], u8] = 0;
    }
}

# An XML_Parser is an opaque pointer; XML_Encoding is read as its `int map[256]`
# followed by the data, convert and release pointers.
import from expat {
    def XML_ParserCreate_MM(
        encoding: ptr[u8], memsuite: ptr[XML_Memory_Handling_Suite], separator: ptr[u8]
    ) -> ptr;  def XML_ExternalEntityParserCreate(
        parser: ptr, context: ptr[u8], encoding: ptr[u8]
    ) -> ptr;  def XML_ParserFree(parser: ptr);  def XML_SetUserData(
        parser: ptr, data: ptr
    );  def XML_SetEncoding(parser: ptr, encoding: ptr[u8]) -> i32;  def XML_SetUnknownEncodingHandler(
        parser: ptr, handler: Callable[[ptr, ptr[u8], ptr[i32]], i32], data: ptr
    );  def XML_SetHashSalt(parser: ptr, salt: u64) -> i32;  def XML_SetReparseDeferralEnabled(
        parser: ptr, enabled: u8
    ) -> u8;  def XML_SetAllocTrackerActivationThreshold(
        parser: ptr, threshold: u64
    ) -> u8;  def XML_SetAllocTrackerMaximumAmplification(
        parser: ptr, factor: f32
    ) -> u8;  def XML_SetBillionLaughsAttackProtectionActivationThreshold(
        parser: ptr, threshold: u64
    ) -> u8;  def XML_SetBillionLaughsAttackProtectionMaximumAmplification(
        parser: ptr, factor: f32
    ) -> u8;  def XML_Parse(
        parser: ptr, data: ptr[u8], length: i32, final: i32
    ) -> i32;  def XML_GetBuffer(parser: ptr, length: i32) -> ptr;  def XML_ParseBuffer(
        parser: ptr, length: i32, final: i32
    ) -> i32;  def XML_StopParser(parser: ptr, resumable: u8) -> i32;  def XML_GetErrorCode(
        parser: ptr
    ) -> i32;  def XML_GetCurrentLineNumber(parser: ptr) -> u64;  def XML_GetCurrentColumnNumber(
        parser: ptr
    ) -> u64;  def XML_GetCurrentByteIndex(parser: ptr) -> i64;  def XML_ErrorString(
        code: i32
    ) -> ptr[u8];  def XML_ExpatVersion -> ptr[u8];  def XML_GetFeatureList -> ptr[
        XML_Feature
    ];  def XML_FreeContentModel(parser: ptr, model: ptr[XML_Content]);  def XML_GetSpecifiedAttributeCount(
        parser: ptr
    ) -> i32;  def XML_SetBase(parser: ptr, base: str) -> i32;  def XML_GetBase(
        parser: ptr
    ) -> ptr[u8];  def XML_GetInputContext(
        parser: ptr, offset: &mut i32, size: &mut i32
    ) -> ptr[u8];  def XML_SetParamEntityParsing(parser: ptr, flag: i32) -> i32;  def XML_UseForeignDTD(
        parser: ptr, flag: u8
    ) -> i32;  def XML_SetReturnNSTriplet(parser: ptr, flag: i32);  def XML_SetStartElementHandler(
        parser: ptr, handler: Callable[[ptr, ptr[u8], ptr[ptr[u8]]], None]
    );  def XML_SetEndElementHandler(
        parser: ptr, handler: Callable[[ptr, ptr[u8]], None]
    );  def XML_SetProcessingInstructionHandler(
        parser: ptr, handler: Callable[[ptr, ptr[u8], ptr[u8]], None]
    );  def XML_SetCharacterDataHandler(
        parser: ptr, handler: Callable[[ptr, ptr[u8], i32], None]
    );  def XML_SetUnparsedEntityDeclHandler(
        parser: ptr,
        handler: Callable[[ptr, ptr[u8], ptr[u8], ptr[u8], ptr[u8], ptr[u8]], None]
    );  def XML_SetNotationDeclHandler(
        parser: ptr, handler: Callable[[ptr, ptr[u8], ptr[u8], ptr[u8], ptr[u8]], None]
    );  def XML_SetStartNamespaceDeclHandler(
        parser: ptr, handler: Callable[[ptr, ptr[u8], ptr[u8]], None]
    );  def XML_SetEndNamespaceDeclHandler(
        parser: ptr, handler: Callable[[ptr, ptr[u8]], None]
    );  def XML_SetNamespaceDeclHandler(
        parser: ptr,
        start: Callable[[ptr, ptr[u8], ptr[u8]], None],
        end: Callable[[ptr, ptr[u8]], None]
    );  def XML_SetElementHandler(
        parser: ptr,
        start: Callable[[ptr, ptr[u8], ptr[ptr[u8]]], None],
        end: Callable[[ptr, ptr[u8]], None]
    );  def XML_SetCommentHandler(
        parser: ptr, handler: Callable[[ptr, ptr[u8]], None]
    );  def XML_SetStartCdataSectionHandler(
        parser: ptr, handler: Callable[[ptr], None]
    );  def XML_SetEndCdataSectionHandler(
        parser: ptr, handler: Callable[[ptr], None]
    );  def XML_SetDefaultHandler(
        parser: ptr, handler: Callable[[ptr, ptr[u8], i32], None]
    );  def XML_SetDefaultHandlerExpand(
        parser: ptr, handler: Callable[[ptr, ptr[u8], i32], None]
    );  def XML_SetNotStandaloneHandler(parser: ptr, handler: Callable[[ptr], i32]);  def XML_SetExternalEntityRefHandler(
        parser: ptr, handler: Callable[[ptr, ptr[u8], ptr[u8], ptr[u8], ptr[u8]], i32]
    );  def XML_SetStartDoctypeDeclHandler(
        parser: ptr, handler: Callable[[ptr, ptr[u8], ptr[u8], ptr[u8], i32], None]
    );  def XML_SetEndDoctypeDeclHandler(parser: ptr, handler: Callable[[ptr], None]);  def XML_SetEntityDeclHandler(
        parser: ptr,
        handler:
            Callable[
                [ptr, ptr[u8], i32, ptr[u8], i32, ptr[u8], ptr[u8], ptr[u8], ptr[u8]],
                None
            ]
    );  def XML_SetXmlDeclHandler(
        parser: ptr, handler: Callable[[ptr, ptr[u8], ptr[u8], i32], None]
    );  def XML_SetElementDeclHandler(
        parser: ptr, handler: Callable[[ptr, ptr[u8], ptr[XML_Content]], None]
    );  def XML_SetAttlistDeclHandler(
        parser: ptr,
        handler: Callable[[ptr, ptr[u8], ptr[u8], ptr[u8], ptr[u8], i32], None]
    );  def XML_SetSkippedEntityHandler(
        parser: ptr, handler: Callable[[ptr, ptr[u8], i32], None]
    );
}

# expat.h enumerations and pyexpat.h's magic.
glob XML_STATUS_ERROR: i32 = 0,
     XML_STATUS_OK: i32 = 1,
     XML_FALSE: u8 = 0,
     XML_TRUE: u8 = 1,
     XML_ERROR_NONE: i32 = 0,
     XML_ERROR_UNDEFINED_ENTITY: i32 = 11,
     XML_ERROR_INVALID_ARGUMENT: i32 = 41,
     XML_FEATURE_END: i32 = 0,
     XML_PARAM_ENTITY_PARSING_NEVER: i32 = 0,
     XML_PARAM_ENTITY_PARSING_UNLESS_STANDALONE: i32 = 1,
     XML_PARAM_ENTITY_PARSING_ALWAYS: i32 = 2,
     # sizeof(struct PyExpat_CAPI): the header, then 25 function pointers.
     PYEXPAT_CAPI_SIZE: i32 = 224,
     PYEXPAT_CAPI_MAGIC: str = "pyexpat.expat_CAPI 1.1",
     PYEXPAT_CAPSULE_NAME: str = "pyexpat.expat_CAPI";

# XML_ExpatVersionInfo(): the (major, minor, micro) of the linked library,
# read from XML_ExpatVersion()'s "expat_X.Y.Z".
def expat_version -> tuple[int, int, int] {
    text = ptr[u8](XML_ExpatVersion());
    numbers: list[int] = [0, 0, 0];
    part = 0;
    index = 0;
    while (text + index).view(1)[0] != 0 and part < 3 {
        byte = int((text + index).view(1)[0]);
        if byte == 46 {
            part += 1;
        } elif 48 <= byte <= 57 {
            numbers[part] = numbers[part] * 10 + (byte - 48);
        }
        index += 1;
    }
    return (numbers[0], numbers[1], numbers[2]);
}

# ExpatMemoryHandler: Expat allocates through PyMem, holding the GIL.
def:priv expat_malloc(size: u64) -> ptr {
    return PyMem_Malloc(size);
}

def:priv expat_realloc(address: ptr, size: u64) -> ptr {
    return PyMem_Realloc(address, size);
}

def:priv expat_free(address: ptr) {
    PyMem_Free(address);
}

import from c {
    glob expat_memory_suite: XML_Memory_Handling_Suite = XML_Memory_Handling_Suite(
             malloc_fcn=expat_malloc, realloc_fcn=expat_realloc, free_fcn=expat_free
         );
}
