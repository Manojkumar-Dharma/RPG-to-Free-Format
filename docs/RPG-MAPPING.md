# RPG II to fully free-form RPG (IACNVFREE)

Status: decisions and evidence for FREE-01 to FREE-08. FREE-03 (control and file description specifications), FREE-04 (input specifications) and FREE-05 (calculation specifications, with the rule tables) are written and not compiled or tested yet; the other specifications are kept as comments.
The source is System/36-compatible RPG II (member type RPG36), or RPG III (RPG38, RPG; section "RPG III" below); the target is
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
- Edit codes and the O specifications: mapping not written yet (FREE-06). Arrays and
  tables are in "Arrays and tables (FREE-07)" below.

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

## Control specification (H) to `ctl-opt`

Source: SC09-1818 chapter 18. Target: `ctl-opt` keywords (SC09-2508). Only the first H specification is converted; a second one is kept as a comment and reported R. Columns that the guide says have no relevance on the AS/400 system (7-14 size entries, 10-12, 16-17, 22-25, 27-36, 38-40, 42, 44, 46-56, 58-74) are ignored.

| Column | Entry | Result | Status |
|---|---|---|---|
| 15 | `1` (debug) | `debug(*dump)` | A: the `DEBUG` operation is a C specification item |
| 18 | a currency symbol | `cursym('c')` | C. `0 * , & . - C R` are R |
| 19-21 | date format `M` `D` `Y`, date edit, inverted print | `datedit(*MDY or *DMY or *YMD` + separator`)`. Blank format is `*DMY` when column 21 is `D`, `I` or `J`, else `*MDY`. A blank separator is `.` when the format is `Y` or blank and column 21 is `I` or `J`, else `/`; `&` means a blank separator. | C. The Reference says `DATEDIT` also sets the `UDATE` format, as columns 19-21 do. |
| 21 | `I` or `J` | `decedit(',')` or `decedit('0,')` | C |
| 26 | `S` (alternate collating sequence) | comment | R: needs its table |
| 37 | `B` (inquiry) | comment | R: System/36 environment function. Blank and `I` are ignored |
| 41 | `1` (1P forms position) | `formsalign(*yes)` | C |
| 43 | `F` (file translation) | comment | R: needs its table |
| 45 | `1` (nonprint characters) | none | A: no equivalent |
| 57 | `1` (transparent literals) | comment | R: double-byte data |
| 75-80 | program name | none | A: the name is set on the compile command |

## File description specification (F) to `dcl-f`

Source: SC09-1818 chapter 19. Target: SC09-2508 "Equivalent Free-form Coding for Fixed-Form File Entries" (Table 105) and Table 106 (`USAGE`). DISK and PRINTER files only; a file with continuation records is kept as comments whole, so no option is lost silently.

| Entry | Result | Status |
|---|---|---|
| DISK, type `I`, designation `F` | `dcl-f NAME disk(len) usage(*input)` | C |
| DISK, type `U`, designation `F` | `usage(*update:*delete)` | A: `*DELETE` is explicit in free-form (Table 106) |
| DISK, type `O`, blank designation | `usage(*output)` | C |
| File addition `A` (column 66) on `I` or `U` | `*input:*output` or `*update:*delete:*output` | same as above. `O` with `A` is R (not supported) |
| Designation `C` (chained) or `D` (demand) | handled as full-procedural | A: use it only with `CHAIN` or `READ` |
| Indexed (column 32 `I`) with address type `A` | `keyed(*char:keylen) keyloc(start)` | A: a zoned-decimal key is declared as a character key |
| Indexed with address type `P`, or blank | comment | R: packed keys are not supported; a blank address type processes by arrival order, free-form `KEYED` reads in key order |
| Record length (24-27) | the number in `disk(len)` | required |
| Designation `P` or `S` | comment | R: the RPG cycle is not supported in free-form |
| Designation `R` or `T`, organization `T`, address type `I` | comment | R: not supported in free-form |
| Mode `L`, sequence checking (18), `EXTK` key | comment | R: not supported in free-form |
| Mode `R` or designation `C` on an output file (direct load) | comment | R |
| File condition `U1` to `U8` | `extind(*INU1)` ... | C |
| End of file `E` (17) on a non-cycle file | ignored | A |
| PRINTER, type `O` | `dcl-f NAME printer` with `oflind(*INOA)` for `OA` to `OG`, `OV` | A: declared externally described, the printer file comes from the O specifications (FREE-06). Column 39 `L` also A; `E` is R |
| WORKSTN, SPECIAL, CONSOLE, KEYBORD, CRT, BSCA | comment | R: WORKSTN needs the display file and format I/O (later item) |
| Continuation records (`K` in column 53: RECNO, SUBR exit, NUM, FMTS, INFSR) | the whole file as comments | R |

## Input specification (I) to data structures

Source: SC09-1818 chapter 23. Target: free-form `DCL-DS` and subfields (SC09-2508; `DCL-SUBF` is optional but written, `POS`, `LEN`, `BINDEC`, `*N`). Decision: an I specification becomes a data structure (RPG II has no externally described files, so the data structures are internal).

An input block is a record line (a file name, or `DS` in columns 19-20) followed by its field lines. A field line has columns 7-42 blank and the field entries in columns 43-70: 43 packed or binary, 44-47 from, 48-51 to, 52 decimal positions, 53-58 name.

| Source | Result | Status |
|---|---|---|
| File record line with no record identification codes, one record type, no indicator, and a file declared by a converted DISK input or update file description | `dcl-ds FILE_REC len(record length);` ... `end-ds;` | A: free-form `READ` and `CHAIN` of a program-described file name this data structure; the C specification converter (FREE-05) must use it |
| `DS` line with a name, or without one | `dcl-ds NAME;` or `dcl-ds *n;` ... `end-ds;` | C |
| Field, blank in column 43 and 52 | `dcl-subf NAME char(len) pos(from);` | C. Longer than 256 is R |
| Field with decimal positions | `zoned(len:dec)` | C. Longer than 15 digits is R |
| Field with `P` (packed) | `packed(2*bytes-1:dec)` | C. Longer than 8 bytes is R |
| Field with `B` (binary) | `bindec(4:dec)` for 2 bytes, `bindec(9:dec)` for 4 bytes | C. Other lengths are R |
| Numeric field with no decimal positions entry | comment | R |
| Name not valid, a special word (`PAGE`, `PAGE1`-`PAGE7`, `UDATE`, `UDAY`, `UMONTH`, `UYEAR`), or already defined (the same field in two record types or files needs one definition) | comment inside the data structure | R |
| Field ends past the record length | comment | R |
| Control level (59-60), matching fields (61-62), field record relation (63-64), field indicators (65-70) | comment | R: the cycle and indicators are not supported in free-form |
| Record identification codes (21-41), AND/OR lines, a second record type for a file | whole block as comments | R: more than one record type is not supported |
| Record-identifying indicator (19-20), sequence checking (15-16 numeric), number/option entries (17-18) | whole block as comments | R: free-form I/O does not set the indicator or check the sequence |
| Look-ahead (`**` in 19-20) | whole block as comments | R |
| `DS` with option `U` (display station local data area), or a name already used | whole block as comments | R |
| File not declared by a converted file description, PRINTER file, or output file | whole block as comments | R |
| A block in which no field converts | whole block as comments | R |

A field that cannot be converted is kept as a comment inside the data structure, so the rest of it still compiles; the field is reported R with its own reason.

### Expected results for `samples/FREEIN.rpg36`

The F specifications at the start of the sample set up the files; the blocks are listed with their results.

| Line | Source (from column 6) | Result | Status | Reason or note |
|---|---|---|---|---|
| 12 | `ICUSTMAS AA`<br>`I                                        1   60CUSTNO`<br>`I                                        7  26 NAME`<br>`I                                    P  27  312BAL`<br>`I                                    B  32  330CNT`<br>`I                                    B  34  370BIGCNT` | `dcl-ds CUSTMAS_REC len(80);`<br>`  dcl-subf CUSTNO zoned(6:0) pos(1);`<br>`  dcl-subf NAME char(20) pos(7);`<br>`// packed (5 bytes), binary (2 and 4 bytes)`<br>`  dcl-subf BAL packed(9:2) pos(27);`<br>`  dcl-subf CNT bindec(4:0) pos(32);`<br>`  dcl-subf BIGCNT bindec(9:0) pos(34);`<br>`end-ds;` | A | record layout of file CUSTMAS declared as data structure CUSTMAS_REC: READ and CHAIN of the file must name it (FREE-05) |
| 19 | `IORDERS  BC`<br>`I                                        1  10 ORDNO`<br>`I                                       11  160CUSTNO`<br>`I                                       17  20xQTY`<br>`I                                      130 140 TOOFAR`<br>`I                                       21  30 PAGE`<br>`I                                       31  40 LV    L1`<br>`I                                       41  50 ORDDAT` | `dcl-ds ORDERS_REC len(120);`<br>`  dcl-subf ORDNO char(10) pos(1);`<br>`// RPG II: I                                       11  160CUSTNO`<br>`// RPG II: I                                       17  20xQTY`<br>`// RPG II: I                                      130 140 TOOFAR`<br>`// RPG II: I                                       21  30 PAGE`<br>`// RPG II: I                                       31  40 LV    L1`<br>`  dcl-subf ORDDAT char(10) pos(41);`<br>`end-ds;` | A | record layout of file ORDERS declared as data structure ORDERS_REC: READ and CHAIN of the file must name it (FREE-05); line 21: field CUSTNO is already defined at line 13; line 22: decimal positions (column 52) are not valid; line 23: field ends past the record length 120; line 24: field name PAGE is a special word; line 25: control level, matching fields, field record relation or field indicators (columns 59-70) are not supported in free-form |
| 27 | `IREPORT1 AA`<br>`I                                        1  10 PRT1` | `// RPG II: IREPORT1 AA`<br>`// RPG II: I                                        1  10 PRT1` | R | file REPORT1 is not a DISK input or update file; line 28: part of the record layout above that is not converted |
| 29 | `ISALES   AA`<br>`I                                        1  10 SAL1` | `// RPG II: ISALES   AA`<br>`// RPG II: I                                        1  10 SAL1` | R | file SALES is not declared by a converted file description; line 30: part of the record layout above that is not converted |
| 31 | `INEWF    AA  01`<br>`I                                        1  10 NEW1` | `// RPG II: INEWF    AA  01`<br>`// RPG II: I                                        1  10 NEW1` | R | record-identifying indicator 01 is not set by free-form I/O; line 32: part of the record layout above that is not converted |
| 33 | `IMULTI   AA      1 C1`<br>`I                                        1  10 MUL1` | `// RPG II: IMULTI   AA      1 C1`<br>`// RPG II: I                                        1  10 MUL1` | R | record identification codes (more than one record type) are not supported in free-form; line 34: part of the record layout above that is not converted |
| 35 | `IMULTI   AB      1 C2`<br>`I                                        1  10 MUL2` | `// RPG II: IMULTI   AB      1 C2`<br>`// RPG II: I                                        1  10 MUL2` | R | record identification codes (more than one record type) are not supported in free-form; line 36: part of the record layout above that is not converted |
| 37 | `ILOOKF   AA`<br>`I                                        1  10 LOK1` | `dcl-ds LOOKF_REC len(80);`<br>`  dcl-subf LOK1 char(10) pos(1);`<br>`end-ds;` | A | record layout of file LOOKF declared as data structure LOOKF_REC: READ and CHAIN of the file must name it (FREE-05) |
| 39 | `I        AA  **`<br>`I                                       11  14 NXTLOK` | `// RPG II: I        AA  **`<br>`// RPG II: I                                       11  14 NXTLOK` | R | look-ahead fields are not supported in free-form; line 40: part of the record layout above that is not converted |
| 41 | `ISEQF    011`<br>`I                                        1  10 SEQ1` | `// RPG II: ISEQF    011`<br>`// RPG II: I                                        1  10 SEQ1` | R | sequence checking (columns 15-16) is not supported in free-form; line 42: part of the record layout above that is not converted |
| 43 | `INOFILE  AA`<br>`I                                        1  10 NOF1` | `// RPG II: INOFILE  AA`<br>`// RPG II: I                                        1  10 NOF1` | R | file NOFILE is not declared by a converted file description; line 44: part of the record layout above that is not converted |
| 45 | `ITWICE   AA`<br>`I                                        1  10 TWI1` | `dcl-ds TWICE_REC len(80);`<br>`  dcl-subf TWI1 char(10) pos(1);`<br>`end-ds;` | A | record layout of file TWICE declared as data structure TWICE_REC: READ and CHAIN of the file must name it (FREE-05) |
| 47 | `ITWICE   AB`<br>`I                                       11  20 TWI2` | `// RPG II: ITWICE   AB`<br>`// RPG II: I                                       11  20 TWI2` | R | file TWICE already has a record layout (more than one record type); line 48: part of the record layout above that is not converted |
| 50 | `IDTADS       DS`<br>`I                                        1   40YEAR`<br>`I                                        5   60MONTH`<br>`I                                        1   60YYMM` | `dcl-ds DTADS;`<br>`  dcl-subf YEAR zoned(4:0) pos(1);`<br>`  dcl-subf MONTH zoned(2:0) pos(5);`<br>`  dcl-subf YYMM zoned(6:0) pos(1);`<br>`end-ds;` | C |  |
| 54 | `I            DS`<br>`I                                        1  10 WORK1`<br>`I                                       11  20 WORK2` | `dcl-ds *n;`<br>`  dcl-subf WORK1 char(10) pos(1);`<br>`  dcl-subf WORK2 char(10) pos(11);`<br>`end-ds;` | C |  |
| 57 | `ILDAREA     UDS`<br>`I                                        1  50 LDA1` | `// RPG II: ILDAREA     UDS`<br>`// RPG II: I                                        1  50 LDA1` | R | data structure option U (display station local data area) is not converted; line 58: part of the record layout above that is not converted |
| 59 | `IDUPDS       DS`<br>`I                                        1  10 ORDNO`<br>`I                                       41  44 ORPHAN` | `dcl-ds DUPDS;`<br>`// RPG II: I                                        1  10 ORDNO`<br>`  dcl-subf ORPHAN char(4) pos(41);`<br>`end-ds;` | C | line 60: field ORDNO is already defined at line 20 |

