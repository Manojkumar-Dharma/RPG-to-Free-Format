**FREE
// IAcnvDspf - entry program (CPP) of command IACNVDSPF.
// Converts DSP36 (S/36 display format source) or DSP38 (S/38 DDS) to
// DDS source for a display file.
// Validates the common parameters, opens the spooled report, runs the
// conversion (module IAdspCvt) and sends a completion message.
// Bind with service program IAcnvSrv.

ctl-opt main(Main) option(*srcstmt:*nodebugio);

/copy qcpysrc,IAcnvSrvP

dcl-pr DspConvert int(10);
  i_src likeds(IAcnvDesc_t) const;
  i_tgt likeds(IAcnvDesc_t) const;
  o_msgId char(7);
  o_msgData char(256);
end-pr;

dcl-proc Main;
  dcl-pi *n;
    i_src likeds(IAcnvFileMbr_t) const;
    i_srcType char(10) const;
    i_srcIfs varchar(1024) const;
    i_tgt likeds(IAcnvFileMbr_t) const;
    i_tgtType char(10) const;
    i_tgtIfs varchar(1024) const;
    i_srcCcsid int(10) const;
    i_tgtCcsid int(10) const;
    i_replace char(4) const;
  end-pi;

  dcl-ds l_parm likeds(IAcnvParm_t);
  dcl-ds l_src likeds(IAcnvDesc_t);
  dcl-ds l_tgt likeds(IAcnvDesc_t);
  dcl-s l_msgId char(7);
  dcl-s l_msgData char(256);
  dcl-s l_conv int(10);
  dcl-s l_assump int(10);
  dcl-s l_review int(10);
  dcl-s l_rc int(10);
  dcl-s l_counts char(256);

  // An IFS source or target has no file: the library is not used then.
  l_parm.srcFile = i_src.file;
  l_parm.srcLib = i_src.lib;
  if i_src.file = *blanks or i_src.file = '*NONE';
    l_parm.srcFile = *blanks;
    l_parm.srcLib = *blanks;
  endif;
  l_parm.srcMbr = i_src.mbr;
  l_parm.srcIfs = i_srcIfs;
  l_parm.srcType = i_srcType;
  l_parm.srcCcsid = i_srcCcsid;
  l_parm.tgtFile = i_tgt.file;
  l_parm.tgtLib = i_tgt.lib;
  // No target file (or the default *SRCFILE together with TGTIFS) means an
  // IFS target.
  if i_tgt.file = *blanks or i_tgt.file = '*NONE'
     or (i_tgt.file = '*SRCFILE' and %len(%trim(i_tgtIfs)) > 0);
    l_parm.tgtFile = *blanks;
    l_parm.tgtLib = *blanks;
  endif;
  l_parm.tgtMbr = i_tgt.mbr;
  l_parm.tgtIfs = i_tgtIfs;
  l_parm.tgtType = i_tgtType;
  l_parm.tgtCcsid = i_tgtCcsid;
  l_parm.replace = i_replace;

  if ValidateIO(C_CNV_DSPF:l_parm:l_src:l_tgt:l_msgId:l_msgData) <> 0;
    SendEscape(l_msgId:l_msgData);
    return;
  endif;

  if RptOpen(C_CNV_DSPF:l_src:l_tgt) <> 0;
    SendEscape('IAC0102':'Cannot open the report file IACNVRPT');
    return;
  endif;

  l_rc = DspConvert(l_src:l_tgt:l_msgId:l_msgData);
  RptClose(l_conv:l_assump:l_review);

  if l_rc <> 0;
    SendEscape(l_msgId:l_msgData);
    return;
  endif;

  // IAC0100 carries three 10-byte counts.
  l_counts = *blanks;
  %subst(l_counts:1:10) = %char(l_conv);
  %subst(l_counts:11:10) = %char(l_assump);
  %subst(l_counts:21:10) = %char(l_review);
  SendCompletion('IAC0100':l_counts);
end-proc;
