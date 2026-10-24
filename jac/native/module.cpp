#include "llvm/IR/Module.h"
#include "core.h"
#include "llvm-c/Analysis.h"
#include "llvm-c/Core.h"
#include "llvm/ADT/SmallString.h"
#include "llvm/Bitcode/BitcodeWriter.h"
#include "llvm/IR/TypeFinder.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Transforms/Utils/SplitModule.h"
#include <clocale>
#include <string>

/* An iterator around a module's globals, including the stop condition */
struct GlobalsIterator {
    typedef llvm::Module::global_iterator iterator;
    iterator cur;
    iterator end;

    GlobalsIterator(iterator cur, iterator end) : cur(cur), end(end) {}
};

struct OpaqueGlobalsIterator;
typedef OpaqueGlobalsIterator *LLVMGlobalsIteratorRef;

/* An iterator around a module's functions, including the stop condition */
struct FunctionsIterator {
    typedef llvm::Module::const_iterator const_iterator;
    const_iterator cur;
    const_iterator end;

    FunctionsIterator(const_iterator cur, const_iterator end)
        : cur(cur), end(end) {}
};

struct OpaqueFunctionsIterator;
typedef OpaqueFunctionsIterator *LLVMFunctionsIteratorRef;

/* module types iterator */
class TypesIterator {
  private:
    llvm::TypeFinder finder;
    using const_iterator = llvm::TypeFinder::const_iterator;
    const_iterator cur;

  public:
    TypesIterator(llvm::Module &m, bool namedOnly)
        : finder(llvm::TypeFinder()) {
        finder.run(m, namedOnly);
        cur = finder.begin();
    }
    const llvm::Type *next() {
        if (cur != finder.end()) {
            return *cur++;
        }
        return nullptr;
    }
};

typedef TypesIterator *LLVMTypesIteratorRef;

//
// Local helper functions
//

namespace llvm {

static LLVMGlobalsIteratorRef wrap(GlobalsIterator *GI) {
    return reinterpret_cast<LLVMGlobalsIteratorRef>(GI);
}

static GlobalsIterator *unwrap(LLVMGlobalsIteratorRef GI) {
    return reinterpret_cast<GlobalsIterator *>(GI);
}

static LLVMFunctionsIteratorRef wrap(FunctionsIterator *GI) {
    return reinterpret_cast<LLVMFunctionsIteratorRef>(GI);
}

static FunctionsIterator *unwrap(LLVMFunctionsIteratorRef GI) {
    return reinterpret_cast<FunctionsIterator *>(GI);
}

static LLVMTypesIteratorRef wrap(TypesIterator *TyI) {
    return reinterpret_cast<LLVMTypesIteratorRef>(TyI);
}

static TypesIterator *unwrap(LLVMTypesIteratorRef TyI) {
    return reinterpret_cast<TypesIterator *>(TyI);
}

} // end namespace llvm

//
// Exported API
//

