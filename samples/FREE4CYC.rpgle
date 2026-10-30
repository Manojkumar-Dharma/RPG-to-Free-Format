      * RPG IV cycle skeleton (FREE-60): program described primary file, levels L1 and L2
     FSALES     IP   F   80        DISK
     FORDHIST   O    F   40        DISK
     ISALES     AA
     I                                  1    3 0REGION        L2
     I                                  4    6 0CUST          L1
     I                                  7   12 2AMT
      * detail calculations: every record
     C                   ADD       AMT           CTOT              9 2
      * total calculations: a break of L1, the last record
     CL1                 Z-ADD     0             CTOT
     CLR                 MOVE      'DONE'        MSG               4
      * a detail record for every record read, a total record at a break of L1
     OORDHIST   D
     O                       CUST                 3
     O                       AMT                  9
