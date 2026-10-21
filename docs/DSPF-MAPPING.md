# DSP36 / DSP38 to DSPF mapping (IACNVDSPF)

Implemented in `src/dspf/IAdspCvt.sqlrpgle`. The command is `IACNVDSPF` (program `IAcnvDspf`). The output is DDS source for a display file (target type `DSPF`, normally member type DSPF in QDDSSRC). Compile it afterwards with `CRTDSPF`.

## Sources and evidence

- DSP36 is System/36 display format source (SFGR): S (display control), H (help) and D (field definition) specifications. Column layouts are in SC41-4730 *System/36 Environment Programming* Appendix B, which is in `docs/sc414730.pdf`.
- How `$SFGR` turns SFGR into DDS (`CRTS36DSPF`) is described in the same book, chapter 14: format names and ALTNAME, `*DDS` comments, data type mapping, `INDARA` and `INVITE`, right-to-left (`CHECK(RLTB)`), DFRWRT and FRCDTA.
- `SRCTYPE` accepts `DSP36` and `DSP38`, and the spellings `DSPF36` and `DSPF38` with the same meaning.
- DSP38 is System/38 display DDS. It is accepted by `CRTDSPF` as it is, so it is copied unchanged.

Where the manuals do not give the generated DDS, the choice made here is marked **assumption** below. The report shows those lines with status A. Anything that is not converted is kept as a DDS comment and reported with status R.

## Source records (DSP36)

Records are 80 columns. Columns 1-5 are a sequence number and are not used. Column 6 is the specification type.

| Record | Result |
|---|---|
| Blank line | Skipped |
| `*` in column 7 | DDS comment (`A` in column 6, text from column 8 unchanged) |
| `*DDS` in columns 1-4 and `*` in column 7 | DDS line inserted as is: column 6 becomes `A`, column 7 becomes blank (as `$SFGR` does) |
| `S` | Start of a record format (below) |
| `H` | Not converted yet: kept as a DDS comment, status R |
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
| Y | not Y | Output field (`O`). Constant text becomes `DFT('text')` |
| indicator | not Y | Output field conditioned by the indicator. Constant text, if any, is a constant conditioned by NOT the indicator |
| N or blank | Y | Input field (`I`). Constant text is not used (A) |
| Y | Y | Input/output field (`B`) |
| indicator | Y | Input/output field (`B`), status R: the output indicator is dropped |

Field names are kept when valid and unique in the format. Otherwise they become `FLDn` (A), because S/36 programs address display fields by position.

### Data types (D column 27)

From the table in SC41-4730 Appendix B: blank and B to A, A to X, M to N, N to M, S to S (length minus 1, 0 decimals), R to I, Z to A, D to D, K to W. The double-byte types E, F, O and X become A. Output-only fields are always A.

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
| 36 | `CHECK(AB)` |
| 34 | `DUP` |
| 51 (or S column 21) | `LOWER`, not on numeric fields |

Each attribute is Y (always) or an indicator. Always-on attributes are joined in one `DSPATR(...)`. An indicator-conditioned attribute is a keyword line conditioned by the indicator.

### Override (S columns 33-34)

When the format uses override: a field with an attribute controlled by an indicator gets `OVRATR`, and a field with an output indicator gets `OVRDTA` conditioned by that indicator (A).

## DSP38

Each line is copied unchanged and reported C. One report line (A) says the member should be compiled with `CRTDSPF` to confirm. Records longer than 80 columns are reported R.

## Not converted yet

Help definition (H) specifications, message fields (D column 56 = M, kept as program output fields), array fields (WSU only), edit codes (WSU only), and reduced behaviour for output indicators on input/output fields.

## Sample

`samples/EMPSCR.dsp36` is a small column-exact DSP36 member (one format, constants, input and output fields, an indicator, a continued constant). Convert it first and send me the generated member and the report if anything looks wrong.
