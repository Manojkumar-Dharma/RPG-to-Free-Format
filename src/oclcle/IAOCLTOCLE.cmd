/* IAOCLTOCLE - convert an OCL36 procedure to CLLE source.            */
/* CPP: IAOCLTOCLE. Parameter order here must match the program's.   */
/* Source: SRCLIB + SRCFILE (member) or SRCIFS (directory); the IFS   */
/* file name is SRCMBR.SRCTYPE. Target: same rule with TGT*.          */
/* TGTFILE has no default on purpose: for an IFS target it stays      */
/* empty.                                                             */
CMD        PROMPT('OCL36 to CLLE converter')

PARM       KWD(SRCLIB) TYPE(*NAME) LEN(10) DFT(*NONE) +
             SPCVAL((*NONE ' ') (*LIBL) (*CURLIB)) +
             PROMPT('Source library')
PARM       KWD(SRCFILE) TYPE(*NAME) LEN(10) DFT(*NONE) +
             SPCVAL((*NONE ' ')) PROMPT('Source file')
PARM       KWD(SRCMBR) TYPE(*NAME) LEN(10) MIN(1) +
             PROMPT('Source member')
PARM       KWD(SRCTYPE) TYPE(*CHAR) LEN(10) MIN(1) +
             PROMPT('Source type')
PARM       KWD(SRCIFS) TYPE(*CHAR) LEN(1024) VARY(*YES) +
             DFT(*NONE) SPCVAL((*NONE ' ')) +
             PROMPT('Source IFS directory')

PARM       KWD(TGTLIB) TYPE(*NAME) LEN(10) DFT(*NONE) +
             SPCVAL((*NONE ' ') (*SRCLIB)) PROMPT('Target library')
PARM       KWD(TGTFILE) TYPE(*NAME) LEN(10) DFT(*NONE) +
             SPCVAL((*NONE ' ')) PROMPT('Target file')
PARM       KWD(TGTMBR) TYPE(*NAME) LEN(10) MIN(1) +
             SPCVAL((*SRCMBR)) PROMPT('Target member')
PARM       KWD(TGTTYPE) TYPE(*CHAR) LEN(10) DFT(CLLE) +
             PROMPT('Target type')
PARM       KWD(TGTIFS) TYPE(*CHAR) LEN(1024) VARY(*YES) +
             DFT(*NONE) SPCVAL((*NONE ' ')) +
             PROMPT('Target IFS directory')

PARM       KWD(SRCCCSID) TYPE(*INT4) DFT(*DFT) +
             SPCVAL((*DFT -1)) PROMPT('Source CCSID')
PARM       KWD(TGTCCSID) TYPE(*INT4) DFT(*DFT) +
             SPCVAL((*DFT -1)) PROMPT('Target CCSID')
PARM       KWD(REPLACE) TYPE(*CHAR) LEN(4) RSTD(*YES) DFT(*NO) +
             VALUES(*NO *YES) PROMPT('Replace existing target')