extern "C" {

API_EXPORT(void)
LLVMPY_DisposeModule(LLVMModuleRef m) { return LLVMDisposeModule(m); }

API_EXPORT(void)
LLVMPY_PrintModuleToString(LLVMModuleRef M, const char **outstr) {
    // Change the locale to en_US before calling LLVM to print the module
    // due to a LLVM bug https://llvm.org/bugs/show_bug.cgi?id=12906
    char *old_locale = strdup(setlocale(LC_ALL, NULL));
    setlocale(LC_ALL, "C");

    *outstr = LLVMPrintModuleToString(M);

    // Revert locale
    setlocale(LC_ALL, old_locale);
    free(old_locale);
}

API_EXPORT(const char *)
LLVMPY_GetModuleSourceFileName(LLVMModuleRef M) {
    return llvm::unwrap(M)->getSourceFileName().c_str();
}

API_EXPORT(const char *)
LLVMPY_GetModuleName(LLVMModuleRef M) {
    return llvm::unwrap(M)->getModuleIdentifier().c_str();
}

API_EXPORT(void)
LLVMPY_SetModuleName(LLVMModuleRef M, const char *Name) {
    llvm::unwrap(M)->setModuleIdentifier(Name);
}

API_EXPORT(LLVMValueRef)
LLVMPY_GetNamedFunction(LLVMModuleRef M, const char *Name) {
    return LLVMGetNamedFunction(M, Name);
}

API_EXPORT(LLVMValueRef)
LLVMPY_GetNamedGlobalVariable(LLVMModuleRef M, const char *Name) {
    using namespace llvm;
    return wrap(unwrap(M)->getGlobalVariable(Name));
}

API_EXPORT(LLVMTypeRef)
LLVMPY_GetNamedStructType(LLVMModuleRef M, const char *Name) {
    return LLVMGetTypeByName(M, Name);
}

API_EXPORT(int)
LLVMPY_VerifyModule(LLVMModuleRef M, char **OutMsg) {
    return LLVMVerifyModule(M, LLVMReturnStatusAction, OutMsg);
}

API_EXPORT(void)
LLVMPY_GetDataLayout(LLVMModuleRef M, const char **DL) {
    *DL = LLVMGetDataLayoutStr(M);
}

API_EXPORT(void)
LLVMPY_SetDataLayout(LLVMModuleRef M, const char *DL) {
    LLVMSetDataLayout(M, DL);
}

API_EXPORT(void)
LLVMPY_GetTarget(LLVMModuleRef M, const char **Triple) {
    *Triple = LLVMGetTarget(M);
}

API_EXPORT(void)
LLVMPY_SetTarget(LLVMModuleRef M, const char *Triple) {
    LLVMSetTarget(M, Triple);
}

// Iteration APIs

API_EXPORT(LLVMGlobalsIteratorRef)
LLVMPY_ModuleGlobalsIter(LLVMModuleRef M) {
    using namespace llvm;
    Module *mod = unwrap(M);
    return wrap(new GlobalsIterator(mod->global_begin(), mod->global_end()));
}

API_EXPORT(LLVMFunctionsIteratorRef)
LLVMPY_ModuleFunctionsIter(LLVMModuleRef M) {
    using namespace llvm;
    Module *mod = unwrap(M);
    return wrap(new FunctionsIterator(mod->begin(), mod->end()));
}

API_EXPORT(LLVMTypesIteratorRef)
LLVMPY_ModuleTypesIter(LLVMModuleRef M) {
    llvm::Module *mod = llvm::unwrap(M);
    auto *iter = new TypesIterator(*mod, false);
    return llvm::wrap(iter);
}

/*
  These functions return NULL if we are at the end
*/
API_EXPORT(LLVMValueRef)
LLVMPY_GlobalsIterNext(LLVMGlobalsIteratorRef GI) {
    using namespace llvm;
    GlobalsIterator *iter = unwrap(GI);
    if (iter->cur != iter->end) {
        return wrap(&*iter->cur++);
    } else {
        return NULL;
    }
}

API_EXPORT(LLVMValueRef)
LLVMPY_FunctionsIterNext(LLVMFunctionsIteratorRef GI) {
    using namespace llvm;
    FunctionsIterator *iter = unwrap(GI);
    if (iter->cur != iter->end) {
        return wrap(&*iter->cur++);
    } else {
        return NULL;
    }
}

API_EXPORT(LLVMTypeRef)
LLVMPY_TypesIterNext(LLVMTypesIteratorRef TyI) {
    return llvm::wrap(llvm::unwrap(TyI)->next());
}

API_EXPORT(void)
LLVMPY_DisposeGlobalsIter(LLVMGlobalsIteratorRef GI) {
    delete llvm::unwrap(GI);
}

API_EXPORT(void)
LLVMPY_DisposeFunctionsIter(LLVMFunctionsIteratorRef GI) {
    delete llvm::unwrap(GI);
}

API_EXPORT(void)
LLVMPY_DisposeTypesIter(LLVMTypesIteratorRef TyI) { delete llvm::unwrap(TyI); }

API_EXPORT(LLVMModuleRef)
LLVMPY_CloneModule(LLVMModuleRef M) { return LLVMCloneModule(M); }

/* Split M into N linkable partitions, each returned as bitcode, so a whole
   program's code generation runs on N threads (each parses its partition into
   its own context), the way LLVM's parallel LTO code generation splits it.
   Module-local symbols become hidden globals shared between partitions; they
   are renamed under a reserved prefix first, so none collides with a symbol
   the objects are linked against. M is consumed: its locals are renamed and
   externalized. Each buffer is released with LLVMPY_DisposeString. */
API_EXPORT(void)
LLVMPY_SplitModuleBitcode(LLVMModuleRef M, unsigned N, const char **outbufs,
                          size_t *outlens) {
    llvm::Module *mod = llvm::unwrap(M);
    for (llvm::GlobalValue &GV : mod->global_values()) {
        if (GV.hasLocalLinkage()) {
            GV.setName(llvm::Twine("__jac_part.") + GV.getName());
        }
    }
    unsigned index = 0;
    llvm::SplitModule(*mod, N, [&](std::unique_ptr<llvm::Module> part) {
        llvm::SmallString<0> buffer;
        llvm::raw_svector_ostream stream(buffer);
        llvm::WriteBitcodeToFile(*part, stream);
        outbufs[index] = LLVMPY_CreateByteString(buffer.data(), buffer.size());
        outlens[index] = buffer.size();
        ++index;
    });
}

} // end extern "C"
