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
| 31-32 erase input | Y or indicator: `ERASEINP`, with `OVERLAY` added on the format because DDS requires it (CPD7567, CPD8111) (A) |
| 33-34 override | Y or indicator: `PUTOVR` (conditioned by the indicator). DDS has no `OVERRIDE` keyword (CPD7484); see override below (A) |
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
| indicator | Y | Input/output field defined twice with the same name (A): `B` conditioned by the indicator (the program's data is shown while it is on) and `I` conditioned by NOT the indicator (input only, no data sent, while it is off). Attributes, checks and `LOWER` are written under both; `EDTCDE` and `OVRDTA` only under the `B` one |

Field names are kept when valid and unique in the format. Otherwise they become `FLDn` (A), because S/36 programs address display fields by position.

### Data types (D column 27)

From the table in SC41-4730 Appendix B: blank and B to A, A to X, M to N, N to M, S to S (length minus 1, 0 decimals), R to I, Z to A, D to D, K to W (A when the file is right-to-left, because Katakana is not valid with `CHECK(RLTB)`, CPD7873, A). The double-byte types E, F, O and X become A. Output-only fields are always A.

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
| Output only, valid code | Written as numeric with data type `Y` (length as in the D record, 0 decimals: the D specification has no decimal positions) with `EDTCDE(x)` (A). `EDTCDE` is only valid with data type `Y` or blank: with `S` `CRTDSPF` gives CPD7554. Code `Y` is a date edit that needs 3 to 8 digits (CPD7560 otherwise): outside that it is not written, status R |
| Input/output, data type S, valid code | Written with data type `Y` (digits = D length minus 1) and `EDTCDE(x)` (A) |
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
| 28 | `CHECK(MF)`. DDS does not allow `RZ` or `RB` with it (CPD7621), so they are left out when column 28 is Y (A) |
| 29 | `CHECK(ME)` |
| 30 | T: `CHECK(M10)`, E: `CHECK(M11)` |
| 31 | Z: `CHECK(RZ)`, B: `CHECK(RB)` |
| 35 | `CHECK(FE)` |
| 36 | `CHECK(AB)`, only together with `M10` or `M11`; DDS needs another validity checking keyword with it (CPD7656). Otherwise left out (A) |
| 34 | `DUP` |
| 51 (or S column 21) | `LOWER`, not on numeric fields |

Each attribute is Y (always) or an indicator. Always-on attributes are joined in one `DSPATR(...)`. An indicator-conditioned attribute is a keyword line conditioned by the indicator.

### Override (S columns 33-34)

When the format uses override the record gets `PUTOVR` (conditioned by the S indicator), because `OVRATR` and `OVRDTA` need it (CPD7615). A field with an attribute controlled by an indicator gets `OVRATR`, and a field with an output indicator gets `OVRDTA` conditioned by that indicator (A).

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

## Assumptions checked (DSP-04)

Each assumption above that is marked A was compared with SC41-4730 (page numbers of the V3R6 book) and the IBM i DDS reference for display files. Status: Confirmed (documented), Open (not in the manuals, needs a compile, a display test or a real S/36 program).

| Assumption | Evidence | Status |
|---|---|---|
| `INDARA` on every file | SC41-4730 chapter 14 (14-22): the System/36 environment supports only display files with a separate indicator area, and `INDARA` satisfies that | Confirmed |
| `INVITE` on every format | Same page: input must be invited after a write for RUF, and to read from a multiple-device file; the environment's RUF supports only display files with `INVITE` | Confirmed |
| Key mask digits and letters | Appendix B (B-7, B-8): function keys 1 to 6; command keys A to L = 1 to 12, M and N = 13 and 14, P to Y = 15 to 24 (no O). Matches the tables above | Confirmed |
| Function key 2 = `ROLLUP`, 3 = `ROLLDOWN` | IBM DDS: `ROLLUP` is the same as `PAGEDOWN`, `ROLLDOWN` the same as `PAGEUP`; without a response indicator input data is returned | Confirmed |
| Command keys as `CFnn`, not `CAnn` | IBM DDS: `CF` returns the changed data, `CA` does not. SC41-4730 only says an enabled command key must be handled by the program and gives no DDS | Open: `CF` is right if S/36 command keys return the screen data, which the manuals in this repository do not state |
| Response indicator = key number, `CFnn(nn)` | Not in the manuals. With `INDARA` it turns on `*INnn`, the same indicators an S/36 program uses as output conditions, so a program that uses indicator 05 for a field and also enables command key 5 would see both | Open: decide with a real program; the alternative is `CFnn` without an indicator (data returned, key found from the AID byte) |
| Override as `PUTOVR` with `OVRDTA` and `OVRATR` | SC41-4730 (14-13): override transmits the conditional output fields (output indicator on) and retransmits the attributes controlled by indicators. This is what `PUTOVR` with `OVRDTA` and `OVRATR` do | Confirmed in intent. Open: `PUTOVR` conditioned by the S indicator needs a compile (the IBM page for it could not be read) |
| Erase input as `ERASEINP` with `OVERLAY` | SC41-4730 (14-12): the operation blanks the unprotected input and input/output fields and invites input. IBM DDS: `ERASEINP` needs `OVERLAY`, and does not erase the fields of the record being written | Open: test on a display that writing the same format again with the indicator on blanks the input fields |

## Not converted yet

Array fields (WSU only: the manual shows only the column labels elements per row or column, fill direction, line skip factor, horizontal positions and space factor, with no entry values). Edit codes are written as EDTCDE (see above) and output indicators on input/output fields as two definitions of the field (see the kind-of-record table).

## Sample

All test cases are in one member, `samples/DSPFALL.dspf36`: a record format per feature, each starting with a comment that says what it tests. Add a new case as a new format at the end, and a row to the table below. Convert it with a message file, then compile and compare the report with the table:

```
IACNVDSPF SRC(MYLIB/QS36SRC DSPFALL) SRCTYPE(DSPF36) TGT(QDDSSRC) MSGF(MYLIB/ORDMSGF)
CRTDSPF FILE(MYLIB/DSPFALL) SRCFILE(MYLIB/QDDSSRC) SRCMBR(DSPFALL)
```

Some cases are not valid input on purpose, so the report (not the compile) shows them: they come out as DDS comments with status R. One compile error anywhere stops `CRTDSPF` for the whole file, so a failing format is found from the compiler messages: the format name is in the preceding comment. To test one format alone, copy the S record and its D records into a new member.

Not in the sample (would stop the compile or needs a program): fields in columns 100-132 (`A0` to `D2`, need `*DS4` size conditioning; add them by hand in `F132`), and a help format that is not in the source (name used as it is).

| Format | Tests | Expected |
|---|---|---|
| (top) | D and H before the first S, record type `Q` | R each, nothing written (the `Q` record becomes a DDS comment) |
| `FKEYY` | Keys `Y`, mask `1236AB`; right-to-left (col 40, first S) | `PRINT ROLLUP ROLLDOWN HOME CF01(01) CF02(02)`; file-level `CHECK(RLTB)` |
| `FKEYN` | Keys `N`, mask `45CD` | All keys except `CLEAR HELP CF03 CF04` |
| `FKEYR` | Keys `R` | No key keywords |
| `FKEYALL` | Keys blank | Every function key and `CF01` to `CF24` |
| `FKEYMIX` | Function keys `Y` mask `5`, command keys blank | `HELP` and all `CFnn` |
| `FSTARTV`, `FSTARTN`, `FCLR10` | Start line and lines to clear | `SLNO(*VAR) CLRL(*ALL)`; `SLNO(5) CLRL(*NO)`; `CLRL(10)` |
| `FOPTY` | Lowercase Y, return input N, alarm, blink, erase, lock Y | `ALARM BLINK ERASEINP LOCK`, no `RTNDTA`; `LCFLD` has `LOWER`, `NOLC` and numeric `NUMLC` do not |
| `FOPTI` | Alarm 31, blink 32, erase 33, override 34, lock 35 | Each keyword conditioned by its indicator, `OVERLAY` before `ERASEINP(33)`, `PUTOVR` conditioned by 34; A |
| `1BADFMT` | Name not valid in DDS | `FMTn` with `ALTNAME('1BADFMT')`, A |
| `F132` | Column 39 `Y` | `DSPSIZ(24 80 *DS3 27 132 *DS4)`, A |
| `FBADS` | Start line 0, alarm `Q` | R; the format is still written |
| `FCONST` | Constants: N, blank and Y output, no text, continued, apostrophe, `C`, input with text | Constants (Y output reported once); no text skipped (A); continued text joined; `''` doubled; input text ignored (A) |
| `FOUT` | Output fields, indicators, names | `OUTY` output; `OUTI` conditioned by 41; `OUTIC` conditioned by 42 plus a constant under N42; `OUTN` skipped; blank, duplicate and invalid names become `FLDn` (A); `LONGNAME` and `OUT$#@_1` kept |
| `FINPUT` | Input, input/output, output indicator on input, length 1 signed | `I`, `I`, `B`; `ININD` is `B` under 43 plus `I` under N43, A; `INS1` R (needs length 2) |
| `FTYPES` | Data types A B M N S R Z D K E F O X blank | DDS types `X A N M S I A D A A A A A A` (`S` length minus 1). `K` is `A` here because the first S record is right-to-left; without it `K` is `W` |
| `FBADD` | No length, no line, no column, output `Q` | R each, not written |
| `FATTR` | HI BL ND RI UL CS, indicators, PR, PC, combinations | `DSPATR(...)` per attribute, indicator forms conditioned; `IALL` has `DSPATR(HI BL RI UL CS)` and `PR` conditioned by 56 |
| `FATTRPC` | Position cursor `Y` | `DSPATR(PC)` on `IPC` |
| `FCHECK` | MF ME M10 M11 RZ RB FE AB DUP LOWER | `CHECK(...)` per field; `CKAB10` has `M10 AB`; `CKABONLY` has no `AB`, A; `CKALL` (MF with RZ) has no `RZ`, A; `CKNUMLOW` has no `LOWER`; `CKOUT` (output) gets no checks |
| `FOVER` | Override (S 33-34) | `PUTOVR` conditioned by 34, `OVRATR` on `OVIN`/`OVBOTH`, `OVRDTA` conditioned by 37 on `OVOUT`, A |
| `FHELP` | 18 H records | 6 valid: `HLPARA` lines with `HLPRCD`/`HLPDOC` (see H table above); the 12 not valid ones R as comments; `1BADFMT` becomes `HLPRCD(FMTn)` |
| `ORDHLP01`, `ORDHLP03`, `ORDHLP05` | Help formats | `HLPSEQ(ORDHLP 1)`, `(ORDHLP 3)`, `(ORDHLP 5)`, A |
| `FMSG` | Message fields | `MSG1` to `MSG9` output fields with `MSGID(USRnnnn file)` (member `U2`, `P1`, `P2`, `M1`, `M2` noted, A; `B001` becomes `USZB001`); `ERRMSG` under 44 plus `MSG10` under N44; `PGMMSG`, `BADMIC`, `MSGIN`, `MSGOUTN` kept as fields, R |
| `EDTOUT`, `EDTBOTH` | All 24 edit codes (1-4, A-D, J-Q, X-Z, 5-9) | `EO`/`EB` plus the code, data type `Y`, `EDTCDE(code)`, A. `EO` fields are 7 long: code `Y` needs 3 to 8 digits |
| `EDTMISC` | Lowercase codes, W E 0 -, input only, other data types, constant | `EDTCDE(J)`, `EDTCDE(Z)`; the others written without `EDTCDE`, R |
| `FDDS` | `*DDS` line, comment, blank | `*DDS` line copied as a DDS line; comment kept; blank skipped |

Note the letters W and E: they are not DDS edit codes (W and E are RPG codes only), so they are reported, not passed through. If a real S/36 member shows other values in column 25, add them to the table above and to `C_EDTCDES` in `IAdspCvt`.

## Subfile candidates (DSP-06, RV-42, FREE-52)

Several D records on consecutive display lines with the same fields at the same positions are what a program that was changed to use a subfile starts from. The converter does not make `SFL` and `SFLCTL`: that waits for a real example that shows how the program was changed (the program must write the subfile records and set the relative record number). It only reports the candidate, and the format is converted as written.

Rule (`CheckSubfileRows` in `IAdspCvt`), for the D records of one format:

- A record counts when it is a field: input (column 26 `Y`) or output other than `N` and blank. A constant is a label and does not count.
- The fields of one display line (column 19-20) make its signature: column, length, output entry, input entry and data type of each field, in the order of the records. Names, line number and constant text are not part of it.
- `C_SFLMIN` (4) or more consecutive display lines with the same signature are reported once, on the first record of the first line, status R: "Display lines a to b repeat the same fields at the same positions: a subfile candidate".

`samples/ORDLIST.dspf36`: `LISTA` has 10 identical rows (lines 6 to 15, reported), `LISTB` has 3 rows then a gap and 2 rows with another column (not reported), `LISTC` has 2 rows (not reported). That sample is written by hand. The real example is below. Written from the design and not from a run.

### Real example: STIPFM (received 2026-10-30)

Three files in `samples/`, from the user, for future reference (no converter code uses them yet):

| File | What it is |
|---|---|
| `STIPFM.dspf36` | The S/36 display format member (formats `CHOIX1`, `CHOIX`, `SAISIE`, `SELECT`, `ECRDI`, `SORTIE`, `CHOIX2`) |
| `STIPFM.dspf` | The same member converted to DDS without any subfile: every format is a plain display format |
| `STIP01FM.dspf` | The `SELECT` format after the program was changed to a subfile (a page at a time). Its header says it replaces the `SELECT` format of `STIPFM` (program described, 1300 bytes) and keeps the same screen layout: 18 lines, same columns |

What the pair `STIPFM.dspf` and `STIP01FM.dspf` shows (read from the files):

- The candidate is real: in `SELECT` the display lines 4 to 21 are 18 rows with the same fields at the same positions (a one-character selection field, 27, 5, 5, 1, 5, 4 and 8 character fields and five `|` constants). `CheckSubfileRows` should report these lines (not run on this member yet).
- The one format `SELECT` became four records: `SELSFL` (`SFL`: one row, on line 4), `SELCTL` (`SFLCTL(SELSFL)` with `SFLSIZ(0018)`, `SFLPAG(0018)`, `OVERLAY`, `SFLCLR` on indicator 31, `SFLDSPCTL` on N31, `SFLDSP` on 32, `ROLLUP(10)`, `ROLLDOWN(09)`, and the `Afficher à partir de:` label with its input field `DEB`), `STIP0H` (the title on line 1 and the column heading on line 3) and `STIP0F` (the message field `MES` on indicator 99, the `(X=Produits choisis)` text and the function key line 24).
- The row fields got names (`SXSEL`, `SMOT`, `SLGART`, `SUSI`, `SCX`, `SSEQP`, `SSEQO`, `SDATIP`) instead of `FL0014` and so on, and three of them are numeric with an edit code (`SLGART` 4,2 `EDTCDE(4)`, `SSEQP` 4,1 `EDTCDE(4)`, `SSEQO` 3,0 `EDTCDE(M)`); in the plain conversion they are character fields of 5, 5 and 4. Names and types come from the program that fills the subfile, not from the display file member.
- The function keys became `CFnn(nn 'text')` with response indicators; the record keywords `PRINT(*PGM)`, `INVITE`, `SLNO(01)`, `CLRL(*ALL)`, `ALWROL`, `HLPRTN`, `HOME` and `HELP` are not in the subfile version, and the file keywords are `DSPSIZ(*DS3)`, `INDARA` and `PRINT`.

Open for DSP-06 (decisions for the user, nothing written): which rule makes `SFL` and `SFLCTL` from a candidate, where the field names and types come from (the program, a parameter, or a generated name with a report line), and whether the converted file must keep the old format name for the program.
