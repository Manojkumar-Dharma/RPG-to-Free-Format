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
     C                   EVAL      *INLR = *ON
