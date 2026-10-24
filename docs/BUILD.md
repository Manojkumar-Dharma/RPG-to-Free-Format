# Building by hand (no build tooling yet)

All commands run on IBM i. `MYLIB` is the library that will hold every object. `REPO` is the repo's path in the IFS, for example `/home/manoj/RPG-to-Free-Format`. Nothing here has been compiled yet, so expect to fix compile messages as they appear.

## 1. Library, report file and messages

```
CRTLIB LIB(MYLIB)
CRTPRTF FILE(MYLIB/IACNVRPT) SRCFILE(...) SRCMBR(IACNVRPT) PAGESIZE(66 132)
```

`src/common/IACNVRPT.prtf` is DDS source: copy it into a source member (or use a CPYFRMSTMF) and compile it from there.

```
CRTBNDCL PGM(MYLIB/IACNVMSG) SRCSTMF('REPO/msg/IACNVMSG.clle')
CALL PGM(MYLIB/IACNVMSG) PARM('MYLIB')
```

Put `MYLIB` on the library list afterwards (the programs find the message file and report file through `*LIBL`).

## 2. Service program IAcnvSrv

Every source is `.sqlrpgle` and is compiled with CRTSQLRPGI (module). The activation group is set on CRTPGM/CRTSRVPGM, never in the source (no `dftactgrp` in a module). The include is read as `/copy qcpysrc,IAcnvSrvP`, so first put it in a source member of file QCPYSRC (in a library on the library list):

```
CRTSRCPF FILE(MYLIB/QCPYSRC) RCDLEN(112)
CPYFRMSTMF FROMSTMF('REPO/src/common/IAcnvSrvP.rpgleinc') TOMBR('/QSYS.LIB/MYLIB.LIB/QCPYSRC.FILE/IAcnvSrvP.MBR') MBROPT(*REPLACE)
CHGPFM FILE(MYLIB/QCPYSRC) MBR(IAcnvSrvP) SRCTYPE(RPGLEINC)
```

Repeat the CPYFRMSTMF after every change to `IAcnvSrvP.rpgleinc`. Modules, in any order (the `INCDIR` entry is no longer needed, but harmless):

```
CRTSQLRPGI OBJ(MYLIB/IAcnvTyp) SRCSTMF('REPO/src/common/IAcnvTyp.sqlrpgle') COMMIT(*NONE) OBJTYPE(*MODULE) INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTSQLRPGI OBJ(MYLIB/IAcnvSys) SRCSTMF('REPO/src/common/IAcnvSys.sqlrpgle') COMMIT(*NONE) OBJTYPE(*MODULE) INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTSQLRPGI OBJ(MYLIB/IAcnvVal) SRCSTMF('REPO/src/common/IAcnvVal.sqlrpgle') COMMIT(*NONE) OBJTYPE(*MODULE) INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTSQLRPGI OBJ(MYLIB/IAcnvIfs) SRCSTMF('REPO/src/common/IAcnvIfs.sqlrpgle') COMMIT(*NONE) OBJTYPE(*MODULE) INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTSQLRPGI OBJ(MYLIB/IAcnvIO) SRCSTMF('REPO/src/common/IAcnvIO.sqlrpgle') COMMIT(*NONE) OBJTYPE(*MODULE) INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTSQLRPGI OBJ(MYLIB/IAcnvRpt) SRCSTMF('REPO/src/common/IAcnvRpt.sqlrpgle') COMMIT(*NONE) OBJTYPE(*MODULE) INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTSQLRPGI OBJ(MYLIB/IAcnvMbr) SRCSTMF('REPO/src/common/IAcnvMbr.sqlrpgle') COMMIT(*NONE) OBJTYPE(*MODULE) INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
```

Then:

```
CRTSRVPGM SRVPGM(MYLIB/IAcnvSrv) MODULE(MYLIB/IAcnvTyp MYLIB/IAcnvSys MYLIB/IAcnvVal MYLIB/IAcnvIfs MYLIB/IAcnvMbr MYLIB/IAcnvIO MYLIB/IAcnvRpt) EXPORT(*SRCFILE) SRCSTMF('REPO/src/common/IAcnvSrv.bnd')
```

## 3. IAOCLTOCLE

