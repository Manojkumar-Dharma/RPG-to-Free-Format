# DSPF36 / DSPF38 to DSPF mapping (IACNVDSPF)

Implemented in `src/dspf/IAdspCvt.sqlrpgle`. The command is `IACNVDSPF` (program `IAcnvDspf`). The output is DDS source for a display file (target type `DSPF`, normally member type DSPF in QDDSSRC). Compile it afterwards with `CRTDSPF`.

## Sources and evidence

- DSPF36 is System/36 display format source (SFGR): S (display control), H (help) and D (field definition) specifications. Column layouts are in SC41-4730 *System/36 Environment Programming* Appendix B, which is in `docs/sc414730.pdf`.
- How `$SFGR` turns SFGR into DDS (`CRTS36DSPF`) is described in the same book, chapter 14: format names and ALTNAME, `*DDS` comments, data type mapping, `INDARA` and `INVITE`, right-to-left (`CHECK(RLTB)`), DFRWRT and FRCDTA.
- `SRCTYPE` must be `DSPF36` or `DSPF38`.
- DSPF38 is System/38 display DDS. It is accepted by `CRTDSPF` as it is, so it is copied unchanged.

Where the manuals do not give the generated DDS, the choice made here is marked **assumption** below. The report shows those lines with status A. Anything that is not converted is kept as a DDS comment and reported with status R.

## Source records (DSPF36)

Records are 80 columns. Columns 1-5 are a sequence number and are not used. Column 6 is the specification type.

| Record | Result |
|---|---|
| Blank line | Skipped |
| `*` in column 7 | DDS comment (`A` in column 6, text from column 8 unchanged) |
| `*DDS` in columns 1-4 and `*` in column 7 | DDS line inserted as is: column 6 becomes `A`, column 7 becomes blank (as `$SFGR` does) |
| `S` | Start of a record format (below) |
| `H` | A help area (below). Before the first `S`: reported R and skipped |
| `D` | One field or constant text (below) |
| Anything else | Kept as a DDS comment, status R |

A `D` record before the first `S` is reported R and skipped.

## File level DDS (from the S records)

| Keyword | Rule |
|---|---|
| `DSPSIZ(24 80 *DS3)` | Always. `DSPSIZ(24 80 *DS3 27 132 *DS4)` when any S record has Y in column 39 |
| `INDARA` | Always (SC41-4730 chapter 14: separate indicator area is required in the System/36 environment) |
| `CHECK(RLTB)` | When the first S record has Y in column 40 (only the first format counts, as in the manual) |

## S specification: record format

| S columns | DDS |
|---|---|
| 7-14 name | `R name`. A name that is not valid in DDS becomes `FMTn` and the original is kept with `ALTNAME('name')` (A) |
| 7-14 help format name `axxxxxnn` | `HLPSEQ(nn)` is added for an 8-character name of a letter, five letters or digits and two digits (SC41-4730 chapter 14) (A) |
| 17-18 start line | blank: nothing; `V`: `SLNO(*VAR)`; number: `SLNO(n)` |
| 19-20 lines to clear | blank: `CLRL(*ALL)`; `0`: `CLRL(*NO)`; number: `CLRL(n)` |
| 21 lowercase | Y makes input fields `LOWER` unless the D record says N (column 51) |
| 22 return input | N: nothing; otherwise `RTNDTA` |
| 25-26 sound alarm | Y: `ALARM`; indicator: `ALARM` conditioned by it |
| 27, 28, 64-79 keys | See keys below |
| 29-30 blink cursor | Y or indicator: `BLINK` |
| 31-32 erase input | Y or indicator: `ERASEINP` |
| 33-34 override | Y or indicator: `OVERRIDE`; see override below (A) |
| 35-36 suppress input | Y or indicator: `LOCK` |
| 37-38 null fill | No effect (the manual says the same) |
| 39 132 columns | Only the file-level `DSPSIZ` changes (A) |
| 40 right to left | See file level |
| all formats | `INVITE` is added (A). Needed for RUF and multi-device files in the System/36 environment |

### Keys (S columns 27, 28 and the mask in 64-79)

Column 27 is for function keys, column 28 for command keys. Blank means all enabled, `Y` only the listed keys, `N` all except the listed keys, `R` retain (no keyword). The mask lists function keys by digit and command keys by letter.

| Function key (digit) | Keyword | | Command key (letter) | Keyword |
|---|---|---|---|---|
| 1 Print | `PRINT` | | A to L = 1 to 12 | `CF01(01)` to `CF12(12)` |
| 2 Page Down | `ROLLUP` | | M, N = 13, 14 | `CF13(13)`, `CF14(14)` |
| 3 Page Up | `ROLLDOWN` | | P to Y = 15 to 24 | `CF15(15)` to `CF24(24)` |
| 4 Clear | `CLEAR` | | | |
| 5 Help | `HELP` | | | |
| 6 Home | `HOME` | | | |

