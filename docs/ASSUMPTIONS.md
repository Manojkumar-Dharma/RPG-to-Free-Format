# Assumption (A) items of IACNVFREE

A means the line was converted, but the result depends on something the converter
cannot check. The R list is in `REVIEW-ITEMS.md`. Audit of 2026-10-27.

## A reported by the rules (`rules/opcodes.json`, 21 operations)

Since FREE-56 the table also shows A for `GOTO`, `TAG`, `CAB` (patterns written, the rest R, see
`ConvertJump`) and `EXFMT`, `READC` (C with a WORKSTN file in the source, R without one; the code
decides). `TIME` is C in the table. These rows describe the operation; the report line carries the
status the code gives.

| Operation | Assumption | Audit |
|---|---|---|
| `CALL` | prototype before the first calculation, `callp`, `PARM` copied with `=` | keep A: the program name and parameter types are guessed |
| `EXCPT` | printer file DDS made from the O specifications is correct | keep A until the DDS is tested (FREE-06) |
| `MVR` | whole numbers only, `%rem` of the `DIV` operands | keep A; decimals stay R |
| `RETRN` | `RETURN`; halt and `LR` checks done by the runtime | keep A |
| `SORTA`, `XFOOT` | array comes from an E specification | done (FREE-56): C when the array is defined in the member, A when it is not |
| `SQRT` | decimals of the result | keep A |
| `TESTZ` (2, 3), `TESTN` (3) | zone/digit test with `%bitand` / `%check` | keep A: EBCDIC assumed |
| `TIME` | 6-digit result only | done (FREE-56): C for a result of 6 digits and 0 decimals defined on the line, R otherwise (as before) |
| `CAT`, `SUBST`, `XLATE` (3) | without `P` the rest of the result keeps its old value in RPG III; free-form pads | keep A: the real difference |
| `CHECK`, `CHEKR`, `SCAN` (3) | start beyond the string: error in RPG III, 0 in free-form | keep A |
| `OCUR` (3) | error indicator (occurrence out of range) | keep A |

## A reported by the converter code

