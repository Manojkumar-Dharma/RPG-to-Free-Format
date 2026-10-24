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
| `// IF cond statement` (also `IFT`) | `IF COND(...) THEN(statement)` when the statement is one CL line; otherwise its CL lines wrapped in `IF COND(...) THEN(DO)` ... `ENDDO` | A |
| `// IFF cond statement` | same with the opposite condition: `a/b` becomes `a *NE b`, a logical variable `*NOT &D1`, anything else `*NOT (...)` | A |
| `// IF c1 IF c2 statement` | `(c1) *AND (c2)` | A |
| `// ELSE statement` directly after an IF line | `*NOT (condition of the IF line)`; `ELSE IF` chains keep the earlier condition as context | A |
| condition `a/b` or `a=b` | `a *EQ b`; a and b are a constant or one `?...?` expression; compared as text | A |
| condition `SWITCHn-0` / `SWITCHn-1` | `%SWITCH(XXXXXXXX)` with the 0 or 1 at position n | A |
| condition `DATAF1-name` | a logical variable `&Dn`, see below | A |
| condition `ACTIVE-name` | a logical variable `&An`, see below | A |
| `// SWITCH nnnnnnnn` | `CHGJOB SWS(nnnnnnnn)` | A |

Other conditions (`BLOCKS-` and so on) and a conditional `LOAD`, `RUN`, `FILE` or `TAG` are not converted (R). The reference compares two all-numeric values as numbers, so `3` and `03` differ here.

### DATAF1 condition

Evidence: SC41-4731, chapter 3, "DATAF1 (Files and Libraries on Disk) Condition". It is true when the file exists (a database file with no member is false) or when a library with that name exists. For `DATAF1-name`, written before the `IF COND(...)` that uses it:

```
CHGVAR VAR(&D1) VALUE('1')
CHKOBJ OBJ(name) OBJTYPE(*FILE) MBR(*FIRST)
MONMSG MSGID(CPF0000) EXEC(CHGVAR VAR(&D1) VALUE('0'))
IF COND(*NOT &D1) THEN(DO)
CHGVAR VAR(&D1) VALUE('1')
CHKOBJ OBJ(QSYS/name) OBJTYPE(*LIB)
MONMSG MSGID(CPF0000) EXEC(CHGVAR VAR(&D1) VALUE('0'))
ENDDO
```

`&D1` is declared `*LGL` and the condition is `&D1` (`*NOT (&D1)` for `IFF`). The name may be a constant or one expression such as `?2?`; a name with expressions inside a word is built into a `&Tn` variable. Assumptions (A): the file is looked for on the library list, because the OCL says the *current files library*; the S/36 scratch and job file rules are not reproduced. `DATAF1-'name,ALL'` and `DATAF1-'name,ALL,library1,library2'` (the extra libraries are searched as well as the library list; true when a file or library whose name *starts with* the text exists; the reference says only local files and libraries are detected) becomes, written before the `IF COND(...)`:

```
CHGVAR VAR(&D2) VALUE('0')
DLTF FILE(QTEMP/IAOBJD)
MONMSG MSGID(CPF0000)
DSPOBJD OBJ(*LIBL/name*) OBJTYPE(*FILE) OUTPUT(*OUTFILE) OUTFILE(QTEMP/IAOBJD) OUTMBR(*FIRST *REPLACE)
MONMSG MSGID(CPF0000)
DSPOBJD OBJ(library1/name*) OBJTYPE(*FILE) OUTPUT(*OUTFILE) OUTFILE(QTEMP/IAOBJD) OUTMBR(*FIRST *ADD)
MONMSG MSGID(CPF0000)
DSPOBJD OBJ(QSYS/name*) OBJTYPE(*LIB) OUTPUT(*OUTFILE) OUTFILE(QTEMP/IAOBJD) OUTMBR(*FIRST *ADD)
MONMSG MSGID(CPF0000)
CHGVAR VAR(&FSN) VALUE(0)
RTVMBRD FILE(QTEMP/IAOBJD) MBR(*FIRST) NBRCURRCD(&FSN)
MONMSG MSGID(CPF0000) EXEC(CHGVAR VAR(&FSN) VALUE(0))
IF COND(&FSN *GT 0) THEN(CHGVAR VAR(&D2) VALUE('1'))
```

