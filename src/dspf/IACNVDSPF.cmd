/* IACNVDSPF - convert DSPF36 or DSPF38 source to DDS source (DSPF). */
/* CPP: IACNVDSPF. Parameter order here must match the program's.         */
/* SRC(lib/file member) and TGT(lib/file member) are grouped values:   */
/*   IACNVDSPF SRC(MYLIB/QS36PRC MYPROC) SRCTYPE(OCL36) TGT(QCLLESRC)    */
/* Target file *SRCFILE and library *SRCLIB mean the source file and   */
/* library. For an IFS source or target give *NONE as the file and    */
/* use SRCIFS or TGTIFS (a directory; TGTIFS(*SRC) = the source's);   */
/* the IFS name is member.type.                                        */
CMD        PROMPT('DSPF36/38 to DSPF converter')

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
PARM       KWD(TGTTYPE) TYPE(*CHAR) LEN(10) DFT(DSPF) +
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
PARM       KWD(MSGF) TYPE(MSGF_Q) DFT(*NONE) +
             PROMPT('Message file for message fields')
MSGF_Q:    QUAL       TYPE(*NAME) LEN(10) DFT(*NONE) SPCVAL((*NONE ' '))
           QUAL       TYPE(*NAME) LEN(10) DFT(*LIBL) +
                        SPCVAL((*LIBL) (*CURLIB)) PROMPT('Library')
