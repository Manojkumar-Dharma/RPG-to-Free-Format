      * RPG IV printer file: EXCEPT and exception records (FREE-42)
     FREPORT    O    F  132        PRINTER OFLIND(*INOA)
     DName             S             20A
     DAmt              S              7P2
     C                   EXCEPT    HEAD
     C                   EVAL      NAME = 'SMITH'
     C                   EVAL      AMT = 1234.5
     C                   EXCEPT    DETAIL
     C  01               EXCEPT    TOTAL
     C                   EVAL      *INLR = *ON
      * heading: space after 1; the constant ends in position 30
     OREPORT    E            HEAD           1
     O                                           30 'CUSTOMER LIST'
      * detail: a field, a numeric field with edit code 1
     OREPORT    E            DETAIL         1
     O                       NAME                20
     O                       AMT           1     32
      * conditioned by indicator 01, skip before 4
     OREPORT    E    01      TOTAL             4
     O                                           12 'END OF LIST'
      * not converted: end position of 5 digits, constant of 27 characters
     OREPORT    E            LONGNAME       1
     O                                        12345 'ABCDEFGHIJKLMNOPQRSTUVWXY'