## Other lines

| Source | Result | Status |
|---|---|---|
| Blank line | blank line | - |
| Comment (`*` in column 7) | `//` and the text of columns 8-80 | - (not reported) |
| `/EJECT`, `/TITLE`, `/SPACE` | kept (valid in free-form) | C |
| `/COPY`, `/INCLUDE` | kept; the member has to be converted too (FREE-29) | A |
| Other directives | comment | R |
| L, O specifications | `// RPG II:` and the line | R (FREE-06) |
| E specifications | see "Arrays and tables (FREE-07)" | C, A or R |
| I specifications | see "Input specification (I) to data structures" | C, A or R |
| C specifications | see "Calculation specifications (C)" | C, A or R |
| `**` record and the data after it | kept as is | R: arrays are not converted yet |

The output always starts with a `**FREE` line.

## Expected results for `samples/FREEHF.rpg36`

The reasons are worded slightly differently in the report; the statements and statuses are what matters. Comment lines and blank lines are not listed.

| Line | Source (from column 6) | Result | Status | Reason |
|---|---|---|---|---|
| 2 | `H        1  %D-I                   1                                 PAYRL1` | `ctl-opt debug(*dump) cursym('%') datedit(*DMY-) decedit(',') formsalign(*yes);` | A | column 15: DEBUG operation itself is a C specification item; program name PAYRL1 is set on the compile command |
| 3 | `H        1` | `// RPG II: H        1` | R | more than one control specification (only the first is converted) |
| 5 | `FCUSTMAS IF         80  6AI     1 DISK` | `dcl-f CUSTMAS disk(80) usage(*input) keyed(*char:6) keyloc(1);` | A | zoned-decimal key (column 31 A) declared as a character key |
| 6 | `FORDERS  UF        120 10AI     1 DISK` | `dcl-f ORDERS disk(120) usage(*update:*delete) keyed(*char:10) keyloc(1);` | A | zoned-decimal key (column 31 A) declared as a character key; *DELETE added: fixed-form update files can delete records |
| 7 | `FORDHIST O         200            DISK` | `dcl-f ORDHIST disk(200) usage(*output);` | C |  |
| 8 | `FCHAINF  IC         64R           DISK` | `dcl-f CHAINF disk(64) usage(*input);` | A | chained file declared as a full-procedural file: use it only with CHAIN |
| 9 | `FDEMAND1 IDE       100            DISK` | `dcl-f DEMAND1 disk(100) usage(*input);` | A | demand file declared as a full-procedural file: use it only with READ; end of file entry (column 17) ignored |
| 10 | `FLIMITS  IF         80L 6AI     1 DISK` | `// RPG II: FLIMITS  IF         80L 6AI     1 DISK` | R | limits processing (column 28 L) is not supported in free-form |
| 11 | `FNEWREC  IF         80            DISK                      A` | `dcl-f NEWREC disk(80) usage(*input:*output);` | C |  |
| 12 | `FCOND1   IF         80            DISK                           U1` | `dcl-f COND1 disk(80) usage(*input) extind(*INU1);` | C |  |
| 13 | `FREPORT1 O         132     OA     PRINTER` | `dcl-f REPORT1 printer oflind(*INOA);` | A | declared externally described: the printer file comes from the O specifications (FREE-06) |
| 14 | `FREPORT2 O         132           LPRINTER` | `dcl-f REPORT2 printer;` | A | line counter specification is converted with the O specifications (FREE-06); declared externally described: the printer file comes from the O specifications (FREE-06) |
| 15 | `FSALES   IP         80            DISK` | `// RPG II: FSALES   IP         80            DISK` | R | primary/secondary file (RPG cycle) is not supported in free-form |
| 16 | `FCRTSCR  CP       1920            WORKSTN` | `// RPG II: FCRTSCR  CP       1920            WORKSTN` | R | device WORKSTN is not converted yet (WORKSTN needs the display file and format I/O) |
| 17 | `FPACKKEY IF         80  6PI     1 DISK` | `// RPG II: FPACKKEY IF         80  6PI     1 DISK` | R | packed key (column 31 P) is not supported in free-form |
| 18 | `FINDXCON IF         80  6 I     1 DISK` | `// RPG II: FINDXCON IF         80  6 I     1 DISK` | R | indexed file processed consecutively or by relative record number: free-form KEYED reads in key order |
| 19 | `FSPEC1   IF         80            SPECIAL       SUBR01` | `// RPG II: FSPEC1   IF         80            SPECIAL       SUBR01` | R | device SPECIAL is not converted yet |
| 20 | `FRECNOF  UF         80            DISK` | `// RPG II: FRECNOF  UF         80            DISK` | R | continuation records (RECNO, SUBR exit, NUM, FMTS, INFSR) are not converted |
| 22 | ` /TITLE Customer update` | `/TITLE Customer update` | C |  |
| 23 | ` /EJECT` | `/EJECT` | C |  |
| 24 | ` /COPY QRPGSRC,MYCOPY` | `/COPY QRPGSRC,MYCOPY` | A | The member is copied into free-form source: convert it too |
| 25 | `E                    TAB1` | `// RPG II: E                    TAB1` | R | E (extension) specification not converted yet |
| 26 | `IORDERS      NS 01` | `// RPG II: IORDERS      NS 01` | R | I specification not converted yet (FREE-04) |
| 27 | `C                     ADD  1         TOTAL` | `TOTAL += 1;` | A | the first calculation also reports the cycle note (see the C section) |
| 28 | `OREPORT1  D` | `// RPG II: OREPORT1  D` | R | O specification not converted yet (FREE-06) |
| 29 | `mpile-time data` | `** compile-time data` | R | compile-time data kept as is; arrays not converted yet |
| 30 | `3` | `ABC123` | - | compile-time data, kept |

## Rule tables (rules/*.json, Db2 tables IACNVxxx)

What an operation code, an indicator or a special name becomes is data, not code. The JSON files in `rules/` are the source of truth; `rules/IACNVRULES.sql` creates the Db2 tables and loads them with `JSON_TABLE` (run it again after every change); IACNVFREE reads the tables once at the start (module IAfreeRul). A missing or empty table ends the run with message IAC0104.

| File | Table | Holds |
|---|---|---|
| `opcodes.json` | IACNVOPC | `dialects` (2 RPG II, 3 RPG III, 4 RPG IV fixed) and every operation code of SC09-1818 chapter 27 (RPG III and RPG IV rows follow the dialect work): kind, whether factor 1, factor 2 and the result field are required (`R`), optional (`O`) or blank (`-`), the test of each resulting indicator column, half adjust allowed, status (C, A, R), the free-form template (`{F1}`, `{F2}`, `{RES}`; a second one when factor 1 is blank), the built-in functions it needs, the reason when not converted, the source |
| `layouts.json` | IACNVLAY | Column map per dialect, specification type and field (`from`, `length`). The C specification of RPG II and RPG III (identical columns, SC09-1818 chapter 24 and SC09-1817 Table 30) is loaded; RPG IV fixed (SC09-2508) and the other specification types follow with the dialect work. The converter reads C fields through this table |
| `rpg36-comparisons.json` | IACNVCMP | xx of IFxx, DOWxx, DOUxx, CASxx and its operator |
| `rpg36-results.json` | IACNVRES | The test a resulting indicator stands for (`+`, `-`, `Z`, `ZB`, `HI`, `LO`, `EQ`, `NR`, `ER`, `EOF`, `BOF`) |
| `rpg36-indicators.json` | IACNVIND | All indicator names with their free-form name; `cycle` = `Y` (L1 to L9, MR) means the line is reported R |
| `rpg36-names.json` | IACNVNAM | Figurative constants and special names (`*BLANKS`, `UDATE`, `PAGE`) |
| `rpg36-bifs.json` | IACNVBIF | Built-in functions the templates use and the release that added each; a function newer than `TARGET_RELEASE` makes the line R |
| `rpg36-config.json` | IACNVCFG | Settings: `NUMERIC_TYPE`, `INDEX_TYPE`, `INDENT`, `TARGET_RELEASE` and the texts of the half-adjust and cycle notes |

The factor flags come from the table at the top of each operation in chapter 27 (the summary Table 20 prints some of them in shifted columns, so it is not used for them). The structure of the operation (IFxx and END groups, CASxx groups, AN and OR lines, declarations) is code in IAfreeCalc; everything that is only a pattern is in the tables. A new operation that has a template needs no program change.

## Calculation specifications (C) to statements (FREE-05)

Source: SC09-1818 chapter 24 (columns) and chapter 27 (operations). Written for programs **without the RPG cycle**: the calculations are written in the order of the source and run once. The first converted detail line is reported A with that reason; control levels, `MR`, total calculations (`L0` to `L9`, `LR` in columns 7-8) and the files that drive the cycle are R.

| Entry | Result | Status |
|---|---|---|
| Columns 9-17 (up to three indicators, `N` = not) | `if *IN01 and not *IN02;` around the statements, closed with `endif;` | C |
| Lines with `AN` and `OR` in columns 7-8 | one condition: AND lines join with `and`, an OR line starts a group, groups are joined with `or` in parentheses, the indicators of the operation line are ANDed to all | C |
| `Z-ADD`, `ADD`, `SUB`, `MULT`, `DIV` (`Z-SUB` as `-(x)`) | `r = f1 + f2;` or `r += f2;` when factor 1 is blank (the same for `-=`, `*=`, `/=`); `Z-ADD` is `r = f2;` | C |
| Half adjust `H` | `eval(h) r = ...;` | A: the S/36 algorithm differs from the AS/400 one (column 53 note in the Guide) |
| Resulting indicators `+`, `-`, `Z` | after the statement: `*IN10 = (r > 0);` `*IN11 = (r < 0);` `*IN12 = (r = 0);` | C |
| `COMP` | `*IN10 = (f1 > f2);` `*IN11 = (f1 < f2);` `*IN12 = (f1 = f2);` for the indicators given; at least one is required | C |
| `SETON`, `SETOF` | `*IN30 = *ON;` for each indicator in columns 54-59 | C |
| `IFxx` ... `ELSE` ... `END` | `if f1 op f2;` `else;` `endif;`. Conditioning indicators control the whole IF/ELSE group in S/36, so they give an outer `if cond;` with the group inside and two `endif;` | C |
| `DOWxx` / `DOUxx` ... `END` | `dow` / `dou f1 op f2;` `enddo;`. Conditioning indicators: R | C |
| `DO` ... `END` | `for idx = start to limit by incr;` `endfor;`. Start and limit default to 1; the increment is factor 2 of the END; without a result field the index `IADOn` is declared | C, A without a result field |
| `CASxx` ... `END` | `select;` `when f1 op f2;` `exsr name;` ... `other;` (CAS with a blank xx) `endsl;`. Conditioning or resulting indicators: R | C |
| `BEGSR`, `ENDSR`, `EXSR` | `begsr`, `endsr;`, `exsr` (`*PSSR` and `*INZSR` allowed). `ENDSR` with a return point (factor 2): R | C |
| `TIME` with a 6-digit result | `r = %dec(%time():*hms);` | A: a 12-digit result also holds the system date: R |
| `SQRT`, `XFOOT`, `SORTA`, `RETRN` | `%sqrt`, `%xfoot`, `sorta`, `return` | A |
| Result field with length (49-51) and decimals (52) | `dcl-s name zoned(len:dec);` (`char(len)` when the decimals are blank and the operation is not numeric), written before the first calculation | C. Two different definitions of one field: R |
| Factors | character literal as is; numeric literal (`+` dropped, `.5` as `0.5`); `*BLANK(S)`, `*ZERO(S)`, `UDATE`, `UMONTH`, `UDAY`, `UYEAR`; array element `ARR,I` as `ARR(I)`; names as typed. `PAGE`, `PAGE1` to `PAGE7`: R (O specifications) | C |
| Comment (columns 60-74) | `// text` after the first statement | - |
| `MOVE`, `MOVEL`, `MOVEA`, `MVR`, move zone, bit operations, `TESTZ`, `LOKUP`, `KEY`, `DEFN`, `CALL`, `PARM`, `PLIST`, `EXIT`, `RLABL`, `FORCE`, `FREE`, `SET`, `SHTDN`, `DEBUG` | comment | R, with the reason from the table |
| `CHAIN`, `READ`, `READE`, `READP`, `SETLL`, `ACQ`, `NEXT`, `POST`, `REL` | comment | R: file operations need the `FILE_REC` data structures from the I specifications (FREE-04, done) and are converted with FREE-08; WORKSTN files need the display file (later item) |
| `EXCPT` | comment | R: converted with the O specifications (FREE-06) |
| `GOTO`, `TAG` | comment | R: no replacement in free-form |
| Unknown operation code, wrong factor entries (required missing, blank given), a built-in function newer than the target release | comment | R |

A line that is not converted is kept as `// RPG II: ...`. When it opens a group (IFxx, DO, DOWxx, DOUxx, CASxx) a placeholder group is opened, so that the END of it is reported R too and the converted groups stay in balance. Everything inside such a group is still converted: read the report before using the result.

Fields that are defined by I, E or O specifications or by other lines are not declared (FREE-04, FREE-07); the result will not compile until those are converted. `samples/FREEC.rpg36` has one line for each rule above; the expected result of each line is what this table says (written from the design, not from a run).

## RPG III (RPG38 and RPG) to free form

