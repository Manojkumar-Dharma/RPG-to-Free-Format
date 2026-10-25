     FORDERS    UF   E           K DISK
     DCount            S        5      I
     DTotal            S        9       2
     DKey              S        6       0
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
     C     X             MOVE      Total         Name
     C                   EVAL      *inlr = *on
