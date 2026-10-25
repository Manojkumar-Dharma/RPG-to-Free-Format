**FREE
// IAcnvFree - entry program (CPP) of command IACNVFREE.
// Converts RPG36 (RPG II), RPG38 and RPG (RPG III) source to fully free-form
// RPGLE.
// Validates the common parameters, opens the spooled report, runs the
// conversion (module IAfreeCvt) and sends a completion message.
// Bind with service program IAcnvSrv.

ctl-opt main(Main) option(*srcstmt:*nodebugio);

/copy qcpysrc,IAcnvSrvP

dcl-pr FreeConvert int(10);
  i_src likeds(IAcnvDesc_t) const;
  i_tgt likeds(IAcnvDesc_t) const;
  o_msgId char(7);
  o_msgData char(256);
end-pr;

dcl-proc Main;
  dcl-pi *n;
    i_sourceFileMember likeds(IAcnvFileMbr_t) const;
    i_srcType char(10) const;
    i_srcIfs varchar(1024) const;
    i_targetFileMember likeds(IAcnvFileMbr_t) const;
    i_tgtType char(10) const;
    i_tgtIfs varchar(1024) const;
    i_srcCcsid int(10) const;
    i_tgtCcsid int(10) const;
    i_replace char(4) const;
  end-pi;

  dcl-ds l_parm likeds(IAcnvParm_t);
  dcl-ds l_sourceDesc likeds(IAcnvDesc_t);
  dcl-ds l_targetDesc likeds(IAcnvDesc_t);
  dcl-s l_msgId char(7);
  dcl-s l_msgData char(256);
  dcl-s l_conv int(10);
  dcl-s l_assump int(10);
  dcl-s l_review int(10);
  dcl-s l_returnCode int(10);
  dcl-s l_counts char(256);

  // An IFS source or target has no file: the library is not used then.
  l_parm.srcFile = i_sourceFileMember.file;
  l_parm.srcLib = i_sourceFileMember.lib;
  if i_sourceFileMember.file = *blanks or i_sourceFileMember.file = '*NONE';
    l_parm.srcFile = *blanks;
    l_parm.srcLib = *blanks;
  endif;
  l_parm.srcMbr = i_sourceFileMember.mbr;
  l_parm.srcIfs = i_srcIfs;
  l_parm.srcType = i_srcType;
  l_parm.srcCcsid = i_srcCcsid;
  l_parm.tgtFile = i_targetFileMember.file;
  l_parm.tgtLib = i_targetFileMember.lib;
  // No target file (or the default *SRCFILE together with TGTIFS) means an
  // IFS target.
  if i_targetFileMember.file = *blanks or i_targetFileMember.file = '*NONE'
     or (i_targetFileMember.file = '*SRCFILE' and %len(%trim(i_tgtIfs)) > 0);
    l_parm.tgtFile = *blanks;
    l_parm.tgtLib = *blanks;
  endif;
  l_parm.tgtMbr = i_targetFileMember.mbr;
  l_parm.tgtIfs = i_tgtIfs;
  l_parm.tgtType = i_tgtType;
  l_parm.tgtCcsid = i_tgtCcsid;
  l_parm.replace = i_replace;

  if ValidateIO(C_CNV_FREE:l_parm:l_sourceDesc:l_targetDesc:l_msgId:l_msgData) <> 0;
    SendEscape(l_msgId:l_msgData);
    return;
  endif;

  if RptOpen(C_CNV_FREE:l_sourceDesc:l_targetDesc) <> 0;
    SendEscape('IAC0102':'Cannot open the report file IACNVRPT');
    return;
  endif;

  l_returnCode = FreeConvert(l_sourceDesc:l_targetDesc:l_msgId:l_msgData);
  RptClose(l_conv:l_assump:l_review);

  if l_returnCode <> 0;
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
