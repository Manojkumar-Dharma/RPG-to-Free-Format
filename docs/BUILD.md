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

Modules, in any order (use `INCDIR('REPO/src/common')` so `/copy 'IAcnvSrvP.rpgleinc'` is found):

```
CRTRPGMOD MODULE(MYLIB/IAcnvTyp) SRCSTMF('REPO/src/common/IAcnvTyp.rpgle') INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTRPGMOD MODULE(MYLIB/IAcnvSys) SRCSTMF('REPO/src/common/IAcnvSys.rpgle') INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTRPGMOD MODULE(MYLIB/IAcnvVal) SRCSTMF('REPO/src/common/IAcnvVal.rpgle') INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTRPGMOD MODULE(MYLIB/IAcnvIfs) SRCSTMF('REPO/src/common/IAcnvIfs.rpgle') INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTRPGMOD MODULE(MYLIB/IAcnvIO)  SRCSTMF('REPO/src/common/IAcnvIO.rpgle')  INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTRPGMOD MODULE(MYLIB/IAcnvRpt) SRCSTMF('REPO/src/common/IAcnvRpt.rpgle') INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTSQLRPGI OBJ(MYLIB/IAcnvMbr) SRCSTMF('REPO/src/common/IAcnvMbr.sqlrpgle') COMMIT(*NONE) OBJTYPE(*MODULE) INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
```

Then:

```
CRTSRVPGM SRVPGM(MYLIB/IAcnvSrv) MODULE(MYLIB/IAcnvTyp MYLIB/IAcnvSys MYLIB/IAcnvVal MYLIB/IAcnvIfs MYLIB/IAcnvMbr MYLIB/IAcnvIO MYLIB/IAcnvRpt) EXPORT(*SRCFILE) SRCSTMF('REPO/src/common/IAcnvSrv.bnd')
```

## 3. IAOCLTOCLE

```
CRTRPGMOD MODULE(MYLIB/IAoclCvt)   SRCSTMF('REPO/src/oclcle/IAoclCvt.rpgle')   INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTRPGMOD MODULE(MYLIB/IAoclToCle) SRCSTMF('REPO/src/oclcle/IAoclToCle.rpgle') INCDIR('REPO/src/common') DBGVIEW(*SOURCE)
CRTPGM PGM(MYLIB/IAOCLTOCLE) MODULE(MYLIB/IAOCLTOCLE MYLIB/IAOCLCVT) BNDSRVPGM(MYLIB/IAcnvSrv) ACTGRP(*NEW)
CRTCMD CMD(MYLIB/IAOCLTOCLE) PGM(MYLIB/IAOCLTOCLE) SRCSTMF('REPO/src/oclcle/IAOCLTOCLE.cmd')
```

## 4. First test

```
IAOCLTOCLE SRCLIB(MYLIB) SRCFILE(QS36PRC) SRCMBR(MYPROC) SRCTYPE(OCL36)
           TGTLIB(*SRCLIB) TGTFILE(QCLLESRC) TGTMBR(*SRCMBR) TGTTYPE(CLLE)
```

Then look at the spooled report (`IACNVRPT`) and the new member. Send the compile messages or the result back so fixes can be pushed.
