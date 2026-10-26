     FORDERS    UF   E           K DISK
     DCount            S        5      I
     DTotal            S        9       2
     DKey              S        6       0
     DName             S        10     A
     DShort            S        4      A
     DFlag             S               N
     DIdx              S        5      I
     DNow              S        6      P0
     DPos              S        3      P0
     DFull             S        30     A
     C*Main loop
     C     Init          BEGSR
     C                   EVAL      Count = 0
     C                   Z-ADD     0             Total
     C                   ENDSR
     C     Key           CHAIN(E)  ORDERS
     C                   IF        %found(ORDERS) and Count < 10
     C     Total         ADD       5             Total
     C                   ELSE
     C                   EVAL      Total = Total + Count * 2 + 100000 +
     C                             Count
     C                   ENDIF
     C                   SELECT
     C     Count         WHENEQ    1
     C                   SETON                                        01
     C                   OTHER
     C                   SETOFF                                       01
     C                   ENDSL
     C     Count         DOWLT     5
     C                   ADD       1             Count
     C                   ENDDO
     C                   EVAL      *inlr = *on
     C     Key           SETLL     ORDERS                             90  89
     C     Key           CHAIN     ORDERS                             9192
     C                   READ      ORDERS                               9394
     C     Count         IFGT      1
     C     Count         ANDLT     9
     C     Total         OREQ      0
     C                   ENDIF
     C     Total         COMP      100                                808182
     C     Total         SUB       1             Total                707172
     C  N90              ADD       1             Count
     C   91              SETON                                          9293
     C                   MOVE      Short         Name
     C                   MOVEL     'ABC'         Name
     C                   MOVE      '1'           *IN50
     C                   MOVE      *BLANKS       Name
     C                   MOVE      Count         Name
     C     Name          CAT       Short:1       Full
     C     'AB'          SCAN      Name:2        Pos
     C     'AB'          SCAN      Name                                   60
     C     3             SUBST(P)  Name:2        Full
     C     1             DO        10            Idx
     C     Name          DSPLY
     C                   ENDDO     2
     C                   TIME                    Now
     C                   COMMIT
     C                   DUMP(A)
     C                   CALL(E)   'MYPGM'
     C     'X'           PARM                    Name
     C                   PARM      Total         Total
     C                   CALL      'OTHER'       PL1
     C     PL1           PLIST
     C                   PARM                    Count
