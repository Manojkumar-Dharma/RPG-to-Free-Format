# OCL36 to CLLE: mapping rules (version 1)

Implemented in `src/oclcle/IAoclCvt.sqlrpgle`. Every OCL statement ends up in one of three states in the spooled report: converted, converted with an assumption (A), or needing review (R). Anything not listed below is copied into the output as a CL comment (`/* OCL: ... */`) and reported as R, so nothing disappears silently.

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
| `// PRINTER [NAME-x][,keywords]` | `OVRPRTF FILE(x) parms`; without NAME `FILE(*PRTF)` | C | Keywords per the table "// PRINTER Override Printer File" (SC41-4730, chapter 17); see below. Removed after the next CALL with `DLTOVR FILE(x)`. Keywords not in the table are listed and the statement is R. |
| `BLDFILE name,S\|D,R\|B,size,reclen[,keylen[,retention]][,LIBRARY-x]` (statement or procedure line) | `CRTPF FILE([x|QTEMP]/name) RCDLEN(n) SIZE(records extend 32767)`; type D adds `INZPFM FILE(QTEMP/name) RCDNBR(records)` | A | See below. Indexed (I) and other types are R. |
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

## PRINTER and BLDFILE

PRINTER keyword mapping (from the guide's table; the guide lists them as
OCL statement keyword and the OVRPRTF parameter it sets):

| PRINTER | OVRPRTF | PRINTER | OVRPRTF |
|---|---|---|---|
| `NAME-x` | `FILE(x)` | `COPIES-n` | `COPIES(n)` |
| `DEVICE-d` | `DEV(d)` | `FORMS-f` | `FORMTYPE(f)` |
| `LINES-n` | `PAGESIZE(n *N)` | `LPI-n`, `CPI-n` | `LPI(n)`, `CPI(n)` |
| `ALIGN-YES/NO` | `ALIGN(*YES/*NO)` | `SPOOL-YES/NO` | `SPOOL(*YES/*NO)` |
| `HOLD-YES/NO` | `SAVE(*YES/*NO)` | `DEFER-YES` | `SCHEDULE(*FILEEND)` |
| `PRIORITY-0` | `OUTPTY(7) HOLD(*YES)` | `PRIORITY-1` to `5` | `OUTPTY(7)` to `OUTPTY(3)` |
| `TEXT-YES/NO` | `PRTQLTY(*NLQ/*DRAFT)` | `EOFMSG-YES/NO` | `FORMFEED(*CONT/*CUT)` |
| `DRAWER-1/2` | `DRAWER(n)` | `DRAWER-3` | `DRAWER(*E1)` |
| `ROTATE-n` | `PAGRTT(n)` | `JUSTIFY-n` | `JUSTIFY(n)` |
| `CONTINUE-YES/NO` | `SHARE(*YES/*NO)` | | |

Assumptions (reported A): `DEFER-NO` is written as `SCHEDULE(*IMMED)` (the
guide lists only DEFER-YES); `CONTINUE-YES` keeps the override until a
`CONTINUE-NO` (it is not removed after the next CALL; the guide describes the
function as like SHARE(*YES) with page size changes between steps, which is
not reproduced); `DLTOVR FILE(*PRTF)` is accepted for the session printer
override. Not converted (statement R): `FONT`, the communications keywords
(`LOCATION`, `SYMID`, `LWSID`, `GROUP`, `APPLID`, `BATCH`, `HOSTNAME`,
`FMHI`, `MSGPROT`, `PARTNER`, `SWTYP`), record keywords (`RECSEP`, `BLKL`,
`RECL`, `TRANSP`, `BLANK`) and the IGC keywords (`IGCCPI`, `SOSI`, `TYPE`,
`EXTN`). A condition (`// IFF ?10?/92 PRINTER ...`) wraps the OVRPRTF as for
other statements.

