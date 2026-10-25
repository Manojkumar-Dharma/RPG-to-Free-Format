# Planned work

Each item is independent and can be worked in parallel. Keep to the project
rules: `.sqlrpgle` sources, fully free format, lines of 90 columns or less,
descriptive names, V7R3 base. Add or update the matching mapping document in
the same commit. Each item has two status columns, so it is clear what to pick and what to test.

**Code status:** `Planned` (not started, pick it), `In progress` (partly written),
`Written` (pushed to main, may still change after testing), `Done` (no more code work).

**Test status:** `Not started` (nothing to test yet), `Not tested` (written, needs a
compile and test on the IBM i), `Tested` (compiled and tested, fine), `N/A` (nothing to
test, for example a study item).

To pick work: Code status `Planned` and no blocker in Notes. To test: Code status
`Written` and Test status `Not tested`.

| ID | Converter | Item | Code status | Test status | Notes |
|----|-----------|------|-------------|-------------|-------|
| OCL-01 | IAOCLTOCLE | PRINTER, BLDFILE | Written | Not tested | Needs a compile and test |
| OCL-02 | IAOCLTOCLE | Procedure calls other than LOAD and RUN | Written | Not tested | Needs a compile and test |
| OCL-03 | IAOCLTOCLE | `?F'...'?` file sizes; DATAF1- and ACTIVE- conditions | Written | Not tested | `?F'A,..'?`, DATAF1 and ACTIVE written; open items moved to OCL-09 |
| OCL-04 | IAOCLTOCLE | WAIT, PAUSE, NOHALT, CANCEL | Written | Not tested | Needs a compile and test; `CANCEL PRT,...` for spool entries moved to OCL-10 |
| OCL-05 | IAOCLTOCLE | ATTR, ALLOCATE, DEALLOC, SCRATCH | Written | Not tested | Needs a compile and test; device names and priorities are untested constants |
| OCL-06 | IAOCLTOCLE | SESSION, MEMBER, LIBRARY, MRTPROC | Written | Not tested | LIBRARY, SESSION for APPC and MRTPROC calls written; MEMBER is part of OCL-11; MRTPROC is a sample procedure name, not a statement |
| OCL-07 | IAOCLTOCLE | PROMPT, HELP, INCLUDE | In progress | Not tested | INCLUDE written as a procedure call; PROMPT and HELP reported R; PROMPT conversion waits for a DSPF sample |
| OCL-08 | IAOCLTOCLE | Explicit SRCCCSID for IFS input (common reader, so it also serves IACNVDSPF) | Written | Not tested | Needs a compile and test |
| OCL-09 | IAOCLTOCLE | Open items from OCL-03: `?F'S,..'?` written as initial records, DATAF1 date form | In progress | Not tested | DATAF1 `'name,ALL'` written, needs a compile and test; `?F'S,..'?` field name PHRCDC to verify; DATAF1 date form still open |
| OCL-10 | IAOCLTOCLE | `// CANCEL PRT,...` (spool file entries) | Written | Not tested | Printer ID taken as an output queue name, own entries only for ALL and FORMS |
| OCL-11 | IAOCLTOCLE | `// *` and `// **` message statements, MEMBER, `?Mmic?` expressions | Written | Not tested | Message ID prefix `USR` assumed (confirmed fine); check against a real message file |
| DSP-01 | IACNVDSPF | H (help) specs | Done | Tested |  |
| DSP-02 | IACNVDSPF | Message fields, array fields, edit codes | Written | Not tested | Message fields written as MSGID fields; edit codes written as EDTCDE; array fields are WSU only, not supported on the AS/400 and not converted |
| DSP-03 | IACNVDSPF | Output indicators on input/output fields | Written | Not tested | Written as two definitions of the field; DDS may not allow one name with usage B and I |
| DSP-04 | IACNVDSPF | Confirm assumptions: CFnn(nn) command keys, INDARA and INVITE added, OVRDTA/OVRATR override keywords | Done | Not tested | Checked against the manuals, see `docs/DSPF-MAPPING.md`; open: `CFnn(nn)` response indicator, `CF` against `CA`, `PUTOVR` and `ERASEINP` behaviour need a compile or display test |
| DSP-05 | IACNVDSPF | Check the layout against a real QS36SRC DSPF36 member | Planned | Not started | Blocked: needs a sample member from the user |
| DSP-06 | IACNVDSPF | Subfile candidates: detect repeated continuous rows of the same D specifications and report them (status R, output unchanged); subfile DDS (`SFL`, `SFLCTL`) only once a real example shows how the program was changed | Planned | Not started | Blocked: waiting for a DSPF36 member that was converted to a subfile, from the user |
| FREE-01 | IACNVFREE | RPG to fully free format, based on the S/36-compatible RPG II guide (SC09-1818). Umbrella for FREE-03 to FREE-12; decisions and evidence in `docs/RPG-MAPPING.md` | In progress | Not tested | Umbrella: status follows FREE-03 to FREE-10 |
| FREE-02 | IACNVFREE | Evaluate CVTRPGSRC as stage 1 | Done | N/A | Answered from the manual: CVTRPGSRC does not convert RPG36 or RPT36, SC09-2507 Table 125; no stage 1 for RPG36 |
| FREE-03 | IACNVFREE | Command, driver, report; H and F specifications to `ctl-opt` and `dcl-f` (E specifications moved to FREE-07) | Written | Not tested | Needs a compile and test; `samples/FREEHF.rpg36` |
| FREE-04 | IACNVFREE | I specifications to D statements (data structure: file record layouts and `DS` lines) | Written | Not tested | `samples/FREEIN.rpg36`; record-identifying indicators, record codes and the cycle entries are R |
| FREE-05 | IACNVFREE | C specifications to free-form calculations, on JSON rule tables loaded into Db2 (`rules/`, `docs/RPG-MAPPING.md`) | Written | Not tested | `samples/FREEC.rpg36`; `rules/IACNVRULES.sql` needs JSON_TABLE; `TAG`, `GOTO`, `CABxx` reported R; file operations and MOVE wait for FREE-08 and the E specifications |
| FREE-06 | IACNVFREE | O specifications to an externally described printer file (DDS in a second member) and `WRITE`/`EXCEPT` | In progress | Not started | Design decided 2026-10-25: generate printer DDS. Picked up 2026-10-25; do not start it in parallel. |
| FREE-07 | IACNVFREE | E specifications (arrays and tables) to `dcl-s` with `dim`, `perrcd`, `ctdata`, `alt`, `ascend`/`descend`; the `**` data sections to `**CTDATA` | Written | Not tested | `samples/FREEE.rpg36`; needs a compile and test; arrays loaded from a file, record address files and packed or binary data are R; tables are A (the `LOKUP` meaning of a table name is not converted); the C specifications on arrays (`LOKUP`, `MOVEA`, `XFOOT`, `SORTA`) are still R |
| FREE-08 | IACNVFREE | File operations in the C specifications (`CHAIN`, `READ`, `READE`, `READP`, `REDPE`, `SETLL`, `SETGT`, `WRITE`, `UPDAT`, `DELET`, `OPEN`, `CLOSE`, `FEOD`, `UNLCK`, `KLIST`/`KFLD`) on the `FILE_REC` data structures from FREE-04 | Written | Not tested | `samples/FREEFIL.rpg36`, `samples/FREEFIL3.rpg38`; needs a compile and test; `MOVE`/`MOVEL` are in (`samples/FREEMOV.rpg36`); `LOKUP`/`MOVEA` are still R; record format names in factor 2, `EXCPT` (FREE-06) and WORKSTN operations are R; `rules/IACNVRULES.sql` must be run again |
| FREE-09 | IACNVFREE | RPG III (`RPG38`, `RPG`): dialect column on `IACNVOPC`, column map `IACNVLAY`, F (external files, `UC`), I (`inz`), structured operations (`SELEC`, `WHxx`, `ANDxx`, `ORxx`, `ENDyy`, `ITER`, `LEAVE`), `CLEAR`, `RESET` | Written | Not tested | `samples/FREE3.rpg38`; `SQLRPG` accepted (its embedded SQL is FREE-11); string operations, `CABxx` and file operations reported R |
| FREE-10 | IACNVFREE | RPG IV fixed form (`RPGLE`, `SQLRPGLE`): H, F, D, I, C, O, P specifications read through `IACNVLAY`; extended factor 2 and the free-form syntax lines of SC09-2508 as templates | In progress | Not tested | Part 1 (H, F, D, P, directives, /FREE; module `IAfreeFx4`) and part 2a (C specifications: extended factor 2, structured ops, arithmetic, file ops without indicators) written, not compiled. Part 2b (resulting indicators of file operations, arithmetic and COMP; ANDxx/ORxx) written. Conditioning indicators on simple operations written. MOVE/MOVEL between declared fields written. String operations CAT, SCAN, CHECK, CHEKR, SUBST written. Open: other MOVE type pairs, MOVEA, XLATE, CALL/PARM, I and O specs. 7.3 manuals are in `docs/ref`. Picked up 2026-10-25; do not start it in parallel. |
| FREE-11 | IACNVFREE | Embedded SQL of `SQLRPG` (`C/EXEC SQL`, `C+`, `C/END-EXEC`) to free-form `exec sql ...;` | Written | Not tested | `samples/FREESQL.sqlrpg`; needs a compile and test; `WHENEVER ... GOTO` is A (TAG not converted); SQL in a `/COPY` member is not possible in RPG/400 |
| FREE-12 | IACNVFREE | RPG III string operations `CAT`, `SCAN`, `SUBST`, `CHECK`, `CHEKR` to `+`, `%scan`, `%subst`, `%check`, `%checkr` (`XLATE` stays R) | Written | Not tested | `samples/FREESTR.rpg38`; needs a compile and test; decision: no `P` is converted with the padded form and marked A; error indicator R; `rules/IACNVRULES.sql` must be run again (new rows and BIFs) |

