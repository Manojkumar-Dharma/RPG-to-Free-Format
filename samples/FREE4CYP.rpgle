      * RPG IV cycle with heading, detail and total records of a printer file (FREE-62)
     FSALES     IP   F   80        DISK
     FREPORT    O    F  132        PRINTER OFLIND(*INOA)
     ISALES     AA  01
     I                                  1    3 0REGION        L2
     I                                  4    6 0CUST          L1
     I                                  7   12 2AMT
      * detail calculation: every record, with record identifying indicator 01
     C   01              ADD       AMT           CTOT              9 2
      * total calculation: a break of L1
     CL1                 ADD       CTOT          GRAND             9 2
      * heading on the first cycle or overflow, detail for each record, totals
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

