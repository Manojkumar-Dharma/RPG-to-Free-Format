# OCL36 to CLLE: mapping rules (version 1)

Implemented in `src/oclcle/IAoclCvt.rpgle`. Every OCL statement ends up in one of three states in the spooled report: converted, converted with an assumption (A), or needing review (R). Anything not listed below is copied into the output as a CL comment (`/* OCL: ... */`) and reported as R, so nothing disappears silently.

## Sources and their limits

- IBM, *System/36 Environment Programming* (SC41-4730), the OCL examples and statement descriptions. This is the main evidence. It is a programming guide, not the full System/36 Environment Reference, so statement keywords it does not show are not converted.
- McPress, [Going Native: AS/400 Equivalents to S/36 OCL](https://www.mcpressonline.com/programming-other/cl/going-native-as400-equivalents-to-s36-ocl) and Wikipedia, [Operational Control Language](https://en.wikipedia.org/wiki/Operational_Control_Language) (general syntax).

Statuses: C converted, A converted with an assumption, R needs review.

## Statements converted

| OCL | CLLE output | Status | Notes |
|---|---|---|---|
| `* text` (asterisk first) | `/* text */` | C | Text kept exactly as written (leading blank kept, trailing blanks removed). `*/` inside becomes `* /`. A comment is split only when it would not fit the target width, preferably at a blank. |
| `// LOAD pgm[,lib]` then `// RUN` | `CALL PGM([lib/]pgm)` | C | The second LOAD operand is the library (shown in the IBM guide). The CALL is written when RUN arrives. |
| `// FILE NAME-x[,LABEL-y][,LIBRARY-z]` | `OVRDBF FILE(x) TOFILE([z/]y)` | C | LABEL defaults to NAME. |
| `// FILE ...,DISP-SHR` (or OLD) | same `OVRDBF` | A | DISP is not converted. |
| `// FILE ...` with other keywords | `OVRDBF` plus the original as a comment | R | The keywords not converted are listed. |
| `// FILE ...,JOB-YES` | `OVRDBF` plus comment | R | Not given the end-of-step removal; the override is meant to last for the job. |
| `// FILE ...,DISP-NEW` | comment only | R | Creating the file is not converted. |
| `// LOCAL OFFSET-n,DATA-'text'[,AREA-USER]` | `CHGDTAARA DTAARA(*LDA (n len)) VALUE('text')` | A | OFFSET taken as a 1-based position; 0 is rejected (R). Other keywords are R. DATA that is one expression (`?DATE?`, `?USER?`, `?L'p,n'?`) uses its variable: `VALUE(&DATE)`. |
| `// TAG name` | `NAME:` | C | Text after the label becomes a comment. |
| `// GOTO name` | `GOTO CMDLBL(NAME)` | C | Text after the label becomes a comment. |
| `// RETURN` | `RETURN` | C | |
| `statement /\ text \/` | statement plus `/* text */` | C | Trailing comment, outside quotes. |

After each `CALL` the converter writes `DLTOVR FILE(names)` for the files overridden by `FILE` statements since the previous `RUN`, because an OCL `FILE` statement applies to one step.

## IF, IFF, ELSE and SWITCH

Evidence: SC41-4731, chapter 3 ("IF", "ELSE", "string1=string2") and chapter 5 ("SWITCH OCL Statement"). An IF condition covers only the statement on the same line, and the condition is one string without blanks.

| OCL | CLLE output | Status |
|---|---|---|
| `// IF cond statement` (also `IFT`) | the statement's CL lines wrapped in `IF COND(...) THEN(DO)` ... `ENDDO` | A |
| `// IFF cond statement` | same with `*NOT (...)` | A |
| `// IF c1 IF c2 statement` | `(c1) *AND (c2)` | A |
| `// ELSE statement` directly after an IF line | `*NOT (condition of the IF line)`; `ELSE IF` chains keep the earlier condition as context | A |
| condition `a/b` or `a=b` | `a *EQ b`; a and b are a constant or one `?...?` expression; compared as text | A |
| condition `SWITCHn-0` / `SWITCHn-1` | `%SWITCH(XXXXXXXX)` with the 0 or 1 at position n | A |
| `// SWITCH nnnnnnnn` | `CHGJOB SWS(nnnnnnnn)` | A |

Other conditions (`DATAF1-`, `ACTIVE-`, `BLOCKS-` and so on) and a conditional `LOAD`, `RUN`, `FILE` or `TAG` are not converted (R). The reference compares two all-numeric values as numbers, so `3` and `03` differ here.

Text after the operands of a statement (after the first blank outside apostrophes) is a comment and becomes a CL comment, except for `EVALUATE`.

## Sort steps (`#GSORT`)

Evidence: IBM, *System/36 Environment Reference* (SC41-4731, `docs/sc414731.pdf`), appendix A "#GSORT Utility", and the "IF", "ELSE" sections of chapter 3; plus two sample procedures from the author. The reference states that #GSORT does its sorting with the `FMTDTA` command and reads the sort specifications either inline (ended by `// END`) or from a source member (`// SOURCE member,library`).

| OCL | CLLE output | Status |
|---|---|---|
| `// LOAD #GSORT`, `FILE NAME-INPUT[n],LABEL-a`, `FILE NAME-OUTPUT,LABEL-b`, `// RUN`, spec lines, `// END` or `/*` | `RTVDTAARA` for the LDA values used, `DLTF`/`CRTSRCPF` of `QTEMP/IASORTn` (CCSID 65535), one `RUNSQL INSERT` per spec line (built in `&SQL` with `*CAT`), then `FMTDTA INFILE(a) OUTFILE(b) SRCFILE(QTEMP/IASORTn) SRCMBR(IASORTn)` | A |
| `NAME-INPUT1` to `INPUT8` | up to eight files in `INFILE` | A |
| `FILE NAME-WORK,...` | dropped (ignored on the AS/400 system, per the reference) | C |
| `// SOURCE member,library` | `FMTDTA ... SRCFILE(library/QS36SRC) SRCMBR(member)` | A |
| Output keywords such as `RECORDS-`, `BLOCKS-`, `DISP-NEW` | not converted; the output file may need creating first | R |
| `// IF`, `IFT`, `IFF` *cond* *spec*, and `// ELSE` *spec* | the insert for that line is wrapped in `IF COND(...) THEN(DO)` / `ENDDO` | A |

Spec lines are copied unchanged. The reference describes the specs as ordinary S/36 sort specifications and the sample columns line up with the `FMTDTA` layout.

Conditions, from the reference: the condition is one string with no blanks (blanks only inside apostrophes); `?expr?/value` and `?expr?=value` both mean equal; `IFF` is true when the condition is false; `ELSE` applies only when it is the first thing on the line right after the IF line. Supported here: `?n?` (1 to 9) and `?L'p,n'?` (local data area text) compared with a literal or blank. Compared as text; the reference compares two all-numeric values as numbers, so `3` and `03` would differ here (reported as an assumption). Anything else (nested IF, other expressions) leaves the whole sort block as comments (R).

The text after a condition is taken to supply columns 4 onward of the specification line (the line is built as three blanks plus that text). This is an assumption from the sample lines, where it puts the spec letter (`I`, `F`) in column 6 (reported as an assumption). `?L'p,n'?` inside a spec line (for example `EQC?L'56,1'?`) is replaced by the value at run time.

## Lines without `//`

- A `/* ... */` line is already a CL comment and is copied (text kept).
- A line that starts like a command name (letters, up to 10 characters) is copied as a command with `?n?` substitution applied, status A (check the command exists; for example `OVRDBF`, `OVRPRTF`, `MULTISUP`).
- Anything else is R.

## Substitution expressions

Evidence: SC41-4731, chapter 3. `?n?` is the nth positional parameter of the procedure, n from 1 through 64, and `EVALUATE Pn=...` assigns to it. So `?10?` is parameter 10, not a separate kind of variable. CL allows 40 parameters, so n above 40 is not converted.

| OCL | CL | Notes |
|---|---|---|
| `?n?` (1 to 40) | `&Pn` | A parameter first read (before any `EVALUATE` assigns it) is passed by the caller: `PGM PARM(&P1 ...)`, `CHAR(10)` (A). A parameter first assigned by `EVALUATE` is a local variable, declared with the length of the assigned value, and is not in `PARM`. |
| `?USER?` | `&USER` | `RTVJOBA USER(&USER)` is added. |
| `?WS?` | `&WS` | `RTVJOBA JOB(&WS)` is added. |
| `?DATE?` | `&DATE` | `RTVSYSVAL SYSVAL(QDATE) RTNVAR(&DATE)`. The S/36 date follows the session date format, QDATE follows the system format (A in practice, not reported yet). |
| `?L'p,n'?` | `&Lp_n` | `RTVDTAARA DTAARA(*LDA (p n)) RTNVAR(&Lp_n)` is written right before the statement that uses it. |
| `?n'value'?`, `?F'...'?`, `?nT'..'?` and the other forms | not converted | The statement is copied as a comment (R). |

CL cannot put a variable inside a word or a quoted text. Where OCL has an expression inside a name (for example `LABEL-STK?10?TRI`), the converter builds the name into a temporary variable `&Tn` with `CHGVAR ... *TCAT ...` before the statement and uses `&Tn` (FILE and LOAD operands). In a copied command (a line without `//`) an expression inside a word is not converted (R).

## EVALUATE

`// EVALUATE Pn[,length]=value ...` becomes `CHGVAR VAR(&Pn) VALUE(...)` for each item. Converted values: a text constant in apostrophes (or `''` for blank), a number (leading zeros dropped, or padded or cut to the length), `?USER?`, `?WS?`, `?DATE?`, `?L'p,n'?`, `?n?`. Arithmetic (`+ - * /` and parentheses), `?F'...'?` and other expressions are not converted (R, one report line per item). Words that are not `Pn=...` are comment text and become a CL comment. Status C, or A when a passed parameter is assigned.

## Other rules

- A statement that ends with a comma continues on the next line (a leading `//` on that line is dropped). Confirmed by the IBM guide.
- Lines after `// RUN` that are not statements are treated as program data and copied as comments (R), until the next `//` statement.
- `/*` and `/&` marker lines are copied as comments (R).
- Statement keywords are matched ignoring case; names are written in upper case.

## Not converted yet

Statements seen in the IBM guides but not converted: `PRINTER` (the page size and printing rules need care), `BLDFILE` and other procedure calls, `?F'...'?` file-size expressions, `DATAF1-`/`ACTIVE-` conditions, `WAIT`, `ATTR`, `ALLOCATE`, `DEALLOC`, `SESSION`, `MEMBER`, `NOHALT`, `PAUSE`, `LIBRARY`, `MRTPROC`, `PROMPT`, `HELP`, plus `CANCEL`, `SCRATCH`, `INCLUDE`. Each is copied as a comment and reported R.