| Cause | Where | Audit |
|---|---|---|
| RPG cycle not emulated (first converted detail calculation, once per member) | `CYCLE_NOTE` | keep; turns every member without a cycle into A on one line |
| Half adjust differs | `HALF_ADJUST_NOTE` | keep |
| RPG cycle skeleton for one primary file (FREE-36): read, control break, `IA_TOTALS`, last cycle | `CycOpen` in `IAfreeCalc` | new: A once per member; the output of the cycle (O specifications, FREE-06) and secondary or matching files are not part of it |
| `GOTO`, `CABxx`, `TAG` patterns (FREE-35) | `ConvertJump` | new: skip forward, end of subroutine or program, loop back, leave |
| Renamed field is a copy (RV-30) | `IAfreeCvt` | text was out of date (said the copy is not written back); corrected: it is copied back before UPDAT and WRITE |
| Record format DS for READ and CHAIN | `IAfreeCvt` | keep |
| `/COPY`, `/INCLUDE`: member must be converted too; other directives dropped | FREE-29 | keep |
| Compile-time data kept as is (`**CTDATA`) | `IAfreeCvt` | keep: check the name |
| `EXTFMT` length includes the sign | E specification | keep |
| Printer file DDS comments, or the DDS member with `DDSTGT` (FREE-06) | `IAfreeCvt` | keep until tested |
| Record types of the primary file (FREE-49): record identifying indicators and codes | `CycleTypeParse` in `IAfreeCvt`, `CycTypeTest` and `CycKeepControl` in `IAfreeCalc` | new: A once for the record layout; a field of another record type holds the bytes of the record, not its old value; sequence checking (columns 15-16) and a record that matches no type (the RPG halt) are not emulated; a control field is compared with `IA_P_name`, the value of the last record of its type |
| Heading, detail and total records of a DISK file in the cycle skeleton (FREE-54) | `CycOutput` in `IAfreeCalc`, `DiskBuild` in `IAfreeOut` | as the exception records of DISK files (FREE-39, FREE-47): A for the record (`%subst` at the end positions, zoned digits with `%EDITC` X); a field defined by a calculation after the skeleton opens is not known for a heading or detail record, so that record stays R |
| The cycle skeleton for RPG IV (FREE-60) | `CalcCycleBefore` in `IAfreeCalc`, `ConvertF`, `ConvertI` and `ConvertC` in `IAfreeFx4` | as the skeleton of FREE-36 (A once per member); the loop opens at the first calculation that is not a KLIST, KFLD, PLIST, PARM or DEFINE line, so their declarations stay before it; a level on a group operation (IF, DOW, DOU, DO, FOR) stays R |
| Multiple device WORKSTN files (FREE-71): `ACQ`, `REL`, `NEXT`, `POST` and the continuation options `ID`, `SAVDS`, `IND`, `NUM`, `SLN`, `PASS` | `ConvertFileOp` in `IAfreeCalc`, `ConvertC` in `IAfreeFx4`, `ContinuationKeywords` in `IAfreeCvt` | A for each operation (check the device and the file); `NUM n` above 1 gives `maxdev(*file)` (the limit n is lost); the DEVID field must be a character field of length 10 defined in the program |
| SPECIAL files of RPG III (FREE-72) | `ConvertFileLine` and `ContinuationKeywords` in `IAfreeCvt` | A for the declaration: the routine of columns 54-59 is called by the compiler with the option, status, error and area parameters as with PGMNAME; the file is handled as a program described DISK file by the file operations and the O specifications |
| Field indicators of an I specification (FREE-74) | `FieldIndReg` in `IAfreeCvt`, `ConvertFileOp` and `CycOpen` in `IAfreeCalc` | A for each input operation: the indicators are set when a record was read; a numeric field with blanks gives a decimal data error at the comparison, RPG set the indicator for it |
| `RT` return indicator (FREE-49) | `CycOpen` in `IAfreeCalc` | new: A; `if *inrt; *inrt = *off; return;` at the top of the cycle, after the output of step 1 and the LR test (as steps 4, 9 and 11 of the cycle in SC09-1817); the total calculations of that cycle are not run and LR stays off; RT also conditions output records (FREE-53) |
| The cycle skeleton with secondary files, match fields and `MR` (FREE-55, RPG II and III) | `CycDeclareMulti`, `CycKeyMulti`, `CycReadMulti`, `CycAssignMulti`, `CycMatchRecord` in `IAfreeCalc` | new: A once per member; written from the manual (SC09-1818 chapter 12, Table 6 and Figures 112-115), not from a run; the sequence of the match fields is not checked (the RPG9032 halt is not converted, a note in the report); the keys are built with `%editc(field:'X')` for numeric fields; descending sequence, RPG IV and a secondary file that is not a program described DISK input file stay R |
| The record identifying indicator of the primary file in RPG IV (FREE-62) | `CvtAddType` in `IAfreeCvt`, `IAfreeFx4` | as FREE-49: the indicator is set after the read; other record identifying indicators and the record identification codes stay R (codes: FREE-69) |
| The cycle without a primary file (FREE-63) | `CycleNoPrimary`, `g_cycNoPrim` in `IAfreeCalc` | new: A once per member; the program loops without a read until it sets LR on (a program that does not loops forever, as in RPG); total time is bypassed on the first cycle; this is my reading of steps 7, 8 and 18 of the cycle in the manual: to be confirmed |
| Data formats L and R on a DISK record of RPG III (FREE-65) | `IAfreeOut` | new: A with its own cause; written as a separate sign (`+` or `-`) before or after the digits and the end position counts the sign; the plus sign character and the end position are assumptions; a printer file and RPG II stay R |
| O specifications of an externally described file (FREE-67) | `ExtBuild`, `ExternalFileInfo` in `IAfreeOut` | new: A; the DDS is not read, so `write FMT` writes all fields of the format (RPG writes only the fields named in the O specification); the file of a format is the only externally described file of the source or comes from ADD or DEL; a field with an output indicator and several externally described files without ADD or DEL stay R |
| Record types of the primary file in RPG IV (FREE-69) | `ConvertITyped4` in `IAfreeFx4`, `CvtAddTypeCond` in `IAfreeCvt` | as FREE-49: A for the record layout and the type tests; the columns 14-16 of an AND or OR line are assumed; Z and D codes, look-ahead and secondary files stay R |
| A level indicator on a field line of a printer record (FREE-73) | `FieldLevels`, `LevelCopy`, `LevelNote` in `IAfreeOut` | new: A with its own cause; the level indicator is copied to a free numbered indicator (from 99 down, found by scanning the source text) before the write, and the DDS field is conditioned by that indicator |
| H, D, T output records of the cycle skeleton (FREE-37) | `OutFinish`, `CycOutput` | new: written at step 1 and in `IA_TOTALS`; the DDS is not tested |
| RPG IV program described printer file, exception records and `EXCEPT` (FREE-42) | `Norm4` in `IAfreeOut`, `ExceptStmt` in `IAfreeFx4` | new: A for the file (declared externally described); the DDS is not tested; the field types come from the D specifications |
| Edited output fields: width of the edit codes, `PAGNBR`, `DATE` (FREE-38) | `IAfreeOut` | new: the DDS positions come from the manual's tables, not from a run |
| WORKSTN file and record formats of a display file (FREE-43) | `ConvertDisplayFile`, `ConvertFileOp` | new: the DDS is not read, a record format is taken as a format of the one WORKSTN file |
| Program described WORKSTN file (FREE-46) | `ConvertProgDisplayFile` in `IAfreeCvt`, `ConvertF` and `ConvertI` in `IAfreeFx4` | new: A; the record is the data structure of the I specifications, as for a DISK file; the DDS is not read |
| RPG IV exception records of a program described DISK or WORKSTN file (FREE-47) | `ConvertF` and `ExceptStmt` in `IAfreeFx4`, `CvtSetFileOutput` in `IAfreeCvt` | new: A; `NAME_OUT` is declared right after the F specification of an output file, even when no `EXCEPT` writes it |
| WORKSTN file and record formats of a display file in RPG IV (FREE-45) | `ConvertF`, `ResultInds`, `IsDisplayFormat` | new: as FREE-43; a name that is not a declared file is taken as a record format when the source has a WORKSTN file |
| `GOTO`, `CABxx`, `TAG` patterns in RPG IV (FREE-44) | `ConvertJumpC` | new: as FREE-35 |