Assumptions (A): `ALL` means the current library list (confirmed by the author; constant `C_ALLSCOPE` in `IAoclCvt`), then each extra library given (one `DSPOBJD ... *ADD` line each, shown above for `library1`), libraries in QSYS; a name given as a variable gets the `*` added at run time. Not tested on the system yet: `DSPOBJD` with a generic name that matches nothing is expected to send a message that the `MONMSG` ignores. Not converted (R): `'name,date'` (the date selects a creation date). The statement is copied as a comment.

### ACTIVE condition

Evidence: SC41-4731, chapter 3, "ACTIVE (Running Procedures) Condition": true when at least one of the named procedures is running (`'proc1,proc2'` is a list; `IFF` is true when none is running); the test for the procedure that contains the test is always false. On the IBM i side a running program holds no lock on its `*PGM` object, and `QSYS2.STACK_INFO` (7.3 TR3 and later) lists the call stack of one job only, so testing every active job needs `*JOBCTL` authority and is slow. The converter uses a cooperative lock instead (decision: shared-lock version).

- Every converted program starts with `CRTDTAARA DTAARA(QGPL/proc) TYPE(*CHAR) LEN(1)` (an existing area is ignored), then `ALCOBJ OBJ((QGPL/proc *DTAARA *SHRRD)) WAIT(0)`, and releases it with `DLCOBJ` before each `RETURN` and before `ENDPGM`. `proc` is the source member name. The library is the constant `C_MARKLIB` in `IAoclCvt`.
- `ACTIVE-name` or `ACTIVE-'n1,n2'` becomes `&An` (`*LGL`), set before the `IF COND(...)`: for each name `ALCOBJ OBJ((QGPL/name *DTAARA *EXCL)) WAIT(0)`; `MONMSG CPF1002` sets `&An` to `'1'` (running); any other message is ignored; then `DLCOBJ` of the exclusive lock.

Status A. Limits: only procedures converted with this version take the lock, so the test is false for a procedure converted earlier or not converted; the job-scope lock is released when the job ends, so an abended job does not leave it held; a data area with the same name in the marker library is used as the marker; the case of a procedure testing itself (the reference says false) is expected to give false but needs a test on the system.

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

## WAIT, PAUSE, NOHALT and CANCEL

Evidence: SC41-4731, chapter 5 ("WAIT OCL Statement", "NOHALT OCL Statement", "CANCEL OCL Statement"), chapter 3 ("PAUSE Statement", "CANCEL Statement") and chapter 4 ("NOHALT Procedure", "RESPONSE Procedure"). Sample: `samples/WAITPAUS.ocl`. None of this has been compiled or run on a system yet.

