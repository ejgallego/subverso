/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module
public import SubVerso.DocString

public section

open Lean
open SubVerso.Compat

namespace SubVerso.Highlighting

/-- Metadata about highlighting, separate from messages produced by the highlighted code. -/
structure Diagnostics where
  /--
  Defining modules whose documentation metadata was unavailable when a docstring lookup failed.
  Sorted and deduplicated by `withDiagnostics`.

  These names suggest `import all M`; they do not prove that a docstring exists. With metadata
  unavailable, even an undocumented declaration can contribute its module. Inherited documentation
  contributes the module reached through the loaded `inherit_doc` references.
  -/
  missingDocStringModules : Array Name := #[]
deriving Inhabited, Repr, BEq, ToJson, FromJson

open Syntax in
instance : Quote Diagnostics where
  quote d := mkCApp ``Diagnostics.mk #[quote d.missingDocStringModules]

/-- A collector that can be shared by several highlighting calls. -/
abbrev DiagnosticsRef := IO.Ref NameSet

/-- Run highlighting with a fresh collector and return its deduplicated diagnostic metadata. -/
def withDiagnostics [Monad m] [MonadLiftT IO m] (act : DiagnosticsRef → m α) :
    m (α × Diagnostics) := do
  let ref ← (IO.mkRef ({} : NameSet) : IO _)
  let result ← act ref
  let modules := (← (ref.get : IO NameSet)).toArray.qsort Name.quickLt
  return (result, { missingDocStringModules := modules })

/-- Look up documentation, recording unavailable metadata only when lookup fails. -/
def findDocStringWithDiagnostics? [Monad m] [MonadLiftT IO m]
    (env : Environment) (declName : Name) (diagnostics : Option DiagnosticsRef := none) :
    m (Option String) := do
  let result ← SubVerso.findDocString env declName
  if let .unavailable mod := result then
    if let some ref := diagnostics then
      (ref.modify (·.insert mod) : IO Unit)
  return result.toOption