Source types `RPG38` (System/38 RPG III and the System/38 environment), `RPG`
(RPG/400, OPM) and `SQLRPG` (RPG/400 with embedded SQL) are converted straight to `**FREE`: no `CVTRPGSRC` stage. The
dialect is chosen from the source type (`RPG36` is dialect 2, `RPG38` and `RPG`
and `SQLRPG` are dialect 3; the embedded SQL statements (`C/EXEC SQL`) of `SQLRPG` are converted, see "Embedded SQL (SQLRPG)" below) and selects the rows of `IACNVOPC` and `IACNVLAY`. Sources:
SC09-1817 (RPG/400 Reference), SC09-1816 (User's Guide, appendix E on the
System/38 environment).

| Specification | RPG II (S/36) | RPG III | What the converter does |
|---|---|---|---|
| H | Columns 15, 18-21, 26, 37, 41, 43, 45, 57, 75-80 | Same, without 37 (inquiry) and 45; column 21 `D` is decimal notation | Same code as RPG II |
| F | Designation `C`, `D` (chained, demand) | Designation `F` only for input and update; `C`, `D` are not valid | `F` becomes a full procedural file |
| F | Column 19 blank or `F` | Column 19 `F` or `E` (externally described) | `E`: `dcl-f NAME usage(...)` without a record length; `K` in column 31 adds `keyed` |
| F | Columns 71-72: `U1` to `U8` | Also `UC` (programmer controls the first open) | `UC` becomes `usropn` |
| I | Record layout, data structure, subfields | Same columns for program-described files; data structure option `I` (column 18) | `I` becomes `inz`; `S` and `U` are reported R; the I specifications of an externally described file (renames) are reported R |
| C | Columns 7-59 | Same columns; column 53 can also be `N` and `P` | Read through `IACNVLAY`; `N` and `P` are reported R (only half adjust is converted) |
| C | `SET`, `KEY`, `EXIT`, `RLABL` | `KLIST`, `KFLD`, `FREE`, ... | Rows have a `dialects` value, so an operation code is only found in its own dialect |

New operation codes converted for RPG III:

| Operation | Becomes | Notes |
|---|---|---|
| `SELEC`, `WHxx`, `OTHER`, `ENDSL` | `select;`, `when a op b;`, `other;`, `endsl;` | `WHxx` and `OTHER` only directly inside a converted `SELEC`; `END` also closes it |
| `ANDxx`, `ORxx` | The condition of the `IFxx`, `DOWxx`, `DOUxx` or `WHxx` header before is extended with `and` or `or` | `AND` binds tighter than `OR`, as in RPG. When an `ANDxx` or `ORxx` line cannot be converted, the header is rewritten to a condition that is never true (always true for `DOU`) and reported R, so no half condition stays in the source |
| `ENDIF`, `ENDDO`, `ENDCS`, `ENDSL` | The same as `END`, checked against the open group | A mismatch is reported R and the group stays open |
| `ITER`, `LEAVE` | `iter;`, `leave;` | Only inside a converted `DO`, `DOWxx` or `DOUxx`; with conditioning indicators they are wrapped in an `if` |
| `CLEAR`, `RESET` | `clear F2;`, `reset F2;` | `*NOKEY` in factor 1 is reported R |
| `CAT` | `R = F1 + F2;` (no colon), `R = %trimr(F1) + ' ' + F2;` (`F2:1`, up to 10 blanks as a numeric literal); without factor 1 the result field is the first string | A without `P` (the rest of the result keeps its old value in RPG III, free-form pads with blanks), C with `P`. A variable number of blanks is R |
| `SCAN` | `R = %scan(F1:base:start);` and, with a found indicator, `*INnn = (R > 0);`; without a result field `*INnn = (%scan(...) > 0);`. A compare length `KEY:3` becomes `%subst(KEY:1:3)` | A: RPG III signals an error when the start is beyond the string, `%scan` returns 0; the result field must not be an array |
| `CHECK`, `CHEKR` | `R = %check(F1:base:start);` / `%checkr`, the found indicator as for `SCAN` | A, same note as `SCAN` |
| `SUBST` | `R = %subst(base:start:length);` without factor 1 `%subst(base:start)`; start defaults to 1 | A without `P` (as for `CAT`), C with `P` |

For the string operations: the error indicator (columns 56-57), a resulting indicator in columns 54-55, an operation extender other than `P` (and `P` on `SCAN`, `CHECK`, `CHEKR`), a figurative constant, and `SCAN`, `CHECK` or `CHEKR` with neither a result field nor a found indicator are reported R. The result field of `SCAN`, `CHECK`, `CHEKR` is declared as a number without decimals, that of `CAT` and `SUBST` as `char` when columns 49-51 give a length. `XLATE` is still R.

Reported R, with the reason in `IACNVOPC`: `CABxx` (no `GOTO` or `TAG` in
free-form), `XLATE` (colon operands and
the rule that the result keeps its tail without `P`), `TESTN`, `DSPLY`, `DUMP`,
all file and data area operations (`OPEN`, `CLOSE`, `WRITE`, `UPDAT`, `DELET`,
`SETGT`, `EXFMT`, `FEOD`, `UNLCK`, `READC`, `REDPE`, `COMIT`, `ROLBK`, `IN`, `OUT`,
`OCUR`, `KLIST`, `KFLD`), which wait for FREE-08. E, L and O specifications are
reported R as for RPG II.

`samples/FREE3.rpg38` has one line for each rule above. Expected result, written
from the design and not from a run:

| Line | Expected |
|---|---|
| `H` | Converted (no `ctl-opt` keyword) |
| `FCUSTMAS IF E K DISK` | `dcl-f CUSTMAS usage(*input) keyed;`, converted |
| `FORDERS UF F 80 DISK` | `dcl-f ORDERS disk(80) usage(*update:*delete);` assumption (`*DELETE` added) |
| `FLATE IF E DISK UC` | `dcl-f LATE usage(*input) usropn;` assumption (`OPEN` waits for FREE-08) |
| `IWORK DS` with option `I` | `dcl-ds WORK inz;` with `dcl-subf CODE char(10) pos(1);` and `dcl-subf RATE packed(9:2) pos(11);` |
| `SELEC` / `WHEQ` / `WHEQ`+`ANDGT` / `OTHER` / `ENDSL` | `select;`, `when CODE = 'A';`, `when CODE = 'B' and RATE > 5;`, `other;`, `endsl;` |
| `IFEQ` + `ANDGT` + `OREQ` | `if CODE = 'X' and RATE > 1 or RATE = 0;` |
| `IFEQ` + `ANDGT` with indicator 99 | `if *off; // ANDxx/ORxx not converted`, the `ANDGT` line R, the body and `ENDIF` converted |
| `DO` then `ENDIF` then `ENDDO` | `ENDIF` reported R (mismatch), `ENDDO` closes the loop |
| `DOWLT`, `ITER` (ind 01), `LEAVE` (ind 02) | `dow CNT < 9;`, `if *IN01; iter; endif;`, `if *IN02; leave; endif;`, `enddo;` |
| `LEAVE` outside a loop | Reported R |
| `CLEAR WORK`, `RESET FLAG` | `clear WORK;`, `reset FLAG;` |
| `CABEQ`, `OPEN`, extra `ENDSL` | Reported R |
| `FIRST CAT LAST:1 NAME 30` | `dcl-s NAME char(30);` and `NAME = %trimr(FIRST) + ' ' + LAST;`, A (no `P`) |

## File operations (FREE-08)

Source: SC09-1818 chapter 27 and SC09-1817 chapter 11 (the operation codes and their resulting indicators), the ILE RPG reference (`CHAIN`, `READ`, `READE`, `READP`, `READPE`, `SETLL`, `SETGT`, `WRITE`, `UPDATE`, `DELETE`, `OPEN`, `CLOSE`, `FEOD`, `UNLOCK`, `%FOUND`, `%EOF`, `%ERROR`, the operation extender `(E)`). Done in `ConvertFileOp` of `IAfreeCalc`, which asks `IAfreeCvt` for the file (`FileInfo`): device, type, record layout, keyed. Only DISK files declared by a converted F specification (FREE-03) are handled.

| Source | Becomes |
|---|---|
| `CHAIN`, `READE`, `REDPE`, `SETLL`, `SETGT`, `DELET` with factor 1 | `chain KEY FILE REC;`, `reade KEY FILE REC;`, `readpe KEY FILE REC;`, `setll KEY FILE;`, `setgt KEY FILE;`, `delete KEY FILE;` |
| `READ`, `READP` | `read FILE REC;`, `readp FILE REC;` |
| `WRITE`, `UPDAT` | `write FILE REC;`, `update FILE REC;` |
| `OPEN`, `CLOSE`, `FEOD`, `UNLCK` | `open FILE;`, `close FILE;`, `feod FILE;`, `unlock FILE;` |
| `REC` for a program-described file | the data structure `FILE_REC` of the I specifications (FREE-04), or the data structure named in the result field; a file with no I specification is R |
| `REC` for an externally described file | nothing, or the data structure named in the result field |
| Error indicator (`ER`) | the extender: `chain(e) ...;`, then `*INnn = %error;` |
| `NR` (no record) | `*INnn = not %found(FILE);` after `CHAIN`, `SETGT`, `DELET` |
| `EOF`, `BOF` | `*INnn = %eof(FILE);` after `READ`, `READE`, `READP`, `REDPE` |
| `KLIST` name in factor 1 | `(F1:F2:...)` for several `KFLD` fields, the field for one |
| `KLIST` and `KFLD` lines | nothing is written, they are reported C |

The key lists are collected from the whole source before the conversion, so a `KLIST` after its use works. A numeric search argument for the key of a program-described keyed file is reported A: the key is declared `keyed(*char:n)` (FREE-03) and the free-form search argument must be a character value.

Reported R: a file that is not declared by a converted F specification (a record format name in factor 2 is not converted), a printer file, a program-described file with no record layout, a `KFLD` that is not a plain field name, a resulting indicator that the operation does not have, `WRITE` with the end of file indicator (file full), and the operations still R in the table (`READC`, `EXFMT`, `COMIT`, `ROLBK`, `IN`, `OUT`, `OCUR`, `EXCPT` and the WORKSTN operations). `EXCPT` waits for the O specifications (FREE-06); `MOVE` and `MOVEL` still wait for the field types.

`samples/FREEFIL.rpg36` (RPG II) and `samples/FREEFIL3.rpg38` (RPG III) have one line for each row. Expected result, written from the design and not from a run:

| Line | Expected |
|---|---|
| `CUSTNO CHAIN CUSTMAS`, `NR` 90 | `chain CUSTNO CUSTMAS CUSTMAS_REC;` and `*IN90 = (not %found(CUSTMAS));`, A (character key) |
| `SETLL`, `READE` with `EOF` 91 | `setll CUSTNO CUSTMAS;`, `reade CUSTNO CUSTMAS CUSTMAS_REC;`, `*IN91 = (%eof(CUSTMAS));` |
| `READ DEMAND1`, `ER` 92, `EOF` 93 | `read(e) DEMAND1 DEMAND1_REC;`, `*IN92 = (%error);`, `*IN93 = (%eof(DEMAND1));` |
| `READ DEMAND1` | `read DEMAND1 DEMAND1_REC;` |
| `CHAIN` of `NOFILE`, `READ` of `NOLAYT` (no I specification), `READ` of the printer file, `CHAIN` with an `ER` indicator | each kept as comment, R |
| `KEYORD CHAIN ORDERS`, `NR` 90 (before the `KLIST`) | `chain (CUSTNO:ORDNO) ORDERS;` and `*IN90 = (not %found(ORDERS));` |
| `UPDAT`, `ER` 92 | `update(e) ORDERS;`, `*IN92 = (%error);` |
| `SETGT`, `NR` 93 | `setgt (CUSTNO:ORDNO) ORDERS;`, `*IN93 = (not %found(ORDERS));` |
| `READP`, `EOF`... `BOF` 94; `REDPE`, 95 | `readp ORDERS;`, `*IN94 = (%eof(ORDERS));`, `readpe CUSTNO ORDERS;`, `*IN95 = (%eof(ORDERS));` |
| `DELET`, `NR` 96; `WRITE`; `OPEN` with `ER` 97; `CHAIN CUSTMAS`; `CLOSE`; `FEOD`; `UNLCK` | `delete (CUSTNO:ORDNO) ORDERS;` ..., `write ORDERS;`, `open(e) CUSTMAS;` ..., `close CUSTMAS;`, `feod ORDERS;`, `unlock ORDERS;` |
| `ONEKEY SETLL ORDERS` | `setll CUSTNO ORDERS;` |
| `KLIST` and `KFLD` lines | reported C, nothing written |
| `WRITE` with `EOF` 98; `CHAIN` with the list `KEYBAD` (a `KFLD` with a literal) | R |

## RPG IV fixed form (RPGLE, SQLRPGLE) to free form (FREE-10)

Source: SC09-2508 (7.3), free-form equivalents of the H, F, D and P
specifications. Module `IAfreeFx4`; columns come from `IACNVLAY` (dialect 4). The
C, I and O specifications are not converted yet and are reported R (the C
specification is the second part of FREE-10).

