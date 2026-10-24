# RPG II to fully free-form RPG (IACNVFREE)

Status: decisions and evidence for FREE-01 to FREE-08. FREE-03 (control and file description specifications), FREE-04 (input specifications) and FREE-05 (calculation specifications, with the rule tables) are written and not compiled or tested yet; the other specifications are kept as comments.
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
| Other directives such as `/COPY` | comment | R |
| E, L, O specifications | `// RPG II:` and the line | R (FREE-06, FREE-07) |
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
| 24 | ` /COPY QRPGSRC,MYCOPY` | `// RPG II:  /COPY QRPGSRC,MYCOPY` | R | directive /COPY is not converted |
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
| `rpg36-opcodes.json` | IACNVOPC | Every operation code of SC09-1818 chapter 27: kind, whether factor 1, factor 2 and the result field are required (`R`), optional (`O`) or blank (`-`), the test of each resulting indicator column, half adjust allowed, status (C, A, R), the free-form template (`{F1}`, `{F2}`, `{RES}`; a second one when factor 1 is blank), the built-in functions it needs, the reason when not converted, the source |
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
| `CHAIN`, `READ`, `READE`, `READP`, `SETLL`, `ACQ`, `NEXT`, `POST`, `REL` | comment | R: file operations need the record layout from the I specifications (FREE-04) or the display file (later item) |
| `EXCPT` | comment | R: converted with the O specifications (FREE-06) |
| `GOTO`, `TAG` | comment | R: no replacement in free-form |
| Unknown operation code, wrong factor entries (required missing, blank given), a built-in function newer than the target release | comment | R |

A line that is not converted is kept as `// RPG II: ...`. When it opens a group (IFxx, DO, DOWxx, DOUxx, CASxx) a placeholder group is opened, so that the END of it is reported R too and the converted groups stay in balance. Everything inside such a group is still converted: read the report before using the result.

Fields that are defined by I, E or O specifications or by other lines are not declared (FREE-04, FREE-07); the result will not compile until those are converted. `samples/FREEC.rpg36` has one line for each rule above; the expected result of each line is what this table says (written from the design, not from a run).

## More mapping tables

To be written with the converter, one section per specification type (E, I, C, O), in the same form as `OCL-MAPPING.md` and `DSPF-MAPPING.md`.
