      * RPG IV: MOVEA of whole arrays and DEFINE *LIKE with a length change (FREE-31)
     DNames            S             10A   DIM(10)
     DCopy             S             10A   DIM(10)
     DShort            S              5A   DIM(5)
     DCodes            S              4A   DIM(10)
     DNums             S              7P2  DIM(10)
     DName             S             10A
     DAmt              S              7P2
     DCnt              S              5I
      * MOVEA: same DIM and element type; *BLANKS and *ZEROS
     C                   MOVEA     Names         Copy
     C                   MOVEA     *BLANKS       Names
     C                   MOVEA     *ZEROS        Nums
      * MOVEA not converted: another DIM, another element length, an index, a field
     C                   MOVEA     Names         Short
     C                   MOVEA     Names         Codes
     C                   MOVEA     Names(2)      Copy
     C                   MOVEA     Name          Copy
     C                   MOVEA     *BLANKS       Nums
      * DEFINE *LIKE, with and without a length change (+n, -n)
     C     *LIKE         DEFINE    Name          Name2
     C     *LIKE         DEFINE    Name          Longer          + 5
     C     *LIKE         DEFINE    Name          Shorter         - 4
     C     *LIKE         DEFINE    Amt           Bigger          + 2
      * Not converted: a length change on an integer, a length that is too small
     C     *LIKE         DEFINE    Cnt           CntX            + 2
     C     *LIKE         DEFINE    Name          Gone            -10
     C                   EVAL      Longer = Name
