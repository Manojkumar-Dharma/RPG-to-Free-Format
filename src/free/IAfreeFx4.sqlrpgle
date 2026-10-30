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
/copy qcpysrc,IAfreeCalP
/copy qcpysrc,IAfreeFx4P
/copy qcpysrc,IAfreeOutP

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
dcl-s g_blockName varchar(150) inz('');
dcl-s g_inFree ind inz(*off);           // inside /FREE ... /END-FREE
dcl-s g_lastLineNo int(10) inz(0);
dcl-s g_stack char(1) dim(60);          // open C groups: I, L, S, W, M, E, R, J (skip of a GOTO)
dcl-s g_depth int(10) inz(0);
dcl-s g_jvScanned ind inz(*off);       // the jumps of the source are given to the planner
dcl-s g_hdrIdx int(10) dim(60);         // output line and text of a DO header
dcl-s g_hdrTxt varchar(300) dim(60);
dcl-s g_klName varchar(14) dim(50);     // KLIST names and their key fields
dcl-s g_klKeys varchar(200) dim(50);
dcl-s g_klCount int(10) inz(0);
dcl-s g_klDone ind inz(*off);
dcl-c C_MAXSYM 1500;
dcl-s g_symName varchar(150) dim(C_MAXSYM);   // declared fields and their types
dcl-s g_symType varchar(60) dim(C_MAXSYM);
dcl-s g_symCount int(10) inz(0);
// The arrays of the D specifications (DIM) and their sequence, for LOOKUP (RV-53).
dcl-c C_MAXARR 200;
dcl-s g_arrName varchar(150) dim(C_MAXARR);
dcl-s g_arrSeq char(1) dim(C_MAXARR);        // A ascending, D descending, blank
dcl-s g_arrDim varchar(30) dim(C_MAXARR);    // the DIM text, for MOVEA
dcl-s g_dtName varchar(150) dim(50);         // fields that got a DTAARA keyword
dcl-s g_dtCount int(10) inz(0);
dcl-s g_arrCount int(10) inz(0);
// CALL, PARM and PLIST: the parameters read last and the prototypes written.
dcl-c C_MAXPARM 20;
dcl-s g_pF1 varchar(14) dim(C_MAXPARM);
dcl-s g_pF2 varchar(14) dim(C_MAXPARM);
dcl-s g_pRes varchar(14) dim(C_MAXPARM);
dcl-s g_pCount int(10) inz(0);
dcl-s g_protoName varchar(10) dim(40);
dcl-s g_protoSig varchar(300) dim(40);
dcl-s g_protoCount int(10) inz(0);
dcl-s g_cStarted ind inz(*off);
// FREE-60: the primary file of the RPG cycle skeleton (RPG IV).
dcl-s g_cycFile4 varchar(8) inz('');
// The last DIV (for a following MVR).
dcl-s g_divIdx int(10) inz(0);
dcl-s g_divF1 varchar(14);
dcl-s g_divF2 varchar(14);
dcl-s g_divRes varchar(14);
dcl-s g_divHalf ind inz(*off);
dcl-s g_quoted ind inz(*off);           // a name was written as a literal
dcl-s g_constName varchar(150) dim(C_MAXCONST);
dcl-s g_constCount int(10) inz(0);
// The files of the F specifications (I specifications and file operations).
dcl-c C_MAXFL 100;
dcl-s g_flName varchar(10) dim(C_MAXFL);
dcl-s g_flLen int(10) dim(C_MAXFL);
dcl-s g_flType char(1) dim(C_MAXFL);
dcl-s g_flDevice varchar(7) dim(C_MAXFL);
dcl-s g_flLayout ind dim(C_MAXFL);
dcl-s g_flCount int(10) inz(0);

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
// The number of open groups (IF, DO, SELECT, ...) of the C specifications, for
// the SQL statements that IAfreeCalc writes inside them (RV-59).
dcl-proc Fx4Depth export;
  dcl-pi *n int(10);
  end-pi;

  return g_depth;
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
  g_jvScanned = *off;
  g_klCount = 0;
  g_klDone = *off;
  g_symCount = 0;
  g_arrCount = 0;
  g_dtCount = 0;
  g_cStarted = *off;
  g_cycFile4 = '';
  g_protoCount = 0;
  g_divIdx = 0;
  g_flCount = 0;
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
// *ON when the text ends inside a character literal (an odd number of quotes;
// a doubled quote inside a literal keeps the count even).
dcl-proc InLiteral;
  dcl-pi *n ind;
    i_text varchar(1200) const;
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_quotes int(10) inz(0);

  for l_index = 1 to %len(i_text);
    if %subst(i_text:l_index:1) = C_QUOTE;
      l_quotes += 1;
    endif;
  endfor;
  return %rem(l_quotes:2) = 1;
end-proc;

// ------------------------------------------------------------------
// FREE-64: the text ends with a numeric literal (digits and decimal points that do not
// belong to a name such as ABC12).
dcl-proc NumericTail;
  dcl-pi *n ind;
    i_text varchar(1200) const;
  end-pi;

  dcl-s l_i int(10);
  dcl-s l_c char(1);

  l_i = %len(i_text);
  dow l_i > 0;
    l_c = %subst(i_text:l_i:1);
    if (l_c >= '0' and l_c <= '9') or l_c = '.';
      l_i -= 1;
    else;
      leave;
    endif;
  enddo;
  if l_i = %len(i_text);
    return *off;
  endif;
  if l_i = 0;
    return *on;
  endif;
  l_c = %subst(i_text:l_i:1);
  return %check('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_$#@'
                :l_c) > 0;
end-proc;

// The continued field starts with a digit or a decimal point.
dcl-proc NumericStart;
  dcl-pi *n ind;
    i_text varchar(1200) const;
  end-pi;

  dcl-s l_c char(1);

  if %len(i_text) = 0;
    return *off;
  endif;
  l_c = %subst(i_text:1:1);
  return (l_c >= '0' and l_c <= '9') or l_c = '.';
end-proc;

// ------------------------------------------------------------------
// Takes the keyword field of a specification and of its continuation lines:
// o_extra is the number of continuation lines. A literal continued with + (the
// first non-blank character of the next line follows) or - (the next line follows
// from the first position of the keyword field) and a name continued with ... are
// joined (SC09-2508, Continuation Rules); a numeric literal goes on with a digit
// or a decimal point at the start of the next line (FREE-64). *OFF when a + or -
// ends a line outside a literal (not converted, the caller reports it).
// ------------------------------------------------------------------
dcl-proc CollectKeywords;
  dcl-pi *n ind;
    i_spec char(1) const;
    i_index int(10) const;
    i_line char(100) const;
    o_text varchar(1200);
    o_extra int(10);
  end-pi;

  dcl-s l_next int(10);
  dcl-s l_len int(10);
  dcl-s l_last char(1);
  dcl-s l_ok ind inz(*on);

  o_text = Txt(i_spec:'KEYWORDS':i_line);
  o_extra = 0;
  l_next = i_index + 1;
  dow l_next <= SrcCount() and IsContinuation(i_spec:SrcLine(l_next));
    l_len = %len(o_text);
    l_last = ' ';
    if l_len > 0;
      l_last = %subst(o_text:l_len:1);
    endif;
    select;
      when InLiteral(o_text) and l_last = '+';
        o_text = %subst(o_text:1:l_len - 1)
                 + Txt(i_spec:'KEYWORDS':SrcLine(l_next));
      when InLiteral(o_text) and l_last = '-';
        o_text = %subst(o_text:1:l_len - 1)
                 + %trimr(RulText(i_spec:'KEYWORDS':SrcLine(l_next)));
      when not InLiteral(o_text) and l_len > 3
           and %subst(o_text:l_len - 2:3) = '...';
        o_text = %subst(o_text:1:l_len - 3)
                 + Txt(i_spec:'KEYWORDS':SrcLine(l_next));
      // FREE-64: a numeric literal has no continuation character: it goes on with a
      // digit or a decimal point at the start of the continued field (RV-57).
      when not InLiteral(o_text) and NumericTail(o_text)
           and NumericStart(Txt(i_spec:'KEYWORDS':SrcLine(l_next)));
        o_text += Txt(i_spec:'KEYWORDS':SrcLine(l_next));
      when l_last = '+' or l_last = '-';
        l_ok = *off;
        o_text += ' ' + Txt(i_spec:'KEYWORDS':SrcLine(l_next));
      other;
        o_text += ' ' + Txt(i_spec:'KEYWORDS':SrcLine(l_next));
    endsl;
    o_extra += 1;
    l_next += 1;
  enddo;
  if %len(o_text) > 0 and o_extra > 0;
    l_last = %subst(o_text:%len(o_text):1);
    if l_last = '+' or l_last = '-';
      l_ok = *off;
    endif;
  endif;
  return l_ok;
end-proc;

// ------------------------------------------------------------------
// *ON when the line of a D or P specification is a continued part of a name: the
// name begins in columns 7 to 21 and the last non-blank characters are ..., with no
// blanks in between (SC09-2508, Definition and Procedure Specification Name Field).
dcl-proc IsNameCont;
  dcl-pi *n ind;
    i_spec char(1) const;
    i_line char(100) const;
  end-pi;

  dcl-s l_text varchar(80);

  if %subst(%xlate(C_LOWER:C_UPPER:i_line):6:1) <> i_spec;
    return *off;
  endif;
  if %subst(i_line:7:1) = '*' or %subst(i_line:7:1) = '/'
     or %trim(%subst(i_line:7:15)) = '';
    return *off;
  endif;
  l_text = %trim(%subst(i_line:7:74));
  return %len(l_text) > 3 and %subst(l_text:%len(l_text) - 2:3) = '...'
         and %scan(' ':l_text) = 0;
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
    i_name varchar(150) const;
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
  dcl-s l_progPrinter ind inz(*off);
  dcl-s l_progDisk ind inz(*off);
  dcl-s l_index int(10);
  dcl-s l_primary ind inz(*off);
  dcl-s l_cycWhy varchar(150) inz('');

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

  // FREE-60: a primary file (designation P) is converted as a full procedural input
  // file when the cycle skeleton can be written for it (one program described DISK
  // input file, see CycleFileOk in IAfreeCvt); the skeleton reads it.
  if l_desig = 'P' and not l_isLike;
    if l_device <> 'DISK';
      l_cycWhy = 'only a DISK primary file is converted';
    elseif l_fmt = 'F' and %len(l_name) > 8;
      l_cycWhy = 'the file name has more than 8 characters';
    elseif CvtCycleFileOk(l_type:l_fmt:l_cycWhy);
      l_primary = *on;
      l_desig = 'F';
    endif;
  endif;

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
    when l_desig = 'P' and l_cycWhy <> '';
      l_reason = 'Primary file (the RPG cycle) is not converted: ' + l_cycWhy;
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
    when l_device = 'WORKSTN' and l_type = 'U';
      l_reason = 'A display file is an input, output or combined file (I, O or C)';
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
    if l_fmt = 'E';
      FlAdd(l_name:0:l_type:l_device);
    else;
      FlAdd(l_name:%int(l_recLen):l_type:l_device);
    endif;
  endif;
  // A program described printer file: the output records become printer file DDS
  // (IAfreeOut), the file is declared externally described (RV-56).
  l_progPrinter = not l_isLike and l_fmt = 'F' and l_type = 'O' and l_device = 'PRINTER'
                  and %len(l_name) <= 8;
  if l_progPrinter;
    CvtRegisterFile(l_name:0:'P':l_type:i_lineNo:*off);
  endif;
  // A program described DISK or WORKSTN file: registered for the output specifications
  // (exception records, as for RPG II and RPG III) and its record data structure
  // NAME_OUT is declared below (FREE-47, RV-56, RV-62).
  l_progDisk = not l_isLike and l_fmt = 'F' and %len(l_name) <= 8 and l_addrType = ''
               and (l_device = 'DISK' or l_device = 'WORKSTN');
  if l_progDisk;
    CvtRegisterFile(l_name:%int(l_recLen):'D':l_type:i_lineNo:*off);
    CvtSetFileOutput(l_name:(l_type = 'O' or l_add = 'A'));
  endif;
  if l_primary and l_progDisk;
    CvtSetCycleFile(l_name);
    g_cycFile4 = l_name;
    if l_note <> '';
      l_note += '; ';
    endif;
    l_note += 'primary file: the RPG cycle skeleton is written for it when its I '
              + 'specification has a record layout (FREE-60)';
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
      if l_note <> '';
        l_note += '; ';
      endif;
      l_note += 'end of file entry (column 19) ignored: it only matters for the '
                + 'RPG cycle';
    endif;
    l_stmt = 'dcl-f ' + l_name + ' ' + l_deviceText;
    // The usage of a combined display file (also a program described one) is the
    // default of workstn.
    if not (l_device = 'WORKSTN' and l_type = 'C');
      l_stmt += ' usage(' + l_usage + ')';
    endif;
    if l_keyed <> '';
      l_stmt += ' ' + l_keyed;
    endif;
    if l_progPrinter;
      l_stmt = 'dcl-f ' + l_name + ' printer';
      if l_note <> '';
        l_note += '; ';
      endif;
      l_note += 'declared externally described: the printer file comes from the O '
                + 'specifications (FREE-42)';
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
  if l_progDisk and (l_type = 'O' or l_add = 'A');
    EmitStatement(0:'dcl-ds ' + l_name + '_OUT len(' + %char(%int(l_recLen))
                  + ') end-ds;':i_lineNo);
  endif;
  g_lastLineNo = i_lineNo;
  ReportWithContinuations(i_index:i_lineNo:i_line:l_extra:l_note);
  return l_extra;