## Notes

- OCL-01 to OCL-07 and OCL-09 to OCL-11 add to `docs/OCL-MAPPING.md`; DSP-01 to DSP-06 add to
  `docs/DSPF-MAPPING.md`.
- FREE-01 to FREE-12 add to `docs/RPG-MAPPING.md`.
- IACNVFREE reuses the shared parameter set and the IAcnvSrv service program.
- Anything that cannot be converted should be reported for review, not
  dropped silently.

## Notes for parallel sessions (IACNVFREE dialects, 2026-10-25)

- Source types for IACNVFREE: `RPG36` (RPG II, dialect 2), `RPG38`, `RPG` and
  `SQLRPG` (RPG III, dialect 3), `RPGLE` and `SQLRPGLE` (RPG IV fixed, dialect 4,
  not converted yet: FREE-10). `RPG3` and `RPG4` are not types. No `CVTRPGSRC`
  stage 1 for any of them: RPG III is converted directly.
- The dialect is chosen in `IAfreeCvt` (`g_dialect`) and given to `RulLoad`. Rule
  rows have a `dialects` value in `rules/opcodes.json` (`2`, `3`, `23`, `4`);
  column positions come from `rules/layouts.json` (`IACNVLAY`) through
  `RulLayout`. New C-spec code must read fields with `Fld(line:'NAME')` in
  `IAfreeCalc`, never by fixed column. H, F, I, E, L and O are still read by
  fixed columns in `IAfreeCvt`; moving them onto `IACNVLAY` is part of FREE-10.
