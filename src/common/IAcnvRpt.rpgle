**FREE
// IAcnvRpt - conversion report written to a plain spooled file
// (printer file IACNVRPT). Module of service program IAcnvSrv.
// One report is open at a time. Every item has a status:
//   C converted, A converted with assumption, R needs manual review.

ctl-opt nomain option(*srcstmt:*nodebugio);

/copy IAcnvSrvP

dcl-f IACNVRPT printer usage(*output) usropn;

dcl-s g_open ind inz(*off);
dcl-s g_conv int(10) inz(0);
dcl-s g_assump int(10) inz(0);
dcl-s g_review int(10) inz(0);

// ------------------------------------------------------------------
dcl-proc PutLine;
  dcl-pi *n;
    i_text varchar(132) const;
    i_first ind const;
  end-pi;

  TXT = i_text;
  if i_first;
    write RPTTOP;
  else;
    write RPTLINE;
  endif;
end-proc;

// ------------------------------------------------------------------
dcl-proc Describe;
  dcl-pi *n varchar(120);
    i_desc likeds(IAcnvDesc_t) const;
  end-pi;

  if i_desc.mode = C_MODE_MBR;
    return %trim(i_desc.lib) + '/' + %trim(i_desc.file)
           + '(' + %trim(i_desc.mbr) + ')  type ' + %trim(i_desc.type);
  endif;
  return %trim(i_desc.path) + '  type ' + %trim(i_desc.type);
end-proc;

// ------------------------------------------------------------------
dcl-proc ConverterName;
  dcl-pi *n varchar(30);
    i_converter int(10) const;
  end-pi;

  select;
    when i_converter = C_CNV_OCL;
      return 'IAOCLTOCLE  (OCL36 to CLLE)';
    when i_converter = C_CNV_DSPF;
      return 'IACNVDSPF  (DSP36/38 to DSPF)';
    when i_converter = C_CNV_FREE;
      return 'IACNVFREE  (RPG to free format)';
  endsl;
  return 'converter';
end-proc;

// ------------------------------------------------------------------
dcl-proc RptOpen export;
  dcl-pi *n int(10);
    i_converter int(10) const;
    i_src likeds(IAcnvDesc_t) const;
    i_tgt likeds(IAcnvDesc_t) const;
  end-pi;

  if g_open;
    RptClose();
  endif;

  monitor;
    open IACNVRPT;
  on-error;
    return 1;
  endmon;

  g_open = *on;
  g_conv = 0;
  g_assump = 0;
  g_review = 0;

  PutLine('Legacy source conversion report   ' + ConverterName(i_converter)
          + '   ' + %char(%date()) + ' ' + %char(%time()):*on);
  PutLine(' ':*off);
  PutLine('Source: ' + Describe(i_src):*off);
  PutLine('Target: ' + Describe(i_tgt):*off);
  PutLine(' ':*off);
  PutLine('Status     Line   Source text                                         '
          + 'Reason':*off);
  PutLine('---------- ------ -------------------------------------------------- '
          + '--------------------------------------------------------------':*off);
  return 0;
end-proc;

// ------------------------------------------------------------------
dcl-proc RptItem export;
  dcl-pi *n;
    i_status char(1) const;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_reason varchar(200) const;
  end-pi;

  dcl-s l_status char(10);
  dcl-s l_line varchar(132);
  dcl-s l_num char(6);
  dcl-s l_text char(50);
  dcl-s l_reason char(62);

  if not g_open;
    return;
  endif;

  select;
    when i_status = C_STS_CONVERTED;
      l_status = 'CONVERTED';
      g_conv += 1;
    when i_status = C_STS_ASSUMPTION;
      l_status = 'ASSUMPTION';
      g_assump += 1;
    other;
      l_status = 'REVIEW';
      g_review += 1;
  endsl;

  // The report lists only items that need attention plus counts of the
  // rest, so a clean conversion stays short.
  if i_status = C_STS_CONVERTED;
    return;
  endif;

  evalr l_num = %char(i_lineNo);
  l_text = i_text;
  l_reason = i_reason;
  l_line = l_status + ' ' + l_num + ' ' + l_text + ' ' + l_reason;
  PutLine(l_line:*off);
end-proc;

// ------------------------------------------------------------------
dcl-proc RptClose export;
  dcl-pi *n;
    o_conv int(10) options(*nopass);
    o_assump int(10) options(*nopass);
    o_review int(10) options(*nopass);
  end-pi;

  if not g_open;
    return;
  endif;

  PutLine(' ':*off);
  PutLine('Totals:  converted ' + %char(g_conv)
          + '   with assumption ' + %char(g_assump)
          + '   for review ' + %char(g_review):*off);
  close IACNVRPT;
  g_open = *off;

  if %parms >= 1;
    o_conv = g_conv;
  endif;
  if %parms >= 2;
    o_assump = g_assump;
  endif;
  if %parms >= 3;
    o_review = g_review;
  endif;
end-proc;
