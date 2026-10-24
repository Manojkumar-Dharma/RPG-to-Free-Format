**FREE
// IAfreeCalc - calculation (C) specifications of RPG36 (System/36-compatible
// RPG II) to fully free-form RPGLE (FREE-05). Module of program IACNVFREE.
//
// What an operation code becomes is read from the rule tables (module
// IAfreeRul, rules/rpg36-opcodes.json): the factors it needs, the free-form
// template, the status and the reason when it is not converted. This module
// holds the rules that need state: conditioning indicators (AN and OR lines),
// structured groups (IFxx, ELSE, DO, DOWxx, DOUxx, CASxx, END), subroutines
// and the declaration of the fields defined by a result field.
//
// Columns of a C specification (SC09-1818 chapter 24): 7-8 control level,
// 9-17 conditioning indicators (N in 9, 12, 15), 18-27 factor 1, 28-32 operation,
// 33-42 factor 2, 43-48 result field, 49-51 length, 52 decimal positions,
// 53 half adjust, 54-59 resulting indicators, 60-74 comments.
//
// Target release V7R3.

ctl-opt nomain option(*srcstmt:*nodebugio);

/copy qcpysrc,IAcnvSrvP
/copy qcpysrc,IAfreeRulP
/copy qcpysrc,IAfreeCalcP