| Fixed form | Free form |
|------------|-----------|
| H keywords (lines joined) | `ctl-opt keywords;` |
| F, type I + designation F | `dcl-f NAME disk(len) usage(*input);` (device keyword carries the record length; externally described: no length) |
| F, I + A / U / U + A / O / C | `usage(*input : *output)` / `*update : *delete` / `*update : *delete : *output` / `*output` / `*input : *output` |
| F, record address type K or A with key length | `keyed` / `keyed(*char : len)` |
| F, designation P, S, R, T; sequence; limits; output + A | R: not supported in free form |
| D, DS | `dcl-ds NAME ... ;` with subfields `dcl-subf`, `end-ds;` (none for LIKEDS or LIKEREC) |
| D, S | `dcl-s NAME type;` |
| D, C | `dcl-c NAME value;` |
| D, PR / PI | `dcl-pr`, `dcl-pi` with `dcl-parm`, `end-pr;`, `end-pi;` |
| D, DS type S / U | `psds` / `dtaara(*auto)` |
| D, from-to positions | length in digits, `pos(from)` for a subfield |
| D, internal type blank + decimals | `packed` (standalone, parameter) or `zoned` (subfield) |
| D, VARYING / DATFMT / TIMFMT / PROCPTR | `varchar(len)` / `date(fmt)` / `time(fmt)` / `pointer(*proc)` |
| D, OVERLAY(ds:pos) | `pos(pos)` |
| D, EXT / EXTNAME / EXTFLD | first keyword, names written as literals (reported A) |
| P, B / E | `dcl-proc NAME;` / `end-proc;` |
| /COPY, /INCLUDE and other directives | kept (A for /COPY: the member has to be free-form too) |
| /FREE ... /END-FREE | lines copied from column 8, markers dropped |

C specifications (part 2, `ConvertC` in `IAfreeFx4`, sample `samples/FREE4C.rpgle`):

| Fixed form | Free form |
|------------|-----------|
| `EVAL`, `EVALR`, `EVAL-CORR`, `IF`, `DOW`, `DOU`, `WHEN`, `ELSEIF`, `FOR`, `RETURN`, `CALLP`, `SORTA`, `ON-ERROR` (extended factor 2, with continuation lines) | same keyword in lower case with the extender, `;` added |
| `ELSE`, `OTHER`, `SELECT`, `MONITOR`, `ENDIF`, `ENDDO`, `ENDFOR`, `ENDSL`, `ENDMON`, `ITER`, `LEAVE`, `LEAVESR`, `BEGSR name`, `ENDSR` | keyword; statements are indented two blanks per open group |
| `IFxx`, `DOWxx`, `DOUxx`, `WHxx` | `if f1 = f2;` with `=`, `<>`, `>`, `<`, `>=`, `<=` |
| a conditioning indicator (columns 9-11) on `IF`, `IFxx`, `DOW`, `DOWxx`, `DOU`, `DOUxx`, `FOR`, `DO` | an outer `if *inNN;` around the whole group, its `endif;` after the `ENDIF` / `ENDDO` / `ENDFOR` (an off indicator skips the group, the `ELSE` branch too); other group operations stay R (FREE-21, RV-52) |
| `DO` without a result field (index) | `for DOIXnnnn = start to limit;` with the hidden index `dcl-s DOIXnnnn int(10);` (nnnn is the source line of the `DO`) before the first calculation (FREE-21, RV-54) |
| `ADD`, `SUB`, `MULT`, `DIV`, `Z-ADD`, `Z-SUB` (result declared elsewhere; `(H)` gives `eval(h)`) | `res = f1 + f2;`; factor 1 blank gives `res = res + f2;`; DIV is A (MVR) |
| `SETON`, `SETOFF` | `*in01 = *on;` / `*off` |
| `CLEAR`, `RESET` with a result | `clear res;` |
| `CHAIN`, `READE`, `READPE`, `SETLL`, `SETGT`, `DELETE`, `READ`, `READP`, `WRITE`, `UPDATE`, `OPEN`, `CLOSE`, `UNLOCK`, `FEOD`, `EXFMT` without resulting indicators | `chain(e) key file;`; a `KLIST` name becomes `(k1 : k2)`; `KLIST` and `KFLD` lines write nothing |
| `/EXEC SQL` ... (SQLRPGLE) | as for SQLRPG (FREE-11) |

| Resulting indicators (Table 99): `NR` 71-72 of `CHAIN`, `SETGT`, `DELETE`, `SETLL` | `*in91 = (not %found(FILE));` |
| `ER` 73-74 | the extender `(e)` is added, `*in92 = (%error);` |
| `EOF` / `BOF` 75-76 of `READ`, `READE`, `READP`, `READPE`; `EQ` of `SETLL` | `*in94 = (%eof(FILE));` / `*in89 = (%equal(FILE));` |
| `+`, `-`, `Z` of the arithmetic operations; `HI`, `LO`, `EQ` of `COMP` | `*in70 = (res > 0);` `*in71 = (res < 0);` `*in72 = (res = 0);` / compare of the two factors |
| `IFxx` / `WHxx` / `DOWxx` / `DOUxx` followed by `ANDxx` / `ORxx` | `if (a = b) and (c < d) or (e = f);` |

| `MOVE`, `MOVEL` between declared fields (type table filled from the D specifications of the same source) | char to char: `res = f2` when the lengths are equal, `%subst` of the longer or `%subst(res:...) = f2` for the shorter; `MOVEL(P)`: `res = f2`; numeric to numeric with equal decimals and enough digits: `res = f2`; literal `'1'`/`'0'` or `*ON`/`*OFF` to `*INnn` or an indicator: `*on`/`*off`; `*BLANKS`, `*ZEROS` and the like: assigned. Reported A (check). Other type pairs, undeclared fields, `MOVE(P)`, a result with length or decimals: R |
| `CAT`, `SCAN`, `CHECK`, `CHEKR`, `SUBST` (result declared in the source; found indicator in 75-76) | as the table of FREE-12: `res = %trimr(f1) + ' ' + f2;`, `pos = %scan(a:b:start);`, `*in60 = (%scan(a:b) > 0);`, `res = %subst(s:start:len);`. A; `(P)` is C. R: error indicator or `(E)`, figurative constants, a variable number of blanks, undeclared result |
| `DO` with a declared index field, `ENDDO` with an increment | `for IDX = start to limit;` (start and limit default to 1), then `for IDX = start to limit by inc;` | C |
| `DSPLY`, `COMIT`/`COMMIT`, `ROLBK`, `DUMP`, `TIME` (6-digit field) | `dsply msg queue resp;`, `commit;`, `rolbk;`, `dump(a);`, `now = %dec(%time() : *hms);` | C |
| `CALL 'PGM'` with its `PARM` lines or a `PLIST` named in the result field | before the first calculation `dcl-pr PGM extpgm('PGM'); dcl-parm *n type; ... end-pr;` (types of the declared parameter fields), then `result = factor1; callp(e) PGM(p1 : p2); factor2 = result;` | A. R: a program name that is not a literal without library, a parameter that is not declared in this source, the same program with other parameter types, `ER`/`LR` indicators, `PLIST *ENTRY`, `PARM` without a `CALL` |
| `XLATE`, `MVR` after an integer `DIV`, `DEFN *LIKE`, `TESTN` | `res = %xlate(from:to:string:start);`; `rem = %rem(dividend : divisor);`; `dcl-s COPY like(NAME);` written before the first calculation; `*in61 = (%check('0123456789' : f) = 0);` (NU), BN and BL tests | A. R: `MVR` not directly after its `DIV`, with decimals or half adjust; `DEFN` with a length or other than `*LIKE`; `TESTN` on a field that is not declared character |
| `LOOKUP` on an array (FREE-27, RV-53) | equal: `*in26 = (%lookup(Code : Names) > 0);` high: `%lookupgt`, low: `%lookuplt`; equal and high: `*in26 = (%lookup(...) > 0); *in27 = (not *in26 and %lookupgt(...) > 0);` (low: `%lookuplt`); with an index `Names(X)` the search starts at `X` (third parameter) and `X = %max(1 : %lookup(Code : Names : X));` follows the indicators (the index is set to the position found or to 1; a constant index does not change) | A. R: a table (result field: `%tlookup`), a name that is not an array of a D specification, high or low without `ASCEND`/`DESCEND`, high and low together, no indicator, an extender |
| `CALL` with an error indicator (columns 73-74, FREE-27, RV-53) | `callp(e) PGM(parms);` followed by `*in90 = (%error);` | A. R: the LR indicator (columns 75-76) and the high indicator |
| Conditioning indicator (columns 9-11) on a simple operation | `if *in90;` or `if not *in90;`, the statement indented, `endif;` |

R: level indicators (columns 7-8), a conditioning indicator on a group operation (`IF`, `DOW`, `BEGSR`...) or on `RT`, resulting indicators of other operations,
`ANDxx` and `ORxx` with indicators (RPG IV: comment lines between the header and the `ANDxx`/`ORxx` lines are converted, FREE-28), traditional `DO`, `MOVE`,
`MOVEL`, `CALL`/`PARM`, string and other operations, a result field defined by
length and decimals, a literal continued with `+` or `-`.

`samples/FREE4LK.rpgle` (FREE-27): expected result, written from the design and not from a run: `*in26 = (%lookup(Code : Names) > 0);`, `*in27 = (%lookupgt(Code : Names) > 0);`, `*in28 = (%lookuplt(Code : Names) > 0);`, the two combined forms, `*in26 = (%lookup(Code : Names : X) > 0);` then `X = %max(1 : %lookup(Code : Names : X));`, three R lines (no sequence on `Plain`, a table in the result field, no indicator), and `callp(e) MYPGM(Count);` then `*in90 = (%error);`.

Embedded SQL in RPG IV (FREE-26, review item RV-59): the statements of a converted `/EXEC SQL` are written by `IAfreeCalc` and indented with the open groups of `IAfreeFx4`: `IndentText` adds two positions for each level that `Fx4Depth` reports (the same width as the RPG IV statements); for RPG II and III the depth is 0 and nothing changes. `samples/FREE4SQL.sqlrpgle`: expected result, written from the design and not from a run: `if Key > 0;` then `  exec sql UPDATE CUSTMAS SET STATUS = 'A'` with its `WHERE` line and the `;` one level further in, the inner `if Count > 1;` with `    exec sql DELETE FROM WORKFILE;` and `  endif;`, then `else;` with `  exec sql SELECT COUNT(*) INTO :COUNT FROM CUSTMAS;` and `endif;`.

Reported R: FROMFILE, TOFILE, CLASS, PACKEVEN, object types, invalid entries.

Continuations (FREE-30, review item RV-57; SC09-2508 Continuation Rules): a D or P line whose name begins in columns 7-21 and ends with `...` (no blanks inside) is a part of a name; the parts and the name of the main definition line, which may be blank, are joined (`QuiteLongFieldNameThatCannotAlwaysFitInOneLine` `...` / `S 10A` becomes `dcl-s QuiteLongFieldNameThatCannotAlwaysFitInOneLine char(10);`); a continued name without a definition line directly after it stays R. In the keyword field a part ending in `...` outside a literal is joined to the next part without a blank (`%addr(QuiteLongFieldName...` / `ThatCannotAlways...` / `FitInOneLine))`). A character literal ending in `+` continues with the first non-blank character of the next keyword line, ending in `-` with the next line from column 44 on (the leading blanks count), and the pieces are written as one literal (`INZ('Mary had a little lamb, its fleece was white as snow.')`; `INZ('abc     def')`); a line that is too long is not split inside the literal. A `+` or `-` at the end of a line outside a literal stays R. `samples/FREE4NM.rpgle`: expected result, written from the design and not from a run: the two long names, `dcl-s Ptr pointer inz(%addr(QuiteLongFieldNameThatCannotAlwaysFitInOneLine));`, `dcl-s NameThatIsSoLongItMustBeContinued char(10);`, `Msg` and `Msg2` as above, and the last line reported R. `**` compile-time
data sections are kept as is (A). Sample: `samples/FREE4.rpgle`.

## Data areas: DEFN *NAMVAR, IN, OUT, UNLCK (FREE-17, review item RV-11)

Source: SC09-1817 chapter 11 (DEFN *NAMVAR, IN, OUT, UNLCK), the ILE RPG reference (the `DTAARA` keyword for a field, subfield and data structure, `IN`, `OUT`, `UNLOCK`). In RPG/400 the data area is associated with a field or data structure by `*NAMVAR DEFN`; `IN`, `OUT` and `UNLCK` name that field. In free form the association is the `DTAARA` keyword on the declaration; its name is written as a literal in capitals (an unquoted name would be a variable that holds the name).

| Source | Becomes | Status |
|---|---|---|
| `*NAMVAR DEFN Area Field`, `Area` a name, `*LDA` or `*PDA` (blank: the name of the field) | the keyword `dtaara('AREA')` on the declaration of `Field` | C |
| `Field` is a named data structure of the I specifications | `dcl-ds FIELD dtaara('AREA');` (the line already written is changed) | C |
| `Field` is declared by a result field with a length, before or after the `DEFN` | `dcl-s FIELD type dtaara('AREA');` in the declarations at the top | C |
| `*LOCK IN Field`, `IN Field`, `OUT Field`, `*LOCK OUT Field` | `in *lock FIELD;`, `in FIELD;`, `out FIELD;`, `out *lock FIELD;` | C |
| `IN *NAMVAR`, `OUT *NAMVAR` | `in *dtaara;`, `out *dtaara;` | C |
| error indicator (columns 56-57) | `in(e) FIELD;` and `*INnn = %error;` | C |
| `UNLCK Field` where `Field` is a data area | `unlock FIELD;` | C |

Reported R: a field that is neither a named data structure of the I specifications nor declared by a result field (a subfield or an input record field; reported at the end of the calculations because the declaration can come after the `DEFN`), a `DEFN *NAMVAR` with a length or with conditioning indicators, a field that is already associated, `IN` or `OUT` of a name that no `DEFN *NAMVAR` defines, `*LOCK` for `*LDA` or `*PDA`, a result field, resulting indicators other than the error indicator. `OCUR` stays R: it needs the multiple-occurrence data structure (`OCCURS` of the I specification is not converted yet).

`samples/FREEDTA.rpg38` has one line for each row. Expected result, written from the design and not from a run:

