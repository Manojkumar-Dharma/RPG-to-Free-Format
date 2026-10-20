**FREE
// IAdspCvt - conversion module of IAcnvDspf.
// DSP36: System/36 display format source (SFGR: S, H and D specifications,
//        SC41-4730 Appendix B) to AS/400 DDS for a display file.
// DSP38: System/38 display DDS, copied line by line (see docs/DSPF-MAPPING.md).
// Bind with service program IAcnvSrv.

ctl-opt nomain option(*srcstmt:*nodebugio);

/copy IAcnvSrvP

dcl-c C_MAXSRC 20000;
dcl-c C_MAXOUT 40000;
dcl-c C_MAXNAMES 600;
dcl-c C_QUOTE '''';
dcl-c C_LOWER 'abcdefghijklmnopqrstuvwxyz';
dcl-c C_UPPER 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
dcl-c C_KEYW 36;                   // width of the DDS keyword area (cols 45-80)

// Source records are 80 columns: columns 1-5 sequence, 6 type, 7-80 data.
dcl-s g_src char(80) dim(C_MAXSRC);
dcl-s g_srcNo int(10) dim(C_MAXSRC);
dcl-s g_srcCnt int(10);
dcl-s g_out varchar(80) dim(C_MAXOUT);
dcl-s g_outCnt int(10);
dcl-s g_overflow ind;

dcl-s g_fmtOpen ind;
dcl-s g_fmtName varchar(10);
dcl-s g_override ind;              // the open format uses override
dcl-s g_lowerDft ind;              // S-spec column 21 = Y for the open format
dcl-s g_fmtCnt int(10);
dcl-s g_fldGen int(10);
dcl-s g_names varchar(10) dim(C_MAXNAMES);
dcl-s g_nameCnt int(10);
dcl-s g_srcLineNo int(10);         // line number reported for the current item

// Keywords collected for one field: indicator ('' = always, else 2 digits).
dcl-c C_MAXKW 40;
dcl-s g_kwInd varchar(2) dim(C_MAXKW);
dcl-s g_kwTxt varchar(80) dim(C_MAXKW);
dcl-s g_kwCnt int(10);

// ------------------------------------------------------------------
// Safe substring helpers (RPG %SUBST fails on empty or out-of-range input).
dcl-proc Mid;
  dcl-pi *n varchar(512);
    i_text varchar(512) const;
    i_from int(10) const;
    i_len int(10) const;
  end-pi;

  dcl-s l_len int(10);

  if i_len <= 0 or i_from < 1 or i_from > %len(i_text);
    return '';
  endif;
  l_len = %min(i_len:%len(i_text) - i_from + 1);
  return %subst(i_text:i_from:l_len);
end-proc;

// ------------------------------------------------------------------
// Columns a through b of a source record, trimmed.
dcl-proc Cols;
  dcl-pi *n varchar(80);
    i_rec char(80) const;
    i_from int(10) const;
    i_to int(10) const;
  end-pi;

  return %trim(%subst(i_rec:i_from:i_to - i_from + 1));
end-proc;

// ------------------------------------------------------------------
// -1 when the text is not a whole number (empty counts as not a number).
dcl-proc Num;
  dcl-pi *n int(10);
    i_text varchar(20) const;
  end-pi;

  dcl-s l_t varchar(20);

  l_t = %trim(i_text);
  if %len(l_t) = 0 or %len(l_t) > 9;
    return -1;
  endif;
  if %check('0123456789':l_t) > 0;
    return -1;
  endif;
  return %int(l_t);
end-proc;

// ------------------------------------------------------------------
// Horizontal position: 1-99, or A0..D2 for 100-132.
dcl-proc HPos;
  dcl-pi *n int(10);
    i_text varchar(20) const;
  end-pi;

  dcl-s l_t varchar(20);
  dcl-s l_base int(10);
  dcl-s l_d int(10);

  l_t = %trim(i_text);
  if %len(l_t) = 2 and %scan(%subst(l_t:1:1):'ABCD') > 0;
    l_base = 100 + (%scan(%subst(l_t:1:1):'ABCD') - 1) * 10;
    l_d = Num(%subst(l_t:2:1));
    if l_d < 0;
      return -1;
    endif;
    return l_base + l_d;
  endif;
  return Num(l_t);
end-proc;

// ------------------------------------------------------------------
// Entry that is Y, N (or blank) or an indicator 01-99:
//   'N' none, 'Y' always, 'I' + 2 digits an indicator, '?' anything else.
dcl-proc IndSpec;
  dcl-pi *n varchar(3);
    i_text varchar(20) const;
  end-pi;

  dcl-s l_t varchar(20);
  dcl-s l_n int(10);

  l_t = %trim(%xlate(C_LOWER:C_UPPER:i_text));
  if l_t = '' or l_t = 'N';
    return 'N';
  endif;
  if l_t = 'Y';
    return 'Y';
  endif;
  l_n = Num(l_t);
  if l_n >= 1 and l_n <= 99 and %len(l_t) <= 2;
    return 'I' + %subst('0' + %trim(%char(l_n)):%len(%trim(%char(l_n))):2);
  endif;
  return '?';
end-proc;

// ------------------------------------------------------------------
// The indicator digits of an IndSpec result ('' when none).
dcl-proc IndOf;
  dcl-pi *n varchar(2);
    i_spec varchar(3) const;
  end-pi;

  if %len(i_spec) = 3 and %subst(i_spec:1:1) = 'I';
    return %subst(i_spec:2:2);
  endif;
  return '';
end-proc;

// ------------------------------------------------------------------
// Right-justified number of the given width, for DDS columns.
dcl-proc RJ;
  dcl-pi *n varchar(10);
    i_n int(10) const;
    i_w int(10) const;
  end-pi;

  dcl-s l_s varchar(10);

  l_s = %trim(%char(i_n));
  if %len(l_s) >= i_w;
    return l_s;
  endif;
  return %subst('          ':1:i_w - %len(l_s)) + l_s;
end-proc;

// ------------------------------------------------------------------
dcl-proc AddOut;
  dcl-pi *n;
    i_rec char(80) const;
  end-pi;

  if g_outCnt >= C_MAXOUT;
    g_overflow = *on;
    return;
  endif;
  g_outCnt += 1;
  g_out(g_outCnt) = %trimr(i_rec);
end-proc;

// ------------------------------------------------------------------
// One DDS line: A in column 6, optional condition (column 8 N, 9-10
// indicator), name type (17), name (19-28), length (30-34), data type (35),
// decimals (36-37), usage (38), line (39-41), position (42-44), keywords
// (45-80). Empty or zero arguments leave their columns blank.
dcl-proc Rec;
  dcl-pi *n char(80);
    i_cond varchar(2) const;
    i_neg ind const;
    i_nameType char(1) const;
    i_name varchar(10) const;
    i_len int(10) const;
    i_dt char(1) const;
    i_dec int(10) const;
    i_use char(1) const;
    i_line int(10) const;
    i_pos int(10) const;
    i_kw varchar(36) const;
  end-pi;

  dcl-s l_r char(80) inz(*blanks);

  %subst(l_r:6:1) = 'A';
  if %len(i_cond) = 2;
    if i_neg;
      %subst(l_r:8:1) = 'N';
    endif;
    %subst(l_r:9:2) = i_cond;
  endif;
  %subst(l_r:17:1) = i_nameType;
  if %len(i_name) > 0;
    %subst(l_r:19:%len(i_name)) = i_name;
  endif;
  if i_len > 0;
    %subst(l_r:30:5) = RJ(i_len:5);
  endif;
  %subst(l_r:35:1) = i_dt;
  if i_dec >= 0;
    %subst(l_r:36:2) = RJ(i_dec:2);
  endif;
  %subst(l_r:38:1) = i_use;
  if i_line > 0;
    %subst(l_r:39:3) = RJ(i_line:3);
  endif;
  if i_pos > 0;
    %subst(l_r:42:3) = RJ(i_pos:3);
  endif;
  if %len(i_kw) > 0;
    %subst(l_r:45:%len(i_kw)) = i_kw;
  endif;
  return l_r;
end-proc;

// ------------------------------------------------------------------
// A keyword (or keyword text) on its own line, optionally conditioned by
// an indicator.
dcl-proc AddKw;
  dcl-pi *n;
    i_ind varchar(2) const;
    i_text varchar(36) const;
  end-pi;

  AddOut(Rec(i_ind:*off:' ':'':0:' ':-1:' ':0:0:i_text));
end-proc;

// ------------------------------------------------------------------
// prefix + 'text' + suffix as DDS keyword text, cut into lines of the
// keyword area with '-' continuation. A doubled apostrophe is never split.
// The first line is i_front (columns 1-44 already filled); the others carry
// only the keyword text.
dcl-proc AddLiteral;
  dcl-pi *n;
    i_front char(80) const;
    i_prefix varchar(10) const;
    i_text varchar(512) const;
    i_suffix varchar(10) const;
  end-pi;

  dcl-s l_full varchar(600);
  dcl-s l_chunk varchar(40);
  dcl-s l_unit varchar(2);
  dcl-s l_i int(10);
  dcl-s l_total int(10);
  dcl-s l_p0 int(10);
  dcl-s l_p1 int(10);
  dcl-s l_first ind inz(*on);
  dcl-s l_line char(80);

  l_p0 = %len(i_prefix) + 2;
  l_full = i_prefix + C_QUOTE + %scanrpl(C_QUOTE:C_QUOTE + C_QUOTE:i_text)
           + C_QUOTE + i_suffix;
  l_total = %len(l_full);
  l_p1 = l_total - %len(i_suffix) - 1;          // last char of the text part
  l_chunk = '';
  l_i = 1;

  dow l_i <= l_total;
    // the rest fits on one line: take it all
    if %len(l_chunk) + (l_total - l_i + 1) <= C_KEYW;
      l_chunk += Mid(l_full:l_i:l_total - l_i + 1);
      leave;
    endif;
    l_unit = Mid(l_full:l_i:1);
    if l_unit = C_QUOTE and l_i >= l_p0 and l_i <= l_p1;
      l_unit = C_QUOTE + C_QUOTE;           // doubled apostrophe stays whole
    endif;
    if %len(l_chunk) + %len(l_unit) > C_KEYW - 1;
      if l_first;
        l_line = i_front;
        %subst(l_line:45:%len(l_chunk) + 1) = l_chunk + '-';
        AddOut(l_line);
        l_first = *off;
      else;
        AddKw('':l_chunk + '-');
      endif;
      l_chunk = '';
    endif;
    l_chunk += l_unit;
    l_i += %len(l_unit);
  enddo;

  if l_first;
    l_line = i_front;
    %subst(l_line:45:%len(l_chunk)) = l_chunk;
    AddOut(l_line);
  else;
    AddKw('':l_chunk);
  endif;
end-proc;

// ------------------------------------------------------------------
dcl-proc ValidDdsName;
  dcl-pi *n ind;
    i_name varchar(10) const;
  end-pi;

  if %len(i_name) < 1 or %len(i_name) > 10;
    return *off;
  endif;
  if %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ@$#':%subst(i_name:1:1)) > 0;
    return *off;
  endif;
  return %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@$#_':i_name) = 0;
end-proc;

// ------------------------------------------------------------------
dcl-proc NameUsed;
  dcl-pi *n ind;
    i_name varchar(10) const;
  end-pi;

  dcl-s l_i int(10);

  for l_i = 1 to %min(g_nameCnt:C_MAXNAMES);
    if g_names(l_i) = i_name;
      return *on;
    endif;
  endfor;
  return *off;
end-proc;

dcl-proc RememberName;
  dcl-pi *n;
    i_name varchar(10) const;
  end-pi;

  if g_nameCnt < C_MAXNAMES;
    g_nameCnt += 1;
    g_names(g_nameCnt) = i_name;
  endif;
end-proc;

// ------------------------------------------------------------------
// Keys listed in the key mask (S-spec columns 64-79) become DDS keywords.
// i_mode is column 27 (function keys) or 28 (command keys): blank = all
// enabled, Y = only the listed ones, N = all but the listed, R = retain.
dcl-proc EnableKey;
  dcl-pi *n ind;
    i_mode char(1) const;
    i_listed ind const;
  end-pi;

  select;
    when i_mode = 'Y';
      return i_listed;
    when i_mode = 'N';
      return not i_listed;
    when i_mode = 'R';
      return *off;
  endsl;
  return *on;
end-proc;

dcl-proc KeyKeywords;
  dcl-pi *n;
    i_rec char(80) const;
  end-pi;

  dcl-c C_FKEYS 'PRINT   ROLLUP  ROLLDOWNCLEAR   HELP    HOME    ';
  dcl-c C_CMDLET 'ABCDEFGHIJKLMNPQRSTUVWXY';

  dcl-s l_mask varchar(20);
  dcl-s l_k int(10);
  dcl-s l_kw varchar(8);
  dcl-s l_two varchar(2);

  l_mask = %xlate(C_LOWER:C_UPPER:Cols(i_rec:64:79));

  for l_k = 1 to 6;
    if EnableKey(%subst(i_rec:27:1):%scan(%char(l_k):l_mask) > 0);
      l_kw = %trim(%subst(C_FKEYS:(l_k - 1) * 8 + 1:8));
      AddKw('':l_kw);
    endif;
  endfor;

  for l_k = 1 to 24;
    if EnableKey(%subst(i_rec:28:1)
                 :%scan(%subst(C_CMDLET:l_k:1):l_mask) > 0);
      l_two = %subst('0' + %trim(%char(l_k)):%len(%trim(%char(l_k))):2);
      AddKw('':'CF' + l_two + '(' + l_two + ')');
    endif;
  endfor;
end-proc;

// ------------------------------------------------------------------
// S specification: start of a record format.
dcl-proc ConvertS;
  dcl-pi *n;
    i_rec char(80) const;
    i_no int(10) const;
  end-pi;

  dcl-s l_name varchar(10);
  dcl-s l_dds varchar(10);
  dcl-s l_v varchar(20);
  dcl-s l_n int(10);
  dcl-s l_sp varchar(3);
  dcl-s l_status char(1) inz(C_STS_CONVERTED);
  dcl-s l_why varchar(200) inz('');

  l_name = Cols(i_rec:7:14);
  g_fmtCnt += 1;
  g_nameCnt = 0;
  g_fldGen = 0;
  g_fmtOpen = *on;

  if ValidDdsName(l_name);
    l_dds = l_name;
  else;
    l_dds = 'FMT' + %trim(%char(g_fmtCnt));
    l_status = C_STS_ASSUMPTION;
    l_why = 'Format name not valid in DDS; ' + l_dds
            + ' used and the original kept as ALTNAME';
  endif;
  AddOut(Rec('':*off:'R':l_dds:0:' ':-1:' ':0:0:''));
  if l_dds <> l_name and %len(l_name) > 0;
    AddKw('':'ALTNAME(' + C_QUOTE + l_name + C_QUOTE + ')');
  endif;

  // Start line (17-18)
  l_v = %xlate(C_LOWER:C_UPPER:Cols(i_rec:17:18));
  if l_v = 'V';
    AddKw('':'SLNO(*VAR)');
  elseif l_v <> '';
    l_n = Num(l_v);
    if l_n >= 1;
      AddKw('':'SLNO(' + %trim(%char(l_n)) + ')');
    else;
      l_status = C_STS_REVIEW;
      l_why = 'Start line number is not valid';
    endif;
  endif;

  // Lines to clear (19-20)
  l_v = Cols(i_rec:19:20);
  if l_v = '';
    AddKw('':'CLRL(*ALL)');
  else;
    l_n = Num(l_v);
    if l_n = 0;
      AddKw('':'CLRL(*NO)');
    elseif l_n > 0;
      AddKw('':'CLRL(' + %trim(%char(l_n)) + ')');
    else;
      l_status = C_STS_REVIEW;
      l_why = 'Lines to clear is not valid';
    endif;
  endif;

  g_lowerDft = %subst(i_rec:21:1) = 'Y' or %subst(i_rec:21:1) = 'y';
  if %subst(i_rec:22:1) <> 'N' and %subst(i_rec:22:1) <> 'n';
    AddKw('':'RTNDTA');
  endif;

  // Alarm (25-26), blink cursor (29-30), erase input (31-32),
  // override (33-34), suppress input (35-36): Y or an indicator.
  l_sp = IndSpec(Cols(i_rec:25:26));
  if l_sp <> 'N';
    if l_sp = '?';
      l_status = C_STS_REVIEW;
      l_why = 'Sound alarm entry is not Y, N or an indicator';
    else;
      AddKw(IndOf(l_sp):'ALARM');
    endif;
  endif;
  l_sp = IndSpec(Cols(i_rec:29:30));
  if l_sp <> 'N' and l_sp <> '?';
    AddKw(IndOf(l_sp):'BLINK');
  endif;
  l_sp = IndSpec(Cols(i_rec:31:32));
  if l_sp <> 'N' and l_sp <> '?';
    AddKw(IndOf(l_sp):'ERASEINP');
  endif;
  l_sp = IndSpec(Cols(i_rec:33:34));
  g_override = (l_sp <> 'N' and l_sp <> '?');
  if g_override;
    AddKw(IndOf(l_sp):'OVERRIDE');
    if l_status = C_STS_CONVERTED;
      l_status = C_STS_ASSUMPTION;
      l_why = 'Override: OVRDTA/OVRATR added on fields; check the behaviour';
    endif;
  endif;
  l_sp = IndSpec(Cols(i_rec:35:36));
  if l_sp <> 'N' and l_sp <> '?';
    AddKw(IndOf(l_sp):'LOCK');
  endif;

  KeyKeywords(i_rec);
  AddKw('':'INVITE');

  if %subst(i_rec:39:1) = 'Y' or %subst(i_rec:39:1) = 'y';
    if l_status = C_STS_CONVERTED;
      l_status = C_STS_ASSUMPTION;
      l_why = '132-column format: the file is created for both sizes';
    endif;
  endif;
  RptItem(l_status:i_no:%trimr(i_rec):l_why);
end-proc;

// ------------------------------------------------------------------
// Attribute and check keywords of one D specification are collected, then
// written after the field (or constant) line.
dcl-proc KwAdd;
  dcl-pi *n;
    i_ind varchar(2) const;
    i_text varchar(80) const;
  end-pi;

  if g_kwCnt < C_MAXKW;
    g_kwCnt += 1;
    g_kwInd(g_kwCnt) = i_ind;
    g_kwTxt(g_kwCnt) = i_text;
  endif;
end-proc;

dcl-proc KwFlush;
  dcl-s l_i int(10);

  for l_i = 1 to g_kwCnt;
    AddKw(g_kwInd(l_i):g_kwTxt(l_i));
  endfor;
  g_kwCnt = 0;
end-proc;

// ------------------------------------------------------------------
// Display attributes: columns 37-48 and 49 and position cursor (32-33).
// Returns *ON when an indicator controls one of the attributes.
dcl-proc CollectAttrs;
  dcl-pi *n ind;
    i_rec char(80) const;
    i_input ind const;
  end-pi;

  dcl-c C_ATTR 'HI BL ND RI UL ';
  dcl-s l_always varchar(30);
  dcl-s l_k int(10);
  dcl-s l_col int(10);
  dcl-s l_sp varchar(3);
  dcl-s l_tok varchar(2);
  dcl-s l_hasInd ind inz(*off);

  l_always = '';
  for l_k = 1 to 5;
    l_col = 37 + l_k * 2;                    // 39, 41, 43, 45, 47
    l_sp = IndSpec(Cols(i_rec:l_col:l_col + 1));
    l_tok = %subst(C_ATTR:(l_k - 1) * 3 + 1:2);
    select;
      when l_sp = 'Y';
        l_always += ' ' + l_tok;
      when %subst(l_sp:1:1) = 'I';
        KwAdd(IndOf(l_sp):'DSPATR(' + l_tok + ')');
        l_hasInd = *on;
    endsl;
  endfor;
  if %subst(i_rec:49:1) = 'Y' or %subst(i_rec:49:1) = 'y';
    l_always += ' CS';
  endif;

  if i_input;
    l_sp = IndSpec(Cols(i_rec:37:38));            // protect
    if l_sp = 'Y';
      l_always += ' PR';
    elseif %subst(l_sp:1:1) = 'I';
      KwAdd(IndOf(l_sp):'DSPATR(PR)');
    endif;
    l_sp = IndSpec(Cols(i_rec:32:33));            // position cursor
    if l_sp = 'Y';
      l_always += ' PC';
    elseif %subst(l_sp:1:1) = 'I';
      KwAdd(IndOf(l_sp):'DSPATR(PC)');
    endif;
  endif;
  if %len(l_always) > 0;
    KwAdd('':'DSPATR(' + %trim(l_always) + ')');
  endif;
  return l_hasInd;
end-proc;

// ------------------------------------------------------------------
// CHECK, DUP and LOWER keywords of an input field.
dcl-proc CollectInput;
  dcl-pi *n;
    i_rec char(80) const;
    i_numeric ind const;
  end-pi;

  dcl-s l_chk varchar(30);
  dcl-s l_c char(1);

  l_chk = '';
  if %subst(i_rec:29:1) = 'Y';
    l_chk += ' ME';
  endif;
  if %subst(i_rec:28:1) = 'Y';
    l_chk += ' MF';
  endif;
  l_c = %subst(i_rec:30:1);
  if l_c = 'T';
    l_chk += ' M10';
  elseif l_c = 'E';
    l_chk += ' M11';
  endif;
  l_c = %subst(i_rec:31:1);
  if l_c = 'Z';
    l_chk += ' RZ';
  elseif l_c = 'B';
    l_chk += ' RB';
  endif;
  if %subst(i_rec:35:1) = 'Y';
    l_chk += ' FE';
  endif;
  if %subst(i_rec:36:1) = 'Y';
    l_chk += ' AB';
  endif;
  if %len(l_chk) > 0;
    KwAdd('':'CHECK(' + %trim(l_chk) + ')');
  endif;
  if %subst(i_rec:34:1) = 'Y';
    KwAdd('':'DUP');
  endif;
  if not i_numeric
     and (%subst(i_rec:51:1) = 'Y'
          or (%subst(i_rec:51:1) = ' ' and g_lowerDft));
    KwAdd('':'LOWER');
  endif;
end-proc;

// ------------------------------------------------------------------
// SFGR data type (D-spec column 27) to DDS data type.
dcl-proc DdsType;
  dcl-pi *n char(1);
    i_dt char(1) const;
  end-pi;

  select;
    when i_dt = 'A';
      return 'X';
    when i_dt = 'M';
      return 'N';
    when i_dt = 'N';
      return 'M';
    when i_dt = 'S';
      return 'S';
    when i_dt = 'R';
      return 'I';
    when i_dt = 'D';
      return 'D';
    when i_dt = 'K';
      return 'W';
  endsl;
  return 'A';                       // blank, B, Z and the double-byte types
end-proc;


// ------------------------------------------------------------------
// D specification: one field or constant. io_i is the index of the record
// and moves on when the constant continues on following records.
dcl-proc ConvertD;
  dcl-pi *n;
    io_i int(10);
  end-pi;

  dcl-s l_rec char(80);
  dcl-s l_no int(10);
  dcl-s l_name varchar(10);
  dcl-s l_len int(10);
  dcl-s l_line int(10);
  dcl-s l_pos int(10);
  dcl-s l_outS varchar(3);
  dcl-s l_ind varchar(2);
  dcl-s l_inp ind;
  dcl-s l_dt char(1);
  dcl-s l_ddt char(1);
  dcl-s l_use char(1);
  dcl-s l_data varchar(512);
  dcl-s l_cont ind;
  dcl-s l_numeric ind;
  dcl-s l_attrInd ind;
  dcl-s l_status char(1) inz(C_STS_CONVERTED);
  dcl-s l_why varchar(200) inz('');
  dcl-s l_ctype char(1);
  dcl-s l_flen int(10);
  dcl-s l_dec int(10);
  dcl-s l_front char(80);
  dcl-s l_gen ind inz(*off);
  dcl-s l_reported ind inz(*off);

  l_rec = g_src(io_i);
  l_no = g_srcNo(io_i);

  l_name = Cols(l_rec:7:14);
  l_len = Num(Cols(l_rec:15:18));
  l_line = Num(Cols(l_rec:19:20));
  l_pos = HPos(Cols(l_rec:21:22));
  l_outS = IndSpec(Cols(l_rec:23:24));
  l_inp = (%subst(l_rec:26:1) = 'Y' or %subst(l_rec:26:1) = 'y');
  l_dt = %xlate(C_LOWER:C_UPPER:%subst(l_rec:27:1));
  l_ctype = %xlate(C_LOWER:C_UPPER:%subst(l_rec:56:1));

  // Constant data is columns 57-79; column 80 = X continues it in columns
  // 7-79 of the next record(s).
  l_data = %trimr(%subst(l_rec:57:23));
  l_cont = (%subst(l_rec:80:1) = 'X' or %subst(l_rec:80:1) = 'x');
  dow l_cont and io_i < g_srcCnt;
    io_i += 1;
    l_data = %trimr(l_data + %subst(g_src(io_i):7:73));
    l_cont = (%subst(g_src(io_i):80:1) = 'X'
              or %subst(g_src(io_i):80:1) = 'x');
  enddo;

  if l_len < 1 or l_line < 1 or l_pos < 1;
    RptItem(C_STS_REVIEW:l_no:%trimr(l_rec)
            :'Field length, line or column is missing or not valid');
    return;
  endif;
  if l_outS = '?';
    RptItem(C_STS_REVIEW:l_no:%trimr(l_rec)
            :'Output data entry is not Y, N or an indicator');
    return;
  endif;
  l_ind = IndOf(l_outS);
  g_kwCnt = 0;

  // ----- constant text: neither an output field nor an input field -----
  if l_outS = 'N' and not l_inp;
    if %len(l_data) = 0;
      RptItem(C_STS_ASSUMPTION:l_no:%trimr(l_rec)
              :'Field has no constant text and no data; skipped');
      return;
    endif;
    l_front = Rec('':*off:' ':'':0:' ':-1:' ':l_line:l_pos:'');
    AddLiteral(l_front:'':l_data:'');
    l_attrInd = CollectAttrs(l_rec:*off);
    if g_override and l_attrInd;
      KwAdd('':'OVRATR');
    endif;
    KwFlush();
    RptItem(C_STS_CONVERTED:l_no:%trimr(l_rec):'');
    return;
  endif;

  // ----- named field -----
  l_numeric = (l_dt = 'S' or l_dt = 'N' or l_dt = 'D');
  l_ddt = 'A';
  if l_inp;
    l_ddt = DdsType(l_dt);
  endif;
  l_flen = l_len;
  l_dec = -1;
  if l_ddt = 'S';
    l_flen = l_len - 1;
    l_dec = 0;
    if l_flen < 1;
      RptItem(C_STS_REVIEW:l_no:%trimr(l_rec)
              :'Signed numeric field needs a length of at least 2');
      return;
    endif;
  endif;

  if l_inp and l_outS <> 'N';
    l_use = 'B';
  elseif l_inp;
    l_use = 'I';
  else;
    l_use = 'O';
  endif;

  if not (ValidDdsName(l_name) and not NameUsed(l_name));
    g_fldGen += 1;
    l_name = 'FLD' + %trim(%char(g_fldGen));
    dow NameUsed(l_name);
      g_fldGen += 1;
      l_name = 'FLD' + %trim(%char(g_fldGen));
    enddo;
    l_gen = *on;
  endif;
  RememberName(l_name);
  if l_gen;
    l_status = C_STS_ASSUMPTION;
    l_why = 'Field name missing, duplicate or invalid in DDS; '
            + l_name + ' generated (fields are positional on S/36)';
  endif;
  if l_ctype = 'M';
    l_status = C_STS_REVIEW;
    l_why = 'Message (MIC) field: kept as a program output field';
  endif;
  if l_use = 'B' and %subst(l_outS:1:1) = 'I';
    l_status = C_STS_REVIEW;
    l_why = 'Output indicator on an input/output field: written as a plain'
            + ' input/output field';
  endif;
  if l_use = 'I' and %len(l_data) > 0;
    if l_status = C_STS_CONVERTED;
      l_status = C_STS_ASSUMPTION;
      l_why = 'Constant data on an input-only field is not used';
    endif;
  endif;

  // The field record. A pure output field with an output indicator is
  // shown only while the indicator is on; the constant text (if any) is
  // shown while it is off.
  if l_use = 'O' and %subst(l_outS:1:1) = 'I';
    AddOut(Rec(l_ind:*off:' ':l_name:l_flen:l_ddt:l_dec:l_use:l_line:l_pos
               :''));
  else;
    AddOut(Rec('':*off:' ':l_name:l_flen:l_ddt:l_dec:l_use:l_line:l_pos:''));
  endif;

  if l_use = 'O' and %len(l_data) > 0 and l_outS = 'Y';
    AddLiteral(Rec('':*off:' ':'':0:' ':-1:' ':0:0:''):'DFT(':l_data:')');
  endif;

  l_attrInd = CollectAttrs(l_rec:l_inp);
  if l_inp;
    CollectInput(l_rec:l_numeric);
  endif;
  if g_override;
    if l_attrInd;
      KwAdd('':'OVRATR');
    endif;
    if %subst(l_outS:1:1) = 'I';
      KwAdd(l_ind:'OVRDTA');
    endif;
  endif;
  KwFlush();

  // constant shown while the output indicator is off
  if l_use = 'O' and %subst(l_outS:1:1) = 'I' and %len(l_data) > 0;
    l_front = Rec(l_ind:*on:' ':'':0:' ':-1:' ':l_line:l_pos:'');
    AddLiteral(l_front:'':l_data:'');
    l_attrInd = CollectAttrs(l_rec:*off);
    KwFlush();
  endif;

  RptItem(l_status:l_no:%trimr(l_rec):l_why);
end-proc;

// ------------------------------------------------------------------
// The first S specification decides the file-level keywords.
dcl-proc FileHeader;
  dcl-s l_i int(10);
  dcl-s l_132 ind inz(*off);
  dcl-s l_rtl ind inz(*off);
  dcl-s l_first ind inz(*on);

  for l_i = 1 to g_srcCnt;
    if %subst(g_src(l_i):6:1) = 'S' and %subst(g_src(l_i):7:1) <> '*';
      if %subst(g_src(l_i):39:1) = 'Y' or %subst(g_src(l_i):39:1) = 'y';
        l_132 = *on;
      endif;
      if l_first and (%subst(g_src(l_i):40:1) = 'Y'
                      or %subst(g_src(l_i):40:1) = 'y');
        l_rtl = *on;
      endif;
      l_first = *off;
    endif;
  endfor;

  if l_132;
    AddKw('':'DSPSIZ(24 80 *DS3 27 132 *DS4)');
  else;
    AddKw('':'DSPSIZ(24 80 *DS3)');
  endif;
  AddKw('':'INDARA');
  if l_rtl;
    AddKw('':'CHECK(RLTB)');
  endif;
  RptItem(C_STS_ASSUMPTION:0:'File-level DDS'
          :'DSPSIZ and INDARA added (CHECK(RLTB) for right-to-left); '
          + 'INVITE added to every format');
end-proc;

// ------------------------------------------------------------------
dcl-proc ConvertSfgr;
  dcl-s l_i int(10);
  dcl-s l_rec char(80);
  dcl-s l_t char(1);
  dcl-s l_out char(80);

  g_fmtOpen = *off;
  g_fmtCnt = 0;
  g_override = *off;
  FileHeader();

  l_i = 1;
  dow l_i <= g_srcCnt;
    l_rec = g_src(l_i);
    l_t = %xlate(C_LOWER:C_UPPER:%subst(l_rec:6:1));
    select;
      when l_rec = *blanks;
        // blank line: nothing to convert
      when %subst(l_rec:1:4) = '*DDS' and %subst(l_rec:7:1) = '*';
        l_out = l_rec;
        %subst(l_out:6:1) = 'A';
        %subst(l_out:7:1) = ' ';
        AddOut(l_out);
        RptItem(C_STS_CONVERTED:g_srcNo(l_i):%trimr(l_rec):'');
      when %subst(l_rec:7:1) = '*';
        // comment: DDS comment, text from column 8 unchanged
        l_out = l_rec;
        %subst(l_out:1:5) = *blanks;
        %subst(l_out:6:1) = 'A';
        AddOut(l_out);
        RptItem(C_STS_CONVERTED:g_srcNo(l_i):%trimr(l_rec):'');
      when l_t = 'S';
        ConvertS(l_rec:g_srcNo(l_i));
      when l_t = 'H';
        l_out = l_rec;
        %subst(l_out:1:5) = *blanks;
        %subst(l_out:6:1) = 'A';
        %subst(l_out:7:1) = '*';
        AddOut(l_out);
        RptItem(C_STS_REVIEW:g_srcNo(l_i):%trimr(l_rec)
                :'Help definition (H) not converted; kept as a DDS comment');
      when l_t = 'D';
        if not g_fmtOpen;
          RptItem(C_STS_REVIEW:g_srcNo(l_i):%trimr(l_rec)
                  :'D specification before the first S specification');
        else;
          ConvertD(l_i);
        endif;
      other;
        l_out = l_rec;
        %subst(l_out:1:5) = *blanks;
        %subst(l_out:6:1) = 'A';
        %subst(l_out:7:1) = '*';
        AddOut(l_out);
        RptItem(C_STS_REVIEW:g_srcNo(l_i):%trimr(l_rec)
                :'Record type in column 6 is not S, H or D');
    endsl;
    l_i += 1;
  enddo;
end-proc;

// ------------------------------------------------------------------
// DSP38: System/38 display DDS is valid input to CRTDSPF as it is.
dcl-proc CopyDds38;
  dcl-s l_i int(10);

  for l_i = 1 to g_srcCnt;
    AddOut(g_src(l_i));
    RptItem(C_STS_CONVERTED:g_srcNo(l_i):%trimr(g_src(l_i)):'');
  endfor;
  RptItem(C_STS_ASSUMPTION:0:'DSP38 source'
          :'Copied unchanged; compile with CRTDSPF to confirm');
end-proc;

// ------------------------------------------------------------------
dcl-proc DspConvert export;
  dcl-pi *n int(10);
    i_src likeds(IAcnvDesc_t) const;
    i_tgt likeds(IAcnvDesc_t) const;
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  dcl-s l_text varchar(512);
  dcl-s l_no int(10);
  dcl-s l_i int(10);
  dcl-s l_lines int(10);
  dcl-s l_status char(1);
  dcl-s l_longCnt int(10) inz(0);
  dcl-s l_type varchar(10);

  g_srcCnt = 0;
  g_outCnt = 0;
  g_overflow = *off;
  g_override = *off;
  g_lowerDft = *off;
  g_kwCnt = 0;

  if OpenSource(i_src:o_msgId:o_msgData) <> 0;
    return 1;
  endif;
  dow ReadLine(l_text:l_no);
    if g_srcCnt >= C_MAXSRC;
      g_overflow = *on;
      leave;
    endif;
    g_srcCnt += 1;
    g_src(g_srcCnt) = l_text;
    g_srcNo(g_srcCnt) = l_no;
    if %len(%trimr(l_text)) > 80;
      l_longCnt += 1;
      RptItem(C_STS_REVIEW:l_no:%trimr(l_text)
              :'Record is longer than 80 columns; the part past column 80 is cut');
    endif;
  enddo;
  if ReadError(o_msgId:o_msgData);
    CloseSource();
    return 1;
  endif;
  CloseSource();
  if g_overflow;
    o_msgId = 'IAC0101';
    o_msgData = 'The source has more than ' + %char(C_MAXSRC) + ' lines';
    return 1;
  endif;

  l_type = %trim(%xlate(C_LOWER:C_UPPER:i_src.type));
  if l_type = 'DSP38';
    CopyDds38();
  else;
    ConvertSfgr();
  endif;
  if g_overflow;
    o_msgId = 'IAC0101';
    o_msgData = 'The converted DDS has more than ' + %char(C_MAXOUT) + ' lines';
    return 1;
  endif;

  if OpenTarget(i_tgt:o_msgId:o_msgData) <> 0;
    return 1;
  endif;
  for l_i = 1 to g_outCnt;
    if WriteText(g_out(l_i):C_WRAP_NONE:l_lines:l_status:o_msgId:o_msgData)
       <> 0;
      CloseTarget();
      return 1;
    endif;
  endfor;
  CloseTarget();
  return 0;
end-proc;
