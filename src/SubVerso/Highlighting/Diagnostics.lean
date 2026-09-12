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

/--
Metadata about highlighting, separate from messages produced by the highlighted code.

Design choice: return a summary alongside each highlighting result, rather than attach lookup
status to every token. Clients can render one warning per missing module, even when many tokens
refer to it. Combining results merges these summaries; individual occurrences are not retained.
-/
structure Diagnostics where
  /--
  Defining modules whose documentation metadata was unavailable when a docstring lookup failed.
  Sorted and deduplicated by the highlighting entrypoints.

  These names suggest `import all M`; they do not prove that a docstring exists. With metadata
  unavailable, even an undocumented declaration can contribute its module. Inherited documentation
  contributes the module reached through the loaded `inherit_doc` references.
  -/
  missingDocStringModules : Array Name := #[]
deriving Inhabited, Repr, BEq, ToJson, FromJson

/--
Read the `diagnostics` field shared by helper results, modules, and examples. Missing or null
fields represent empty diagnostics, allowing payloads from older SubVerso versions to be decoded.
-/
def Diagnostics.fromJsonField? (json : Json) : Except String Diagnostics :=
  if json.getObjValD "diagnostics" == .null then pure {}
  else json.getObjValAs? Diagnostics "diagnostics"

open Syntax in
instance : Quote Diagnostics where
  quote d := mkCApp ``Diagnostics.mk #[quote d.missingDocStringModules]

/-- Construct diagnostic metadata with sorted, deduplicated module names. -/
def Diagnostics.ofMissingDocStringModules (modules : Array Name) : Diagnostics :=
  let names := modules.foldl (fun names name => names.insert name) ({} : NameSet)
  { missingDocStringModules := names.toArray.qsort Name.quickLt }

/-- Combine diagnostics from separately highlighted pieces of code. -/
def Diagnostics.append (a b : Diagnostics) : Diagnostics :=
  .ofMissingDocStringModules (a.missingDocStringModules ++ b.missingDocStringModules)

instance : Append Diagnostics := ⟨Diagnostics.append⟩
