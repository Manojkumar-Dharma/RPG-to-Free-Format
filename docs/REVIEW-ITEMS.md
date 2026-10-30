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
| RV-04 | `TESTN` (3), `TESTZ` (2, 3) | no direct built-in function | Convert: `%check` on the digits / zone test with `%bitand`; done in FREE-14 | Written | Not tested |
| RV-05 | `BITON`, `BITOF`, `TESTB` (2, 3) | bit operations | Convert: `%bitor`, `%bitand` with `%bitnot`; test with `%bitand`; done in FREE-14 | Written | Not tested |
| RV-06 | `MHHZO`, `MHLZO`, `MLHZO`, `MLLZO` (2, 3) | zone moves | Convert with `%bitand`/`%bitor` on one byte, or No form; character fields done in FREE-15, numeric (sign zone) stays R | Written | Not tested |
| RV-07 | `DEFN` (`*LIKE`) (2, 3) | declaration | Convert: `dcl-s NAME like(OTHER)` with the length of `OTHER` | Written | Not tested |
| RV-08 | `CALL`, `PARM`, `PLIST` (2, 3) | prototype needed | Convert: `dcl-pr` with `extpgm` and `callp`; parameter types from the known fields; done in FREE-16 (`PLIST *ENTRY` stays R) | Written | Not tested |
| RV-09 | `DSPLY`, `DUMP` (3) | message queue and response operands | Convert: `dsply` and `dump(a)`; the queue operands as written | Written | Not tested |
| RV-10 | `COMIT`, `ROLBK` (3) | file handling | Convert: `commit`, `rolbk`; the file list as `(e)` where used | Written | Not tested |
| RV-11 | `IN`, `OUT`, `*NAMVAR DEFN`, `UNLCK` of a data area written (FREE-17); `OCUR` written (FREE-20) | data areas and data structures | Convert: `in`, `out`, `occur`; `*DTAARA` definitions through `DEFN` (RV-07) | Written | Not tested |
| RV-12 | `EXFMT`, `READC`, `ACQ`, `NEXT`, `POST`, `REL` | WORKSTN file I/O | Decided 2026-10-28: externally described display files first; `EXFMT`, `READC` and the format operations written in FREE-43 (RPG III) and FREE-45 (RPG IV); `ACQ`, `REL`, `NEXT`, `POST` stay R | Written | Not tested |
| RV-13 | `EXCPT`, `PAGE`, `PAGE1` to `PAGE7`, O and L specifications | output | FREE-06: exception records done in part 1, the rest is RV-60 to RV-63 | Written | Not tested |
| RV-14 | `GOTO`, `TAG`, `CABxx` | free-form has no `GOTO` | Decided: rewrite the common patterns (skip forward to a `TAG` in the same group, loop back, jump to the end) with `if`, `dou`/`dow`, `leave`, `return`; the other patterns stay R | Written for RPG II and III (FREE-35) and RPG IV fixed form (FREE-44) | Not tested |
| RV-15 | `DEBUG`, `EXIT`, `FORCE`, `FREE`, `KEY`, `RLABL`, `SET`, `SHTDN` | S/36 and external subroutine features | No form: the reason names the replacement (`dump`, `callp`, `*inlr`) | Done | N/A |

## IACNVFREE: the RPG cycle

| ID | Item | Why R today | Resolution | Code status | Test status |
|----|------|-------------|------------|-------------|-------------|
| RV-20 | Control level indicators `L1` to `L9`, `LR`, matching records `MR`, total calculations, `1P` | the cycle is not in free-form | Decide: write the cycle as a `dow` loop with the primary file, level breaks and `*INLR` at the end (a skeleton the programmer completes), or keep R | Decided 2026-10-27: skeleton. FREE-36 wrote it for one primary file with control levels and total calculations | Written | Not tested; open: matching records `MR`, secondary and look-ahead files (`1P` needs no work: it is valid on output records only and is written with the skeleton) |
| RV-21 | Primary, secondary and look-ahead files, multiple record types, record identifying codes | the cycle | Decide with RV-20 | Decided with RV-20; FREE-36 handles one primary file; FREE-49 adds record types of the primary file (indicators 01 to 99, codes C and N, AND/OR); secondary and look-ahead files, Z and D codes stay R | Written in part | Not tested |

