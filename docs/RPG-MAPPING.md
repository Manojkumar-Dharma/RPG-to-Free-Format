# RPG II to fully free-form RPG (IACNVFREE)

Status: decisions and evidence for FREE-01 to FREE-06. No converter code yet.
The source is System/36-compatible RPG II (member type RPG36); the target is
`**FREE` RPGLE, written for the V7R3 base release.

## Decisions

| Topic | Decision | Source of the decision |
|---|---|---|
| Stage 1 | None. `CVTRPGSRC` does not convert RPG36 or RPT36 members (SC09-2507, Table 125, "Source Member Types and their Conversion Status": No). RPG II is converted straight to `**FREE`. | Manual |
| Target | `**FREE` RPGLE. Features newer than V7R3 are avoided unless documented (SC09-2508, "What's New in 7.4" and later). | Project rule |
| Input specifications | Become definition (D) statements: a field rename, or a data structure, external or internal. | Author |
| Output specifications | An externally described printer file (PRTF, DDS) is created; the program writes its record formats. | Author |
| Companion RPG IV copy member | Not made for now. Whatever cannot be written in `**FREE` is kept as a comment and reported R. | Author |

## Limits of `**FREE` that matter here

SC09-2508, "Free-Form Statements": fixed-form statements such as `TAG`, and
Input and Output specifications, cannot appear in fully free-form source; they
must be in a copy file. Table 124 ("Operation Codes in Free-Form Syntax") is the
complete list of operations that can be written free-form. Every operation
section starts with a "Free-Form Syntax" line: the syntax, or "not allowed -
use ..." with the replacement (for example `ADD` becomes `+` or `+=`, `MOVEL`
becomes `EVAL` with built-ins, `PARM` becomes prototypes and `CALLP`).

Because there is no companion copy member, these are reported R and kept as
comments: `TAG`, `GOTO`, `CABxx` and anything else with no free-form form and no
documented replacement. (Open: whether a `GOTO`/`TAG` loop can be restructured
safely; not attempted.)

## Open items

- The RPG cycle: primary and secondary files, control levels (`L1` to `L9`),
  matching records, `1P`, `LR`. Check in SC09-2508 what `**FREE` can express
  before converting anything that relies on the cycle; until then such programs
  are reported R.
- A real RPG36 source member is still needed: the stored record layout (a
  sequence number or date prefix) is not documented in the guide, and the
  `.rpg36` files in `samples/OCL Examples` are placeholders (for example
  `SETON` at position 13, where RPG II has the operation in columns 28-32).
- Arrays and tables (E specifications), data structures, edit codes and
  compile-time data: mapping not written yet.

## Where to look in the manuals

Search the text files in `docs/ref/` for the heading.

| Topic | File | Heading to search |
|---|---|---|
| Control specification (H) | `sc091818-rpg2-guide.txt` | `Chapter 18. Control Specification` |
| File description (F) | same | `Chapter 19. File Description Specifications` |
| Extension (E) | same | `Chapter 20. Extension Specifications` |
| Line counter (L) | same | `Chapter 21. Line Counter Specifications` |
| Input (I) | same | `Chapter 23. Input Specifications` |
| Calculation (C) | same | `Chapter 24. Calculation Specifications` |
| Output (O) | same | `Chapter 25. Output Specifications` |
| Operation codes | same | `Chapter 27. Operation Codes` (each operation starts with a table of the factors it needs) |
| The cycle | same | `Chapter 5. The Detailed RPG II Program Cycle` |
| Indicators | same | `Chapter 13. Using Indicators` |
| Arrays and tables | same | `Chapter 14. Using Arrays and Tables` |
| Data structures | same | `Chapter 15. Using Data Structures` |
| Edit codes | same | `Chapter 16. Editing Numeric Fields` |
| System/36 against AS/400 differences | same | `Appendix A. Differences between System/36 RPG II and AS/400` |
| Free-form rules and `**FREE` | `sc092508-ile-rpg-reference.txt` | `Fully free-form statements` |
| Operations in free-form | same | `Table 124. Operation Codes in Free-Form Syntax` |
| Which release added a feature | same | `What's New in 7.3?`, `What's New in 7.4?` |
| CVTRPGSRC and member types | `sc092507-ile-rpg-programmers-guide.txt` | `Table 125. Source Member Types and their Conversion Status` |

## Mapping tables

To be written with the converter, one section per specification type, in the
same form as `OCL-MAPPING.md` and `DSPF-MAPPING.md`.