BLDFILE: the guide's example `BLDFILE NEWFILE,S,R,100,256,,T` gives the
positions: file name, type, size type, size, record length, key length,
retention. `R` or `RECORDS` is a size in records, `B` or `BLOCKS` in blocks of
2560 bytes (records = blocks x 2560 / record length). The extend value is the
guide's default, 32767 divided by the record length; the number of extends is
taken as 32767. The file goes to QTEMP unless a library is given with an added
`LIBRARY-x` operand (for example `BLDFILE NEWFILE,S,R,100,256,LIBRARY-QS36F`);
QTEMP is removed when the job ends, so retention `T` and `J` need no extra step,
but a file meant to last must be given a library. Direct
files are filled with blank records by INZPFM (the guide says a new direct file
must be initialised). A key length, other retention values or more operands
are listed and the statement is R.

## Procedure calls

Evidence: SC41-4730 chapter 16 ("Calling Procedures", "Calling a Procedure from Another Procedure") and SC41-4731 chapter 2. A procedure is called with `name[,library] data`, `// name[,library] data` or `// INCLUDE name[,library] data` (INCLUDE is not converted yet). The data is a list of positional parameters separated by commas; an omitted parameter keeps its comma (`PROCA PARM1,,PARM3`).

| OCL | CLLE output | Status |
|---|---|---|
| `name[,lib] p1,p2,...` or `// name[,lib] p1,p2,...` | `CALL PGM([lib/]name) PARM(v1 v2 ...)` | A |
| `// IF cond name ...` | wrapped in `IF COND(...) THEN(DO)` as for other statements | A |

Assumptions (all reported A): the called procedure is converted to a program of the same name (the CALL does not say where it lives unless the library is given); each parameter is passed as 10 characters, because every converted program declares its `?n?` parameters `CHAR(10)`.

Parameter rules:

- Text, a number or a quoted text is written as a quoted CL value padded with blanks to 10 characters (`FILE1` becomes `'FILE1     '`). Text is kept as typed.
- An omitted parameter is 10 blanks.
- A single `?n?`, `?USER?`, `?WS?`, `?DATE?` or `?L'p,n'?` is passed as its variable. A variable shorter than 10 characters (`&DATE`) is first copied with `CHGVAR` into a temporary variable so the called program does not read past its end.
- Text mixed with an expression (`A?1?`) is built with `*TCAT` into a temporary variable (the text is upper-cased there).
- Not converted (R): a parameter longer than 10 characters, a parameter with an apostrophe that is not doubled, other `?...?` expressions, more than 40 parameters, a name that is not a valid name.

What counts as a procedure call:

- On a `//` line, any first word that is not an OCL statement word (the list in `InitReservedNames`, taken from SC41-4731 chapter 5) and not an IBM-supplied procedure.
- On a line without `//`, the first word, as long as the line has no `keyword(` parentheses. A line with parentheses is still copied as a CL command (see below). A bare command name without parentheses, such as `DSPLIBL`, is therefore taken as a procedure call; check the A items in the report.
- The IBM-supplied procedures listed in SC41-4731 chapter 4 (`DELETE`, `PRINT`, `COPYDATA`, `LISTDATA`, `SORT` and so on) are not user procedures and are not turned into a CALL: the line becomes a comment and is reported R. Each needs its own AS/400 equivalent. `BLDFILE` is the exception that is converted (above).
- A procedure call after `// RUN` and before the next `//` line may be program data instead; the report entry says so.
- Text after the data (after the first blank outside apostrophes) is a comment, as for other statements, so parameter text with blanks must be in apostrophes.

## Lines without `//`

- A `/* ... */` line is already a CL comment and is copied (text kept).
- A line that starts like a command name (letters, up to 10 characters) and has a keyword in parentheses is copied as a command with `?n?` substitution applied, status A (check the command exists; for example `OVRDBF`, `OVRPRTF`). Without parentheses it is a procedure call (see Procedure calls).
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

Statements seen in the IBM guides but not converted: calls of the IBM-supplied procedures (`BLDFILE` is converted, and calls of your own procedures are converted), `?F'...'?` file-size expressions, `DATAF1-`/`ACTIVE-` conditions, `WAIT`, `ATTR`, `ALLOCATE`, `DEALLOC`, `SESSION`, `MEMBER`, `NOHALT`, `PAUSE`, `LIBRARY`, `MRTPROC`, `PROMPT`, `HELP`, plus `CANCEL`, `SCRATCH`, `INCLUDE`. Each is copied as a comment and reported R.