## IACNVFREE: F, E and I specifications

| ID | Item | Why R today | Resolution | Code status | Test status |
|----|------|-------------|------------|-------------|-------------|
| RV-30 | I specifications of externally described files: renames, field indicators | no field rename on a file in free form | Decided: renamed field is a copy (`dcl-s NEW like(EXT)`), set after READ and CHAIN when a record was read (FREE-24) and copied back to the external fields before WRITE and UPDATE of a record format named by an I specification (FREE-25); control levels, matching fields and field indicators stay R | Written | Not tested |
| RV-31 | WORKSTN, SPECIAL and other devices (F) | display files | externally described WORKSTN written for RPG III in FREE-43 (`sfile`) and RPG IV in FREE-45; program described display files in FREE-46 (declaration and I specification layout); SPECIAL stays R | Written | Not tested |
| RV-32 | Continuation records (`RECNO`, `SUBR` exit, `NUM`, `FMTS`, `INFSR`) | | Convert: `dcl-f` keywords where they exist; done in FREE-18 for DISK and PRINTER files (`COMIT`, `INFDS`, `INFSR`, `RECNO`, `RENAME`, `IGNORE`); WORKSTN, SPECIAL and `PRTCTL` options stay R | Written | Not tested |
| RV-33 | Alternate collating sequence, file translation, transparent literals | tables, FREE-50: `altseq(*src)`, `ftrans(*src)`, `**ALTSEQ`, `**FTRANS`; column 57 stays R | Hand-written sample `samples/FREEALT.rpg38` (H columns 26, 43, 57, `**` records of file translation and ALTSEQ, one compile-time array); a real member with tables is still wanted | Written in part | Not tested |
| RV-34 | Record address and table files, address output (T), limits processing, direct file load, file addition output, packed key, noncontiguous key | not in free form | No form for most; `EXTK`: R by design | Done | N/A |
| RV-35 | Arrays from a file (E, columns 11-18), to a file, packed or binary format (columns 43, 55) | not converted | Not possible: `FROMFILE` and `TOFILE` are not allowed in a free-form definition, `EXTFMT(P/B)` is only for such arrays (decided in FREE-19, stays R with that reason); `L` and `R` of compile-time arrays converted to `extfmt` | Written | Not tested |
| RV-36 | Compiler directives (`/COPY`, `/TITLE` etc.) | members are fixed form | Decide: `/copy` only when the member is converted too; the other directives are dropped with a note. Decided: convert the directive. Written as in RPG IV (FREE-29): `/COPY` and `/INCLUDE` are kept with status A in RPG II and III too | Written (kept as A) | Not tested |
| RV-37 | Embedded SQL: `WHENEVER ... GOTO`, `C/EXEC SQL` with indicators | needs `TAG` (RV-14) | Decided: `WHENEVER` is replaced by an explicit test of `SQLCODE` after each executable SQL statement that follows it (`sqlcode < 0`, `sqlcode = 100`, `sqlwarn0 = 'W'` or another positive `sqlcode`); the RV-14 planner decides what the test does (`if not (...)` ... `endif;` at the `TAG`, or `leavesr`, `return`, `iter`); no loop is built for a jump back, that stays R. `C/EXEC SQL` with indicators: No form, by design: SC09-1816 ("The Structured Query Language") puts the delimiter in columns 7-15, so the source has no place for a conditioning indicator; the line stays R and its reason tells the programmer to use an `IFxx` group, which is converted | Written for the `WHENEVER ... GOTO` part, RPG III and RPG IV (FREE-48); the indicators part needs no work | Not tested |

## IACNVFREE: RPG IV

FREE-10 (module `IAfreeFx4`): the R items of the RPG IV source types `RPGLE` and
`SQLRPGLE`. Code status follows `PLANNED.md`.

