# Review (R) items

Every line the converter cannot convert is kept as a comment and reported R with
a reason. This file lists the R cases that are left and what it takes to resolve
each one. The task list stays in `PLANNED.md`; the mapping is in
`RPG-MAPPING.md`, `DSPF-MAPPING.md` and `OCL-MAPPING.md`.

**Resolution kinds**

- **Convert**: work only, the free-form form exists.
- **Decide**: more than one result is possible, the owner decides first.
- **Sample**: needs a real member from the owner.
- **No form**: free-form RPG has no equivalent. The line stays R by design; the
  resolution is the reason text that tells the programmer what to do by hand.

Code status and test status follow `PLANNED.md`.

## IACNVFREE: C specification operations

| ID | Operation (dialect) | Why R today | Resolution | Code status | Test status |
|----|---------------------|-------------|------------|-------------|-------------|
| RV-01 | `LOKUP`, `MOVEA` (2, 3) | arrays | Convert: done in FREE-08 | Written | Not tested |
| RV-02 | `XLATE` (3) | colon operands | Convert: `%xlate(from:to:string:start)`; the no-`P` rule as for `CAT` | Written | Not tested |
| RV-03 | `MVR` (2, 3) | `%rem` needs integer operands | Convert for integer `DIV`/`MVR` pairs; R for decimals | Written | Not tested |
| RV-04 | `TESTN` (3), `TESTZ` (2, 3) | no direct built-in function | Convert: `%check` on the digits / zone test with `%bitand` | Planned | Not started |
| RV-05 | `BITON`, `BITOF`, `TESTB` (2, 3) | bit operations | Convert: `%bitor`, `%bitand` with `%bitnot`; test with `%bitand` | Planned | Not started |
| RV-06 | `MHHZO`, `MHLZO`, `MLHZO`, `MLLZO` (2, 3) | zone moves | Convert with `%bitand`/`%bitor` on one byte, or No form | Planned | Not started |
| RV-07 | `DEFN` (`*LIKE`) (2, 3) | declaration | Convert: `dcl-s NAME like(OTHER)` with the length of `OTHER` | Written | Not tested |
| RV-08 | `CALL`, `PARM`, `PLIST` (2, 3) | prototype needed | Convert: `dcl-pr` with `extpgm` and `callp`; parameter types from the known fields | Planned | Not started |
| RV-09 | `DSPLY`, `DUMP` (3) | message queue and response operands | Convert: `dsply` and `dump(a)`; the queue operands as written | Written | Not tested |
| RV-10 | `COMIT`, `ROLBK` (3) | file handling | Convert: `commit`, `rolbk`; the file list as `(e)` where used | Written | Not tested |
| RV-11 | `IN`, `OUT`, `OCUR` (3) | data areas and data structures | Convert: `in`, `out`, `occur`; `*DTAARA` definitions through `DEFN` (RV-07) | Planned | Not started |
| RV-12 | `EXFMT`, `READC`, `ACQ`, `NEXT`, `POST`, `REL` | WORKSTN file I/O | Convert with the display file of IACNVDSPF; needs the I/O design | Planned | Not started |
| RV-13 | `EXCPT`, `PAGE`, `PAGE1` to `PAGE7`, O and L specifications | output | FREE-06 (picked up by another session) | In progress | Not tested |
| RV-14 | `GOTO`, `TAG`, `CABxx` | free-form has no `GOTO` | Decide: rewrite the common patterns (skip forward to a `TAG` in the same group, loop back, jump to the end) with `if`, `dow`, `leave`, `return`; the other patterns stay R | Planned | Not started |
| RV-15 | `DEBUG`, `EXIT`, `FORCE`, `FREE`, `KEY`, `RLABL`, `SET`, `SHTDN` | S/36 and external subroutine features | No form: the reason names the replacement (`dump`, `callp`, `*inlr`) | Done | N/A |

## IACNVFREE: the RPG cycle

| ID | Item | Why R today | Resolution | Code status | Test status |
|----|------|-------------|------------|-------------|-------------|
| RV-20 | Control level indicators `L1` to `L9`, `LR`, matching records `MR`, total calculations, `1P` | the cycle is not in free-form | Decide: write the cycle as a `dow` loop with the primary file, level breaks and `*INLR` at the end (a skeleton the programmer completes), or keep R | Planned | Not started |
| RV-21 | Primary, secondary and look-ahead files, multiple record types, record identifying codes | the cycle | Decide with RV-20 | Planned | Not started |

## IACNVFREE: F, E and I specifications

| ID | Item | Why R today | Resolution | Code status | Test status |
|----|------|-------------|------------|-------------|-------------|
| RV-30 | I specifications of externally described files: renames, field indicators | no field rename on a file in free form | Decide: `prefix` on `dcl-f` and a data structure with `extname` and `extfld` for the reads and writes | Planned | Not started |
| RV-31 | WORKSTN, SPECIAL and other devices (F) | display files | with RV-12 | Planned | Not started |
| RV-32 | Continuation records (`RECNO`, `SUBR` exit, `NUM`, `FMTS`, `INFSR`) | | Convert: `dcl-f` keywords where they exist | Planned | Not started |
| RV-33 | Alternate collating sequence, file translation, transparent literals | tables | Sample: needs the tables | Planned | Not started |
| RV-34 | Record address and table files, address output (T), limits processing, direct file load, file addition output, packed key, noncontiguous key | not in free form | No form for most; `EXTK`: R by design | Done | N/A |
| RV-35 | Arrays from a file (E, columns 11-18), to a file, packed or binary format (columns 43, 55) | not converted | Convert: `fromfile`, `tofile`, `extfmt(P)`, `extfmt(B)` | Planned | Not started |
| RV-36 | Compiler directives (`/COPY`, `/TITLE` etc.) | members are fixed form | Decide: `/copy` only when the member is converted too; the other directives are dropped with a note | Planned | Not started |
| RV-37 | Embedded SQL: `WHENEVER ... GOTO`, `C/EXEC SQL` with indicators | needs `TAG` (RV-14) | with RV-14 | Planned | Not started |

## IACNVFREE: RPG IV

FREE-10 is being worked on in another session; its R items are tracked there.

## IAOCLTOCLE and IACNVDSPF

| ID | Item | Resolution | Code status | Test status |
|----|------|------------|-------------|-------------|
| RV-40 | OCL statements reported R (`PROMPT`, `HELP`, the `?F'S,..'?` field name, the DATAF1 date form) | see OCL-07, OCL-09 in `PLANNED.md` | In progress | Not tested |
| RV-41 | DSPF layout against a real member | Sample: DSP-05 | Planned | Not started |
| RV-42 | Subfile candidates | Sample: DSP-06 | Planned | Not started |

## Order of work

1. Open items first: RV-01 (written), then FREE-06 and FREE-10 when the other
   session is finished.
2. The Convert items that need no decision: RV-02, RV-03, RV-07, RV-09 and RV-10
   are written (FREE-13); RV-04, RV-05, RV-06, RV-08, RV-11, RV-32, RV-35 are next.
3. The Decide items: RV-14, RV-20/21, RV-30, RV-36.
4. The Sample items when the members arrive: RV-33, RV-41, RV-42.
5. RV-12 and RV-31 together with the display file converter.

RV-15 and RV-34 are not work items: a free-form source cannot contain them.