| OCL | CLLE output | Status | Notes |
|---|---|---|---|
| `// WAIT TIME-hhmmss` | `DLYJOB RSMTIME(hhmmss)` | A | `240000` is written as `000000`. The reference says a time that has already passed means the next day; `RSMTIME` is expected to behave the same (to test). |
| `// WAIT INTERVAL-hhmmss` | `DLYJOB DLY(seconds)` | C | hours x 3600 + minutes x 60 + seconds, at most 86400. |
| `// WAIT INTERVAL-000000` | comment only | A | No delay. |
| `// WAIT` with another keyword, a value that is not 6 digits, hh above 24, mm or ss above 59, or more than `240000` | comment | R | |
| `// PAUSE 'text'` | `SNDUSRMSG MSG('text') VALUES('0') MSGTYPE(*INQ) TOUSR(*REQUESTER) MSGRPY(&PAUSERPY)` | A | The reference sends the message to the display station of an interactive job and to the console for a job from the job queue; `TOUSR(*REQUESTER)` is meant to do the same. Only a reply of `0` continues. `&PAUSERPY` is declared `CHAR(1)`. Not tested. |
| `// PAUSE` | same with the text `PAUSE -- when ready, enter 0 to continue` | A | The default text of the reference. |
| `// PAUSE` text without apostrophes, an apostrophe that is not doubled, text over 500 characters, or an expression that is not converted | comment | R | The S/36 display shows only the first 68 characters, the CL message shows all of it. Text with `?...?` expressions is built into `&MSGOUT` (see OCL-11). |
| `// NOHALT 0[,JOB]` | `CHGJOB INQMSGRPY(*RQD)` | A | Also accepted without `//` (the NOHALT procedure has the same operands). |
| `// NOHALT 1[,JOB]` to `4` | `CHGJOB INQMSGRPY(*DFT)` | A | The reference says OS/400 does not use the severity level, only the reply (job basis for the job message queue), so levels 1 to 4 are not told apart. JOB is assumed inside a procedure. |
| `// NOHALT n,SESSION` or `,SYSTEM` | comment | R | The level is meant for later jobs or other display stations, which a CL program cannot set. |
| `// CANCEL` | `DLCOBJ` of the marker lock, `RETURN` | A | The reference cancels the procedure and treats the job end as abnormal, returning to the keyboard. Written like `// RETURN`, so a called program returns to its caller only; the abnormal end is not reproduced. `// IFF DATAF1-FILEA CANCEL` works through the usual condition handling. |
| `// CANCEL PRT,...` | comment | R | Cancels spool file entries (printer ID, `ALL`, `FORMS`, `USER`). Not converted yet: the two-character S/36 printer ID has no known AS/400 device name, and the `*JOBCTL` scope needs a decision (OCL-10). |

## LIBRARY, SESSION, MEMBER and MRTPROC

Evidence: SC41-4731, chapter 5 ("LIBRARY OCL Statement", "SESSION OCL Statement", "MEMBER OCL Statement"); SC41-4730, chapter 13 ("Mapping SESSION OCL Statement to the OVRICFDEVE Command", Figure 13-10) and chapter 1 and 5 (a message member is a message file, `*MSGF`). Sample: `samples/LIBSESS.ocl`. None of this has been compiled or run on a system yet.

| OCL | CLLE output | Status | Notes |
|---|---|---|---|
| `// LIBRARY NAME-lib[,SESSION-NO]` | `CHGCURLIB CURLIB(lib)`; at every exit `CHGCURLIB CURLIB(&OLDCURLIB)` | A | The reference says the library is current only while the procedure runs, and the previous one is current again at the end. The program starts with `RTVJOBA CURLIB(&OLDCURLIB)` (`*NONE` is kept as `*CRTDFT`). The restore is written at `// RETURN`, `// CANCEL` and the end of the program, after the first LIBRARY statement in the source only. The OS/400 search order differs from the S/36 one (system libraries first); not reproduced. |
| `// LIBRARY NAME-0` | `CHGCURLIB CURLIB(*CRTDFT)` | A | Only `#LIBRARY` is searched on the S/36 system; here no current library. |
| `// LIBRARY NAME-lib,SESSION-YES` | `CHGCURLIB CURLIB(lib)` at every exit | A | The session library takes effect after the job ends, not for the running procedure, so the change is made when the program exits and stays. |
| `// LIBRARY` with both SESSION-NO and SESSION-YES in one procedure, between LOAD and RUN, a name that is not valid, or other operands | comment | R | |
| `// SESSION SYMID-id,LOCATION-name[,GROUP-mode][,APPCNET-YES\|NO]` between LOAD and RUN | `OVRICFDEVE PGMDEV(id) RMTLOCNAME(name) [MODE(mode)]` | A | APPC form, mapping from Figure 13-10 (`APPCNET` is checked and ignored). The reference says an OVRICFDEVE run from a CL program applies only while that program runs, so no `DLTOVR` is written (to test). A SYMID that starts with a digit (`1S`) may need quotes. |
| `// SESSION` for the other communications types (BSCEL, asynchronous, finance, retail, SNUF: `LWSID`, `APPLID`, `PARTNER`, ...), not between LOAD and RUN, or bad operands | comment | R | Figure 13-10 shows the mapping, but the value formats are not known for these types. |
| `// MEMBER USER1-m,...` | no CL, see OCL-11 below | A | |
| `MRTPROC` | procedure call (OCL-02) | A | Not an OCL statement: the IBM guide uses MRTPROC as the name of a sample MRT procedure. A MRT procedure converts like any other procedure; the MRT behaviour (several requesters, `MRTMAX`) belongs to the program and the procedure attributes, not to the source. Taken out of the reserved word list so it is called like any other procedure. |

