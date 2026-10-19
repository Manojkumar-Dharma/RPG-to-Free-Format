**FREE
// IAcnvIO - one reader and one writer for converters, whatever the
// location mode. Dispatches to IAcnvMbr (source member) or IAcnvIfs
// (stream file) and wraps long lines at a safe point before writing.
// Module of service program IAcnvSrv.
//
// Wrap rules (design document section 4.1): never inside a quoted literal;
// prefer after a comma that is close to the limit, else after a blank.
// If no safe point exists before the limit, the first safe point after it is
// used and the line is reported as REVIEW. If there is none at all, the
// line is written as is (REVIEW); a member target then refuses it.

ctl-opt nomain option(*srcstmt:*nodebugio);

/copy IAcnvSrvP

dcl-c C_QUOTE '''';
dcl-c C_COMMAWINDOW 30;          // a comma this close to the last blank wins
dcl-c C_CONTINDENT 2;

dcl-s g_srcMode char(1) inz(' ');
dcl-s g_tgtMode char(1) inz(' ');
dcl-s g_width int(10) inz(0);

// ------------------------------------------------------------------
dcl-proc OpenSource export;
  dcl-pi *n int(10);
    i_desc likeds(IAcnvDesc_t) const;
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  g_srcMode = i_desc.mode;
  if i_desc.mode = C_MODE_MBR;
    return MbrOpenSource(i_desc:o_msgId:o_msgData);
  endif;
  return IfsOpenSource(i_desc:o_msgId:o_msgData);
end-proc;

// ------------------------------------------------------------------
dcl-proc ReadLine export;
  dcl-pi *n ind;
    o_text varchar(512);
    o_lineNo int(10);
  end-pi;

  if g_srcMode = C_MODE_MBR;
    return MbrReadLine(o_text:o_lineNo);
  endif;
  return IfsReadLine(o_text:o_lineNo);
end-proc;

// ------------------------------------------------------------------
// After ReadLine returned *OFF: *ON when that was an error, not the end.
dcl-proc ReadError export;
  dcl-pi *n ind;
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  o_msgId = *blanks;
  o_msgData = *blanks;
  if g_srcMode = C_MODE_IFS;
    return IfsLastError(o_msgId:o_msgData);
  endif;
  return *off;
end-proc;

// ------------------------------------------------------------------
dcl-proc CloseSource export;
  dcl-pi *n;
  end-pi;

  if g_srcMode = C_MODE_MBR;
    MbrCloseSource();
  elseif g_srcMode = C_MODE_IFS;
    IfsCloseSource();
  endif;
  g_srcMode = ' ';
end-proc;

// ------------------------------------------------------------------
dcl-proc OpenTarget export;
  dcl-pi *n int(10);
    i_desc likeds(IAcnvDesc_t) const;
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  dcl-s l_width int(10);
  dcl-s l_rc int(10);

  g_tgtMode = i_desc.mode;
  if i_desc.mode = C_MODE_MBR;
    l_rc = MbrOpenTarget(i_desc:l_width:o_msgId:o_msgData);
    g_width = l_width;
    return l_rc;
  endif;
  g_width = C_STMFWIDTH;
  return IfsOpenTarget(i_desc:o_msgId:o_msgData);
end-proc;

// ------------------------------------------------------------------
dcl-proc CloseTarget export;
  dcl-pi *n;
  end-pi;

  if g_tgtMode = C_MODE_MBR;
    MbrCloseTarget();
  elseif g_tgtMode = C_MODE_IFS;
    IfsCloseTarget();
  endif;
  g_tgtMode = ' ';
end-proc;

// ------------------------------------------------------------------
dcl-proc RawWrite;
  dcl-pi *n int(10);
    i_text varchar(512) const;
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  if g_tgtMode = C_MODE_MBR;
    return MbrWriteLine(i_text:o_msgId:o_msgData);
  endif;
  return IfsWriteLine(i_text:o_msgId:o_msgData);
end-proc;

// ------------------------------------------------------------------
// Last position (<= i_limit) after which the line can be cut: a comma or a
// blank outside quotes, past i_minPos (the indentation or the continuation
// prefix, so every wrap makes progress). 0 when there is none.
dcl-proc FindBreak;
  dcl-pi *n int(10);
    i_text varchar(512) const;
    i_limit int(10) const;
    i_minPos int(10) const;
  end-pi;

  dcl-s l_i int(10);
  dcl-s l_inQuote ind inz(*off);
  dcl-s l_blank int(10) inz(0);
  dcl-s l_comma int(10) inz(0);
  dcl-s l_ch char(1);

  for l_i = 1 to %min(i_limit:%len(i_text));
    l_ch = %subst(i_text:l_i:1);
    if l_ch = C_QUOTE;
      l_inQuote = not l_inQuote;
    elseif not l_inQuote and l_i > i_minPos;
      if l_ch = ' ';
        l_blank = l_i;
      elseif l_ch = ',';
        l_comma = l_i;
      endif;
    endif;
  endfor;

  if l_comma > 0 and l_comma >= l_blank - C_COMMAWINDOW;
    return l_comma;
  endif;
  return l_blank;
end-proc;

// ------------------------------------------------------------------
// First comma or blank outside quotes after position i_from, 0 if none.
dcl-proc FindBreakAfter;
  dcl-pi *n int(10);
    i_text varchar(512) const;
    i_from int(10) const;
  end-pi;

  dcl-s l_i int(10);
  dcl-s l_inQuote ind inz(*off);
  dcl-s l_ch char(1);

  for l_i = 1 to %len(i_text);
    l_ch = %subst(i_text:l_i:1);
    if l_ch = C_QUOTE;
      l_inQuote = not l_inQuote;
    elseif not l_inQuote and l_i > i_from and (l_ch = ' ' or l_ch = ',');
      return l_i;
    endif;
  endfor;
  return 0;
end-proc;

// ------------------------------------------------------------------
// Writes one logical line, wrapping it when it is wider than the target.
// i_style: C_WRAP_NONE, C_WRAP_CL ('+' continuation) or C_WRAP_FREE.
// o_status: C_STS_CONVERTED normally, C_STS_REVIEW when a safe break was
// not available. o_lines: physical lines written.
dcl-proc WriteText export;
  dcl-pi *n int(10);
    i_text varchar(512) const;
    i_style int(10) const;
    o_lines int(10);
    o_status char(1);
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  dcl-s l_rest varchar(512);
  dcl-s l_piece varchar(512);
  dcl-s l_limit int(10);
  dcl-s l_p int(10);
  dcl-s l_lead int(10);
  dcl-s l_prefix varchar(512);
  dcl-s l_isComment ind;
  dcl-s l_minPos int(10);

  o_lines = 0;
  o_status = C_STS_CONVERTED;
  l_rest = %trimr(i_text);

  l_lead = %len(l_rest) - %len(%triml(l_rest));
  l_isComment = %len(%triml(l_rest)) >= 2
                and %subst(%triml(l_rest):1:2) = '//';
  if l_isComment;
    l_prefix = %subst(l_rest:1:l_lead) + '// ';
  else;
    l_prefix = %subst(l_rest:1:l_lead) + %subst('   ':1:C_CONTINDENT);
  endif;

  l_minPos = l_lead + 1;
  l_limit = g_width;
  if i_style = C_WRAP_CL;
    l_limit = g_width - 1;       // room for the '+'
  endif;

  dow i_style <> C_WRAP_NONE and %len(l_rest) > g_width;
    l_p = FindBreak(l_rest:l_limit:l_minPos);
    if l_p = 0;
      o_status = C_STS_REVIEW;
      l_p = FindBreakAfter(l_rest:l_limit);
      if l_p = 0;
        leave;                   // no safe point at all: write as is
      endif;
    endif;

    l_piece = %subst(l_rest:1:l_p);
    if l_p >= %len(l_rest);
      leave;
    endif;
    l_rest = %triml(%subst(l_rest:l_p + 1));
    if l_rest = '';
      l_rest = l_piece;          // only blanks were left: nothing to wrap
      leave;
    endif;

    if i_style = C_WRAP_CL;
      l_piece = %trimr(l_piece) + ' +';
    else;
      l_piece = %trimr(l_piece);
    endif;
    if RawWrite(l_piece:o_msgId:o_msgData) <> 0;
      return 1;
    endif;
    o_lines += 1;
    l_rest = l_prefix + l_rest;
    l_minPos = %len(l_prefix) + 1;
  enddo;

  if %len(l_rest) > g_width and o_status = C_STS_CONVERTED;
    o_status = C_STS_REVIEW;
  endif;
  if RawWrite(l_rest:o_msgId:o_msgData) <> 0;
    return 1;
  endif;
  o_lines += 1;
  return 0;
end-proc;

// ------------------------------------------------------------------
// Width a converter can plan lines for before the target is opened:
// the source file's data width for a member, C_STMFWIDTH for a stream file.
// 0 when a member target's width cannot be found.
dcl-proc TargetWidthFor export;
  dcl-pi *n int(10);
    i_desc likeds(IAcnvDesc_t) const;
  end-pi;

  if i_desc.mode = C_MODE_MBR;
    return MbrTargetWidth(i_desc);
  endif;
  return C_STMFWIDTH;
end-proc;
