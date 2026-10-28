      * RPG IV: WHENEVER ... GOTO becomes tests of SQLCODE (RV-37)
     DCnt              S              5  0
     DKey              S              5  0
     C     1             ADD       Key           Key
      * 1. NOT FOUND to a TAG with more lines after it: IF around the lines
     C/EXEC SQL WHENEVER NOT FOUND GOTO NOROW
     C/END-EXEC
     C/EXEC SQL
     C+  SELECT COUNT(*) INTO :CNT FROM CUSTMAS WHERE CUSTNO = :KEY
     C/END-EXEC
     C     2             ADD       Key           Key
     C     NOROW         TAG
      * 2. CONTINUE: no test of NOT FOUND for the statements after it
     C/EXEC SQL WHENEVER NOT FOUND CONTINUE
     C/END-EXEC
     C/EXEC SQL
     C+  DELETE FROM WORKFILE
     C/END-EXEC
      * 3. Not converted: the label is before the statement (a jump back)
     C     AGAIN         TAG
     C/EXEC SQL WHENEVER SQLWARNING GOTO AGAIN
     C/END-EXEC
     C/EXEC SQL
     C+  INSERT INTO LOGFILE VALUES(:KEY)
     C/END-EXEC
     C/EXEC SQL WHENEVER SQLWARNING CONTINUE
     C/END-EXEC
      * 4. SQLERROR to the last TAG of the program, inside a group
     C     Key           IFGT      0
     C/EXEC SQL WHENEVER SQLERROR GOTO FIN
     C/END-EXEC
     C/EXEC SQL
     C+  UPDATE CUSTMAS SET STATUS = 'A' WHERE CUSTNO = :KEY
     C/END-EXEC
     C                   ENDIF
     C/EXEC SQL
     C+  DELETE FROM OLDFILE
     C/END-EXEC
     C     FIN           TAG
      * 5. Not understood: kept as written and reported
     C/EXEC SQL WHENEVER SQLERROR STOP
     C/END-EXEC
