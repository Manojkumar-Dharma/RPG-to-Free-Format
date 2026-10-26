**FREE
// IAfreeFx4 - RPG IV fixed-form source (RPGLE, SQLRPGLE) to fully free-form:
// H, F, D and P specifications, compiler directives and /FREE blocks. The
// column positions come from the layout table IACNVLAY (dialect 4); what a
// specification becomes follows the tables "Free-form equivalents" of SC09-2508
// (7.3), Tables 79 to 93. C specifications are converted by IAfreeCalc; I and O
// specifications are reported R. Module of program IACNVFREE.
// Target release V7R3.

ctl-opt nomain option(*srcstmt:*nodebugio);

/copy qcpysrc,IAcnvSrvP
/copy qcpysrc,IAfreeRulP
/copy qcpysrc,IAfreeCalcP
/copy qcpysrc,IAfreeFx4P

dcl-c C_LOWER 'abcdefghijklmnopqrstuvwxyz';
dcl-c C_UPPER 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
dcl-c C_DIGITS '0123456789';
dcl-c C_QUOTE '''';
dcl-c C_MAXKW 40;
dcl-c C_MAXCONST 300;
dcl-c C_LINEMAX 84;

// The keywords of the specification being converted (blank-separated words
// of the keyword field, parameters kept with their keyword).
dcl-s g_kw varchar(300) dim(C_MAXKW);
dcl-s g_kwCount int(10) inz(0);

dcl-s g_block char(2) inz('');          // DS, PR or PI that is still open
dcl-s g_blockName varchar(21) inz('');
dcl-s g_inFree ind inz(*off);           // inside /FREE ... /END-FREE
dcl-s g_lastLineNo int(10) inz(0);
dcl-s g_stack char(1) dim(60);          // open C groups: I, L, S, W, M, E, R
dcl-s g_depth int(10) inz(0);
dcl-s g_hdrIdx int(10) dim(60);         // output line and text of a DO header
dcl-s g_hdrTxt varchar(300) dim(60);
dcl-s g_klName varchar(14) dim(50);     // KLIST names and their key fields
dcl-s g_klKeys varchar(200) dim(50);
dcl-s g_klCount int(10) inz(0);
dcl-s g_klDone ind inz(*off);
dcl-c C_MAXSYM 1500;
dcl-s g_symName varchar(45) dim(C_MAXSYM);   // declared fields and their types
dcl-s g_symType varchar(60) dim(C_MAXSYM);
dcl-s g_symCount int(10) inz(0);
dcl-s g_quoted ind inz(*off);           // a name was written as a literal
dcl-s g_constName varchar(21) dim(C_MAXCONST);
dcl-s g_constCount int(10) inz(0);

// ------------------------------------------------------------------
dcl-proc Up;
  dcl-pi *n varchar(300);
    i_text varchar(300) const;
  end-pi;

  return %xlate(C_LOWER:C_UPPER:i_text);
end-proc;

// ------------------------------------------------------------------
// i_count blanks (0 to 40).
dcl-proc Pad;
  dcl-pi *n varchar(40);
    i_count int(10) const;
  end-pi;

  if i_count <= 0;
    return '';
  endif;
  return %subst('                                        ':1:%min(i_count:40));
end-proc;

// ------------------------------------------------------------------
dcl-proc Low;
  dcl-pi *n varchar(300);
    i_text varchar(300) const;
  end-pi;

  return %xlate(C_UPPER:C_LOWER:i_text);
end-proc;

// ------------------------------------------------------------------
// The trimmed text of a field of a specification.
dcl-proc Txt;
  dcl-pi *n varchar(100);
    i_spec char(1) const;
    i_field varchar(12) const;
    i_line char(100) const;
  end-pi;

  return %trim(RulText(i_spec:i_field:i_line));
end-proc;

// ------------------------------------------------------------------
dcl-proc IsDigits;
  dcl-pi *n ind;
    i_text varchar(100) const;
  end-pi;

  return %len(i_text) > 0 and %check(C_DIGITS:i_text) = 0;
end-proc;

// ------------------------------------------------------------------
dcl-proc Fx4Start export;
  dcl-pi *n;
  end-pi;

  g_block = '';
  g_blockName = '';
  g_inFree = *off;
  g_lastLineNo = 0;
  g_constCount = 0;
  g_kwCount = 0;
  g_depth = 0;
  g_klCount = 0;
  g_klDone = *off;
  g_symCount = 0;
end-proc;

// ------------------------------------------------------------------
dcl-proc Fx4Flush export;
  dcl-pi *n;
  end-pi;

  select;
    when g_block = 'DS';
      AddOut('end-ds;':g_lastLineNo);
    when g_block = 'PR';
      AddOut('end-pr;':g_lastLineNo);
    when g_block = 'PI';
      AddOut('end-pi;':g_lastLineNo);
  endsl;
  g_block = '';
  g_blockName = '';
end-proc;

// ------------------------------------------------------------------
// Splits a keyword field into words at the blanks that are outside quotes and
// parentheses.
dcl-proc SplitKeywords;
  dcl-pi *n;
    i_text varchar(1200) const;
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_depth int(10) inz(0);
  dcl-s l_inQuote ind inz(*off);
  dcl-s l_start int(10) inz(1);
  dcl-s l_char char(1);
  dcl-s l_word varchar(300);

  g_kwCount = 0;
  for l_index = 1 to %len(i_text) + 1;
    if l_index <= %len(i_text);
      l_char = %subst(i_text:l_index:1);
    else;
      l_char = ' ';
      l_depth = 0;
      l_inQuote = *off;
    endif;
    select;
      when l_char = C_QUOTE;
        l_inQuote = not l_inQuote;
      when l_inQuote;
      when l_char = '(';
        l_depth += 1;
      when l_char = ')';
        l_depth -= 1;
      when l_char = ' ' and l_depth = 0;
        if l_index > l_start;
          l_word = %trim(%subst(i_text:l_start:l_index - l_start));
          if %len(l_word) > 0 and g_kwCount < C_MAXKW;
            g_kwCount += 1;
            g_kw(g_kwCount) = l_word;
          endif;
        endif;
        l_start = l_index + 1;
    endsl;
  endfor;
end-proc;

// ------------------------------------------------------------------
// The name of keyword i in upper case, without its parameters.
dcl-proc KwName;
  dcl-pi *n varchar(60);
    i_index int(10) const;
  end-pi;

  dcl-s l_paren int(10);

  if i_index < 1 or i_index > g_kwCount or %len(g_kw(i_index)) = 0;
    return '';
  endif;
  l_paren = %scan('(':g_kw(i_index));
  if l_paren = 0;
    return Up(g_kw(i_index));
  endif;
  return Up(%subst(g_kw(i_index):1:l_paren - 1));
end-proc;

// ------------------------------------------------------------------
// The parameters of keyword i (between the first and the last parenthesis),
// or '' when it has none.
dcl-proc KwParam;
  dcl-pi *n varchar(300);
    i_index int(10) const;
  end-pi;

  dcl-s l_paren int(10);
  dcl-s l_text varchar(300);

  if i_index < 1 or i_index > g_kwCount;
    return '';
  endif;
  l_text = g_kw(i_index);
  l_paren = %scan('(':l_text);
  if l_paren = 0 or %subst(l_text:%len(l_text):1) <> ')';
    return '';
  endif;
  return %trim(%subst(l_text:l_paren + 1:%len(l_text) - l_paren - 1));
end-proc;

// ------------------------------------------------------------------
// The index of a keyword by name, or 0.
dcl-proc KwFind;
  dcl-pi *n int(10);
    i_name varchar(20) const;
  end-pi;

  dcl-s l_index int(10);

  for l_index = 1 to g_kwCount;
    if KwName(l_index) = i_name;
      return l_index;
    endif;
  endfor;
  return 0;
end-proc;

// ------------------------------------------------------------------
dcl-proc KwDrop;
  dcl-pi *n;
    i_index int(10) const;
  end-pi;

  if i_index >= 1 and i_index <= g_kwCount;
    g_kw(i_index) = '';
  endif;
end-proc;

// ------------------------------------------------------------------
dcl-proc IsConstName;
  dcl-pi *n ind;
    i_name varchar(100) const;
  end-pi;

  dcl-s l_index int(10);

  for l_index = 1 to g_constCount;
    if g_constName(l_index) = Up(i_name);
      return *on;
    endif;
  endfor;
  return *off;
end-proc;

// ------------------------------------------------------------------
// A file, format or field name in a keyword parameter becomes a character
// literal (free-form needs one); literals, special values (*ALL) and named
// constants stay as they are.
dcl-proc QuoteName;
  dcl-pi *n varchar(110);
    i_text varchar(100) const;
  end-pi;

  if %len(i_text) = 0 or %subst(i_text:1:1) = C_QUOTE
     or %subst(i_text:1:1) = '*' or IsConstName(i_text);
    return i_text;
  endif;
  g_quoted = *on;
  return C_QUOTE + Up(i_text) + C_QUOTE;
end-proc;

// ------------------------------------------------------------------
// The parameters of EXTNAME or EXTFLD, each one quoted when needed.
dcl-proc QuoteParams;
  dcl-pi *n varchar(300);
    i_text varchar(300) const;
  end-pi;

  dcl-s l_rest varchar(300);
  dcl-s l_colon int(10);
  dcl-s l_result varchar(300) inz('');
  dcl-s l_part varchar(100);

  l_rest = i_text;
  dow *on;
    l_colon = %scan(':':l_rest);
    if l_colon = 0 or %scan(C_QUOTE:l_rest) > 0 and %scan(C_QUOTE:l_rest) < l_colon;
      l_part = %trim(l_rest);
      l_rest = '';
    else;
      l_part = %trim(%subst(l_rest:1:l_colon - 1));
      l_rest = %subst(l_rest:l_colon + 1);
    endif;
    if %len(l_result) > 0;
      l_result += ' : ';
    endif;
    l_result += QuoteName(l_part);
    if l_colon = 0 or %scan(C_QUOTE:l_part) > 0 and %len(l_rest) = 0;
      leave;
    endif;
    if %len(l_rest) = 0;
      leave;
    endif;
  enddo;
  return l_result;
end-proc;

// ------------------------------------------------------------------
// Writes a statement, breaking it at blanks outside quotes so that no line is
// longer than C_LINEMAX; continuation lines are indented by four more blanks.
dcl-proc EmitStatement;
  dcl-pi *n;
    i_indent int(10) const;
    i_text varchar(1200) const;
    i_lineNo int(10) const;
  end-pi;

  dcl-s l_rest varchar(1200);
  dcl-s l_index int(10);
  dcl-s l_break int(10);
  dcl-s l_inQuote ind;
  dcl-s l_room int(10);
  dcl-s l_first ind inz(*on);

  l_rest = i_text;
  dow *on;
    l_room = C_LINEMAX - i_indent;
    if not l_first;
      l_room -= 4;
    endif;
    if %len(l_rest) <= l_room;
      leave;
    endif;
    l_break = 0;
    l_inQuote = *off;
    for l_index = 1 to %len(l_rest);
      if %subst(l_rest:l_index:1) = C_QUOTE;
        l_inQuote = not l_inQuote;
      endif;
      if %subst(l_rest:l_index:1) = ' ' and not l_inQuote;
        if l_index > l_room + 1;
          leave;
        endif;
        l_break = l_index;
      endif;
    endfor;
    if l_break < 2;
      leave;
    endif;
    if l_first;
      AddOut(Pad(i_indent)
             + %subst(l_rest:1:l_break - 1):i_lineNo);
    else;
      AddOut(Pad(i_indent + 4)
             + %subst(l_rest:1:l_break - 1):i_lineNo);
    endif;
    l_first = *off;
    l_rest = %subst(l_rest:l_break + 1);
  enddo;
  if l_first;
    AddOut(Pad(i_indent) + l_rest
           :i_lineNo);
  else;
    AddOut(Pad(i_indent + 4) + l_rest
           :i_lineNo);
  endif;
end-proc;

// ------------------------------------------------------------------
// *ON when the line is a keyword continuation line of an F or D specification:
// the form type is the same and columns 7 to 43 are blank while the keyword
// field has text.
dcl-proc IsContinuation;
  dcl-pi *n ind;
    i_spec char(1) const;
    i_line char(100) const;
  end-pi;

  if %subst(%xlate(C_LOWER:C_UPPER:i_line):6:1) <> i_spec;
    return *off;
  endif;
  if %subst(i_line:7:1) = '*' or %subst(i_line:7:1) = '/';
    return *off;
  endif;
  return Txt(i_spec:'CONTBLANK':i_line) = '' and Txt(i_spec:'KEYWORDS':i_line) <> '';
end-proc;

// ------------------------------------------------------------------
// Takes the keyword field of a specification and of its continuation lines:
// o_extra is the number of continuation lines. *OFF when a keyword literal is
// continued with + or - (not converted, the caller reports it).
dcl-proc CollectKeywords;
  dcl-pi *n ind;
    i_spec char(1) const;
    i_index int(10) const;
    i_line char(100) const;
    o_text varchar(1200);
    o_extra int(10);
  end-pi;

  dcl-s l_next int(10);
  dcl-s l_more varchar(100);
  dcl-s l_last char(1);
  dcl-s l_ok ind inz(*on);

  o_text = Txt(i_spec:'KEYWORDS':i_line);
  o_extra = 0;
  l_next = i_index + 1;
  dow l_next <= SrcCount() and IsContinuation(i_spec:SrcLine(l_next));
    if %len(o_text) > 0;
      l_last = %subst(o_text:%len(o_text):1);
      if l_last = '+' or l_last = '-';
        l_ok = *off;
      endif;
    endif;
    l_more = Txt(i_spec:'KEYWORDS':SrcLine(l_next));
    o_text += ' ' + l_more;
    o_extra += 1;
    l_next += 1;
  enddo;
  if %len(o_text) > 0;
    l_last = %subst(o_text:%len(o_text):1);
    if o_extra > 0 and (l_last = '+' or l_last = '-');
      l_ok = *off;
    endif;
  endif;
  return l_ok;
end-proc;

// ------------------------------------------------------------------
// Reports a specification and its continuation lines as not converted.
dcl-proc ReviewWithContinuations;
  dcl-pi *n;
    i_index int(10) const;
    i_lineNo int(10) const;
    i_line char(100) const;
    i_extra int(10) const;
    i_reason varchar(190) const;
  end-pi;

  dcl-s l_k int(10);

  ReviewSpec(i_lineNo:i_line:i_reason);
  for l_k = 1 to i_extra;
    ReviewSpec(SrcLineNo(i_index + l_k):SrcLine(i_index + l_k)
               :'Continuation of the specification above');
  endfor;
end-proc;

// ------------------------------------------------------------------
// Reports a converted specification and its continuation lines.
dcl-proc ReportWithContinuations;
  dcl-pi *n;
    i_index int(10) const;
    i_lineNo int(10) const;
    i_line char(100) const;
    i_extra int(10) const;
    i_note varchar(190) const;
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_status char(1);

  if i_note = '';
    l_status = C_STS_CONVERTED;
  else;
    l_status = C_STS_ASSUMPTION;
  endif;
  RptItem(l_status:i_lineNo:%trimr(%subst(i_line:6:75)):i_note);
  for l_k = 1 to i_extra;
    RptItem(C_STS_CONVERTED:SrcLineNo(i_index + l_k)
            :%trimr(%subst(SrcLine(i_index + l_k):6:75)):'');
  endfor;
end-proc;

// ------------------------------------------------------------------
dcl-proc AddConstName;
  dcl-pi *n;
    i_name varchar(21) const;
  end-pi;

  if g_constCount < C_MAXCONST;
    g_constCount += 1;
    g_constName(g_constCount) = Up(i_name);
  endif;
end-proc;

// ------------------------------------------------------------------
// H: control specification. The keywords of consecutive H lines become one
// CTL-OPT statement. Returns the number of H lines that followed and were used.
dcl-proc ConvertH;
  dcl-pi *n int(10);
    i_index int(10) const;
    i_lineNo int(10) const;
    i_line char(100) const;
  end-pi;

  dcl-s l_text varchar(1200);
  dcl-s l_next int(10);
  dcl-s l_extra int(10) inz(0);

  l_text = Txt('H':'KEYWORDS':i_line);
  l_next = i_index + 1;
  dow l_next <= SrcCount()
      and %subst(%xlate(C_LOWER:C_UPPER:SrcLine(l_next)):6:1) = 'H'
      and %subst(SrcLine(l_next):7:1) <> '*';
    l_text += ' ' + Txt('H':'KEYWORDS':SrcLine(l_next));
    l_extra += 1;
    l_next += 1;
  enddo;
  l_text = %trim(l_text);

  if %len(l_text) > 0;
    if %subst(l_text:%len(l_text):1) = '+' or %subst(l_text:%len(l_text):1) = '-';
      ReviewWithContinuations(i_index:i_lineNo:i_line:l_extra
                              :'A literal continued with + or - is not converted');
      return l_extra;
    endif;
    EmitStatement(0:'ctl-opt ' + l_text + ';':i_lineNo);
  endif;
  g_lastLineNo = i_lineNo;
  ReportWithContinuations(i_index:i_lineNo:i_line:l_extra:'');
  return l_extra;
end-proc;

// ------------------------------------------------------------------
// F: file description specification (Tables 79 and 80) to DCL-F.
dcl-proc ConvertF;
  dcl-pi *n int(10);
    i_index int(10) const;
    i_lineNo int(10) const;
    i_line char(100) const;
  end-pi;

  dcl-s l_kwText varchar(1200);
  dcl-s l_extra int(10);
  dcl-s l_name varchar(10);
  dcl-s l_type varchar(1);
  dcl-s l_desig varchar(1);
  dcl-s l_eof varchar(1);
  dcl-s l_add varchar(1);
  dcl-s l_seq varchar(1);
  dcl-s l_fmt varchar(1);
  dcl-s l_recLen varchar(5);
  dcl-s l_limits varchar(1);
  dcl-s l_keyLen varchar(5);
  dcl-s l_addrType varchar(1);
  dcl-s l_org varchar(1);
  dcl-s l_device varchar(7);
  dcl-s l_deviceText varchar(30);
  dcl-s l_usage varchar(40);
  dcl-s l_keyed varchar(30) inz('');
  dcl-s l_stmt varchar(1200);
  dcl-s l_note varchar(190) inz('');
  dcl-s l_reason varchar(190) inz('');
  dcl-s l_isLike ind;
  dcl-s l_index int(10);

  if not CollectKeywords('F':i_index:i_line:l_kwText:l_extra);
    ReviewWithContinuations(i_index:i_lineNo:i_line:l_extra
                            :'A literal continued with + or - is not converted');
    return l_extra;
  endif;
  SplitKeywords(l_kwText);
  g_quoted = *off;

  l_name = Txt('F':'NAME':i_line);
  l_type = Up(Txt('F':'TYPE':i_line));
  l_desig = Up(Txt('F':'DESIG':i_line));
  l_eof = Up(Txt('F':'EOF':i_line));
  l_add = Up(Txt('F':'ADD':i_line));
  l_seq = Up(Txt('F':'SEQ':i_line));
  l_fmt = Up(Txt('F':'FORMAT':i_line));
  l_recLen = Txt('F':'RECLEN':i_line);
  l_limits = Up(Txt('F':'LIMITS':i_line));
  l_keyLen = Txt('F':'KEYLEN':i_line);
  l_addrType = Up(Txt('F':'ADDRTYPE':i_line));
  l_org = Up(Txt('F':'ORG':i_line));
  l_device = Up(Txt('F':'DEVICE':i_line));
  l_isLike = KwFind('LIKEFILE') > 0;

  select;
    when l_name = '' or %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_$#@':Up(l_name))
         > 0;
      l_reason = 'File name (columns 7-16) is not valid';
    when l_isLike;
      if l_type <> '' or l_desig <> '' or l_eof <> '' or l_add <> '' or l_seq <> ''
         or l_fmt <> '' or l_recLen <> '' or l_limits <> '' or l_keyLen <> ''
         or l_addrType <> '' or l_org <> '' or l_device <> '';
        l_reason = 'Entries from column 17 to 42 must be blank with LIKEFILE';
      endif;
    when l_type <> 'I' and l_type <> 'O' and l_type <> 'U' and l_type <> 'C';
      l_reason = 'File type (column 17) must be I, O, U or C';
    when l_desig = 'P' or l_desig = 'S' or l_desig = 'T' or l_desig = 'R';
      l_reason = 'Primary, secondary, table and record address files (the RPG '
                 + 'cycle) are not supported in free-form';
    when l_desig <> '' and l_desig <> 'F';
      l_reason = 'File designation (column 18) ' + l_desig + ' is not valid';
    when l_desig = '' and l_type <> 'O';
      l_reason = 'An input, update or combined file needs designation F';
    when l_desig <> '' and l_type = 'O';
      l_reason = 'An output file must have a blank file designation';
    when l_seq <> '';
      l_reason = 'Sequence (column 21) is not supported in free-form';
    when l_limits = 'L';
      l_reason = 'Limits processing (column 28) is not supported in free-form';
    when l_add <> '' and l_add <> 'A';
      l_reason = 'File addition (column 20) must be blank or A';
    when l_type = 'O' and l_add = 'A';
      l_reason = 'Output with file addition is not supported in free-form';
    when l_type = 'C' and l_add <> '';
      l_reason = 'File addition is not valid for a combined file';
    when l_fmt <> 'E' and l_fmt <> 'F';
      l_reason = 'File format (column 22) must be E or F';
    when l_device <> 'DISK' and l_device <> 'PRINTER' and l_device <> 'WORKSTN'
         and l_device <> 'SEQ' and l_device <> 'SPECIAL';
      l_reason = 'Device (columns 36-42) ' + l_device + ' is not valid';
    when l_fmt = 'F' and not IsDigits(l_recLen);
      l_reason = 'Record length (columns 23-27) is missing';
    when l_fmt = 'E' and l_recLen <> '';
      l_reason = 'Record length must be blank for an externally described file';
    when l_org = 'T';
      l_reason = 'Address output file organization (T) is not supported';
    when l_addrType <> '' and l_addrType <> 'A' and l_addrType <> 'K';
      l_reason = 'Record address type (column 34) ' + l_addrType
                 + ' is not supported in free-form';
    when l_addrType = 'K' and l_fmt <> 'E';
      l_reason = 'Record address type K is for externally described files';
    when l_addrType = 'A' and (l_fmt <> 'F' or not IsDigits(l_keyLen));
      l_reason = 'Record address type A needs a program described file and a key '
                 + 'length (columns 29-33)';
    when l_addrType = '' and (l_keyLen <> '' or l_org <> '');
      l_reason = 'Key length or organization without a record address type';
  endsl;
  if l_reason <> '';
    ReviewWithContinuations(i_index:i_lineNo:i_line:l_extra:l_reason);
    return l_extra;
  endif;

  if not l_isLike;
    select;
      when l_type = 'I' and l_add = 'A';
        l_usage = '*input : *output';
      when l_type = 'I';
        l_usage = '*input';
      when l_type = 'U' and l_add = 'A';
        l_usage = '*update : *delete : *output';
      when l_type = 'U';
        l_usage = '*update : *delete';
      when l_type = 'C';
        l_usage = '*input : *output';
      other;
        l_usage = '*output';
    endsl;
    if l_fmt = 'E';
      l_deviceText = Low(l_device);
    else;
      l_deviceText = Low(l_device) + '(' + %char(%int(l_recLen)) + ')';
    endif;
    if l_addrType <> '';
      if l_addrType = 'K';
        l_keyed = 'keyed';
      else;
        l_keyed = 'keyed(*char : ' + %char(%int(l_keyLen)) + ')';
      endif;
    endif;
    if l_eof = 'E';
      l_note = 'end of file entry (column 19) ignored: it only matters for the '
               + 'RPG cycle';
    endif;
    l_stmt = 'dcl-f ' + l_name + ' ' + l_deviceText + ' usage(' + l_usage + ')';
    if l_keyed <> '';
      l_stmt += ' ' + l_keyed;
    endif;
  else;
    l_stmt = 'dcl-f ' + l_name;
  endif;

  // Keywords: EXTFILE and the like are kept; the external names of EXTDESC,
  // EXTFILE and EXTMBR may be names in fixed-form, a literal is needed.
  for l_index = 1 to g_kwCount;
    if %len(g_kw(l_index)) = 0;
      iter;
    endif;
    l_stmt += ' ' + g_kw(l_index);
  endfor;
  l_stmt += ';';

  EmitStatement(0:l_stmt:i_lineNo);
  g_lastLineNo = i_lineNo;
  ReportWithContinuations(i_index:i_lineNo:i_line:l_extra:l_note);
  return l_extra;
end-proc;

// ------------------------------------------------------------------
// P: procedure specification. B starts DCL-PROC, E ends it.
dcl-proc ConvertP;
  dcl-pi *n int(10);
    i_index int(10) const;
    i_lineNo int(10) const;
    i_line char(100) const;
  end-pi;

  dcl-s l_kwText varchar(1200);
  dcl-s l_extra int(10);
  dcl-s l_name varchar(21);
  dcl-s l_be varchar(1);
  dcl-s l_stmt varchar(1200);
  dcl-s l_index int(10);

  Fx4Flush();
  if not CollectKeywords('P':i_index:i_line:l_kwText:l_extra);
    ReviewWithContinuations(i_index:i_lineNo:i_line:l_extra
                            :'A literal continued with + or - is not converted');
    return l_extra;
  endif;
  SplitKeywords(l_kwText);
  l_name = Txt('P':'NAME':i_line);
  l_be = Up(Txt('P':'BEGEND':i_line));

  select;
    when l_be = 'B';
      if l_name = '' or %subst(l_name:%len(l_name):1) = '.';
        ReviewWithContinuations(i_index:i_lineNo:i_line:l_extra
                                :'Procedure name is missing or continued');
        return l_extra;
      endif;
      l_stmt = 'dcl-proc ' + l_name;
      for l_index = 1 to g_kwCount;
        if %len(g_kw(l_index)) > 0;
          l_stmt += ' ' + g_kw(l_index);
        endif;
      endfor;
      l_stmt += ';';
    when l_be = 'E';
      l_stmt = 'end-proc;';
    other;
      ReviewWithContinuations(i_index:i_lineNo:i_line:l_extra
                              :'Begin/end entry (column 24) must be B or E');
      return l_extra;
  endsl;
  EmitStatement(0:l_stmt:i_lineNo);
  g_lastLineNo = i_lineNo;
  ReportWithContinuations(i_index:i_lineNo:i_line:l_extra:'');
  return l_extra;
end-proc;

// ------------------------------------------------------------------
// The size of a field in the free-form data type keyword: bytes (from-to
// positions) become digits for the numeric types. Returns -1 when the number of
// bytes is not valid for the type.
dcl-proc TypeSize;
  dcl-pi *n int(10);
    i_dtype char(1) const;
    i_size int(10) const;
    i_bytes ind const;
  end-pi;

  if not i_bytes;
    return i_size;
  endif;
  select;
    when i_dtype = 'P';
      return 2 * i_size - 1;
    when i_dtype = 'B';
      if i_size = 2;
        return 4;
      elseif i_size = 4;
        return 9;
      endif;
      return -1;
    when i_dtype = 'I' or i_dtype = 'U';
      if i_size = 1;
        return 3;
      elseif i_size = 2;
        return 5;
      elseif i_size = 4;
        return 10;
      elseif i_size = 8;
        return 20;
      endif;
      return -1;
    when i_dtype = 'G' or i_dtype = 'C';
      return i_size / 2;
  endsl;
  return i_size;
end-proc;

// ------------------------------------------------------------------
// The free-form data type keyword of a definition (Table 87). The keywords
// VARYING, DATFMT, TIMFMT and PROCPTR are used here and dropped from the
// keyword list. o_reason is set when the definition cannot be converted.
dcl-proc BuildType;
  dcl-pi *n varchar(60);
    i_dtype char(1) const;
    i_len varchar(10) const;
    i_dec varchar(5) const;
    i_bytes ind const;
    i_isSub ind const;
    o_reason varchar(150);
  end-pi;

  dcl-s l_dtype char(1);
  dcl-s l_size int(10) inz(0);
  dcl-s l_hasSize ind inz(*off);
  dcl-s l_dec varchar(5);
  dcl-s l_vary int(10);
  dcl-s l_prefix varchar(5) inz('');
  dcl-s l_fmt int(10);
  dcl-s l_text varchar(60) inz('');

  o_reason = '';
  l_dtype = i_dtype;
  l_dec = i_dec;
  if i_len <> '';
    if not IsDigits(i_len);
      o_reason = 'Length ' + i_len + ' is not a number';
      return '';
    endif;
    l_size = TypeSize(l_dtype:%int(i_len):i_bytes);
    l_hasSize = *on;
    if l_size < 0;
      o_reason = 'The from-to length does not fit data type ' + l_dtype;
      return '';
    endif;
  endif;
  if l_dec <> '' and not IsDigits(l_dec);
    o_reason = 'Decimal positions ' + l_dec + ' are not a number';
    return '';
  endif;

  // A blank data type: character, or numeric when decimal positions are given.
  if l_dtype = ' ';
    if l_dec = '';
      l_dtype = 'A';
    elseif i_isSub;
      l_dtype = 'S';
    else;
      l_dtype = 'P';
    endif;
  endif;

  select;
    when l_dtype = 'A' or l_dtype = 'G' or l_dtype = 'C';
      if not l_hasSize;
        o_reason = 'Length is missing';
        return '';
      endif;
      l_vary = KwFind('VARYING');
      if l_vary > 0;
        l_prefix = KwParam(l_vary);
        KwDrop(l_vary);
        if l_dtype = 'A';
          l_text = 'varchar(' + %char(l_size);
        elseif l_dtype = 'G';
          l_text = 'vargraph(' + %char(l_size);
        else;
          l_text = 'varucs2(' + %char(l_size);
        endif;
        if l_prefix <> '';
          l_text += ' : ' + l_prefix;
        endif;
        l_text += ')';
      else;
        if l_dtype = 'A';
          l_text = 'char(' + %char(l_size) + ')';
        elseif l_dtype = 'G';
          l_text = 'graph(' + %char(l_size) + ')';
        else;
          l_text = 'ucs2(' + %char(l_size) + ')';
        endif;
      endif;
    when l_dtype = 'B' or l_dtype = 'P' or l_dtype = 'S';
      if not l_hasSize or l_dec = '';
        o_reason = 'Length and decimal positions are needed for data type '
                   + l_dtype;
        return '';
      endif;
      if l_dtype = 'B';
        l_text = 'bindec(';
      elseif l_dtype = 'P';
        l_text = 'packed(';
      else;
        l_text = 'zoned(';
      endif;
      l_text += %char(l_size) + ' : ' + %char(%int(l_dec)) + ')';
    when l_dtype = 'I' or l_dtype = 'U';
      if not l_hasSize or (l_dec <> '' and %int(l_dec) <> 0);
        o_reason = 'An integer needs a length and no decimal positions';
        return '';
      endif;
      if l_dtype = 'I';
        l_text = 'int(' + %char(l_size) + ')';
      else;
        l_text = 'uns(' + %char(l_size) + ')';
      endif;
    when l_dtype = 'F';
      if not l_hasSize;
        o_reason = 'Length is missing for a float field';
        return '';
      endif;
      l_text = 'float(' + %char(l_size) + ')';
    when l_dtype = 'N';
      l_text = 'ind';
    when l_dtype = 'D';
      l_fmt = KwFind('DATFMT');
      if l_fmt > 0;
        l_text = 'date(' + KwParam(l_fmt) + ')';
        KwDrop(l_fmt);
      else;
        l_text = 'date';
      endif;
    when l_dtype = 'T';
      l_fmt = KwFind('TIMFMT');
      if l_fmt > 0;
        l_text = 'time(' + KwParam(l_fmt) + ')';
        KwDrop(l_fmt);
      else;
        l_text = 'time';
      endif;
    when l_dtype = 'Z';
      if l_dec <> '';
        l_text = 'timestamp(' + %char(%int(l_dec)) + ')';
      else;
        l_text = 'timestamp';
      endif;
    when l_dtype = '*';
      l_fmt = KwFind('PROCPTR');
      if l_fmt > 0;
        l_text = 'pointer(*proc)';
        KwDrop(l_fmt);
      else;
        l_text = 'pointer';
      endif;
    other;
      o_reason = 'Data type ' + l_dtype + ' (object) is not converted';
      return '';
  endsl;
  return l_text;
end-proc;

// ------------------------------------------------------------------
// D: definition specification (Tables 87 to 93) to DCL-S, DCL-C, DCL-DS,
// DCL-SUBF, DCL-PR, DCL-PI and DCL-PARM. The END-DS, END-PR and END-PI of a block
// are written by Fx4Flush when the block ends.
dcl-proc ConvertD;
  dcl-pi *n int(10);
    i_index int(10) const;
    i_lineNo int(10) const;
    i_line char(100) const;
  end-pi;

  dcl-s l_kwText varchar(1200);
  dcl-s l_extra int(10);
  dcl-s l_name varchar(21);
  dcl-s l_ext varchar(1);
  dcl-s l_dsType varchar(1);
  dcl-s l_defType varchar(2);
  dcl-s l_from varchar(7);
  dcl-s l_to varchar(7);
  dcl-s l_dtype char(1);
  dcl-s l_dec varchar(2);
  dcl-s l_comment varchar(20);
  dcl-s l_head varchar(10);
  dcl-s l_nameOut varchar(25);
  dcl-s l_typeText varchar(60) inz('');
  dcl-s l_first varchar(300) inz('');
  dcl-s l_stmt varchar(1200);
  dcl-s l_reason varchar(190) inz('');
  dcl-s l_note varchar(190) inz('');
  dcl-s l_isLike ind;
  dcl-s l_isSub ind inz(*off);
  dcl-s l_opensBlock ind inz(*off);
  dcl-s l_closesNow ind inz(*off);
  dcl-s l_bytes ind inz(*off);
  dcl-s l_lenText varchar(10);
  dcl-s l_special varchar(10) inz('');
  dcl-s l_pos varchar(10) inz('');
  dcl-s l_index int(10);
  dcl-s l_k int(10);
  dcl-s l_param varchar(300);
  dcl-s l_colon int(10);
  dcl-s l_indent int(10) inz(0);
  dcl-s l_fromNum int(10);
  dcl-s l_toNum int(10);
  dcl-s l_value varchar(300);

  if not CollectKeywords('D':i_index:i_line:l_kwText:l_extra);
    ReviewWithContinuations(i_index:i_lineNo:i_line:l_extra
                            :'A literal continued with + or - is not converted');
    return l_extra;
  endif;
  SplitKeywords(l_kwText);
  g_quoted = *off;

  l_name = Txt('D':'NAME':i_line);
  l_ext = Up(Txt('D':'EXT':i_line));
  l_dsType = Up(Txt('D':'DSTYPE':i_line));
  l_defType = Up(Txt('D':'DEFTYPE':i_line));
  l_from = Txt('D':'FROM':i_line);
  l_to = Txt('D':'TO':i_line);
  l_dtype = %subst(Up(Txt('D':'DTYPE':i_line) + ' '):1:1);
  l_dec = Txt('D':'DEC':i_line);
  l_comment = Txt('D':'COMMENT':i_line);
  l_isLike = KwFind('LIKE') > 0 or KwFind('LIKEDS') > 0 or KwFind('LIKEREC') > 0;

  // ---- what the line is ----
  select;
    when %len(l_name) > 3 and %subst(l_name:%len(l_name) - 2:3) = '...';
      l_reason = 'A name continued over several lines is not converted';
    when l_name = '' and l_ext = '' and l_dsType = '' and l_defType = ''
         and l_from = '' and l_to = '' and l_dtype = ' ' and l_dec = ''
         and g_block = '';
      l_reason = 'Keyword continuation line without a definition';
    when l_defType <> '' and l_defType <> 'C' and l_defType <> 'S'
         and l_defType <> 'DS' and l_defType <> 'PR' and l_defType <> 'PI';
      l_reason = 'Definition type (columns 24-25) ' + l_defType + ' is not valid';
    when l_defType = '' and g_block = '';
      l_reason = 'Subfield or parameter without a data structure, prototype or '
                 + 'procedure interface';
    when (l_defType = 'S' or l_defType = 'C') and l_name = '';
      l_reason = 'A standalone field or constant needs a name';
  endsl;
  if l_reason <> '';
    if g_block <> '' and l_defType <> '';
      Fx4Flush();
    endif;
    ReviewWithContinuations(i_index:i_lineNo:i_line:l_extra:l_reason);
    return l_extra;
  endif;

  // ---- named constant ----
  if l_defType = 'C';
    Fx4Flush();
    l_k = KwFind('CONST');
    if l_k > 0;
      l_value = KwParam(l_k);
    elseif g_kwCount = 1;
      l_value = g_kw(1);
    else;
      l_value = '';
    endif;
    if l_value = '';
      ReviewWithContinuations(i_index:i_lineNo:i_line:l_extra
                              :'The value of the constant is not clear');
      return l_extra;
    endif;
    AddConstName(l_name);
    EmitStatement(0:'dcl-c ' + l_name + ' ' + l_value + ';':i_lineNo);
    g_lastLineNo = i_lineNo;
    ReportWithContinuations(i_index:i_lineNo:i_line:l_extra:'');
    return l_extra;
  endif;

  // ---- statement head ----
  select;
    when l_defType = 'S';
      Fx4Flush();
      l_head = 'dcl-s';
    when l_defType = 'DS';
      Fx4Flush();
      l_head = 'dcl-ds';
      l_opensBlock = *on;
    when l_defType = 'PR';
      Fx4Flush();
      l_head = 'dcl-pr';
      l_opensBlock = *on;
    when l_defType = 'PI';
      Fx4Flush();
      l_head = 'dcl-pi';
      l_opensBlock = *on;
    when g_block = 'DS';
      l_head = 'dcl-subf';
      l_isSub = *on;
      l_indent = 2;
    other;
      l_head = 'dcl-parm';
      l_indent = 2;
  endsl;

  if l_name = '';
    l_nameOut = '*n';
  else;
    l_nameOut = l_name;
  endif;

  // ---- length and position ----
  l_lenText = l_to;
  l_fromNum = 0;
  if l_from <> '';
    if %subst(l_from:1:1) = '*' or %subst(l_to:1:1) = '*';
      // *STATUS, *PROC and the like replace the data type keyword.
      if %subst(l_from:1:1) = '*';
        l_special = Low(l_from);
      else;
        l_special = Low(l_to);
      endif;
      l_lenText = '';
    elseif IsDigits(l_from) and IsDigits(l_to);
      l_fromNum = %int(l_from);
      l_toNum = %int(l_to);
      if l_toNum < l_fromNum;
        ReviewWithContinuations(i_index:i_lineNo:i_line:l_extra
                                :'The to position is before the from position');
        return l_extra;
      endif;
      l_lenText = %char(l_toNum - l_fromNum + 1);
      l_bytes = *on;
      l_pos = %char(l_fromNum);
    elseif IsDigits(l_from) and l_to = '';
      l_fromNum = %int(l_from);
      l_pos = %char(l_fromNum);
      l_lenText = '';
    else;
      ReviewWithContinuations(i_index:i_lineNo:i_line:l_extra
                              :'From and to positions are not valid');
      return l_extra;
    endif;
  endif;

  // ---- data type ----
  select;
    when l_special <> '';
      l_typeText = l_special;
    when l_defType = 'DS';
      if l_dtype <> ' ';
        ReviewWithContinuations(i_index:i_lineNo:i_line:l_extra
                                :'A data type is not valid on a data structure');
        return l_extra;
      endif;
    when l_isLike;
      if l_dtype <> ' ' or l_lenText <> '' or l_dec <> '';
        ReviewWithContinuations(i_index:i_lineNo:i_line:l_extra
                                :'Length, data type and decimals must be blank '
                                 + 'with LIKE, LIKEDS or LIKEREC');
        return l_extra;
      endif;
    when l_ext = 'E' and l_lenText = '' and l_dtype = ' ' and l_dec = '';
      // An externally described subfield: the data type comes from the file.
    when l_lenText = '' and l_dtype = ' ' and l_dec = ''
         and (l_defType = 'PR' or l_defType = 'PI');
      // A prototype or procedure interface that returns nothing.
    when l_lenText = '' and l_dtype = ' ' and l_dec = '' and l_defType = '' and
         l_name = '' and not l_isSub;
      // A parameter of a prototype without name and type: not valid.
      l_reason = 'A parameter needs a data type';
    other;
      l_typeText = BuildType(l_dtype:l_lenText:l_dec:l_bytes:l_isSub:l_reason);
  endsl;
  if l_reason <> '';
    ReviewWithContinuations(i_index:i_lineNo:i_line:l_extra:l_reason);
    if l_opensBlock;
      g_block = '';
    endif;
    return l_extra;
  endif;

  // ---- keywords that change ----
  for l_index = 1 to g_kwCount;
    select;
      when KwName(l_index) = 'PACKEVEN' or KwName(l_index) = 'CLASS'
           or KwName(l_index) = 'FROMFILE' or KwName(l_index) = 'TOFILE'
           or KwName(l_index) = 'VARYING' or KwName(l_index) = 'DATFMT'
           or KwName(l_index) = 'TIMFMT' or KwName(l_index) = 'PROCPTR';
        l_reason = 'Keyword ' + KwName(l_index) + ' is not valid here or has no '
                   + 'free-form form';
      when KwName(l_index) = 'OVERLAY';
        l_param = KwParam(l_index);
        l_colon = %scan(':':l_param);
        if l_colon = 0;
          if Up(%trim(l_param)) = Up(g_blockName);
            g_kw(l_index) = 'pos(1)';
          endif;
        elseif Up(%trim(%subst(l_param:1:l_colon - 1))) = Up(g_blockName);
          g_kw(l_index) = 'pos(' + %trim(%subst(l_param:l_colon + 1)) + ')';
        endif;
      when KwName(l_index) = 'EXTNAME';
        g_kw(l_index) = 'extname(' + QuoteParams(KwParam(l_index)) + ')';
      when KwName(l_index) = 'EXTFLD';
        if KwParam(l_index) <> '';
          g_kw(l_index) = 'extfld(' + QuoteParams(KwParam(l_index)) + ')';
        endif;
    endsl;
    if l_reason <> '';
      leave;
    endif;
  endfor;
  if l_reason <> '';
    ReviewWithContinuations(i_index:i_lineNo:i_line:l_extra:l_reason);
    if l_opensBlock;
      g_block = '';
    endif;
    return l_extra;
  endif;

  // ---- keywords that come first ----
  if l_defType = 'DS' and l_ext = 'E';
    l_k = KwFind('EXTNAME');
    if l_k > 0;
      l_first = g_kw(l_k);
      KwDrop(l_k);
    else;
      l_first = 'ext';
    endif;
  endif;
  if l_isSub and l_ext = 'E';
    l_k = KwFind('EXTFLD');
    if l_k > 0;
      l_first = g_kw(l_k);
      KwDrop(l_k);
    else;
      l_first = 'extfld';
    endif;
  endif;

  // ---- the data structure type, length and position ----
  l_stmt = l_head + ' ' + l_nameOut;
  if l_typeText <> '';
    l_stmt += ' ' + l_typeText;
  endif;
  if l_first <> '';
    l_stmt += ' ' + l_first;
  endif;
  if l_defType = 'DS';
    if l_dsType = 'S';
      l_stmt += ' psds';
    elseif l_dsType = 'U';
      l_k = KwFind('DTAARA');
      if l_k > 0;
        g_kw(l_k) = 'dtaara(*auto : ' + KwParam(l_k) + ')';
      else;
        l_stmt += ' dtaara(*auto)';
      endif;
    elseif l_dsType <> '';
      ReviewWithContinuations(i_index:i_lineNo:i_line:l_extra
                              :'Data structure type (column 23) ' + l_dsType
                              + ' is not valid');
      g_block = '';
      return l_extra;
    endif;
    if l_lenText <> '' and KwFind('LEN') = 0;
      l_stmt += ' len(' + l_lenText + ')';
    endif;
  endif;
  if l_isSub and l_pos <> '' and KwFind('OVERLAY') = 0 and KwFind('POS') = 0;
    l_stmt += ' pos(' + l_pos + ')';
  endif;
  for l_index = 1 to g_kwCount;
    if %len(g_kw(l_index)) > 0;
      l_stmt += ' ' + g_kw(l_index);
    endif;
  endfor;
  l_stmt += ';';

  // Remember the type for MOVE and MOVEL (C specifications).
  if l_name <> '' and (l_head = 'dcl-s' or l_head = 'dcl-subf' or l_head = 'dcl-parm');
    l_k = KwFind('LIKE');
    if l_typeText = '' and l_k > 0;
      l_typeText = SymType(KwParam(l_k));
    endif;
    if l_typeText <> '';
      AddSym(l_name:l_typeText);
      if l_isSub and g_blockName <> '';
        AddSym(g_blockName + '.' + l_name:l_typeText);
      endif;
    endif;
  endif;

  // LIKEDS and LIKEREC data structures have no END-DS.
  if l_defType = 'DS' and (KwFind('LIKEDS') > 0 or KwFind('LIKEREC') > 0);
    l_opensBlock = *off;
  endif;
  if l_opensBlock;
    g_block = l_defType;
    g_blockName = l_name;
  endif;

  if l_comment <> '';
    AddOut(Pad(l_indent) + '// '
           + l_comment:i_lineNo);
  endif;
  EmitStatement(l_indent:l_stmt:i_lineNo);
  g_lastLineNo = i_lineNo;
  if g_quoted;
    l_note = 'a file, format or field name was written as a literal: check it';
  endif;
  ReportWithContinuations(i_index:i_lineNo:i_line:l_extra:l_note);
  return l_extra;
end-proc;

// ------------------------------------------------------------------
// Compiler directives. /COPY and /INCLUDE stay but the member has to be
// free-form too (a fixed-form member cannot be copied into **FREE source).
dcl-proc ConvertDirective4;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_line char(100) const;
  end-pi;

  dcl-s l_text varchar(100);
  dcl-s l_blank int(10);
  dcl-s l_word varchar(20);

  l_text = %trim(%subst(i_line:7:74));
  l_blank = %scan(' ':l_text);
  if l_blank = 0;
    l_word = Up(l_text);
  else;
    l_word = Up(%subst(l_text:1:l_blank - 1));
  endif;

  select;
    when l_word = '/FREE';
      g_inFree = *on;
      RptItem(C_STS_CONVERTED:i_lineNo:l_text:'');
    when l_word = '/END-FREE';
      g_inFree = *off;
      RptItem(C_STS_CONVERTED:i_lineNo:l_text:'');
    when l_word = '/COPY' or l_word = '/INCLUDE';
      AddOut(l_text:i_lineNo);
      RptItem(C_STS_ASSUMPTION:i_lineNo:l_text
              :'The member is copied into free-form source: convert it too');
    when l_word = '/EJECT' or l_word = '/TITLE' or l_word = '/SPACE'
         or l_word = '/IF' or l_word = '/ELSEIF' or l_word = '/ELSE'
         or l_word = '/ENDIF' or l_word = '/DEFINE' or l_word = '/UNDEFINE'
         or l_word = '/EOF' or l_word = '/SET' or l_word = '/RESTORE';
      AddOut(l_text:i_lineNo);
      RptItem(C_STS_CONVERTED:i_lineNo:l_text:'');
    other;
      ReviewSpec(i_lineNo:i_line:'Compiler directive ' + l_word + ' is not converted');
  endsl;
end-proc;


// ------------------------------------------------------------------
// C specifications, part 1 (FREE-10): extended factor 2 operations, operations
// without operands, IFxx/DOWxx/DOUxx/WHxx, arithmetic, SETON/SETOFF, CLEAR/RESET
// and the file operations without resulting indicators. Everything else is
// kept as a comment and reported R.
dcl-proc PrescanKlist;
  dcl-pi *n;
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_line char(100);
  dcl-s l_cur int(10) inz(0);

  g_klDone = *on;
  for l_k = 1 to SrcCount();
    l_line = SrcLine(l_k);
    if %subst(%xlate(C_LOWER:C_UPPER:l_line):6:1) <> 'C'
       or %subst(l_line:7:1) = '*';
      iter;
    endif;
    select;
      when Up(Txt('C':'OPERATION':l_line)) = 'KLIST' and g_klCount < 50;
        g_klCount += 1;
        l_cur = g_klCount;
        g_klName(l_cur) = Up(Txt('C':'FACTOR1':l_line));
        g_klKeys(l_cur) = '';
      when Up(Txt('C':'OPERATION':l_line)) = 'KFLD' and l_cur > 0;
        if g_klKeys(l_cur) <> '';
          g_klKeys(l_cur) += ' : ';
        endif;
        g_klKeys(l_cur) += Txt('C':'RESULT':l_line);
      when Txt('C':'OPERATION':l_line) <> '';
        l_cur = 0;
    endsl;
  endfor;
end-proc;

// ------------------------------------------------------------------
// A key operand: a KLIST name becomes its list of fields.
dcl-proc KeyText;
  dcl-pi *n varchar(220);
    i_key varchar(100) const;
  end-pi;

  dcl-s l_k int(10);

  for l_k = 1 to g_klCount;
    if g_klName(l_k) = Up(i_key) and g_klKeys(l_k) <> '';
      return '(' + g_klKeys(l_k) + ')';
    endif;
  endfor;
  return i_key;
end-proc;

// ------------------------------------------------------------------
dcl-proc CPush;
  dcl-pi *n;
    i_kind char(1) const;
  end-pi;

  if g_depth < 60;
    g_depth += 1;
    g_stack(g_depth) = i_kind;
  endif;
end-proc;

dcl-proc CPop;
  dcl-pi *n;
    i_kind char(1) const;
  end-pi;

  // Leaves a WHEN or ON-ERROR body first, then the group itself.
  if g_depth > 0 and (g_stack(g_depth) = 'W' or g_stack(g_depth) = 'E');
    g_depth -= 1;
  endif;
  if g_depth > 0;
    g_depth -= 1;
  endif;
end-proc;

// ------------------------------------------------------------------
dcl-proc IsArith;
  dcl-pi *n ind;
    i_op varchar(10) const;
  end-pi;

  return i_op = 'ADD' or i_op = 'SUB' or i_op = 'MULT' or i_op = 'DIV'
         or i_op = 'Z-ADD' or i_op = 'Z-SUB';
end-proc;


// ------------------------------------------------------------------
dcl-proc AddSym;
  dcl-pi *n;
    i_name varchar(45) const;
    i_type varchar(60) const;
  end-pi;

  if g_symCount < C_MAXSYM;
    g_symCount += 1;
    g_symName(g_symCount) = Up(i_name);
    g_symType(g_symCount) = i_type;
  endif;
end-proc;

// ------------------------------------------------------------------
// The free-form type text of a declared field, '' when it is not known.
dcl-proc SymType;
  dcl-pi *n varchar(60);
    i_name varchar(100) const;
  end-pi;

  dcl-s l_k int(10);

  for l_k = g_symCount downto 1;
    if g_symName(l_k) = Up(i_name);
      return g_symType(l_k);
    endif;
  endfor;
  return '';
end-proc;

// ------------------------------------------------------------------
// Splits a type text such as packed(9 : 2): o_kind C char, V varchar, N numeric
// (packed, zoned, int, uns, bindec), I indicator, O other; o_len length or digits,
// o_dec decimals.
dcl-proc ParseType;
  dcl-pi *n;
    i_text varchar(60) const;
    o_kind char(1);
    o_len int(10);
    o_dec int(10);
  end-pi;

  dcl-s l_word varchar(20);
  dcl-s l_paren int(10);
  dcl-s l_arg varchar(40);
  dcl-s l_colon int(10);

  o_kind = 'O';
  o_len = 0;
  o_dec = 0;
  l_paren = %scan('(':i_text);
  if l_paren = 0;
    l_word = i_text;
    l_arg = '';
  else;
    l_word = %subst(i_text:1:l_paren - 1);
    l_arg = %trim(%subst(i_text:l_paren + 1:%len(i_text) - l_paren - 1));
  endif;
  l_colon = %scan(':':l_arg);
  if l_word = 'ind';
    o_kind = 'I';
    return;
  endif;
  if l_arg = '' or %check(C_DIGITS + ': ':l_arg) > 0;
    return;
  endif;
  if l_colon > 0;
    o_len = %int(%trim(%subst(l_arg:1:l_colon - 1)));
    o_dec = %int(%trim(%subst(l_arg:l_colon + 1)));
  else;
    o_len = %int(l_arg);
  endif;
  select;
    when l_word = 'char';
      o_kind = 'C';
    when l_word = 'varchar';
      o_kind = 'V';
    when l_word = 'packed' or l_word = 'zoned' or l_word = 'int' or l_word = 'uns'
         or l_word = 'bindec';
      o_kind = 'N';
  endsl;
end-proc;

// ------------------------------------------------------------------
// MOVE and MOVEL (SC09-2508, the operation codes): converted only when both
// fields are declared in this source, have a known type and the result is the
// same as an assignment or a %SUBST of it. Returns the statement, or '' with
// o_reason set.
dcl-proc MoveStmt;
  dcl-pi *n varchar(300);
    i_op varchar(10) const;
    i_pad ind const;
    i_f2 varchar(14) const;
    i_res varchar(14) const;
    o_reason varchar(190);
  end-pi;

  dcl-s l_rKind char(1);
  dcl-s l_rLen int(10);
  dcl-s l_rDec int(10);
  dcl-s l_sKind char(1);
  dcl-s l_sLen int(10);
  dcl-s l_sDec int(10);
  dcl-s l_rType varchar(60);
  dcl-s l_sType varchar(60);
  dcl-s l_k int(10);
  dcl-s l_pairs int(10);
  dcl-s l_isIndRes ind inz(*off);
  dcl-s l_up varchar(14);

  o_reason = '';
  l_up = Up(i_f2);
  l_rType = SymType(i_res);

  // Indicators: MOVE '1' *IN90, MOVE *ON ind.
  if %len(i_res) = 5 and Up(%subst(i_res:1:3)) = '*IN'
     and %check(C_DIGITS:%subst(i_res:4:2)) = 0;
    l_isIndRes = *on;
  endif;
  if l_isIndRes or (l_rType = 'ind');
    select;
      when i_f2 = '''1''' or l_up = '*ON';
        return i_res + ' = *on';
      when i_f2 = '''0''' or l_up = '*OFF';
        return i_res + ' = *off';
    endsl;
    o_reason = 'MOVE to an indicator needs the literal 1 or 0, *ON or *OFF';
    return '';
  endif;

  // Figurative constants.
  if l_up = '*BLANK' or l_up = '*BLANKS' or l_up = '*ZERO' or l_up = '*ZEROS'
     or l_up = '*HIVAL' or l_up = '*LOVAL';
    if l_rType = '';
      o_reason = 'The result field ' + i_res + ' is not declared in this source';
      return '';
    endif;
    if l_up = '*ZERO' or l_up = '*ZEROS';
      ParseType(l_rType:l_rKind:l_rLen:l_rDec);
      if l_rKind = 'N';
        return i_res + ' = 0';
      endif;
    endif;
    return i_res + ' = ' + Low(i_f2);
  endif;

  if l_rType = '';
    o_reason = 'The result field ' + i_res + ' is not declared in this source';
    return '';
  endif;
  ParseType(l_rType:l_rKind:l_rLen:l_rDec);

  // The source: a literal or a declared field.
  select;
    when %subst(i_f2:1:1) = C_QUOTE;
      l_sKind = 'C';
      l_pairs = 0;
      l_k = %scan('''''':i_f2:2);
      dow l_k > 0 and l_k < %len(i_f2);
        l_pairs += 1;
        l_k = %scan('''''':i_f2:l_k + 2);
      enddo;
      l_sLen = %len(i_f2) - 2 - l_pairs;
      l_sDec = 0;
    when %check('0123456789':i_f2) = 0;
      l_sKind = 'N';
      l_sLen = %len(i_f2);
      l_sDec = 0;
    other;
      l_sType = SymType(i_f2);
      if l_sType = '';
        o_reason = 'Factor 2 ' + i_f2 + ' is not declared in this source';
        return '';
      endif;
      ParseType(l_sType:l_sKind:l_sLen:l_sDec);
  endsl;

  select;
    when l_rKind = 'C' and l_sKind = 'C';
      if i_pad and i_op = 'MOVEL';
        return i_res + ' = ' + i_f2;
      endif;
      if i_pad;
        o_reason = 'MOVE(P) is not converted';
        return '';
      endif;
      if l_sLen = l_rLen;
        return i_res + ' = ' + i_f2;
      endif;
      if i_op = 'MOVEL';
        if l_sLen > l_rLen;
          return i_res + ' = %subst(' + i_f2 + ':1:' + %char(l_rLen) + ')';
        endif;
        return '%subst(' + i_res + ':1:' + %char(l_sLen) + ') = ' + i_f2;
      endif;
      if l_sLen > l_rLen;
        return i_res + ' = %subst(' + i_f2 + ':' + %char(l_sLen - l_rLen + 1) + ')';
      endif;
      return '%subst(' + i_res + ':' + %char(l_rLen - l_sLen + 1) + ':'
             + %char(l_sLen) + ') = ' + i_f2;
    when l_rKind = 'N' and l_sKind = 'N' and not i_pad
         and l_sDec = l_rDec and l_sLen <= l_rLen
         and (l_sLen = l_rLen or i_op = 'MOVE');
      return i_res + ' = ' + i_f2;
  endsl;
  o_reason = i_op + ' between these field types is not converted';
  return '';
end-proc;


// ------------------------------------------------------------------
// Splits 'a:b' (a colon outside quotes and parentheses) into its two parts;
// o_second is '' when there is no colon.
dcl-proc SplitPair;
  dcl-pi *n;
    i_text varchar(100) const;
    o_first varchar(100);
    o_second varchar(100);
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_depth int(10) inz(0);
  dcl-s l_inQuote ind inz(*off);
  dcl-s l_ch char(1);

  o_first = i_text;
  o_second = '';
  for l_k = 1 to %len(i_text);
    l_ch = %subst(i_text:l_k:1);
    select;
      when l_ch = C_QUOTE;
        l_inQuote = not l_inQuote;
      when l_inQuote;
      when l_ch = '(';
        l_depth += 1;
      when l_ch = ')';
        l_depth -= 1;
      when l_ch = ':' and l_depth = 0;
        o_first = %trim(%subst(i_text:1:l_k - 1));
        o_second = %trim(%subst(i_text:l_k + 1));
        return;
    endsl;
  endfor;
end-proc;

// ------------------------------------------------------------------
// CAT, SCAN, CHECK, CHEKR and SUBST (SC09-2508, the operation codes) to +,
// %SCAN, %CHECK, %CHECKR and %SUBST. o_found is the statement for the found
// indicator ('' when none). The result field has to be declared already.
dcl-proc StringStmt;
  dcl-pi *n varchar(300);
    i_op varchar(10) const;
    i_pad ind const;
    i_f1 varchar(14) const;
    i_f2 varchar(14) const;
    i_res varchar(14) const;
    i_found varchar(2) const;
    o_post varchar(100);
    o_reason varchar(190);
  end-pi;

  dcl-s l_a varchar(100);
  dcl-s l_b varchar(100);
  dcl-s l_c varchar(100);
  dcl-s l_d varchar(100);
  dcl-s l_fn varchar(10);
  dcl-s l_expr varchar(300);
  dcl-s l_first varchar(120);
  dcl-s l_blanks varchar(60);
  dcl-s l_n int(10);

  o_post = '';
  o_reason = '';
  SplitPair(i_f1:l_a:l_b);
  SplitPair(i_f2:l_c:l_d);

  select;
    when i_op = 'CAT';
      if i_f2 = '' or i_res = '';
        o_reason = 'CAT needs factor 2 and a result field';
        return '';
      endif;
      if l_d <> '' and (not IsDigits(l_d) or %int(l_d) > 40);
        o_reason = 'CAT with a variable number of blanks is not converted';
        return '';
      endif;
      if %subst(l_c:1:1) = '*' or %subst(l_a:1:1) = '*';
        o_reason = 'CAT with a figurative constant is not converted';
        return '';
      endif;
      if l_b <> '';
        o_reason = 'CAT with a start in factor 1 is not valid';
        return '';
      endif;
      if l_a = '';
        l_first = i_res;
      else;
        l_first = l_a;
      endif;
      l_expr = '';
      if l_d <> '';
        if %subst(l_first:1:1) <> C_QUOTE;
          l_first = '%trimr(' + l_first + ')';
        endif;
        l_expr = l_first;
        if %int(l_d) > 0;
          l_blanks = C_QUOTE + %subst('                                        '
                     :1:%int(l_d)) + C_QUOTE;
          l_expr += ' + ' + l_blanks;
        endif;
        l_expr += ' + ' + l_c;
      else;
        l_expr = l_first + ' + ' + l_c;
      endif;
      return i_res + ' = ' + l_expr;

    when i_op = 'SCAN' or i_op = 'CHECK' or i_op = 'CHEKR';
      if i_pad;
        o_reason = 'Operation extender P is not valid on ' + i_op;
        return '';
      endif;
      if i_f1 = '' or i_f2 = '' or (i_res = '' and i_found = '');
        o_reason = i_op + ' needs factors 1 and 2 and a result field or an '
                   + 'indicator';
        return '';
      endif;
      select;
        when i_op = 'SCAN';
          l_fn = '%scan';
        when i_op = 'CHECK';
          l_fn = '%check';
        other;
          l_fn = '%checkr';
      endsl;
      // Factor 1 with a length takes the left part of the string.
      if l_b <> '';
        l_a = '%subst(' + l_a + ':1:' + l_b + ')';
      endif;
      l_expr = l_fn + '(' + l_a + ':' + l_c;
      if l_d <> '';
        l_expr += ':' + l_d;
      endif;
      l_expr += ')';
      if i_res <> '';
        if i_found <> '';
          o_post = '*in' + i_found + ' = (' + i_res + ' > 0)';
        endif;
        return i_res + ' = ' + l_expr;
      endif;
      o_post = '*in' + i_found + ' = (' + l_expr + ' > 0)';
      return '';

    when i_op = 'SUBST';
      if i_f2 = '' or i_res = '';
        o_reason = 'SUBST needs factor 2 and a result field';
        return '';
      endif;
      if i_found <> '';
        o_reason = 'SUBST with an indicator needs MONITOR';
        return '';
      endif;
      if l_b <> '';
        o_reason = 'SUBST with a start in factor 1 is not valid';
        return '';
      endif;
      if l_d = '';
        l_d = '1';
      endif;
      if l_a <> '';
        return i_res + ' = %subst(' + l_c + ':' + l_d + ':' + l_a + ')';
      endif;
      return i_res + ' = %subst(' + l_c + ':' + l_d + ')';
  endsl;
  o_reason = 'Operation ' + i_op + ' is not converted';
  return '';
end-proc;

// ------------------------------------------------------------------
dcl-proc IsStringOp;
  dcl-pi *n ind;
    i_op varchar(10) const;
  end-pi;

  return i_op = 'CAT' or i_op = 'SCAN' or i_op = 'CHECK' or i_op = 'CHEKR'
         or i_op = 'SUBST';
end-proc;

// ------------------------------------------------------------------
// ANDxx or ORxx with a valid xx.
dcl-proc IsAndOr;
  dcl-pi *n ind;
    i_op varchar(10) const;
  end-pi;

  if %len(i_op) = 5 and %subst(i_op:1:3) = 'AND';
    return CompareSymbol(%subst(i_op:4:2)) <> '';
  endif;
  if %len(i_op) = 4 and %subst(i_op:1:2) = 'OR';
    return CompareSymbol(%subst(i_op:3:2)) <> '';
  endif;
  return *off;
end-proc;

// ------------------------------------------------------------------
// The statements that give the resulting indicators of an operation their value
// (Table 99 of SC09-2508): '; ' separated, '' when there are none. o_error is
// *on when an error indicator needs the (E) extender. o_reason is set for an
// indicator that has no free-form equivalent.
dcl-proc ResultInds;
  dcl-pi *n varchar(400);
    i_op varchar(10) const;
    i_f1 varchar(14) const;
    i_f2 varchar(14) const;
    i_res varchar(14) const;
    i_line char(100) const;
    o_error ind;
    o_reason varchar(190);
  end-pi;

  dcl-s l_ind varchar(2) dim(3);
  dcl-s l_k int(10);
  dcl-s l_out varchar(400) inz('');
  dcl-s l_test varchar(100);
  dcl-s l_isFile ind inz(*off);
  dcl-s l_pos int(10);

  o_error = *off;
  o_reason = '';
  l_ind(1) = Txt('C':'HI':i_line);
  l_ind(2) = Txt('C':'LO':i_line);
  l_ind(3) = Txt('C':'EQ':i_line);
  l_isFile = i_op = 'CHAIN' or i_op = 'SETLL' or i_op = 'SETGT'
             or i_op = 'DELETE' or i_op = 'READ' or i_op = 'READE'
             or i_op = 'READP' or i_op = 'READPE' or i_op = 'WRITE'
             or i_op = 'UPDATE' or i_op = 'EXFMT' or i_op = 'OPEN'
             or i_op = 'CLOSE' or i_op = 'UNLOCK' or i_op = 'FEOD';

  for l_k = 1 to 3;
    if l_ind(l_k) = '';
      iter;
    endif;
    l_test = '';
    select;
      when l_isFile and l_k = 1 and (i_op = 'CHAIN' or i_op = 'SETLL'
           or i_op = 'SETGT' or i_op = 'DELETE');
        l_test = 'not %found(' + i_f2 + ')';
      when l_isFile and l_k = 2;
        o_error = *on;
        l_test = '%error';
      when l_isFile and l_k = 3 and (i_op = 'READ' or i_op = 'READE'
           or i_op = 'READP' or i_op = 'READPE');
        l_test = '%eof(' + i_f2 + ')';
      when l_isFile and l_k = 3 and i_op = 'SETLL';
        l_test = '%equal(' + i_f2 + ')';
      when (i_op = 'ADD' or i_op = 'SUB' or i_op = 'MULT' or i_op = 'DIV'
           or i_op = 'Z-ADD' or i_op = 'Z-SUB') and i_res <> '';
        select;
          when l_k = 1;
            l_test = i_res + ' > 0';
          when l_k = 2;
            l_test = i_res + ' < 0';
          other;
            l_test = i_res + ' = 0';
        endsl;
      when i_op = 'COMP' and i_f1 <> '' and i_f2 <> '';
        select;
          when l_k = 1;
            l_test = i_f1 + ' > ' + i_f2;
          when l_k = 2;
            l_test = i_f1 + ' < ' + i_f2;
          other;
            l_test = i_f1 + ' = ' + i_f2;
        endsl;
      other;
        o_reason = 'Resulting indicator in columns ' + %char(69 + 2 * l_k) + '-'
                   + %char(70 + 2 * l_k) + ' of ' + i_op + ' is not converted';
        return '';
    endsl;
    if %len(l_out) > 0;
      l_out += '; ';
    endif;
    l_out += '*in' + l_ind(l_k) + ' = (' + l_test + ')';
  endfor;
  return l_out;
end-proc;

// ------------------------------------------------------------------
// The operation code of a C line without its extender, in upper case.
dcl-proc OpOf;
  dcl-pi *n varchar(10);
    i_line char(100) const;
  end-pi;

  dcl-s l_text varchar(10);
  dcl-s l_paren int(10);

  l_text = Up(Txt('C':'OPERATION':i_line));
  l_paren = %scan('(':l_text);
  if l_paren > 1;
    return %subst(l_text:1:l_paren - 1);
  endif;
  return l_text;
end-proc;

// ------------------------------------------------------------------
dcl-proc IsExtF2Op;
  dcl-pi *n ind;
    i_op varchar(10) const;
  end-pi;

  return i_op = 'EVAL' or i_op = 'EVALR' or i_op = 'EVAL-CORR' or i_op = 'IF'
         or i_op = 'DOW' or i_op = 'DOU' or i_op = 'WHEN' or i_op = 'ELSEIF'
         or i_op = 'FOR' or i_op = 'RETURN' or i_op = 'CALLP' or i_op = 'SORTA'
         or i_op = 'ON-ERROR';
end-proc;

// ------------------------------------------------------------------
// The compare symbol of the xx of IFxx, DOWxx, DOUxx and WHxx.
dcl-proc CompareSymbol;
  dcl-pi *n varchar(2);
    i_xx varchar(2) const;
  end-pi;

  select;
    when i_xx = 'EQ';
      return '=';
    when i_xx = 'NE';
      return '<>';
    when i_xx = 'GT';
      return '>';
    when i_xx = 'LT';
      return '<';
    when i_xx = 'GE';
      return '>=';
    when i_xx = 'LE';
      return '<=';
  endsl;
  return '';
end-proc;

// ------------------------------------------------------------------
// *ON when a following C line continues the extended factor 2.
dcl-proc IsCContinuation;
  dcl-pi *n ind;
    i_line char(100) const;
  end-pi;

  if %subst(%xlate(C_LOWER:C_UPPER:i_line):6:1) <> 'C'
     or %subst(i_line:7:1) = '*' or %subst(i_line:7:1) = '/'
     or %subst(i_line:7:1) = '+';
    return *off;
  endif;
  return Txt('C':'CONTBLANK':i_line) = '' and Txt('C':'OPERATION':i_line) = ''
         and Txt('C':'EXTF2':i_line) <> '';
end-proc;

// ------------------------------------------------------------------
dcl-proc IsCOp;
  dcl-pi *n ind;
    i_line char(100) const;
  end-pi;

  return %subst(%xlate(C_LOWER:C_UPPER:i_line):6:1) = 'C'
         and %subst(i_line:7:1) <> '*' and %subst(i_line:7:1) <> '/'
         and %subst(i_line:7:1) <> '+'
         and Txt('C':'OPERATION':i_line) <> '';
end-proc;

// ------------------------------------------------------------------
dcl-proc ConvertC;
  dcl-pi *n int(10);
    i_index int(10) const;
    i_lineNo int(10) const;
    i_line char(100) const;
  end-pi;

  dcl-s l_opText varchar(10);
  dcl-s l_op varchar(10);
  dcl-s l_ext varchar(6) inz('');
  dcl-s l_paren int(10);
  dcl-s l_f1 varchar(14);
  dcl-s l_f2 varchar(14);
  dcl-s l_res varchar(14);
  dcl-s l_ef2 varchar(400) inz('');
  dcl-s l_extra int(10) inz(0);
  dcl-s l_next int(10);
  dcl-s l_stmt varchar(600) inz('');
  dcl-s l_reason varchar(190) inz('');
  dcl-s l_note varchar(190) inz('');
  dcl-s l_xx varchar(2);
  dcl-s l_sym varchar(2);
  dcl-s l_indent int(10);
  dcl-s l_kind char(1) inz(' ');
  dcl-s l_dedent ind inz(*off);
  dcl-s l_sets varchar(200);
  dcl-s l_ind varchar(2);
  dcl-s l_k int(10);
  dcl-s l_val varchar(5);
  dcl-s l_half ind inz(*off);
  dcl-s l_expr varchar(100);
  dcl-s l_args varchar(300);
  dcl-s l_open ind inz(*off);
  dcl-s l_post varchar(400) inz('');
  dcl-s l_err ind inz(*off);
  dcl-s l_andOp varchar(10);
  dcl-s l_andSym varchar(2);
  dcl-s l_andLine char(100);
  dcl-s l_andF1 varchar(14);
  dcl-s l_andF2 varchar(14);
  dcl-s l_hasInd ind inz(*off);
  dcl-s l_cond varchar(30) inz('');
  dcl-s l_incr varchar(14) inz('');
  dcl-s l_hdr varchar(300);
  dcl-s l_start varchar(14);
  dcl-s l_limit varchar(14);
  dcl-s l_base int(10);

  if not g_klDone;
    PrescanKlist();
  endif;

  l_opText = Up(Txt('C':'OPERATION':i_line));
  l_paren = %scan('(':l_opText);
  if l_paren > 0;
    l_op = %subst(l_opText:1:l_paren - 1);
    l_ext = Low(%subst(l_opText:l_paren));
  else;
    l_op = l_opText;
  endif;
  l_f1 = Txt('C':'FACTOR1':i_line);
  l_f2 = Txt('C':'FACTOR2':i_line);
  l_res = Txt('C':'RESULT':i_line);

  // Extended factor 2 and its continuation lines.
  if IsExtF2Op(l_op);
    l_ef2 = Txt('C':'EXTF2':i_line);
    l_next = i_index + 1;
    dow l_next <= SrcCount() and IsCContinuation(SrcLine(l_next));
      if %len(l_ef2) > 0 and (%subst(l_ef2:%len(l_ef2):1) = '+'
         or %subst(l_ef2:%len(l_ef2):1) = '-');
        l_reason = 'A literal continued with + or - is not converted';
      endif;
      l_ef2 += ' ' + Txt('C':'EXTF2':SrcLine(l_next));
      l_extra += 1;
      l_next += 1;
    enddo;
  endif;

  // ---- what cannot be converted here ----
  select;
    when l_reason <> '';
    when Txt('C':'LEVEL':i_line) <> '';
      l_reason = 'Level indicator (columns 7-8) on a calculation';
    when Txt('C':'NOT1':i_line) <> '' and Txt('C':'IND1':i_line) = '';
      l_reason = 'N in column 9 without an indicator';
    when Txt('C':'IND1':i_line) <> '' and
         %check(C_UPPER + C_DIGITS:Up(Txt('C':'IND1':i_line))) > 0;
      l_reason = 'Conditioning indicator is not valid';
    when Txt('C':'IND1':i_line) <> '' and Up(Txt('C':'IND1':i_line)) = 'RT';
      l_reason = 'Indicator RT is not converted';
    when (Txt('C':'HI':i_line) <> '' or Txt('C':'LO':i_line) <> ''
         or Txt('C':'EQ':i_line) <> '') and l_op <> 'SETON' and l_op <> 'SETOFF'
         and not IsStringOp(l_op);
      l_post = ResultInds(l_op:l_f1:l_f2:l_res:i_line:l_err:l_reason);
      l_hasInd = l_reason = '';
    when IsAndOr(l_op);
      l_reason = 'ANDxx and ORxx are not converted yet';
  endsl;
  if l_reason = '' and l_op <> 'BEGSR' and l_op <> 'ENDSR' and l_f1 <> ''
     and l_op <> 'KLIST' and l_op <> 'COMP' and not IsStringOp(l_op)
     and l_op <> 'DO' and l_op <> 'DSPLY' and l_op <> 'COMIT' and l_op <> 'COMMIT'
     and not IsArith(l_op) and not (l_op = 'CHAIN' or l_op = 'SETLL'
     or l_op = 'SETGT' or l_op = 'READE' or l_op = 'READPE' or l_op = 'DELETE')
     and %subst(l_op:1:2) <> 'IF' and %subst(l_op:1:3) <> 'DOW'
     and %subst(l_op:1:3) <> 'DOU' and %subst(l_op:1:2) <> 'WH'
     and not (l_op = 'SETON' or l_op = 'SETOFF');
    l_reason = 'Factor 1 on ' + l_op + ' is not converted';
  endif;
  if l_reason = '' and l_ef2 = '' and IsExtF2Op(l_op) and l_op <> 'RETURN'
     and l_op <> 'ON-ERROR';
    l_reason = 'Extended factor 2 is missing';
  endif;

  // ---- the statement ----
  if l_reason = '';
    select;
      when IsExtF2Op(l_op);
        l_stmt = Low(l_op) + l_ext;
        if l_ef2 <> '';
          l_stmt += ' ' + l_ef2;
        endif;
        select;
          when l_op = 'IF' or l_op = 'DOW' or l_op = 'DOU' or l_op = 'FOR';
            l_kind = 'I';
            if l_op <> 'IF';
              l_kind = 'L';
            endif;
          when l_op = 'WHEN';
            l_kind = 'w';
          when l_op = 'ELSEIF';
            l_dedent = *on;
          when l_op = 'ON-ERROR';
            l_kind = 'e';
        endsl;
      when l_op = 'ELSE';
        l_stmt = 'else';
        l_dedent = *on;
      when l_op = 'OTHER';
        l_stmt = 'other';
        l_kind = 'w';
      when l_op = 'SELECT';
        l_stmt = 'select';
        l_kind = 'S';
      when l_op = 'MONITOR';
        l_stmt = 'monitor';
        l_kind = 'M';
      when l_op = 'ENDIF' or l_op = 'ENDDO' or l_op = 'ENDFOR' or l_op = 'ENDSL'
           or l_op = 'ENDMON';
        if l_f2 <> '' and l_op = 'ENDDO';
          if g_depth > 0 and g_stack(g_depth) = 'F';
            if l_f2 <> '1';
              l_incr = l_f2;
            endif;
          else;
            l_reason = 'ENDDO with an increment (factor 2) closes no DO loop';
          endif;
        endif;
        l_stmt = Low(l_op);
        l_kind = '-';
      when l_op = 'ITER' or l_op = 'LEAVE' or l_op = 'LEAVESR';
        l_stmt = Low(l_op);
      when l_op = 'DO';
        l_start = l_f1;
        l_limit = l_f2;
        if l_start = '';
          l_start = '1';
        endif;
        if l_limit = '';
          l_limit = '1';
        endif;
        if l_res = '' or Txt('C':'LENGTH':i_line) <> ''
           or Txt('C':'DECIMALS':i_line) <> '' or l_ext <> '';
          l_reason = 'DO needs an index field that is declared elsewhere (no '
                     + 'length, decimals or extender)';
        else;
          l_stmt = 'for ' + l_res + ' = ' + l_start + ' to ' + l_limit;
          l_kind = 'F';
        endif;
      when l_op = 'DSPLY';
        if l_f1 = '' and (l_f2 <> '' or l_res <> '');
          l_reason = 'DSPLY with a queue or response needs a message in factor 1';
        elseif l_f2 = '' and l_res <> '';
          l_reason = 'DSPLY with a response and no queue is not converted';
        else;
          l_stmt = 'dsply' + l_ext + ' ' + l_f1;
          if l_f2 <> '';
            l_stmt += ' ' + l_f2;
          endif;
          if l_res <> '';
            l_stmt += ' ' + l_res;
          endif;
        endif;
      when l_op = 'COMIT' or l_op = 'COMMIT' or l_op = 'ROLBK';
        l_stmt = Low(l_op) + l_ext;
        if l_op = 'COMIT';
          l_stmt = 'commit' + l_ext;
        endif;
        if l_f1 <> '' and l_op <> 'ROLBK';
          l_stmt += ' ' + l_f1;
        elseif l_f1 <> '';
          l_reason = 'ROLBK with factor 1 is not valid';
        endif;
      when l_op = 'DUMP';
        l_stmt = 'dump' + l_ext;
      when l_op = 'TIME';
        if l_res = '' or SymType(l_res) <> 'packed(6 : 0)'
           and SymType(l_res) <> 'zoned(6 : 0)';
          l_reason = 'TIME is converted for a declared 6-digit numeric field only';
        else;
          l_stmt = l_res + ' = %dec(%time() : *hms)';
        endif;
      when l_op = 'BEGSR';
        if l_f1 = '';
          l_reason = 'BEGSR without a name';
        endif;
        l_stmt = 'begsr ' + l_f1;
        l_kind = 'R';
      when l_op = 'ENDSR';
        if l_f2 <> '' or l_res <> '';
          l_reason = 'ENDSR with a return point is not converted';
        endif;
        l_stmt = 'endsr';
        l_kind = '-';
      when l_op = 'KLIST' or l_op = 'KFLD';
        l_stmt = '';
        l_kind = 'k';
      when %subst(l_op:1:2) = 'IF' or %subst(l_op:1:3) = 'DOW'
           or %subst(l_op:1:3) = 'DOU' or %subst(l_op:1:2) = 'WH';
        select;
          when %subst(l_op:1:2) = 'IF';
            l_xx = %subst(l_op:3);
            l_stmt = 'if';
            l_kind = 'I';
          when %subst(l_op:1:3) = 'DOW';
            l_xx = %subst(l_op:4);
            l_stmt = 'dow';
            l_kind = 'L';
          when %subst(l_op:1:3) = 'DOU';
            l_xx = %subst(l_op:4);
            l_stmt = 'dou';
            l_kind = 'L';
          other;
            l_xx = %subst(l_op:3);
            l_stmt = 'when';
            l_kind = 'w';
        endsl;
        l_sym = CompareSymbol(l_xx);
        if l_sym = '' or l_f1 = '' or l_f2 = '';
          l_reason = 'Operation ' + l_op + ' is not converted';
        else;
          l_open = *off;
          if i_index < SrcCount();
            if IsCOp(SrcLine(i_index + 1));
              l_open = IsAndOr(OpOf(SrcLine(i_index + 1)));
            endif;
          endif;
          if l_open;
            l_stmt += ' (' + l_f1 + ' ' + l_sym + ' ' + l_f2 + ')';
          else;
            l_stmt += ' ' + l_f1 + ' ' + l_sym + ' ' + l_f2;
          endif;
          l_next = i_index + 1;
          dow l_next <= SrcCount() and IsCOp(SrcLine(l_next))
              and IsAndOr(OpOf(SrcLine(l_next)));
            l_andLine = SrcLine(l_next);
            l_andOp = OpOf(l_andLine);
            l_andF1 = Txt('C':'FACTOR1':l_andLine);
            l_andF2 = Txt('C':'FACTOR2':l_andLine);
            if %subst(l_andOp:1:3) = 'AND';
              l_andSym = CompareSymbol(%subst(l_andOp:4:2));
            else;
              l_andSym = CompareSymbol(%subst(l_andOp:3:2));
            endif;
            if l_andF1 = '' or l_andF2 = '' or Txt('C':'LEVEL':l_andLine) <> ''
               or Txt('C':'NOT1':l_andLine) <> '' or Txt('C':'IND1':l_andLine) <> ''
               or Txt('C':'HI':l_andLine) <> '' or Txt('C':'LO':l_andLine) <> ''
               or Txt('C':'EQ':l_andLine) <> '';
              l_reason = 'ANDxx or ORxx with indicators or without factors';
              leave;
            endif;
            if %subst(l_andOp:1:3) = 'AND';
              l_stmt += ' and (';
            else;
              l_stmt += ' or (';
            endif;
            l_stmt += l_andF1 + ' ' + l_andSym + ' ' + l_andF2 + ')';
            l_extra += 1;
            l_next += 1;
          enddo;
        endif;
      when l_op = 'SETON' or l_op = 'SETOFF';
        if l_op = 'SETON';
          l_val = '*on';
        else;
          l_val = '*off';
        endif;
        l_sets = '';
        for l_k = 1 to 3;
          select;
            when l_k = 1;
              l_ind = Txt('C':'HI':i_line);
            when l_k = 2;
              l_ind = Txt('C':'LO':i_line);
            other;
              l_ind = Txt('C':'EQ':i_line);
          endsl;
          if l_ind <> '';
            if %len(l_sets) > 0;
              l_sets += '; ';
            endif;
            l_sets += '*in' + l_ind + ' = ' + l_val;
          endif;
        endfor;
        if l_sets = '';
          l_reason = l_op + ' without indicators';
        endif;
        l_stmt = l_sets;
      when IsArith(l_op);
        if l_res = '' or Txt('C':'LENGTH':i_line) <> ''
           or Txt('C':'DECIMALS':i_line) <> '';
          l_reason = 'The result field is not declared here (length or decimals '
                     + 'given, or no result)';
        elseif l_f2 = '';
          l_reason = 'Factor 2 is missing';
        elseif l_ext <> '' and l_ext <> '(h)';
          l_reason = 'Operation extender ' + l_ext + ' is not converted';
        else;
          l_half = (l_ext = '(h)');
          select;
            when l_op = 'Z-ADD';
              l_expr = l_f2;
            when l_op = 'Z-SUB';
              l_expr = '-' + l_f2;
            when l_op = 'ADD' and l_f1 = '';
              l_expr = l_res + ' + ' + l_f2;
            when l_op = 'SUB' and l_f1 = '';
              l_expr = l_res + ' - ' + l_f2;
            when l_op = 'MULT' and l_f1 = '';
              l_expr = l_res + ' * ' + l_f2;
            when l_op = 'DIV' and l_f1 = '';
              l_expr = l_res + ' / ' + l_f2;
            when l_op = 'ADD';
              l_expr = l_f1 + ' + ' + l_f2;
            when l_op = 'SUB';
              l_expr = l_f1 + ' - ' + l_f2;
            when l_op = 'MULT';
              l_expr = l_f1 + ' * ' + l_f2;
            other;
              l_expr = l_f1 + ' / ' + l_f2;
          endsl;
          if l_half;
            l_stmt = 'eval(h) ' + l_res + ' = ' + l_expr;
          else;
            l_stmt = l_res + ' = ' + l_expr;
          endif;
          if l_op = 'DIV';
            l_note = 'DIV followed by MVR needs a review';
          endif;
        endif;
      when IsStringOp(l_op);
        if Txt('C':'LENGTH':i_line) <> '' or Txt('C':'DECIMALS':i_line) <> ''
           or Txt('C':'HI':i_line) <> '' or Txt('C':'LO':i_line) <> ''
           or (l_ext <> '' and l_ext <> '(p)');
          l_reason = l_op + ' with a declared result, an error indicator, an '
                     + 'extender or a high/low indicator is not converted';
        elseif l_res <> '' and SymType(l_res) = '';
          l_reason = 'The result field ' + l_res + ' is not declared in this source';
        else;
          l_stmt = StringStmt(l_op:l_ext = '(p)':l_f1:l_f2:l_res
                              :Txt('C':'EQ':i_line):l_post:l_reason);
          if l_reason = '' and not (l_ext = '(p)' and l_op <> 'SCAN');
            l_note = l_op + ' converted: the unused part of the result is not '
                     + 'padded the same way, check';
          endif;
        endif;
      when l_op = 'MOVE' or l_op = 'MOVEL';
        if l_f1 <> '' or l_f2 = '' or l_res = ''
           or Txt('C':'LENGTH':i_line) <> '' or Txt('C':'DECIMALS':i_line) <> ''
           or (l_ext <> '' and l_ext <> '(p)');
          l_reason = l_op + ' with factor 1, extender, length or without both '
                     + 'fields is not converted';
        else;
          l_stmt = MoveStmt(l_op:l_ext = '(p)':l_f2:l_res:l_reason);
          if l_reason = '' and l_stmt <> '';
            l_note = l_op + ' converted from the declared field types: check';
          endif;
        endif;
      when l_op = 'COMP';
        if not l_hasInd or l_f1 = '' or l_f2 = '';
          l_reason = 'COMP needs two factors and resulting indicators';
        endif;
        l_stmt = '';
      when l_op = 'CLEAR' or l_op = 'RESET';
        if l_f1 <> '' or l_f2 <> '' or l_res = '';
          l_reason = l_op + ' with factors is not converted';
        endif;
        l_stmt = Low(l_op) + ' ' + l_res;
      when l_op = 'CHAIN' or l_op = 'READE' or l_op = 'READPE' or l_op = 'SETLL'
           or l_op = 'SETGT' or l_op = 'DELETE' or l_op = 'READ' or l_op = 'READP'
           or l_op = 'WRITE' or l_op = 'UPDATE' or l_op = 'OPEN' or l_op = 'CLOSE'
           or l_op = 'UNLOCK' or l_op = 'FEOD' or l_op = 'EXFMT';
        if l_err and %scan('e':l_ext) = 0;
          if l_ext = '';
            l_ext = '(e)';
          else;
            l_ext = '(e' + %subst(l_ext:2);
          endif;
        endif;
        l_stmt = Low(l_op) + l_ext;
        l_args = '';
        if l_op = 'CHAIN' or l_op = 'READE' or l_op = 'READPE' or l_op = 'SETLL'
           or l_op = 'SETGT' or l_op = 'DELETE';
          if l_f1 <> '';
            l_args = KeyText(l_f1) + ' ';
          elseif l_op = 'CHAIN' or l_op = 'SETLL' or l_op = 'SETGT';
            l_reason = l_op + ' without a key in factor 1';
          endif;
        elseif l_f1 <> '';
          l_reason = 'Factor 1 on ' + l_op + ' is not converted';
        endif;
        if l_f2 = '';
          l_reason = l_op + ' without a file or record in factor 2';
        endif;
        l_args += l_f2;
        if l_res <> '' and (l_op = 'CHAIN' or l_op = 'READE' or l_op = 'READPE'
           or l_op = 'READ' or l_op = 'READP' or l_op = 'WRITE' or l_op = 'UPDATE'
           or l_op = 'EXFMT');
          l_args += ' ' + l_res;
        elseif l_res <> '';
          l_reason = 'Result field on ' + l_op + ' is not converted';
        endif;
        l_stmt += ' ' + l_args;
      other;
        l_reason = 'Operation ' + l_op + ' is not converted yet (RPG IV)';
    endsl;
  endif;

  // A conditioning indicator wraps the statement in IF ... ENDIF; a group
  // operation cannot be wrapped this way.
  if l_reason = '' and Txt('C':'IND1':i_line) <> '';
    if l_kind <> ' ' and l_kind <> 'k';
      l_reason = 'Conditioning indicator on ' + l_op + ' is not converted';
    else;
      l_cond = '*in' + Up(Txt('C':'IND1':i_line));
      if Up(Txt('C':'NOT1':i_line)) = 'N';
        l_cond = 'not ' + l_cond;
      endif;
    endif;
  endif;

  if l_reason <> '';
    ReviewWithContinuations(i_index:i_lineNo:i_line:l_extra:l_reason);
    return l_extra;
  endif;

  // ---- indentation and output ----
  if l_kind = 'k';
    RptItem(C_STS_CONVERTED:i_lineNo:%trimr(%subst(i_line:6:75)):'');
    return l_extra;
  endif;
  select;
    when l_kind = '-';
      if l_incr <> '' and g_depth > 0;
        l_hdr = g_hdrTxt(g_depth);
        OutSet(g_hdrIdx(g_depth):%subst(l_hdr:1:%len(l_hdr) - 1) + ' by '
               + l_incr + ';');
      endif;
      CPop(' ');
    when l_kind = 'w' or l_kind = 'e';
      if g_depth > 0 and (g_stack(g_depth) = 'W' or g_stack(g_depth) = 'E');
        g_depth -= 1;
      endif;
  endsl;
  l_indent = 2 * g_depth;
  if l_dedent and l_indent >= 2;
    l_indent -= 2;
  endif;
  // SETON and SETOFF give several statements: written like the indicator tests.
  if l_op = 'SETON' or l_op = 'SETOFF';
    l_post = l_stmt;
    l_stmt = '';
  endif;
  l_base = l_indent;
  if l_cond <> '' and (l_stmt <> '' or l_post <> '');
    EmitStatement(l_base:'if ' + l_cond + ';':i_lineNo);
    l_indent += 2;
  endif;
  if l_stmt <> '';
    EmitStatement(l_indent:l_stmt + ';':i_lineNo);
  endif;
  l_k = %scan('; ':l_post);
  dow l_post <> '';
    if l_k > 0;
      EmitStatement(l_indent:%subst(l_post:1:l_k - 1) + ';':i_lineNo);
      l_post = %subst(l_post:l_k + 2);
    else;
      EmitStatement(l_indent:l_post + ';':i_lineNo);
      l_post = '';
    endif;
    l_k = %scan('; ':l_post);
  enddo;
  if l_indent > l_base;
    EmitStatement(l_base:'endif;':i_lineNo);
  endif;
  select;
    when l_kind = 'I' or l_kind = 'L' or l_kind = 'F';
      CPush(l_kind);
      if l_kind = 'F' and g_depth > 0;
        g_hdrIdx(g_depth) = OutCount();
        g_hdrTxt(g_depth) = Pad(l_indent) + l_stmt + ';';
      endif;
    when l_kind = 'S' or l_kind = 'M' or l_kind = 'R';
      CPush(l_kind);
    when l_kind = 'w';
      CPush('W');
    when l_kind = 'e';
      CPush('E');
  endsl;
  g_lastLineNo = i_lineNo;
  ReportWithContinuations(i_index:i_lineNo:i_line:l_extra:l_note);
  return l_extra;
end-proc;

// ------------------------------------------------------------------
dcl-proc Fx4Line export;
  dcl-pi *n ind;
    i_index int(10) const;
    i_lineNo int(10) const;
    i_line char(100) const;
    o_extra int(10);
  end-pi;

  dcl-s l_form char(1);
  dcl-s l_text varchar(100);

  o_extra = 0;
  l_form = %subst(%xlate(C_LOWER:C_UPPER:i_line):6:1);

  // Inside /FREE ... /END-FREE: free-form statements from column 8.
  if g_inFree;
    l_text = %trim(%subst(i_line:7:74));
    if Up(l_text) = '/END-FREE';
      ConvertDirective4(i_lineNo:i_line);
      return *on;
    endif;
    AddOut(%trimr(%subst(i_line:8:93)):i_lineNo);
    RptItem(C_STS_CONVERTED:i_lineNo:%trimr(%subst(i_line:8:70)):'');
    return *on;
  endif;

  if %subst(i_line:7:1) = '/';
    Fx4Flush();
    ConvertDirective4(i_lineNo:i_line);
    return *on;
  endif;

  select;
    when l_form = 'H';
      Fx4Flush();
      o_extra = ConvertH(i_index:i_lineNo:i_line);
    when l_form = 'F';
      Fx4Flush();
      o_extra = ConvertF(i_index:i_lineNo:i_line);
    when l_form = 'D';
      o_extra = ConvertD(i_index:i_lineNo:i_line);
    when l_form = 'P';
      o_extra = ConvertP(i_index:i_lineNo:i_line);
    when l_form = 'I';
      Fx4Flush();
      ReviewSpec(i_lineNo:i_line:'RPG IV input specification is not converted yet');
    when l_form = 'O';
      Fx4Flush();
      ReviewSpec(i_lineNo:i_line:'RPG IV output specification is not converted yet '
                 + '(FREE-06)');
    when l_form = 'C';
      Fx4Flush();
      o_extra = ConvertC(i_index:i_lineNo:i_line);
    other;
      Fx4Flush();
      ReviewSpec(i_lineNo:i_line:'Unknown specification type in column 6');
  endsl;
  return *on;
end-proc;