## Message statements, MEMBER and ?Mmic? (OCL-11)

Evidence: SC41-4731, chapter 3 ("// * (Informational Message) Statement", "// ** (System Console Message) Statement", "?Mmic? or ?M'mic,position,length'? Expression"), chapter 4 ("CREATE Procedure", message member statements) and chapter 5 ("MEMBER OCL Statement"); SC41-4730, chapter 15 ("Message Files and the System/36 Environment"). Sample: `samples/MSGMEM.ocl`. None of this has been compiled or run on a system yet.

A message member is a message file (`*MSGF`) on the AS/400 system, made by `CREATE` or `CRTS36MSGF` from a source member of type MSGF36. Each message becomes a message description; the 4-digit message identification code (MIC) becomes a 7-character message ID, the first 3 characters being a prefix that is `USR` unless it was changed (rules: the prefix is the same for the whole file and is taken from the first message of the file). The converter cannot see the message file, so it assumes `USR` (constant `C_MSGPREFIX` in `IAoclCvt`).

| OCL | CLLE output | Status | Notes |
|---|---|---|---|
| `// MEMBER USER1-m[,USER2-m][,LIBRARY-lib]` | no CL line | A | The names are kept while the source is converted. `USER1-0` means no current member. `LIBRARY` stays until another MEMBER statement gives one (the reference does not say whether an omitted LIBRARY clears it). `PROGRAM1` and `PROGRAM2` (IBM licensed program messages) are accepted and ignored. Programs that read the current message member on their own are not changed, because CL has no command that sets it. Every `// RUN` that follows while a USER1 or USER2 member is current gets an A note on the report ("MEMBER USER1-x is current; PROGRAM may read it") so the called programs can be checked. A conditional MEMBER statement, a name that is not valid or other operands are R. |
| `// * 'text'` | `SNDUSRMSG MSG('text') TOUSR(*REQUESTER)` | A | The message goes to the display station that submitted the job, or to the system console for a job from the job queue (as the reference says); `TOUSR(*REQUESTER)` is meant to do the same. `INFOMSG NO` (which hides `// *` messages) is not converted. Text up to 505 characters. |
| `// * mic` | `SNDUSRMSG MSGID(USRmic) MSGF([lib/]file) TOUSR(*REQUESTER)` | A | The file is the current USER1 member. R when no `MEMBER USER1` came before it or the code is not 4 digits. |
| `// ** 'text'` or `// ** mic` | `SNDUSRMSG ... VALUES('0') MSGTYPE(*INQ) TOMSGQ(*SYSOPR) MSGRPY(&PAUSERPY)` | A | QSYSOPR, the job waits for the reply 0, like PAUSE. Text up to 504 characters. |
| Message text with `?...?` expressions (also in `PAUSE`) | `CHGVAR VAR(&MSGOUT) VALUE('text ' *CAT &P1 *TCAT ' more')`, `MSG(&MSGOUT)` | A | `&MSGOUT` is `CHAR(512)`. Trailing blanks of an expression are removed (`*TCAT`), blanks of the text are kept (`*CAT`). A text with a `?` that is not an expression, or an expression that cannot be converted, is R. |
| `?Mmic?`, `?M'mic,position,length'?` | `RTVMSG MSGID(USRmic) MSGF(file) MSG(&MSGTXT)`, then `CHGVAR VAR(&Mn) VALUE(%SST(&MSGTXT pos len))` | A | Written before the statement that uses it. `&Mn` is `CHAR(75)` and `&MSGTXT` `CHAR(132)`; a missing message gives blanks (`MONMSG`). Position 1 to 75, position + length at most 76. Needs a `MEMBER USER1` before it; without one the expression is not converted and the statement is R. |

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
| `?F'A,name'?` | `&Fn`, 8 characters with leading zeros | A | The actual number of data records. See below. |
| `?Mmic?`, `?M'mic,p,n'?` | `&Mn`, 75 characters | A | Text of a message of the USER1 message file, read with `RTVMSG`. See "Message statements, MEMBER and ?Mmic?". |
| `?n'value'?`, `?F'T,name'?`, `?F'A,name,date'?`, `?nT'..'?` and the other forms | not converted | The statement is copied as a comment (R). |

