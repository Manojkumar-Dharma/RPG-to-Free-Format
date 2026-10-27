     FORDERS    UF   E           K DISK
     DCount            S        5      I
     DTotal            S        9       2
     DKey              S        6       0
     DName             S        10     A
     DShort            S        4      A
     DFlag             S               N
     DQ                S        5      I
     DRem              S        5      I
     DDigits           S        10     A
     DIdx              S        5      I
     DNow              S        6      P0
     DPos              S        3      P0
     DFull             S        30     A
     DBits             S        1      A
     DMaskF            S        1      A
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
      * ANDxx and ORxx after comment lines (FREE-28)
     C     Count         IFGT      1
      * second condition
     C     Count         ANDLT     9
      * or the total is zero
      * (two comment lines)
     C     Total         OREQ      0
     C                   ADD       1             Count
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
     C     'abc':'ABC'   XLATE     Name          Full
     C     Count         DIV       3             Q
     C                   MVR                     Rem
     C     *LIKE         DEFINE    Name          Copy
     C                   TESTN                   Digits               61  62
      * Conditioned groups and DO without an index (FREE-21)
     C   01Count         IFEQ      1
     C     Count         ADD       1             Count
     C                   ELSE
     C     Count         SUB       1             Count
     C                   ENDIF
     C  N02Count         DOWLT     10
     C     Count         ADD       1             Count
     C                   ENDDO
     C   03              DO        3
     C     Count         ADD       1             Count
     C                   ENDDO
     C                   DO        2
     C     Count         ADD       1             Count
     C                   ENDDO
      * Bit operations and TESTZ (FREE-22)
     C                   BITON     '0'           Bits
     C                   BITOF     '67'          Bits
     C                   BITON     X'88'         Bits
     C                   BITON     MaskF         Bits
     C                   TESTB     '07'          Bits                 616263
     C                   TESTB     X'01'         Bits                 61  63
     C                   TESTZ                   Bits                 616263
     C                   BITON     '8'           Bits
     C                   TESTB     '0'           Digits                   61
     C                   BITON     '0'           Bits                 61