## Proposed changes

All three were written on 2026-10-30 (FREE-56, not compiled or tested):

1. `SORTA` and `XFOOT`: reported C when the array is defined in the member.
2. `TIME`: C for a 6-digit result field, R otherwise.
3. The A reasons of IACNVFREE have one fixed text per cause (no file, label or record names: the
   source text on the report line shows them) and `IAcnvRpt` prints "Assumptions by cause" with a
   count for each, before the totals. The causes of one line are joined by ` | ` (`AddReason`,
   `AppendText`) and counted one by one; a cause can hold `; ` itself. Only IACNVFREE is counted:
   the reasons of IAOCLTOCLE and IACNVDSPF still hold names. Left as they are in IACNVFREE: some
   notes of `IAfreeCvt` (`INFDS`, `RECNO` and relative record number fields, `UC`) hold a field
   name, and a line whose causes together pass 190 characters (a half-adjust note and the cycle
   note) is cut at the end, as before.

## R list audit (REVIEW-ITEMS.md)

- Done or by design, no work: RV-15, RV-34, RV-35, `1P` (RV-20, RV-60: valid on output records only, written with the skeleton).
- Written, waiting for a compile and test: RV-01 to RV-11, RV-13, RV-14 (RPG II/III), RV-30, RV-32, RV-36, RV-37 (WHENEVER GOTO, 2026-10-28, option decided by the owner: explicit SQLCODE tests), RV-50 to RV-55, RV-57, RV-58, RV-59.
- Decided 2026-10-27: RV-20/21 (cycle skeleton, FREE-36 first increment), FREE-06 second member for the printer DDS, RV-12/31 (WORKSTN through IACNVDSPF display files, after the cycle).
- Needs a decision: none open.
- Needs a sample member: RV-33, DSP-05. DSP-06 has a real example since 2026-10-30 (`STIPFM.dspf36`, `STIPFM.dspf`, `STIP01FM.dspf`). Hand-written samples exist (`FREEALT.rpg38`, `ORDENTRY.dspf36`, `ORDLIST.dspf36`, `PROMPTS.ocl`, `FSIZEDAT.ocl`), made from the IBM manuals and not from a real system.
- Follow-ups: RV-56, RV-61 to RV-63 (output). RV-14 for RPG IV and RV-37 (SQL `WHENEVER GOTO`) are written (FREE-44, FREE-48).
- Stale entries corrected today: RV-55 and the "Order of work" list.
