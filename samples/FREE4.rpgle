     HDFTACTGRP(*NO) OPTION(*SRCSTMT)
     FCUSTOMER  IF   E             DISK    USROPN
     FORDERS    UF A E           K DISK
     FREPORT    O    F132          PRINTER
     DMAXROWS          C                   CONST(100)
     DCount            S        5      I
     DTotal            S        9       2  INZ(0)
     DName             S        30     A   VARYING
     DToday            S               D   DATFMT(*ISO)
     DAddr             DS                  QUALIFIED
     DStreet                    30     A
     DCity                      20     A
     DZip                1      5      S0  OVERLAY(Addr)
     DPgm             SDS
     DPgmName            1      10
     DAddTax           PR       9      P2  EXTPROC('ADDTAX')
     DAmount                    9      P2  CONST
     DRate                      5      P3  VALUE
     DData             DS                  EXTNAME(CUSTOMER) INZ
     PAddTax           B                   EXPORT
     DAddTax           PI       9      P2
     DAmount                    9      P2  CONST
     C                   EVAL      Count = Count + 1
     PAddTax           E
     /COPY QCPYSRC,CUSTP