| Line | Expected |
|---|---|
| `*NAMVAR DEFN *LDA MYDS` | `dcl-ds MYDS dtaara('*LDA');` |
| `TOTAL` declared before, `*NAMVAR DEFN TOTDA TOTAL` | `dcl-s TOTAL zoned(9:0) dtaara('TOTDA');` |
| `*NAMVAR DEFN CNTDA CNT`, `CNT` declared after | `dcl-s CNT zoned(5:0) dtaara('CNTDA');` |
| `*LOCK IN TOTAL`, `OUT TOTAL`, `IN MYDS` | `in *lock TOTAL;`, `out TOTAL;`, `in MYDS;` |
| `IN TOTAL` with 90; `*LOCK OUT TOTAL` with 91 | `in(e) TOTAL;`, `*IN90 = %error;`; `out(e) *lock TOTAL;`, `*IN91 = %error;` |
| `IN *NAMVAR`, `OUT *NAMVAR`, `UNLCK TOTAL` | `in *dtaara;`, `out *dtaara;`, `unlock TOTAL;` |
| the "Not converted" lines | each kept as comment, R; the `DEFN` of `GHOST` is reported R at the end |

## XLATE, MVR, DEFN, DSPLY, DUMP, COMIT, ROLBK (FREE-13, review items RV-02, RV-03, RV-07, RV-09, RV-10)

Source: SC09-1817 chapter 11 (each operation), the ILE RPG reference (`%XLATE`, `%REM`, `LIKE`, `DSPLY`, `DUMP`, `COMMIT`, `ROLBK`).

| Source | Becomes | Status |
|---|---|---|
| `From:To XLATE String:start Result` | `R = %xlate(From:To:String:start);` (start defaults to 1, characters before it are copied unchanged, as in RPG III) | A without `P` (the rest of a longer result keeps its old value in RPG III, free-form pads it), C with `P` |
| `DIV` followed by `MVR` | `R = %rem(dividend:divisor);` with the operands of that `DIV` | A; only when the dividend, the divisor and the quotient field are known whole numbers (`%REM` needs integers; with decimals the remainder is not the `%REM`); `MVR` not directly after a `DIV`, or after a `DIV` without factor 1, is R |
| `*LIKE DEFN Other New` | `dcl-s New like(Other);` with the declarations at the top; `+ n` or `- n` in columns 49-51 gives `like(Other:+n)` | C |
| `DSPLY Message Queue Response` | `dsply message queue response;` with the error indicator as `dsply(e)` and `*INnn = %error;` | C; A when there is a response and no queue: `*EXT` is used, RPG/400 uses `QSYSOPR` for a batch job |
| `DUMP Identifier` | `dump identifier;` (made only with `debug(*dump)`, which the control specification column 15 gives) | C |
| `COMIT Boundary`, `ROLBK` | `commit boundary;`, `rolbk;`, the error indicator as `commit(e)` and `*INnn = %error;` | C |

Reported R: `XLATE` with an error indicator, with a factor 1 that is not `From:To`, or with a figurative constant; `DEFN *NAMVAR` (data areas, RV-11), `DEFN` with a literal in factor 2, with conditioning indicators, or with a length that is not `+n` or `-n`; `DSPLY` without factor 1, with a `*M` message identifier, or with a numeric message field; resulting indicators other than the error indicator.

`samples/FREEOP2.rpg38` has one line for each row. Expected result, written from the design and not from a run:

| Line | Expected |
|---|---|
| `N1 DIV N2 Q`, `MVR R` (all 5,0) | `Q = N1 / N2;`, `R = %rem(N1:N2);`, A |
| `'abc':'ABC' XLATE STR:2 OUT 10` | `OUT = %xlate('abc':'ABC':STR:2);`, A; with `P` and `OUT2` C |
| `*LIKE DEFN STR COPY`, `... LONGER + 5` | `dcl-s COPY like(STR);`, `dcl-s LONGER like(STR:+5);` at the top |
| `DSPLY 'Hello'`; with `*EXT` and a response; with a response only; with an error indicator | `dsply 'Hello';`; `dsply 'Name?' *EXT ANSWER;`; `dsply 'Name?' *EXT ANSWER;` (A); `dsply(e) 'Name?';` and `*IN91 = %error;` |
| `DUMP 'AT END'`, `DUMP` | `dump 'AT END';`, `dump;` |
| `COMIT 'B1'` with error indicator 90, `ROLBK` | `commit(e) 'B1';` and `*IN90 = %error;`, `rolbk;` |
| `DIV` to 2 decimals then `MVR`; `MVR` after `ADD`; `XLATE` with an error indicator; `XLATE` with no `From:To`; `*LIKE DEFN` of a literal; `*NAMVAR DEFN`; `DEFN` with a length `5`; `DSPLY *MABC1`; `DSPLY` without factor 1; `DSPLY` of a numeric field | each kept as comment, R |

## TESTN, TESTZ, BITON, BITOF, TESTB (FREE-14, review items RV-04 and RV-05)

Source: SC09-1817 chapter 11 (each operation), the ILE RPG reference (`%BITAND`, `%BITOR`, `%BITNOT`, `%CHECK`, `%TRIML`). Code: `ConvertBitTest`, `BitMask`, `HexByte` in `IAfreeCalc`; the resulting indicator tests are given to `ResultStatement` because they depend on the field.

| Source | Becomes | Status |
|---|---|---|
| `BITON '036' FLDA` (bit numbers 0 to 7, 0 is the leftmost bit) | `FLDA = %bitor(FLDA:x'92');` (the mask is worked out) | C |
| `BITOF '7' FLDA` | `FLDA = %bitand(FLDA:x'FE');` (the inverted mask) | C |
| `BITON X'88' FLDA`, `BITOF X'88' FLDA` | `%bitor(FLDA:x'88')`, `%bitand(FLDA:x'77')` | C |
| `BITON FLDB FLDA`, `BITOF FLDB FLDA` (one-position field in factor 2) | `%bitor(FLDA:FLDB)`, `%bitand(FLDA:%bitnot(FLDB))` | C |
| `TESTB mask FLDA 16 17 18` | `*IN16 = (%bitand(FLDA:mask) = x'00');` all bits off (54-55); `*IN17 = (... <> x'00' and ... <> mask);` mixed (56-57); `*IN18 = (%bitand(FLDA:mask) = mask);` all on (58-59) | C; A with a field in factor 2 (RPG/400 sets no indicator on when the field has no bit on) |
| `TESTN FLD 21 22 23` (field of length n) | NU: `%check('0123456789':%subst(FLD:1:n-1)) = 0 and %check('0123456789ABCDEFGHIJKLMNOPQR{}':%subst(FLD:n:1)) = 0`; BN (leading blanks, then digits): first position blank, the other positions digits or blanks, no blank after the first digit (`%scan(' ':%triml(FLD)) = 0`); BL: `FLD = *blanks` | A: the sign zone is tested as a letter (A-R, `{`, `}`), not as a hexadecimal zone |
| `TESTZ FLD 31 32 33` | zone of the first character `%bitand(%subst(FLD:1:1):x'F0')`: `x'50'` or `x'C0'` (`&`, A-I) in 54-55, `x'60'` or `x'D0'` (`-`, J-R) in 56-57, any other zone in 58-59 | A: EBCDIC zones |

Reported R: bit numbers other than 0 to 7, repeated bit numbers, more than 8 bits, a named constant or an array element in factor 2, a factor 2 field that is not one position character, a result field that is numeric or (bit operations, `TESTB`) longer than one position, resulting indicators on `BITON` and `BITOF`, an indicator in 56-57 of `TESTB` with one bit or of `TESTN` on a field of one position, no resulting indicator on a test, `TESTN` on a field not defined before the line.

`samples/FREEBIT.rpg38` has one line for each row, then the R lines. Expected result, written from the design and not from a run: the masks of the first lines are `x'92'` (bits 0, 3, 6), `x'FE'`, `x'88'`, `x'77'`; the last nine lines are kept as comments, R.

## MHHZO, MHLZO, MLHZO, MLLZO (FREE-15, review item RV-06)

Source: SC09-1817 chapter 11 (Move Zone Operations). Code: `ConvertZoneMove` in `IAfreeCalc`. The second letter of the code is the factor 2 side, the third the result side: H is the first (leftmost) character of the field, L the last.

| Source | Becomes | Status |
|---|---|---|
| `MHHZO SRC TGT` (SRC 2, TGT 5) | `%subst(TGT:1:1) = %bitor(%bitand(%subst(TGT:1:1):x'0F'):%bitand(%subst(SRC:1:1):x'F0'));` | C |
| `MHLZO`, `MLHZO`, `MLLZO` | the same with the positions 1 or the field length: `%subst(TGT:5:1)` and `%subst(SRC:2:1)` for L | C |

The zone is the left four bits of the byte, so the result is the EBCDIC zone of the RPG/400 operation. Reported R: a numeric factor 2 or result field (the sign zone of a zoned field has no free-form equivalent), a field not defined before the line (its length is needed), resulting indicators, a missing factor 2 or result.

`samples/FREEZON.rpg38`: the four operations, then four R lines. Expected result, written from the design and not from a run: `%subst(TGT:1:1)` and `%subst(TGT:5:1)` take the zone of `%subst(SRC:1:1)` or `%subst(SRC:2:1)`.

## CALL, PARM, PLIST (FREE-16, review item RV-08)

Source: SC09-1817 chapter 11 (CALL, PARM, PLIST). Code: `ConvertCall`, `ConvertPlist`, `ConvertParm` in `IAfreeCalc`. `CalcPrescan` collects the PARM lines of every CALL and PLIST before the conversion (as for `KLIST`); the prototypes are written before the first calculation, after the `dcl-s` lines of the result fields (`CalcFinish`).

| Source | Becomes | Status |
|---|---|---|
| `CALL 'PGMA'` with `PARM NAME`, `PARM CNT` | `dcl-pr PGMA extpgm('PGMA'); dcl-parm *n like(NAME); dcl-parm *n like(CNT); end-pr;` before the first calculation, then `callp PGMA(NAME : CNT);` | A |
| `CALL 'PGMB' PLST1` (the PLIST named in the result field) | the same, with the PARM lines of the PLIST | A |
| `CALL` with an indicator in columns 56-57 | `callp(e) ...;` and `*INnn = %error;` | A |
| `PARM` with factor 1 | `RESULT = factor1;` before the call | A |
| `PARM` with factor 2 | `factor2 = RESULT;` after the call | A |
| `PARM` with a length in columns 49-51 | the result field is declared (`char(n)`, or zoned with decimals) where the PARM is | C |
| `PLIST name`, `PARM` lines | no statement; reported C with the CALL | C |

The prototype takes its parameter types from the fields with `like(...)`, so a packed or other type of an I specification is kept. A program called again must have the same kinds, lengths and decimals; the first CALL gives the prototype.

Reported R: a program name that is not a literal without library (`CALL PGMNM`, `CALL 'LIB/PGM'`), a program name that is also a field name, the LR indicator (58-59), an indicator in columns 54-55, a PLIST that is not defined, a parameter that is an array element or not defined before the CALL, the same program called with other parameter types, `PLIST *ENTRY` (the parameters of the program itself need `dcl-pi`) and its PARM lines, `PARM` without a CALL or PLIST before it.

`samples/FREECAL.rpg38`: the cases above, then the R lines. Expected result, written from the design and not from a run: prototypes `PGMA` (like NAME, like CNT) and `PGMB` (like CODE, like SAVE) before the first calculation; `callp PGMA(NAME : CNT);`, `callp(e) PGMA(NAME : CNT);` with `*IN91 = %error;`, `CODE = 'X'; SAVE = NAME; callp PGMB(CODE : SAVE); BACK = SAVE;`.

## File description continuation records (FREE-18, review item RV-32)

Source: SC09-1817 chapter 5 (Continuation Line, Tables 16 and 17). Code: `ContinuationKeywords` and `ConvertFile` (which now calls `ConvertFileLine`) in `IAfreeCvt`. The option of a continuation record (K in column 53, option in columns 54-59, entry in columns 60-67) can also be on the main file line. The options become keywords of the `dcl-f` of the main line; all the records of the file are reported with it.

| Option | Keyword | Files |
|---|---|---|
| `COMIT` | `commit` | DISK |
| `INFDS name` | `infds(NAME)` (the data structure keeps the RPG/400 layout: A) | DISK, PRINTER |
| `INFSR name`, `INFSR *PSSR` | `infsr(NAME)`, `infsr(*pssr)` | DISK, PRINTER |
| `RECNO field` | `recno(FIELD)` (numeric, no decimals, defined in the program: A) | DISK |
| `RENAME` (external name in columns 19-28, new name in 60-67) | `rename(EXT:NEW)` | externally described DISK |
| `IGNORE` (record format in columns 19-28) | `ignore(FORMAT)` | externally described DISK |

Reported R, with the whole file kept as comments (the main line and its records): `PRTCTL` (needs a program-described printer file; the printer file is declared externally described), the options of WORKSTN and SPECIAL files (`ID`, `IND`, `NUM`, `PASS`, `SAVDS`, `SFILE`, `SLN`, `PLIST`), an option that is not in Table 17, an option given twice (`RENAME` and `IGNORE` may be repeated), an entry that is not a name, `COMIT` with an entry, `RENAME` or `IGNORE` for a file that is not externally described, entries in columns 29-52 or 68-74 of a continuation record, a continuation record without an option.

`samples/FREEFCN.rpg38`: one file for each converted option (also `COMIT` on the main line), then the R files. Expected result, written from the design and not from a run: `dcl-f CUSTMAS disk usage(*input) keyed commit;`, `dcl-f ORDERS disk usage(*update:*delete) keyed recno(RRN) infds(ORDDS) infsr(*pssr);`, `dcl-f ITEMS disk usage(*input) keyed rename(ITEMREC:ITEMR) ignore(OLDREC);`, `dcl-f QPRINT printer infsr(PRTERR);`.

## Arrays: sign format, files and data format (FREE-19, review item RV-35)

