## Variante de fin ouvrant le J31 (M12 §1.3, §1.9 ; ARCHITECTURE §11.4) :
## treize clés `f1`, `f3`, `f4`, `f5b`, `f7` (A), `f5c`, `f5s`, `f9` (B), `f8`,
## `f10` (C), `f2`, `f6t`, `f6d` (D) — `EpilogueService.ending_key()`.
class_name EpilogueEndingDef
extends Resource

## Clé de variante (`f6t`…).
@export var key: StringName = &""
## Monde (`a`…`d`).
@export var world: StringName = &""
## Ouverture et clôture de la conclusion (`epi_f6t_open`, `epi_f6t_close`).
@export var open_key: String = ""
@export var close_key: String = ""
## QA-056 : variantes conditionnelles de l'ouverture et de la clôture (foyer
## `hh_*` du matin du J31…) — la première vraie l'emporte ; sinon
## `open_key` / `close_key`, qui ne nomment aucun proche.
@export var open_lines: Array[ConditionalKey] = []
@export var close_lines: Array[ConditionalKey] = []
## Jauge dont la valeur remplit le `%d` de l'ouverture (F10 : `pont31`), vide sinon.
@export var open_gauge: StringName = &""
## Lignes du foyer propres à la variante (première vraie) ; vide = celles de
## l'`EpilogueDef` (`home_lines`).
@export var home_lines: Array[ConditionalKey] = []
## Pas de ligne du foyer (F3 : `epi_home_none`).
@export var no_home_line: bool = false
## Briefing propre à la variante (`day31_d_intro_f6t`), lu par `BriefingContent`.
@export var intro_key: String = ""
