import Lake
open Lake DSL
open System (FilePath)

require subverso from "no-mod"

package «ffi»

target ffi.o pkg : FilePath := do
  let src ← inputFile (pkg.dir / "ffi.c") true
  let args :=
    if System.Platform.isWindows then #["-DLEAN_EXPORTING"]
    else #["-DLEAN_EXPORTING", "-fPIC"]
  buildLeanO (pkg.buildDir / "native" / "ffi.o") src #[] args

-- A separate library lets importers load the bindings and C object together.
lean_lib FfiBindings where
  roots := #[`Ffi.Bindings]
  precompileModules := true
  moreLinkObjs := #[ffi.o]

@[default_target]
lean_lib Ffi where
  roots := #[`FfiTest]