end-proc;

// ------------------------------------------------------------------
// The files of the converted F specifications that I specifications and file
// operations need: record length (0 for an external file), layout written.
dcl-proc FlAdd;
  dcl-pi *n;
    i_name varchar(10) const;
    i_recLen int(10) const;
    i_type char(1) const;
    i_device varchar(7) const;
  end-pi;

  if g_flCount < C_MAXFL;
    g_flCount += 1;
    g_flName(g_flCount) = Up(i_name);
    g_flLen(g_flCount) = i_recLen;
    g_flType(g_flCount) = i_type;
    g_flDevice(g_flCount) = i_device;
    g_flLayout(g_flCount) = *off;
  endif;
end-proc;

dcl-proc FlFind;
  dcl-pi *n int(10);
    i_name varchar(14) const;
  end-pi;

  dcl-s l_k int(10);

  for l_k = 1 to g_flCount;
    if g_flName(l_k) = Up(i_name);
      return l_k;
    endif;
  endfor;
  return 0;
end-proc;

// ------------------------------------------------------------------
// One field line of an I specification of a program described file (columns 31
// to 74). o_stmt is the dcl-subf statement, o_reason says why it cannot be
// converted. Columns: 31-35 data attributes, 36 format, 37-41 from, 42-46 to,
// 47-48 decimals, 49-62 name, 63-64 level, 65-66 matching, 67-68 relation,
// 69-74 indicators.
dcl-proc InputField4;
  dcl-pi *n ind;
    i_line char(100) const;
    i_recLen int(10) const;
    o_stmt varchar(200);
    o_reason varchar(190);
    i_primary ind const;
    o_level int(10);
    o_name varchar(14);
  end-pi;

  dcl-s l_lvl int(10) inz(0);
  dcl-s l_up char(100);
  dcl-s l_fmt char(1);
  dcl-s l_decText varchar(2);
  dcl-s l_dec int(10);
  dcl-s l_from int(10);
  dcl-s l_to int(10);
  dcl-s l_len int(10);
  dcl-s l_digits int(10);
  dcl-s l_name varchar(14);
  dcl-s l_type varchar(30);
  dcl-s l_fromText varchar(5);
  dcl-s l_toText varchar(5);

  o_stmt = '';
  o_reason = '';
  o_level = 0;
  o_name = '';
  l_up = %xlate(C_LOWER:C_UPPER:i_line);
  l_fmt = %subst(l_up:36:1);
  l_fromText = %trim(%subst(l_up:37:5));
  l_toText = %trim(%subst(l_up:42:5));
  l_decText = %trim(%subst(l_up:47:2));
  l_name = %trim(%subst(l_up:49:14));
  // FREE-60: a control level (columns 63-64: L1 to L9) of a field of the primary
  // file, with nothing else in columns 65-74, is the control field of the skeleton.
  if i_primary and %subst(l_up:63:1) = 'L' and %check('123456789':%subst(l_up:64:1)) = 0
     and %trim(%subst(l_up:65:10)) = '';
    l_lvl = %int(%subst(l_up:64:1));
  endif;

  select;
    when %trim(%subst(l_up:31:5)) <> '';
      o_reason = 'Data attributes (columns 31-35: date or time format, *VAR) are '
                 + 'not converted';
    when not IsDigits(l_fromText) or not IsDigits(l_toText);
      o_reason = 'Field location (columns 37-46) is not valid';
    when %trim(%subst(l_up:63:12)) <> '' and l_lvl = 0;
      o_reason = 'Control level, matching fields, field record relation or field '
                 + 'indicators are not supported in free-form';
    when l_lvl > 0 and %len(l_name) > 6;
      o_reason = 'A control field name of more than 6 characters is not converted';
    when l_name = '' or %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_$#@':l_name) > 0
         or %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ_$#@':%subst(l_name:1:1)) > 0;
      o_reason = 'Field name (columns 49-62) is not a simple name (an array '
                 + 'element, *IN or PAGE is not converted)';
    when l_decText <> '' and not IsDigits(l_decText);
      o_reason = 'Decimal positions (columns 47-48) are not valid';
    when SymType(l_name) <> '';
      o_reason = 'Field ' + l_name + ' is already declared';
  endsl;
  if o_reason <> '';
    return *off;
  endif;
  l_from = %int(l_fromText);
  l_to = %int(l_toText);
  l_len = l_to - l_from + 1;
  if l_decText <> '';
    l_dec = %int(l_decText);
  else;
    l_dec = 0;
  endif;
  if l_from < 1 or l_to < l_from;
    o_reason = 'Field location (columns 37-46) is not valid';
  elseif i_recLen > 0 and l_to > i_recLen;
    o_reason = 'Field ends past the record length ' + %char(i_recLen);
  endif;
  if o_reason <> '';
    return *off;
  endif;

  select;
    when (l_fmt = ' ' and l_decText = '') or l_fmt = 'A';
      if l_decText <> '';
        o_reason = 'Decimal positions on a character field';
      else;
        l_type = 'char(' + %char(l_len) + ')';
      endif;
    when l_fmt = 'N';
      if l_len <> 1 or l_decText <> '';
        o_reason = 'An indicator field (N) is one position without decimals';
      else;
        l_type = 'ind';
      endif;
    when l_fmt = 'F';
      if (l_len <> 4 and l_len <> 8) or l_decText <> '';
        o_reason = 'A float field is 4 or 8 bytes long and has no decimals';
      else;
        l_type = 'float(' + %char(l_len) + ')';
      endif;
    when l_decText = '';
      o_reason = 'A numeric field needs decimal positions (columns 47-48)';
    when l_fmt = ' ' or l_fmt = 'S';
      l_digits = l_len;
      if l_len > 63;
        o_reason = 'A zoned field is longer than 63 digits';
      else;
        l_type = 'zoned(' + %char(l_len) + ' : ' + %char(l_dec) + ')';
      endif;
    when l_fmt = 'P';
      l_digits = 2 * l_len - 1;
      if l_len > 32;
        o_reason = 'A packed field is longer than 32 bytes';
      else;
        l_type = 'packed(' + %char(l_digits) + ' : ' + %char(l_dec) + ')';
      endif;
    when l_fmt = 'B';
      if l_len <> 2 and l_len <> 4;
        o_reason = 'A binary field must be 2 or 4 bytes long';
      else;
        if l_len = 2;
          l_digits = 4;
        else;
          l_digits = 9;
        endif;
        l_type = 'bindec(' + %char(l_digits) + ' : ' + %char(l_dec) + ')';
      endif;
    when l_fmt = 'I' or l_fmt = 'U';
      select;
        when l_len = 1;
          l_digits = 3;
        when l_len = 2;
          l_digits = 5;
        when l_len = 4;
          l_digits = 10;
        when l_len = 8;
          l_digits = 20;
        other;
          o_reason = 'An integer field is 1, 2, 4 or 8 bytes long';
      endsl;
      if l_dec <> 0;
        o_reason = 'An integer field has no decimal positions';
      endif;
      if o_reason = '';
        if l_fmt = 'I';
          l_type = 'int(' + %char(l_digits) + ')';
        else;
          l_type = 'uns(' + %char(l_digits) + ')';
        endif;
      endif;
    other;
      o_reason = 'Data format ' + l_fmt + ' (sign formats, date, time, timestamp, '
                 + 'graphic, UCS-2) is not converted';
  endsl;
  if o_reason = '' and l_dec > l_len and l_fmt <> 'P' and l_fmt <> 'B';
    o_reason = 'Decimal positions are more than the length';
  endif;
  if o_reason <> '';
    return *off;
  endif;

  o_stmt = '  dcl-subf ' + l_name + ' ' + l_type + ' pos(' + %char(l_from) + ');';
  AddSym(l_name:l_type);
  o_level = l_lvl;
  o_name = l_name;
  return *on;
end-proc;

