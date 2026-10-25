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
      ReviewSpec(i_lineNo:i_line:'RPG IV calculation specification is not '
                 + 'converted yet (FREE-10, second part)');
    other;
      Fx4Flush();
      ReviewSpec(i_lineNo:i_line:'Unknown specification type in column 6');
  endsl;
  return *on;
end-proc;
