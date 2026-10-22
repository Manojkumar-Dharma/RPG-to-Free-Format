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
| Y, no input | valid | given | An output field named `MSG1`, `MSG2`, ... of the D field length at the line and column, with `MSGID(USRnnnn [library/]file)` (A). The text is read from the message file when the program writes the record. A member other than U1 is reported in the same line; the one file is used |
| indicator, no input | valid | given | Output field conditioned by the indicator (the program sends the message) and a `MSGn` field with `MSGID` conditioned by NOT the indicator (A) |
| any | valid | not given | Kept as a program output field, status R, with the message id in the report |
| Y | blank or not valid | any | Kept as a program output field, status R: the program (or PROMPT) supplies the MIC at run time, which has no DDS equivalent |
| any | any | any, input allowed | Kept as an input/output field, status R |

`MSGID(message-id [library/]file)` is used instead of `MSGCON` because the message is read at run time, so `CRTDSPF` does not need the message descriptions. The message file must be on the library list (or the `MSGF` library given) when the program runs, and `OVRMSGF` can change it. The field is usage O, so the program cannot use it. For an output field under indicator 07 and a `MSGn` field under N07 at the same position `CRTDSPF` gives the warning CPD7865 (field overlaps); the file is still created and the two never show together.

### Edit code (column 25)

Column 25 is an edit code on the D specification form, marked WSU only. SC41-4730 gives no entry values and no DDS result for it, so the values are taken from the DDS `EDTCDE` keyword (1-4, A-D, J-Q, X-Z, and the user-defined 5-9), and IBM i DDS for display files says `EDTCDE` is only valid on output-capable numeric fields and that the display length grows by the editing characters.

| Field | Result |
|---|---|
| Output only, valid code | Written as zoned numeric (data type `S`, length as in the D record, 0 decimals: the D specification has no decimal positions) with `EDTCDE(x)` (A) |
| Input/output, data type S, valid code | `EDTCDE(x)` added to the signed numeric field (A) |
| Input/output, other data types | Not written, status R: `EDTCDE` needs a numeric-only field |
| Input only | Not written, status R |
| Code not in the list above | Not written, status R |
| Constant or message field | Ignored, status R |

The output length is a guess: if the S/36 field length already includes the editing characters, the converted field is too wide. Check the first conversion on the display.

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

DDS written for each H record, after the record-level keywords of its format and before its first field. Checked against the IBM i DDS reference (HLPARA, HLPRCD, HLPBDY, HLPDOC, HLPRTN, HLPSEQ) after `CRTDSPF` rejected the first version (CPD7486: the help keywords were written at record level):

| Source | DDS |
|---|---|
| Start of the area | A line with `H` in column 17 and `HLPARA(row col row col)` (rows and columns as in the H record, like the D lines; the S start line is not added). `HLPARA` takes no option indicator |
| Null area | `HLPARA(*NONE)` |
| Help format, blank 16-23 | `HLPRCD(format)`. The format is looked up in the whole source, so a format that is defined further down is found and a renamed one (`FMTn`) gets its DDS name. A name not in the source is used as it is when it is valid in DDS |
| Help format in another file | `HLPRCD(format lib/file)` (`file` alone when 25-32 is blank). When a name is not valid in DDS the record is ignored, as `$SFGR` does (SC41-4730 chapter 14): kept as a comment, status R |
| Online document | `HLPDOC(label document folder)`. Label, document and folder must all be given |
| Suppress indicator | `HLPRCD` or `HLPDOC` is conditioned by NOT the indicator (the specification is active when it is off) |
| Boundary `Y` / indicator | `HLPBDY` / `HLPBDY` conditioned by the indicator. Not written with `HLPDOC` (not allowed together), reported A |
| Restore display (47-48) | Not written: DDS has no keyword for it (`RSTDSP` is a `CRTDSPF` parameter; `HLPRTN` returns control to the program, which is something else). Reported A |
| Help format name `axxxxxnn` | `HLPSEQ(axxxxx nn)` on that format: group name = first 6 characters, sequence = last two digits (the group name is an assumption, A) |

The help areas only work with the `HELP` keyword without a response indicator (IBM i DDS for display files, `HELP`). It is added to the format, before the first H line, when the S specification did not already produce it.

Not valid entries (Y or N in 44-45, a corner without the other, a row over 27, a lower right corner above or left of the upper left, a library without a file, and so on) are kept as a DDS comment and reported R.