```
CRTSQLRPGI OBJ(MYLIB/IAoclCvt) SRCSTMF('REPO/src/oclcle/IAoclCvt.sqlrpgle') COMMIT(*NONE) OBJTYPE(*MODULE) INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTSQLRPGI OBJ(MYLIB/IAoclToCle) SRCSTMF('REPO/src/oclcle/IAoclToCle.sqlrpgle') COMMIT(*NONE) OBJTYPE(*MODULE) INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTPGM PGM(MYLIB/IAOCLTOCLE) MODULE(MYLIB/IAoclToCle MYLIB/IAoclCvt) BNDSRVPGM(MYLIB/IAcnvSrv) ACTGRP(*NEW)
CRTCMD CMD(MYLIB/IAOCLTOCLE) PGM(MYLIB/IAOCLTOCLE) SRCSTMF('REPO/src/oclcle/IAOCLTOCLE.cmd')
```

## 4. First test

```
IAOCLTOCLE SRC(MYLIB/QS36PRC MYPROC) SRCTYPE(OCL36) TGT(QCLLESRC)
```

Then look at the spooled report (`IACNVRPT`) and the new member. Send the compile messages or the result back so fixes can be pushed.

## 5. IACNVDSPF (DSPF36 or DSPF38 to DSPF)

Uses the same service program IAcnvSrv.

```
CRTSQLRPGI OBJ(MYLIB/IAdspCvt)  SRCSTMF('REPO/src/dspf/IAdspCvt.sqlrpgle')  COMMIT(*NONE) OBJTYPE(*MODULE) INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTSQLRPGI OBJ(MYLIB/IAcnvDspf) SRCSTMF('REPO/src/dspf/IAcnvDspf.sqlrpgle') COMMIT(*NONE) OBJTYPE(*MODULE) INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTPGM PGM(MYLIB/IACNVDSPF) MODULE(MYLIB/IAcnvDspf MYLIB/IAdspCvt) BNDSRVPGM(MYLIB/IAcnvSrv) ACTGRP(*NEW)
CRTCMD CMD(MYLIB/IACNVDSPF) PGM(MYLIB/IACNVDSPF) SRCSTMF('REPO/src/dspf/IACNVDSPF.cmd')
```

First test, with the sample member copied into a source file as type DSPF36:

```
IACNVDSPF SRC(MYLIB/QS36SRC DSPFALL) SRCTYPE(DSPF36) TGT(QDDSSRC) MSGF(MYLIB/ORDMSGF)
```

Then `CRTDSPF FILE(MYLIB/DSPFALL) SRCFILE(MYLIB/QDDSSRC) SRCMBR(DSPFALL)`.

A source with message fields (D column 56 = M) needs the message file they refer to (`MSGF` parameter). It is read when the program runs, so it only has to be on the library list then, not when the display file is created.

Without `MSGF` message fields are reported for review and kept as program output fields. Module IAdspCvt must be compiled before IAcnvDspf is bound: after this change `DspConvert` has two more parameters (message file and library), so compile both modules again and run CRTPGM and CRTCMD again.

## 6. IACNVFREE (RPG36 to fully free-form RPGLE)

Uses the same service program IAcnvSrv. Only RPG36 source is converted so far; other source types end with message IAC0103. Run `IACNVMSG` again after pulling this change (it adds IAC0103 and IAC0104).

**Rule tables first.** The conversion rules are in `rules/*.json` and are loaded into Db2 tables (see `docs/RPG-MAPPING.md`). Edit the path in the `SET IARULESDIR` statement of `rules/IACNVRULES.sql` to the `rules/` directory of the repo in the IFS (keep the trailing slash), then:

```
RUNSQLSTM SRCSTMF('REPO/rules/IACNVRULES.sql') COMMIT(*NONE) NAMING(*SYS) DFTRDBCOL(MYLIB)
```

The last statement lists the number of rows of each table (61 operation codes, 6 comparisons, 11 results, 159 indicators, 16 names, 7 built-in functions, 6 settings). Run it again after every change to a JSON file. `JSON_TABLE` needs a recent Db2 group PTF level on IBM i 7.3 (or 7.4 and later); if the statement is rejected, send the message back.

Two more includes go into QCPYSRC, the same way as `IAcnvSrvP` (repeat the copy after every change):

