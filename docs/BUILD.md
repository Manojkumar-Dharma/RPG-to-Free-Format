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
IAOCLTOCLE SRCLIB(MYLIB) SRCFILE(QS36PRC) SRCMBR(MYPROC) SRCTYPE(OCL36)
           TGTLIB(*SRCLIB) TGTFILE(QCLLESRC) TGTMBR(*SRCMBR) TGTTYPE(CLLE)
```

Then look at the spooled report (`IACNVRPT`) and the new member. Send the compile messages or the result back so fixes can be pushed.