- After changing a JSON file in `rules/`, re-run `rules/IACNVRULES.sql`.
- Comments in the converted source use `RulDialectLabel()` (`// RPG III: ...`).
- Open decisions and gaps: `SQLRPG` embedded SQL is converted (FREE-11, written in
  `CalcSqlLine` of `IAfreeCalc`, needs a compile and test); string
  operations `CAT`, `SCAN`, `SUBST`, `CHECK`, `CHEKR` are converted (FREE-12, no `P`
  gives the padded form with status A); `XLATE` is reported R; file operations, `KLIST`/`KFLD` and `OPEN`/`CLOSE` wait for FREE-08;
  RPG III I specifications of externally described files (renames) are
  reported R.
- Hot spots for merge conflicts: `IAfreeCalc.sqlrpgle` (`CalcLine`, dispatch in
  `CalcLine`, `ConvertEnd`), `IAfreeCvt.sqlrpgle` (`ConvertFile`, `ConvertInput`),
  `rules/opcodes.json`, `docs/RPG-MAPPING.md` (sections "RPG III" and "Rule
  tables"). Pull and rebase before editing them.
- Waiting on the user: compile and test spools for `FREEC.rpg36` (RPG36) and
  `FREE3.rpg38` (RPG38); the JSON_TABLE level on V7R3; real RPG II, RPG III
  and RPG IV source members.
- Reference text copies are in `docs/ref/` (index in `docs/ref/README.md`):
  SC09-1818 (RPG II), SC09-1817 and SC09-1816 (RPG III), SC09-2508 and
  SC09-2507 for IBM i 7.3 (RPG IV).