// ------------------------------------------------------------------
// I specification of a program described file: one record type, no record
// identifying codes. The record line and its field lines become the data
// structure FILE_REC (length of the record) with the fields as subfields; the
// file operations of the C specifications name it in their result field.
dcl-proc ConvertI;
  dcl-pi *n int(10);
    i_index int(10) const;
    i_lineNo int(10) const;
    i_line char(100) const;
  end-pi;

  dcl-s l_up char(100);
  dcl-s l_next char(100);
  dcl-s l_nextUp char(100);
  dcl-s l_name varchar(10);
  dcl-s l_file int(10);
  dcl-s l_reason varchar(190) inz('');
  dcl-s l_last int(10);
  dcl-s l_k int(10);
  dcl-s l_stmt varchar(200);
  dcl-s l_fieldReason varchar(190);
  dcl-s l_fields int(10) inz(0);
  dcl-s l_multi ind inz(*off);
  dcl-s l_recLen int(10) inz(0);
  dcl-s l_dsName varchar(14);
  dcl-s l_out varchar(200) dim(300);
  dcl-s l_outNo int(10) dim(300);
  dcl-s l_outCount int(10) inz(0);
  dcl-s l_status char(1);
  dcl-s l_reasons varchar(190) dim(300);
  dcl-s l_ok ind dim(300);
  dcl-s l_isCyc ind inz(*off);
  dcl-s l_lvl int(10);
  dcl-s l_lvls int(10) dim(300);
  dcl-s l_fname varchar(14);
  dcl-s l_fnames varchar(14) dim(300);

  l_up = %xlate(C_LOWER:C_UPPER:i_line);
  l_name = %trim(%subst(l_up:7:10));
  l_isCyc = (g_cycFile4 <> '' and l_name = g_cycFile4);

  // A field line or an AND/OR line with no record line before it.
  if l_name = '' and %subst(l_up:16:3) <> 'AND' and %subst(l_up:16:2) <> 'OR';
    ReviewSpec(i_lineNo:i_line:'Field line without an input record line');
    return 0;
  endif;
  if l_name = '';
    ReviewSpec(i_lineNo:i_line:'AND/OR line without an input record line');
    return 0;
  endif;

  // The block: the field lines, and AND/OR lines (not converted) after the
  // record line.
  l_last = 0;
  l_k = i_index + 1;
  dow l_k <= SrcCount();
    l_next = SrcLine(l_k);
    l_nextUp = %xlate(C_LOWER:C_UPPER:l_next);
    if %subst(l_nextUp:6:1) <> 'I' or %subst(l_nextUp:7:1) = '*'
       or %subst(l_nextUp:7:1) = '/';
      leave;
    endif;
    if %trim(%subst(l_nextUp:7:10)) <> '';
      leave;
    endif;
    if %subst(l_nextUp:16:3) = 'AND' or %subst(l_nextUp:16:2) = 'OR';
      l_multi = *on;
    endif;
    l_last += 1;
    l_k += 1;
  enddo;

  l_file = FlFind(l_name);
  l_dsName = l_name + '_REC';
  select;
    when l_multi;
      l_reason = 'More than one record type (AND/OR lines) is not supported in '
                 + 'free-form';
    when l_last > 250;
      l_reason = 'The record layout has more than 250 lines';
    when l_file = 0;
      l_reason = 'File ' + l_name + ' is not declared by a converted F '
                 + 'specification';
    when g_flLen(l_file) = 0;
      l_reason = 'File ' + l_name + ' is externally described: field renames and '
                 + 'field indicators are not converted yet';
    when g_flDevice(l_file) <> 'DISK' and g_flDevice(l_file) <> 'SEQ'
         and g_flDevice(l_file) <> 'WORKSTN';
      l_reason = 'File ' + l_name + ' is not a DISK, SEQ or WORKSTN file';
    when g_flType(l_file) <> 'I' and g_flType(l_file) <> 'U'
         and g_flType(l_file) <> 'C';
      l_reason = 'File ' + l_name + ' is not an input, update or combined file';
    when g_flLayout(l_file);
      l_reason = 'File ' + l_name + ' already has a record layout (more than one '
                 + 'record type)';
    when %subst(l_up:21:2) = '**';
      l_reason = 'Look-ahead fields are not supported in free-form';
    when %trim(%subst(l_up:21:2)) <> ''
         and not (l_isCyc and %check('0123456789':%subst(l_up:21:2)) = 0
                  and %subst(l_up:21:2) <> '00');
      l_reason = 'Record identifying indicator ' + %trim(%subst(l_up:21:2))
                 + ' is not set by free-form I/O (only 01 to 99 of the primary file '
                 + 'of the cycle skeleton)';
    when %trim(%subst(l_up:23:24)) <> '';
      l_reason = 'Record identification codes (more than one record type) are not '
                 + 'supported in free-form';
    when %trim(%subst(l_up:19:2)) <> '' or (%subst(l_up:17:2) <> '  '
         and %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ':%subst(l_up:17:2)) > 0);
      l_reason = 'Sequence checking (columns 17-20) is not supported in free-form';
  endsl;
  if l_reason <> '';
    ReviewWithContinuations(i_index:i_lineNo:i_line:l_last:l_reason);
    return l_last;
  endif;
  l_recLen = g_flLen(l_file);

  l_outCount += 1;
  l_out(l_outCount) = 'dcl-ds ' + l_dsName + ' len(' + %char(l_recLen) + ');';
  l_outNo(l_outCount) = i_lineNo;
  for l_k = 1 to l_last;
    l_next = SrcLine(i_index + l_k);
    l_nextUp = %xlate(C_LOWER:C_UPPER:l_next);
    l_ok(l_k) = InputField4(l_next:l_recLen:l_stmt:l_fieldReason:l_isCyc:l_lvl
                            :l_fname);
    l_lvls(l_k) = l_lvl;
    l_fnames(l_k) = l_fname;
    if l_ok(l_k);
      l_fields += 1;
      l_outCount += 1;
      l_out(l_outCount) = l_stmt;
      l_outNo(l_outCount) = SrcLineNo(i_index + l_k);
    else;
      l_reasons(l_k) = l_fieldReason;
      l_outCount += 1;
      l_out(l_outCount) = '// ' + %trimr(%subst(l_next:6:69));
      l_outNo(l_outCount) = SrcLineNo(i_index + l_k);
    endif;
  endfor;
  if l_fields = 0;
    ReviewWithContinuations(i_index:i_lineNo:i_line:l_last
                            :'No subfield could be converted');
    return l_last;
  endif;
  l_outCount += 1;
  l_out(l_outCount) = 'end-ds;';
  l_outNo(l_outCount) = SrcLineNo(i_index + l_last);
  for l_k = 1 to l_outCount;
    AddOut(l_out(l_k):l_outNo(l_k));
  endfor;
  g_flLayout(l_file) = *on;
  AddSym(l_dsName:'ds');
  // FREE-60: the record layout of the primary file and its control fields go to the
  // cycle skeleton (IAfreeCalc reads them through CycleInfo and CycleControl).
  if l_isCyc;
    CvtSetLayout(l_name);
    // FREE-62: the record identifying indicator of the primary file (01 to 99).
    if %trim(%subst(l_up:21:2)) <> '';
      CvtAddType(%subst(l_up:21:2));
    endif;
    for l_k = 1 to l_last;
      if l_ok(l_k) and l_lvls(l_k) > 0;
        CvtAddControl(l_fnames(l_k):l_lvls(l_k));
      endif;
    endfor;
  endif;

  RptItem(C_STS_ASSUMPTION:i_lineNo:%trimr(%subst(i_line:6:75))
          :'record layout of the file declared as a data structure: READ and '
          + 'CHAIN of the file name it');
  for l_k = 1 to l_last;
    l_next = SrcLine(i_index + l_k);
    if l_ok(l_k);
      RptItem(C_STS_CONVERTED:SrcLineNo(i_index + l_k):%trimr(%subst(l_next:6:75)):'');
    else;
      RptItem(C_STS_REVIEW:SrcLineNo(i_index + l_k):%trimr(%subst(l_next:6:75))
              :l_reasons(l_k));
    endif;
  endfor;
  g_lastLineNo = SrcLineNo(i_index + l_last);
  return l_last;
end-proc;

// ------------------------------------------------------------------
// P: procedure specification. B starts DCL-PROC, E ends it.
dcl-proc ConvertP;
  dcl-pi *n int(10);
    i_index int(10) const;
    i_lineNo int(10) const;
    i_line char(100) const;
    i_longName varchar(150) const options(*nopass);
  end-pi;

  dcl-s l_kwText varchar(1200);
  dcl-s l_extra int(10);
  dcl-s l_name varchar(150);
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
  if %parms >= 4;
    l_name = i_longName;
  endif;
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
    o_reason varchar(190);
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
    i_longName varchar(150) const options(*nopass);
  end-pi;

  dcl-s l_kwText varchar(1200);
  dcl-s l_extra int(10);
  dcl-s l_name varchar(150);
  dcl-s l_ext varchar(1);
  dcl-s l_dsType varchar(1);
  dcl-s l_defType varchar(2);
  dcl-s l_from varchar(7);
  dcl-s l_to varchar(7);
  dcl-s l_dtype char(1);
  dcl-s l_dec varchar(2);
  dcl-s l_comment varchar(20);
  dcl-s l_head varchar(10);
  dcl-s l_nameOut varchar(155);
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
  dcl-s l_dtExt varchar(150);

  if not CollectKeywords('D':i_index:i_line:l_kwText:l_extra);
    ReviewWithContinuations(i_index:i_lineNo:i_line:l_extra
                            :'A literal continued with + or - is not converted');
    return l_extra;
  endif;
  SplitKeywords(l_kwText);
  g_quoted = *off;

  l_name = Txt('D':'NAME':i_line);
  if %parms >= 4;
    l_name = i_longName;
  endif;
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
  // *DTAARA DEFINE of the C specifications: the DTAARA keyword (RV-11).
  if l_name <> '' and (l_head = 'dcl-s' or l_head = 'dcl-ds') and not l_isSub
     and KwFind('DTAARA') = 0 and l_dsType = '';
    l_dtExt = DefineDtaara(l_name);
    if l_dtExt <> '' and g_dtCount < 50;
      l_stmt += ' dtaara(' + C_QUOTE + l_dtExt + C_QUOTE + ')';
      g_dtCount += 1;
      g_dtName(g_dtCount) = Up(l_name);
    endif;
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

  // Remember the arrays and their sequence for LOOKUP (RV-53).
  if l_name <> '' and (l_head = 'dcl-s' or l_head = 'dcl-subf')
     and KwFind('DIM') > 0 and g_arrCount < C_MAXARR;
    g_arrCount += 1;
    g_arrName(g_arrCount) = Up(l_name);
    g_arrDim(g_arrCount) = Up(KwParam(KwFind('DIM')));
    select;
      when KwFind('DESCEND') > 0;
        g_arrSeq(g_arrCount) = 'D';
      when KwFind('ASCEND') > 0;
        g_arrSeq(g_arrCount) = 'A';
      other;
        g_arrSeq(g_arrCount) = ' ';
    endsl;
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

// The group of a skip written by IAfreeCalc after an SQL statement (RV-37): the
// TAG of the jump closes it like any other skip of ConvertJumpC ('J').
dcl-proc Fx4SkipOpen export;
  dcl-pi *n ind;
    i_open ind const;
  end-pi;

  // *OFF when the group stack is full (CPush would do nothing): nothing may be
  // written then, or the IF would have no ENDIF. With i_open *off only the room is
  // tested: the IF is written first (at the depth before the group) and the group
  // is opened after it, as ConvertJumpC does.
  if g_depth >= 60;
    return *off;
  endif;
  if i_open;
    CPush('J');
  endif;
  return *on;
end-proc;

// ------------------------------------------------------------------
dcl-proc Fx4ScanJumps export;
  dcl-pi *n;
  end-pi;

  if not g_jvScanned;
    ScanJumps();
  endif;
end-proc;

// ------------------------------------------------------------------
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
    i_name varchar(150) const;
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
// The length column of DEFINE *LIKE: blank, or +n or -n (blanks allowed between
// the sign and the digits). o_delta is the signed change; returns *off when the
// text is not valid.
dcl-proc LengthDelta;
  dcl-pi *n ind;
    i_text varchar(10) const;
    o_delta int(10);
  end-pi;

  dcl-s l_t varchar(10);
  dcl-s l_sign char(1);

  o_delta = 0;
  l_t = %scanrpl(' ':'':i_text);
  if l_t = '';
    return *on;
  endif;
  l_sign = %subst(l_t:1:1);
  if (l_sign <> '+' and l_sign <> '-') or %len(l_t) < 2
     or %check(C_DIGITS:%subst(l_t:2)) > 0;
    return *off;
  endif;
  o_delta = %int(%subst(l_t:2));
  if l_sign = '-';
    o_delta = -o_delta;
  endif;
  return *on;
end-proc;

// ------------------------------------------------------------------
dcl-proc DeltaText;
  dcl-pi *n varchar(12);
    i_delta int(10) const;
  end-pi;

  if i_delta < 0;
    return '-' + %char(-i_delta);
  endif;
  return '+' + %char(i_delta);
end-proc;

// ------------------------------------------------------------------
// The type text with its length changed by i_delta (length adjustment of
// DEFINE *LIKE, SC09-2508: character and numeric fields only). Returns '' when
// the type is not char, packed or zoned or the new length is not valid.
dcl-proc AdjustType;
  dcl-pi *n varchar(60);
    i_text varchar(60) const;
    i_delta int(10) const;
  end-pi;

  dcl-s l_kind char(1);
  dcl-s l_len int(10);
  dcl-s l_dec int(10);
  dcl-s l_word varchar(20);
  dcl-s l_new int(10);

  l_word = %subst(i_text:1:%max(%scan('(':i_text) - 1:0));
  if l_word <> 'char' and l_word <> 'packed' and l_word <> 'zoned';
    return '';
  endif;
  ParseType(i_text:l_kind:l_len:l_dec);
  if l_kind <> 'C' and l_kind <> 'N';
    return '';
  endif;
  l_new = l_len + i_delta;
  if l_new < 1 or (l_word = 'char' and l_new > 16773100)
     or (l_word <> 'char' and (l_new > 63 or l_new <= l_dec));
    return '';
  endif;
  if l_word = 'char';
    return 'char(' + %char(l_new) + ')';
  endif;
  return l_word + '(' + %char(l_new) + ' : ' + %char(l_dec) + ')';
end-proc;

// ------------------------------------------------------------------
// The external name of the data area that a *DTAARA DEFINE of the C
// specifications gives to the field i_name (factor 2; blank: the name of the
// field); '' when there is none or the DEFINE has a length, decimals or a
// conditioning indicator.
dcl-proc DefineDtaara;
  dcl-pi *n varchar(150);
    i_name varchar(150) const;
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_line char(100);

  for l_k = 1 to SrcCount();
    l_line = SrcLine(l_k);
    if IsCOp(l_line) and OpOf(l_line) = 'DEFN'
       and Up(Txt('C':'FACTOR1':l_line)) = '*DTAARA'
       and Up(Txt('C':'RESULT':l_line)) = Up(i_name)
       and Txt('C':'LENGTH':l_line) = '' and Txt('C':'DECIMALS':l_line) = ''
       and Txt('C':'IND1':l_line) = '';
      if Txt('C':'FACTOR2':l_line) = '';
        return Up(i_name);
      endif;
      return Up(Txt('C':'FACTOR2':l_line));
    endif;
  endfor;
  return '';
end-proc;

// ------------------------------------------------------------------
// True when ConvertD wrote a DTAARA keyword for the field.
dcl-proc DtaaraApplied;
  dcl-pi *n ind;
    i_name varchar(150) const;
  end-pi;

  dcl-s l_k int(10);

  for l_k = 1 to g_dtCount;
    if g_dtName(l_k) = Up(i_name);
      return *on;
    endif;
  endfor;
  return *off;
end-proc;

// ------------------------------------------------------------------
// EXCEPT (RV-56): writes the record formats of the printer DDS that were made from
// the exception records (type E) of the O specifications (module IAfreeOut). The
// statements are separated by '; '.
dcl-proc ExceptStmt;
  dcl-pi *n varchar(500);
    i_f2 varchar(14) const;
    o_reason varchar(190);
  end-pi;

  dcl-s l_name varchar(10);
  dcl-s l_count int(10);
  dcl-s l_k int(10);
  dcl-s l_cond varchar(200);
  dcl-s l_after varchar(120);
  dcl-s l_before varchar(250);
  dcl-s l_one varchar(500);
  dcl-s l_text varchar(500) inz('');
  dcl-s l_n int(10);
  dcl-s l_j int(10);
  dcl-s l_why varchar(190);
  dcl-s l_tmp varchar(250) dim(40);

  o_reason = '';
  l_name = Up(i_f2);
  if %len(l_name) > 10;
    o_reason = 'EXCEPT name ' + l_name + ' is too long';
    return '';
  endif;
  l_count = OutExceptCount(l_name);
  if l_count = 0;
    o_reason = 'No exception output record named ' + l_name + ' was converted '
               + '(see the O specifications)';
    return '';
  endif;
  for l_k = 1 to l_count;
    if OutExceptDisk(l_name:l_k);
      // A record of a program described DISK or WORKSTN file: the statements
      // come from IAfreeOut, as for RPG II and RPG III (FREE-47).
      l_n = OutDiskStatements(l_name:l_k:l_tmp:l_why);
      if l_n = 0;
        o_reason = 'EXCEPT ' + l_name + ': ' + l_why;
        return '';
      endif;
      l_one = l_tmp(1);
      for l_j = 2 to l_n;
        l_one += '; ' + l_tmp(l_j);
      endfor;
    else;
      l_cond = OutExceptCond(l_name:l_k);
      l_after = OutExceptAfter(l_name:l_k);
      // FREE-58: the assignments of the fields that have a DDS name of their own
      // (array elements, UDAY, UMONTH, UYEAR, *PLACE) come before the write.
      l_before = OutExceptBefore(l_name:l_k);
      l_one = 'write ' + OutExceptFormat(l_name:l_k);
      if l_before <> '';
        l_one = l_before + '; ' + l_one;
      endif;
      if l_after <> '';
        l_one += '; ' + l_after;
      endif;
      if l_cond <> '';
        l_one = 'if ' + l_cond + '; ' + l_one + '; endif';
      endif;
    endif;
    if %len(l_text) + %len(l_one) + 2 > 500;
      o_reason = 'EXCEPT ' + l_name + ' writes too many statements for one line';
      return '';
    endif;
    if l_text <> '';
      l_text += '; ';
    endif;
    l_text += l_one;
  endfor;
  return l_text;
end-proc;

// ------------------------------------------------------------------
// For the DDS of the output records (IAfreeOut): kind, length and decimal positions
// of a character, varying or packed/zoned field of the D specifications or of a
// result field.
dcl-proc Fx4FieldInfo export;
  dcl-pi *n ind;
    i_name varchar(14) const;
    o_kind char(1);
    o_length int(10);
    o_decimals int(10);
  end-pi;

  dcl-s l_type varchar(60);
  dcl-s l_kind char(1);
  dcl-s l_len int(10);
  dcl-s l_dec int(10);

  l_type = SymType(i_name);
  if l_type = '';
    return *off;
  endif;
  ParseType(l_type:l_kind:l_len:l_dec);
  select;
    when l_kind = 'C' or l_kind = 'V';
      o_kind = 'C';
    when l_kind = 'N' and (%subst(l_type:1:6) = 'packed' or %subst(l_type:1:5) = 'zoned');
      o_kind = 'N';
    other;
      return *off;
  endsl;
  o_length = l_len;
  o_decimals = l_dec;
  return *on;
end-proc;

// ------------------------------------------------------------------
// MOVEA of whole arrays of the D specifications (SC09-2508): the same DIM and the
// same element type, or *BLANK(S) and *ZERO(S) to an array. An index, a field
// instead of an array and arrays of another size or type are not converted.
dcl-proc MoveaStmt;
  dcl-pi *n varchar(300);
    i_f2 varchar(14) const;
    i_res varchar(14) const;
    o_reason varchar(190);
  end-pi;

  dcl-s l_kR int(10);
  dcl-s l_kS int(10);
  dcl-s l_kind char(1);
  dcl-s l_len int(10);
  dcl-s l_dec int(10);
  dcl-s l_up varchar(14);

  o_reason = '';
  l_up = Up(i_f2);
  if %scan('(':i_f2) > 0 or %scan('(':i_res) > 0;
    o_reason = 'MOVEA with an array index is not converted';
    return '';
  endif;
  l_kR = ArrayFind(i_res);
  if l_kR = 0 or SymType(i_res) = '';
    o_reason = 'MOVEA to ' + i_res + ': not an array of the D specifications';
    return '';
  endif;
  ParseType(SymType(i_res):l_kind:l_len:l_dec);
  select;
    when l_up = '*BLANK' or l_up = '*BLANKS';
      if l_kind = 'C' or l_kind = 'V';
        return i_res + ' = *blanks';
      endif;
      o_reason = 'MOVEA of *BLANK needs an alphanumeric array';
      return '';
    when l_up = '*ZERO' or l_up = '*ZEROS';
      return i_res + ' = *zeros';
  endsl;
  l_kS = ArrayFind(i_f2);
  if l_kS = 0 or SymType(i_f2) = '';
    o_reason = 'MOVEA from ' + i_f2 + ': not an array of the D specifications '
               + '(MOVEA from a field is not converted)';
    return '';
  endif;
  if g_arrDim(l_kS) <> g_arrDim(l_kR);
    o_reason = 'MOVEA between arrays of a different DIM is not converted';
    return '';
  endif;
  if SymType(i_f2) <> SymType(i_res);
    o_reason = 'MOVEA between arrays of a different element type or length is '
               + 'not converted';
    return '';
  endif;
  return i_res + ' = ' + i_f2;
end-proc;

// ------------------------------------------------------------------
// MOVE and MOVEL (SC09-2508, the operation codes): converted only when both
// fields are declared in this source, have a known type and the result is the
// same as an assignment or a %SUBST of it (MOVE(P) may give two statements
// separated by '; '). Returns the statement, or '' with
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
        // MOVE(P): the result is blanked, the source ends at its last position.
        if l_sLen >= l_rLen;
          if l_sLen = l_rLen;
            return i_res + ' = ' + i_f2;
          endif;
          return i_res + ' = %subst(' + i_f2 + ':' + %char(l_sLen - l_rLen + 1)
                 + ')';
        endif;
        return i_res + ' = *blanks; %subst(' + i_res + ':'
               + %char(l_rLen - l_sLen + 1) + ':' + %char(l_sLen) + ') = ' + i_f2;
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
    o_post varchar(400);
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

    when i_op = 'XLATE';
      if i_f1 = '' or i_f2 = '' or i_res = '' or l_b = '' or i_found <> '';
        o_reason = 'XLATE needs from:to in factor 1, a string in factor 2 and a '
                   + 'result field, and has no found indicator';
        return '';
      endif;
      l_expr = '%xlate(' + l_a + ':' + l_b + ':' + l_c;
      if l_d <> '';
        l_expr += ':' + l_d;
      endif;
      l_expr += ')';
      return i_res + ' = ' + l_expr;

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
         or i_op = 'SUBST' or i_op = 'XLATE';
end-proc;


// ------------------------------------------------------------------
// CALL, PARM and PLIST (FREE-10): a CALL of a literal program name with its
// PARM lines (or the PARM lines of a PLIST) becomes a prototype with EXTPGM,
// written before the first calculation, and a CALLP.

// The PARM lines that follow the line at i_index (consecutive C lines). Returns
// their number; the entries are in g_pF1, g_pF2 and g_pRes.
dcl-proc ReadParms;
  dcl-pi *n int(10);
    i_index int(10) const;
  end-pi;

  dcl-s l_next int(10);
  dcl-s l_line char(100);

  g_pCount = 0;
  l_next = i_index + 1;
  dow l_next <= SrcCount();
    l_line = SrcLine(l_next);
    if not IsCOp(l_line) or OpOf(l_line) <> 'PARM';
      leave;
    endif;
    if g_pCount < C_MAXPARM;
      g_pCount += 1;
      g_pF1(g_pCount) = Txt('C':'FACTOR1':l_line);
      g_pF2(g_pCount) = Txt('C':'FACTOR2':l_line);
      g_pRes(g_pCount) = Txt('C':'RESULT':l_line);
    endif;
    l_next += 1;
  enddo;
  return l_next - i_index - 1;
end-proc;

// ------------------------------------------------------------------
// The source index of the first line after the PLIST with this name, or 0.
dcl-proc FindPlist;
  dcl-pi *n int(10);
    i_name varchar(14) const;
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_line char(100);

  for l_k = 1 to SrcCount();
    l_line = SrcLine(l_k);
    if IsCOp(l_line) and OpOf(l_line) = 'PLIST'
       and Up(Txt('C':'FACTOR1':l_line)) = Up(i_name);
      return l_k;
    endif;
  endfor;
  return 0;
end-proc;

// ------------------------------------------------------------------
// Reads the parameters of the CALL at i_index (its own PARM lines, or the
// PLIST named in the result field). Returns '' or the reason it fails.
dcl-proc CallParms;
  dcl-pi *n varchar(150);
    i_index int(10) const;
    i_plist varchar(14) const;
    o_extra int(10);
  end-pi;

  dcl-s l_pl int(10);

  o_extra = 0;
  if i_plist = '';
    o_extra = ReadParms(i_index);
    return '';
  endif;
  l_pl = FindPlist(i_plist);
  if l_pl = 0;
    return 'PLIST ' + i_plist + ' is not defined';
  endif;
  if Up(Txt('C':'FACTOR1':SrcLine(l_pl))) = '*ENTRY';
    return 'The PLIST *ENTRY is not a parameter list for CALL';
  endif;
  ReadParms(l_pl);
  return '';
end-proc;

// ------------------------------------------------------------------
// Program name of a CALL (a literal without library), as a free-form name.
dcl-proc ProgramName;
  dcl-pi *n varchar(10);
    i_f2 varchar(14) const;
  end-pi;

  dcl-s l_name varchar(14);

  if %len(i_f2) < 3 or %subst(i_f2:1:1) <> C_QUOTE
     or %subst(i_f2:%len(i_f2):1) <> C_QUOTE;
    return '';
  endif;
  l_name = Up(%subst(i_f2:2:%len(i_f2) - 2));
  if %len(l_name) > 10 or %check(C_UPPER + C_DIGITS + '_#@$':l_name) > 0
     or %check(C_UPPER + '#@$':%subst(l_name:1:1)) > 0;
    return '';
  endif;
  return l_name;
end-proc;

// ------------------------------------------------------------------
// The parameter types of the parameters read last: '' with o_reason when a type
// is not known. The signature is the types joined with ';'.
dcl-proc ParmSignature;
  dcl-pi *n varchar(300);
    o_reason varchar(150);
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_type varchar(60);
  dcl-s l_sig varchar(300) inz('');

  o_reason = '';
  for l_k = 1 to g_pCount;
    if g_pRes(l_k) = '';
      o_reason = 'PARM without a result field';
      return '';
    endif;
    l_type = SymType(g_pRes(l_k));
    if l_type = '';
      o_reason = 'Parameter ' + g_pRes(l_k) + ' is not declared in this source';
      return '';
    endif;
    if l_k > 1;
      l_sig += ';';
    endif;
    l_sig += l_type;
  endfor;
  return l_sig;
end-proc;

// ------------------------------------------------------------------
// Before the first calculation: one DCL-PR for each program that is called with
// the same parameter types every time.
dcl-proc WritePrototypes;
  dcl-pi *n;
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_line char(100);
  dcl-s l_name varchar(10);
  dcl-s l_sig varchar(300);
  dcl-s l_reason varchar(150);
  dcl-s l_extra int(10);
  dcl-s l_plist varchar(14);
  dcl-s l_p int(10);
  dcl-s l_rest varchar(300);
  dcl-s l_semi int(10);
  dcl-s l_f int(10);
  dcl-s l_known ind;
  dcl-s l_delta int(10);

  g_protoCount = 0;
  for l_k = 1 to SrcCount();
    l_line = SrcLine(l_k);
    if IsCOp(l_line) and OpOf(l_line) = 'DEFN'
       and Up(Txt('C':'FACTOR1':l_line)) = '*LIKE'
       and SymType(Txt('C':'FACTOR2':l_line)) <> ''
       and Txt('C':'RESULT':l_line) <> ''
       and SymType(Txt('C':'RESULT':l_line)) = ''
       and Txt('C':'DECIMALS':l_line) = ''
       and LengthDelta(Txt('C':'LENGTH':l_line):l_delta)
       and (l_delta = 0 or AdjustType(SymType(Txt('C':'FACTOR2':l_line)):l_delta)
            <> '');
      if l_delta = 0;
        AddOut('dcl-s ' + Txt('C':'RESULT':l_line) + ' like('
               + Txt('C':'FACTOR2':l_line) + ');':SrcLineNo(l_k));
        AddSym(Txt('C':'RESULT':l_line):SymType(Txt('C':'FACTOR2':l_line)));
      else;
        AddOut('dcl-s ' + Txt('C':'RESULT':l_line) + ' like('
               + Txt('C':'FACTOR2':l_line) + ' : ' + DeltaText(l_delta) + ');'
               :SrcLineNo(l_k));
        AddSym(Txt('C':'RESULT':l_line)
               :AdjustType(SymType(Txt('C':'FACTOR2':l_line)):l_delta));
      endif;
      iter;
    endif;
    // DO without an index field: a hidden index, named after the line.
    if IsCOp(l_line) and OpOf(l_line) = 'DO' and Txt('C':'RESULT':l_line) = ''
       and Txt('C':'DECIMALS':l_line) = '' and Txt('C':'LENGTH':l_line) = '';
      AddOut('dcl-s DOIX' + %char(SrcLineNo(l_k)) + ' int(10);':SrcLineNo(l_k));
      iter;
    endif;
    if not IsCOp(l_line) or OpOf(l_line) <> 'CALL';
      iter;
    endif;
    l_name = ProgramName(Txt('C':'FACTOR2':l_line));
    if l_name = '';
      iter;
    endif;
    l_plist = Txt('C':'RESULT':l_line);
    if CallParms(l_k:l_plist:l_extra) <> '';
      iter;
    endif;
    l_sig = ParmSignature(l_reason);
    if l_reason <> '';
      iter;
    endif;
    l_known = *off;
    for l_f = 1 to g_protoCount;
      if g_protoName(l_f) = l_name;
        l_known = *on;
      endif;
    endfor;
    if l_known or g_protoCount >= 40 or IsConstName(l_name);
      iter;
    endif;
    g_protoCount += 1;
    g_protoName(g_protoCount) = l_name;
    g_protoSig(g_protoCount) = l_sig;
    AddOut('dcl-pr ' + l_name + ' extpgm(''' + l_name + ''');':SrcLineNo(l_k));
    l_rest = l_sig;
    dow l_rest <> '';
      l_semi = %scan(';':l_rest);
      if l_semi = 0;
        AddOut('  dcl-parm *n ' + l_rest + ';':SrcLineNo(l_k));
        l_rest = '';
      else;
        AddOut('  dcl-parm *n ' + %subst(l_rest:1:l_semi - 1) + ';':SrcLineNo(l_k));
        l_rest = %subst(l_rest:l_semi + 1);
      endif;
    enddo;
    AddOut('end-pr;':SrcLineNo(l_k));
  endfor;
end-proc;

// ------------------------------------------------------------------
// *ON when the program was called with the same parameter types as its prototype.
dcl-proc ProtoMatches;
  dcl-pi *n ind;
    i_name varchar(10) const;
    i_sig varchar(300) const;
  end-pi;

  dcl-s l_f int(10);

  for l_f = 1 to g_protoCount;
    if g_protoName(l_f) = i_name;
      return g_protoSig(l_f) = i_sig;
    endif;
  endfor;
  return *off;
end-proc;

// ------------------------------------------------------------------
// The statements of a CALL: o_extra PARM lines were read with it.
dcl-proc CallStatements;
  dcl-pi *n varchar(1000);
    i_index int(10) const;
    i_f2 varchar(14) const;
    i_plist varchar(14) const;
    i_ext varchar(6) const;
    o_extra int(10);
    o_reason varchar(190);
  end-pi;

  dcl-s l_name varchar(10);
  dcl-s l_sig varchar(300);
  dcl-s l_reason varchar(150);
  dcl-s l_k int(10);
  dcl-s l_pre varchar(500) inz('');
  dcl-s l_post varchar(500) inz('');
  dcl-s l_args varchar(300) inz('');
  dcl-s l_call varchar(400);

  o_reason = '';
  l_name = ProgramName(i_f2);
  if l_name = '';
    o_reason = 'CALL needs a literal program name without a library';
    return '';
  endif;
  l_reason = CallParms(i_index:i_plist:o_extra);
  if l_reason <> '';
    o_reason = l_reason;
    return '';
  endif;
  l_sig = ParmSignature(l_reason);
  if l_reason <> '';
    o_reason = l_reason;
    return '';
  endif;
  if not ProtoMatches(l_name:l_sig);
    o_reason = 'Program ' + l_name + ' is called with different parameter types '
               + 'or its name is already used';
    return '';
  endif;
  for l_k = 1 to g_pCount;
    if l_k > 1;
      l_args += ' : ';
    endif;
    l_args += g_pRes(l_k);
    if g_pF1(l_k) <> '';
      if l_pre <> '';
        l_pre += '; ';
      endif;
      l_pre += g_pRes(l_k) + ' = ' + g_pF1(l_k);
    endif;
    if g_pF2(l_k) <> '';
      if l_post <> '';
        l_post += '; ';
      endif;
      l_post += g_pF2(l_k) + ' = ' + g_pRes(l_k);
    endif;
  endfor;
  l_call = 'callp' + i_ext + ' ' + l_name + '(' + l_args + ')';
  if l_pre <> '';
    l_call = l_pre + '; ' + l_call;
  endif;
  if l_post <> '';
    l_call += '; ' + l_post;
  endif;
  return l_call;
end-proc;


// ------------------------------------------------------------------
// MVR directly after a DIV without half adjust: the
// remainder is %REM of the operands of the DIV (whole numbers) or the dividend
// less quotient times divisor (decimals). Returns '' or the reason.
dcl-proc MvrCheck;
  dcl-pi *n varchar(150);
    i_index int(10) const;
    i_f1 varchar(14) const;
    i_f2 varchar(14) const;
    i_ext varchar(6) const;
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_prev int(10) inz(0);

  if i_f1 <> '' or i_f2 <> '' or i_ext <> '';
    return 'MVR with factors or an extender is not converted';
  endif;
  for l_k = i_index - 1 downto 1;
    if IsCOp(SrcLine(l_k));
      l_prev = l_k;
      leave;
    endif;
  endfor;
  if g_divIdx = 0 or l_prev <> g_divIdx;
    return 'MVR is converted only directly after its DIV';
  endif;
  if g_divHalf;
    return 'MVR after DIV with half adjust is not converted';
  endif;
  // The DIV result overwrote an operand: the dividend or divisor is lost.
  if Up(g_divF1) = Up(g_divRes) or Up(g_divF2) = Up(g_divRes);
    return 'The DIV above overwrote its dividend or divisor: MVR is not converted';
  endif;
  if not IsNumericOperand(g_divF1) or not IsNumericOperand(g_divF2)
     or not IsNumericOperand(g_divRes);
    return 'MVR needs numeric operands that are declared in this source';
  endif;
  return '';
end-proc;

// ------------------------------------------------------------------
// MVR statement: %REM when all operands of the DIV are whole numbers, else the
// remainder as the dividend less quotient times divisor (the quotient of the DIV
// is truncated to its decimal positions, so this is the remainder of RPG).
dcl-proc MvrStmt;
  dcl-pi *n varchar(300);
    i_res varchar(14) const;
    o_note varchar(190);
  end-pi;

  if IsIntegerOperand(g_divF1) and IsIntegerOperand(g_divF2)
     and IsIntegerOperand(g_divRes);
    o_note = 'MVR converted with %rem on the operands of the DIV above';
    return i_res + ' = %rem(' + g_divF1 + ' : ' + g_divF2 + ')';
  endif;
  o_note = 'MVR with decimals: dividend less quotient times divisor, check '
           + 'the decimal positions of ' + i_res;
  return i_res + ' = ' + g_divF1 + ' - ' + g_divRes + ' * ' + g_divF2;
end-proc;

// ------------------------------------------------------------------
// A numeric literal (digits, one decimal point) or a declared numeric field.
dcl-proc IsNumericOperand;
  dcl-pi *n ind;
    i_text varchar(14) const;
  end-pi;

  dcl-s l_kind char(1);
  dcl-s l_len int(10);
  dcl-s l_dec int(10);

  if %len(i_text) > 0 and %check(C_DIGITS + '.':i_text) = 0;
    return *on;
  endif;
  if SymType(i_text) = '';
    return *off;
  endif;
  ParseType(SymType(i_text):l_kind:l_len:l_dec);
  return l_kind = 'N';
end-proc;

// ------------------------------------------------------------------
dcl-proc IsIntegerOperand;
  dcl-pi *n ind;
    i_text varchar(14) const;
  end-pi;

  dcl-s l_kind char(1);
  dcl-s l_len int(10);
  dcl-s l_dec int(10);

  if %len(i_text) > 0 and %check(C_DIGITS:i_text) = 0;
    return *on;
  endif;
  if SymType(i_text) = '';
    return *off;
  endif;
  ParseType(SymType(i_text):l_kind:l_len:l_dec);
  return l_kind = 'N' and l_dec = 0;
end-proc;

// ------------------------------------------------------------------
// TESTN: NU (columns 71-72) all digits, BN (73-74) blanks and then digits,
// BL (75-76) all blanks. '; ' separated statements.
dcl-proc TestnStmts;
  dcl-pi *n varchar(400);
    i_line char(100) const;
    i_res varchar(14) const;
    o_reason varchar(190);
  end-pi;

  dcl-s l_out varchar(400) inz('');
  dcl-s l_ind varchar(2);
  dcl-s l_k int(10);
  dcl-s l_test varchar(160);

  o_reason = '';
  if i_res = '' or SymType(i_res) = '' or %subst(SymType(i_res):1:4) <> 'char';
    o_reason = 'TESTN needs a declared character result field';
    return '';
  endif;
  for l_k = 1 to 3;
    select;
      when l_k = 1;
        l_ind = Txt('C':'HI':i_line);
      when l_k = 2;
        l_ind = Txt('C':'LO':i_line);
      other;
        l_ind = Txt('C':'EQ':i_line);
    endsl;
    if l_ind = '';
      iter;
    endif;
    select;
      when l_k = 1;
        l_test = '%check(''0123456789'' : ' + i_res + ') = 0';
      when l_k = 2;
        l_test = i_res + ' <> *blanks and %subst(' + i_res + ':1:1) = '' '' and '
                 + '%check(''0123456789'' : %trim(' + i_res + ')) = 0';
      other;
        l_test = i_res + ' = *blanks';
    endsl;
    if %len(l_out) > 0;
      l_out += '; ';
    endif;
    l_out += '*in' + l_ind + ' = (' + l_test + ')';
  endfor;
  if l_out = '';
    o_reason = 'TESTN needs a resulting indicator';
  endif;
  return l_out;
end-proc;

// ------------------------------------------------------------------
// BITON, BITOF, TESTB and TESTZ (RPG/400 reference; free-form %BITOR, %BITAND,
// %BITNOT). Factor 2 of the bit operations: bit numbers in apostrophes ('036'),
// a 1-byte hexadecimal literal (X'88') or a one-position character field. The
// result field must be a declared character field. '; ' separated statements;
// o_note is set when the conversion is an assumption.
dcl-proc BitStmts;
  dcl-pi *n varchar(500);
    i_op varchar(10) const;
    i_f2 varchar(14) const;
    i_res varchar(14) const;
    i_line char(100) const;
    o_reason varchar(190);
    o_note varchar(190);
  end-pi;

  dcl-c C_HEXD '0123456789ABCDEF';
  dcl-c C_BITV '128064032016008004002001';

  dcl-s l_out varchar(500) inz('');
  dcl-s l_resType varchar(30);
  dcl-s l_up varchar(14);
  dcl-s l_inner varchar(14);
  dcl-s l_seen char(8) inz('00000000');
  dcl-s l_mask int(10) inz(0);
  dcl-s l_bits int(10) inz(0);
  dcl-s l_bit int(10);
  dcl-s l_k int(10);
  dcl-s l_hex varchar(40) inz('');
  dcl-s l_inverse varchar(40) inz('');
  dcl-s l_field ind inz(*off);
  dcl-s l_and varchar(100);
  dcl-s l_zone varchar(100);
  dcl-s l_ind char(2);
  dcl-s l_test varchar(300);
  dcl-s l_slotCount int(10) inz(0);
  dcl-s l_fType varchar(30);

  o_reason = '';
  o_note = '';
  l_resType = SymType(i_res);
  if i_res = '' or l_resType = '' or %subst(l_resType:1:4) <> 'char';
    o_reason = i_op + ' needs a declared character result field';
    return '';
  endif;
  if i_op <> 'TESTZ' and l_resType <> 'char(1)';
    o_reason = 'The result field of ' + i_op + ' must be one position';
    return '';
  endif;
  if Txt('C':'LENGTH':i_line) <> '' or Txt('C':'DECIMALS':i_line) <> '';
    o_reason = i_op + ' with a length or decimals on the result field is not '
               + 'converted';
    return '';
  endif;

  // ---- factor 2 of the bit operations ----
  if i_op <> 'TESTZ';
    l_up = Up(i_f2);
    select;
      when %len(l_up) = 5 and %subst(l_up:1:2) = 'X''' and %subst(l_up:5:1) = '''';
        if %check(C_HEXD:%subst(l_up:3:2)) <> 0;
          o_reason = 'The hexadecimal literal ' + i_f2 + ' is not valid';
          return '';
        endif;
        l_mask = (%scan(%subst(l_up:3:1):C_HEXD) - 1) * 16
                 + %scan(%subst(l_up:4:1):C_HEXD) - 1;
        for l_k = 0 to 7;
          if %rem(%div(l_mask:%int(%subst(C_BITV:l_k * 3 + 1:3))):2) = 1;
            l_bits += 1;
          endif;
        endfor;
      when %len(i_f2) >= 3 and %subst(i_f2:1:1) = '''' and
           %subst(i_f2:%len(i_f2):1) = '''';
        l_inner = %subst(i_f2:2:%len(i_f2) - 2);
        if %len(l_inner) > 8 or %check('01234567':l_inner) <> 0;
          o_reason = 'The bit numbers ' + i_f2 + ' must be 1 to 8 digits from 0 to 7';
          return '';
        endif;
        for l_k = 1 to %len(l_inner);
          l_bit = %int(%subst(l_inner:l_k:1));
          if %subst(l_seen:l_bit + 1:1) = '1';
            o_reason = 'Bit number ' + %char(l_bit) + ' is repeated in ' + i_f2;
            return '';
          endif;
          %subst(l_seen:l_bit + 1:1) = '1';
          l_mask += %int(%subst(C_BITV:l_bit * 3 + 1:3));
          l_bits += 1;
        endfor;
      when SymType(i_f2) <> '';
        l_fType = SymType(i_f2);
        if l_fType <> 'char(1)';
          o_reason = 'Factor 2 ' + i_f2 + ' must be a declared one-position '
                     + 'character field';
          return '';
        endif;
        l_field = *on;
      other;
        o_reason = 'Factor 2 ' + i_f2 + ' is not converted for ' + i_op;
        return '';
    endsl;
    if l_field;
      l_hex = i_f2;
      l_inverse = '%bitnot(' + i_f2 + ')';
    else;
      l_hex = 'x''' + %subst(C_HEXD:%div(l_mask:16) + 1:1)
              + %subst(C_HEXD:%rem(l_mask:16) + 1:1) + '''';
      l_inverse = 'x''' + %subst(C_HEXD:%div(255 - l_mask:16) + 1:1)
                  + %subst(C_HEXD:%rem(255 - l_mask:16) + 1:1) + '''';
    endif;
  endif;

  // ---- BITON and BITOF set bits ----
  if i_op = 'BITON' or i_op = 'BITOF';
    if Txt('C':'HI':i_line) <> '' or Txt('C':'LO':i_line) <> ''
       or Txt('C':'EQ':i_line) <> '';
      o_reason = 'Resulting indicators are not allowed for ' + i_op;
      return '';
    endif;
    if i_op = 'BITON';
      return i_res + ' = %bitor(' + i_res + ' : ' + l_hex + ')';
    endif;
    return i_res + ' = %bitand(' + i_res + ' : ' + l_inverse + ')';
  endif;

  // ---- the tests: one expression for each resulting indicator ----
  if i_op = 'TESTB';
    l_and = '%bitand(' + i_res + ' : ' + l_hex + ')';
    if l_field;
      o_note = 'TESTB with a field in factor 2: RPG sets no indicator on when the '
               + 'field has no bit on';
    endif;
  else;
    l_zone = '%bitand(%subst(' + i_res + ':1:1) : x''F0'')';
    o_note = 'TESTZ is written on the zone of the first character as EBCDIC: & and '
             + 'A-I (zone C), - and J-R (zone D), other zones';
  endif;
  for l_k = 1 to 3;
    select;
      when l_k = 1;
        l_ind = Txt('C':'HI':i_line);
      when l_k = 2;
        l_ind = Txt('C':'LO':i_line);
      other;
        l_ind = Txt('C':'EQ':i_line);
    endsl;
    if l_ind = '';
      iter;
    endif;
    l_test = '';
    if i_op = 'TESTB';
      select;
        when l_k = 1;
          l_test = l_and + ' = x''00''';
        when l_k = 2;
          if l_bits = 1 and not l_field;
            o_reason = 'Indicator ' + l_ind + ' (bits on and off) cannot be set '
                       + 'for one bit';
            return '';
          endif;
          l_test = l_and + ' <> x''00'' and ' + l_and + ' <> ' + l_hex;
        other;
          l_test = l_and + ' = ' + l_hex;
      endsl;
    else;
      select;
        when l_k = 1;
          l_test = l_zone + ' = x''50'' or ' + l_zone + ' = x''C0''';
        when l_k = 2;
          l_test = l_zone + ' = x''60'' or ' + l_zone + ' = x''D0''';
        other;
          l_test = 'not (' + l_zone + ' = x''50'' or ' + l_zone + ' = x''C0'' or '
                   + l_zone + ' = x''60'' or ' + l_zone + ' = x''D0'')';
      endsl;
    endif;
    if %len(l_out) > 0;
      l_out += '; ';
    endif;
    l_out += '*in' + l_ind + ' = (' + l_test + ')';
    l_slotCount += 1;
  endfor;
  if l_slotCount = 0;
    o_reason = i_op + ' needs a resulting indicator';
  endif;
  return l_out;
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
// The position of an array of the D specifications in g_arrName, 0 when the
// name is not an array.
dcl-proc ArrayFind;
  dcl-pi *n int(10);
    i_name varchar(150) const;
  end-pi;

  dcl-s l_k int(10);

  for l_k = g_arrCount downto 1;
    if g_arrName(l_k) = Up(i_name);
      return l_k;
    endif;
  endfor;
  return 0;
end-proc;

// ------------------------------------------------------------------
// LOOKUP on an array (SC09-2508, LOOKUP; %LOOKUPxx): '; ' separated statements,
// '' with o_reason set when it is not converted. Resulting indicators: high (71-72),
// low (73-74), equal (75-76); high and low are not used together and need ASCEND or
// DESCEND. Equal and high or low give %lookupge / %lookuple for the index, and the
// indicators are set from the equal search first. With an index (ARR(X)) the search
// starts at X, and X is set to the position found or to 1. A table (result field)
// is not converted (%tlookup).
dcl-proc LookupStmts;
  dcl-pi *n varchar(400);
    i_f1 varchar(14) const;
    i_f2 varchar(14) const;
    i_res varchar(14) const;
    i_line char(100) const;
    o_reason varchar(190);
  end-pi;

  dcl-s l_hi varchar(2);
  dcl-s l_lo varchar(2);
  dcl-s l_eq varchar(2);
  dcl-s l_arr varchar(14);
  dcl-s l_idx varchar(14) inz('');
  dcl-s l_paren int(10);
  dcl-s l_k int(10);
  dcl-s l_fn varchar(12);
  dcl-s l_args varchar(60);
  dcl-s l_out varchar(400) inz('');

  o_reason = '';
  l_hi = Txt('C':'HI':i_line);
  l_lo = Txt('C':'LO':i_line);
  l_eq = Txt('C':'EQ':i_line);
  l_arr = Up(i_f2);
  l_paren = %scan('(':l_arr);
  if l_paren > 0;
    if %subst(l_arr:%len(l_arr):1) <> ')' or l_paren = 1
       or %len(l_arr) - l_paren < 2;
      o_reason = 'The index of ' + i_f2 + ' is not valid';
      return '';
    endif;
    l_idx = %subst(l_arr:l_paren + 1:%len(l_arr) - l_paren - 1);
    l_arr = %subst(l_arr:1:l_paren - 1);
  endif;
  l_k = ArrayFind(l_arr);
  select;
    when i_res <> '';
      o_reason = 'LOOKUP of a table (second table in the result field) is not '
                 + 'converted: use %tlookup by hand';
    when l_k = 0;
      o_reason = l_arr + ' is not an array declared by a D specification (a '
                 + 'table is not converted)';
    when i_f1 = '';
      o_reason = 'LOOKUP needs a search argument in factor 1';
    when l_hi <> '' and l_lo <> '';
      o_reason = 'High and low cannot be used together with LOOKUP';
    when l_hi = '' and l_lo = '' and l_eq = '';
      o_reason = 'LOOKUP needs a high, low or equal resulting indicator';
    when (l_hi <> '' or l_lo <> '') and g_arrSeq(l_k) = ' ';
      o_reason = 'A high or low search needs ASCEND or DESCEND on ' + l_arr;
  endsl;
  if o_reason <> '';
    return '';
  endif;

  l_args = i_f1 + ' : ' + l_arr;
  if l_idx <> '';
    l_args += ' : ' + l_idx;
  endif;
  select;
    when l_hi <> '' and l_eq <> '';
      l_fn = '%lookupge';
    when l_lo <> '' and l_eq <> '';
      l_fn = '%lookuple';
    when l_hi <> '';
      l_fn = '%lookupgt';
    when l_lo <> '';
      l_fn = '%lookuplt';
    other;
      l_fn = '%lookup';
  endsl;

  // The indicators first: they use the index as it was before the search.
  select;
    when l_eq <> '' and l_hi <> '';
      l_out = '*in' + l_eq + ' = (%lookup(' + l_args + ') > 0); *in' + l_hi
              + ' = (not *in' + l_eq + ' and %lookupgt(' + l_args + ') > 0)';
    when l_eq <> '' and l_lo <> '';
      l_out = '*in' + l_eq + ' = (%lookup(' + l_args + ') > 0); *in' + l_lo
              + ' = (not *in' + l_eq + ' and %lookuplt(' + l_args + ') > 0)';
    when l_eq <> '';
      l_out = '*in' + l_eq + ' = (%lookup(' + l_args + ') > 0)';
    when l_hi <> '';
      l_out = '*in' + l_hi + ' = (%lookupgt(' + l_args + ') > 0)';
    other;
      l_out = '*in' + l_lo + ' = (%lookuplt(' + l_args + ') > 0)';
  endsl;

  // The index is set to the position found, or to 1 (a constant does not change).
  if l_idx <> '' and not IsDigits(l_idx) and not IsConstName(l_idx);
    l_out += '; ' + l_idx + ' = %max(1 : ' + l_fn + '(' + l_args + '))';
  endif;
  return l_out;
end-proc;

// ------------------------------------------------------------------
// True when the name is not a declared file but the source has a WORKSTN file: it is
// taken as a record format of the display file (RV-12, RV-31; the DDS is not read).
dcl-proc IsDisplayFormat;
  dcl-pi *n ind;
    i_name varchar(14) const;
  end-pi;

  dcl-s l_k int(10);

  if i_name = '' or FlFind(i_name) > 0;
    return *off;
  endif;
  for l_k = 1 to g_flCount;
    if g_flDevice(l_k) = 'WORKSTN';
      return *on;
    endif;
  endfor;
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
  dcl-s l_arg varchar(16);

  o_error = *off;
  o_reason = '';
  // The built-in functions of file operations take a file name: the record format
  // of a display file (RV-12, RV-31) is not one, so no argument is written and the
  // function refers to the file of the operation just done.
  l_arg = '(' + i_f2 + ')';
  if IsDisplayFormat(i_f2);
    l_arg = '';
  endif;
  l_ind(1) = Txt('C':'HI':i_line);
  l_ind(2) = Txt('C':'LO':i_line);
  l_ind(3) = Txt('C':'EQ':i_line);
  l_isFile = i_op = 'CHAIN' or i_op = 'SETLL' or i_op = 'SETGT'
             or i_op = 'DELETE' or i_op = 'READ' or i_op = 'READE'
             or i_op = 'READP' or i_op = 'READPE' or i_op = 'WRITE'
             or i_op = 'UPDATE' or i_op = 'EXFMT' or i_op = 'OPEN'
             or i_op = 'CLOSE' or i_op = 'UNLOCK' or i_op = 'FEOD'
             or i_op = 'READC';

  for l_k = 1 to 3;
    if l_ind(l_k) = '';
      iter;
    endif;
    l_test = '';
    select;
      when l_isFile and l_k = 1 and (i_op = 'CHAIN' or i_op = 'SETLL'
           or i_op = 'SETGT' or i_op = 'DELETE');
        l_test = 'not %found' + l_arg;
      when l_isFile and l_k = 2;
        o_error = *on;
        l_test = '%error';
      when l_isFile and l_k = 3 and (i_op = 'READ' or i_op = 'READE'
           or i_op = 'READP' or i_op = 'READPE' or i_op = 'READC');
        l_test = '%eof' + l_arg;
      when l_isFile and l_k = 3 and i_op = 'SETLL';
        l_test = '%equal' + l_arg;
      when i_op = 'CALL' and l_k = 2;
        o_error = *on;
        l_test = '%error';
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
    l_text = %subst(l_text:1:l_paren - 1);
  endif;
  if l_text = 'DEFINE';
    return 'DEFN';
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
// The index of the next calculation line from i_from on, skipping comment
// lines (* in column 7); 0 when the next line that is not a comment is not
// a calculation operation line.
dcl-proc NextCalcLine;
  dcl-pi *n int(10);
    i_from int(10) const;
  end-pi;

  dcl-s l_i int(10);

  l_i = i_from;
  dow l_i <= SrcCount();
    if %subst(SrcLine(l_i):7:1) = '*';
      l_i += 1;
    else;
      if IsCOp(SrcLine(l_i));
        return l_i;
      endif;
      return 0;
    endif;
  enddo;
  return 0;
end-proc;

// ------------------------------------------------------------------
// GOTO, CABxx and TAG of the C specifications (review item RV-14). The whole source
// is given once to the planner of IAfreeCalc (skip forward, jump to the end of the
// subroutine or program, loop back, leave: see RPG-MAPPING.md); the line then
// writes what the plan decided.
dcl-proc JumpIndicator;
  dcl-pi *n varchar(40);
    i_line char(100) const;
    o_bad ind;
  end-pi;

  dcl-s l_ind varchar(2);
  dcl-s l_text varchar(40) inz('');

  o_bad = *off;
  l_ind = Up(Txt('C':'IND1':i_line));
  if l_ind = '';
    if Txt('C':'NOT1':i_line) <> '';
      o_bad = *on;
    endif;
    return '';
  endif;
  if %check(C_UPPER + C_DIGITS:l_ind) > 0 or l_ind = 'RT'
     or %subst(l_ind:1:1) = 'L';
    o_bad = *on;
    return '';
  endif;
  l_text = '*in' + l_ind;
  if Up(Txt('C':'NOT1':i_line)) = 'N';
    l_text = 'not ' + l_text;
  endif;
  return l_text;
end-proc;

// ------------------------------------------------------------------
dcl-proc IsCabOp;
  dcl-pi *n ind;
    i_op varchar(10) const;
  end-pi;

  return %len(i_op) = 5 and %subst(i_op:1:3) = 'CAB'
         and CompareSymbol(%subst(i_op:4:2)) <> '';
end-proc;

// ------------------------------------------------------------------
dcl-proc ScanJumps;
  dcl-pi *n;
  end-pi;

  dcl-s l_i int(10);
  dcl-s l_line char(100);
  dcl-s l_op varchar(10);
  dcl-s l_p varchar(15);
  dcl-s l_kind char(1);
  dcl-s l_label varchar(14);
  dcl-s l_cond varchar(300);
  dcl-s l_ind varchar(40);
  dcl-s l_bad ind;
  dcl-s l_condF ind;
  dcl-s l_word varchar(10);

  g_jvScanned = *on;
  for l_i = 1 to SrcCount();
    l_line = SrcLine(l_i);
    // A /FREE block or a CASxx: the planner cannot follow it.
    l_word = Up(%trim(%subst(l_line:7:6)));
    if %scan('/FREE':l_word) = 1;
      JumpUnsafe();
      iter;
    endif;
    // The lines of an embedded SQL statement: the WHENEVER jumps (RV-37).
    CalcSqlJumpScan(l_line:SrcLineNo(l_i));
    if %subst(%xlate(C_LOWER:C_UPPER:l_line):6:1) <> 'C'
       or %subst(l_line:7:1) = '*' or %subst(l_line:7:1) = '/'
       or %subst(l_line:7:1) = '+';
      iter;
    endif;
    l_op = OpOf(l_line);
    if l_op = '' or IsAndOr(l_op);
      iter;
    endif;
    l_p = l_op + '     ';
    l_kind = 'X';
    l_label = '';
    l_cond = '';
    l_bad = *off;
    l_condF = *off;
    select;
      when l_op = 'IF' or l_op = 'SELECT' or l_op = 'MONITOR'
           or (%subst(l_p:1:2) = 'IF'
               and CompareSymbol(%trim(%subst(l_p:3:2))) <> '');
        l_kind = 'O';
      when l_op = 'DO' or l_op = 'DOW' or l_op = 'DOU' or l_op = 'FOR'
           or ((%subst(l_p:1:3) = 'DOW' or %subst(l_p:1:3) = 'DOU')
               and CompareSymbol(%trim(%subst(l_p:4:2))) <> '');
        l_kind = 'L';
      when l_op = 'ELSE' or l_op = 'ELSEIF' or l_op = 'WHEN' or l_op = 'OTHER'
           or l_op = 'ON-ERROR'
           or (%subst(l_p:1:2) = 'WH'
               and CompareSymbol(%trim(%subst(l_p:3:2))) <> '');
        l_kind = 'M';
      when l_op = 'ENDIF' or l_op = 'ENDDO' or l_op = 'ENDFOR' or l_op = 'ENDSL'
           or l_op = 'ENDMON' or l_op = 'END';
        l_kind = 'C';
      when l_op = 'BEGSR';
        l_kind = 'S';
      when l_op = 'ENDSR';
        l_kind = 'E';
      when l_op = 'ITER' or l_op = 'LEAVE';
        l_kind = 'Z';
      when l_op = 'CAS' or (%subst(l_p:1:3) = 'CAS'
           and CompareSymbol(%trim(%subst(l_p:4:2))) <> '');
        JumpUnsafe();
      when l_op = 'GOTO' or IsCabOp(l_op);
        l_kind = 'G';
        l_ind = JumpIndicator(l_line:l_bad);
        l_condF = (l_ind <> '');
        l_cond = l_ind;
        if l_op = 'GOTO';
          l_label = Up(Txt('C':'FACTOR2':l_line));
        else;
          l_label = Up(Txt('C':'RESULT':l_line));
          l_condF = *on;
          if Txt('C':'FACTOR1':l_line) = '' or Txt('C':'FACTOR2':l_line) = ''
             or Txt('C':'HI':l_line) <> '' or Txt('C':'LO':l_line) <> ''
             or Txt('C':'EQ':l_line) <> '';
            l_bad = *on;
          else;
            if l_cond <> '';
              l_cond += ' and ';
            endif;
            l_cond += Txt('C':'FACTOR1':l_line) + ' '
                      + CompareSymbol(%subst(l_op:4:2)) + ' '
                      + Txt('C':'FACTOR2':l_line);
          endif;
        endif;
      when l_op = 'TAG';
        l_kind = 'T';
        l_label = Up(Txt('C':'FACTOR1':l_line));
        l_ind = JumpIndicator(l_line:l_bad);
        if l_ind <> '';
          l_bad = *on;
        endif;
    endsl;
    if l_kind = 'G' or l_kind = 'T';
      if l_label = '' or Txt('C':'LEVEL':l_line) <> '';
        l_bad = *on;
      endif;
    endif;
    JumpEvent(SrcLineNo(l_i):l_kind:l_label:l_condF:l_bad:l_cond);
  endfor;
end-proc;

// ------------------------------------------------------------------
// The conversion of one GOTO, CABxx or TAG line (i_op is one of them).
dcl-proc ConvertJumpC;
  dcl-pi *n;
    i_index int(10) const;
    i_lineNo int(10) const;
    i_line char(100) const;
  end-pi;

  dcl-s l_kind char(1);
  dcl-s l_act char(1);
  dcl-s l_label varchar(14);
  dcl-s l_cond varchar(300);
  dcl-s l_inSub ind;
  dcl-s l_loop ind;
  dcl-s l_loopCond varchar(300);
  dcl-s l_kEnds int(10);
  dcl-s l_unconv int(10);
  dcl-s l_n int(10);
  dcl-s l_word varchar(10);
  dcl-s l_note varchar(190);

  if not g_jvScanned;
    ScanJumps();
  endif;
  if not JumpInfo(i_lineNo:l_kind:l_act:l_label:l_cond:l_inSub:l_loop:l_loopCond
                  :l_kEnds:l_unconv);
    ReviewWithContinuations(i_index:i_lineNo:i_line:0
                            :'GOTO, CABxx or TAG outside the converted patterns '
                             + '(RV-14)');
    return;
  endif;

  if l_kind = 'T';
    // The IFs of the skips that were written end here.
    for l_n = 1 to l_kEnds;
      if g_depth > 0 and g_stack(g_depth) = 'J';
        CPop(' ');
        EmitStatement(2 * g_depth:'endif;':i_lineNo);
      endif;
    endfor;
    if l_loop;
      if l_loopCond <> '';
        EmitStatement(2 * g_depth:'dou ' + JumpNegate(l_loopCond) + ';':i_lineNo);
      else;
        EmitStatement(2 * g_depth:'dow *on;':i_lineNo);
      endif;
      CPush('L');
      ReportWithContinuations(i_index:i_lineNo:i_line:0
                              :'A TAG starts a loop that ends at the '
                               + 'jump back');
    elseif l_unconv > 0;
      ReviewWithContinuations(i_index:i_lineNo:i_line:0
                              :'A GOTO or CABxx to ' + l_label + ' is not converted');
    else;
      EmitStatement(2 * g_depth:'// TAG ' + l_label:i_lineNo);
      ReportWithContinuations(i_index:i_lineNo:i_line:0:'');
    endif;
    return;
  endif;

  select;
    when l_act = 'K';
      EmitStatement(2 * g_depth:'if ' + JumpNegate(l_cond) + ';':i_lineNo);
      CPush('J');
      ReportWithContinuations(i_index:i_lineNo:i_line:0
                              :'Jump forward to a TAG became an IF '
                               + 'around the lines up to the TAG');
    when l_act = 'B';
      if g_depth > 0 and g_stack(g_depth) = 'L';
        CPop(' ');
        EmitStatement(2 * g_depth:'enddo;':i_lineNo);
        ReportWithContinuations(i_index:i_lineNo:i_line:0
                                :'Jump back to a TAG became the end of '
                                 + 'a loop');
      else;
        ReviewWithContinuations(i_index:i_lineNo:i_line:0
                                :'GOTO, CABxx or TAG outside the converted patterns '
                                 + '(RV-14)');
      endif;
    when l_act = 'R' or l_act = 'V';
      if l_act = 'V';
        l_word = 'leave';
        l_note = 'Jump to the TAG after the loop became LEAVE';
      elseif l_inSub;
        l_word = 'leavesr';
        l_note = 'Jump to the last TAG of the subroutine became LEAVESR';
      else;
        l_word = 'return';
        l_note = 'Jump to the last TAG of the program became RETURN';
      endif;
      if l_cond = '';
        EmitStatement(2 * g_depth:l_word + ';':i_lineNo);
      else;
        EmitStatement(2 * g_depth:'if ' + l_cond + ';':i_lineNo);
        EmitStatement(2 * g_depth + 2:l_word + ';':i_lineNo);
        EmitStatement(2 * g_depth:'endif;':i_lineNo);
      endif;
      ReportWithContinuations(i_index:i_lineNo:i_line:0:l_note);
    other;
      ReviewWithContinuations(i_index:i_lineNo:i_line:0
                              :'GOTO, CABxx or TAG outside the converted patterns '
                               + '(RV-14)');
  endsl;
end-proc;

// ------------------------------------------------------------------
// FREE-60: a control level (L1 to L9, LR) in columns 7-8 of an RPG IV calculation is
// converted when the cycle skeleton is written: the line is a total calculation.
dcl-proc CycleLevelOk;
  dcl-pi *n ind;
    i_level varchar(100) const;
  end-pi;

  if not CalcCycleActive();
    return *off;
  endif;
  return i_level = 'LR' or (%len(i_level) = 2 and %subst(i_level:1:1) = 'L'
         and %check('123456789':%subst(i_level:2:1)) = 0);
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
  dcl-s l_scan int(10);
  dcl-s l_hasCmt ind inz(*off);
  dcl-s l_stmt varchar(600) inz('');
  dcl-s l_reason varchar(190) inz('');
  dcl-s l_note varchar(190) inz('');
  dcl-s l_xx varchar(2);
  dcl-s l_sym varchar(2);
  dcl-s l_indent int(10);
  dcl-s l_kind char(1) inz(' ');
  dcl-s l_dedent ind inz(*off);
  dcl-s l_wrap ind inz(*off);
  dcl-s l_sets varchar(200);
  dcl-s l_ind varchar(2);
  dcl-s l_k int(10);
  dcl-s l_val varchar(5);
  dcl-s l_half ind inz(*off);
  dcl-s l_expr varchar(100);
  dcl-s l_args varchar(300);
  dcl-s l_fi int(10);
  dcl-s l_open ind inz(*off);
  dcl-s l_post varchar(400) inz('');
  dcl-s l_back varchar(400) inz('');
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
  dcl-s l_level varchar(2) inz('');
  dcl-s l_lvlTerm varchar(8) inz('');

  if not g_klDone;
    PrescanKlist();
  endif;
  if not g_cStarted;
    g_cStarted = *on;
    WritePrototypes();
  endif;

  l_opText = Up(Txt('C':'OPERATION':i_line));
  l_paren = %scan('(':l_opText);
  if l_paren > 0;
    l_op = %subst(l_opText:1:l_paren - 1);
    l_ext = Low(%subst(l_opText:l_paren));
  else;
    l_op = l_opText;
  endif;
  if l_op = 'DEFINE';
    l_op = 'DEFN';
  endif;
  l_f1 = Txt('C':'FACTOR1':i_line);
  l_f2 = Txt('C':'FACTOR2':i_line);
  l_res = Txt('C':'RESULT':i_line);

  // GOTO, CABxx and TAG (RV-14).
  if l_op = 'GOTO' or l_op = 'TAG' or IsCabOp(l_op);
    ConvertJumpC(i_index:i_lineNo:i_line);
    return 0;
  endif;

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
    when Txt('C':'LEVEL':i_line) <> '' and not CycleLevelOk(Up(Txt('C':'LEVEL':i_line)));
      l_reason = 'Level indicator (columns 7-8) on a calculation';
    when Txt('C':'NOT1':i_line) <> '' and Txt('C':'IND1':i_line) = '';
      l_reason = 'N in column 9 without an indicator';
    when Txt('C':'IND1':i_line) <> '' and
         %check(C_UPPER + C_DIGITS:Up(Txt('C':'IND1':i_line))) > 0;
      l_reason = 'Conditioning indicator is not valid';
    when Txt('C':'IND1':i_line) <> '' and Up(Txt('C':'IND1':i_line)) = 'RT'
         and not CalcCycleActive();
      l_reason = 'Indicator RT is not converted';
    when (Txt('C':'HI':i_line) <> '' or Txt('C':'LO':i_line) <> ''
         or Txt('C':'EQ':i_line) <> '') and l_op <> 'SETON' and l_op <> 'SETOFF'
         and not IsStringOp(l_op) and l_op <> 'TESTN' and l_op <> 'TESTB'
         and l_op <> 'TESTZ' and l_op <> 'LOOKUP';
      l_post = ResultInds(l_op:l_f1:l_f2:l_res:i_line:l_err:l_reason);
      l_hasInd = l_reason = '';
    when IsAndOr(l_op);
      l_reason = 'ANDxx and ORxx are not converted yet';
  endsl;
  if l_reason = '' and l_op <> 'BEGSR' and l_op <> 'ENDSR' and l_f1 <> ''
     and l_op <> 'KLIST' and l_op <> 'COMP' and not IsStringOp(l_op)
     and l_op <> 'DEFN' and l_op <> 'CALL' and l_op <> 'PLIST' and l_op <> 'PARM'
     and l_op <> 'IN' and l_op <> 'OUT'
     and l_op <> 'LOOKUP'
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
        if l_res = '' and Txt('C':'LENGTH':i_line) = ''
           and Txt('C':'DECIMALS':i_line) = '' and l_ext = '';
          l_res = 'DOIX' + %char(i_lineNo);
          l_note = 'DO without an index field: hidden index DOIXnnn';
        endif;
        if l_res = '' or Txt('C':'LENGTH':i_line) <> ''
           or Txt('C':'DECIMALS':i_line) <> '' or l_ext <> '';
          l_reason = 'DO needs an index field that is declared elsewhere (no '
                     + 'length, decimals or extender)';
        else;
          l_stmt = 'for ' + l_res + ' = ' + l_start + ' to ' + l_limit;
          l_kind = 'F';
        endif;
      when l_op = 'MVR';
        l_reason = MvrCheck(i_index:l_f1:l_f2:l_ext);
        if l_reason = '' and (l_res = '' or Txt('C':'LENGTH':i_line) <> ''
           or Txt('C':'DECIMALS':i_line) <> '');
          l_reason = 'MVR needs a declared result field';
        endif;
        if l_reason = '';
          l_stmt = MvrStmt(l_res:l_note);
        endif;
      when l_op = 'DEFN';
        if Up(l_f1) = '*LIKE' and l_res <> '' and SymType(l_res) <> '';
          l_stmt = '';
          l_kind = 'k';
        elseif Up(l_f1) = '*DTAARA' and DtaaraApplied(l_res);
          l_stmt = '';
          l_kind = 'k';
          l_note = '*DTAARA DEFINE written as the DTAARA keyword of the field';
        else;
          if Up(l_f1) = '*DTAARA';
            l_reason = '*DTAARA DEFINE needs a stand-alone field or data structure '
                       + 'of the D specifications without length, decimals or '
                       + 'indicators: add the DTAARA keyword to ' + l_res;
          else;
            l_reason = 'DEFINE is converted for *LIKE only, with a declared '
                       + 'factor 2, a new result field and a valid length change';
          endif;
        endif;
      when l_op = 'BITON' or l_op = 'BITOF' or l_op = 'TESTB' or l_op = 'TESTZ';
        if l_ext <> '' or (l_op = 'TESTZ' and l_f2 <> '')
           or (l_op <> 'TESTZ' and l_f2 = '');
          l_reason = l_op + ' with an extender or without the right factor 2';
        else;
          l_post = BitStmts(l_op:l_f2:l_res:i_line:l_reason:l_note);
        endif;
        l_stmt = '';
      when l_op = 'TESTN';
        l_post = TestnStmts(i_line:l_res:l_reason);
        l_stmt = '';
        l_note = 'TESTN approximated with %check: check the blank rules';
      when l_op = 'LOOKUP';
        if l_ext <> '' or Txt('C':'LENGTH':i_line) <> ''
           or Txt('C':'DECIMALS':i_line) <> '';
          l_reason = 'LOOKUP with an extender, length or decimals is not converted';
        else;
          l_post = LookupStmts(l_f1:l_f2:l_res:i_line:l_reason);
          l_note = 'LOOKUP converted with %lookup: the search argument must have '
                   + 'the type and length of the array entries';
        endif;
        l_stmt = '';
      when l_op = 'CALL';
        if l_f1 <> '' or Txt('C':'LENGTH':i_line) <> ''
           or (l_ext <> '' and l_ext <> '(e)');
          l_reason = 'CALL with factor 1, length or an extender other than (E)';
        else;
          // The error indicator (columns 73-74) is tested after the call.
          l_back = l_post;
          if l_err and l_ext = '';
            l_ext = '(e)';
          endif;
          l_post = CallStatements(i_index:l_f2:l_res:l_ext:l_k:l_reason);
          if l_back <> '' and l_reason = '';
            l_post += '; ' + l_back;
          endif;
          l_extra += l_k;
          l_stmt = '';
          l_note = 'CALL converted to a CALLP of a prototype written before the '
                   + 'calculations: parameters are passed by reference as before';
        endif;
      when l_op = 'PLIST';
        if Up(l_f1) = '*ENTRY' or l_f1 = '';
          l_reason = 'PLIST *ENTRY: declare the parameters of the program with '
                     + 'dcl-pi by hand';
        else;
          l_extra += ReadParms(i_index);
          l_kind = 'k';
        endif;
      when l_op = 'PARM';
        l_reason = 'PARM without a CALL or PLIST before it';
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
          l_scan = NextCalcLine(i_index + 1);
          if l_scan > 0;
            l_open = IsAndOr(OpOf(SrcLine(l_scan)));
          endif;
          if l_open;
            l_stmt += ' (' + l_f1 + ' ' + l_sym + ' ' + l_f2 + ')';
          else;
            l_stmt += ' ' + l_f1 + ' ' + l_sym + ' ' + l_f2;
          endif;
          l_next = i_index + 1;
          // Comment lines between the header and its ANDxx or ORxx lines are
          // skipped; they are written after the header (see l_hasCmt).
          dou *off;
            l_scan = NextCalcLine(l_next);
            if l_scan = 0 or not IsAndOr(OpOf(SrcLine(l_scan)));
              leave;
            endif;
            l_andLine = SrcLine(l_scan);
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
            if l_scan > l_next;
              l_hasCmt = *on;
            endif;
            l_extra += l_scan - l_next + 1;
            l_next = l_scan + 1;
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
            g_divIdx = i_index;
            g_divF1 = l_f1;
            if l_f1 = '';
              g_divF1 = l_res;
            endif;
            g_divF2 = l_f2;
            g_divRes = l_res;
            g_divHalf = l_half;
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
            l_note = 'String operation converted: the unused part of the result is '
                     + 'not padded the same way, check';
          endif;
        endif;
      when l_op = 'IN' or l_op = 'OUT';
        if (l_f1 <> '' and Up(l_f1) <> '*LOCK') or l_f2 = '' or l_res <> ''
           or Txt('C':'LENGTH':i_line) <> '' or Txt('C':'DECIMALS':i_line) <> '';
          l_reason = l_op + ' needs a data area in factor 2, *LOCK or nothing in '
                     + 'factor 1 and no result field';
        else;
          l_stmt = Low(l_op) + l_ext;
          if l_f1 <> '';
            l_stmt += ' *lock';
          endif;
          if Up(l_f2) = '*DTAARA';
            l_stmt += ' *dtaara';
          else;
            l_stmt += ' ' + l_f2;
          endif;
        endif;
      when l_op = 'EXCEPT';
        if l_f1 <> '' or l_res <> '' or Txt('C':'LENGTH':i_line) <> ''
           or Txt('C':'DECIMALS':i_line) <> '' or l_ext <> '';
          l_reason = 'EXCEPT with factor 1, a result field or an extender is not '
                     + 'converted';
        else;
          l_stmt = ExceptStmt(l_f2:l_reason);
          if l_reason = '' and %scan('; ':l_stmt) > 0;
            l_post = l_stmt;
            l_stmt = '';
          endif;
        endif;
      when l_op = 'MOVEA';
        if l_f1 <> '' or l_f2 = '' or l_res = ''
           or Txt('C':'LENGTH':i_line) <> '' or Txt('C':'DECIMALS':i_line) <> ''
           or l_ext <> '';
          l_reason = 'MOVEA with factor 1, extender, length or without both '
                     + 'arrays is not converted';
        else;
          l_stmt = MoveaStmt(l_f2:l_res:l_reason);
          if l_reason = '' and l_stmt <> '';
            l_note = 'MOVEA of whole arrays converted: check';
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
            l_note = 'MOVE or MOVEL converted from the declared field types: check';
          endif;
          // Two statements (MOVE(P) to a longer result): written one by one.
          if %scan('; ':l_stmt) > 0;
            l_post = l_stmt;
            l_stmt = '';
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
           or l_op = 'UNLOCK' or l_op = 'FEOD' or l_op = 'EXFMT' or l_op = 'READC';
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
        // A program described file with an I specification: the result is its
        // record data structure.
        if l_res = '' and (l_op = 'CHAIN' or l_op = 'READE' or l_op = 'READPE'
           or l_op = 'READ' or l_op = 'READP' or l_op = 'UPDATE');
          l_fi = FlFind(l_f2);
          if l_fi > 0;
            if g_flLayout(l_fi);
              l_res = Up(l_f2) + '_REC';
            endif;
          endif;
        endif;
        if l_res <> '' and (l_op = 'CHAIN' or l_op = 'READE' or l_op = 'READPE'
           or l_op = 'READ' or l_op = 'READP' or l_op = 'WRITE' or l_op = 'UPDATE'
           or l_op = 'EXFMT' or l_op = 'READC');
          l_args += ' ' + l_res;
        elseif l_res <> '';
          l_reason = 'Result field on ' + l_op + ' is not converted';
        endif;
        l_stmt += ' ' + l_args;
      when l_op = 'ACQ' or l_op = 'REL' or l_op = 'NEXT' or l_op = 'POST';
        l_reason = l_op + ' (multiple device files and WORKSTN) has no free-form '
                   + 'equivalent that is converted';
      other;
        l_reason = 'Operation ' + l_op + ' is not converted yet (RPG IV)';
    endsl;
  endif;

  // A conditioning indicator wraps the statement in IF ... ENDIF; a group
  // operation cannot be wrapped this way.
  if l_reason = '' and Txt('C':'IND1':i_line) <> '';
    if l_kind = 'I' or l_kind = 'L' or l_kind = 'F';
      // IFxx, DOWxx, DOUxx, DO: an outer IF skips the whole group when the
      // indicator is off; its ENDIF follows the END of the group.
      l_wrap = *on;
      l_cond = '*in' + Up(Txt('C':'IND1':i_line));
      if Up(Txt('C':'NOT1':i_line)) = 'N';
        l_cond = 'not ' + l_cond;
      endif;
    elseif l_kind <> ' ' and l_kind <> 'k';
      l_reason = 'Conditioning indicator on ' + l_op + ' is not converted';
    else;
      l_cond = '*in' + Up(Txt('C':'IND1':i_line));
      if Up(Txt('C':'NOT1':i_line)) = 'N';
        l_cond = 'not ' + l_cond;
      endif;
    endif;
  endif;

  // FREE-60: a total calculation (control level in columns 7-8) runs when the level
  // indicator is on: the cycle skeleton calls IA_TOTALS for it.
  l_level = Up(Txt('C':'LEVEL':i_line));
  if l_reason = '' and l_level <> '';
    l_lvlTerm = '*in' + Low(l_level);
    if l_kind = 'I' or l_kind = 'L' or l_kind = 'F';
      l_reason = 'Level indicator on ' + l_op + ' (a group operation) is not converted';
    elseif l_kind <> ' ' and l_kind <> 'k';
      l_reason = 'Level indicator on ' + l_op + ' is not converted';
    elseif l_cond <> '';
      l_cond = l_lvlTerm + ' and ' + l_cond;
    else;
      l_cond = l_lvlTerm;
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
  if l_wrap;
    EmitStatement(l_indent:'if ' + l_cond + ';':i_lineNo);
    CPush('X');
    l_indent += 2;
    l_cond = '';
  endif;
  l_base = l_indent;
  if l_cond <> '' and (l_stmt <> '' or l_post <> '');
    EmitStatement(l_base:'if ' + l_cond + ';':i_lineNo);
    l_indent += 2;
  endif;
  if l_stmt <> '';
    EmitStatement(l_indent:l_stmt + ';':i_lineNo);
  endif;
  if l_hasCmt;
    for l_k = 1 to l_extra;
      if %subst(SrcLine(i_index + l_k):7:1) = '*';
        AddOut(Pad(l_indent) + '//' + %trimr(%subst(SrcLine(i_index + l_k):8:73))
               :SrcLineNo(i_index + l_k));
      endif;
    endfor;
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
  if l_kind = '-' and l_stmt <> 'endsr' and g_depth > 0 and g_stack(g_depth) = 'X';
    g_depth -= 1;
    EmitStatement(2 * g_depth:'endif;':i_lineNo);
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
// A D or P specification whose name is continued over several lines: the parts
// (without the ...) and the name of the main definition line are the name, and
// the main line is converted with it. Returns the number of lines after the first
// one that were used.
dcl-proc ConvertLongName;
  dcl-pi *n int(10);
    i_spec char(1) const;
    i_index int(10) const;
    i_lineNo int(10) const;
    i_line char(100) const;
  end-pi;

  dcl-s l_name varchar(150);
  dcl-s l_text varchar(80);
  dcl-s l_count int(10) inz(1);
  dcl-s l_next int(10);
  dcl-s l_k int(10);
  dcl-s l_extra int(10);
  dcl-s l_main char(100);

  l_text = %trim(%subst(i_line:7:74));
  l_name = %subst(l_text:1:%len(l_text) - 3);
  l_next = i_index + 1;
  dow l_next <= SrcCount() and IsNameCont(i_spec:SrcLine(l_next));
    l_text = %trim(%subst(SrcLine(l_next):7:74));
    l_name += %subst(l_text:1:%len(l_text) - 3);
    l_count += 1;
    l_next += 1;
  enddo;

  // The main definition line has to follow directly.
  if l_next > SrcCount();
    l_main = '';
  else;
    l_main = SrcLine(l_next);
  endif;
  if l_main = '' or %subst(%xlate(C_LOWER:C_UPPER:l_main):6:1) <> i_spec
     or %subst(l_main:7:1) = '*' or %subst(l_main:7:1) = '/';
    ReviewSpec(i_lineNo:i_line:'A continued name without the definition line after it');
    for l_k = 1 to l_count - 1;
      ReviewSpec(SrcLineNo(i_index + l_k):SrcLine(i_index + l_k)
                 :'Continuation of the name above');
    endfor;
    return l_count - 1;
  endif;

  l_name += Txt(i_spec:'NAME':l_main);
  RptItem(C_STS_CONVERTED:i_lineNo:%trimr(%subst(i_line:6:75)):'');
  for l_k = 1 to l_count - 1;
    RptItem(C_STS_CONVERTED:SrcLineNo(i_index + l_k)
            :%trimr(%subst(SrcLine(i_index + l_k):6:75)):'');
  endfor;
  if i_spec = 'D';
    l_extra = ConvertD(l_next:SrcLineNo(l_next):l_main:l_name);
  else;
    l_extra = ConvertP(l_next:SrcLineNo(l_next):l_main:l_name);
  endif;
  return l_count + l_extra;
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
    when (l_form = 'D' or l_form = 'P') and IsNameCont(l_form:i_line);
      o_extra = ConvertLongName(l_form:i_index:i_lineNo:i_line);
    when l_form = 'D';
      o_extra = ConvertD(i_index:i_lineNo:i_line);
    when l_form = 'P';
      o_extra = ConvertP(i_index:i_lineNo:i_line);
    when l_form = 'I';
      Fx4Flush();
      o_extra = ConvertI(i_index:i_lineNo:i_line);
    when l_form = 'O';
      Fx4Flush();
      ReviewSpec(i_lineNo:i_line:'RPG IV output specification is not converted yet '
                 + '(FREE-06)');
    when l_form = 'C';
      Fx4Flush();
      // FREE-60: the prototypes and KLIST declarations go before the loop of the
      // cycle skeleton, which CalcCycleBefore opens at the first calculation.
      if not g_klDone;
        PrescanKlist();
      endif;
      if not g_cStarted;
        g_cStarted = *on;
        WritePrototypes();
      endif;
      CalcCycleBefore(i_line:i_lineNo);
      o_extra = ConvertC(i_index:i_lineNo:i_line);
    other;
      Fx4Flush();
      ReviewSpec(i_lineNo:i_line:'Unknown specification type in column 6');
  endsl;
  return *on;
end-proc;