Assumptions (A): command keys become `CFnn(nn)`, so data is returned with the key. The response indicator is the key number. The function key keywords are written without response indicators.

## D specification: field or constant

| D columns | Meaning |
|---|---|
| 7-14 | Field name (SFGR does not use it in the display) |
| 15-18 | Length |
| 19-20 | Line, relative to the start line |
| 21-22 | Column; `A0` to `D2` are 100 to 132 |
| 23-24 | Output data: Y, N, or an indicator |
| 26 | Input allowed |
| 27 | Data type |
| 56 | Constant type (C or M) |
| 57-79 | Constant data; X in column 80 continues it in columns 7-79 of the next record |

### Kind of record

| Output (23-24) | Input (26) | DDS |
|---|---|---|
| N or blank | not Y | Constant text at the line and column. A record with no text is skipped (A) |
| Y | not Y | With constant text (not a message field): constant text as above (A, reported once), because DDS rejects `DFT` on an output-only field without `OVRDTA` (CPD7620) and the program cannot send data to it. Without constant text: output field (`O`) |
| indicator | not Y | Output field conditioned by the indicator. Constant text, if any, is a constant conditioned by NOT the indicator |
| N or blank | Y | Input field (`I`). Constant text is not used (A) |
| Y | Y | Input/output field (`B`) |
| indicator | Y | Input/output field (`B`), status R: the output indicator is dropped |

Field names are kept when valid and unique in the format. Otherwise they become `FLDn` (A), because S/36 programs address display fields by position.

### Data types (D column 27)

From the table in SC41-4730 Appendix B: blank and B to A, A to X, M to N, N to M, S to S (length minus 1, 0 decimals), R to I, Z to A, D to D, K to W. The double-byte types E, F, O and X become A. Output-only fields are always A.

### Message fields (column 56 = M)

Columns 57-62 hold the message identification code (MIC, four characters 0-9 or A-F) and the message member (`U1` or blank, `U2`, `P1`, `P2`, `M1`, `M2`). SC41-4730 says `$SFGR` assumes the message ID prefix `USR`, and that DBCS messages (MIC above A000) have the prefix `USZ` (chapter 15).

On S/36 the member is tied to a message file only at run time (`// MEMBER` or `OVRMSGF`), so the converted display file needs the message file from the command parameter `MSGF(file library)` (one file for all message fields; `*NONE` by default).

| Output (23-24) | MIC | `MSGF` | Result |
|---|---|---|---|
| Y, no input | valid | given | `MSGCON(length USRnnnn [library/]file)` at the line and column, length = the D field length (A). A member other than U1 is reported in the same line; the one file is used |
| indicator, no input | valid | given | Output field conditioned by the indicator (the program sends the message) and `MSGCON` conditioned by NOT the indicator (A) |
| any | valid | not given | Kept as a program output field, status R, with the message id in the report |
| Y | blank or not valid | any | Kept as a program output field, status R: the program (or PROMPT) supplies the MIC at run time, which has no DDS equivalent |
| any | any | any, input allowed | Kept as an input/output field, status R |

`MSGCON` and its operand order are assumptions (A): the manual describes the S/36 side only, so confirm the first compile with `CRTDSPF`. The message file has to exist then.

### Edit code (column 25)

Column 25 is an edit code on the D specification form, marked WSU only. SC41-4730 gives no entry values and no DDS result for it, and the field length and decimals needed for `EDTCDE` are not in the D specification. A D record with an entry in column 25 is therefore converted as before and reported R (edit code not converted).

### Attributes and checks

| D columns | DDS |
|---|---|
| 39-40 | `DSPATR(HI)` |
| 41-42 | `DSPATR(BL)` |
| 43-44 | `DSPATR(ND)` |
| 45-46 | `DSPATR(RI)` |
| 47-48 | `DSPATR(UL)` |
| 49 | `DSPATR(CS)` |
| 37-38 (input) | `DSPATR(PR)` |
| 32-33 (input) | `DSPATR(PC)` |
| 28 | `CHECK(MF)` |
| 29 | `CHECK(ME)` |
| 30 | T: `CHECK(M10)`, E: `CHECK(M11)` |
| 31 | Z: `CHECK(RZ)`, B: `CHECK(RB)` |
| 35 | `CHECK(FE)` |
| 36 | `CHECK(AB)`, only together with `M10` or `M11`; DDS needs another validity checking keyword with it (CPD7656). Otherwise left out (A) |
| 34 | `DUP` |
| 51 (or S column 21) | `LOWER`, not on numeric fields |

Each attribute is Y (always) or an indicator. Always-on attributes are joined in one `DSPATR(...)`. An indicator-conditioned attribute is a keyword line conditioned by the indicator.