`?F'A,name'?` (evidence: SC41-4731, chapter 3, "?F'A,name'? (Actual File Size) Expression"): the result is 8 digits with leading zeros, 00000000 when the file does not exist, has no member or is locked, and 16777215 at most. For each use the converter writes, before the statement:

```
CHGVAR VAR(&FSN) VALUE(0)
RTVMBRD FILE(name) MBR(*LAST) NBRCURRCD(&FSN)
MONMSG MSGID(CPF0000) EXEC(CHGVAR VAR(&FSN) VALUE(0))
IF COND(&FSN *GT 16777215) THEN(CHGVAR VAR(&FSN) VALUE(16777215))
CHGVAR VAR(&FSD) VALUE(&FSN)
CHGVAR VAR(&F1) VALUE(&FSD)
```

`&FSN` is `*DEC (10 0)`, `&FSD` is `*DEC (8 0)` and `&F1` is `*CHAR (8)`; the move through `&FSD` gives the leading zeros. Checked against the IBM i 7.3 CL reference: `RTVMBRD` `NBRCURRCD` is the number of non-deleted records, and `MBR(*LAST)` is the last member in a date-ordered list, which matches "the member with the most recent creation date". Remaining assumption (A): the file is found on the library list (SC41-4730 chapter 11 says the file size expressions use the library list when the library list search is on; `?FLIB?`, the current files library, is not converted). `?F'S,name'?` (allocated size) is converted as the initial number of records of the file (A): one `DSPFD TYPE(*ATR) FILEATR(*PF)` per file into `QTEMP/IAFD`, read once before the body with `DCLF QSYS/QAFDPHY` (field `PHRCDC`, **name not yet verified on a system**; change `C_FDINITFLD` if it differs), 8 digits with leading zeros, `00000000` when the file is not found. S/36 returns the size in the unit (blocks or records) given when the file was created; that unit is not kept, so the value is treated as records. A form with a creation date is R. In a `FILE` statement `?F'...'?` is used with `BLOCKS-` or `RECORDS-` to create a file, and creating the file (`DISP-NEW`) is not converted yet, so those statements stay R.

CL cannot put a variable inside a word or a quoted text. Where OCL has an expression inside a name (for example `LABEL-STK?10?TRI`), the converter builds the name into a temporary variable `&Tn` with `CHGVAR ... *TCAT ...` before the statement and uses `&Tn` (FILE and LOAD operands). In a copied command (a line without `//`) an expression inside a word is not converted (R).

## EVALUATE