```
CPYFRMSTMF FROMSTMF('REPO/src/free/IAfreeRulP.rpgleinc')  TOMBR('/QSYS.LIB/MYLIB.LIB/QCPYSRC.FILE/IAfreeRulP.MBR')  MBROPT(*REPLACE)
CHGPFM FILE(MYLIB/QCPYSRC) MBR(IAfreeRulP) SRCTYPE(RPGLEINC)
CPYFRMSTMF FROMSTMF('REPO/src/free/IAfreeCalcP.rpgleinc') TOMBR('/QSYS.LIB/MYLIB.LIB/QCPYSRC.FILE/IAfreeCalcP.MBR') MBROPT(*REPLACE)
CHGPFM FILE(MYLIB/QCPYSRC) MBR(IAfreeCalcP) SRCTYPE(RPGLEINC)
```

```
CRTSQLRPGI OBJ(MYLIB/IAfreeRul)  SRCSTMF('REPO/src/free/IAfreeRul.sqlrpgle')  COMMIT(*NONE) OBJTYPE(*MODULE) INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTSQLRPGI OBJ(MYLIB/IAfreeCalc) SRCSTMF('REPO/src/free/IAfreeCalc.sqlrpgle') COMMIT(*NONE) OBJTYPE(*MODULE) INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTSQLRPGI OBJ(MYLIB/IAfreeCvt)  SRCSTMF('REPO/src/free/IAfreeCvt.sqlrpgle')  COMMIT(*NONE) OBJTYPE(*MODULE) INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTSQLRPGI OBJ(MYLIB/IAcnvFree)  SRCSTMF('REPO/src/free/IAcnvFree.sqlrpgle')  COMMIT(*NONE) OBJTYPE(*MODULE) INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTPGM PGM(MYLIB/IACNVFREE) MODULE(MYLIB/IAcnvFree MYLIB/IAfreeCvt MYLIB/IAfreeCalc MYLIB/IAfreeRul) BNDSRVPGM(MYLIB/IAcnvSrv) ACTGRP(*NEW)
CRTCMD CMD(MYLIB/IACNVFREE) PGM(MYLIB/IACNVFREE) SRCSTMF('REPO/src/free/IACNVFREE.cmd')
```

The tables are found through the library list, so `MYLIB` has to be on it when IACNVFREE runs.

First test, with `samples/FREEHF.rpg36` and `samples/FREEC.rpg36` copied into a source file (record length 112 or more) as type RPG36:

```
IACNVFREE SRC(MYLIB/QS36SRC FREEHF) SRCTYPE(RPG36) TGT(QRPGLESRC)
IACNVFREE SRC(MYLIB/QS36SRC FREEC)  SRCTYPE(RPG36) TGT(QRPGLESRC)
```

Expected result: the control and file description specifications become `ctl-opt` and `dcl-f` statements, the calculation specifications become statements as described in `docs/RPG-MAPPING.md`, and everything else (E, I and O specifications, compile-time data) is kept as `// RPG II:` comments and reported R. The target is not meant to compile yet: fields from the I and E specifications are not declared.

## Grouped file and member parameters

`SRC(lib/file member)` and `TGT(lib/file member)` replace the separate library, file and member keywords:

```
IAOCLTOCLE SRC(MYLIB/QS36PRC MYPROC) SRCTYPE(OCL36)                 /* target library = source library, member = MYPROC */
IAOCLTOCLE SRC(MYLIB/QS36PRC MYPROC) SRCTYPE(OCL36) TGT(OTHERLIB/QCLLESRC NEWNAME)
IAOCLTOCLE SRC(*NONE MYPROC) SRCTYPE(OCL36) SRCIFS('/home/me/ocl') TGT(*NONE *SRCMBR) TGTIFS('/home/me/out')
```

The target file defaults to `*SRCFILE` (the source file) and the target library to `*SRCLIB` (the library the source file is found in, even when the source library is `*LIBL`), so `TGT(*SRCFILE *SRCMBR)` is the default; it is rejected because source and target are the same, so give a different file, library or member. `TGT(QCLLESRC)` alone uses the source library and the source member name. `TGTIFS(*SRC)` puts the target in the same directory as the source (only when `SRCIFS` is used; the member name and type then have to differ, which they do when converting OCL36 to CLLE). `*NONE` as the file means an IFS location (then use SRCIFS or TGTIFS). When the target is omitted, the target is an IFS directory only if TGTIFS is given; otherwise the validation fails with the usual message.
