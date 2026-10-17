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
| `// LOCAL OFFSET-n,DATA-'text'[,AREA-USER]` | `CHGDTAARA DTAARA(*LDA (n len)) VALUE('text')` | A | OFFSET taken as a 1-based position; 0 is rejected (R). Other keywords are R. |
| `// TAG name` | `NAME:` | C | Text after the label becomes a comment. |
| `// GOTO name` | `GOTO CMDLBL(NAME)` | C | Text after the label becomes a comment. |
| `// RETURN` | `RETURN` | C | |
| `statement /\ text \/` | statement plus `/* text */` | C | Trailing comment, outside quotes. |

After each `CALL` the converter writes `DLTOVR FILE(names)` for the files overridden by `FILE` statements since the previous `RUN`, because an OCL `FILE` statement applies to one step.

## Substitution expressions

| OCL | CL | Notes |
|---|---|---|
| `?n?` (1 to 99) | `&Pn` | The program gets `PGM PARM(&P1 ...)`. Each parameter is declared `CHAR(10)` (A, once per run). |
| `?USER?` | `&USER` | `RTVJOBA USER(&USER)` is added. |
| `?WS?` | `&WS` | `RTVJOBA JOB(&WS)` is added. |
| anything else between `?` marks | not converted | The statement is copied as a comment (R). |

## Other rules

- A statement that ends with a comma continues on the next line (a leading `//` on that line is dropped). Confirmed by the IBM guide.
- Lines after `// RUN` that are not statements are treated as program data and copied as comments (R), until the next `//` statement.
- `/*` and `/&` marker lines are copied as comments (R).
- Statement keywords are matched ignoring case; names are written in upper case.

## Not converted yet

Statements seen in the IBM guide but not converted: `IF`, `IFF`, `ELSE` (with `?CD?` and similar tests), `EVALUATE`, `WAIT`, `ATTR`, `ALLOCATE`, `DEALLOC`, `SESSION`, `MEMBER`, `NOHALT`, `PAUSE`, `PRINTER`, `LIBRARY`, `MRTPROC`, `PROMPT`, `HELP`, plus `CANCEL`, `SWITCH`, `SCRATCH`, `INCLUDE`. Each is copied as a comment and reported R. `IF`/`IFF`/`ELSE`/`EVALUATE` are the next piece.
