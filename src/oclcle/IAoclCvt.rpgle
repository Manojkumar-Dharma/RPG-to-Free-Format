**FREE
// IAoclCvt - OCL36 to CLLE conversion logic (module of IAoclToCle).
//
// Converted in v1 (see docs/OCL-MAPPING.md for the rules and what is assumed):
//   comment lines, LOAD + RUN, FILE, LOCAL, TAG, GOTO, RETURN,
//   substitution expressions ?n?, ?USER?, ?WS?
// Everything else is written as a CL comment and reported as REVIEW.
// The converted program is collected first, because the PGM statement and
// the DCLs depend on which substitution expressions were used.

ctl-opt nomain option(*srcstmt:*nodebugio);

/copy 'IAcnvSrvP.rpgleinc'

dcl-c C_MAXBODY 5000;
dcl-c C_MAXITEMS 20;
dcl-c C_QUOTE '''';
dcl-c C_CMTCHUNK 60;             // longest piece of text in one CL comment
dcl-c C_LOWER 'abcdefghijklmnopqrstuvwxyz';
dcl-c C_UPPER 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

dcl-s g_body varchar(512) dim(C_MAXBODY);
dcl-s g_bodyCnt int(10);
dcl-s g_overflow ind;
dcl-s g_maxParm int(10);
dcl-s g_useUser ind;
dcl-s g_useWs ind;
dcl-s g_pendLoad ind;
dcl-s g_loadName varchar(60);
dcl-s g_loadLib varchar(60);
dcl-s g_loadLine int(10);
dcl-s g_loadText varchar(512);
dcl-s g_afterRun ind;

// ------------------------------------------------------------------
dcl-proc Up;
  dcl-pi *n varchar(512);
    i_text varchar(512) const;
  end-pi;

  return %xlate(C_LOWER:C_UPPER:i_text);
end-proc;

// ------------------------------------------------------------------
dcl-proc AddBody;
  dcl-pi *n;
    i_text varchar(512) const;
  end-pi;

  if g_bodyCnt >= C_MAXBODY;
    g_overflow = *on;
    return;
  endif;
  g_bodyCnt += 1;
  g_body(g_bodyCnt) = i_text;
end-proc;

// ------------------------------------------------------------------
// Adds text as one or more CL comments (long text is cut into pieces so
// that no comment ever needs a continuation).
dcl-proc AddComment;
  dcl-pi *n;
    i_text varchar(512) const;
  end-pi;

  dcl-s l_rest varchar(512);
  dcl-s l_piece varchar(512);

  l_rest = %trim(%scanrpl('*/':'* /':i_text));
  if %len(l_rest) = 0;
    return;
  endif;
  dow %len(l_rest) > 0;
    if %len(l_rest) > C_CMTCHUNK;
      l_piece = %subst(l_rest:1:C_CMTCHUNK);
      l_rest = %subst(l_rest:C_CMTCHUNK + 1);
    else;
      l_piece = l_rest;
      l_rest = '';
    endif;
    AddBody('/* ' + l_piece + ' */');
  enddo;
end-proc;

// ------------------------------------------------------------------
// Replaces ?n?, ?USER? and ?WS?. o_open is *ON when some other ?...?
// expression is left (it cannot be converted).
dcl-proc Subst;
  dcl-pi *n varchar(512);
    i_text varchar(512) const;
    o_open ind;
  end-pi;

  dcl-s l_in varchar(512);
  dcl-s l_out varchar(512) inz('');
  dcl-s l_p1 int(10);
  dcl-s l_p2 int(10);
  dcl-s l_tok varchar(60);
  dcl-s l_n int(10);

  o_open = *off;
  l_in = i_text;

  dow *on;
    l_p1 = %scan('?':l_in);
    if l_p1 = 0;
      l_out += l_in;
      leave;
    endif;
    l_p2 = %scan('?':l_in:l_p1 + 1);
    if l_p2 = 0;
      o_open = *on;
      l_out += l_in;
      leave;
    endif;

    if l_p1 > 1;
      l_out += %subst(l_in:1:l_p1 - 1);
    endif;
    if l_p2 = l_p1 + 1;          // "??" is not an expression
      o_open = *on;
      l_out += '??';
      if l_p2 >= %len(l_in);
        leave;
      endif;
      l_in = %subst(l_in:l_p2 + 1);
      iter;
    endif;
    l_tok = Up(%subst(l_in:l_p1 + 1:l_p2 - l_p1 - 1));

    select;
      when %len(l_tok) > 0 and %len(l_tok) <= 2
           and %check('0123456789':l_tok) = 0;
        l_n = %int(l_tok);
        if l_n = 0;
          o_open = *on;
          l_out += %subst(l_in:l_p1:l_p2 - l_p1 + 1);
        else;
          g_maxParm = %max(g_maxParm:l_n);
          l_out += '&P' + %trim(%char(l_n));
        endif;
      when l_tok = 'USER';
        g_useUser = *on;
        l_out += '&USER';
      when l_tok = 'WS';
        g_useWs = *on;
        l_out += '&WS';
      other;
        o_open = *on;
        l_out += %subst(l_in:l_p1:l_p2 - l_p1 + 1);
    endsl;

    if l_p2 >= %len(l_in);
      leave;
    endif;
    l_in = %subst(l_in:l_p2 + 1);
  enddo;

  return l_out;
end-proc;

// ------------------------------------------------------------------
// Splits comma separated operands outside quotes. Returns the count.
dcl-proc SplitItems;
  dcl-pi *n int(10);
    i_text varchar(512) const;
    o_items varchar(200) dim(C_MAXITEMS);
  end-pi;

  dcl-s l_i int(10);
  dcl-s l_cnt int(10) inz(0);
  dcl-s l_cur varchar(200) inz('');
  dcl-s l_inQuote ind inz(*off);
  dcl-s l_ch char(1);

  for l_i = 1 to %len(i_text);
    l_ch = %subst(i_text:l_i:1);
    if l_ch = C_QUOTE;
      l_inQuote = not l_inQuote;
    endif;
    if l_ch = ',' and not l_inQuote;
      if l_cnt < C_MAXITEMS;
        l_cnt += 1;
        o_items(l_cnt) = %trim(l_cur);
      endif;
      l_cur = '';
    else;
      l_cur += l_ch;
    endif;
  endfor;

  if %len(%trim(l_cur)) > 0 and l_cnt < C_MAXITEMS;
    l_cnt += 1;
    o_items(l_cnt) = %trim(l_cur);
  endif;
  return l_cnt;
end-proc;

// ------------------------------------------------------------------
// Splits KEY-value. A plain value (no key) comes back with an empty key.
dcl-proc SplitKey;
  dcl-pi *n;
    i_item varchar(200) const;
    o_key varchar(60);
    o_value varchar(200);
  end-pi;

  dcl-s l_p int(10);
  dcl-s l_key varchar(60);

  l_p = %scan('-':i_item);
  if l_p > 1;
    l_key = Up(%trim(%subst(i_item:1:l_p - 1)));
    if %scan(' ':l_key) = 0 and %scan(C_QUOTE:l_key) = 0;
      o_key = l_key;
      o_value = %trim(%subst(i_item:l_p + 1));
      return;
    endif;
  endif;
  o_key = '';
  o_value = %trim(i_item);
end-proc;

// ------------------------------------------------------------------
dcl-proc IsName;
  dcl-pi *n ind;
    i_name varchar(60) const;
    i_maxLen int(10) const;
  end-pi;

  if %len(i_name) = 0 or %len(i_name) > i_maxLen;
    return *off;
  endif;
  if %subst(i_name:1:1) = '&';
    return *on;                  // a variable made by Subst
  endif;
  return %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_#@$':Up(i_name)) = 0;
end-proc;

// ------------------------------------------------------------------
dcl-proc ReviewLine;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_reason varchar(200) const;
  end-pi;

  AddComment('OCL: ' + i_text);
  RptItem(C_STS_REVIEW:i_lineNo:i_text:i_reason);
end-proc;

// ------------------------------------------------------------------
// // LOAD program[,library]   (the CALL is written when RUN arrives)
dcl-proc DoLoad;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_operands varchar(512) const;
  end-pi;

  dcl-s l_items varchar(200) dim(C_MAXITEMS);
  dcl-s l_cnt int(10);
  dcl-s l_open ind;
  dcl-s l_ops varchar(512);
  dcl-s l_name varchar(60);
  dcl-s l_lib varchar(60);

  if g_pendLoad;
    ReviewLine(g_loadLine:g_loadText
               :'LOAD was not followed by RUN before the next LOAD');
    g_pendLoad = *off;
  endif;

  l_ops = Subst(i_operands:l_open);
  l_cnt = SplitItems(l_ops:l_items);
  if l_open or l_cnt < 1 or l_cnt > 2;
    ReviewLine(i_lineNo:i_text
               :'LOAD operands not understood (expected program[,library])');
    return;
  endif;

  l_name = Up(l_items(1));
  l_lib = '';
  if l_cnt = 2;
    l_lib = Up(l_items(2));
  endif;
  if not IsName(l_name:10) or (l_lib <> '' and not IsName(l_lib:10));
    ReviewLine(i_lineNo:i_text:'Program or library name is not a valid name');
    return;
  endif;

  g_pendLoad = *on;
  g_loadName = l_name;
  g_loadLib = l_lib;
  g_loadLine = i_lineNo;
  g_loadText = i_text;
end-proc;

// ------------------------------------------------------------------
dcl-proc DoRun;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_operands varchar(512) const;
  end-pi;

  dcl-s l_call varchar(200);

  g_afterRun = *on;
  if not g_pendLoad;
    ReviewLine(i_lineNo:i_text:'RUN without a LOAD');
    return;
  endif;

  l_call = 'CALL PGM(';
  if g_loadLib <> '';
    l_call += g_loadLib + '/';
  endif;
  l_call += g_loadName + ')';
  AddBody(l_call);
  g_pendLoad = *off;

  select;
    when %len(%trim(i_operands)) > 0;
      AddComment('OCL: ' + i_text);
      RptItem(C_STS_REVIEW:i_lineNo:i_text:'RUN operands are not converted');
    when g_loadLib <> '';
      RptItem(C_STS_ASSUMPTION:g_loadLine:g_loadText
              :'Second LOAD operand taken as the program library');
    other;
      RptItem(C_STS_CONVERTED:g_loadLine:g_loadText:'');
  endsl;
end-proc;

// ------------------------------------------------------------------
// // FILE NAME-x[,LABEL-y][,LIBRARY-z][,DISP-...]  ->  OVRDBF
dcl-proc DoFile;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_operands varchar(512) const;
  end-pi;

  dcl-s l_items varchar(200) dim(C_MAXITEMS);
  dcl-s l_cnt int(10);
  dcl-s l_i int(10);
  dcl-s l_open ind;
  dcl-s l_ops varchar(512);
  dcl-s l_key varchar(60);
  dcl-s l_val varchar(200);
  dcl-s l_name varchar(60) inz('');
  dcl-s l_label varchar(60) inz('');
  dcl-s l_lib varchar(60) inz('');
  dcl-s l_disp varchar(60) inz('');
  dcl-s l_other varchar(200) inz('');
  dcl-s l_cmd varchar(200);

  l_ops = Subst(i_operands:l_open);
  l_cnt = SplitItems(l_ops:l_items);
  if l_open or l_cnt < 1;
    ReviewLine(i_lineNo:i_text:'FILE operands not understood');
    return;
  endif;

  for l_i = 1 to l_cnt;
    SplitKey(l_items(l_i):l_key:l_val);
    select;
      when l_key = 'NAME';
        l_name = Up(l_val);
      when l_key = 'LABEL';
        l_label = Up(l_val);
      when l_key = 'LIBRARY';
        l_lib = Up(l_val);
      when l_key = 'DISP';
        l_disp = Up(l_val);
      other;
        if %len(l_other) > 0;
          l_other += ' ';
        endif;
        if l_key = '';
          l_other += l_val;
        else;
          l_other += l_key;
        endif;
    endsl;
  endfor;

  if l_label = '';
    l_label = l_name;
  endif;
  if not IsName(l_name:10) or not IsName(l_label:10)
     or (l_lib <> '' and not IsName(l_lib:10));
    ReviewLine(i_lineNo:i_text:'NAME, LABEL or LIBRARY is missing or not a valid name');
    return;
  endif;
  if l_disp = 'NEW';
    ReviewLine(i_lineNo:i_text
               :'DISP-NEW (creating the file) is not converted');
    return;
  endif;

  l_cmd = 'OVRDBF FILE(' + l_name + ') TOFILE(';
  if l_lib <> '';
    l_cmd += l_lib + '/';
  endif;
  l_cmd += l_label + ')';
  AddBody(l_cmd);

  select;
    when l_other <> '';
      AddComment('OCL: ' + i_text);
      RptItem(C_STS_REVIEW:i_lineNo:i_text
              :'Keywords not converted: ' + l_other);
    when l_disp <> '';
      RptItem(C_STS_ASSUMPTION:i_lineNo:i_text
              :'DISP-' + l_disp + ' not converted; OVRDBF default sharing applies');
    other;
      RptItem(C_STS_CONVERTED:i_lineNo:i_text:'');
  endsl;
end-proc;

// ------------------------------------------------------------------
// // LOCAL OFFSET-n,DATA-'text'  ->  CHGDTAARA on *LDA
// The OFFSET base (0 or 1) has not been verified against IBM's reference,
// so the line is written (position = OFFSET + 1) and reported as REVIEW.
dcl-proc DoLocal;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_operands varchar(512) const;
  end-pi;

  dcl-s l_items varchar(200) dim(C_MAXITEMS);
  dcl-s l_cnt int(10);
  dcl-s l_i int(10);
  dcl-s l_key varchar(60);
  dcl-s l_val varchar(200);
  dcl-s l_offset varchar(60) inz('');
  dcl-s l_data varchar(200) inz('');
  dcl-s l_hasData ind inz(*off);
  dcl-s l_other ind inz(*off);
  dcl-s l_open ind;
  dcl-s l_chk varchar(512);
  dcl-s l_len int(10);
  dcl-s l_pos int(10);

  l_cnt = SplitItems(i_operands:l_items);
  for l_i = 1 to l_cnt;
    SplitKey(l_items(l_i):l_key:l_val);
    select;
      when l_key = 'OFFSET';
        l_offset = l_val;
      when l_key = 'DATA';
        l_data = l_val;
        l_hasData = *on;
      other;
        l_other = *on;
    endsl;
  endfor;

  if l_cnt < 1 or l_other or not l_hasData
     or %len(l_offset) = 0 or %check('0123456789':l_offset) > 0;
    ReviewLine(i_lineNo:i_text
               :'LOCAL needs OFFSET-n and DATA-value only');
    return;
  endif;

  // Strip the quotes round the data.
  if %len(l_data) >= 2 and %subst(l_data:1:1) = C_QUOTE
     and %subst(l_data:%len(l_data):1) = C_QUOTE;
    l_data = %subst(l_data:2:%len(l_data) - 2);
  endif;

  // Substitution inside the data cannot be expressed by CHGDTAARA VALUE.
  l_chk = Subst(l_data:l_open);
  if l_open or l_chk <> l_data or %len(l_data) = 0;
    ReviewLine(i_lineNo:i_text
               :'DATA is empty or uses a substitution expression');
    return;
  endif;

  l_len = %len(%scanrpl('''''':' ':l_data));
  l_pos = %int(l_offset) + 1;
  AddBody('CHGDTAARA DTAARA(*LDA (' + %trim(%char(l_pos)) + ' '
          + %trim(%char(l_len)) + ')) VALUE(' + C_QUOTE + l_data
          + C_QUOTE + ')');
  RptItem(C_STS_REVIEW:i_lineNo:i_text
          :'OFFSET base not verified: position written as OFFSET + 1');
end-proc;

// ------------------------------------------------------------------
// // TAG name  and  // GOTO name
dcl-proc DoTagGoto;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_isTag ind const;
    i_operands varchar(512) const;
  end-pi;

  dcl-s l_label varchar(60);

  l_label = Up(%trim(i_operands));
  if not IsName(l_label:10) or %scan(' ':l_label) > 0
     or %subst(l_label:1:1) = '&';
    ReviewLine(i_lineNo:i_text:'Label is not a valid CL label (10 characters)');
    return;
  endif;

  if i_isTag;
    AddBody(l_label + ':');
  else;
    AddBody('GOTO CMDLBL(' + l_label + ')');
  endif;
  RptItem(C_STS_CONVERTED:i_lineNo:i_text:'');
end-proc;

// ------------------------------------------------------------------
dcl-proc ProcessStatement;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
  end-pi;

  dcl-s l_s varchar(512);
  dcl-s l_kw varchar(60);
  dcl-s l_ops varchar(512);
  dcl-s l_p int(10);

  g_afterRun = *off;
  l_s = %trim(%subst(%trim(i_text):3));
  if %len(l_s) = 0;
    ReviewLine(i_lineNo:i_text:'Empty OCL statement');
    return;
  endif;

  l_p = %scan(' ':l_s);
  if l_p = 0;
    l_kw = Up(l_s);
    l_ops = '';
  else;
    l_kw = Up(%subst(l_s:1:l_p - 1));
    l_ops = %trim(%subst(l_s:l_p + 1));
  endif;

  select;
    when l_kw = 'LOAD';
      DoLoad(i_lineNo:i_text:l_ops);
    when l_kw = 'RUN';
      DoRun(i_lineNo:i_text:l_ops);
    when l_kw = 'FILE';
      DoFile(i_lineNo:i_text:l_ops);
    when l_kw = 'LOCAL';
      DoLocal(i_lineNo:i_text:l_ops);
    when l_kw = 'TAG';
      DoTagGoto(i_lineNo:i_text:*on:l_ops);
    when l_kw = 'GOTO';
      DoTagGoto(i_lineNo:i_text:*off:l_ops);
    when l_kw = 'RETURN' and %len(l_ops) = 0;
      AddBody('RETURN');
      RptItem(C_STS_CONVERTED:i_lineNo:i_text:'');
    other;
      ReviewLine(i_lineNo:i_text
                 :'OCL statement ' + l_kw + ' is not converted in this version');
  endsl;
end-proc;

// ------------------------------------------------------------------
dcl-proc ProcessLine;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
  end-pi;

  dcl-s l_t varchar(512);
  dcl-s l_c varchar(512);

  l_t = %trim(i_text);

  select;
    when %len(l_t) = 0;
      AddBody('');
    when %subst(l_t:1:1) = '*';
      l_c = %trim(%subst(l_t:2));
      if %len(l_c) = 0;
        AddBody('');
      else;
        AddComment(l_c);
      endif;
      RptItem(C_STS_CONVERTED:i_lineNo:i_text:'');
    when %len(l_t) >= 2 and (%subst(l_t:1:2) = '/*'
         or %subst(l_t:1:2) = '/&');
      g_afterRun = *off;
      ReviewLine(i_lineNo:i_text
                 :'End-of-data or end-of-job marker is not converted');
    when %len(l_t) >= 2 and %subst(l_t:1:2) = '//';
      ProcessStatement(i_lineNo:i_text);
    other;
      if g_afterRun;
        ReviewLine(i_lineNo:i_text:'Data line after RUN is not converted');
      else;
        ReviewLine(i_lineNo:i_text:'Line is not an OCL statement');
      endif;
  endsl;
end-proc;

// ------------------------------------------------------------------
dcl-proc WriteCl;
  dcl-pi *n int(10);
    i_line varchar(512) const;
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  dcl-s l_lines int(10);
  dcl-s l_status char(1);

  if WriteText(i_line:C_WRAP_CL:l_lines:l_status:o_msgId:o_msgData) <> 0;
    return 1;
  endif;
  if l_status = C_STS_REVIEW;
    RptItem(C_STS_REVIEW:0:i_line:'Line written without a safe break');
  endif;
  return 0;
end-proc;

// ------------------------------------------------------------------
dcl-proc WriteProgram;
  dcl-pi *n int(10);
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  dcl-s l_i int(10);
  dcl-s l_line varchar(512);
  dcl-s l_parms varchar(512);

  l_line = 'PGM';
  if g_maxParm > 0;
    l_parms = '';
    for l_i = 1 to g_maxParm;
      if l_i > 1;
        l_parms += ' ';
      endif;
      l_parms += '&P' + %trim(%char(l_i));
    endfor;
    l_line += ' PARM(' + l_parms + ')';
  endif;
  if WriteCl(l_line:o_msgId:o_msgData) <> 0;
    return 1;
  endif;

  for l_i = 1 to g_maxParm;
    if WriteCl('DCL VAR(&P' + %trim(%char(l_i)) + ') TYPE(*CHAR) LEN(10)'
               :o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endfor;
  if g_useUser;
    if WriteCl('DCL VAR(&USER) TYPE(*CHAR) LEN(10)':o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endif;
  if g_useWs;
    if WriteCl('DCL VAR(&WS) TYPE(*CHAR) LEN(10)':o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endif;
  if g_useUser;
    if WriteCl('RTVJOBA USER(&USER)':o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endif;
  if g_useWs;
    if WriteCl('RTVJOBA JOB(&WS)':o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endif;

  for l_i = 1 to g_bodyCnt;
    if WriteCl(g_body(l_i):o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endfor;

  if WriteCl('ENDPGM':o_msgId:o_msgData) <> 0;
    return 1;
  endif;
  return 0;
end-proc;

// ------------------------------------------------------------------
dcl-proc OclConvert export;
  dcl-pi *n int(10);
    i_src likeds(IAcnvDesc_t) const;
    i_tgt likeds(IAcnvDesc_t) const;
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  dcl-s l_text varchar(512);
  dcl-s l_next varchar(512);
  dcl-s l_t varchar(512);
  dcl-s l_nt varchar(512);
  dcl-s l_no int(10);
  dcl-s l_first int(10);
  dcl-s l_joined ind;
  dcl-s l_rc int(10);

  g_bodyCnt = 0;
  g_overflow = *off;
  g_maxParm = 0;
  g_useUser = *off;
  g_useWs = *off;
  g_pendLoad = *off;
  g_afterRun = *off;

  if OpenSource(i_src:o_msgId:o_msgData) <> 0;
    return 1;
  endif;

  dow ReadLine(l_text:l_no);
    l_first = l_no;
    l_t = %trim(l_text);
    l_joined = *off;

    // A statement continues when it ends with a comma.
    if %len(l_t) >= 2 and %subst(l_t:1:2) = '//';
      dow %len(l_t) > 0 and %subst(l_t:%len(l_t):1) = ',';
        if not ReadLine(l_next:l_no);
          leave;
        endif;
        l_nt = %trim(l_next);
        if %len(l_nt) >= 2 and %subst(l_nt:1:2) = '//';
          l_nt = %trim(%subst(l_nt:3));
        endif;
        l_t += l_nt;
        l_joined = *on;
      enddo;
    endif;

    ProcessLine(l_first:l_t);
    if l_joined;
      RptItem(C_STS_ASSUMPTION:l_first:l_t
              :'Continuation lines joined after a trailing comma');
    endif;
    if g_overflow;
      leave;
    endif;
  enddo;

  if ReadError(o_msgId:o_msgData);
    CloseSource();
    return 1;
  endif;
  CloseSource();

  if g_overflow;
    o_msgId = 'IAC0101';
    o_msgData = 'The program has more than ' + %char(C_MAXBODY)
                + ' converted lines';
    return 1;
  endif;

  if g_pendLoad;
    ReviewLine(g_loadLine:g_loadText:'LOAD was never followed by RUN');
    g_pendLoad = *off;
  endif;
  if g_maxParm > 0;
    RptItem(C_STS_ASSUMPTION:0:'Parameters ?n?'
            :'Declared as CHAR(10); check the lengths the callers pass');
  endif;

  if OpenTarget(i_tgt:o_msgId:o_msgData) <> 0;
    return 1;
  endif;
  l_rc = WriteProgram(o_msgId:o_msgData);
  CloseTarget();
  return l_rc;
end-proc;
