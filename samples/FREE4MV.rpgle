      * RPG IV: MOVEA of whole arrays and DEFINE *LIKE with a length change (FREE-31)
     DNames            S             10A   DIM(10)
     DCopy             S             10A   DIM(10)
     DShort            S              5A   DIM(5)
     DCodes            S              4A   DIM(10)
     DNums             S              7P2  DIM(10)
     DName             S             10A
     DAmt              S              7P2
     DCnt              S              5I
     DDvd              S              9P2
     DDvr              S              5P2
     DQuo              S              9P2
     DRemd             S              9P2
     DQuo0             S              9P0
     DWide             S             10A
     DNarrow           S              4A
     DSame             S             10A
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
      * MVR after a DIV with decimals: dividend less quotient times divisor
     C     Dvd           DIV       Dvr           Quo
     C                   MVR                     Remd
      * Not converted: the DIV overwrote its dividend; half adjust
     C     Dvd           DIV       Dvr           Dvd
     C                   MVR                     Remd
     C     Dvd           DIV(H)    Dvr           Quo0
     C                   MVR                     Remd
      * MOVE(P) of character fields: the result is blanked first (FREE-34)
     C                   MOVE(P)   Narrow        Wide
     C                   MOVE(P)   Wide          Narrow
     C                   MOVE(P)   Same          Wide
     C                   MOVE(P)   'AB'          Wide
     C                   MOVEL(P)  Narrow        Wide
