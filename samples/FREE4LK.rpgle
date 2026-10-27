      * RPG IV: LOOKUP on arrays and the error indicator of CALL (RV-53)
     DNames            S        10     A   DIM(10) ASCEND
     DPlain            S        10     A   DIM(10)
     DCode             S        10     A
     DX                S        5      I
     DCount            S        5      I
      * Equal; high; low; high and equal; low and equal
     C     Code          LOOKUP    Names                                  26
     C     Code          LOOKUP    Names                              27
     C     Code          LOOKUP    Names                                28
     C     Code          LOOKUP    Names                              27  26
     C     Code          LOOKUP    Names                                2826
      * With an index: the search starts at X, X is set to the position or 1
     C     Code          LOOKUP    Names(X)                               26
      * Not converted: high without a sequence, a table, no indicator
     C     Code          LOOKUP    Plain                              27
     C     Code          LOOKUP    Names         Names                    26
     C     Code          LOOKUP    Names
      * CALL with an error indicator (columns 73-74)
     C                   CALL      'MYPGM'                              90
     C                   PARM                    Count