Source: SC09-1817 chapter 6 (E specification: positions 11-26, 43, 55), the ILE RPG reference (`EXTFMT`, `FROMFILE`, `TOFILE`, "Free-form equivalents for keywords that are not supported in free-form definitions"). Code: `ConvertExtension` in `IAfreeCvt`.

**The planned conversion of RV-35 (`fromfile`, `tofile`, `extfmt(P)`, `extfmt(B)`) is not possible**: the ILE RPG reference says the `FROMFILE` and `TOFILE` keywords are not allowed in a free-form definition (a fixed-form D specification is needed), and `EXTFMT` P and B are only for arrays loaded from a file. These stay R, with that reason. What can be converted is the sign format of compile-time arrays:

| Source | Becomes | Status |
|---|---|---|
| Compile-time array, `L` or `R` in column 43 (numeric, length 3 with 2 decimals) | `dcl-s SGN zoned(2:2) dim(5) perrcd(5) extfmt(L) ctdata;` (the length of the entry includes the sign, the declared digits are one less) | A |
| Alternating array, `L` or `R` in column 55 | `dcl-s ARR2 zoned(3:1) dim(6) extfmt(R) alt(ARR1);` | A |

Reported R: an array with a file in columns 11-18 (FROMFILE) or 19-26 (TOFILE), packed or binary data (`P`, `B`), a record address file (name blank), a sign format for a character array, a run-time array (columns 33-35 blank) or an entry shorter than 2, a data format other than blank, `L` or `R`. A compile-time array that is not converted (also one with a to-file) still takes its data section, so the next arrays keep their `**CTDATA` names. To convert such an array, load it with `READ` operations and write it with `WRITE` operations, or keep a fixed-form D specification (the source then is not fully free-form).

`samples/FREEARR.rpg38`: the converted sign arrays, then the R lines. Expected result, written from the design and not from a run: `SGN zoned(2:2) ... extfmt(L)`, `SGR zoned(4:0) ... extfmt(R)`, `ARR1 zoned(6:0) ...` with `ARR2 zoned(3:1) dim(6) extfmt(R) alt(ARR1)`.

## Renamed fields of an externally described file (FREE-24, review item RV-30)

Source: SC09-1817 chapter 8 (I specifications of an externally described file: record line with the record format name, field lines with the external name in columns 21-30 and the program name in 53-58); the ILE RPG reference (`dcl-f` has no per-field rename: `PREFIX` renames all fields of a file, `EXTFLD` only renames subfields of a data structure). Code: `ExternalFileOf`, `ConvertInputExternal`, `ConvertExternalField`, `FileRenames`, `FileRenamesBack` and `FormatFile` in `IAfreeCvt`; `ConvertFileOp` in `IAfreeCalc`. FREE-25 adds the write back.

Design (chosen with you): the renamed field is a **copy** of the external field.

| Source | Becomes | Status |
|---|---|---|
| Field line `CUSTNAME` in 21-30, `CNAME` in 53-58 | `dcl-s CNAME like(CUSTNAME);` where the line is | A |
| `CHAIN` or `READ`, `READE`, `READP`, `REDPE` of the file | the operation, then `if %found(FILE)` (CHAIN) or `if not %eof(FILE)` (the others), `CNAME = CUSTNAME; ...`, `endif;` | A |
| `WRITE` or `UPDAT` of a record format named by an I specification record line (FREE-25) | `CUSTNAME = CNAME; CUSTBAL = CBAL;` (external field = renamed field), then `write CUSTREC;` or `update CUSTREC;` | A |
| Field line with no external name (name only) | nothing; reported C | C |
| Record line (record format name) | nothing; reported C | C |

The record line names a record format, so it belongs to the file named in columns 7-14 or, when no file has that name, to the only externally described file of the program. With several externally described files and a format name that is no file name, the block stays R (the format cannot be tied to a file without its DDS). The copy is made only when a record was read, so a failed `CHAIN` or the end of file does not overwrite the renamed field.

Write back (FREE-25): `WRITE` and `UPDAT` of an externally described file name a record format. The record line of the I specifications gives the format name and ties it to its file, so `ConvertFileOp` converts the operation and sets the external fields from the renamed fields in the statement before it. The copy is unconditional: a field the program did not change holds the value copied after the read. A record format that no I specification names (the DDS is not read) stays R. A file with several record formats copies all its renamed fields, because the renames are kept per file. Reported R: control levels, matching fields and field indicators (columns 59-70), record identifying indicators (19-20), AND/OR lines, a name that is already used, an external name that is not a name (10 characters at most), too many renamed fields for one file.

`samples/FREEREN.rpg38`: two renames and a name-only line, then three R lines, then `CHAIN` and `READ`. Expected result, written from the design and not from a run: `dcl-s CNAME like(CUSTNAME);`, `dcl-s CBAL like(CUSTBAL);`, then `chain KEY CUSTMAS;` followed by `*IN50 = not %found(CUSTMAS);`, `if %found(CUSTMAS);`, `CNAME = CUSTNAME; CBAL = CUSTBAL;`, `endif;`. The last lines (FREE-25): `CUSTNAME = CNAME; CUSTBAL = CBAL;`, then `update CUSTREC;`, and again before `write CUSTREC;`; the file is `UF` so that `UPDAT` is valid.

## LOKUP and MOVEA (FREE-08, arrays and tables of FREE-07)

Source: SC09-1818 chapter 27 and SC09-1817 chapter 11 (LOKUP: the search argument, the high, low and equal indicators, the index, the second table), the ILE RPG reference (`%LOOKUP`, `%LOOKUPGT`, `%LOOKUPGE`, `%LOOKUPLT`, `%LOOKUPLE`). `IAfreeCvt` gives `IAfreeCalc` the arrays and tables of the E specifications (`CalcDefineArray`: name, sequence, number of entries, alternating array). The statements use the hidden field `LOKUP_IX` (declared once).

| Source | Becomes | Status |
|---|---|---|
| `LOKUP ARR`, equal indicator | `LOKUP_IX = %lookup(F1:ARR);` and `*INeq = (LOKUP_IX > 0);` | C |
| high only / low only | `%lookupgt` / `%lookuplt`, `*INnn = (LOKUP_IX > 0);` | C (needs the sequence, column 45) |
| equal and high / equal and low | `%lookupge` / `%lookuple`, both indicators set off, then `if LOKUP_IX > 0; if ARR(LOKUP_IX) = F1; *INeq = *on; else; *INhi = *on; endif; endif;` | C (needs the sequence) |
| `LOKUP ARR,X` | the search starts at `X`: `%lookup(F1:ARR:X)`, then `X` is the position found or 1; a numeric literal index is not changed | C |
| `LOKUP TAB` (table) | the same search; the entry found is kept in `TAB_IDX` (declared `int(10) inz(1)`), also in the index of the alternating table and of the table in the result field | A |
| a table name in any other calculation | `TAB(TAB_IDX)`, the current entry (the first one before a `LOKUP`); a table name as factor 1 of `LOKUP` is the current entry too | A |
| `MOVEA ARR1 ARR2`, same number of entries, same entry length and type | `ARR2 = ARR1;` | C |
| `MOVEA *BLANK(S) ARR`, `MOVEA *ZERO(S) ARR` | `ARR = *blanks;` (alphanumeric array), `ARR = *zeros;` | C |

Reported R: no resulting indicator, more than two, high and low together, high or low without the sequence of the array, an index on a table, a result field with an array, a result field that is not a table, a search argument field of another length or format than the entries (a literal is not checked), an array or table that no E specification defines, `MOVEA` with an index, between an array and a field, to or from a table, and between arrays of another size, entry length or type. The result indicator rules follow the manual: an indicator is set on only for a successful search; the conversion sets it off when the search fails.

`samples/FREELOK.rpg36` has one line for each row. Expected result, written from the design and not from a run:

| Line | Expected |
|---|---|
| `SRCH LOKUP ARR`, 90 | `LOKUP_IX = %lookup(SRCH:ARR);`, `*IN90 = (LOKUP_IX > 0);` |
| `SRCH LOKUP ARR,X`, 91 | `LOKUP_IX = %lookup(SRCH:ARR:X);`, `*IN91 = (LOKUP_IX > 0);`, `if LOKUP_IX = 0; X = 1; else; X = LOKUP_IX; endif;` |
| high 92; high 93 and equal 94; low 95 and equal 96 | `%lookupgt`; `%lookupge` with the `if ... endif` test; `%lookuple` with the test |
| `SRCH3 LOKUP TABCOD`, 97 | `%lookup(SRCH3:TABCOD)`, `*IN97`, `if LOKUP_IX > 0; TABCOD_IDX = LOKUP_IX; TABAMT_IDX = LOKUP_IX; endif;`, A |
| `Z-ADD TABAMT TOTAL` | `TOTAL = TABAMT(TABAMT_IDX);` |
| `MOVEA ARR ARRB`, `MOVEA *BLANK CHRARR`, `MOVEA *ZEROS ARRB` | `ARRB = ARR;`, `CHRARR = *blanks;`, `ARRB = *zeros;` |
| the "Not converted" lines | each kept as comment, R |

## MOVE and MOVEL (FREE-08)

Source: SC09-1818 chapter 27 and SC09-1817 chapter 11 (the move operations), the ILE RPG reference (`%SUBST` as the target of an assignment). `MOVE` moves right-justified, `MOVEL` left-justified; the rest of the result field keeps its old value (no `P`), so both lengths must be known. `IAfreeCvt` gives `IAfreeCalc` the length and type of the fields of the I specifications and of the arrays of the E specifications (`CalcDefineField`); a field that a result field defines is known as well. Only these fields, literals and figurative constants are converted; a field of any other origin (data structure subfields, external fields) is R. Lengths below are the lengths `LR` of the result and `LF` of factor 2.

| Source | Becomes | Status |
|---|---|---|
| alphanumeric to alphanumeric, `LF = LR` | `R = F2;` | C |
| `MOVE`, `LF > LR` | `R = %subst(F2:LF-LR+1);` (the right end of factor 2) | C |
| `MOVE`, `LF < LR` | `%subst(R:LR-LF+1:LF) = F2;`; with `P` `R = *blanks;` first | C |
| `MOVEL`, `LF > LR` | `R = %subst(F2:1:LR);` | C |
| `MOVEL`, `LF < LR` | `%subst(R:1:LF) = F2;`; with `P` `R = F2;` | C |
| character literal as factor 2 | the same, with the length of the literal | C |
| `*BLANK(S)` to an alphanumeric result | `R = *blanks;` | C |
| `*ZERO(S)` to a numeric or alphanumeric result | `R = 0;` or `R = *zeros;` | C |
| numeric field to a numeric result with the same digits and decimal positions (any of zoned, packed, binary), or a numeric literal with the digits of the result and no decimals | `R = F2;` | C |
| a result field with a length (`MOVE X NEWFLD 10`) | declared as for the other operations: alphanumeric without decimal positions, numeric with | C |

Reported R: alphanumeric to numeric and numeric to alphanumeric, numeric of another length or decimal positions (the rest of the result keeps its digits), `P` on a numeric result, other figurative constants, a field of unknown length or type, and resulting indicators. `MOVEA` is still R.

`samples/FREEMOV.rpg36` has one line for each row. Fields: `NAME` char(20), `CODE` char(5), `CUSTNO` and `ACCT` zoned(6:0), `BAL` packed(9:2). Expected result, written from the design and not from a run:

| Line | Expected |
|---|---|
| `MOVE NAME NAME2 20` | `dcl-s NAME2 char(20);`, `NAME2 = NAME;` |
| `MOVE NAME CODE` / `MOVE CODE NAME` / `MOVE CODE NAME` with `P` | `CODE = %subst(NAME:16);` / `%subst(NAME:16:5) = CODE;` / `NAME = *blanks;` and `%subst(NAME:16:5) = CODE;` |
| `MOVEL NAME CODE` / `MOVEL CODE NAME` / with `P` | `CODE = %subst(NAME:1:5);` / `%subst(NAME:1:5) = CODE;` / `NAME = CODE;` |
| `MOVE 'AB' CODE`, `MOVEL 'ABCDE' CODE` | `%subst(CODE:4:2) = 'AB';`, `CODE = 'ABCDE';` |
| `MOVE *BLANK NAME`, `MOVE *ZERO ACCT`, `MOVE *ZEROS CODE` | `NAME = *blanks;`, `ACCT = 0;`, `CODE = *zeros;` |
| `MOVE CUSTNO ACCT` | `ACCT = CUSTNO;` |
| numeric to alphanumeric and back, `BAL` to `ACCT`, literal `5` to `ACCT`, unknown field, `*HIVAL`, `P` on a numeric result, a resulting indicator | each kept as comment, R |

## Output specifications to a printer file DDS (FREE-06)

Decision (user, 2026-10-25): the output of a PRINTER file is made as an externally described printer file. First increment: RPG II and RPG III (RPG36, RPG38, RPG, SQLRPG), module `IAfreeOut`. The DDS source is written as comments at the end of the converted member (a separate `DDSTGT` member is the next step).