dcl-c C_LOWER 'abcdefghijklmnopqrstuvwxyz';
dcl-c C_UPPER 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
dcl-c C_DIGITS '0123456789';
dcl-c C_QUOTE '''';
dcl-c C_NAMEFIRST 'ABCDEFGHIJKLMNOPQRSTUVWXYZ#@$';
dcl-c C_NAMEREST 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#@$_';
dcl-c C_MAXSTACK 100;
dcl-c C_MAXDECL 500;
dcl-c C_MAXGROUP 8;
dcl-c C_MAXCONDLINES 16;
dcl-c C_MAXSTMT 8;

// The parts of one C specification line.
dcl-ds Calc_t qualified template;
  line char(100);
  lineNo int(10);
  level char(2);
  factor1 varchar(10);
  operation varchar(5);
  factor2 varchar(10);
  result varchar(6);
  length varchar(3);
  decimals char(1);
  halfAdjust char(1);
  result1 char(2);
  result2 char(2);
  result3 char(2);
  comment varchar(15);
  factor1C varchar(30);          // converted
  factor2C varchar(30);
  resultC varchar(30);
  cond varchar(300);             // free-form condition, '' when none
end-ds;

// Open groups: IF, IFW (IF under conditioning indicators), DO, DOW, DOU, CAS,
// RVW (a group that is not converted).
dcl-s g_stackKind char(3) dim(C_MAXSTACK);
dcl-s g_stackAdd int(10) dim(C_MAXSTACK);      // indent added by the group
dcl-s g_stackIndex int(10) dim(C_MAXSTACK);    // output line of a DO header
dcl-s g_stackHeader varchar(200) dim(C_MAXSTACK);
dcl-s g_stackCount int(10);
dcl-s g_depth int(10);
dcl-s g_inSub ind;
dcl-s g_cycleNoted ind;
dcl-s g_lastLineNo int(10);

// Lines of conditioning indicators waiting for their operation.
dcl-s g_condTerms varchar(300) dim(C_MAXGROUP);
dcl-s g_condCount int(10);
dcl-s g_condLines char(100) dim(C_MAXCONDLINES);
dcl-s g_condLineNos int(10) dim(C_MAXCONDLINES);
dcl-s g_condLineCount int(10);
dcl-s g_condLevel char(2);
dcl-s g_condBad varchar(150);

// Fields defined by result fields.
dcl-s g_declName varchar(10) dim(C_MAXDECL);
dcl-s g_declType varchar(40) dim(C_MAXDECL);
dcl-s g_declCount int(10);
dcl-s g_declAt int(10);
dcl-s g_doCount int(10);

// ------------------------------------------------------------------
dcl-proc CalcStart export;
  dcl-pi *n;
  end-pi;

  g_stackCount = 0;
  g_depth = 0;
  g_inSub = *off;
  g_cycleNoted = *off;
  g_lastLineNo = 0;
  g_condCount = 0;
  g_condLineCount = 0;
  g_condBad = '';
  g_declCount = 0;
  g_declAt = 0;
  g_doCount = 0;
end-proc;

// ------------------------------------------------------------------
dcl-proc Up;
  dcl-pi *n varchar(100);
    i_text varchar(100) const;
  end-pi;

  return %xlate(C_LOWER:C_UPPER:i_text);
end-proc;

// ------------------------------------------------------------------
dcl-proc Low;
  dcl-pi *n varchar(100);
    i_text varchar(100) const;
  end-pi;

  return %xlate(C_UPPER:C_LOWER:i_text);
end-proc;

// ------------------------------------------------------------------
dcl-proc IndentText;
  dcl-pi *n varchar(60);
    i_extra int(10) const options(*nopass);
  end-pi;

  dcl-s l_width int(10);
  dcl-s l_levels int(10);

  l_width = %int(RulConfig('INDENT':'2'));
  l_levels = g_depth;
  if %parms >= 1;
    l_levels += i_extra;
  endif;
  if l_levels <= 0 or l_width <= 0;
    return '';
  endif;
  return %subst('                                                            '
                :1:%min(l_levels * l_width:60));
end-proc;

// ------------------------------------------------------------------
dcl-proc Emit;
  dcl-pi *n;
    i_text varchar(190) const;
    i_lineNo int(10) const;
    i_extra int(10) const options(*nopass);
  end-pi;

  if %parms >= 3;
    AddOut(IndentText(i_extra) + i_text:i_lineNo);
  else;
    AddOut(IndentText() + i_text:i_lineNo);
  endif;
end-proc;

// ------------------------------------------------------------------
dcl-proc SpecText;
  dcl-pi *n varchar(75);
    i_line char(100) const;
  end-pi;

  return %trimr(%subst(i_line:6:75));
end-proc;

// ------------------------------------------------------------------
dcl-proc IsName;
  dcl-pi *n ind;
    i_text varchar(30) const;
  end-pi;

  if %len(i_text) = 0;
    return *off;
  endif;
  if %check(C_NAMEFIRST:%subst(Up(i_text):1:1)) > 0;
    return *off;
  endif;
  return %check(C_NAMEREST:Up(i_text)) = 0;
end-proc;

// ------------------------------------------------------------------
// A numeric literal: optional sign, digits and one decimal point.
dcl-proc IsNumberLiteral;
  dcl-pi *n ind;
    i_text varchar(30) const;
  end-pi;

  dcl-s l_body varchar(30);
  dcl-s l_point int(10);

  l_body = i_text;
  if %len(l_body) > 0 and (%subst(l_body:1:1) = '-' or %subst(l_body:1:1) = '+');
    l_body = %subst(l_body:2);
  endif;
  if %len(l_body) = 0;
    return *off;
  endif;
  l_point = %scan('.':l_body);
  if l_point > 0;
    if %scan('.':l_body:l_point + 1) > 0;
      return *off;
    endif;
    l_body = %scanrpl('.':'':l_body);
    if %len(l_body) = 0;
      return *off;
    endif;
  endif;
  return %check(C_DIGITS:l_body) = 0;
end-proc;

// ------------------------------------------------------------------
// A factor or result field as free-form text: a literal, a figurative
// constant or special name (table IACNVNAM), a field name, or an array
// element NAME,INDEX. i_subroutine accepts *PSSR and *INZSR.
dcl-proc ConvOperand;
  dcl-pi *n ind;
    i_text varchar(30) const;
    o_text varchar(30);
    o_reason varchar(150);
    i_subroutine ind const options(*nopass);
  end-pi;

  dcl-ds l_name likeds(IAfreeNam_t);
  dcl-s l_comma int(10);
  dcl-s l_first varchar(30);
  dcl-s l_second varchar(30);
  dcl-s l_isSubr ind inz(*off);
  dcl-s l_upper varchar(30);

  o_text = '';
  o_reason = '';
  if %parms >= 4;
    l_isSubr = i_subroutine;
  endif;
  if %len(i_text) = 0;
    return *on;
  endif;

  // Character literal.
  if %subst(i_text:1:1) = C_QUOTE;
    if %len(i_text) < 2 or %subst(i_text:%len(i_text):1) <> C_QUOTE;
      o_reason = 'Character literal ' + i_text + ' is not closed';
      return *off;
    endif;
    o_text = i_text;
    return *on;
  endif;

  // Numeric literal.
  if IsNumberLiteral(i_text);
    o_text = i_text;
    if %subst(o_text:1:1) = '+';
      o_text = %subst(o_text:2);
    endif;
    if %subst(o_text:1:1) = '.';
      o_text = '0' + o_text;
    endif;
    if %len(o_text) > 1 and %subst(o_text:1:2) = '-.';
      o_text = '-0' + %subst(o_text:2);
    endif;
    return *on;
  endif;

  l_upper = Up(i_text);
  if l_isSubr and (l_upper = '*PSSR' or l_upper = '*INZSR');
    o_text = Low(l_upper);
    return *on;
  endif;

  // Figurative constants and special names.
  if RulName(l_upper:l_name);
    if l_name.status = 'R' or l_name.freeForm = '';
      o_reason = i_text + ': ' + %trim(l_name.reason);
      return *off;
    endif;
    o_text = l_name.freeForm;
    return *on;
  endif;
  if %subst(i_text:1:1) = '*';
    o_reason = 'Special name ' + i_text + ' is not converted';
    return *off;
  endif;

  // Array element.
  l_comma = %scan(',':i_text);
  if l_comma > 0;
    l_first = %subst(i_text:1:l_comma - 1);
    l_second = %subst(i_text:l_comma + 1);
    if IsName(l_first) and (IsName(l_second) or IsNumberLiteral(l_second));
      o_text = l_first + '(' + l_second + ')';
      return *on;
    endif;
    o_reason = 'Array element ' + i_text + ' is not understood';
    return *off;
  endif;

  if IsName(i_text);
    o_text = i_text;
    return *on;
  endif;
  o_reason = 'Name or literal ' + i_text + ' is not valid';
  return *off;
end-proc;

// ------------------------------------------------------------------
// The conditioning indicators of one line (columns 9 to 17) as free-form
// terms joined by 'and'. o_reason is set when an indicator is not valid or
// belongs to the RPG cycle.
dcl-proc LineTerms;
  dcl-pi *n varchar(150);
    i_line char(100) const;
    o_reason varchar(150);
  end-pi;

  dcl-ds l_rule likeds(IAfreeInd_t);
  dcl-s l_slot int(10);
  dcl-s l_not char(1);
  dcl-s l_name char(2);
  dcl-s l_terms varchar(150) inz('');
  dcl-s l_term varchar(20);

  o_reason = '';
  for l_slot = 0 to 2;
    l_not = %subst(i_line:9 + l_slot * 3:1);
    l_name = %subst(i_line:10 + l_slot * 3:2);
    if l_name <> '  ';
      if not RulIndicator(l_name:l_rule);
        o_reason = 'Indicator ' + %trim(l_name) + ' is not known';
      elseif l_rule.cycle = 'Y';
        o_reason = %trim(l_rule.reason);
      else;
        l_term = %trim(l_rule.freeForm);
        if %xlate(C_LOWER:C_UPPER:l_not) = 'N';
          l_term = 'not ' + l_term;
        endif;
        if %len(l_terms) > 0;
          l_terms += ' and ';
        endif;
        l_terms += l_term;
      endif;
    elseif l_not <> ' ';
      o_reason = 'N without an indicator';
    endif;
  endfor;
  return l_terms;
end-proc;

// ------------------------------------------------------------------
// Keeps a line as a comment, reports it R and, when asked, opens a group that
// stands for an IF, DO, DOW, DOU or CAS that was not converted so that its END
// matches.
dcl-proc ReviewHere;
  dcl-pi *n;
    i_line char(100) const;
    i_lineNo int(10) const;
    i_reason varchar(190) const;
    i_opensGroup ind const options(*nopass);
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_reason varchar(190);

  l_reason = i_reason;
  for l_index = 1 to g_condLineCount;
    Emit('// RPG II: ' + SpecText(g_condLines(l_index)):g_condLineNos(l_index));
    RptItem(C_STS_REVIEW:g_condLineNos(l_index):SpecText(g_condLines(l_index))
            :'Indicator line of an operation that is not converted');
  endfor;
  Emit('// RPG II: ' + SpecText(i_line):i_lineNo);
  RptItem(C_STS_REVIEW:i_lineNo:SpecText(i_line):l_reason);
  g_condCount = 0;
  g_condLineCount = 0;
  g_condBad = '';

  if %parms >= 4;
    if i_opensGroup and g_stackCount < C_MAXSTACK;
      g_stackCount += 1;
      g_stackKind(g_stackCount) = 'RVW';
      g_stackAdd(g_stackCount) = 0;
      g_stackIndex(g_stackCount) = 0;
      g_stackHeader(g_stackCount) = '';
    endif;
  endif;
end-proc;

// ------------------------------------------------------------------
dcl-proc Push;
  dcl-pi *n ind;
    i_kind char(3) const;
    i_add int(10) const;
    i_index int(10) const;
    i_header varchar(200) const;
  end-pi;

  if g_stackCount >= C_MAXSTACK;
    return *off;
  endif;
  g_stackCount += 1;
  g_stackKind(g_stackCount) = i_kind;
  g_stackAdd(g_stackCount) = i_add;
  g_stackIndex(g_stackCount) = i_index;
  g_stackHeader(g_stackCount) = i_header;
  g_depth += i_add;
  return *on;
end-proc;

// ------------------------------------------------------------------
// Closes the top group: lowers the indent by what it added.
dcl-proc Pop;
  dcl-pi *n;
  end-pi;

  g_depth -= g_stackAdd(g_stackCount);
  g_stackCount -= 1;
  if g_depth < 0;
    g_depth = 0;
  endif;
end-proc;

// ------------------------------------------------------------------
// Declares the field a result field defines (columns 49-52). Returns an
// empty text, or the reason it cannot be declared.
dcl-proc DeclareResult;
  dcl-pi *n varchar(150);
    i_name varchar(30) const;
    i_length varchar(3) const;
    i_decimals char(1) const;
    i_numeric ind const;
  end-pi;

  dcl-s l_type varchar(40);
  dcl-s l_length int(10);
  dcl-s l_decimals int(10);
  dcl-s l_index int(10);

  if %len(i_length) = 0;
    return '';                      // defined elsewhere
  endif;
  if %scan('(':i_name) > 0;
    return '';                      // array element
  endif;
  if %check(C_DIGITS:i_length) > 0;
    return 'Length of ' + i_name + ' is not a number';
  endif;
  l_length = %int(i_length);
  if l_length < 1 or l_length > 256;
    return 'Length of ' + i_name + ' must be 1 to 256';
  endif;

  if i_decimals = ' ' and not i_numeric;
    l_type = 'char(' + %char(l_length) + ')';
  else;
    if i_decimals = ' ';
      l_decimals = 0;
    elseif %check(C_DIGITS:i_decimals) > 0;
      return 'Decimal positions of ' + i_name + ' are not a digit';
    else;
      l_decimals = %int(i_decimals);
    endif;
    if l_decimals > l_length or l_length > 63;
      return 'Decimal positions of ' + i_name + ' do not fit its length';
    endif;
    l_type = RulConfig('NUMERIC_TYPE':'zoned') + '(' + %char(l_length) + ':'
             + %char(l_decimals) + ')';
  endif;

  for l_index = 1 to g_declCount;
    if g_declName(l_index) = Up(i_name);
      if g_declType(l_index) <> l_type;
        return i_name + ' is already defined as ' + g_declType(l_index);
      endif;
      return '';
    endif;
  endfor;
  if g_declCount >= C_MAXDECL;
    return 'Too many fields defined by result fields';
  endif;
  g_declCount += 1;
  g_declName(g_declCount) = Up(i_name);
  g_declType(g_declCount) = l_type;
  return '';
end-proc;

// ------------------------------------------------------------------
// One resulting indicator slot (1 to 3) after an operation: the free-form
// name of the indicator and its test. Returns '' or the reason it fails.
dcl-proc ResultStatement;
  dcl-pi *n varchar(150);
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
    i_slot int(10) const;
    o_statement varchar(250);
  end-pi;

  dcl-ds l_ind likeds(IAfreeInd_t);
  dcl-s l_code varchar(4);
  dcl-s l_name char(2);
  dcl-s l_test varchar(100);

  o_statement = '';
  select;
    when i_slot = 1;
      l_name = i_c.result1;
      l_code = i_rule.ind1;
    when i_slot = 2;
      l_name = i_c.result2;
      l_code = i_rule.ind2;
    other;
      l_name = i_c.result3;
      l_code = i_rule.ind3;
  endsl;
  if l_name = '  ';
    return '';
  endif;
  if l_code = '' or l_code = 'O' or l_code = 'R';
    return 'Resulting indicator ' + l_name + ' is not allowed for ' + i_rule.opcode;
  endif;
  if not RulIndicator(l_name:l_ind);
    return 'Indicator ' + %trim(l_name) + ' is not known';
  endif;
  if l_ind.cycle = 'Y';
    return %trim(l_ind.reason);
  endif;
  l_test = RulResultTest(l_code);
  if l_test = '';
    return 'The test ' + l_code + ' of ' + i_rule.opcode + ' is not in IACNVRES';
  endif;
  l_test = %scanrpl('{RES}':i_c.resultC:l_test);
  l_test = %scanrpl('{F1}':i_c.factor1C:l_test);
  l_test = %scanrpl('{F2}':i_c.factor2C:l_test);
  o_statement = %trim(l_ind.freeForm) + ' = (' + l_test + ')';
  return '';
end-proc;

// ------------------------------------------------------------------
// The first built-in function of a template that came with a release later
// than TARGET_RELEASE, or ''.
dcl-proc LateBif;
  dcl-pi *n varchar(40);
    i_bifs varchar(100) const;
  end-pi;

  dcl-s l_rest varchar(100);
  dcl-s l_comma int(10);
  dcl-s l_name varchar(20);
  dcl-s l_since varchar(4);
  dcl-s l_target varchar(4);

  l_target = RulConfig('TARGET_RELEASE':'V7R3');
  l_rest = i_bifs;
  dow %len(l_rest) > 0;
    l_comma = %scan(',':l_rest);
    if l_comma = 0;
      l_name = %trim(l_rest);
      l_rest = '';
    else;
      l_name = %trim(%subst(l_rest:1:l_comma - 1));
      l_rest = %subst(l_rest:l_comma + 1);
    endif;
    l_since = RulBifSince(l_name);
    if l_since <> '' and ReleaseNumber(l_since) > ReleaseNumber(l_target);
      return l_name;
    endif;
  enddo;
  return '';
end-proc;

// ------------------------------------------------------------------
// V7R3 as 703, V5R1 as 501.
dcl-proc ReleaseNumber;
  dcl-pi *n int(10);
    i_release varchar(4) const;
  end-pi;

  if %len(i_release) <> 4 or %subst(i_release:1:1) <> 'V'
     or %subst(i_release:3:1) <> 'R';
    return 0;
  endif;
  if %check(C_DIGITS:%subst(i_release:2:1)) > 0
     or %check(C_DIGITS:%subst(i_release:4:1)) > 0;
    return 0;
  endif;
  return %int(%subst(i_release:2:1)) * 100 + %int(%subst(i_release:4:1));
end-proc;

// ------------------------------------------------------------------
// Writes a converted operation: its statements inside an IF when conditioning
// indicators apply, then the report line.
dcl-proc EmitStatements;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
    i_statements varchar(250) dim(C_MAXSTMT) const;
    i_count int(10) const;
    i_reason varchar(190) const;
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_text varchar(250);
  dcl-s l_extra int(10) inz(0);
  dcl-s l_status char(1);
  dcl-s l_reason varchar(190);

  if i_c.cond <> '';
    Emit('if ' + i_c.cond + ';':i_c.lineNo);
    l_extra = 1;
  endif;
  for l_index = 1 to i_count;
    l_text = i_statements(l_index) + ';';
    if l_index = 1 and %len(i_c.comment) > 0;
      l_text += ' // ' + i_c.comment;
    endif;
    Emit(l_text:i_c.lineNo:l_extra);
  endfor;
  if i_c.cond <> '';
    Emit('endif;':i_c.lineNo);
  endif;

  l_status = i_rule.status;
  l_reason = i_reason;
  if i_c.halfAdjust = 'H';
    l_status = C_STS_ASSUMPTION;
    AddReason(l_reason:RulConfig('HALF_ADJUST_NOTE':'Half adjust differs'));
  endif;
  if i_rule.reason <> '' and i_rule.status = 'A';
    AddReason(l_reason:%trim(i_rule.reason));
  endif;
  if not g_inSub and not g_cycleNoted;
    g_cycleNoted = *on;
    l_status = C_STS_ASSUMPTION;
    AddReason(l_reason:RulConfig('CYCLE_NOTE':'The RPG cycle is not emulated'));
  endif;
  RptItem(l_status:i_c.lineNo:SpecText(i_c.line):l_reason);
end-proc;

// ------------------------------------------------------------------
dcl-proc AddReason;
  dcl-pi *n;
    io_text varchar(190);
    i_add varchar(190) const;
  end-pi;

  if %len(io_text) > 0;
    io_text += '; ';
  endif;
  io_text += i_add;
end-proc;

// ------------------------------------------------------------------
// One C specification line.
dcl-proc CalcLine export;
  dcl-pi *n;
    i_line char(100) const;
    i_lineNo int(10) const;
  end-pi;

  dcl-ds l_c likeds(Calc_t);
  dcl-ds l_rule likeds(IAfreeOpc_t);
  dcl-s l_xx char(2);
  dcl-s l_up char(100);
  dcl-s l_terms varchar(150);
  dcl-s l_reason varchar(150);
  dcl-s l_hasGroup ind;
  dcl-s l_isCondOnly ind;
  dcl-s l_index int(10);
  dcl-s l_own varchar(150);
  dcl-s l_list varchar(300);
  dcl-s l_isStructure ind;
  dcl-s l_isSubrOperand ind;

  g_lastLineNo = i_lineNo;
  l_up = %xlate(C_LOWER:C_UPPER:i_line);

  // Everything between columns 7 and 59 blank: nothing to convert.
  if %trim(%subst(i_line:7:53)) = '';
    return;
  endif;

  // The declarations of the result fields go here when the source is done.
  if g_declAt = 0;
    AddOut('':i_lineNo);
    g_declAt = OutCount();
  endif;

  clear l_c;
  l_c.line = i_line;
  l_c.lineNo = i_lineNo;
  l_c.level = %subst(l_up:7:2);
  l_c.factor1 = %trim(%subst(i_line:18:10));
  l_c.operation = %trim(%subst(l_up:28:5));
  l_c.factor2 = %trim(%subst(i_line:33:10));
  l_c.result = %trim(%subst(i_line:43:6));
  l_c.length = %trim(%subst(l_up:49:3));
  l_c.decimals = %subst(l_up:52:1);
  l_c.halfAdjust = %subst(l_up:53:1);
  l_c.result1 = %subst(l_up:54:2);
  l_c.result2 = %subst(l_up:56:2);
  l_c.result3 = %subst(l_up:58:2);
  l_c.comment = %trimr(%subst(i_line:60:15));

  l_isCondOnly = ((%trim(%subst(i_line:18:42)) = '')
                  and (%trim(%subst(i_line:9:9)) <> ''
                       or l_c.level = 'AN' or l_c.level = 'OR'));

  // ---- A line of conditioning indicators without an operation -------------
  if l_isCondOnly;
    if g_condLineCount >= C_MAXCONDLINES;
      ReviewHere(i_line:i_lineNo:'More than ' + %char(C_MAXCONDLINES)
                 + ' lines of indicators');
      return;
    endif;
    l_terms = LineTerms(i_line:l_reason);
    if l_c.level = 'AN' or l_c.level = 'OR';
      if g_condLineCount = 0;
        ReviewHere(i_line:i_lineNo:'AN or OR line without a first line of indicators');
        return;
      endif;
      if l_c.level = 'OR';
        if g_condCount >= C_MAXGROUP;
          g_condBad = 'More than ' + %char(C_MAXGROUP) + ' OR lines';
        else;
          g_condCount += 1;
          g_condTerms(g_condCount) = l_terms;
        endif;
      else;
        if g_condTerms(g_condCount) <> '' and l_terms <> '';
          g_condTerms(g_condCount) += ' and ';
        endif;
        g_condTerms(g_condCount) += l_terms;
      endif;
    else;
      if g_condLineCount > 0;
        ReviewHere(i_line:i_lineNo:'Line of indicators without AN or OR after a line'
                   + ' of indicators without an operation');
        return;
      endif;
      g_condCount = 1;
      g_condTerms(1) = l_terms;
      g_condLevel = l_c.level;
    endif;
    if l_reason <> '' and g_condBad = '';
      g_condBad = l_reason;
    endif;
    g_condLineCount += 1;
    g_condLines(g_condLineCount) = i_line;
    g_condLineNos(g_condLineCount) = i_lineNo;
    return;
  endif;

  // ---- The operation line --------------------------------------------------
  l_hasGroup = g_condLineCount > 0;
  if l_hasGroup and l_c.level <> 'AN' and l_c.level <> 'OR';
    ReviewHere(i_line:i_lineNo:'Lines of indicators must end with an AN or OR line'
               + ' that holds the operation');
    g_condCount = 0;
    g_condLineCount = 0;
    g_condBad = '';
    return;
  endif;
  if not l_hasGroup and (l_c.level = 'AN' or l_c.level = 'OR');
    ReviewHere(i_line:i_lineNo:'AN or OR line without a first line of indicators');
    return;
  endif;

  // Control level of the group (the first line) or of this line.
  if l_hasGroup;
    l_c.level = g_condLevel;
  endif;
  select;
    when l_c.level = '  ' or l_c.level = 'SR';
    when l_c.level = 'AN' or l_c.level = 'OR';
    other;
      ReviewHere(i_line:i_lineNo:'Total calculation (' + l_c.level
                 + ') belongs to the RPG cycle, which is not supported'
                 :IsGroupOpener(l_up));
      return;
  endsl;

  // Conditioning indicators: the group, then the line itself.
  l_reason = '';
  l_own = LineTerms(i_line:l_reason);
  if l_hasGroup and g_condBad <> '';
    l_reason = g_condBad;
  endif;
  if l_reason <> '';
    ReviewHere(i_line:i_lineNo:l_reason:IsGroupOpener(l_up));
    return;
  endif;
  l_list = '';
  if l_hasGroup;
    if g_condCount = 1;
      l_list = g_condTerms(1);
    else;
      for l_index = 1 to g_condCount;
        if l_index > 1;
          l_list += ' or ';
        endif;
        l_list += '(' + g_condTerms(l_index) + ')';
      endfor;
      l_list = '(' + l_list + ')';
    endif;
  endif;
  if l_own <> '';
    if l_list <> '';
      l_list += ' and ';
    endif;
    l_list += l_own;
  endif;
  l_c.cond = l_list;
  if g_condLineCount > 0;
    // The indicator lines are part of this operation: report them with it.
    for l_index = 1 to g_condLineCount;
      RptItem(C_STS_CONVERTED:g_condLineNos(l_index)
              :SpecText(g_condLines(l_index)):'');
    endfor;
  endif;
  g_condCount = 0;
  g_condLineCount = 0;
  g_condBad = '';

  // ---- The operation code ---------------------------------------------------
  if l_c.operation = '';
    ReviewHere(i_line:i_lineNo:'No operation code');
    return;
  endif;
  if not RulOpcode(l_c.operation:l_rule:l_xx);
    ReviewHere(i_line:i_lineNo:'Operation code ' + l_c.operation + ' is not known');
    return;
  endif;
  l_isStructure = (l_rule.kind = 'IF' or l_rule.kind = 'DO' or l_rule.kind = 'DOW'
                   or l_rule.kind = 'DOU' or l_rule.kind = 'CASE');
  if l_rule.status = 'R';
    ReviewHere(i_line:i_lineNo:%trim(l_rule.reason):l_isStructure);
    return;
  endif;

  // Only CASxx operations and the END can be inside a CAS group.
  if g_stackCount > 0 and g_stackKind(g_stackCount) = 'CAS'
     and l_rule.kind <> 'CASE' and l_rule.kind <> 'END';
    ReviewHere(i_line:i_lineNo:'Only CASxx operations can be in a CAS group');
    return;
  endif;

  // Subroutine statements outside a subroutine, and the reverse.
  if (l_rule.kind = 'SUBR' and l_rule.opcode = 'BEGSR' and g_stackCount > 0);
    ReviewHere(i_line:i_lineNo:'BEGSR inside a group that is still open');
    return;
  endif;

  // ---- Factors ---------------------------------------------------------------
  l_reason = CheckFactors(l_c:l_rule);
  if l_reason <> '';
    ReviewHere(i_line:i_lineNo:l_reason:l_isStructure);
    return;
  endif;
  l_isSubrOperand = (l_rule.opcode = 'EXSR' or l_rule.opcode = 'BEGSR'
                     or l_rule.opcode = 'ENDSR' or l_rule.kind = 'CASE');
  if not ConvertFactors(l_c:l_isSubrOperand:l_rule:l_reason);
    ReviewHere(i_line:i_lineNo:l_reason:l_isStructure);
    return;
  endif;

  // Built-in functions that are too new for the target release.
  if l_rule.bifs <> '';
    l_reason = LateBif(l_rule.bifs);
    if l_reason <> '';
      ReviewHere(i_line:i_lineNo:'Built-in function ' + l_reason
                 + ' is newer than the target release');
      return;
    endif;
  endif;

  if l_c.halfAdjust <> ' ' and (l_c.halfAdjust <> 'H' or l_rule.halfAdjust <> 'Y');
    ReviewHere(i_line:i_lineNo:'Half adjust is not allowed for ' + l_rule.opcode
               :l_isStructure);
    return;
  endif;

  select;
    when l_rule.kind = 'IF';
      ConvertIf(l_c:l_rule:l_xx);
    when l_rule.kind = 'DOW' or l_rule.kind = 'DOU';
      ConvertDoWhile(l_c:l_rule:l_xx);
    when l_rule.kind = 'DO';
      ConvertDo(l_c:l_rule);
    when l_rule.kind = 'ELSE';
      ConvertElse(l_c);
    when l_rule.kind = 'END';
      ConvertEnd(l_c);
    when l_rule.kind = 'CASE';
      ConvertCase(l_c:l_rule:l_xx);
    when l_rule.kind = 'SUBR' and l_rule.opcode = 'BEGSR';
      ConvertBegsr(l_c);
    when l_rule.kind = 'SUBR' and l_rule.opcode = 'ENDSR';
      ConvertEndsr(l_c);
    when l_rule.kind = 'IND';
      ConvertSetIndicators(l_c:l_rule);
    when l_rule.kind = 'COMPARE';
      ConvertCompare(l_c:l_rule);
    when l_rule.kind = 'TIME';
      ConvertTime(l_c:l_rule);
    other;
      ConvertTemplate(l_c:l_rule);
  endsl;
end-proc;

// ------------------------------------------------------------------
// *ON when the operation code of the line starts a group (IFxx, DO, DOWxx,
// DOUxx, CASxx), so that a line that is not converted still gets its END.
dcl-proc IsGroupOpener;
  dcl-pi *n ind;
    i_up char(100) const;
  end-pi;

  dcl-s l_op varchar(5);

  l_op = %trim(%subst(i_up:28:5));
  return l_op = 'DO' or l_op = 'CAS'
         or (%len(l_op) >= 3 and %subst(l_op:1:2) = 'IF')
         or (%len(l_op) >= 4 and %subst(l_op:1:3) = 'DOW')
         or (%len(l_op) >= 4 and %subst(l_op:1:3) = 'DOU')
         or (%len(l_op) >= 4 and %subst(l_op:1:3) = 'CAS');
end-proc;

// ------------------------------------------------------------------
// Factor 1, factor 2 and the result field against the table: a required entry
// is there and a blank one is blank. Returns '' or the reason.
dcl-proc CheckFactors;
  dcl-pi *n varchar(150);
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  if i_rule.factor1 = 'R' and i_c.factor1 = '';
    return 'Factor 1 is required for ' + i_rule.opcode;
  endif;
  if i_rule.factor1 = '-' and i_c.factor1 <> '';
    return 'Factor 1 must be blank for ' + i_rule.opcode;
  endif;
  if i_rule.factor2 = 'R' and i_c.factor2 = '' and not
     (i_rule.kind = 'CASE');
    return 'Factor 2 is required for ' + i_rule.opcode;
  endif;
  if i_rule.factor2 = '-' and i_c.factor2 <> '';
    return 'Factor 2 must be blank for ' + i_rule.opcode;
  endif;
  if i_rule.result = 'R' and i_c.result = '';
    return 'The result field is required for ' + i_rule.opcode;
  endif;
  if i_rule.result = '-' and i_c.result <> '';
    return 'The result field must be blank for ' + i_rule.opcode;
  endif;
  return '';
end-proc;

// ------------------------------------------------------------------
dcl-proc ConvertFactors;
  dcl-pi *n ind;
    io_c likeds(Calc_t);
    i_subroutine ind const;
    i_rule likeds(IAfreeOpc_t) const;
    o_reason varchar(150);
  end-pi;

  dcl-s l_text varchar(30);

  if not ConvOperand(io_c.factor1:l_text:o_reason:i_subroutine);
    return *off;
  endif;
  io_c.factor1C = l_text;
  if not ConvOperand(io_c.factor2:l_text:o_reason:i_subroutine);
    return *off;
  endif;
  io_c.factor2C = l_text;
  if not ConvOperand(io_c.result:l_text:o_reason:i_subroutine);
    return *off;
  endif;
  io_c.resultC = l_text;
  // A result field is a name or an array element, never a literal.
  if io_c.result <> '' and (%subst(io_c.result:1:1) = C_QUOTE
     or IsNumberLiteral(io_c.result) or %subst(io_c.resultC:1:1) = '*');
    o_reason = 'The result field ' + io_c.result + ' is not a field name';
    return *off;
  endif;
  return *on;
end-proc;

// ------------------------------------------------------------------
// IFxx. Conditioning indicators control the whole IF/ELSE group, so they get
// an outer IF of their own (group kind IFW, closed by two ENDIFs).
dcl-proc ConvertIf;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
    i_xx char(2) const;
  end-pi;

  dcl-s l_operator varchar(2);
  dcl-s l_compare varchar(100);

  l_operator = RulComparison(i_xx);
  l_compare = i_c.factor1C + ' ' + l_operator + ' ' + i_c.factor2C;
  if l_operator = '';
    ReviewHere(i_c.line:i_c.lineNo:'IF needs xx: GT, LT, EQ, NE, GE or LE':*on);
    return;
  endif;
  if i_c.cond = '';
    Emit('if ' + l_compare + ';':i_c.lineNo);
    if not Push('IF ':1:0:'');
      ReviewHere(i_c.line:i_c.lineNo:'Groups are nested too deep');
      return;
    endif;
  else;
    Emit('if ' + i_c.cond + ';':i_c.lineNo);
    g_depth += 1;
    Emit('if ' + l_compare + ';':i_c.lineNo);
    g_depth -= 1;
    if not Push('IFW':2:0:'');
      ReviewHere(i_c.line:i_c.lineNo:'Groups are nested too deep');
      return;
    endif;
  endif;
  ReportConverted(i_c:i_rule:'');
end-proc;

// ------------------------------------------------------------------
dcl-proc ConvertDoWhile;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
    i_xx char(2) const;
  end-pi;

  dcl-s l_operator varchar(2);

  l_operator = RulComparison(i_xx);
  if l_operator = '';
    ReviewHere(i_c.line:i_c.lineNo:i_rule.opcode + ' needs xx: GT, LT, EQ, NE, GE or LE'
               :*on);
    return;
  endif;
  if i_c.cond <> '';
    ReviewHere(i_c.line:i_c.lineNo:'Conditioning indicators on ' + i_rule.opcode
               + ' are not converted':*on);
    return;
  endif;
  Emit(Low(i_rule.opcode) + ' ' + i_c.factor1C + ' ' + l_operator + ' '
       + i_c.factor2C + ';':i_c.lineNo);
  if not Push(%subst(i_rule.opcode + '   ':1:3):1:0:'');
    ReviewHere(i_c.line:i_c.lineNo:'Groups are nested too deep');
    return;
  endif;
  ReportConverted(i_c:i_rule:'');
end-proc;

// ------------------------------------------------------------------
// DO: a FOR loop. The increment is on the END and is added there. Without a
// result field the compiler of S/36 makes an index; a field is declared here.
dcl-proc ConvertDo;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  dcl-s l_start varchar(30);
  dcl-s l_limit varchar(30);
  dcl-s l_index varchar(30);
  dcl-s l_reason varchar(150);
  dcl-s l_header varchar(200);
  dcl-s l_note varchar(190) inz('');

  if i_c.cond <> '';
    ReviewHere(i_c.line:i_c.lineNo:'Conditioning indicators on DO are not converted'
               :*on);
    return;
  endif;
  l_start = i_c.factor1C;
  if l_start = '';
    l_start = '1';
  endif;
  l_limit = i_c.factor2C;
  if l_limit = '';
    l_limit = '1';
  endif;
  l_index = i_c.resultC;
  if l_index = '';
    g_doCount += 1;
    l_index = 'IADO' + %trim(%char(g_doCount));
    l_reason = DeclareDoIndex(l_index);
    l_note = 'DO without a result field: index ' + l_index + ' declared';
  else;
    l_reason = DeclareResult(l_index:i_c.length:i_c.decimals:*on);
  endif;
  if l_reason <> '';
    ReviewHere(i_c.line:i_c.lineNo:l_reason:*on);
    return;
  endif;

  l_header = IndentText() + 'for ' + l_index + ' = ' + l_start + ' to ' + l_limit;
  AddOut(l_header + ';':i_c.lineNo);
  if not Push('DO ':1:OutCount():l_header);
    ReviewHere(i_c.line:i_c.lineNo:'Groups are nested too deep');
    return;
  endif;
  ReportConverted(i_c:i_rule:l_note);
end-proc;

// ------------------------------------------------------------------
dcl-proc DeclareDoIndex;
  dcl-pi *n varchar(150);
    i_name varchar(30) const;
  end-pi;

  if g_declCount >= C_MAXDECL;
    return 'Too many fields defined by result fields';
  endif;
  g_declCount += 1;
  g_declName(g_declCount) = Up(i_name);
  g_declType(g_declCount) = RulConfig('INDEX_TYPE':'int(10)');
  return '';
end-proc;

// ------------------------------------------------------------------
dcl-proc ConvertElse;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
  end-pi;

  if i_c.cond <> '';
    ReviewHere(i_c.line:i_c.lineNo:'Conditioning indicators on ELSE are not converted');
    return;
  endif;
  if g_stackCount = 0 or (g_stackKind(g_stackCount) <> 'IF '
     and g_stackKind(g_stackCount) <> 'IFW');
    ReviewHere(i_c.line:i_c.lineNo:'ELSE without an IFxx that was converted');
    return;
  endif;
  Emit('else;':i_c.lineNo:-1);
  RptItem(C_STS_CONVERTED:i_c.lineNo:SpecText(i_c.line):'');
end-proc;

// ------------------------------------------------------------------
dcl-proc ConvertEnd;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
  end-pi;

  dcl-s l_kind char(3);
  dcl-s l_increment varchar(30);
  dcl-s l_note varchar(190) inz('');

  if g_stackCount = 0;
    ReviewHere(i_c.line:i_c.lineNo:'END without an open group');
    return;
  endif;
  if i_c.cond <> '';
    ReviewHere(i_c.line:i_c.lineNo:'Conditioning indicators on END are not converted');
    return;
  endif;

  l_kind = g_stackKind(g_stackCount);
  select;
    when l_kind = 'RVW';
      Pop();
      ReviewHere(i_c.line:i_c.lineNo:'END of a group that was not converted');
      return;
    when l_kind = 'IF ';
      Pop();
      Emit('endif;':i_c.lineNo);
    when l_kind = 'IFW';
      Pop();
      Emit('endif;':i_c.lineNo:1);
      Emit('endif;':i_c.lineNo);
    when l_kind = 'DOW' or l_kind = 'DOU';
      Pop();
      Emit('enddo;':i_c.lineNo);
    when l_kind = 'CAS';
      Pop();
      Emit('endsl;':i_c.lineNo);
    when l_kind = 'DO ';
      l_increment = i_c.factor2C;
      if l_increment <> '' and l_increment <> '1';
        OutSet(g_stackIndex(g_stackCount):g_stackHeader(g_stackCount) + ' by '
               + l_increment + ';');
      endif;
      Pop();
      Emit('endfor;':i_c.lineNo);
    other;
      Pop();
  endsl;
  if i_c.factor2 <> '' and l_kind <> 'DO ';
    l_note = 'Factor 2 of END is ignored';
  endif;
  if l_note = '';
    RptItem(C_STS_CONVERTED:i_c.lineNo:SpecText(i_c.line):'');
  else;
    RptItem(C_STS_ASSUMPTION:i_c.lineNo:SpecText(i_c.line):l_note);
  endif;
end-proc;

// ------------------------------------------------------------------
// CASxx group: SELECT with a WHEN for each CASxx and OTHER for CAS with a
// blank xx. The first CASxx opens the group, the END closes it.
dcl-proc ConvertCase;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
    i_xx char(2) const;
  end-pi;

  dcl-s l_operator varchar(2);

  if i_c.cond <> '';
    ReviewHere(i_c.line:i_c.lineNo:'Conditioning indicators on CASxx are not converted');
    return;
  endif;
  if i_c.result1 <> '  ' or i_c.result2 <> '  ' or i_c.result3 <> '  ';
    ReviewHere(i_c.line:i_c.lineNo:'Resulting indicators on CASxx are not converted');
    return;
  endif;
  if i_c.resultC = '';
    ReviewHere(i_c.line:i_c.lineNo:'CASxx needs a subroutine name in the result field');
    return;
  endif;
  if i_xx = '  ';
    if i_c.factor1 <> '' or i_c.factor2 <> '';
      ReviewHere(i_c.line:i_c.lineNo:'CAS with a blank xx has no factors');
      return;
    endif;
  else;
    l_operator = RulComparison(i_xx);
    if l_operator = '' or i_c.factor1 = '' or i_c.factor2 = '';
      ReviewHere(i_c.line:i_c.lineNo:'CASxx needs xx and both factors');
      return;
    endif;
  endif;

  if g_stackCount = 0 or g_stackKind(g_stackCount) <> 'CAS';
    Emit('select;':i_c.lineNo);
    if not Push('CAS':1:0:'');
      ReviewHere(i_c.line:i_c.lineNo:'Groups are nested too deep');
      return;
    endif;
  endif;
  if i_xx = '  ';
    Emit('other;':i_c.lineNo);
  else;
    Emit('when ' + i_c.factor1C + ' ' + l_operator + ' ' + i_c.factor2C + ';'
         :i_c.lineNo);
  endif;
  Emit('exsr ' + i_c.resultC + ';':i_c.lineNo:1);
  ReportConverted(i_c:i_rule:'');
end-proc;

// ------------------------------------------------------------------
dcl-proc ConvertBegsr;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
  end-pi;

  if i_c.cond <> '';
    ReviewHere(i_c.line:i_c.lineNo:'Conditioning indicators on BEGSR are not allowed');
    return;
  endif;
  if g_inSub;
    ReviewHere(i_c.line:i_c.lineNo:'BEGSR inside a subroutine');
    return;
  endif;
  Emit('begsr ' + i_c.factor1C + ';':i_c.lineNo);
  g_depth += 1;
  g_inSub = *on;
  RptItem(C_STS_CONVERTED:i_c.lineNo:SpecText(i_c.line):'');
end-proc;

// ------------------------------------------------------------------
dcl-proc ConvertEndsr;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
  end-pi;

  if i_c.cond <> '' or i_c.factor2 <> '';
    ReviewHere(i_c.line:i_c.lineNo
               :'ENDSR with conditioning indicators or a return point is not converted');
    return;
  endif;
  if not g_inSub or g_stackCount > 0;
    ReviewHere(i_c.line:i_c.lineNo
               :'ENDSR without a BEGSR, or a group is still open');
    return;
  endif;
  g_depth -= 1;
  if g_depth < 0;
    g_depth = 0;
  endif;
  Emit('endsr;':i_c.lineNo);
  g_inSub = *off;
  RptItem(C_STS_CONVERTED:i_c.lineNo:SpecText(i_c.line):'');
end-proc;

// ------------------------------------------------------------------
// SETON and SETOF: one statement for each resulting indicator.
dcl-proc ConvertSetIndicators;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  dcl-ds l_ind likeds(IAfreeInd_t);
  dcl-s l_statements varchar(250) dim(C_MAXSTMT);
  dcl-s l_count int(10) inz(0);
  dcl-s l_slot int(10);
  dcl-s l_name char(2);
  dcl-s l_statement varchar(250);

  for l_slot = 1 to 3;
    select;
      when l_slot = 1;
        l_name = i_c.result1;
      when l_slot = 2;
        l_name = i_c.result2;
      other;
        l_name = i_c.result3;
    endsl;
    if l_name <> '  ';
      if not RulIndicator(l_name:l_ind) or l_ind.cycle = 'Y';
        ReviewHere(i_c.line:i_c.lineNo:'Indicator ' + %trim(l_name)
                   + ' cannot be set in free-form');
        return;
      endif;
      l_statement = %scanrpl('{n}':%trim(l_ind.freeForm):i_rule.template);
      l_count += 1;
      l_statements(l_count) = l_statement;
    endif;
  endfor;
  if l_count = 0;
    ReviewHere(i_c.line:i_c.lineNo:i_rule.opcode + ' needs a resulting indicator');
    return;
  endif;
  EmitStatements(i_c:i_rule:l_statements:l_count:'');
end-proc;

// ------------------------------------------------------------------
// COMP: one statement for each resulting indicator, at least one.
dcl-proc ConvertCompare;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  dcl-s l_statements varchar(250) dim(C_MAXSTMT);
  dcl-s l_count int(10) inz(0);
  dcl-s l_slot int(10);
  dcl-s l_statement varchar(250);
  dcl-s l_reason varchar(150);

  for l_slot = 1 to 3;
    l_reason = ResultStatement(i_c:i_rule:l_slot:l_statement);
    if l_reason <> '';
      ReviewHere(i_c.line:i_c.lineNo:l_reason);
      return;
    endif;
    if l_statement <> '';
      l_count += 1;
      l_statements(l_count) = l_statement;
    endif;
  endfor;
  if l_count = 0;
    ReviewHere(i_c.line:i_c.lineNo:'COMP needs a resulting indicator');
    return;
  endif;
  EmitStatements(i_c:i_rule:l_statements:l_count:'');
end-proc;

// ------------------------------------------------------------------
// TIME with a 6-digit result field (hhmmss). A 12-digit field also holds the
// system date and is not converted.
dcl-proc ConvertTime;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  dcl-s l_statements varchar(250) dim(C_MAXSTMT);
  dcl-s l_reason varchar(150);

  if i_c.length <> '6' or i_c.decimals <> '0';
    ReviewHere(i_c.line:i_c.lineNo:'TIME is converted for a result field of 6 digits'
               + ' with 0 decimals defined on this line (a 12-digit field holds'
               + ' the system date as well)');
    return;
  endif;
  l_reason = DeclareResult(i_c.resultC:i_c.length:i_c.decimals:*on);
  if l_reason <> '';
    ReviewHere(i_c.line:i_c.lineNo:l_reason);
    return;
  endif;
  l_statements(1) = %scanrpl('{RES}':i_c.resultC:i_rule.template);
  EmitStatements(i_c:i_rule:l_statements:1:'');
end-proc;

// ------------------------------------------------------------------
// The operations that come from a template: arithmetic, EXSR, SORTA, RETRN.
// Factor 1 that the template does not use must be blank (ADD and the like
// have a template for a blank factor 1).
dcl-proc ConvertTemplate;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  dcl-s l_template varchar(200);
  dcl-s l_statements varchar(250) dim(C_MAXSTMT);
  dcl-s l_count int(10) inz(1);
  dcl-s l_slot int(10);
  dcl-s l_statement varchar(250);
  dcl-s l_reason varchar(150);
  dcl-s l_numeric ind;

  l_template = i_rule.template;
  if i_c.factor1C = '' and i_rule.templateNoF1 <> '';
    l_template = i_rule.templateNoF1;
  endif;
  if l_template = '';
    ReviewHere(i_c.line:i_c.lineNo:i_rule.opcode + ' has no free-form template in'
               + ' IACNVOPC');
    return;
  endif;
  if %scan('{F1}':l_template) > 0 and i_c.factor1C = '';
    ReviewHere(i_c.line:i_c.lineNo:'Factor 1 is needed for ' + i_rule.opcode);
    return;
  endif;
  if %scan('{F1}':l_template) = 0 and i_c.factor1C <> '';
    ReviewHere(i_c.line:i_c.lineNo:'Factor 1 is not used by ' + i_rule.opcode);
    return;
  endif;

  // The field a result field defines.
  if i_c.result <> '';
    l_numeric = (i_rule.kind = 'ARITH');
    l_reason = DeclareResult(i_c.resultC:i_c.length:i_c.decimals:l_numeric);
    if l_reason <> '';
      ReviewHere(i_c.line:i_c.lineNo:l_reason);
      return;
    endif;
  endif;

  l_statement = %scanrpl('{F1}':i_c.factor1C:l_template);
  l_statement = %scanrpl('{F2}':i_c.factor2C:l_statement);
  l_statement = %scanrpl('{RES}':i_c.resultC:l_statement);
  if i_c.halfAdjust = 'H';
    l_statement = 'eval(h) ' + l_statement;
  endif;
  l_statements(1) = l_statement;

  // Resulting indicators after an arithmetic operation.
  for l_slot = 1 to 3;
    l_reason = ResultStatement(i_c:i_rule:l_slot:l_statement);
    if l_reason <> '';
      ReviewHere(i_c.line:i_c.lineNo:l_reason);
      return;
    endif;
    if l_statement <> '' and l_count < C_MAXSTMT;
      l_count += 1;
      l_statements(l_count) = l_statement;
    endif;
  endfor;
  EmitStatements(i_c:i_rule:l_statements:l_count:'');
end-proc;

// ------------------------------------------------------------------
// The report line of a group operation that wrote its statement already.
dcl-proc ReportConverted;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
    i_note varchar(190) const;
  end-pi;

  dcl-s l_status char(1);
  dcl-s l_reason varchar(190);

  l_status = i_rule.status;
  l_reason = i_note;
  if i_note <> '';
    l_status = C_STS_ASSUMPTION;
  endif;
  if not g_inSub and not g_cycleNoted;
    g_cycleNoted = *on;
    l_status = C_STS_ASSUMPTION;
    AddReason(l_reason:RulConfig('CYCLE_NOTE':'The RPG cycle is not emulated'));
  endif;
  RptItem(l_status:i_c.lineNo:SpecText(i_c.line):l_reason);
end-proc;

// ------------------------------------------------------------------
// The end of the source: groups still open are reported, and the placeholder
// written before the first calculation becomes the declarations of the fields
// that result fields define.
dcl-proc CalcFinish export;
  dcl-pi *n;
  end-pi;

  dcl-s l_index int(10);

  if g_condLineCount > 0;
    g_depth = 0;
    for l_index = 1 to g_condLineCount;
      RptItem(C_STS_REVIEW:g_condLineNos(l_index):SpecText(g_condLines(l_index))
              :'Indicator line at the end of the source without an operation');
    endfor;
    g_condLineCount = 0;
  endif;
  if g_stackCount > 0;
    RptItem(C_STS_REVIEW:g_lastLineNo:'END'
            :'A group (IFxx, DO, DOWxx, DOUxx or CASxx) is not closed at the end of the'
             + ' source');
  endif;
  if g_inSub;
    RptItem(C_STS_REVIEW:g_lastLineNo:'ENDSR':'A subroutine is not closed at the end'
            + ' of the source');
  endif;

  if g_declAt = 0;
    return;
  endif;
  if g_declCount = 0;
    OutSet(g_declAt:'');
    return;
  endif;
  OutSet(g_declAt:'dcl-s ' + g_declName(1) + ' ' + g_declType(1) + ';');
  for l_index = 2 to g_declCount;
    OutInsertAfter(g_declAt + l_index - 2:'dcl-s ' + g_declName(l_index) + ' '
                   + g_declType(l_index) + ';');
  endfor;
end-proc;
