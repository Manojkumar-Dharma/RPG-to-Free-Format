# Assumption (A) items of IACNVFREE

A means the line was converted, but the result depends on something the converter
cannot check. The R list is in `REVIEW-ITEMS.md`. Audit of 2026-10-27.

## A reported by the rules (`rules/opcodes.json`, 17 operations)

| Operation | Assumption | Audit |
|---|---|---|
| `CALL` | prototype before the first calculation, `callp`, `PARM` copied with `=` | keep A: the program name and parameter types are guessed |
| `EXCPT` | printer file DDS made from the O specifications is correct | keep A until the DDS is tested (FREE-06) |
| `MVR` | whole numbers only, `%rem` of the `DIV` operands | keep A; decimals stay R |
| `RETRN` | `RETURN`; halt and `LR` checks done by the runtime | keep A |
| `SORTA`, `XFOOT` | array comes from an E specification | could be C when the array is known; today A always |
| `SQRT` | decimals of the result | keep A |
| `TESTZ` (2, 3), `TESTN` (3) | zone/digit test with `%bitand` / `%check` | keep A: EBCDIC assumed |
| `TIME` | 6-digit result only | could be C for 6 digits and R otherwise |
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
| `RT` return indicator (FREE-49) | `CycOpen` in `IAfreeCalc` | new: A; `if *inrt; *inrt = *off; return;` at the top of the cycle, after the output of step 1 and the LR test (as steps 4, 9 and 11 of the cycle in SC09-1817); the total calculations of that cycle are not run and LR stays off; RT also conditions output records (FREE-53) |
| H, D, T output records of the cycle skeleton (FREE-37) | `OutFinish`, `CycOutput` | new: written at step 1 and in `IA_TOTALS`; the DDS is not tested |
| RPG IV program described printer file, exception records and `EXCEPT` (FREE-42) | `Norm4` in `IAfreeOut`, `ExceptStmt` in `IAfreeFx4` | new: A for the file (declared externally described); the DDS is not tested; the field types come from the D specifications |
| Edited output fields: width of the edit codes, `PAGNBR`, `DATE` (FREE-38) | `IAfreeOut` | new: the DDS positions come from the manual's tables, not from a run |
| WORKSTN file and record formats of a display file (FREE-43) | `ConvertDisplayFile`, `ConvertFileOp` | new: the DDS is not read, a record format is taken as a format of the one WORKSTN file |
| Program described WORKSTN file (FREE-46) | `ConvertProgDisplayFile` in `IAfreeCvt`, `ConvertF` and `ConvertI` in `IAfreeFx4` | new: A; the record is the data structure of the I specifications, as for a DISK file; the DDS is not read |
| RPG IV exception records of a program described DISK or WORKSTN file (FREE-47) | `ConvertF` and `ExceptStmt` in `IAfreeFx4`, `CvtSetFileOutput` in `IAfreeCvt` | new: A; `NAME_OUT` is declared right after the F specification of an output file, even when no `EXCEPT` writes it |
| WORKSTN file and record formats of a display file in RPG IV (FREE-45) | `ConvertF`, `ResultInds`, `IsDisplayFormat` | new: as FREE-43; a name that is not a declared file is taken as a record format when the source has a WORKSTN file |
| `GOTO`, `CABxx`, `TAG` patterns in RPG IV (FREE-44) | `ConvertJumpC` | new: as FREE-35 |

## Proposed changes

1. `SORTA` and `XFOOT`: report C when the array is defined in the member.
2. `TIME`: C for a 6-digit result field, R otherwise.
3. Group the A reasons under one reason text each so a report counts them by cause.

## R list audit (REVIEW-ITEMS.md)

- Done or by design, no work: RV-15, RV-34, RV-35.
- Written, waiting for a compile and test: RV-01 to RV-11, RV-13, RV-14 (RPG II/III), RV-30, RV-32, RV-36, RV-37 (WHENEVER GOTO, 2026-10-28, option decided by the owner: explicit SQLCODE tests), RV-50 to RV-55, RV-57, RV-58, RV-59.
- Decided 2026-10-27: RV-20/21 (cycle skeleton, FREE-36 first increment), FREE-06 second member for the printer DDS, RV-12/31 (WORKSTN through IACNVDSPF display files, after the cycle).
- Needs a decision: none open.
- Needs a sample member: RV-33, DSP-05/06. Hand-written samples exist (`FREEALT.rpg38`, `ORDENTRY.dspf36`, `ORDLIST.dspf36`, `PROMPTS.ocl`, `FSIZEDAT.ocl`), made from the IBM manuals and not from a real system.
- Follow-ups: RV-56, RV-61 to RV-63 (output). RV-14 for RPG IV and RV-37 (SQL `WHENEVER GOTO`) are written (FREE-44, FREE-48).
- Stale entries corrected today: RV-55 and the "Order of work" list.