| Source | Result | Status |
|---|---|---|
| `O` record line type `E` (exception) of a PRINTER file declared by a converted F specification, with its field lines | a record format of the printer DDS, named as the EXCPT name (columns 32-37; with a two-digit number when several records have the name; `EXCPT` for no name) | A (DDS not tested) |
| Space before / after (columns 17-18), skip before / after (19-22) | `SPACEB(n)`, `SPACEA(n)`, `SKIPB(n)`, `SKIPA(n)` (`A0`-`A9` are 100-109, `B0`-`B2` are 110-112). `SPACEA(0)` is always written: a blank entry means no spacing in RPG but the DDS default is one line | C |
| Output indicators of a field line (23-31) | DDS conditioning indicators of the field (`N01`, ` 02`) | C |
| Output indicators of a record line (and AND lines) | the condition of the `write`: `if *in01 and not *in02; write DETAIL; endif;` | C |
| Constant (45-70) with an end position | a constant at line blank, position = end - length + 1 | C |
| Character or unedited numeric field (name 32-37, end position 40-43) | field with length and type of the definition (`A`, or `S` with decimals), usage `O`, position = end - length + 1 | C |
| `EXCPT NAME` in the calculations | one `write FORMAT;` for each record format with the name, in source order | A |
| `EXCPT` without a name | the formats of the exception records without a name | A |
| Heading, detail and total records (types H, D, T) with the cycle skeleton (FREE-36) | a record format `HEAD01`, `DETAIL01`, `TOTAL01` (next free number); H and D are written at step 1 of the cycle, T at the end of `IA_TOTALS` (see below) | A |
| Heading, detail and total records without the cycle skeleton | whole record as comments | R |
| `MR`, `RT` output indicators; ADD, DEL, fetch overflow, release (16-18) | comments | R |
| Edit codes (38) on a numeric field, edit words, blank after (39), data format P, B, L, R (44), relative end positions, `PAGE`, `UDATE` and the like, `*PLACE`, array elements | comments | R |
| A field without a known length (not defined by I, E or a result field) | the record format is not generated | R (the `write` has to be fixed by hand) |
| A second printer file, a file that is not a converted PRINTER file | comments | R |

Open: the DDS line position (columns 39-41) is left blank so that `SPACEA`, `SPACEB` and `SKIP` place the record: confirm with `CRTPRTF` on the first test. Edited numeric fields need the width of each edit code (next step); heading, detail and total records need the cycle.

Sample: `samples/FREEO.rpg36`. Expected: record formats `HEAD` (constant at position 8, `SPACEB(1)`, `SPACEA(1)`), `DETAIL` (`SPACEA(1)`, `NAME` at 6, `TOTAL` at 32 conditioned by `01`), `EXCPT01`...; the `H` record and `EDITED` stay R; `EXCPT HEAD` becomes `write HEAD;`, `EXCPT DETAIL` becomes `if not *in02; write DETAIL; endif;` inside `if *in01`.

## Arrays and tables (FREE-07)

Source: SC09-1818 chapter 20 (RPG II), SC09-1817 chapter 9 (RPG III), ILE RPG reference (`dcl-s` keywords `DIM`, `PERRCD`, `CTDATA`, `ALT`, `ASCEND`, `DESCEND`; compile-time data, "Coding a Compile-Time Array"). Columns of the E specification: 11-18 from file, 19-26 to file, 27-32 name, 33-35 entries per record, 36-39 entries per array, 40-42 length, 43 packed or binary, 44 decimal positions, 45 sequence, 46-51 second array of an alternating pair with 52-54 length, 55 packed or binary, 56 decimal positions, 57 sequence.

| Source | Becomes | Status |
|---|---|---|
| Run-time array (columns 33-35 blank) | `dcl-s NAME char(len) dim(n);`, `zoned(len:dec)` when column 44 has decimal positions | C |
| Compile-time array (columns 33-35 filled, no file) | `dcl-s NAME type dim(n) perrcd(k) ctdata;` | C |
| Sequence A or D (column 45) | `ascend` or `descend` | C |
| Alternating pair (columns 46-57) | the main array as above, and `dcl-s ALT type dim(n) alt(NAME);` for the second array (`ALT` is on the alternating array, `PERRCD` and `CTDATA` only on the main one) | C |
| Table (name starts with `TAB`) | declared as an array with the index field `NAME_IDX` | A: in RPG II the table name in a calculation means the entry found by the last `LOKUP`; it is written `NAME(NAME_IDX)` (see "LOKUP and MOVEA") |
| The `**` record before compile-time data | `**CTDATA NAME`, the name of the next compile-time array or table in the order of the E specifications; the data records are copied as they are | C |
| A `**` section with no converted array | kept as it is | R |
| From file (11-18), to file (19-26), record address files, packed or binary format (43, 55), a name or length that is not valid, a name already defined | line kept as `// RPG II:` comment; a compile-time array that is not converted still owns its data section, so the sections stay in order | R |

Numeric entries are declared `zoned`, the format of the data records. Entries of a numeric array are limited to 15 digits and alphanumeric entries to 256 characters, as in the source. The C specifications keep their own rules: `SORTA` and `XFOOT` were already converted and now find their array; `LOKUP` and `MOVEA` are converted, see "LOKUP and MOVEA" below.

`samples/FREEE.rpg36` has one case for each row. Expected result, written from the design and not from a run:

| Lines | Expected |
|---|---|
| `WORK` 10 entries of 5 | `dcl-s WORK char(5) dim(10);` |
| `DAYS` 7 per record, 7 entries of 3 | `dcl-s DAYS char(3) dim(7) perrcd(7) ctdata;` |
| `TABCOD` 3 digits, A, with `TABAMT` 6 digits 2 decimals | `dcl-s TABCOD zoned(3:0) dim(10) perrcd(5) ctdata ascend;` (A: table) and `dcl-s TABAMT zoned(6:2) dim(10) alt(TABCOD);` |
| `AMT` 5 digits 2 decimals, D | `dcl-s AMT zoned(5:2) dim(8) perrcd(4) ctdata descend;` |
| `FILARR` with a from file, `PCKARR` with P, `BADLEN` length 300, a second `DAYS` | each kept as comment, R; `PCKARR` still owns a data section |
| the four `**` sections | `**CTDATA DAYS`, `**CTDATA TABCOD`, `**CTDATA AMT`, and the fourth kept as `**`, R |

## String operations (FREE-12)

`samples/FREESTR.rpg38` has one line for each rule of the string operations table above. Expected result, written from the design and not from a run:

| Line | Expected |
|---|---|
| `FIRST CAT LAST:1 NAME 30` | `NAME = %trimr(FIRST) + ' ' + LAST;`, `dcl-s NAME char(30);`, A |
| `FIRST CAT LAST:0 NAME2 30 P` | `NAME2 = %trimr(FIRST) + LAST;`, C |
| `FIRST CAT LAST FULL 60` | `FULL = FIRST + LAST;`, A |
| `CAT TAIL:2 NAME` | `NAME = %trimr(NAME) + '  ' + TAIL;`, A |
| `'AB' SCAN STRING:T POS 3 0` | `POS = %scan('AB':STRING:T);`, `dcl-s POS zoned(3:0);`, A |
| `KEY:3 SCAN STRING POS` | `POS = %scan(%subst(KEY:1:3):STRING);`, A |
| `'AB' SCAN STRING`, found indicator 90 | `*IN90 = (%scan('AB':STRING) > 0);`, A |
| `'AB' SCAN STRING POS`, found indicator 91 | `POS = %scan('AB':STRING);` and `*IN91 = (POS > 0);`, A |
| `DIGITS CHECK STRING:2 N 3 0`, found 92 | `N = %check(DIGITS:STRING:2);`, `*IN92 = (N > 0);`, A |
| `' ' CHEKR STRING LEN 3 0` | `LEN = %checkr(' ':STRING);`, A |
| `3 SUBST STRING:T OUT 10` | `OUT = %subst(STRING:T:3);`, `dcl-s OUT char(10);`, A |
| `3 SUBST STRING:T OUT2 10 P` | `OUT2 = %subst(STRING:T:3);`, C |
| `SUBST STRING:T OUT` | `OUT = %subst(STRING:T);`, A |
| `SUBST` with error indicator 93 | R (needs MONITOR) |
| `SCAN` with `P` | R (extender not allowed) |
| `SCAN` without result field and indicator | R |
| `CAT` with `*BLANK`, `CAT` with `LAST:N` | R (figurative constant; variable number of blanks) |
| `XLATE` | R |

## Embedded SQL (SQLRPG) to free form (FREE-11)

