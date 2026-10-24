#include "core.h"

#include "lld/Common/Driver.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/StringExtras.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/BinaryFormat/COFF.h"
#include "llvm/Object/COFFImportFile.h"
#include "llvm/Object/ObjectFile.h"
#include "llvm/Config/llvm-config.h"
#include "llvm/Plugins/PassPlugin.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/raw_ostream.h"

#include <string>
#include <vector>

LLD_HAS_DRIVER(elf)
LLD_HAS_DRIVER(macho)
LLD_HAS_DRIVER(coff)
LLD_HAS_DRIVER(wasm)

// LLD's LTO backend (llvm::lto::opt) registers every pass plugin the LLVM
// build linked statically, calling get<Ext>PluginInfo() for each extension in
// llvm/Support/Extension.def. The official upstream releases (the
// macos-aarch64 slice) are built with Polly linked in, so their libLLVMLTO
// references getPollyPluginInfo(), which lives in libPolly.a; the shim links
// no Polly. Define each listed extension as a plugin that registers nothing.
// The from-source slices list no extensions, so this expands to nothing there.
#define HANDLE_EXTENSION(Ext)                                                  \
    llvm::PassPluginLibraryInfo get##Ext##PluginInfo() {                       \
        return {LLVM_PLUGIN_API_VERSION, #Ext, LLVM_VERSION_STRING,            \
                [](llvm::PassBuilder &) {}};                                   \
    }
#include "llvm/Support/Extension.def"

extern "C" {

// Run one LLD link in-process. argv[0] names the flavor the way the LLD
// binaries do ("ld.lld", "ld64.lld", "lld-link", "wasm-ld"); the rest are the
// linker's own command-line arguments. Returns the linker's exit code and
// hands back everything it printed. A link that crashed leaves LLD unable to
// run again in this process; *CanRunAgain reports that.
API_EXPORT(int)
LLVMPY_LldLink(const char **Argv, size_t Argc, const char **Out,
               int *CanRunAgain) {
    std::string text;
    llvm::raw_string_ostream os(text);
    std::vector<const char *> args(Argv, Argv + Argc);
    lld::Result result = lld::lldMain(
        args, os, os,
        {{lld::Gnu, &lld::elf::link},
         {lld::Darwin, &lld::macho::link},
         {lld::WinLink, &lld::coff::link},
         {lld::Wasm, &lld::wasm::link}});
    os.flush();
    *Out = LLVMPY_CreateString(text.c_str());
    *CanRunAgain = result.canRunAgain ? 1 : 0;
    return result.retCode;
}

// Write a COFF import library that binds Names to DllName, so lld-link can
// name a DLL the link never sees. ImportNames[i] is the DLL's own name for
// Names[i] (the CRT exports `strtoll` where the program calls `strtol`).
// Machine is an IMAGE_FILE_MACHINE_* value. Returns 0 on success, otherwise
// 1 with the reason in *Err.
API_EXPORT(int)
LLVMPY_WriteImportLibrary(const char *DllName, const char *Path,
                          unsigned Machine, const char **Names,
                          const char **ImportNames, size_t Count,
                          const char **Err) {
    std::vector<llvm::object::COFFShortExport> exports;
    exports.reserve(Count);
    for (size_t i = 0; i < Count; ++i) {
        llvm::object::COFFShortExport e;
        e.Name = Names[i];
        if (std::strcmp(Names[i], ImportNames[i]) != 0)
            e.ImportName = ImportNames[i];
        exports.push_back(e);
    }
    llvm::Error failed = llvm::object::writeImportLibrary(
        DllName, Path, exports,
        static_cast<llvm::COFF::MachineTypes>(Machine), false);
    if (failed) {
        *Err = LLVMPY_CreateString(llvm::toString(std::move(failed)).c_str());
        return 1;
    }
    return 0;
}

// List an object's global symbols, one per line: "U <name>" for a symbol the
// object references but does not define, "D <name> <address>" (hex) for one
// it defines. With Locals set, defined local symbols are listed too, so a
// linked image's whole symbol table can be read back.
// Returns 0 on success, otherwise 1 with the reason in *Out.
API_EXPORT(int)
LLVMPY_ObjectSymbols(const char *Buf, size_t Len, int Locals,
                     const char **Out) {
    auto buffer = llvm::MemoryBuffer::getMemBuffer(
        llvm::StringRef(Buf, Len), "", false);
    auto object =
        llvm::object::ObjectFile::createObjectFile(buffer->getMemBufferRef());
    if (!object) {
        *Out = LLVMPY_CreateString(
            llvm::toString(object.takeError()).c_str());
        return 1;
    }
    std::string text;
    for (const llvm::object::SymbolRef &sym : (*object)->symbols()) {
        llvm::Expected<uint32_t> flags = sym.getFlags();
        if (!flags) {
            llvm::consumeError(flags.takeError());
            continue;
        }
        if (!Locals && !(*flags & llvm::object::SymbolRef::SF_Global) &&
            !(*flags & llvm::object::SymbolRef::SF_Undefined))
            continue;
        if (*flags & llvm::object::SymbolRef::SF_FormatSpecific)
            continue;
        llvm::Expected<llvm::StringRef> name = sym.getName();
        if (!name) {
            llvm::consumeError(name.takeError());
            continue;
        }
        if (name->empty())
            continue;
        if (*flags & llvm::object::SymbolRef::SF_Undefined) {
            text += "U ";
            text += name->str();
            text += "\n";
            continue;
        }
        llvm::Expected<uint64_t> address = sym.getAddress();
        if (!address) {
            llvm::consumeError(address.takeError());
            continue;
        }
        text += "D ";
        text += name->str();
        text += " ";
        text += llvm::utohexstr(*address);
        text += "\n";
    }
    *Out = LLVMPY_CreateString(text.c_str());
    return 0;
}

} // end extern "C"
