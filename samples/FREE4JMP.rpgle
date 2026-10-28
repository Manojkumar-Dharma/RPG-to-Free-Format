      * RPG IV GOTO, CABxx and TAG (FREE-44, RV-14)
     DCnt              S              5  0
     DNum              S              5  0
      * 1. skip forward (indicator 01)
     C   01              GOTO      SKIP1
     C     1             ADD       Cnt           Cnt
     C     2             ADD       Cnt           Cnt
     C     SKIP1         TAG
      * 2. CABxx forward
     C     Cnt           CABGT     99            SKIP2
     C     3             ADD       Cnt           Cnt
     C     SKIP2         TAG
      * 3. loop back
     C     AGAIN         TAG
     C     1             ADD       Cnt           Cnt
     C     Cnt           CABLT     10            AGAIN
      * 4. subroutine: jump to its last TAG
     C                   EXSR      CHECK
     C     CHECK         BEGSR
     C   02              GOTO      DONE
     C     5             ADD       Cnt           Cnt
     C     DONE          TAG
     C                   ENDSR
      * 5. not converted: two jumps back to one TAG
     C     TWICE         TAG
     C   03              GOTO      TWICE
     C   04              GOTO      TWICE