Source: SC09-1816 (RPG/400 User's Guide), chapter 1, "The Structured Query Language". The rules there: the delimiter `/EXEC SQL` is in columns 7-15 with the slash in column 7; the statement can start on the same line and go on over any number of lines with `+` in column 7; statements cannot go past column 74; `/END-EXEC` is in columns 7-15 on a line of its own. Only for the RPG III dialect (`SQLRPG`); in `RPG36` the lines stay R (compiler directive).

| Source | Becomes | Status |
|---|---|---|
| `C/EXEC SQL` (text after column 15 optional), `C+` lines (columns 8-74), `C/END-EXEC` | `exec sql <first line>`, the other lines of the statement under it, indented one level, and the closing `;` on the last line. The SQL text is not changed and every source line stays one output line | C |
| `C* comment` between the lines of a statement | `// comment`, written before the statement | C |
| A `--` comment at the end of the last line | The `;` goes on a line of its own, so the comment cannot hide it | C |
| `WHENEVER ... GOTO label` | Converted as written; `TAG` is not converted, so the label does not exist in the result | A |
| The first statement outside a subroutine | Also carries the cycle note, as the first calculation does | A |
| Conditioning indicators before `C/EXEC SQL`, `EXEC SQL` in a `CASxx` group, a `;` in the SQL text outside a literal, no SQL text, more than 200 lines | Lines kept as `// RPG III: ...` | R |
| `C/EXEC SQL` without `C/END-EXEC` (the next specification ends it), `C/END-EXEC` or `C+` without `C/EXEC SQL` | Lines kept as comments | R |

Host variables (`:name`) are not changed. A field that is only used in an SQL statement and defined nowhere else is not declared; the SQL precompiler reports it. The converted member must be compiled as `SQLRPGLE` (`CRTSQLRPGI`); `C/EXEC SQL INCLUDE SQLCA` is converted to `exec sql include sqlca;` (check on the first compile that the precompiler accepts it in a free-form source). SQL in `/COPY` members is not allowed in RPG/400, so nothing is converted there.

`samples/FREESQL.sqlrpg` has one case for each row. Expected result, written from the design and not from a run:

| Lines | Expected |
|---|---|
| `C/EXEC SQL INCLUDE SQLCA` + `C/END-EXEC` | `exec sql include sqlca;`, converted (cycle note, A) |
| `Z-ADD 1 KEY 5 0` | `dcl-s KEY zoned(5:0);` at the top, `KEY = 1;` |
| `C/EXEC SQL` + 3 `C+` lines (a comment line between) | the comment, then `exec sql select count(*)`, `into :CNT`, `from CUSTMAS`, `where CUSTNO = :KEY;` on separate lines (SQL text as typed) |
| `IFGT` + `C/EXEC SQL UPDATE ...` + `END` | the statement indented inside `if KEY > 0;` ... `endif;` |
| `DELETE FROM WORKFILE -- clear the work file` | `exec sql DELETE FROM WORKFILE -- clear the work file` and `;` on the next line |
| `WHENEVER SQLERROR GOTO ERR` | `exec sql WHENEVER SQLERROR GOTO ERR;`, A (TAG) |
| `C   01` before `C/EXEC SQL` | indicator line and statement as `// RPG III:` comments, R |
| `C/EXEC SQL` with no `C/END-EXEC`, then `ADD 1 KEY` | statement kept as comments, R; `ADD` converted; the `C/END-EXEC` after it R |

## More mapping tables

To be written with the converter, one section per specification type (E, I, C, O), in the same form as `OCL-MAPPING.md` and `DSPF-MAPPING.md`.

## Multiple-occurrence data structures and OCUR (RPG III)

`samples/FREEOCC.rpg38` has one line for each row. Expected result, written from the design and not from a run:

| RPG III | Free-form | Status |
|---|---|---|
| data structure line with columns 44-47 (number of occurrences, 1 to 9999) | `dcl-ds NAME occurs(n);` (with `inz` for the option `I`) | A |
| `OCUR` with factor 1 | `%occur(ds) = factor1;` | A |
| `OCUR` with a result field | `result = %occur(ds);` (the result is declared when columns 49-52 give a length) | A |
| `OCUR` with both | the two statements in this order | A |

Reported R: the error indicator of `OCUR` (occurrence out of range; needs `MONITOR`), a factor 2 that is not a data structure with occurrences, a factor 1 that is a data structure, a result field with decimal positions, `OCUR` with no factor 1 and no result, and a data structure line with a length (columns 48-51) or other entries in columns 43-70.

## RPG IV: BITON, BITOF, TESTB, TESTZ (FREE-22, RV-50)

`ConvertC` of `IAfreeFx4` converts these with the same expressions as the RPG II and III conversion (see "TESTN, TESTZ, BITON, BITOF, TESTB"), written as `*inNN = (test);` for each resulting indicator and `FLD = %bitor(FLD : x'mask');` or `%bitand(FLD : x'inverse')` for the bit setting. The result field must be a declared character field (one position for the bit operations, any length for `TESTZ`; the D specification gives the type); factor 2 is a bit number text (`'036'`), a hexadecimal literal (`X'88'`) or a declared one-position character field. `TESTZ` and `TESTB` with a field are assumptions (A) with the reason of the RPG III conversion. Reported R: a result field that is not declared, not character or (bit operations) not one position, a length or decimals on the result field, an operation extender, bit numbers other than 0 to 7, repeated bit numbers, resulting indicators on `BITON` or `BITOF`, no resulting indicator on `TESTB` or `TESTZ`, indicator 2 of `TESTB` for one bit.

## RPG IV input specifications of program described files (FREE-23, RV-55)

`samples/FREE4I.rpgle` has one line for each row; `ConvertI` of `IAfreeFx4` reads the columns of the RPG IV I specification (file 7-16, sequence 17-18, record identifying indicator 21-22, codes 23-46; fields: data attributes 31-35, format 36, from 37-41, to 42-46, decimals 47-48, name 49-62, level 63-64, matching 65-66, relation 67-68, indicators 69-74). Expected result, written from the design and not from a run:

| RPG IV | Free-form | Status |
|---|---|---|
| record line of a DISK or SEQ file with record length (F specification format `F`), alphabetic sequence entry, no indicator and no codes | `dcl-ds FILE_REC len(n);` ... `end-ds;` | A (the READ and CHAIN of the file must name it) |
| field: format blank or `A` | `dcl-subf NAME char(len) pos(from);` (blank with decimals: `zoned`) | C |
| field: `S` | `zoned(len : dec)` | C |
| field: `P` | `packed(2*len-1 : dec)` | C |
| field: `B` (2 or 4 bytes) | `bindec(4 or 9 : dec)` | C |
| field: `I`, `U` (1, 2, 4, 8 bytes) | `int(3, 5, 10, 20)`, `uns(...)` | C |
| field: `F` (4 or 8 bytes) | `float(4)` or `float(8)` | C |
| field: `N` (one position) | `ind` | C |
| `READ`, `READP`, `READE`, `READPE`, `CHAIN`, `UPDATE` of such a file with no result field | the result field becomes `FILE_REC` | C |

Reported R: an externally described file (field renames and field indicators: RV-30), a file that no converted F specification declares, a file that is not DISK or SEQ, a second record type (AND/OR lines, record identification codes, a second record line for the file), a record identifying indicator, `**` (look-ahead), sequence checking (numeric sequence, columns 19-20), control level, matching fields, field record relation and field indicators, data attributes (`*VAR`, date and time formats), the formats `L`, `R`, `D`, `T`, `Z`, `C`, `G`, a field name that is not a simple name (array element, `*IN`, `PAGE`), a field already declared, and a field past the record length. A field that cannot be converted is kept as a comment inside the data structure; when none can be converted the whole block stays R.


## RPG IV: MOVEA of arrays and DEFINE *LIKE with a length change (FREE-31, RV-50)

`samples/FREE4MV.rpgle` has one line for each row. `IAfreeFx4` knows the `DIM` text of every array of the D specifications (`g_arrDim`) and its type through the symbol table. The operation code of RPG IV is `DEFINE`; `DEFN` is the RPG II and III name. `OpOf` and `ConvertC` read both as `DEFN`, so the converted `*LIKE` lines of `samples/FREE4C.rpgle` (written there as `DEFN`, which RPG IV does not accept) now use the real name. Expected result, written from the design and not from a run:

| RPG IV | Free-form | Status |
|--------|-----------|--------|
| `MOVEA Names Copy`, same `DIM` and same element type | `Copy = Names;` | C |
| `MOVEA *BLANKS Names` (alphanumeric array) | `Names = *blanks;` | C |
| `MOVEA *ZEROS Nums` | `Nums = *zeros;` | C |
| `*LIKE DEFINE Name Name2` | `dcl-s Name2 like(Name);` (before the first calculation) | C |
| `*LIKE DEFINE Name Longer + 5`, `- 4` | `dcl-s Longer like(Name : +5);`, `like(Name : -4)`; the symbol table gets the changed length | C |
| `*LIKE DEFINE Amt Bigger + 2` (packed, zoned) | `dcl-s Bigger like(Amt : +2);` | C |

Reported R: `MOVEA` with an index, from or to a field, between arrays of another `DIM`, another element type or length, `MOVEA *BLANKS` to a numeric array, a length change on a type other than `char`, `packed` or `zoned` (integer, float, date), a length that falls below 1 or the decimal positions, a result field that is already declared, and `*DTAARA DEFINE` (the reason names the `DTAARA` keyword: the definition is already written when the C specification is read). Open: `MOVE`/`MOVEL` of other type pairs, `IN`/`OUT` of a data area for RPG IV.

`MVR` with decimals (FREE-32): after a `DIV` without half adjust whose operands are declared numeric fields or numeric literals, `MVR` is written as `REM = DIVIDEND - QUOTIENT * DIVISOR;` (status A: check the decimal positions of the result); whole-number operands still give `%rem`. R: the `DIV` result field is its own dividend or divisor (the operand was overwritten; this also applies to the `%rem` form), half adjust, an undeclared operand. `samples/FREE4MV.rpgle` (last lines).

## RPG IV: data areas, *DTAARA DEFINE, IN, OUT (FREE-33, RV-11, RV-50)

Source: SC09-2508 (7.3), `DEFINE`, `IN`, `OUT`, and the `DTAARA` keyword. In RPG IV the data area of a field is the `DTAARA` keyword of its definition, and `*DTAARA DEFINE` of the C specifications is only the older way of saying it. `ConvertD` of `IAfreeFx4` reads the C specifications (`DefineDtaara`) and adds the keyword when it writes the definition; the `DEFINE` line then produces no statement. The external name is written as a literal in capitals, as in FREE-17. `samples/FREE4DA.rpgle` has one line for each row. Expected result, written from the design and not from a run:

| RPG IV | Free-form | Status |
|--------|-----------|--------|
| `*DTAARA DEFINE TOTDA Total`, `Total` a stand-alone field | `dcl-s Total packed(9 : 2) dtaara('TOTDA');` | C |
| `*DTAARA DEFINE *LDA MyDs`, `MyDs` a data structure | `dcl-ds MyDs dtaara('*LDA');` | C |
| `*DTAARA DEFINE` with factor 2 blank | the name of the field is the data area: `dtaara('OWN')` | C |
| `*LOCK IN Total`, `IN Total`, `OUT Total`, `*LOCK OUT Total` | `in *lock Total;`, `in Total;`, `out Total;`, `out *lock Total;` | C |
| `IN(E) MyDs` | `in(e) MyDs;` | C |
| `IN *DTAARA`, `OUT *DTAARA` | `in *dtaara;`, `out *dtaara;` | C |

Reported R: a `DEFINE *DTAARA` with a length, decimals or a conditioning indicator (the field is defined by the result field), whose result field is a subfield or is not declared in the D specifications, `IN` or `OUT` with another factor 1 than `*LOCK`, without factor 2 or with a result field, resulting indicators (the error indicator is not converted; use the `(E)` extender). The data area of a field is not checked by the converter: `IN Plain` for a field without the keyword is left to the compiler. `UNLOCK` of a data area is written by the file operation path, which gives the same `unlock NAME;`.

## RPG IV: MOVE(P) of character fields (FREE-34, RV-50)

`samples/FREE4MV.rpgle` (last lines). `MoveStmt` of `IAfreeFx4`: with the `(P)` extender the result field is blanked and the source is placed at the right end (`MOVE`) or the left end (`MOVEL`); both fields must be declared character fields of a known length. Expected result, written from the design and not from a run (`Wide` 10, `Narrow` 4):

| RPG IV | Free-form | Status |
|--------|-----------|--------|
| `MOVE(P) Narrow Wide` (source shorter) | `Wide = *blanks;` then `%subst(Wide : 7 : 4) = Narrow;` | A |
| `MOVE(P) Wide Narrow` (source longer) | `Narrow = %subst(Wide : 7);` | A |
| `MOVE(P)` of two fields of the same length | `Wide = Same;` | A |
| `MOVE(P) 'AB' Wide` | `Wide = *blanks;` then `%subst(Wide : 9 : 2) = 'AB';` | A |
| `MOVEL(P) Narrow Wide` | `Wide = Narrow;` (was already converted) | A |

`MOVE`/`MOVEL` of other type pairs (character and numeric, numeric of another length or decimal positions) stay R: the digits are moved without the decimal point and the sign goes into the zone, so no assignment gives the same result.

## GOTO, CABxx and TAG (RPG II and III)

Free-form has no GOTO, so three patterns are rewritten; the plan is made before the first line is written (`CalcJumpScan`, `BuildJumpPlan`). Each is reported A.

| Pattern | Result |
|---|---|
| `GOTO` or `CABxx` with a condition to a later `TAG` in the same group | `if not (cond);` ... `endif;` at the `TAG` |
| jump to a `TAG` that is the last statement of the subroutine or program | `leavesr;` or `return;` (with `if cond;` when conditioned) |
| one `GOTO` or `CABxx` back to an earlier `TAG` in the same group | `dou not (cond);` (`dow *on;` without a condition) at the `TAG`, `enddo;` at the jump |
| a jump inside such a loop to the `TAG` right after it | `leave;` |

Everything else stays R: two jumps back to one `TAG`, jumps into or out of groups, over `ELSE`, `BEGSR` or `ENDSR`, crossing patterns, duplicate labels, level indicators, CAB result indicators, `CASxx` in the source, and jumps in RPG IV.

## RPG II and III: the program cycle as a skeleton (FREE-36, RV-20, RV-21, RV-52, decided 2026-10-27)

Source: SC09-1818 (the RPG program cycle, steps 1 to 11, and the control level rules), SC09-1816. Decision: the cycle is written as a `dow` loop that the programmer completes; every part is marked A. First increment, `samples/FREECYC.rpg36`:

- **Accepted:** one primary file (column 16 `P`), input, program described, no other file with `P`, `S`, `R` or `T`, whose I specification has one record type and a record layout (FREE-04). Control levels `L1` to `L9` in columns 59-60 of its field lines. Calculation lines with a control level (columns 7-8: `L0` to `L9`, `LR`) are total calculations; the level indicators `L1` to `L9` as conditioning indicators (columns 9-17) are `*INL1` to `*INL9`.
- **Written for the primary file `SALES` with the levels `L1` (`CUST`) and `L2` (`REGION`)** (expected text, written from the design and not from a run):

| Part | Free-form |
|------|-----------|
| declarations (before the first calculation) | `dcl-s IA_FIRST ind inz(*on);` and `dcl-ds IA_NEXT likeds(SALES_REC);` |
| loop | `dow *on;` ... `enddo;` |
| step 2, LR check | `if *inlr; leave; endif;` then `*inl1 = *off;` and `*inl2 = *off;` |
| step 3 | `read SALES IA_NEXT;` the new record is read into `IA_NEXT`, so the total calculations still see the fields of the previous record; `if %eof(SALES); *inlr = *on; leave; endif;` |
| steps 4 and 5 | first record: every control level on (the control fields are compared with zeros in RPG); else `select; when IA_NEXT.REGION <> REGION; *inl1 = *on; *inl2 = *on; when IA_NEXT.CUST <> CUST; *inl1 = *on; endsl;` (the highest level first, all lower levels on) |
| steps 6 and 7 | `if not IA_FIRST; exsr IA_TOTALS; endif;` (total time is bypassed on the first record) |
| step 10 | `SALES_REC = IA_NEXT;` and `IA_FIRST = *off;` |
| step 11 | the detail calculations (lines without a control level), as FREE-05 converts them |
| last cycle | after `enddo;`: `*inlr = *on;`, every control level on, `exsr IA_TOTALS;` |
| total calculations | `begsr IA_TOTALS;` ... `endsr;`: the lines with a control level, each conditioned by its level (`if *inl1; ... endif;`, `L0` always, `LR` is `*inlr`) |

The control level stays on during the detail calculations of the record that caused the break and is turned off at the start of the next cycle (step 2). The loop closes before the first `BEGSR` or at the end of the source; when no calculation line exists the loop is still written. A `GOTO` to the last `TAG` of the detail calculations (RV-14) becomes `iter`, the next cycle. Step 1 (heading and detail output of the previous record) and the total output are not part of it: the O specifications still need FREE-06; a comment marks the place.

Reported R, as before: secondary, record address and table files, more than one primary file, an update primary file, an externally described primary file, more than one record type, record identifying indicators and codes, matching fields (`M1` to `M9`, `MR`), look-ahead fields, `1P`, field indicators and field record relations, a level on an `AN` or `OR` group other than that of its first line, a jump that crosses from the detail to the total calculations. Total calculations after the first subroutine are not placed in `IA_TOTALS`.

## Printer DDS in a second member (FREE-06, RV-63)

New parameters `DDSTGT` (file, library and member), `DDSTYPE` (default `PRTF`) and `DDSIFS` of `IACNVFREE`; usage in `docs/BUILD.md`. Without `DDSTGT` nothing changes: the DDS is kept as `//` comments at the end of the converted source. With it (`FreeConvert` of `IAfreeCvt`):

| Part | Result |
|------|--------|
| the end of the converted source | two comment lines: the DDS is written to the DDS target, create the printer file with `CRTPRTF`; the DDS lines are not repeated |
| DDS target | the lines of `OutDdsLine` are written unchanged (`     A` records, 80 characters, `C_WRAP_NONE`) to the member named by `DDSTGT` (`*PRTF` is the name of the printer file) |
| validation | after the conversion and before the target is opened, with the rules of `TGT` (`ValidateIO` with converter 4, type `PRTF`); a failure writes nothing |
| same target | the DDS target equal to `TGT` is refused (IAC0105) |
| no printer output | `DDSTGT` is not used |

Written from the design, not from a run.

## Heading, detail and total records in the cycle skeleton (FREE-37, RV-60)

Source: SC09-1817 (output indicators, the 1P indicator, the program cycle). The record formats are made like the exception records (printer DDS, see above); the cycle skeleton of FREE-36 writes them. Without the skeleton the records stay R.

| Source | Free-form |
|---|---|
| H or D record | `write HEAD01;` at the start of each cycle (step 1: the output of the previous record, before the LR check); the fields are those of the previous record |
| T record | `write TOTAL01;` at the end of the subroutine `IA_TOTALS`, after the total calculations (step 7), also for the last cycle |
| output indicators on the record line | as for exception records: `*in01`, `not *in02` |
| `1P` (H and D only) | `IA_FIRST` (on in step 1 of the first cycle, before the first record is read) |
| `L1` to `L9`, `LR` | `*inl1` to `*inl9`, `*inlr`; the levels stay on during step 1 of the next cycle, as in RPG |
| AND lines | `and`; OR lines: `(a) or (b)`, for every record type including E |
| `MR`, `RT`, `1P` on T, a field line with a level indicator | R |

A heading or detail record without any indicator is also written on the first cycle (fields still blank), as RPG does. The numbers of the record formats follow the source order for each type.
