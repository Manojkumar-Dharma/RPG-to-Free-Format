**FREE
// IAcnvRpt - conversion report written to a plain spooled file
// (printer file IACNVRPT). Module of service program IAcnvSrv.
// One report is open at a time. Every item has a status:
//   C converted, A converted with assumption, R needs manual review.

ctl-opt nomain option(*srcstmt:*nodebugio);

/copy qcpysrc,IAcnvSrvP

dcl-f IACNVRPT printer usage(*output) usropn oflind(g_pageFull);

dcl-s g_open ind inz(*off);
dcl-s g_pageFull ind inz(*off);      // overflow indicator of IACNVRPT
dcl-s g_conv int(10) inz(0);
dcl-s g_assump int(10) inz(0);
dcl-s g_review int(10) inz(0);

// The reasons of the items with an assumption (A), counted by cause. A reason can
// hold several causes joined by ' | ' (AddReason, AppendText): each is counted on
// its own, by its exact text, so a cause must have one fixed text (no names or
// numbers in it). Only for IACNVFREE: the reasons of the other converters still hold
// names and would fill the table with single causes.
dcl-s g_countCauses ind inz(*off);
dcl-c C_MAXCAUSE 60;
dcl-c C_CAUSEWIDTH 118;
dcl-s g_causeText varchar(200) dim(C_MAXCAUSE);
dcl-s g_causeCount int(10) dim(C_MAXCAUSE);
dcl-s g_causeUsed int(10) inz(0);
dcl-s g_causeOther int(10) inz(0);     // causes after the table was full

// ------------------------------------------------------------------
dcl-proc AddCause;
  dcl-pi *n;
    i_text varchar(200) const;
  end-pi;

  dcl-s l_index int(10);

  if i_text = '';
    return;
  endif;
  for l_index = 1 to g_causeUsed;
    if g_causeText(l_index) = i_text;
      g_causeCount(l_index) += 1;
      return;
    endif;
  endfor;
  if g_causeUsed >= C_MAXCAUSE;
    g_causeOther += 1;
    return;
  endif;
  g_causeUsed += 1;
  g_causeText(g_causeUsed) = i_text;
  g_causeCount(g_causeUsed) = 1;
end-proc;

// ------------------------------------------------------------------
// Splits a reason at ' | ' and counts each cause.
dcl-proc CountCauses;
  dcl-pi *n;
    i_reason varchar(200) const;
  end-pi;

  dcl-s l_rest varchar(200);
  dcl-s l_p int(10);

  l_rest = i_reason;
  dow l_rest <> '';
    l_p = %scan(' | ':l_rest);
    if l_p = 0;
      AddCause(%trim(l_rest));
      l_rest = '';
    else;
      AddCause(%trim(%subst(l_rest:1:l_p - 1)));
      if l_p + 3 > %len(l_rest);
        l_rest = '';
      else;
        l_rest = %subst(l_rest:l_p + 3);
      endif;
    endif;
  enddo;
end-proc;

// ------------------------------------------------------------------
// The causes of the assumptions with their counts, the most frequent first.
dcl-proc PrintCauses;
  dcl-pi *n;
  end-pi;

  dcl-s l_i int(10);
  dcl-s l_j int(10);
  dcl-s l_text varchar(200);
  dcl-s l_count int(10);
  dcl-s l_rest varchar(200);
  dcl-s l_first ind;
  dcl-s l_num char(6);

  if g_causeUsed = 0 and g_causeOther = 0;
    return;
  endif;
  // Sort by count, descending; equal counts keep the order of first appearance.
  for l_i = 1 to g_causeUsed - 1;
    for l_j = 1 to g_causeUsed - l_i;
      if g_causeCount(l_j) < g_causeCount(l_j + 1);
        l_text = g_causeText(l_j);
        l_count = g_causeCount(l_j);
        g_causeText(l_j) = g_causeText(l_j + 1);
        g_causeCount(l_j) = g_causeCount(l_j + 1);
        g_causeText(l_j + 1) = l_text;
        g_causeCount(l_j + 1) = l_count;
      endif;
    endfor;
  endfor;

  PutLine(' ':*off);
  PutLine('Assumptions by cause:':*off);
  for l_i = 1 to g_causeUsed;
    evalr l_num = %char(g_causeCount(l_i));
    l_rest = g_causeText(l_i);
    l_first = *on;
    dow l_rest <> '';
      if l_first;
        PutLine(l_num + '  ' + %subst(l_rest:1:%min(%len(l_rest):C_CAUSEWIDTH))
                :*off);
      else;
        PutLine('        ' + %subst(l_rest:1:%min(%len(l_rest):C_CAUSEWIDTH))
                :*off);
      endif;
      l_first = *off;
      if %len(l_rest) > C_CAUSEWIDTH;
        l_rest = %subst(l_rest:C_CAUSEWIDTH + 1);
      else;
        l_rest = '';
      endif;
    enddo;
  endfor;
  if g_causeOther > 0;
    evalr l_num = %char(g_causeOther);
    PutLine(l_num + '  other causes (more than ' + %char(C_MAXCAUSE)
            + ' different ones)':*off);
  endif;
end-proc;

// ------------------------------------------------------------------
dcl-proc PutLine;
  dcl-pi *n;
    i_text varchar(132) const;
    i_first ind const;
  end-pi;

  dcl-s l_clean varchar(132);
  dcl-s l_index int(10);
  dcl-s l_char char(1);

  // Source text can hold control characters (below x'40'); the printer file
  // does not accept them, so they are printed as blanks.
  l_clean = i_text;
  for l_index = 1 to %len(l_clean);
    l_char = %subst(l_clean:l_index:1);
    if l_char < x'40';
      %subst(l_clean:l_index:1) = ' ';
    endif;
  endfor;
  TXT = l_clean;
  // When the overflow line was reached on the last write, CPF5004 would be
  // sent on the next one. Start a new page instead and reset the indicator.
  if i_first or g_pageFull;
    write RPTTOP;
    g_pageFull = *off;
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
      return 'IACNVDSPF  (DSPF36/38 to DSPF)';
    when i_converter = C_CNV_FREE;
      return 'IACNVFREE  (RPG to free format)';
  endsl;
  return 'converter';
end-proc;

// ------------------------------------------------------------------
dcl-proc RptOpen export;
  dcl-pi *n int(10);
    i_converter int(10) const;
    i_source likeds(IAcnvDesc_t) const;
    i_target likeds(IAcnvDesc_t) const;
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
  g_pageFull = *off;
  g_conv = 0;
  g_assump = 0;
  g_review = 0;
  g_causeUsed = 0;
  g_causeOther = 0;
  g_countCauses = (i_converter = C_CNV_FREE or i_converter = C_CNV_FREEDDS);

  PutLine('Legacy source conversion report   ' + ConverterName(i_converter)
          + '   ' + %char(%date()) + ' ' + %char(%time()):*on);
  PutLine(' ':*off);
  PutLine('Source: ' + Describe(i_source):*off);
  PutLine('Target: ' + Describe(i_target):*off);
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
  dcl-s l_lineText char(6);
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
      if g_countCauses;
        CountCauses(i_reason);
      endif;
    other;
      l_status = 'REVIEW';
      g_review += 1;
  endsl;

  // The report lists only items that need attention plus counts of the
  // rest, so a clean conversion stays short.
  if i_status = C_STS_CONVERTED;
    return;
  endif;

  evalr l_lineText = %char(i_lineNo);
  l_text = i_text;
  l_reason = i_reason;
  l_line = l_status + ' ' + l_lineText + ' ' + l_text + ' ' + l_reason;
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

  PrintCauses();
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