### Override (S columns 33-34)

When the format uses override: a field with an attribute controlled by an indicator gets `OVRATR`, and a field with an output indicator gets `OVRDTA` conditioned by that indicator (A).

## H specification: help area

H records follow an S record and come before its first D record. Each one is a help area: a rectangle of the display, and what the Help key shows while the cursor is in it (SC41-4730 Appendix B). Columns used:

| H columns | Meaning |
|---|---|
| 7-14 | Help format name (`axxxxxnn`), or the help text label of an online document |
| 16-23 | Display file that holds the help format, or the document name |
| 25-32 | Library of that display file, or the folder of the document |
| 34-37, 39-42 | Upper left and lower right corner, `rrcc` (column `A0` to `D2` for 100 to 132). Both blank is a null help area |
| 44-45 | Suppress selection: blank, or an indicator (when on, the area is ignored) |
| 47-48 | Restore the display format after help: `Y` or blank, `N`, or an indicator |
| 50-51 | Boundary for Page Up and Page Down: blank or `N`, `Y`, or an indicator |
| 53 | `Y` online document, blank or `N` help format |

DDS written for each H record, after the keywords of its format:

| Source | DDS (assumption A) |
|---|---|
| Area given | `HLPARA(row col row col)`, rows and columns as in the H record (like the D lines, relative to the start line; the S start line is not added) |
| Null area | `HLPARA(*NONE)` |
| Help format, blank 16-23 | `HLPRCD(format)`. The format is looked up in the whole source, so a format that is defined further down is found and a renamed one (`FMTn`) gets its DDS name. A name not in the source is used as it is when it is valid in DDS |
| Help format in another file | `HLPRCD(format lib/file)` (`file` alone when 25-32 is blank). When a name is not valid in DDS the record is ignored, as `$SFGR` does (SC41-4730 chapter 14): kept as a comment, status R |
| Online document | `HLPDOC(label document folder)`. Label, document and folder must all be given |
| Suppress indicator | `HLPARA` and `HLPRCD` or `HLPDOC` are conditioned by NOT the indicator |
| Boundary `Y` / indicator | `HLPBDY` / `HLPBDY` conditioned by the indicator |
| Restore `N` / indicator | `HLPRTN` / `HLPRTN` conditioned by NOT the indicator |

Not valid entries (Y or N in 44-45, a corner without the other, a row over 27, a lower right corner above or left of the upper left, a library without a file, and so on) are kept as a DDS comment and reported R. The manual only describes the DDS result for `HLPSEQ`; the other keywords, their order and the `HLPDOC` and `HLPRCD` operands are assumptions to confirm with `CRTDSPF`.

## DSPF38

Each line is copied unchanged and reported C. One report line (A) says the member should be compiled with `CRTDSPF` to confirm. Records longer than 80 columns are reported R.

## Not converted yet

Array fields (WSU only: the manual shows only the column labels elements per row or column, fill direction, line skip factor, horizontal positions and space factor, with no entry values), edit codes (reported, see above), and reduced behaviour for output indicators on input/output fields.

## Sample

`samples/EMPSCR.dspf36` is a small column-exact DSPF36 member (one format, constants, input and output fields, an indicator, a continued constant). Convert it first and send me the generated member and the report if anything looks wrong.

`samples/HELPSCR.dspf36` has four H records (help format of this source with a boundary, a format in another file with a library, restore N and a suppress indicator, an online document, and a null area) and two help formats. Expected DDS for the first format: `HLPARA(3 15 3 19)`, `HLPRCD(ORDHLP01)`, `HLPBDY`; then `HLPARA(5 15 5 30)` and `HLPRCD(ORDHLP02 MYLIB/ORDHELP)` both conditioned by `N05`, and `HLPRTN`; then `HLPDOC(ORDLBL ORDDOC ORDFLD)`; then `HLPARA(*NONE)` and `HLPRCD(ORDHLP03)`. The formats ORDHLP01 and ORDHLP03 get `HLPSEQ(1)` and `HLPSEQ(3)`.

`samples/MSGSCR.dspf36` has two message constants (U1 and U2 members), a message with an output indicator, a message field with no id and a field with an edit code. Convert it with `MSGF(MYLIB/ORDMSGF)` (any name; it must exist for `CRTDSPF`). Expected: `MSGCON(30 USR0001 ORDMSGF)` at line 1 column 2; `MSGCON(40 USR000A ORDMSGF)` at line 3 (member U2 noted in the report, A); `ERRMSG` as a 50-character output field conditioned by 07 and `MSGCON(50 USR0002 ORDMSGF)` conditioned by N07; `PGMMSG` as an output field, R; `AMOUNT` as written before, R for the edit code.
