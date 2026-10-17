# OCL36 to CLLE: mapping rules (version 1)

Implemented in `src/oclcle/IAoclCvt.rpgle`. Every OCL statement ends up in one of three states in the spooled report: converted, converted with an assumption (A), or needing review (R). Anything not listed below is copied into the output as a CL comment (`/* OCL: ... */`) and reported as R, so nothing disappears silently.

## Sources and their limits

The rules below come from two secondary sources, not from IBM's System/36 environment reference:

- McPress, [Going Native: AS/400 Equivalents to S/36 OCL](https://www.mcpressonline.com/programming-other/cl/going-native-as400-equivalents-to-s36-ocl) (comments, substitution expressions; the page was only partly readable)
- Wikipedia, [Operational Control Language](https://en.wikipedia.org/wiki/Operational_Control_Language) (statement list and general syntax)

Items marked "not verified" should be checked against IBM's reference before this converter is trusted for production procedures.

## Statements converted

| OCL | CLLE output | Status | Notes |
|---|---|---|---|
| `* text` (asterisk first) | `/* text */` | converted | Text containing `*/` becomes `* /`. Long text is split into several comments. |
| `// LOAD pgm` then `// RUN` | `CALL PGM(pgm)` | converted | The CALL is written when RUN arrives. |
| `// LOAD pgm,lib` then `// RUN` | `CALL PGM(lib/pgm)` | A | Second operand taken as the library (not verified). |
| `// FILE NAME-x[,LABEL-y][,LIBRARY-z]` | `OVRDBF FILE(x) TOFILE([z/]y)` | converted | LABEL defaults to NAME. |
| `// FILE ...,DISP-SHR` (or OLD) | same `OVRDBF` | A | DISP is not converted. |
| `// FILE ...` with other keywords | `OVRDBF` plus the original as a comment | R | The keywords not converted are listed in the report. |
| `// FILE ...,DISP-NEW` | comment only | R | Creating the file is not converted. |
| `// LOCAL OFFSET-n,DATA-'text'` | `CHGDTAARA DTAARA(*LDA (n+1 len)) VALUE('text')` | R | The OFFSET base (0 or 1) is not verified. The line is written assuming zero-based. |
| `// TAG name` | `NAME:` | converted | Label must be a valid CL label (10 characters). |
| `// GOTO name` | `GOTO CMDLBL(NAME)` | converted | |
| `// RETURN` | `RETURN` | converted | |

## Substitution expressions

| OCL | CL | Notes |
|---|---|---|
| `?n?` (1 to 99) | `&Pn` | The program gets `PGM PARM(&P1 ...)`. Each parameter is declared `CHAR(10)` (A, once per run). |
| `?USER?` | `&USER` | `RTVJOBA USER(&USER)` is added. |
| `?WS?` | `&WS` | `RTVJOBA JOB(&WS)` is added. |
| anything else between `?` marks | not converted | The statement is copied as a comment (R). |

## Other rules

- A statement that ends with a comma continues on the next line (a leading `//` on that line is dropped). Reported as A. Not verified.
- Lines after `// RUN` that are not statements are treated as program data and copied as comments (R), until the next `//` statement.
- `/*` and `/&` marker lines are copied as comments (R).
- Statement keywords are matched ignoring case; names are written in upper case.

## Not converted yet

`IF`, `IFF`, `PAUSE`, `CANCEL`, `SWITCH`, `SCRATCH`, `INCLUDE`, `EVALUATE`, `ATTR` and every other statement. The McPress article describes how `IF` tests map (for example file existence to `CHKOBJ`), which is the likely next piece.
