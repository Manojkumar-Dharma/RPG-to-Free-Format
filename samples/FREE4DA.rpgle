      * RPG IV data areas: *DTAARA DEFINE, IN, OUT (FREE-33)
     DTotal            S              9P2
     DCnt              S              5S0
     DMyDs             DS
     D DsFld                        10A
     DOwn              S              8A
     DPlain            S              4A
      * *DTAARA DEFINE: the DTAARA keyword of the definition
     C     *DTAARA       DEFINE    TOTDA         Total
     C     *DTAARA       DEFINE    *LDA          MyDs
     C     *DTAARA       DEFINE                  Own
      * IN and OUT, *LOCK, the extender, *DTAARA
     C     *LOCK         IN        Total
     C                   OUT       Total
     C                   IN(E)     MyDs
     C                   IN        *DTAARA
     C                   OUT       *DTAARA
     C     *LOCK         OUT       Total
      * Not converted: a DEFINE with a length, an undeclared field, a result field
     C     *DTAARA       DEFINE    CNTDA         Cnt               5
     C     *DTAARA       DEFINE    GHOSTD        Ghost
     C                   IN        Total         Plain
