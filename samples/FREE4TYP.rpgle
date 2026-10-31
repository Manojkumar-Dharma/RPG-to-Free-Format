      * RPG IV cycle with two record types of the primary file (FREE-69, RV-21)
      * Type A (01): record code A in position 1, CUST and AMT. Type B (02): code B
      * or C, NOTE. CTOT adds the amounts of type A, NOTES counts the records of type B.
     FSALES     IP   F   80        DISK
     FREPORT    O    F  132        PRINTER OFLIND(*INOA)
     ISALES     AA  01    1 CA
     I                                  2    4 0CUST          L1
     I                                  5   10 2AMT
     ISALES     BB  02    1 CB
     I       OR           1 CC
     I                                  2   20   NOTE
     C   01              ADD       AMT           CTOT              9 2
     C   02              ADD       1             NOTES             5 0
     CL1                 ADD       CTOT          GRAND             9 2
     OREPORT    H    1P                     1
     O           OR  OA
     O                                           25 'Sales by customer'
     OREPORT    D                           1
     O                       CUST                10
     O                       AMT           1     25
     OREPORT    T    L1                     2
     O                                           20 'Customer total'
     O                       CTOT          1     35
     OREPORT    T    LR                     2
     O                                           20 'Grand total'
     O                       GRAND         1     35
