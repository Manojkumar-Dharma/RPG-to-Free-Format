      * RPG IV: embedded SQL inside groups is indented with the group (RV-59)
     DCount            S        5      I
     DKey              S        6       0
     C                   IF        Key > 0
     C/EXEC SQL
     C+  UPDATE CUSTMAS SET STATUS = 'A'
     C+    WHERE CUSTNO = :KEY
     C/END-EXEC
     C                   IF        Count > 1
     C/EXEC SQL DELETE FROM WORKFILE
     C/END-EXEC
     C                   ENDIF
     C                   ELSE
     C/EXEC SQL
     C+  SELECT COUNT(*) INTO :COUNT FROM CUSTMAS
     C/END-EXEC
     C                   ENDIF