| ID | Item | Why R today | Resolution | Code status | Test status |
|----|------|-------------|------------|-------------|-------------|
| RV-50 | C specifications: `MOVE`/`MOVEL` between other type pairs, `MOVEA`, `TESTZ`, bit operations (`BITON`, `BITOF`, `TESTB`), `MVR` with decimals, `DEFN` with length or `*DTAARA`, `LOOKUP` | not converted for RPG IV yet (`XLATE`, `MVR` on integers, `DEFN *LIKE`, `TESTN` are done) | Convert: as RV-03 to RV-07 on the RPG IV columns and the type table of `IAfreeFx4` | Written | Not tested; FREE-22 wrote `BITON`, `BITOF`, `TESTB`, `TESTZ`; FREE-31 wrote `MOVEA` of whole arrays and `*LIKE DEFINE` with a length change; FREE-32 wrote `MVR` with decimals; FREE-33 wrote `*DTAARA DEFINE`, `IN`, `OUT`; FREE-34 wrote `MOVE(P)` of character fields; the other `MOVE`/`MOVEL` type pairs stay R by design (no equivalent assignment) |
| RV-51 | `CALL`/`PARM`/`PLIST` with a program name in a field or with a library, `CALLB`, `PLIST *ENTRY`, `ER`/`LR` indicators on `CALL` | the simple CALL is done | Convert: `extpgm(field)`, `extproc`, `dcl-pi *n` for `*ENTRY` (its parameter fields must not be declared twice) | Written | Not tested |
| RV-52 | Level indicators (columns 7-8) and `RT` on a calculation; a conditioning indicator on a group operation (`IF`, `DOW`, `BEGSR` ...) | the cycle, or no statement to wrap | Decide with RV-20 (cycle); for the group operations convert with a nested `if` | Written for `IF`/`DOW`/`DOU`/`FOR`/`DO` (FREE-21); FREE-36 wrote the control levels of the cycle skeleton; `RT` as conditioning or resulting indicator written by FREE-49 (`if *inrt; return;` at the top of the cycle, A) | Not tested |
| RV-53 | Resulting indicators of operations other than file operations, arithmetic and `COMP` (`LOOKUP`, `TESTN`, `CHECK` with `ER`, `SUBST` with `ER`, `CALL`) | no tests exist for them | Convert with the operation (RV-50): `TESTN` (FREE-14); `LOOKUP` on arrays and the error indicator of `CALL` (FREE-27). Stay R: `LOOKUP` of a table (`%tlookup`), the LR indicator of `CALL`, `SUBST` and `CHECK` with an error indicator (needs `MONITOR`) | Written | Not tested |
| RV-54 | `ANDxx`/`ORxx` after a comment line or with indicators; traditional `DO` without an index field | needs a hidden index | Convert: declare an index like FREE-05; `ANDxx`/`ORxx` after comment lines in RPG IV (FREE-28); with indicators: No form, the manual does not allow conditioning indicators on `ANDxx`/`ORxx`, stays R | DO without index written (FREE-21); ANDxx after comment lines written (FREE-28) | Not tested |
| RV-55 | I specifications (program described and external field renames) | cycle entries, rename | Convert program described files like FREE-04; renames with RV-30 | Written for program described files (FREE-23); renames with RV-30 (FREE-24, FREE-25) | Not tested |
| RV-56 | O specifications of RPG IV | columns differ | With FREE-06 part 3 | Written in part (FREE-42: program described printer file, exception records and `EXCEPT`) | Not tested; FREE-54 writes H, D and T records of a program described DISK file in the RPG II/III cycle skeleton; open: H, D and T records in RPG IV (needs an RPG IV cycle skeleton: the F specification of a primary file in `IAfreeFx4`), externally described O specifications |
| RV-57 | D specifications: names continued with `...`, keyword literals continued with `+` or `-`, `FROMFILE`, `TOFILE`, `CLASS`, `PACKEVEN`, object types; the F spec designations P, S, R, T, sequence, limits | not valid or no form | Convert the continuations (FREE-30: names continued with `...` on D and P specifications and inside keywords, literals continued with `+` or `-`); No form for the rest (`FROMFILE`, `TOFILE`, `CLASS`, `PACKEVEN`, object types, F designations P, S, R, T, sequence, limits stay R); a numeric constant continued on the next line stays open | Written | Not tested |
| RV-58 | `/COPY` and `/INCLUDE` members | the member is fixed form | with RV-36; converting the copied member itself is still open | Written (directive kept as A) | Not tested |
| RV-59 | SQL statements inside RPG IV groups are not indented with the group | `CalcSqlLine` keeps the RPG II/III indentation | Convert: indent with the group depth of `IAfreeFx4` (`Fx4Depth`, FREE-26) | Written | Not tested |

