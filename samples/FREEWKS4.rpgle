      * WORKSTN display file, externally described, RPG IV (FREE-45, RV-12, RV-31)
     FDSPFILE   CF   E             WORKSTN SFILE(SFLREC:RRN)
     FDSPOUT    O    E             WORKSTN
     DRRN              S              4S0
     C                   EVAL      RRN = 1
     C                   WRITE     SFLREC
     C                   EXFMT     CTLREC                               90
     C                   READC     SFLREC                                 91
     C     RRN           CHAIN     SFLREC                             92
     C                   UPDATE    SFLREC
     C                   CLOSE     DSPFILE
     C                   ACQ       DSPFILE
      * FREE-71: program device in factor 1; the ACQ above has none (R)
     C     'DEV1'        ACQ       DSPFILE                              93
     C     'DEV1'        NEXT      DSPFILE
     C                   POST      DSPFILE
     C     'DEV1'        REL(E)    DSPFILE
     C                   EVAL      *INLR = *ON
