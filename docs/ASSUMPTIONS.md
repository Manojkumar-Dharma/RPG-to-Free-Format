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
| H, D, T output records of the cycle skeleton (FREE-37) | `OutFinish`, `CycOutput` | new: written at step 1 and in `IA_TOTALS`; the DDS is not tested |
| Edited output fields: width of the edit codes, `PAGNBR`, `DATE` (FREE-38) | `IAfreeOut` | new: the DDS positions come from the manual's tables, not from a run |

## Proposed changes

1. `SORTA` and `XFOOT`: report C when the array is defined in the member.
2. `TIME`: C for a 6-digit result field, R otherwise.
3. Group the A reasons under one reason text each so a report counts them by cause.

## R list audit (REVIEW-ITEMS.md)

- Done or by design, no work: RV-15, RV-34, RV-35.
- Written, waiting for a compile and test: RV-01 to RV-11, RV-13, RV-14 (RPG II/III), RV-30, RV-32, RV-36, RV-50 to RV-55, RV-57, RV-58, RV-59.
- Decided 2026-10-27: RV-20/21 (cycle skeleton, FREE-36 first increment), FREE-06 second member for the printer DDS, RV-12/31 (WORKSTN through IACNVDSPF display files, after the cycle).
- Needs a decision: none open.
- Needs a sample member: RV-33, DSP-05/06.
- Follow-ups: RV-14 for RPG IV, RV-37 (SQL `WHENEVER GOTO`), RV-56, RV-61 to RV-63 (output).
- Stale entries corrected today: RV-55 and the "Order of work" list.
