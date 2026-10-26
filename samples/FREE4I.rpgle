      * RPG IV input specifications of program described files (FREE-23)
     FINFILE    IF   F   60        DISK
     FUPFILE    UF   F   20        DISK
     FEXTFIL    IF   E             DISK
     IINFILE    AA
     I                                  1   10  CUSTNM
     I                             P   11   15 2BALANCE
     I                             S   16   20 0ZIPCOD
     I                             B   21   22 0COUNT2
     I                             I   23   26 0COUNT4
     I                             N   27   27  FLAGN
     I                             F   28   31  RATE
     I                             A   32   40  NOTE
     I                             L   41   45 2SIGNED
     I                                 46   50 0LVL                 L1
     IUPFILE    AA
     I                                  1   20  UPREC
     IEXTFIL    AA
     INOFILE    AA
     IINFILE    01
     C                   READ      INFILE
     C     KEY           CHAIN     UPFILE
     C                   UPDATE    UPFILE
