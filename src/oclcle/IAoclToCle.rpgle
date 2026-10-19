**FREE
// IAoclToCle - entry program (CPP) of command IAOCLTOCLE.
// Converts an OCL36 procedure to CLLE source.
// Validates the common parameters, opens the spooled report, runs the
// conversion (module IAoclCvt) and sends a completion message.
// Bind with service program IAcnvSrv.

ctl-opt dftactgrp(*no) actgrp(*new) main(Main) option(*srcstmt:*nodebugio);

/copy IAcnvSrvP

dcl-pr OclConvert int(10);
  i_src likeds(IAcnvDesc_t) const;
  i_tgt likeds(IAcnvDesc_t) const;
  o_msgId char(7);
  o_msgData char(256);
end-pr;

dcl-proc Main;
  dcl-pi *n;
    i_srcLib char(10) const;
    i_srcFile char(10) const;
    i_srcMbr char(10) const;
    i_srcType char(10) const;
    i_srcIfs varchar(1024) const;
    i_tgtLib char(10) const;
    i_tgtFile char(10) const;
    i_tgtMbr char(10) const;
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

  l_parm.srcLib = i_srcLib;
  l_parm.srcFile = i_srcFile;
  l_parm.srcIfs = i_srcIfs;
  l_parm.srcMbr = i_srcMbr;
  l_parm.srcType = i_srcType;
  l_parm.srcCcsid = i_srcCcsid;
  l_parm.tgtLib = i_tgtLib;
  l_parm.tgtFile = i_tgtFile;
  l_parm.tgtIfs = i_tgtIfs;
  l_parm.tgtMbr = i_tgtMbr;
  l_parm.tgtType = i_tgtType;
  l_parm.tgtCcsid = i_tgtCcsid;
  l_parm.replace = i_replace;

  if ValidateIO(C_CNV_OCL:l_parm:l_src:l_tgt:l_msgId:l_msgData) <> 0;
    SendEscape(l_msgId:l_msgData);
    return;
  endif;

  if RptOpen(C_CNV_OCL:l_src:l_tgt) <> 0;
    SendEscape('IAC0102':'Cannot open the report file IACNVRPT');
    return;
  endif;

  l_rc = OclConvert(l_src:l_tgt:l_msgId:l_msgData);
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