`// EVALUATE Pn[,length]=value ...` becomes `CHGVAR VAR(&Pn) VALUE(...)` for each item. Converted values: a text constant in apostrophes (or `''` for blank), one expression written inside apostrophes (`P10='?L'201,2'?'` is the same as `P10=?L'201,2'?`: `RTVDTAARA DTAARA(*LDA (201 2)) RTNVAR(&L201_2)` then `CHGVAR VAR(&P10) VALUE(&L201_2)`), a number (leading zeros dropped, or padded or cut to the length), `?USER?`, `?WS?`, `?DATE?`, `?L'p,n'?`, `?n?`. Arithmetic (`+ - * /` and parentheses), `?F'...'?` and other expressions are not converted (R, one report line per item). Words that are not `Pn=...` are comment text and become a CL comment. Status C, or A when a passed parameter is assigned.

## Other rules

- A statement that ends with a comma continues on the next line (a leading `//` on that line is dropped). Confirmed by the IBM guide.
- Lines after `// RUN` that are not statements are treated as program data and copied as comments (R), until the next `//` statement.
- `/*` and `/&` marker lines are copied as comments (R).
- Statement keywords are matched ignoring case; names are written in upper case.

## ALLOCATE, DEALLOC, ATTR, SCRATCH (OCL-05)

Evidence: SC41-4731 chapter 5 (`ALLOCATE`, `DEALLOC`, `ATTR`), chapter 3 Table 3-1 (`?CD?` return codes) and appendix A ("$DELET Utility"). The device names and run priorities are constants at the top of IAoclCvt and were **not tested on a system**.

| OCL | CLLE output | Status |
|---|---|---|
| `// ALLOCATE UNIT-I1\|T1\|T2\|'T1,T2'\|TC[,WAIT-YES\|NO]` | `CHGVAR &CD '0000'`, `ALCOBJ OBJ((QSYS/dev *DEVD *EXCL))` (`WAIT(0)` for WAIT-NO), `MONMSG CPF1002` sets `&CD` to the in-use code | A |
| `?CD?` | `&CD` (4 characters, declared when used). 2033 diskette, 2036 tape 1, 2038 tape 2, 2042 tape cartridge | A |
| `// DEALLOC UNIT-...` | `DLCOBJ`, `MONMSG CPF0000` | A |
| `// ATTR PRIORITY-HIGH\|MEDIUM\|LOW` | `CHGJOB RUNPTY(10\|20\|50)` | A |
| `// ATTR` with CANCEL-YES, INQUIRY-YES, NEP-NO, MRTWAIT-YES, RELEASE-NO, NOTIFY-NO | nothing (normal behaviour), comment | A |
| `// ATTR` with CANCEL-NO, INQUIRY-NO, NEP-YES, MRTMAX, MRTWAIT-NO, RELEASE-YES, NOTIFY-JOB, PRIORITY-NO | comment | R |
| `// LOAD $DELET`, `// RUN`, `// SCRATCH LABEL-file,UNIT-F1`, `// END` | `DLTF FILE(file)`, `MONMSG CPF2105` | A |
| `SCRATCH` for UNIT-I1, LABEL-ALL, DATE, LOCATION, GROUP and other keywords; `REMOVE` | comment | R |

Assumptions: WAIT-YES (the default) waits the `ALCOBJ` default of 30 seconds, not the class wait time; `AUTO-YES` (next tape drive) is not converted; `CONTINUE` is accepted for diskette only. `SCRATCH` looks for the file on the library list and ignores a missing file; the reference does not say what S/36 does.

## Not converted yet

Statements seen in the IBM guides but not converted: calls of the IBM-supplied procedures (`BLDFILE` is converted, and calls of your own procedures are converted), `PROMPT`, `HELP`, `INCLUDE`, `SESSION` for communications types other than APPC, and `CANCEL PRT,...` (spool file entries). Each is copied as a comment and reported R.
