      * RPG IV program described WORKSTN and DISK files (FREE-46, FREE-47, RV-31)
     FDSPIN     CF   F   80        WORKSTN
     FDSPOUT    O    F   80        WORKSTN
     FHISTORY   O    F   40        DISK
     DName             S             20A
     DAmt              S              7P2
     IDSPIN     AA
     I                                  1   10  CODE
     I                                 11   30  NAME
     C                   READ      DSPIN
     C                   EVAL      AMT = 100
     C                   EXCEPT    SCREEN
     C                   EXCEPT    LOGREC
     C                   EVAL      *INLR = *ON
      * program described display output: exception record, fields by end position
     ODSPOUT    E            SCREEN
     O                       NAME                20
     O                                           30 'DONE'
      * program described DISK output
     OHISTORY   E            LOGREC
     O                       NAME                20
     O                       AMT                 27