FREE-06 (module `IAfreeOut`): the R items of the output specifications.

| ID | Item | Why R today | Resolution | Code status | Test status |
|----|------|-------------|------------|-------------|-------------|
| RV-60 | Heading, detail and total output records (types H, D, T), `1P`, level indicators on output | written by the RPG cycle | Decided with RV-20: written by the cycle skeleton (FREE-37); OR lines of output indicators converted | Written | Not tested; `RT` on H, D and T records written by FREE-53 (`*inrt`); open: `MR` (with the secondary files, FREE-55), a program without a primary file (no skeleton: stays R, a design decision for you) |
| RV-61 | Edited numeric fields (edit codes, edit words), blank after, data format P, B, L, R, relative end positions, `PAGE`, `UDATE` and the like, `*PLACE`, array elements | DDS needs the edited width and other keywords | Convert: width table of the edit codes, `EDTCDE`/`EDTWRD`, `PAGNBR`, `DATE`, `clear` | Written in FREE-38, FREE-57 (`PAGE1`-`PAGE7`) and FREE-58 (`UDAY`, `UMONTH`, `UYEAR`, array elements and `*PLACE` through assignments before the `write`; data formats P and B on DISK records); stay R: data formats on a printer file, L, R, edit codes 5-9 | Not tested |
| RV-62 | Output of DISK files (`EXCPT`, `ADD`, `DEL`) and a second printer file | one DDS per source today | Convert: `write` of the record with a data structure; one DDS member per file with `DDSTGT` | Disk part written (FREE-39: exception records, `ADD`, `DEL`); several printer files written (FREE-40: one DDS per file, `*PRTF` gives each member its file name, IAC0106); the update of the record read written (FREE-41, `update FILE FILE_REC`) | Not tested |
| RV-63 | The DDS is written as comments at the end of the member | no second target yet | Convert: `DDSTGT` parameter and a second member | Written (FREE-06, `DDSTGT`, `DDSTYPE`, `DDSIFS`, message IAC0105) | Not tested |

## IAOCLTOCLE and IACNVDSPF

| ID | Item | Resolution | Code status | Test status |
|----|------|------------|-------------|-------------|
| RV-40 | OCL statements reported R (`PROMPT`, `HELP`, the `?F'S,..'?` field name, the DATAF1 date form) | see OCL-07, OCL-09 in `PLANNED.md`; samples `samples/PROMPTS.ocl` (PROMPT and HELP forms) and `samples/FSIZEDAT.ocl` (`?F'S,..'?`, DATAF1 with a date); DATAF1 date form written in FREE-51; `PROMPT` and `HELP` stay R by design (see OCL-07); the field name of `?F'S,..'?` still has to be checked on a system | In progress | Not tested |
| RV-41 | DSPF layout against a real member | Hand-written member `samples/ORDENTRY.dspf36` (order entry, 3 formats); a real QS36SRC member is still wanted: DSP-05 | Planned | Not started |
| RV-42 | Subfile candidates | Hand-written member `samples/ORDLIST.dspf36` (a list of 10 rows, one with a gap, one with 2 rows); a member that was converted to a subfile is still wanted: DSP-06; detection of candidates written in FREE-52 (report only, R) | Written in part | Not tested |

## Order of work

1. Open items first: RV-01 (written), then FREE-06 (RV-60 to RV-63) and FREE-10
   (RV-50 to RV-59).
2. The Convert items that need no decision: RV-02, RV-03, RV-07, RV-09 and RV-10
   are written (FREE-13); RV-04 and RV-05 are written (FREE-14), RV-06 (FREE-15), RV-08 (FREE-16), RV-11 (FREE-17, OCUR in FREE-20), RV-32 (FREE-18), RV-35 (FREE-19: L and R only, the file arrays have no free-form form). The planned items of this list are done; OCUR is written (FREE-20).
3. The Decide items still open: RV-20/21 (RV-14, RV-30 and RV-36 are decided).
4. The Sample items when the members arrive: RV-33, RV-41, RV-42.
5. RV-12 and RV-31 together with the display file converter.

RV-15 and RV-34 are not work items: a free-form source cannot contain them.