## DSPF38

Each line is copied unchanged and reported C. One report line (A) says the member should be compiled with `CRTDSPF` to confirm. Records longer than 80 columns are reported R.

## Not converted yet

Array fields (WSU only: the manual shows only the column labels elements per row or column, fill direction, line skip factor, horizontal positions and space factor, with no entry values), edit codes (written as EDTCDE, see above), and reduced behaviour for output indicators on input/output fields.

## Sample

`samples/EMPSCR.dspf36` is a small column-exact DSPF36 member (one format, constants, input and output fields, an indicator, a continued constant). Convert it first and send me the generated member and the report if anything looks wrong.

`samples/HELPSCR.dspf36` has four H records (help format of this source with a boundary, a format in another file with a library, restore N and a suppress indicator, an online document, and a null area) and two help formats. Expected DDS for the first format: an `H` line with `HLPARA(3 15 3 19)`, `HLPRCD(ORDHLP01)`, `HLPBDY`; then an `H` line with `HLPARA(5 15 5 30)` and `HLPRCD(ORDHLP02 MYLIB/ORDHELP)` conditioned by `N05` (the restore N is reported, not written); then an `H` line with `HLPARA(7 15 7 25)` and `HLPDOC(ORDLBL ORDDOC ORDFLD)` (its boundary Y is reported, not written); then an `H` line with `HLPARA(*NONE)` and `HLPRCD(ORDHLP03)`. The formats ORDHLP01 and ORDHLP03 get `HLPSEQ(ORDHLP 1)` and `HLPSEQ(ORDHLP 3)`.

`samples/MSGSCR.dspf36` has two message constants (U1 and U2 members), a message with an output indicator, and a message field with no id. Convert it with `MSGF(MYLIB/ORDMSGF)` (any name; it must exist for `CRTDSPF`). Expected: an output field `MSG1` with `MSGID(USR0001 ORDMSGF)` at line 1 column 2; `MSG2` with `MSGID(USR000A ORDMSGF)` at line 3 (member U2 noted in the report, A); `ERRMSG` as a 50-character output field conditioned by 07 and `MSG3` with `MSGID(USR0002 ORDMSGF)` conditioned by N07; `PGMMSG` as an output field, R;

`samples/EDTSCR.dspf36` has five D records with an edit code. Expected: `AMOUNT` as a 9-digit zoned output field with `EDTCDE(1)` (A); `BADCD` (code W) written without `EDTCDE`, R; `INONLY` (input only) written without `EDTCDE`, R; `BOTHFLD` as a signed numeric input/output field of 7 digits with `EDTCDE(J)` (A); the constant with an edit code written as a constant, R.

`samples/EDTALL.dspf36` has three formats that cover every edit code (1-4, A-D, J-Q, X-Z, 5-9: 24 codes). Expected results:

| Format | Fields | Expected |
|---|---|---|
| `EDTOUT` | `EO1` to `EO9`, `EOA` to `EOZ` (name = EO plus the code), output only, length 9 | Each as a 9-digit zoned output field (`S`, 0 decimals) with `EDTCDE(code)`, A |
| `EDTBOTH` | `EB1` to `EBZ`, input/output, data type S, length 8 | Each as a 7-digit signed numeric input/output field with `EDTCDE(code)`, A |
| `EDTMISC` | `ELOWOUT` (code j), `ELOWBOTH` (code z, data type S) | Lowercase is accepted: `EDTCDE(J)` and `EDTCDE(Z)`, A |
| `EDTMISC` | `BADW`, `BADE`, `BAD0`, `BADDASH` (codes W, E, 0, -) | Field written without `EDTCDE`, R (not a DDS edit code) |
| `EDTMISC` | `INONLY` (input only) | Written without `EDTCDE`, R |
| `EDTMISC` | `BOTHALP`, `BOTHNUM`, `BOTHDIG` (input/output, data types A, N, D) | Written without `EDTCDE`, R (needs data type S) |
| `EDTMISC` | constant `TOTAL:` with code 1 | Written as a constant, R (edit code ignored) |

Note the letters W and E: they are not DDS edit codes (W and E are RPG codes only), so they must be reported, not passed through. If a real S/36 member shows other values in column 25, add them to the table above and to `C_EDTCDES` in `IAdspCvt`.

