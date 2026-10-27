/* IACNVFREE - convert RPG36, RPG38 or RPG source to fully free-form RPGLE. */
/* CPP: IACNVFREE. Parameter order here must match the program's.         */
/* SRC(lib/file member) and TGT(lib/file member) are grouped values:   */
/*   IACNVFREE SRC(MYLIB/QS36SRC MYPGM) SRCTYPE(RPG36) TGT(QRPGLESRC)     */
/* Target file *SRCFILE and library *SRCLIB mean the source file and   */
/* library. For an IFS source or target give *NONE as the file and    */
/* use SRCIFS or TGTIFS (a directory; TGTIFS(*SRC) = the source's);   */
/* the IFS name is member.type.                                        */
/* DDSTGT writes the printer file DDS made from the O specifications   */
/* to its own member (default *NONE: the DDS stays as comments at the  */
/* end of the converted source). *TGTFILE and *TGTLIB mean the target  */
/* file and library, *PRTF the name of the printer file; DDSIFS(*TGT)  */
/* is the target IFS directory.                                        */
CMD        PROMPT('RPG to free-format converter')

PARM       KWD(SRC) TYPE(SRC_T) MIN(1) PROMPT('Source file and member')
SRC_T:     ELEM       TYPE(SRCFILE_Q) MIN(1) PROMPT('Source file')
           ELEM       TYPE(*NAME) LEN(10) MIN(1) PROMPT('Source member')
SRCFILE_Q: QUAL       TYPE(*NAME) LEN(10) MIN(1) SPCVAL((*NONE ' '))
           QUAL       TYPE(*NAME) LEN(10) DFT(*LIBL) +
                        SPCVAL((*LIBL) (*CURLIB)) PROMPT('Library')
PARM       KWD(SRCTYPE) TYPE(*CHAR) LEN(10) MIN(1) +
             PROMPT('Source type')
PARM       KWD(SRCIFS) TYPE(*CHAR) LEN(1024) VARY(*YES) +
             DFT(*NONE) SPCVAL((*NONE ' ')) +
             PROMPT('Source IFS directory')

PARM       KWD(TGT) TYPE(TGT_T) PROMPT('Target file and member')
TGT_T:     ELEM       TYPE(TGTFILE_Q) PROMPT('Target file')
           ELEM       TYPE(*NAME) LEN(10) DFT(*SRCMBR) +
                        SPCVAL((*SRCMBR)) PROMPT('Target member')
TGTFILE_Q: QUAL       TYPE(*NAME) LEN(10) DFT(*SRCFILE) +
                        SPCVAL((*SRCFILE) (*NONE ' '))
           QUAL       TYPE(*NAME) LEN(10) DFT(*SRCLIB) +
                        SPCVAL((*SRCLIB)) PROMPT('Library')
PARM       KWD(TGTTYPE) TYPE(*CHAR) LEN(10) DFT(RPGLE) +
             PROMPT('Target type')
PARM       KWD(TGTIFS) TYPE(*CHAR) LEN(1024) VARY(*YES) +
             DFT(*NONE) SPCVAL((*NONE ' ') (*SRC)) +
             PROMPT('Target IFS directory')

PARM       KWD(SRCCCSID) TYPE(*INT4) DFT(*DFT) +
             SPCVAL((*DFT -1)) PROMPT('Source CCSID')
PARM       KWD(TGTCCSID) TYPE(*INT4) DFT(*DFT) +
             SPCVAL((*DFT -1)) PROMPT('Target CCSID')
PARM       KWD(REPLACE) TYPE(*CHAR) LEN(4) RSTD(*YES) DFT(*NO) +
             VALUES(*NO *YES) PROMPT('Replace existing target')

PARM       KWD(DDSTGT) TYPE(DDSTGT_T) PROMPT('Printer DDS file and member')
DDSTGT_T:  ELEM       TYPE(DDSFILE_Q) PROMPT('DDS source file')
           ELEM       TYPE(*NAME) LEN(10) DFT(*PRTF) +
                        SPCVAL((*PRTF)) PROMPT('DDS member')
DDSFILE_Q: QUAL       TYPE(*NAME) LEN(10) DFT(*NONE) +
                        SPCVAL((*NONE ' ') (*TGTFILE))
           QUAL       TYPE(*NAME) LEN(10) DFT(*TGTLIB) +
                        SPCVAL((*TGTLIB)) PROMPT('Library')
PARM       KWD(DDSTYPE) TYPE(*CHAR) LEN(10) DFT(PRTF) +
             PROMPT('DDS member type')
PARM       KWD(DDSIFS) TYPE(*CHAR) LEN(1024) VARY(*YES) +
             DFT(*NONE) SPCVAL((*NONE ' ') (*TGT)) +
             PROMPT('DDS IFS directory')
