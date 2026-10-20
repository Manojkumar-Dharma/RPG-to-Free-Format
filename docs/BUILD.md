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

Every source is `.sqlrpgle` and is compiled with CRTSQLRPGI (module). The activation group is set on CRTPGM/CRTSRVPGM, never in the source (no `dftactgrp` in a module). Modules, in any order (use `INCDIR('REPO/src/common')` so `/copy IAcnvSrvP` is found):

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

## 5. IACNVDSPF (DSP36 or DSP38 to DSPF)

Uses the same service program IAcnvSrv.

```
CRTSQLRPGI OBJ(MYLIB/IAdspCvt)  SRCSTMF('REPO/src/dspf/IAdspCvt.sqlrpgle')  COMMIT(*NONE) OBJTYPE(*MODULE) INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTSQLRPGI OBJ(MYLIB/IAcnvDspf) SRCSTMF('REPO/src/dspf/IAcnvDspf.sqlrpgle') COMMIT(*NONE) OBJTYPE(*MODULE) INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTPGM PGM(MYLIB/IACNVDSPF) MODULE(MYLIB/IAcnvDspf MYLIB/IAdspCvt) BNDSRVPGM(MYLIB/IAcnvSrv) ACTGRP(*NEW)
CRTCMD CMD(MYLIB/IACNVDSPF) PGM(MYLIB/IACNVDSPF) SRCSTMF('REPO/src/dspf/IACNVDSPF.cmd')
```

First test, with the sample member copied into a source file as type DSP36:

```
IACNVDSPF SRC(MYLIB/QS36SRC EMPSCR) SRCTYPE(DSP36) TGT(QDDSSRC)
```

Then `CRTDSPF FILE(MYLIB/EMPSCR) SRCFILE(MYLIB/QDDSSRC) SRCMBR(EMPSCR)`.

## Grouped file and member parameters

`SRC(lib/file member)` and `TGT(lib/file member)` replace the separate library, file and member keywords:

```
IAOCLTOCLE SRC(MYLIB/QS36PRC MYPROC) SRCTYPE(OCL36)                 /* target library = source library, member = MYPROC */
IAOCLTOCLE SRC(MYLIB/QS36PRC MYPROC) SRCTYPE(OCL36) TGT(OTHERLIB/QCLLESRC NEWNAME)
IAOCLTOCLE SRC(*NONE MYPROC) SRCTYPE(OCL36) SRCIFS('/home/me/ocl') TGT(*NONE *SRCMBR) TGTIFS('/home/me/out')
```

The target file defaults to `*SRCFILE` (the source file) and the target library to `*SRCLIB` (the library the source file is found in, even when the source library is `*LIBL`), so `TGT(*SRCFILE *SRCMBR)` is the default; it is rejected because source and target are the same, so give a different file, library or member. `TGT(QCLLESRC)` alone uses the source library and the source member name. `*NONE` as the file means an IFS location (then use SRCIFS or TGTIFS). When the target is omitted, the target is an IFS directory only if TGTIFS is given; otherwise the validation fails with the usual message.
