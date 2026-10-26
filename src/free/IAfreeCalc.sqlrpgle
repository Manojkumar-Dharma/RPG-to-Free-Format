**FREE
// IAfreeCalc - calculation (C) specifications of RPG36 (System/36-compatible
// RPG II) to fully free-form RPGLE (FREE-05). Module of program IACNVFREE.
//
// What an operation code becomes is read from the rule tables (module
// IAfreeRul, rules/opcodes.json): the factors it needs, the free-form
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
/copy qcpysrc,IAfreeOutP
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
dcl-c C_MAXSQL 200;
dcl-c C_MAXKL 100;
dcl-c C_MAXPL 40;
dcl-c C_MAXCALL 100;
dcl-c C_MAXPM 400;
dcl-c C_MAXPROTO 40;
dcl-c C_MAXPLINE 300;
dcl-c C_MAXFLD 1000;
dcl-c C_MAXARR 200;

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

// The last converted IFxx, DOWxx, DOUxx or WHxx header: ANDxx and ORxx lines
// that follow extend its condition. g_hdrIndex is 0 when there is none.
dcl-s g_hdrIndex int(10);
dcl-s g_hdrKeyword varchar(4);
dcl-s g_hdrLine varchar(200);

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

// The fields whose length and type are known: those of the I and E specifications
// (defined by IAfreeCvt through CalcDefineField) and the ones a result field
// defines. Kind C is alphanumeric, N numeric (length in digits).
dcl-s g_fldName varchar(10) dim(C_MAXFLD);
dcl-s g_fldKind char(1) dim(C_MAXFLD);
dcl-s g_fldLen int(10) dim(C_MAXFLD);
dcl-s g_fldDec int(10) dim(C_MAXFLD);
dcl-s g_fldCount int(10);

// The arrays and tables of the E specifications (CalcDefineArray): the name, the
// sequence (A, D or blank), the number of entries, the alternating array of a
// main array and whether it is a table (a name that starts with TAB).
dcl-s g_arrName varchar(10) dim(C_MAXARR);
dcl-s g_arrSeq char(1) dim(C_MAXARR);
dcl-s g_arrDim int(10) dim(C_MAXARR);
dcl-s g_arrAlt varchar(10) dim(C_MAXARR);
dcl-s g_arrTable ind dim(C_MAXARR);
dcl-s g_arrCount int(10);
dcl-s g_lookupDeclared ind;

// The operation before this one, and the operands of the last DIV for the MVR that
// follows it.
dcl-s g_prevOp varchar(5) inz('');
dcl-s g_divF1 varchar(60) inz('');
dcl-s g_divF2 varchar(60) inz('');
dcl-s g_divRes varchar(60) inz('');

// Key lists (KLIST and KFLD), collected before the conversion: the name, the key
// fields joined with ':', their number and whether a KFLD was not a plain name.
dcl-s g_klName varchar(10) dim(C_MAXKL);
dcl-s g_klFields varchar(200) dim(C_MAXKL);
dcl-s g_klNumber int(10) dim(C_MAXKL);
dcl-s g_klBad ind dim(C_MAXKL);
dcl-s g_klCount int(10);
dcl-s g_klOpen ind;

// CALL, PARM and PLIST, collected before the conversion (CalcPrescan): the PARM
// lines in order (factor 1, factor 2, result field, length, decimals), the first
// of each PLIST and each CALL and their number. g_parmTarget is the list that
// takes the next PARM (a PLIST, or minus a CALL). g_callSeen counts the CALL
// lines of the conversion; g_parmMode is the owner of the PARM lines in the
// conversion (C call, P plist, X not converted, blank none). The prototypes
// written before the first calculation are kept with the types of the first call.
dcl-s g_pmF1 varchar(30) dim(C_MAXPM);
dcl-s g_pmF2 varchar(30) dim(C_MAXPM);
dcl-s g_pmRes varchar(30) dim(C_MAXPM);
dcl-s g_pmLen varchar(3) dim(C_MAXPM);
dcl-s g_pmDec char(1) dim(C_MAXPM);
dcl-s g_pmCount int(10);
dcl-s g_plName varchar(10) dim(C_MAXPL);
dcl-s g_plFirst int(10) dim(C_MAXPL);
dcl-s g_plNum int(10) dim(C_MAXPL);
dcl-s g_plCount int(10);
dcl-s g_callFirst int(10) dim(C_MAXCALL);
dcl-s g_callNum int(10) dim(C_MAXCALL);
dcl-s g_callCount int(10);
dcl-s g_callSeen int(10);
dcl-s g_parmTarget int(10);
dcl-s g_parmMode char(1);
dcl-s g_parmReason varchar(150);
dcl-s g_protoName varchar(10) dim(C_MAXPROTO);
dcl-s g_protoSig varchar(250) dim(C_MAXPROTO);
dcl-s g_protoCount int(10);
dcl-s g_protoLine varchar(100) dim(C_MAXPLINE);
dcl-s g_protoLineCount int(10);

// An embedded SQL statement (C/EXEC SQL, C+ lines, C/END-EXEC) being read. Text
// is kept from column 16 of the first line and columns 8 to 74 of the others.
dcl-s g_sqlOpen ind;
dcl-s g_sqlTooLong ind;
dcl-s g_sqlCount int(10);
dcl-s g_sqlText varchar(70) dim(C_MAXSQL);
dcl-s g_sqlLineNo int(10) dim(C_MAXSQL);
dcl-s g_sqlRaw char(100) dim(C_MAXSQL);

// ------------------------------------------------------------------
dcl-proc CalcStart export;
  dcl-pi *n;
  end-pi;

  g_stackCount = 0;
  g_depth = 0;
  g_inSub = *off;
  g_cycleNoted = *off;
  g_lastLineNo = 0;
  g_hdrIndex = 0;
  g_condCount = 0;
  g_condLineCount = 0;
  g_condBad = '';
  g_declCount = 0;
  g_declAt = 0;
  g_doCount = 0;
  g_sqlOpen = *off;
  g_sqlTooLong = *off;
  g_sqlCount = 0;
  g_klCount = 0;
  g_klOpen = *off;
  g_pmCount = 0;
  g_plCount = 0;
  g_callCount = 0;
  g_callSeen = 0;
  g_parmTarget = 0;
  g_parmMode = ' ';
  g_parmReason = '';
  g_protoCount = 0;
  g_protoLineCount = 0;
  g_fldCount = 0;
  g_arrCount = 0;
  g_lookupDeclared = *off;
  g_prevOp = '';
  g_divF1 = '';
  g_divF2 = '';
  g_divRes = '';
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

  // A table name in a calculation is the entry the last LOKUP selected.
  if IsTableName(l_upper);
    o_text = i_text + '(' + i_text + '_IDX)';
    return *on;
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
// The text of a field of a C specification, read through the column map of the
// dialect (IACNVLAY). Blank when the dialect has no such field.
dcl-proc Fld;
  dcl-pi *n varchar(80);
    i_line char(100) const;
    i_field varchar(12) const;
  end-pi;

  dcl-s l_from int(10);
  dcl-s l_len int(10);

  if not RulLayout('C':i_field:l_from:l_len) or l_len = 0;
    return '';
  endif;
  return %subst(i_line:l_from:l_len);
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
  dcl-s l_from int(10);
  dcl-s l_len int(10);

  o_reason = '';
  for l_slot = 1 to 3;
    if not RulLayout('C':'IND' + %char(l_slot):l_from:l_len);
      leave;
    endif;
    l_not = Fld(i_line:'NOT' + %char(l_slot));
    l_name = Fld(i_line:'IND' + %char(l_slot));
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
// Remembers the header just written so that ANDxx and ORxx can extend it.
dcl-proc SetHeader;
  dcl-pi *n;
    i_keyword varchar(4) const;
    i_text varchar(200) const;
  end-pi;

  g_hdrIndex = OutCount();
  g_hdrKeyword = i_keyword;
  g_hdrLine = i_text;
end-proc;

// ------------------------------------------------------------------
// An ANDxx or ORxx line that cannot be converted must not leave the header it
// belongs to with half of its condition: the header gets a condition that is
// never true (always true for DOU, which runs its body once), and the line is
// reported R.
dcl-proc SafeHeader;
  dcl-pi *n;
  end-pi;

  dcl-s l_condition varchar(5);

  if g_hdrIndex = 0;
    return;
  endif;
  if g_hdrKeyword = 'dou';
    l_condition = '*on';
  else;
    l_condition = '*off';
  endif;
  OutSet(g_hdrIndex:%subst(g_hdrLine:1:%scan(g_hdrKeyword:g_hdrLine) - 1)
         + g_hdrKeyword + ' ' + l_condition + '; // ANDxx/ORxx not converted');
  g_hdrIndex = 0;
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
  dcl-s l_op varchar(5);

  // An ANDxx or ORxx line that fails leaves its header safe.
  if g_hdrIndex > 0;
    l_op = Up(%trim(Fld(i_line:'OPERATION')));
    if %len(l_op) = 5 and %subst(l_op:1:3) = 'AND'
       and RulComparison(%subst(l_op:4:2)) <> '';
      SafeHeader();
    elseif %len(l_op) = 4 and %subst(l_op:1:2) = 'OR'
       and RulComparison(%subst(l_op:3:2)) <> '';
      SafeHeader();
    else;
      g_hdrIndex = 0;
    endif;
  endif;

  l_reason = i_reason;
  for l_index = 1 to g_condLineCount;
    Emit('// ' + RulDialectLabel() + ': ' + SpecText(g_condLines(l_index))
         :g_condLineNos(l_index));
    RptItem(C_STS_REVIEW:g_condLineNos(l_index):SpecText(g_condLines(l_index))
            :'Indicator line of an operation that is not converted');
  endfor;
  Emit('// ' + RulDialectLabel() + ': ' + SpecText(i_line):i_lineNo);
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
  if i_decimals = ' ' and not i_numeric;
    CalcDefineField(Up(i_name):'C':l_length:0);
  else;
    CalcDefineField(Up(i_name):'N':l_length:l_decimals);
  endif;
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
    i_test varchar(250) const options(*nopass);
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
  // TESTN, TESTZ and TESTB give their own test (it depends on the field).
  if %parms >= 5 and i_test <> '';
    l_test = i_test;
  else;
    l_test = RulResultTest(l_code);
  endif;
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
  dcl-s l_prevOp varchar(5);

  g_lastLineNo = i_lineNo;
  l_up = %xlate(C_LOWER:C_UPPER:i_line);

  // The CALL lines are counted as CalcPrescan counted them.
  if %subst(l_up:7:1) <> '*' and %subst(l_up:7:1) <> '/'
     and %subst(l_up:7:1) <> '+' and %trim(Fld(l_up:'OPERATION')) = 'CALL';
    g_callSeen += 1;
  endif;

  // Everything between columns 7 and 59 blank: nothing to convert.
  if %trim(Fld(i_line:'ALLC')) = '';
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
  l_c.level = Fld(l_up:'LEVEL');
  l_c.factor1 = %trim(Fld(i_line:'FACTOR1'));
  l_c.operation = %trim(Fld(l_up:'OPERATION'));
  l_c.factor2 = %trim(Fld(i_line:'FACTOR2'));
  l_c.result = %trim(Fld(i_line:'RESULT'));
  l_c.length = %trim(Fld(l_up:'LENGTH'));
  l_c.decimals = Fld(l_up:'DECIMALS');
  l_c.halfAdjust = Fld(l_up:'EXTENDER');
  l_c.result1 = Fld(l_up:'RES1');
  l_c.result2 = Fld(l_up:'RES2');
  l_c.result3 = Fld(l_up:'RES3');
  l_c.comment = %trimr(Fld(i_line:'COMMENT'));

  l_isCondOnly = ((%trim(Fld(i_line:'BODY')) = '')
                  and (%trim(Fld(i_line:'CONDALL')) <> ''
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
  l_prevOp = g_prevOp;
  g_prevOp = '';
  if l_c.operation = '';
    ReviewHere(i_line:i_lineNo:'No operation code');
    return;
  endif;
  if not RulOpcode(l_c.operation:l_rule:l_xx);
    ReviewHere(i_line:i_lineNo:'Operation code ' + l_c.operation + ' is not known');
    return;
  endif;
  if l_rule.opcode <> 'CALL' and l_rule.opcode <> 'PARM'
     and l_rule.opcode <> 'PLIST';
    g_parmMode = ' ';
  endif;
  l_isStructure = (l_rule.kind = 'IF' or l_rule.kind = 'DO' or l_rule.kind = 'DOW'
                   or l_rule.kind = 'DOU' or l_rule.kind = 'CASE'
                   or l_rule.kind = 'SELEC');
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
  // String operations read their own colon operands and the P extender.
  if l_rule.kind = 'STRING';
    g_hdrIndex = 0;
    ConvertString(l_c:l_rule);
    return;
  endif;
  // LOKUP reads its own operands: array name with an index, tables.
  if l_rule.kind = 'LOOKUP';
    g_hdrIndex = 0;
    ConvertLookup(l_c:l_rule);
    return;
  endif;
  // DEFN, DSPLY: factor 1 and factor 2 can hold *LIKE, *EXT and *M entries.
  if l_rule.kind = 'DEFN';
    g_hdrIndex = 0;
    ConvertDefn(l_c:l_rule);
    return;
  endif;
  if l_rule.kind = 'DISPLAY';
    g_hdrIndex = 0;
    ConvertDsply(l_c:l_rule);
    return;
  endif;
  // Bit operations, TESTN and TESTZ read their own factor 2 (bit numbers).
  if l_rule.opcode = 'BITON' or l_rule.opcode = 'BITOF'
     or l_rule.opcode = 'TESTB' or l_rule.opcode = 'TESTN'
     or l_rule.opcode = 'TESTZ';
    g_hdrIndex = 0;
    ConvertBitTest(l_c:l_rule);
    return;
  endif;
  if l_rule.opcode = 'MHHZO' or l_rule.opcode = 'MHLZO'
     or l_rule.opcode = 'MLHZO' or l_rule.opcode = 'MLLZO';
    g_hdrIndex = 0;
    ConvertZoneMove(l_c:l_rule);
    return;
  endif;
  // CALL, PARM and PLIST read their own operands.
  if l_rule.opcode = 'CALL' or l_rule.opcode = 'PARM' or l_rule.opcode = 'PLIST';
    g_hdrIndex = 0;
    select;
      when l_rule.opcode = 'CALL';
        ConvertCall(l_c:l_rule);
      when l_rule.opcode = 'PLIST';
        ConvertPlist(l_c);
      other;
        ConvertParm(l_c);
    endsl;
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

  if l_c.halfAdjust <> ' ' and (l_c.halfAdjust <> 'H' or l_rule.halfAdjust <> 'Y')
     and not (l_c.halfAdjust = 'P' and l_rule.kind = 'MOVE');
    ReviewHere(i_line:i_lineNo:'Half adjust is not allowed for ' + l_rule.opcode
               :l_isStructure);
    return;
  endif;

  if l_rule.kind <> 'ANDOR';
    g_hdrIndex = 0;
  endif;

  // DIV keeps its operands for the MVR after it, which divides again with %rem.
  g_prevOp = l_rule.opcode;
  if l_rule.opcode = 'DIV';
    g_divF1 = l_c.factor1C;
    g_divF2 = l_c.factor2C;
    g_divRes = l_c.resultC;
  endif;
  if l_rule.opcode = 'MVR';
    l_reason = MvrOperands(l_prevOp);
    if l_reason <> '';
      ReviewHere(i_line:i_lineNo:l_reason);
      return;
    endif;
    l_c.factor1 = g_divF1;
    l_c.factor1C = g_divF1;
    l_c.factor2 = g_divF2;
    l_c.factor2C = g_divF2;
  endif;
  select;
    when l_rule.kind = 'IF';
      ConvertIf(l_c:l_rule:l_xx);
    when l_rule.kind = 'ANDOR';
      ConvertAndOr(l_c:l_rule:l_xx);
    when l_rule.kind = 'WHEN';
      ConvertWhen(l_c:l_rule:l_xx);
    when l_rule.kind = 'SELEC';
      ConvertSelec(l_c:l_rule);
    when l_rule.kind = 'OTHER';
      ConvertOther(l_c:l_rule);
    when l_rule.kind = 'LOOPCTL';
      ConvertLoopControl(l_c:l_rule);
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
    when l_rule.kind = 'FILE';
      ConvertFileOp(l_c:l_rule);
    when l_rule.kind = 'KEY';
      ConvertKeyList(l_c);
    when l_rule.kind = 'MOVE';
      ConvertMove(l_c:l_rule);
    when l_rule.kind = 'OUTPUT';
      ConvertExcept(l_c:l_rule);
    when l_rule.kind = 'DEBUG' and l_rule.opcode = 'DUMP';
      ConvertDump(l_c:l_rule);
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

  l_op = %trim(Fld(i_up:'OPERATION'));
  return l_op = 'DO' or l_op = 'CAS' or l_op = 'SELEC'
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
    SetHeader('if':IndentText() + 'if ' + l_compare);
    if not Push('IF ':1:0:'');
      ReviewHere(i_c.line:i_c.lineNo:'Groups are nested too deep');
      return;
    endif;
  else;
    Emit('if ' + i_c.cond + ';':i_c.lineNo);
    g_depth += 1;
    Emit('if ' + l_compare + ';':i_c.lineNo);
    SetHeader('if':IndentText() + 'if ' + l_compare);
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
  SetHeader(Low(i_rule.opcode):IndentText() + Low(i_rule.opcode) + ' '
            + i_c.factor1C + ' ' + l_operator + ' ' + i_c.factor2C);
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
  if i_c.operation <> 'END' and l_kind <> 'RVW' and not EndMatches(i_c.operation:l_kind);
    ReviewHere(i_c.line:i_c.lineNo:i_c.operation + ' does not match the open group');
    return;
  endif;
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
    when l_kind = 'CAS' or l_kind = 'SEL';
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
// Does ENDIF, ENDDO, ENDCS or ENDSL close a group of this kind?
dcl-proc EndMatches;
  dcl-pi *n ind;
    i_operation varchar(5) const;
    i_kind char(3) const;
  end-pi;

  select;
    when i_operation = 'ENDIF';
      return i_kind = 'IF ' or i_kind = 'IFW';
    when i_operation = 'ENDDO';
      return i_kind = 'DO ' or i_kind = 'DOW' or i_kind = 'DOU';
    when i_operation = 'ENDCS';
      return i_kind = 'CAS';
    when i_operation = 'ENDSL';
      return i_kind = 'SEL';
  endsl;
  return *on;
end-proc;

// ------------------------------------------------------------------
// ANDxx and ORxx: extend the condition of the IFxx, DOWxx, DOUxx or WHxx
// header just before. AND binds tighter than OR in RPG and in free-form.
dcl-proc ConvertAndOr;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
    i_xx char(2) const;
  end-pi;

  dcl-s l_operator varchar(2);
  dcl-s l_joiner varchar(5);

  if i_c.cond <> '';
    ReviewHere(i_c.line:i_c.lineNo:'Conditioning indicators on ' + i_rule.opcode
               + 'xx are not converted');
    return;
  endif;
  l_operator = RulComparison(i_xx);
  if l_operator = '';
    ReviewHere(i_c.line:i_c.lineNo:i_rule.opcode + ' needs xx: GT, LT, EQ, NE, GE'
               + ' or LE');
    return;
  endif;
  if g_hdrIndex = 0;
    ReviewHere(i_c.line:i_c.lineNo:i_rule.opcode + 'xx without an IFxx, DOWxx, DOUxx'
               + ' or WHxx that was converted');
    return;
  endif;
  if i_rule.opcode = 'AND';
    l_joiner = ' and ';
  else;
    l_joiner = ' or ';
  endif;
  g_hdrLine += l_joiner + i_c.factor1C + ' ' + l_operator + ' ' + i_c.factor2C;
  OutSet(g_hdrIndex:g_hdrLine + ';');
  ReportConverted(i_c:i_rule:'');
end-proc;

// ------------------------------------------------------------------
// SELEC: SELECT. The WHxx and OTHER lines are one level in, their statements
// two levels in; ENDSL (or END) closes the group.
dcl-proc ConvertSelec;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  if i_c.cond <> '';
    ReviewHere(i_c.line:i_c.lineNo:'Conditioning indicators on SELEC are not converted'
               :*on);
    return;
  endif;
  Emit('select;':i_c.lineNo);
  if not Push('SEL':2:0:'');
    ReviewHere(i_c.line:i_c.lineNo:'Groups are nested too deep');
    return;
  endif;
  ReportConverted(i_c:i_rule:'');
end-proc;

// ------------------------------------------------------------------
dcl-proc ConvertWhen;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
    i_xx char(2) const;
  end-pi;

  dcl-s l_operator varchar(2);

  if i_c.cond <> '';
    ReviewHere(i_c.line:i_c.lineNo:'Conditioning indicators on WHxx are not converted');
    return;
  endif;
  l_operator = RulComparison(i_xx);
  if l_operator = '';
    ReviewHere(i_c.line:i_c.lineNo:'WH needs xx: GT, LT, EQ, NE, GE or LE');
    return;
  endif;
  if g_stackCount = 0 or g_stackKind(g_stackCount) <> 'SEL';
    ReviewHere(i_c.line:i_c.lineNo:'WHxx without a SELEC that was converted, or inside'
               + ' a group that is still open');
    return;
  endif;
  Emit('when ' + i_c.factor1C + ' ' + l_operator + ' ' + i_c.factor2C + ';'
       :i_c.lineNo:-1);
  SetHeader('when':IndentText(-1) + 'when ' + i_c.factor1C + ' ' + l_operator + ' '
            + i_c.factor2C);
  ReportConverted(i_c:i_rule:'');
end-proc;

// ------------------------------------------------------------------
dcl-proc ConvertOther;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  if i_c.cond <> '';
    ReviewHere(i_c.line:i_c.lineNo:'Conditioning indicators on OTHER are not converted');
    return;
  endif;
  if g_stackCount = 0 or g_stackKind(g_stackCount) <> 'SEL';
    ReviewHere(i_c.line:i_c.lineNo:'OTHER without a SELEC that was converted, or inside'
               + ' a group that is still open');
    return;
  endif;
  Emit('other;':i_c.lineNo:-1);
  ReportConverted(i_c:i_rule:'');
end-proc;

// ------------------------------------------------------------------
// ITER and LEAVE need a DO, DOWxx or DOUxx group around them.
dcl-proc ConvertLoopControl;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_inLoop ind inz(*off);

  for l_index = 1 to g_stackCount;
    if g_stackKind(l_index) = 'DO ' or g_stackKind(l_index) = 'DOW'
       or g_stackKind(l_index) = 'DOU';
      l_inLoop = *on;
    endif;
  endfor;
  if not l_inLoop;
    ReviewHere(i_c.line:i_c.lineNo:i_rule.opcode + ' is not inside a DO, DOWxx or DOUxx'
               + ' group that was converted');
    return;
  endif;
  ConvertTemplate(i_c:i_rule);
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
// Splits an operand at its colon (not inside a literal): STRING:T is the string
// and its start, 'AB':2 the compare string and its length, TXT:1 the string and
// its number of blanks.
dcl-proc SplitColon;
  dcl-pi *n;
    i_text varchar(30) const;
    o_first varchar(30);
    o_second varchar(30);
    o_has ind;
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_inLiteral ind inz(*off);

  o_first = i_text;
  o_second = '';
  o_has = *off;
  for l_index = 1 to %len(i_text);
    if %subst(i_text:l_index:1) = C_QUOTE;
      l_inLiteral = not l_inLiteral;
    elseif %subst(i_text:l_index:1) = ':' and not l_inLiteral;
      if l_index = 1;
        o_first = '';
      else;
        o_first = %subst(i_text:1:l_index - 1);
      endif;
      if l_index < %len(i_text);
        o_second = %subst(i_text:l_index + 1);
      endif;
      o_has = *on;
      leave;
    endif;
  endfor;
end-proc;

// ------------------------------------------------------------------
// One operand of a string operation as free-form text. Figurative constants
// cannot be used in these operations.
dcl-proc StringOperand;
  dcl-pi *n ind;
    i_text varchar(30) const;
    o_text varchar(30);
    o_reason varchar(150);
  end-pi;

  if not ConvOperand(i_text:o_text:o_reason);
    return *off;
  endif;
  if %len(o_text) > 0;
    if %subst(o_text:1:1) = '*';
      o_reason = 'Figurative constants cannot be used in a string operation: '
                 + i_text;
      return *off;
    endif;
  endif;
  return *on;
end-proc;

// ------------------------------------------------------------------
// The free-form name of a resulting indicator, or the reason it cannot be used.
dcl-proc IndicatorName;
  dcl-pi *n varchar(150);
    i_name char(2) const;
    o_free varchar(20);
  end-pi;

  dcl-ds l_ind likeds(IAfreeInd_t);

  o_free = '';
  if not RulIndicator(i_name:l_ind);
    return 'Indicator ' + %trim(i_name) + ' is not known';
  endif;
  if l_ind.cycle = 'Y';
    return %trim(l_ind.reason);
  endif;
  o_free = %trim(l_ind.freeForm);
  return '';
end-proc;

// ------------------------------------------------------------------
// Defines a field whose length and type are known (called by IAfreeCvt for the
// fields of the I specifications and the entries of the arrays of the E
// specifications). Kind C: alphanumeric, length in characters. Kind N: numeric,
// length in digits.
dcl-proc CalcDefineField export;
  dcl-pi *n;
    i_name varchar(10) const;
    i_kind char(1) const;
    i_length int(10) const;
    i_decimals int(10) const;
  end-pi;

  dcl-s l_index int(10);

  for l_index = 1 to g_fldCount;
    if g_fldName(l_index) = Up(i_name);
      return;
    endif;
  endfor;
  if g_fldCount >= C_MAXFLD;
    return;
  endif;
  g_fldCount += 1;
  g_fldName(g_fldCount) = Up(i_name);
  g_fldKind(g_fldCount) = i_kind;
  g_fldLen(g_fldCount) = i_length;
  g_fldDec(g_fldCount) = i_decimals;
end-proc;

// ------------------------------------------------------------------
// EXCPT (FREE-06): writes the record formats of the printer DDS that were made
// from the exception records of the O specifications (module IAfreeOut).
dcl-proc ConvertExcept;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  dcl-s l_name varchar(10);
  dcl-s l_count int(10);
  dcl-s l_k int(10);
  dcl-s l_cond varchar(80);
  dcl-s l_statements varchar(250) dim(C_MAXSTMT);

  l_name = Up(i_c.factor2);
  if %len(l_name) > 6;
    ReviewHere(i_c.line:i_c.lineNo:'EXCPT name ' + l_name + ' is too long');
    return;
  endif;
  l_count = OutExceptCount(l_name);
  if l_count = 0 or l_count > C_MAXSTMT;
    ReviewHere(i_c.line:i_c.lineNo:'No exception output record named '
               + l_name + ' was converted (see the O specifications)');
    return;
  endif;
  for l_k = 1 to l_count;
    l_cond = OutExceptCond(l_name:l_k);
    if l_cond = '';
      l_statements(l_k) = 'write ' + OutExceptFormat(l_name:l_k);
    else;
      l_statements(l_k) = 'if ' + l_cond + '; write '
                          + OutExceptFormat(l_name:l_k) + '; endif';
    endif;
  endfor;
  EmitStatements(i_c:i_rule:l_statements:l_count:'');
end-proc;

// ------------------------------------------------------------------
// Kind and size of a field defined so far (for the output specifications).
dcl-proc CalcFieldInfo export;
  dcl-pi *n ind;
    i_name varchar(10) const;
    o_kind char(1);
    o_length int(10);
    o_decimals int(10);
  end-pi;

  dcl-s l_index int(10);

  for l_index = 1 to g_fldCount;
    if g_fldName(l_index) = Up(i_name);
      o_kind = g_fldKind(l_index);
      o_length = g_fldLen(l_index);
      o_decimals = g_fldDec(l_index);
      return *on;
    endif;
  endfor;
  return *off;
end-proc;

// ------------------------------------------------------------------
// Kind, length and decimal positions of an operand of MOVE or MOVEL as free-form
// text: a character or numeric literal, a figurative constant (kind F), a field
// or an array element. Returns *off when the operand is a field of unknown
// length or type.
dcl-proc OperandType;
  dcl-pi *n ind;
    i_text varchar(30) const;
    o_kind char(1);
    o_length int(10);
    o_decimals int(10);
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_paren int(10);
  dcl-s l_name varchar(30);
  dcl-s l_point int(10);
  dcl-s l_char char(1);

  o_kind = ' ';
  o_length = 0;
  o_decimals = 0;
  if %len(i_text) = 0;
    return *off;
  endif;

  select;
    when %subst(i_text:1:1) = '*';
      o_kind = 'F';
      return *on;
    when %subst(i_text:1:1) = C_QUOTE;
      // Character literal: a doubled quote is one character.
      o_kind = 'C';
      l_index = 2;
      dow l_index < %len(i_text);
        o_length += 1;
        if %subst(i_text:l_index:1) = C_QUOTE;
          l_index += 1;
        endif;
        l_index += 1;
      enddo;
      return (o_length > 0);
    when IsNumberLiteral(i_text);
      o_kind = 'N';
      l_point = %scan('.':i_text);
      for l_index = 1 to %len(i_text);
        l_char = %subst(i_text:l_index:1);
        if l_char >= '0' and l_char <= '9';
          o_length += 1;
          if l_point > 0 and l_index > l_point;
            o_decimals += 1;
          endif;
        endif;
      endfor;
      return *on;
  endsl;

  // A field or an array element.
  l_name = i_text;
  l_paren = %scan('(':l_name);
  if l_paren > 1;
    l_name = %subst(l_name:1:l_paren - 1);
  endif;
  l_name = Up(l_name);
  for l_index = 1 to g_fldCount;
    if g_fldName(l_index) = l_name;
      o_kind = g_fldKind(l_index);
      o_length = g_fldLen(l_index);
      o_decimals = g_fldDec(l_index);
      return *on;
    endif;
  endfor;
  return *off;
end-proc;

// ------------------------------------------------------------------
// Defines an array or table of an E specification (called by IAfreeCvt). A name
// that starts with TAB is a table: its current entry is selected by LOKUP, which
// the conversion keeps in the field NAME_IDX (declared here, first entry 1).
dcl-proc CalcDefineArray export;
  dcl-pi *n;
    i_name varchar(10) const;
    i_sequence char(1) const;
    i_dim int(10) const;
    i_alt varchar(10) const;
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_isTable ind;

  if g_arrCount >= C_MAXARR;
    return;
  endif;
  g_arrCount += 1;
  g_arrName(g_arrCount) = Up(i_name);
  g_arrSeq(g_arrCount) = i_sequence;
  g_arrDim(g_arrCount) = i_dim;
  g_arrAlt(g_arrCount) = Up(i_alt);
  l_isTable = (%scan('TAB':Up(i_name)) = 1);
  g_arrTable(g_arrCount) = l_isTable;
  if l_isTable;
    DeclareHidden(Up(i_name) + '_IDX':'int(10) inz(1)');
  endif;
end-proc;

// ------------------------------------------------------------------
dcl-proc ArrayInfo;
  dcl-pi *n ind;
    i_name varchar(30) const;
    o_isTable ind;
    o_sequence char(1);
    o_dim int(10);
    o_alt varchar(10);
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_name varchar(30);

  l_name = Up(i_name);
  for l_index = 1 to g_arrCount;
    if g_arrName(l_index) = l_name;
      o_isTable = g_arrTable(l_index);
      o_sequence = g_arrSeq(l_index);
      o_dim = g_arrDim(l_index);
      o_alt = g_arrAlt(l_index);
      return *on;
    endif;
  endfor;
  return *off;
end-proc;

// ------------------------------------------------------------------
dcl-proc IsTableName;
  dcl-pi *n ind;
    i_upper varchar(30) const;
  end-pi;

  dcl-s l_index int(10);

  for l_index = 1 to g_arrCount;
    if g_arrName(l_index) = i_upper and g_arrTable(l_index);
      return *on;
    endif;
  endfor;
  return *off;
end-proc;

// ------------------------------------------------------------------
// A field of the conversion itself (the index of a table, the result of a
// lookup): declared with the other fields at the end, once.
dcl-proc DeclareHidden;
  dcl-pi *n;
    i_name varchar(30) const;
    i_type varchar(40) const;
  end-pi;

  dcl-s l_index int(10);

  for l_index = 1 to g_declCount;
    if g_declName(l_index) = Up(i_name);
      return;
    endif;
  endfor;
  if g_declCount >= C_MAXDECL;
    return;
  endif;
  g_declCount += 1;
  g_declName(g_declCount) = Up(i_name);
  g_declType(g_declCount) = i_type;
end-proc;

// ------------------------------------------------------------------
// MVR: the remainder of the DIV before it. Only for whole numbers, because %REM
// needs integer operands: dividend, divisor and the quotient field must have no
// decimal positions. Returns the reason when that cannot be shown.
dcl-proc MvrOperands;
  dcl-pi *n varchar(190);
    i_prevOp varchar(5) const;
  end-pi;

  dcl-s l_kind char(1);
  dcl-s l_len int(10);
  dcl-s l_dec int(10);

  if i_prevOp <> 'DIV';
    return 'MVR must come immediately after the DIV it belongs to';
  endif;
  if g_divF1 = '';
    return 'MVR after a DIV without factor 1 is not converted: the dividend is '
           + 'the quotient field';
  endif;
  if not OperandType(g_divF1:l_kind:l_len:l_dec);
    return 'Length and type of ' + g_divF1 + ' are not known: %REM needs a whole '
           + 'number';
  endif;
  if l_kind <> 'N' or l_dec <> 0;
    return '%REM needs whole numbers: ' + g_divF1 + ' has decimal positions or '
           + 'is not numeric';
  endif;
  if not OperandType(g_divF2:l_kind:l_len:l_dec);
    return 'Length and type of ' + g_divF2 + ' are not known: %REM needs a whole '
           + 'number';
  endif;
  if l_kind <> 'N' or l_dec <> 0;
    return '%REM needs whole numbers: ' + g_divF2 + ' has decimal positions or '
           + 'is not numeric';
  endif;
  if not OperandType(g_divRes:l_kind:l_len:l_dec);
    return 'Length and type of the quotient field ' + g_divRes + ' are not known';
  endif;
  if l_dec <> 0;
    return 'The quotient field ' + g_divRes + ' has decimal positions: the '
           + 'remainder is not the %REM of the operands';
  endif;
  return '';
end-proc;

// ------------------------------------------------------------------
// DEFN *LIKE: dcl-s NAME like(OTHER); with the length change of columns 49-51
// (+n or -n) as like(OTHER:+n). The declaration goes with the others at the top.
// *NAMVAR (data areas) is converted with IN and OUT.
dcl-proc ConvertDefn;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  dcl-s l_reason varchar(190) inz('');
  dcl-s l_base varchar(30);
  dcl-s l_res varchar(30);
  dcl-s l_adj varchar(10) inz('');
  dcl-s l_len varchar(3);
  dcl-s l_comma int(10);
  dcl-s l_kind char(1);
  dcl-s l_flen int(10);
  dcl-s l_fdec int(10);
  dcl-s l_delta int(10) inz(0);
  dcl-s l_sign char(1);

  select;
    when i_c.cond <> '';
      l_reason = 'Conditioning indicators are not allowed for DEFN';
    when Up(i_c.factor1) = '*NAMVAR';
      l_reason = 'DEFN *NAMVAR (data area) is not converted yet';
    when Up(i_c.factor1) <> '*LIKE';
      l_reason = 'Factor 1 of DEFN must be *LIKE or *NAMVAR';
    when i_c.factor2 = '' or i_c.result = '';
      l_reason = 'DEFN *LIKE needs the referenced field in factor 2 and the '
                 + 'defined field in the result field';
    when i_c.result1 <> '  ' or i_c.result2 <> '  ' or i_c.result3 <> '  ';
      l_reason = 'Resulting indicators are not used by DEFN';
    when i_c.halfAdjust <> ' ';
      l_reason = 'Operation extender ' + i_c.halfAdjust + ' is not allowed for DEFN';
  endsl;

  // Factor 2: a field, an array (an element is the model) or a table.
  if l_reason = '';
    l_base = i_c.factor2;
    l_comma = %scan(',':l_base);
    if l_comma > 1;
      l_base = %subst(l_base:1:l_comma - 1);
    endif;
    if %subst(l_base:1:1) = C_QUOTE or IsNumberLiteral(l_base)
       or not IsName(l_base);
      l_reason = 'Factor 2 of DEFN *LIKE must be the name of a field';
    elseif %scan(',':i_c.result) > 0 or not IsName(i_c.result);
      l_reason = 'The result field of DEFN *LIKE must be a field name';
    elseif ArrayInfoQuick(i_c.result);
      l_reason = 'The result field of DEFN *LIKE cannot be an array or table';
    endif;
  endif;

  // The change of length: + or - in column 49, the number in 50-51.
  if l_reason = '' and i_c.length <> '';
    l_sign = %subst(i_c.length:1:1);
    if (l_sign <> '+' and l_sign <> '-') or %len(i_c.length) < 2;
      l_reason = 'The length of DEFN *LIKE must be + or - and a number '
                 + '(columns 49-51)';
    else;
      l_len = %trim(%subst(i_c.length:2));
      if l_len = '' or %check(C_DIGITS:l_len) > 0;
        l_reason = 'The length of DEFN *LIKE must be + or - and a number '
                   + '(columns 49-51)';
      else;
        l_delta = %int(l_len);
        l_adj = ':' + l_sign + %trim(%char(l_delta));
        if l_sign = '-';
          l_delta = -l_delta;
        endif;
      endif;
    endif;
  endif;

  if l_reason <> '';
    ReviewHere(i_c.line:i_c.lineNo:l_reason);
    return;
  endif;

  DeclareHidden(Up(i_c.result):'like(' + l_base + l_adj + ')');
  if OperandType(l_base:l_kind:l_flen:l_fdec) and l_kind <> 'F';
    CalcDefineField(Up(i_c.result):l_kind:l_flen + l_delta:l_fdec);
  endif;
  RptItem(C_STS_CONVERTED:i_c.lineNo:SpecText(i_c.line):'');
end-proc;

// ------------------------------------------------------------------
dcl-proc ArrayInfoQuick;
  dcl-pi *n ind;
    i_name varchar(30) const;
  end-pi;

  dcl-s l_table ind;
  dcl-s l_seq char(1);
  dcl-s l_dim int(10);
  dcl-s l_alt varchar(10);

  return ArrayInfo(i_name:l_table:l_seq:l_dim:l_alt);
end-proc;

// ------------------------------------------------------------------
// DSPLY (RPG/400 reference chapter 11): dsply message msgq response; with the
// error indicator as dsply(e) and *INnn = %error. A response without an output
// queue uses *EXT (the requester) where RPG/400 uses the job type; a message
// identifier (*M) and a missing message are not converted.
dcl-proc ConvertDsply;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  dcl-ds l_rule likeds(IAfreeOpc_t);
  dcl-s l_msg varchar(30) inz('');
  dcl-s l_queue varchar(30) inz('');
  dcl-s l_res varchar(30) inz('');
  dcl-s l_ext varchar(3) inz('');
  dcl-s l_ind varchar(20) inz('');
  dcl-s l_reason varchar(150) inz('');
  dcl-s l_note varchar(190) inz('');
  dcl-s l_stmt varchar(250);
  dcl-s l_statements varchar(250) dim(C_MAXSTMT);
  dcl-s l_count int(10) inz(0);
  dcl-s l_kind char(1);
  dcl-s l_len int(10);
  dcl-s l_dec int(10);

  select;
    when i_c.result1 <> '  ' or i_c.result3 <> '  ';
      l_reason = 'Only the error indicator (columns 56-57) is used by DSPLY';
    when i_c.halfAdjust <> ' ';
      l_reason = 'Operation extender ' + i_c.halfAdjust + ' is not allowed for '
                 + 'DSPLY';
    when i_c.factor1 = '';
      l_reason = 'DSPLY without factor 1 is not converted';
    when %scan('*M':Up(i_c.factor1)) = 1;
      l_reason = 'DSPLY with a message identifier (*M) is not converted: the '
                 + 'message comes from QUSERMSG';
  endsl;
  if l_reason = '';
    if not ConvOperand(i_c.factor1:l_msg:l_reason);
      l_msg = '';
    endif;
  endif;
  if l_reason = '' and i_c.factor2 <> '';
    if Up(i_c.factor2) = '*EXT';
      l_queue = '*EXT';
    elseif not ConvOperand(i_c.factor2:l_queue:l_reason);
      l_queue = '';
    endif;
  endif;
  if l_reason = '' and i_c.result <> '';
    if not ConvOperand(i_c.result:l_res:l_reason);
      l_res = '';
    elseif i_c.length <> '';
      l_reason = DeclareResult(l_res:i_c.length:i_c.decimals:*off);
    endif;
  endif;
  if l_reason = '' and %len(l_msg) > 0;
    if OperandType(l_msg:l_kind:l_len:l_dec);
      if l_kind = 'N';
        l_reason = 'The message of DSPLY must be alphanumeric';
      endif;
    endif;
  endif;
  if l_reason = '' and i_c.result2 <> '  ';
    l_reason = IndicatorName(i_c.result2:l_ind);
    l_ext = '(e)';
  endif;

  if l_reason <> '';
    ReviewHere(i_c.line:i_c.lineNo:l_reason);
    return;
  endif;

  l_stmt = 'dsply' + l_ext + ' ' + l_msg;
  if l_res <> '';
    if l_queue = '';
      l_queue = '*EXT';
      l_note = 'No output queue: *EXT (the requester) is used; RPG/400 uses '
               + 'QSYSOPR for a batch job';
    endif;
    l_stmt += ' ' + l_queue + ' ' + l_res;
  elseif l_queue <> '';
    l_stmt += ' ' + l_queue;
  endif;
  l_count = 1;
  l_statements(1) = l_stmt;
  if l_ind <> '';
    l_count += 1;
    l_statements(l_count) = l_ind + ' = %error';
  endif;

  l_rule = i_rule;
  l_rule.reason = l_note;
  if l_note = '';
    l_rule.status = C_STS_CONVERTED;
  else;
    l_rule.status = C_STS_ASSUMPTION;
  endif;
  EmitStatements(i_c:l_rule:l_statements:l_count:'');
end-proc;

// ------------------------------------------------------------------
// The two hexadecimal digits of a byte value (0 to 255).
dcl-proc HexByte;
  dcl-pi *n char(2);
    i_value int(10) const;
  end-pi;

  dcl-c C_HEXDIGITS '0123456789ABCDEF';

  return %subst(C_HEXDIGITS:%div(i_value:16) + 1:1)
         + %subst(C_HEXDIGITS:%rem(i_value:16) + 1:1);
end-proc;

// ------------------------------------------------------------------
// Factor 2 of BITON, BITOF and TESTB: bit numbers in apostrophes ('036'), a
// 1-byte hexadecimal literal (X'88') or the name of a one-position field.
// A literal gives the mask (0 to 255) and the number of bits; a field name
// gives o_field. Returns '' or the reason it fails.
dcl-proc BitMask;
  dcl-pi *n varchar(150);
    i_c likeds(Calc_t) const;
    o_mask int(10);
    o_bits int(10);
    o_field varchar(30);
  end-pi;

  dcl-c C_HEXDIGITS '0123456789ABCDEF';
  dcl-c C_BITVALUES '128064032016008004002001';

  dcl-s l_text varchar(30);
  dcl-s l_up varchar(30);
  dcl-s l_inner varchar(30);
  dcl-s l_seen char(8) inz('00000000');
  dcl-s l_bit int(10);
  dcl-s l_index int(10);
  dcl-s l_kind char(1);
  dcl-s l_len int(10);
  dcl-s l_dec int(10);
  dcl-s l_reason varchar(150) inz('');

  o_mask = 0;
  o_bits = 0;
  o_field = '';
  l_text = %trim(i_c.factor2);
  l_up = Up(l_text);
  select;
    when %len(l_up) = 5 and %subst(l_up:1:2) = 'X''' and %subst(l_up:5:1) = '''';
      if %check(C_HEXDIGITS:%subst(l_up:3:2)) <> 0;
        return 'The hexadecimal literal ' + l_text + ' is not valid';
      endif;
      o_mask = (%scan(%subst(l_up:3:1):C_HEXDIGITS) - 1) * 16
               + %scan(%subst(l_up:4:1):C_HEXDIGITS) - 1;
      for l_index = 0 to 7;
        if %rem(%div(o_mask:%int(%subst(C_BITVALUES:l_index * 3 + 1:3))):2) = 1;
          o_bits += 1;
        endif;
      endfor;
    when %len(l_text) >= 3 and %subst(l_text:1:1) = C_QUOTE
         and %subst(l_text:%len(l_text):1) = C_QUOTE;
      l_inner = %subst(l_text:2:%len(l_text) - 2);
      if %len(l_inner) > 8 or %check('01234567':l_inner) <> 0;
        return 'The bit numbers ' + l_text + ' must be 1 to 8 digits from 0 to 7';
      endif;
      for l_index = 1 to %len(l_inner);
        l_bit = %int(%subst(l_inner:l_index:1));
        if %subst(l_seen:l_bit + 1:1) = '1';
          return 'Bit number ' + %char(l_bit) + ' is repeated in ' + l_text;
        endif;
        %subst(l_seen:l_bit + 1:1) = '1';
        o_mask += %int(%subst(C_BITVALUES:l_bit * 3 + 1:3));
        o_bits += 1;
      endfor;
    when IsName(l_text);
      if not ConvOperand(l_text:o_field:l_reason);
        return l_reason;
      endif;
      if OperandType(o_field:l_kind:l_len:l_dec) and (l_kind <> 'C' or l_len <> 1);
        return 'Factor 2 ' + l_text + ' must be a one-position character field';
      endif;
    other;
      return 'Factor 2 ' + l_text + ' (named constant or array element) is not'
             + ' converted for ' + i_c.operation;
  endsl;
  return '';
end-proc;

// ------------------------------------------------------------------
// BITON, BITOF, TESTB, TESTN and TESTZ of RPG II and RPG III (RV-04, RV-05).
dcl-proc ConvertBitTest;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  dcl-c C_NUMERICLOW '0123456789ABCDEFGHIJKLMNOPQR{}';
  dcl-ds l_rule likeds(IAfreeOpc_t);
  dcl-s l_statements varchar(250) dim(C_MAXSTMT);
  dcl-s l_tests varchar(250) dim(3);
  dcl-s l_count int(10) inz(0);
  dcl-s l_slot int(10);
  dcl-s l_statement varchar(250);
  dcl-s l_reason varchar(150) inz('');
  dcl-s l_note varchar(190) inz('');
  dcl-s l_res varchar(30) inz('');
  dcl-s l_mask int(10) inz(0);
  dcl-s l_bits int(10) inz(0);
  dcl-s l_field varchar(30) inz('');
  dcl-s l_hex varchar(40) inz('');
  dcl-s l_inverse varchar(60) inz('');
  dcl-s l_and varchar(100);
  dcl-s l_zone varchar(100);
  dcl-s l_first varchar(60);
  dcl-s l_last varchar(60);
  dcl-s l_kind char(1);
  dcl-s l_len int(10) inz(0);
  dcl-s l_dec int(10);
  dcl-s l_known ind inz(*off);
  dcl-s l_slotName char(2);

  // The result field: one position for the bit operations, character for all.
  if i_c.result = '';
    l_reason = 'The result field is required for ' + i_rule.opcode;
  elseif not ConvOperand(i_c.result:l_res:l_reason);
    l_res = '';
  endif;
  if l_reason = '' and i_c.length <> '';
    l_reason = DeclareResult(l_res:i_c.length:i_c.decimals:*off);
  endif;
  if l_reason = '';
    l_known = OperandType(l_res:l_kind:l_len:l_dec);
    if l_known and l_kind = 'N';
      l_reason = 'The result field of ' + i_rule.opcode + ' must be a character'
                 + ' field';
    elseif l_known and i_rule.opcode <> 'TESTN' and i_rule.opcode <> 'TESTZ'
           and l_len <> 1;
      l_reason = 'The result field of ' + i_rule.opcode + ' must be one position';
    elseif not l_known and i_rule.opcode = 'TESTN';
      l_reason = 'TESTN needs the length of ' + l_res + ': it is not defined'
                 + ' before this line';
    endif;
  endif;

  // Factor 2 of the bit operations.
  if l_reason = '' and (i_rule.opcode = 'BITON' or i_rule.opcode = 'BITOF'
                        or i_rule.opcode = 'TESTB');
    l_reason = BitMask(i_c:l_mask:l_bits:l_field);
    if l_reason = '';
      if l_field = '';
        l_hex = 'x''' + HexByte(l_mask) + '''';
        l_inverse = 'x''' + HexByte(255 - l_mask) + '''';
      else;
        l_hex = l_field;
        l_inverse = '%bitnot(' + l_field + ')';
      endif;
    endif;
  endif;

  if l_reason <> '';
    ReviewHere(i_c.line:i_c.lineNo:l_reason);
    return;
  endif;

  // The bit operations that set bits.
  if i_rule.opcode = 'BITON' or i_rule.opcode = 'BITOF';
    if i_c.result1 <> '  ' or i_c.result2 <> '  ' or i_c.result3 <> '  ';
      ReviewHere(i_c.line:i_c.lineNo:'Resulting indicators are not allowed for '
                 + i_rule.opcode);
      return;
    endif;
    if i_rule.opcode = 'BITON';
      l_statements(1) = l_res + ' = %bitor(' + l_res + ':' + l_hex + ')';
    else;
      l_statements(1) = l_res + ' = %bitand(' + l_res + ':' + l_inverse + ')';
    endif;
    l_rule = i_rule;
    l_rule.status = C_STS_CONVERTED;
    l_rule.reason = '';
    EmitStatements(i_c:l_rule:l_statements:1:'');
    return;
  endif;

  // The tests: one expression for each resulting indicator position.
  select;
    when i_rule.opcode = 'TESTB';
      l_and = '%bitand(' + l_res + ':' + l_hex + ')';
      l_tests(1) = l_and + ' = x''00''';
      if l_bits <> 1 or l_field <> '';
        l_tests(2) = l_and + ' <> x''00'' and ' + l_and + ' <> ' + l_hex;
      endif;
      l_tests(3) = l_and + ' = ' + l_hex;
      if l_field <> '';
        l_note = 'TESTB with a field in factor 2: RPG/400 sets no indicator on'
                 + ' when the field has no bit on';
      endif;
    when i_rule.opcode = 'TESTZ';
      l_zone = '%bitand(%subst(' + l_res + ':1:1):x''F0'')';
      l_tests(1) = l_zone + ' = x''50'' or ' + l_zone + ' = x''C0''';
      l_tests(2) = l_zone + ' = x''60'' or ' + l_zone + ' = x''D0''';
      l_tests(3) = 'not (' + l_zone + ' = x''50'' or ' + l_zone + ' = x''C0'''
                   + ' or ' + l_zone + ' = x''60'' or ' + l_zone + ' = x''D0'')';
      l_note = 'TESTZ is written on the zone of the first character as EBCDIC:'
               + ' & and A-I (zone C), - and J-R (zone D), other zones';
    other;                                    // TESTN
      if l_len = 1;
        l_tests(1) = '%check(''' + C_NUMERICLOW + ''':' + l_res + ') = 0';
      else;
        l_first = '%subst(' + l_res + ':1:' + %char(l_len - 1) + ')';
        l_last = '%subst(' + l_res + ':' + %char(l_len) + ':1)';
        l_tests(1) = '%check(''' + C_DIGITS + ''':' + l_first + ') = 0 and '
                     + '%check(''' + C_NUMERICLOW + ''':' + l_last + ') = 0';
        // Leading blanks, then digits, the last one may carry a sign letter.
        l_tests(2) = '%subst(' + l_res + ':1:1) = '' '' and %check('''
                     + C_DIGITS + ' '':' + l_first + ') = 0 and %check('''
                     + C_NUMERICLOW + ''':' + l_last + ') = 0 and %scan('' '':'
                     + '%triml(' + l_res + ')) = 0';
      endif;
      l_tests(3) = l_res + ' = *blanks';
      l_note = 'TESTN is written with %check: the last position may hold a sign'
               + ' letter (A-R, { or }); the zones are not tested as hexadecimal';
  endsl;

  for l_slot = 1 to 3;
    select;
      when l_slot = 1;
        l_slotName = i_c.result1;
      when l_slot = 2;
        l_slotName = i_c.result2;
      other;
        l_slotName = i_c.result3;
    endsl;
    if l_slotName <> '  ' and l_tests(l_slot) = '';
      ReviewHere(i_c.line:i_c.lineNo:'Resulting indicator ' + %trim(l_slotName)
                 + ' is not allowed here for ' + i_rule.opcode);
      return;
    endif;
    l_reason = ResultStatement(i_c:i_rule:l_slot:l_statement:l_tests(l_slot));
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
    ReviewHere(i_c.line:i_c.lineNo:i_rule.opcode + ' needs a resulting indicator');
    return;
  endif;

  l_rule = i_rule;
  if l_note = '';
    l_rule.status = C_STS_CONVERTED;
  else;
    l_rule.status = C_STS_ASSUMPTION;
  endif;
  l_rule.reason = l_note;
  EmitStatements(i_c:l_rule:l_statements:l_count:'');
end-proc;

// ------------------------------------------------------------------
// MHHZO, MHLZO, MLHZO and MLLZO of RPG II and RPG III (RV-06): the zone (left
// four bits) of the high (first) or low (last) character of factor 2 goes to the
// zone of the high or low character of the result field. Both fields are
// character fields here; a numeric field (the sign zone) is reported R.
dcl-proc ConvertZoneMove;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  dcl-ds l_rule likeds(IAfreeOpc_t);
  dcl-s l_statements varchar(250) dim(C_MAXSTMT);
  dcl-s l_reason varchar(150) inz('');
  dcl-s l_src varchar(30) inz('');
  dcl-s l_res varchar(30) inz('');
  dcl-s l_kind char(1);
  dcl-s l_srcLen int(10) inz(0);
  dcl-s l_resLen int(10) inz(0);
  dcl-s l_dec int(10);
  dcl-s l_srcPos int(10);
  dcl-s l_resPos int(10);
  dcl-s l_op varchar(5);

  l_op = Up(%trim(i_rule.opcode));
  if i_c.result1 <> '  ' or i_c.result2 <> '  ' or i_c.result3 <> '  ';
    l_reason = 'Resulting indicators are not allowed for ' + l_op;
  elseif i_c.result = '' or i_c.factor2 = '';
    l_reason = 'Factor 2 and the result field are required for ' + l_op;
  elseif not ConvOperand(i_c.factor2:l_src:l_reason);
    l_src = '';
  elseif not ConvOperand(i_c.result:l_res:l_reason);
    l_res = '';
  endif;
  if l_reason = '' and i_c.length <> '';
    l_reason = DeclareResult(l_res:i_c.length:i_c.decimals:*off);
  endif;
  if l_reason = '';
    if not OperandType(l_src:l_kind:l_srcLen:l_dec) or l_kind <> 'C';
      l_reason = 'Factor 2 of ' + l_op + ' must be a character field known'
                 + ' before this line (a numeric sign zone is not converted)';
    elseif not OperandType(l_res:l_kind:l_resLen:l_dec) or l_kind <> 'C';
      l_reason = 'The result field of ' + l_op + ' must be a character field'
                 + ' known before this line (a numeric sign zone is not'
                 + ' converted)';
    endif;
  endif;
  if l_reason <> '';
    ReviewHere(i_c.line:i_c.lineNo:l_reason);
    return;
  endif;

  // The 2nd letter of the code is the factor 2 side, the 3rd the result side.
  if %subst(l_op:2:1) = 'H';
    l_srcPos = 1;
  else;
    l_srcPos = l_srcLen;
  endif;
  if %subst(l_op:3:1) = 'H';
    l_resPos = 1;
  else;
    l_resPos = l_resLen;
  endif;
  l_statements(1) = '%subst(' + l_res + ':' + %char(l_resPos) + ':1) = '
                    + '%bitor(%bitand(%subst(' + l_res + ':' + %char(l_resPos)
                    + ':1):x''0F''):%bitand(%subst(' + l_src + ':'
                    + %char(l_srcPos) + ':1):x''F0''))';
  l_rule = i_rule;
  l_rule.status = C_STS_CONVERTED;
  l_rule.reason = '';
  EmitStatements(i_c:l_rule:l_statements:1:'');
end-proc;

// ------------------------------------------------------------------
// CALL, PARM and PLIST of RPG II and RPG III (RV-08). The PARM lines of a CALL
// (CalcPrescan keeps them) or the PARM lines of the PLIST named in its result
// field give a prototype with EXTPGM, written before the first calculation
// with the types of the parameter fields (like), and a CALLP.

// The program name of a CALL: a literal without library, as a free-form name.
dcl-proc ProgramLiteral;
  dcl-pi *n varchar(10);
    i_f2 varchar(30) const;
  end-pi;

  dcl-s l_name varchar(30);

  if %len(i_f2) < 3 or %subst(i_f2:1:1) <> C_QUOTE
     or %subst(i_f2:%len(i_f2):1) <> C_QUOTE;
    return '';
  endif;
  l_name = Up(%subst(i_f2:2:%len(i_f2) - 2));
  if %len(l_name) > 10 or %check(C_NAMEREST:l_name) > 0
     or %check(C_NAMEFIRST:%subst(l_name:1:1)) > 0;
    return '';
  endif;
  return %trim(l_name);
end-proc;

// ------------------------------------------------------------------
// One PARM of the list read at i_first + i_k - 1: the free-form result field
// (defined by its length when it has one), its type signature and the moves
// before and after the call. Returns '' or the reason it fails.
dcl-proc ParmEntry;
  dcl-pi *n varchar(150);
    i_index int(10) const;
    o_field varchar(30);
    o_sig varchar(30);
    o_pre varchar(100);
    o_post varchar(100);
  end-pi;

  dcl-s l_reason varchar(150) inz('');
  dcl-s l_text varchar(30);
  dcl-s l_kind char(1);
  dcl-s l_len int(10);
  dcl-s l_dec int(10);

  o_field = '';
  o_sig = '';
  o_pre = '';
  o_post = '';
  if g_pmRes(i_index) = '';
    return 'PARM without a result field';
  endif;
  if not ConvOperand(g_pmRes(i_index):o_field:l_reason);
    return l_reason;
  endif;
  if %scan('(':o_field) > 0;
    return 'PARM ' + g_pmRes(i_index) + ' is an array element: not converted';
  endif;
  l_reason = DeclareResult(o_field:g_pmLen(i_index):g_pmDec(i_index):*off);
  if l_reason <> '';
    return l_reason;
  endif;
  if not OperandType(o_field:l_kind:l_len:l_dec) or l_kind = 'F';
    return 'Parameter ' + g_pmRes(i_index) + ' is not defined before the CALL';
  endif;
  o_sig = l_kind + %char(l_len) + ',' + %char(l_dec);
  if g_pmF1(i_index) <> '';
    if not ConvOperand(g_pmF1(i_index):l_text:l_reason);
      return l_reason;
    endif;
    o_pre = o_field + ' = ' + l_text;
  endif;
  if g_pmF2(i_index) <> '';
    if not ConvOperand(g_pmF2(i_index):l_text:l_reason);
      return l_reason;
    endif;
    o_post = l_text + ' = ' + o_field;
  endif;
  return '';
end-proc;

// ------------------------------------------------------------------
dcl-proc ConvertCall;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  dcl-ds l_rule likeds(IAfreeOpc_t);
  dcl-s l_statements varchar(250) dim(C_MAXSTMT);
  dcl-s l_count int(10) inz(0);
  dcl-s l_reason varchar(150) inz('');
  dcl-s l_name varchar(10);
  dcl-s l_first int(10) inz(0);
  dcl-s l_num int(10) inz(0);
  dcl-s l_k int(10);
  dcl-s l_p int(10);
  dcl-s l_field varchar(30);
  dcl-s l_sig varchar(30);
  dcl-s l_pre varchar(100);
  dcl-s l_post varchar(100);
  dcl-s l_allPre varchar(250) inz('');
  dcl-s l_allPost varchar(250) inz('');
  dcl-s l_args varchar(250) inz('');
  dcl-s l_sigs varchar(250) inz('');
  dcl-s l_protos varchar(250) inz('');
  dcl-s l_ind varchar(20) inz('');
  dcl-s l_ext varchar(3) inz('');
  dcl-s l_kind char(1);
  dcl-s l_len int(10);
  dcl-s l_dec int(10);
  dcl-s l_known ind inz(*off);
  dcl-s l_found int(10) inz(0);

  g_parmMode = 'X';
  l_name = ProgramLiteral(i_c.factor2);
  select;
    when l_name = '';
      l_reason = 'CALL needs a literal program name without a library';
    when i_c.result1 <> '  ';
      l_reason = 'Resulting indicator ' + %trim(i_c.result1)
                 + ' is not allowed for CALL';
    when i_c.result3 <> '  ';
      l_reason = 'The LR indicator of CALL (columns 58-59) is not converted';
    when i_c.halfAdjust <> ' ';
      l_reason = 'Operation extender ' + i_c.halfAdjust + ' is not allowed for CALL';
    when g_callSeen > C_MAXCALL;
      l_reason = 'Too many CALL operations';
  endsl;
  if l_reason = '' and OperandType(l_name:l_kind:l_len:l_dec);
    l_reason = 'The program name ' + l_name + ' is also the name of a field';
  endif;
  if l_reason = '';
    if i_c.result = '';
      l_first = g_callFirst(g_callSeen);
      l_num = g_callNum(g_callSeen);
    else;
      for l_p = 1 to g_plCount;
        if g_plName(l_p) = Up(i_c.result);
          l_found = l_p;
        endif;
      endfor;
      if l_found = 0;
        l_reason = 'PLIST ' + i_c.result + ' is not defined';
      else;
        l_first = g_plFirst(l_found);
        l_num = g_plNum(l_found);
      endif;
    endif;
  endif;
  if l_reason = '' and i_c.result2 <> '  ';
    l_reason = IndicatorName(i_c.result2:l_ind);
    l_ext = '(e)';
  endif;

  for l_k = 1 to l_num;
    if l_reason <> '';
      leave;
    endif;
    l_reason = ParmEntry(l_first + l_k - 1:l_field:l_sig:l_pre:l_post);
    if l_reason = '';
      if l_k > 1;
        l_args += ' : ';
        l_sigs += ';';
        l_protos += ';';
      endif;
      l_args += l_field;
      l_sigs += l_sig;
      l_protos += l_field;
      if l_pre <> '';
        if l_allPre <> '';
          l_allPre += '; ';
        endif;
        l_allPre += l_pre;
      endif;
      if l_post <> '';
        if l_allPost <> '';
          l_allPost += '; ';
        endif;
        l_allPost += l_post;
      endif;
    endif;
  endfor;

  // The prototype: the first CALL of a program gives it, the others must match.
  if l_reason = '';
    l_known = *off;
    for l_p = 1 to g_protoCount;
      if g_protoName(l_p) = l_name;
        l_known = *on;
        if g_protoSig(l_p) <> l_sigs;
          l_reason = 'Program ' + l_name + ' is called with other parameter types'
                     + ' than before';
        endif;
      endif;
    endfor;
    if not l_known and l_reason = '';
      if g_protoCount >= C_MAXPROTO or g_protoLineCount + l_num + 2 > C_MAXPLINE;
        l_reason = 'Too many programs are called';
      else;
        g_protoCount += 1;
        g_protoName(g_protoCount) = l_name;
        g_protoSig(g_protoCount) = l_sigs;
        g_protoLineCount += 1;
        g_protoLine(g_protoLineCount) = 'dcl-pr ' + l_name + ' extpgm('''
                                        + l_name + ''');';
        for l_k = 1 to l_num;
          g_protoLineCount += 1;
          g_protoLine(g_protoLineCount) = '  dcl-parm *n like('
              + %subst(l_protos:1:%scan(';':l_protos + ';') - 1) + ');';
          if %scan(';':l_protos) > 0;
            l_protos = %subst(l_protos:%scan(';':l_protos) + 1);
          endif;
        endfor;
        g_protoLineCount += 1;
        g_protoLine(g_protoLineCount) = 'end-pr;';
      endif;
    endif;
  endif;
  if l_reason = '' and (%len(l_allPre) + %len(l_allPost) + %len(l_args) > 200);
    l_reason = 'The parameters of CALL ' + l_name + ' are too long';
  endif;

  if l_reason <> '';
    g_parmReason = l_reason;
    ReviewHere(i_c.line:i_c.lineNo:l_reason);
    return;
  endif;

  if l_allPre <> '';
    l_count += 1;
    l_statements(l_count) = l_allPre;
  endif;
  l_count += 1;
  l_statements(l_count) = 'callp' + l_ext + ' ' + l_name + '(' + l_args + ')';
  if l_ind <> '';
    l_count += 1;
    l_statements(l_count) = l_ind + ' = %error';
  endif;
  if l_allPost <> '';
    l_count += 1;
    l_statements(l_count) = l_allPost;
  endif;
  g_parmMode = 'C';
  l_rule = i_rule;
  l_rule.status = C_STS_ASSUMPTION;
  l_rule.reason = 'CALL is written as a prototype (before the first calculation) and'
                  + ' CALLP; factor 1 and factor 2 of PARM are moved with = before'
                  + ' and after the call';
  EmitStatements(i_c:l_rule:l_statements:l_count:'');
end-proc;

// ------------------------------------------------------------------
dcl-proc ConvertPlist;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
  end-pi;

  if Up(i_c.factor1) = '*ENTRY';
    g_parmMode = 'X';
    g_parmReason = 'PLIST *ENTRY: declare the parameters of the program with'
                   + ' dcl-pi';
    ReviewHere(i_c.line:i_c.lineNo:g_parmReason);
    return;
  endif;
  g_parmMode = 'P';
  g_parmReason = '';
  RptItem(C_STS_CONVERTED:i_c.lineNo:SpecText(i_c.line):'');
end-proc;

// ------------------------------------------------------------------
// PARM: the parameter of a CALL or PLIST. Written with the CALL; a length in
// columns 49-51 defines the field here, where the PARM is.
dcl-proc ConvertParm;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
  end-pi;

  dcl-s l_field varchar(30) inz('');
  dcl-s l_reason varchar(150) inz('');

  select;
    when g_parmMode = ' ';
      l_reason = 'PARM without a CALL or PLIST before it';
    when g_parmMode = 'X';
      l_reason = 'PARM of a CALL or PLIST that is not converted: '
                 + g_parmReason;
    when i_c.result = '';
      l_reason = 'PARM without a result field';
    when not ConvOperand(i_c.result:l_field:l_reason);
      l_field = '';
    other;
      l_reason = DeclareResult(l_field:i_c.length:i_c.decimals:*off);
  endsl;
  if l_reason <> '';
    ReviewHere(i_c.line:i_c.lineNo:l_reason);
    return;
  endif;
  RptItem(C_STS_CONVERTED:i_c.lineNo:SpecText(i_c.line):'');
end-proc;

// ------------------------------------------------------------------
// DUMP: dump identifier; The dump is made only when the control specification has
// the debug entry (converted to debug(*dump), FREE-03), as in RPG/400.
dcl-proc ConvertDump;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  dcl-s l_statements varchar(250) dim(C_MAXSTMT);

  l_statements(1) = 'dump';
  if i_c.factor1 <> '';
    l_statements(1) += ' ' + i_c.factor1C;
  endif;
  EmitStatements(i_c:i_rule:l_statements:1:'');
end-proc;

// ------------------------------------------------------------------
// LOKUP (RPG II guide chapter 27; RPG/400 reference chapter 11) on an array or a
// table of the E specifications. Resulting indicators: high (54-55), low (56-57)
// and equal (58-59); one or two of them, high and low not together.
//   equal            LOKUP_IX = %lookup(F1:ARR);          *INeq = (LOKUP_IX > 0);
//   high / low       %lookupgt / %lookuplt                 (needs the sequence)
//   equal and high   %lookupge, equal and low %lookuple    (needs the sequence)
// With an index (ARR,X) the search starts at X, and X is set to the position found
// or to 1. A table keeps the entry found in NAME_IDX, which every reference to the
// table name in a calculation uses; the second table in the result field and the
// alternating table get the same entry.
dcl-proc ConvertLookup;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  dcl-ds l_rule likeds(IAfreeOpc_t);
  dcl-s l_comma int(10);
  dcl-s l_name varchar(30);
  dcl-s l_idxText varchar(30) inz('');
  dcl-s l_idxConv varchar(30) inz('');
  dcl-s l_hasIndex ind inz(*off);
  dcl-s l_isTable ind;
  dcl-s l_seq char(1);
  dcl-s l_dim int(10);
  dcl-s l_alt varchar(10);
  dcl-s l_resName varchar(30) inz('');
  dcl-s l_resTable ind;
  dcl-s l_resSeq char(1);
  dcl-s l_resDim int(10);
  dcl-s l_resAlt varchar(10);
  dcl-s l_f1 varchar(30);
  dcl-s l_hi varchar(20) inz('');
  dcl-s l_lo varchar(20) inz('');
  dcl-s l_eq varchar(20) inz('');
  dcl-s l_count int(10) inz(0);
  dcl-s l_func varchar(12);
  dcl-s l_search varchar(150);
  dcl-s l_element varchar(60);
  dcl-s l_reason varchar(150) inz('');
  dcl-s l_note varchar(190) inz('');
  dcl-s l_kind1 char(1);
  dcl-s l_len1 int(10);
  dcl-s l_dec1 int(10);
  dcl-s l_kind2 char(1);
  dcl-s l_len2 int(10);
  dcl-s l_dec2 int(10);
  dcl-s l_statements varchar(250) dim(C_MAXSTMT);
  dcl-s l_n int(10) inz(0);

  // The array or table, and its index.
  l_name = i_c.factor2;
  l_comma = %scan(',':l_name);
  if l_comma > 0;
    l_idxText = %trim(%subst(l_name:l_comma + 1));
    l_name = %subst(l_name:1:l_comma - 1);
    l_hasIndex = *on;
  endif;
  l_name = Up(l_name);
  if not ArrayInfo(l_name:l_isTable:l_seq:l_dim:l_alt);
    l_reason = l_name + ' is not an array or table defined by an E specification';
  endif;
  if l_reason = '' and l_hasIndex and l_isTable;
    l_reason = 'A table has no index';
  endif;
  if l_reason = '' and i_c.result <> '';
    if not l_isTable;
      l_reason = 'The result field must be blank when factor 2 is an array';
    elseif not ArrayInfo(i_c.result:l_resTable:l_resSeq:l_resDim:l_resAlt);
      l_reason = i_c.result + ' is not a table defined by an E specification';
    elseif not l_resTable;
      l_reason = i_c.result + ' is not a table';
    else;
      l_resName = Up(i_c.result);
    endif;
  endif;

  // The resulting indicators.
  if l_reason = '';
    if i_c.result1 <> '  ';
      l_reason = IndicatorName(i_c.result1:l_hi);
      l_count += 1;
    endif;
    if l_reason = '' and i_c.result2 <> '  ';
      l_reason = IndicatorName(i_c.result2:l_lo);
      l_count += 1;
    endif;
    if l_reason = '' and i_c.result3 <> '  ';
      l_reason = IndicatorName(i_c.result3:l_eq);
      l_count += 1;
    endif;
  endif;
  if l_reason = '';
    select;
      when l_count = 0;
        l_reason = 'LOKUP needs a high, low or equal resulting indicator';
      when l_count > 2;
        l_reason = 'No more than two resulting indicators can be used with LOKUP';
      when l_hi <> '' and l_lo <> '';
        l_reason = 'High and low cannot be used together with LOKUP';
      when (l_hi <> '' or l_lo <> '') and l_seq = ' ';
        l_reason = 'A high or low search needs the sequence of ' + l_name
                   + ' (column 45 of the E specification)';
    endsl;
  endif;

  // The search argument and the index.
  if l_reason = '';
    if not ConvOperand(i_c.factor1:l_f1:l_reason);
      l_f1 = '';
    endif;
  endif;
  if l_reason = '' and l_hasIndex;
    if not ConvOperand(l_idxText:l_idxConv:l_reason);
      l_idxConv = '';
    endif;
  endif;
  // A field used as search argument must have the length and format of the
  // entries (a literal or a figurative constant is not checked).
  if l_reason = '' and %len(l_f1) > 0;
    if %subst(l_f1:1:1) <> C_QUOTE and %subst(l_f1:1:1) <> '*'
       and not IsNumberLiteral(l_f1);
      if OperandType(l_f1:l_kind1:l_len1:l_dec1);
        if OperandType(l_name:l_kind2:l_len2:l_dec2);
          if l_kind1 <> l_kind2 or l_len1 <> l_len2;
            l_reason = 'The search argument and the entries of ' + l_name
                       + ' must have the same length and format';
          endif;
        endif;
      endif;
    endif;
  endif;

  if l_reason <> '';
    ReviewHere(i_c.line:i_c.lineNo:l_reason);
    return;
  endif;

  // The search.
  select;
    when l_hi <> '' and l_eq <> '';
      l_func = '%lookupge';
    when l_lo <> '' and l_eq <> '';
      l_func = '%lookuple';
    when l_hi <> '';
      l_func = '%lookupgt';
    when l_lo <> '';
      l_func = '%lookuplt';
    other;
      l_func = '%lookup';
  endsl;
  l_search = l_func + '(' + l_f1 + ':' + l_name;
  if l_hasIndex;
    l_search += ':' + l_idxConv;
  endif;
  l_search += ')';
  l_element = l_name + '(LOKUP_IX)';

  DeclareHidden('LOKUP_IX':'int(10)');
  l_n += 1;
  l_statements(l_n) = 'LOKUP_IX = ' + l_search;
  select;
    when l_eq <> '' and (l_hi <> '' or l_lo <> '');
      l_n += 1;
      l_statements(l_n) = l_eq + ' = *off';
      l_n += 1;
      l_statements(l_n) = %trim(l_hi + l_lo) + ' = *off';
      l_n += 1;
      l_statements(l_n) = 'if LOKUP_IX > 0; if ' + l_element + ' = ' + l_f1 + '; '
                          + l_eq + ' = *on; else; ' + %trim(l_hi + l_lo)
                          + ' = *on; endif; endif';
    when l_eq <> '';
      l_n += 1;
      l_statements(l_n) = l_eq + ' = (LOKUP_IX > 0)';
    other;
      l_n += 1;
      l_statements(l_n) = %trim(l_hi + l_lo) + ' = (LOKUP_IX > 0)';
  endsl;

  // The index of the array, or the current entry of the table.
  if l_hasIndex;
    if IsName(l_idxText);
      l_n += 1;
      l_statements(l_n) = 'if LOKUP_IX = 0; ' + l_idxConv + ' = 1; else; '
                          + l_idxConv + ' = LOKUP_IX; endif';
    endif;
  elseif l_isTable;
    l_note = 'Table ' + l_name + ': the entry found is kept in ' + l_name
             + '_IDX, which the references to the table name use';
    l_n += 1;
    l_statements(l_n) = 'if LOKUP_IX > 0; ' + l_name + '_IDX = LOKUP_IX';
    if l_alt <> '';
      l_statements(l_n) += '; ' + l_alt + '_IDX = LOKUP_IX';
    endif;
    if l_resName <> '';
      l_statements(l_n) += '; ' + l_resName + '_IDX = LOKUP_IX';
    endif;
    l_statements(l_n) += '; endif';
  endif;

  l_rule = i_rule;
  l_rule.reason = l_note;
  if l_note = '';
    l_rule.status = C_STS_CONVERTED;
  else;
    l_rule.status = C_STS_ASSUMPTION;
  endif;
  EmitStatements(i_c:l_rule:l_statements:l_n:'');
end-proc;

// ------------------------------------------------------------------
// MOVEA, the whole array to a whole array of the same number of entries and the
// same entry length and type, or *BLANK(S) and *ZERO(S) to an array. Moves with
// an index, between an array and a field, and between arrays of another size are
// reported R.
dcl-proc ConvertMovea;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  dcl-s l_reason varchar(190) inz('');
  dcl-s l_isTable1 ind;
  dcl-s l_isTable2 ind;
  dcl-s l_seq char(1);
  dcl-s l_dim1 int(10);
  dcl-s l_dim2 int(10);
  dcl-s l_alt varchar(10);
  dcl-s l_kind1 char(1);
  dcl-s l_len1 int(10);
  dcl-s l_dec1 int(10);
  dcl-s l_kind2 char(1);
  dcl-s l_len2 int(10);
  dcl-s l_dec2 int(10);
  dcl-s l_figure varchar(10);
  dcl-s l_statements varchar(250) dim(C_MAXSTMT);

  select;
    when i_c.result1 <> '  ' or i_c.result2 <> '  ' or i_c.result3 <> '  ';
      l_reason = 'Resulting indicators are not used by MOVEA';
    when %scan(',':i_c.result) > 0 or %scan(',':i_c.factor2) > 0;
      l_reason = 'MOVEA with an array index is not converted';
    when not ArrayInfo(i_c.result:l_isTable2:l_seq:l_dim2:l_alt);
      l_reason = i_c.result + ' is not an array defined by an E specification '
                 + '(MOVEA to a field is not converted)';
    when l_isTable2;
      l_reason = 'MOVEA to a table is not converted';
  endsl;

  if l_reason = '';
    l_figure = Up(i_c.factor2C);
    select;
      when l_figure = '*BLANK' or l_figure = '*BLANKS';
        if OperandType(i_c.result:l_kind2:l_len2:l_dec2) and l_kind2 = 'C';
          l_statements(1) = i_c.resultC + ' = *blanks';
        else;
          l_reason = 'MOVEA of *BLANK needs an alphanumeric array';
        endif;
      when l_figure = '*ZERO' or l_figure = '*ZEROS';
        l_statements(1) = i_c.resultC + ' = *zeros';
      when not ArrayInfo(i_c.factor2:l_isTable1:l_seq:l_dim1:l_alt);
        l_reason = i_c.factor2 + ' is not an array defined by an E specification '
                   + '(MOVEA from a field is not converted)';
      when l_isTable1;
        l_reason = 'MOVEA from a table is not converted';
      when l_dim1 <> l_dim2;
        l_reason = 'MOVEA between arrays of a different number of entries is not '
                   + 'converted';
      other;
        if OperandType(i_c.factor2:l_kind1:l_len1:l_dec1)
           and OperandType(i_c.result:l_kind2:l_len2:l_dec2)
           and l_kind1 = l_kind2 and l_len1 = l_len2 and l_dec1 = l_dec2;
          l_statements(1) = i_c.resultC + ' = ' + i_c.factor2C;
        else;
          l_reason = 'MOVEA between arrays of a different entry length or type is '
                     + 'not converted';
        endif;
    endsl;
  endif;

  if l_reason <> '';
    ReviewHere(i_c.line:i_c.lineNo:l_reason);
    return;
  endif;
  EmitStatements(i_c:i_rule:l_statements:1:'');
end-proc;

// ------------------------------------------------------------------
// MOVE and MOVEL (RPG II guide chapter 27; RPG/400 reference chapter 11). The
// data is moved right-justified (MOVE) or left-justified (MOVEL) and the rest of
// the result field keeps its old value, so the lengths of both fields must be
// known (I and E specifications, fields defined by result fields). Converted:
//   alphanumeric to alphanumeric        R = F2;  %subst(R:..) = F2;  R = %subst(F2:..);
//   with P (blank padding)              R = *blanks; %subst(R:..) = F2;  or  R = F2;
//   *BLANK(S), *ZERO(S)                 R = *blanks;  R = 0;  R = *zeros;
//   numeric to numeric, same length and decimal positions       R = F2;
// Everything else (alphanumeric to numeric and back, numeric of another length or
// decimal positions, other figurative constants, a field of unknown length) is R.
dcl-proc ConvertMove;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  dcl-s l_left ind;
  dcl-s l_pad ind;
  dcl-s l_kind2 char(1);
  dcl-s l_len2 int(10);
  dcl-s l_dec2 int(10);
  dcl-s l_kindR char(1);
  dcl-s l_lenR int(10);
  dcl-s l_decR int(10);
  dcl-s l_figure varchar(10);
  dcl-s l_reason varchar(190) inz('');
  dcl-s l_statements varchar(250) dim(C_MAXSTMT);
  dcl-s l_count int(10) inz(0);
  dcl-s l_res varchar(40);
  dcl-s l_f2 varchar(40);
  dcl-s l_found ind;

  if i_rule.opcode = 'MOVEA';
    ConvertMovea(i_c:i_rule);
    return;
  endif;
  l_left = (i_rule.opcode = 'MOVEL');
  l_pad = (i_c.halfAdjust = 'P');
  l_res = i_c.resultC;
  l_f2 = i_c.factor2C;

  if i_c.result1 <> '  ' or i_c.result2 <> '  ' or i_c.result3 <> '  ';
    l_reason = 'Resulting indicators are not used by ' + i_rule.opcode;
  endif;

  // A result field that has a length defines the field (alphanumeric without
  // decimal positions, numeric with).
  if l_reason = '' and i_c.length <> '';
    l_reason = DeclareResult(l_res:i_c.length:i_c.decimals:*off);
  endif;

  if l_reason = '';
    l_found = OperandType(l_f2:l_kind2:l_len2:l_dec2);
    if not l_found;
      l_reason = 'Length and type of ' + i_c.factor2 + ' are not known: it is not '
                 + 'defined by an I or E specification or by a result field';
    endif;
  endif;
  if l_reason = '';
    l_found = OperandType(l_res:l_kindR:l_lenR:l_decR);
    if not l_found;
      l_reason = 'Length and type of ' + i_c.result + ' are not known: it is not '
                 + 'defined by an I or E specification or by a result field';
    endif;
  endif;

  if l_reason = '';
    select;
      when l_kind2 = 'F';
        l_figure = Up(l_f2);
        select;
          when (l_figure = '*BLANK' or l_figure = '*BLANKS') and l_kindR = 'C';
            l_count = 1;
            l_statements(1) = l_res + ' = *blanks';
          when (l_figure = '*ZERO' or l_figure = '*ZEROS') and l_kindR = 'N';
            l_count = 1;
            l_statements(1) = l_res + ' = 0';
          when (l_figure = '*ZERO' or l_figure = '*ZEROS') and l_kindR = 'C';
            l_count = 1;
            l_statements(1) = l_res + ' = *zeros';
          other;
            l_reason = 'The figurative constant ' + l_f2 + ' is not converted for '
                       + 'this result field';
        endsl;

      when l_kind2 = 'C' and l_kindR = 'C';
        l_count = 0;
        select;
          when l_len2 = l_lenR;
            l_count = 1;
            l_statements(1) = l_res + ' = ' + l_f2;
          when l_len2 > l_lenR and l_left;
            l_count = 1;
            l_statements(1) = l_res + ' = %subst(' + l_f2 + ':1:'
                              + %trim(%char(l_lenR)) + ')';
          when l_len2 > l_lenR;
            l_count = 1;
            l_statements(1) = l_res + ' = %subst(' + l_f2 + ':'
                              + %trim(%char(l_len2 - l_lenR + 1)) + ')';
          when l_left and l_pad;
            l_count = 1;
            l_statements(1) = l_res + ' = ' + l_f2;
          when l_left;
            l_count = 1;
            l_statements(1) = '%subst(' + l_res + ':1:' + %trim(%char(l_len2))
                              + ') = ' + l_f2;
          other;
            // MOVE of a shorter field: the right end of the result.
            if l_pad;
              l_count += 1;
              l_statements(l_count) = l_res + ' = *blanks';
            endif;
            l_count += 1;
            l_statements(l_count) = '%subst(' + l_res + ':'
                                    + %trim(%char(l_lenR - l_len2 + 1)) + ':'
                                    + %trim(%char(l_len2)) + ') = ' + l_f2;
        endsl;

      when l_kind2 = 'N' and l_kindR = 'N';
        if l_pad;
          l_reason = 'The P extender is only for an alphanumeric result field';
        elseif l_len2 = l_lenR and l_dec2 = l_decR;
          l_count = 1;
          l_statements(1) = l_res + ' = ' + l_f2;
        else;
          l_reason = 'A numeric ' + i_rule.opcode + ' of another length or decimal '
                     + 'positions keeps part of the result: not converted';
        endif;

      other;
        l_reason = i_rule.opcode + ' between an alphanumeric and a numeric field '
                   + 'is not converted';
    endsl;
  endif;

  if l_reason <> '';
    ReviewHere(i_c.line:i_c.lineNo:l_reason);
    return;
  endif;
  EmitStatements(i_c:i_rule:l_statements:l_count:'');
end-proc;

// ------------------------------------------------------------------
// Before the conversion: collects the key lists, so one can be used before it is
// defined. KLIST has its name in factor 1; the KFLD lines after it name the key
// fields in the result field.
dcl-proc CalcPrescan export;
  dcl-pi *n;
    i_line char(100) const;
  end-pi;

  dcl-s l_up char(100);
  dcl-s l_op varchar(5);
  dcl-s l_field varchar(30);

  l_up = %xlate(C_LOWER:C_UPPER:i_line);
  if %subst(l_up:6:1) <> 'C';
    return;
  endif;
  if %subst(l_up:7:1) = '*' or %subst(l_up:7:1) = '/' or %subst(l_up:7:1) = '+';
    return;
  endif;
  l_op = %trim(Fld(l_up:'OPERATION'));
  if l_op <> '' and l_op <> 'CALL' and l_op <> 'PLIST' and l_op <> 'PARM';
    g_parmTarget = 0;
  endif;
  select;
    when l_op = 'CALL';
      g_klOpen = *off;
      g_callCount += 1;
      if g_callCount <= C_MAXCALL;
        g_callFirst(g_callCount) = g_pmCount + 1;
        g_callNum(g_callCount) = 0;
        g_parmTarget = -g_callCount;
      else;
        g_parmTarget = 0;
      endif;
    when l_op = 'PLIST';
      g_klOpen = *off;
      g_parmTarget = 0;
      if g_plCount < C_MAXPL and %trim(Fld(l_up:'FACTOR1')) <> '';
        g_plCount += 1;
        g_plName(g_plCount) = %trim(Fld(l_up:'FACTOR1'));
        g_plFirst(g_plCount) = g_pmCount + 1;
        g_plNum(g_plCount) = 0;
        g_parmTarget = g_plCount;
      endif;
    when l_op = 'PARM';
      g_klOpen = *off;
      if g_parmTarget <> 0 and g_pmCount < C_MAXPM;
        g_pmCount += 1;
        g_pmF1(g_pmCount) = %trim(Fld(i_line:'FACTOR1'));
        g_pmF2(g_pmCount) = %trim(Fld(i_line:'FACTOR2'));
        g_pmRes(g_pmCount) = %trim(Fld(i_line:'RESULT'));
        g_pmLen(g_pmCount) = %trim(Fld(l_up:'LENGTH'));
        g_pmDec(g_pmCount) = Fld(l_up:'DECIMALS');
        if g_parmTarget > 0;
          g_plNum(g_parmTarget) += 1;
        else;
          g_callNum(-g_parmTarget) += 1;
        endif;
      endif;
    when l_op = 'KLIST';
      g_klOpen = *off;
      if g_klCount < C_MAXKL and %trim(Fld(l_up:'FACTOR1')) <> '';
        g_klCount += 1;
        g_klName(g_klCount) = %trim(Fld(l_up:'FACTOR1'));
        g_klFields(g_klCount) = '';
        g_klNumber(g_klCount) = 0;
        g_klBad(g_klCount) = *off;
        g_klOpen = *on;
      endif;
    when l_op = 'KFLD';
      if g_klOpen;
        l_field = %trim(Fld(l_up:'RESULT'));
        if l_field = '' or %scan(' ':l_field) > 0 or %scan(',':l_field) > 0
           or %scan(C_QUOTE:l_field) > 0;
          g_klBad(g_klCount) = *on;
        else;
          if g_klNumber(g_klCount) > 0;
            g_klFields(g_klCount) += ':';
          endif;
          g_klFields(g_klCount) += l_field;
          g_klNumber(g_klCount) += 1;
        endif;
      endif;
    when l_op <> '';
      g_klOpen = *off;
  endsl;
end-proc;

// ------------------------------------------------------------------
// The search argument of a file operation: the key list when factor 1 names one,
// (F1:F2:...) for several key fields, the converted factor 1 otherwise.
dcl-proc KeyArgument;
  dcl-pi *n varchar(190);
    i_factor1 varchar(30) const;
    i_factor1C varchar(80) const;
    o_reason varchar(190);
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_name varchar(30);

  o_reason = '';
  l_name = %xlate(C_LOWER:C_UPPER:i_factor1);
  for l_index = 1 to g_klCount;
    if g_klName(l_index) = l_name;
      if g_klBad(l_index) or g_klNumber(l_index) = 0;
        o_reason = 'Key list ' + l_name + ' has a KFLD that is not a field name '
                   + 'or no KFLD';
        return '';
      endif;
      if g_klNumber(l_index) = 1;
        return g_klFields(l_index);
      endif;
      return '(' + g_klFields(l_index) + ')';
    endif;
  endfor;
  return i_factor1C;
end-proc;

// ------------------------------------------------------------------
// KLIST and KFLD write nothing: the key list is written where a file operation
// uses it (see CalcPrescan and KeyArgument).
dcl-proc ConvertKeyList;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
  end-pi;

  RptItem(C_STS_CONVERTED:i_c.lineNo:SpecText(i_c.line)
          :'');
end-proc;

// ------------------------------------------------------------------
// File operations on DISK files declared by converted F specifications (RPG II
// guide chapter 27; RPG/400 reference chapter 11; free-form operations in the
// ILE RPG reference): CHAIN, READ, READE, READP, REDPE, SETLL, SETGT, WRITE,
// UPDAT, DELET, OPEN, CLOSE, FEOD and UNLCK. The resulting indicators become
// *INnn = %found, %eof or %error tests; an error indicator adds the (e)
// extender. A program-described file reads and writes its record layout data
// structure FILE_REC (the I specifications, FREE-04) or the data structure
// named in the result field; an externally described file needs none.
dcl-proc ConvertFileOp;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  dcl-ds l_rule likeds(IAfreeOpc_t);
  dcl-s l_op varchar(5);
  dcl-s l_free varchar(8);
  dcl-s l_name varchar(8);
  dcl-s l_device char(1);
  dcl-s l_type char(1);
  dcl-s l_recDs varchar(12);
  dcl-s l_keyed ind;
  dcl-s l_keyOp ind;
  dcl-s l_dsOp ind;
  dcl-s l_key varchar(190) inz('');
  dcl-s l_ds varchar(30) inz('');
  dcl-s l_ext varchar(3) inz('');
  dcl-s l_stmt varchar(250);
  dcl-s l_ind varchar(250);
  dcl-s l_reason varchar(190) inz('');
  dcl-s l_note varchar(190) inz('');
  dcl-s l_slot int(10);
  dcl-s l_statements varchar(250) dim(C_MAXSTMT);
  dcl-s l_count int(10) inz(0);

  l_op = i_rule.opcode;
  select;
    when l_op = 'CHAIN';
      l_free = 'chain';
    when l_op = 'READ';
      l_free = 'read';
    when l_op = 'READE';
      l_free = 'reade';
    when l_op = 'READP';
      l_free = 'readp';
    when l_op = 'REDPE';
      l_free = 'readpe';
    when l_op = 'SETLL';
      l_free = 'setll';
    when l_op = 'SETGT';
      l_free = 'setgt';
    when l_op = 'WRITE';
      l_free = 'write';
    when l_op = 'UPDAT';
      l_free = 'update';
    when l_op = 'DELET';
      l_free = 'delete';
    when l_op = 'OPEN';
      l_free = 'open';
    when l_op = 'CLOSE';
      l_free = 'close';
    when l_op = 'FEOD';
      l_free = 'feod';
    when l_op = 'UNLCK';
      l_free = 'unlock';
    when l_op = 'COMIT';
      l_free = 'commit';
    when l_op = 'ROLBK';
      l_free = 'rolbk';
    other;
      l_reason = l_op + ' is not converted';
  endsl;
  l_keyOp = (l_op = 'CHAIN' or l_op = 'READE' or l_op = 'REDPE' or l_op = 'SETLL'
             or l_op = 'SETGT' or l_op = 'DELET');
  l_dsOp = (l_op = 'CHAIN' or l_op = 'READ' or l_op = 'READE' or l_op = 'READP'
            or l_op = 'REDPE' or l_op = 'UPDAT' or l_op = 'WRITE');

  // The file (COMIT and ROLBK name none).
  if l_reason = '' and l_op <> 'COMIT' and l_op <> 'ROLBK';
    l_name = %trim(%xlate(C_LOWER:C_UPPER:i_c.factor2));
    if not FileInfo(l_name:l_device:l_type:l_recDs:l_keyed);
      l_reason = 'File ' + i_c.factor2 + ' is not declared by a converted file '
                 + 'description (a record format name is not converted)';
    elseif l_device <> 'D' and l_device <> 'X';
      l_reason = 'File ' + l_name + ' is not a DISK file';
    endif;
  endif;

  // The search argument and the data structure.
  if l_reason = '' and l_keyOp and i_c.factor1 <> '';
    l_key = KeyArgument(i_c.factor1:i_c.factor1C:l_reason);
  endif;
  if l_reason = '' and l_dsOp;
    select;
      when i_c.result <> '';
        l_ds = i_c.resultC;
      when l_device = 'D' and l_recDs = '';
        l_reason = 'File ' + l_name + ' has no record layout: a program-described '
                   + 'file needs the I specification of its record';
      when l_device = 'D';
        l_ds = l_recDs;
    endsl;
  endif;
  if l_reason = '' and not l_dsOp and i_c.result <> '';
    l_reason = 'The result field is not used by ' + l_op;
  endif;

  // The error extender, and the indicators written after the operation.
  if l_reason = '';
    if (i_c.result1 <> '  ' and i_rule.ind1 = 'ER')
       or (i_c.result2 <> '  ' and i_rule.ind2 = 'ER')
       or (i_c.result3 <> '  ' and i_rule.ind3 = 'ER');
      l_ext = '(e)';
    endif;
    if l_op = 'WRITE' and i_c.result3 <> '  ';
      l_reason = 'The end of file indicator of WRITE (file full) is not converted';
    endif;
  endif;

  if l_reason = '';
    l_stmt = l_free + l_ext;
    if l_key <> '';
      l_stmt += ' ' + l_key;
    endif;
    if l_op = 'COMIT' or l_op = 'ROLBK';
      if l_op = 'COMIT' and i_c.factor1 <> '';
        l_stmt += ' ' + i_c.factor1C;
      endif;
    else;
      l_stmt += ' ' + i_c.factor2C;
    endif;
    if l_ds <> '';
      l_stmt += ' ' + l_ds;
    endif;
    l_count = 1;
    l_statements(1) = l_stmt;
    for l_slot = 1 to 3;
      l_reason = ResultStatement(i_c:i_rule:l_slot:l_ind);
      if l_reason <> '';
        leave;
      endif;
      if l_ind <> '';
        l_count += 1;
        l_statements(l_count) = l_ind;
      endif;
    endfor;
  endif;

  if l_reason <> '';
    ReviewHere(i_c.line:i_c.lineNo:l_reason);
    return;
  endif;

  // The note: a character key of a program-described file.
  if l_keyOp and l_device = 'D' and l_keyed and l_key <> '';
    if %subst(l_key:1:1) <> C_QUOTE;
      AddReason(l_note:'The key of file ' + l_name + ' is declared as a '
                + 'character key: a numeric search argument must be converted');
    endif;
  endif;
  l_rule = i_rule;
  l_rule.reason = l_note;
  if l_note = '';
    l_rule.status = C_STS_CONVERTED;
  else;
    l_rule.status = C_STS_ASSUMPTION;
  endif;
  EmitStatements(i_c:l_rule:l_statements:l_count:'');
end-proc;

// ------------------------------------------------------------------
// RPG III string operations (SC09-1817 chapter 11): CAT, SCAN, SUBST, CHECK and
// CHEKR. The colon operands of factor 1 and factor 2 are read here. A line that
// cannot be converted is reported R (the error indicator in columns 56-57 needs
// MONITOR, a figurative constant or a variable number of blanks has no form).
dcl-proc ConvertString;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  dcl-ds l_rule likeds(IAfreeOpc_t);
  dcl-s l_op varchar(5);
  dcl-s l_f1a varchar(30);
  dcl-s l_f1b varchar(30);
  dcl-s l_f2a varchar(30);
  dcl-s l_f2b varchar(30);
  dcl-s l_has1 ind;
  dcl-s l_has2 ind;
  dcl-s l_c1a varchar(30);
  dcl-s l_c1b varchar(30);
  dcl-s l_c2a varchar(30);
  dcl-s l_c2b varchar(30);
  dcl-s l_res varchar(30);
  dcl-s l_left varchar(30);
  dcl-s l_cmp varchar(80);
  dcl-s l_expr varchar(200);
  dcl-s l_found varchar(20);
  dcl-s l_reason varchar(150) inz('');
  dcl-s l_note varchar(190) inz('');
  dcl-s l_pad ind;
  dcl-s l_numeric ind;
  dcl-s l_blanks int(10);
  dcl-s l_statements varchar(250) dim(C_MAXSTMT);
  dcl-s l_count int(10) inz(0);

  l_op = i_rule.opcode;
  l_numeric = (l_op = 'SCAN' or l_op = 'CHECK' or l_op = 'CHEKR');
  l_pad = (i_c.halfAdjust = 'P');

  // Indicators and the operation extender.
  select;
    when i_c.result1 <> '  ';
      l_reason = 'Resulting indicator in columns 54-55 is not used by ' + l_op;
    when i_c.result2 <> '  ';
      l_reason = 'The error indicator (columns 56-57) needs MONITOR: not converted';
    when i_c.result3 <> '  ' and not l_numeric;
      l_reason = 'Resulting indicator in columns 58-59 is not used by ' + l_op;
    when i_c.halfAdjust <> ' ' and not (l_pad and not l_numeric);
      l_reason = 'Operation extender ' + i_c.halfAdjust + ' is not allowed for '
                 + l_op;
  endsl;

  // Colon operands.
  if l_reason = '';
    SplitColon(i_c.factor1:l_f1a:l_f1b:l_has1);
    SplitColon(i_c.factor2:l_f2a:l_f2b:l_has2);
    select;
      when l_has1 and l_op <> 'SCAN' and l_op <> 'XLATE';
        l_reason = 'Factor 1 of ' + l_op + ' has no colon operand';
      when l_op = 'XLATE' and not l_has1;
        l_reason = 'Factor 1 of XLATE needs the From:To strings';
      when (l_has1 and l_f1b = '') or (l_has2 and l_f2b = '')
           or (l_has1 and l_f1a = '') or l_f2a = '';
        l_reason = 'A colon operand is not complete';
    endsl;
  endif;

  // The operands as free-form text (a failing operand sets l_reason).
  if l_reason = '' and l_f1a <> '';
    StringOperand(l_f1a:l_c1a:l_reason);
  endif;
  if l_reason = '' and l_f1b <> '';
    StringOperand(l_f1b:l_c1b:l_reason);
  endif;
  if l_reason = '';
    StringOperand(l_f2a:l_c2a:l_reason);
  endif;
  if l_reason = '' and l_f2b <> '';
    StringOperand(l_f2b:l_c2b:l_reason);
  endif;
  if l_reason = '';
    if i_c.result <> '';
      if %subst(i_c.result:1:1) = C_QUOTE or IsNumberLiteral(i_c.result);
        l_reason = 'The result field ' + i_c.result + ' is not a field name';
      else;
        StringOperand(i_c.result:l_res:l_reason);
      endif;
    endif;
  endif;
  if l_reason = '' and i_rule.bifs <> '';
    l_expr = LateBif(i_rule.bifs);
    if l_expr <> '';
      l_reason = 'Built-in function ' + l_expr + ' is newer than the target release';
    endif;
  endif;

  // The found indicator (columns 58-59) of SCAN, CHECK and CHEKR.
  l_found = '';
  if l_reason = '' and l_numeric;
    if i_c.result3 <> '  ';
      l_reason = IndicatorName(i_c.result3:l_found);
    endif;
    if l_reason = '' and i_c.result = '' and l_found = '';
      l_reason = 'A result field or a found indicator is required for ' + l_op;
    endif;
  endif;

  // The expression.
  if l_reason = '';
    select;
      when l_op = 'SCAN' or l_op = 'CHECK' or l_op = 'CHEKR';
        l_cmp = l_c1a;
        if l_has1;
          l_cmp = '%subst(' + l_c1a + ':1:' + l_c1b + ')';
        endif;
        select;
          when l_op = 'SCAN';
            l_expr = '%scan(';
          when l_op = 'CHECK';
            l_expr = '%check(';
          other;
            l_expr = '%checkr(';
        endsl;
        l_expr += l_cmp + ':' + l_c2a;
        if l_has2;
          l_expr += ':' + l_c2b;
        endif;
        l_expr += ')';
      when l_op = 'XLATE';
        l_expr = '%xlate(' + l_c1a + ':' + l_c1b + ':' + l_c2a;
        if l_has2;
          l_expr += ':' + l_c2b;
        endif;
        l_expr += ')';
      when l_op = 'SUBST';
        l_expr = '%subst(' + l_c2a + ':';
        if l_has2;
          l_expr += l_c2b;
        else;
          l_expr += '1';
        endif;
        if l_c1a <> '';
          l_expr += ':' + l_c1a;
        endif;
        l_expr += ')';
      other;
        // CAT: factor 1, or the result field when factor 1 is blank.
        l_left = l_c1a;
        if l_left = '';
          l_left = l_res;
        endif;
        if l_has2;
          if %check(C_DIGITS:l_c2b) > 0 or %len(l_c2b) > 2;
            l_reason = 'The number of blanks must be a numeric literal up to 10';
          else;
            l_blanks = %int(l_c2b);
            if l_blanks > 10;
              l_reason = 'The number of blanks must be a numeric literal up to 10';
            endif;
          endif;
          l_expr = '%trimr(' + l_left + ')';
          if l_blanks > 0 and l_reason = '';
            l_expr += ' + ' + C_QUOTE + %subst('          ':1:l_blanks) + C_QUOTE;
          endif;
          l_expr += ' + ' + l_c2a;
        else;
          l_expr = l_left + ' + ' + l_c2a;
        endif;
    endsl;
  endif;

  // The field a result field defines.
  if l_reason = '' and i_c.result <> '';
    l_reason = DeclareResult(l_res:i_c.length:i_c.decimals:l_numeric);
  endif;

  if l_reason <> '';
    ReviewHere(i_c.line:i_c.lineNo:l_reason);
    return;
  endif;

  // The statements.
  if i_c.result <> '';
    l_count += 1;
    l_statements(l_count) = l_res + ' = ' + l_expr;
    if l_found <> '';
      l_count += 1;
      l_statements(l_count) = l_found + ' = (' + l_res + ' > 0)';
    endif;
  else;
    l_count = 1;
    l_statements(1) = l_found + ' = (' + l_expr + ' > 0)';
  endif;

  // The status: A with the note of the table, C when P was given.
  l_rule = i_rule;
  if (l_op = 'CAT' or l_op = 'SUBST' or l_op = 'XLATE') and l_pad;
    l_rule.status = C_STS_CONVERTED;
    l_rule.reason = '';
  else;
    l_rule.status = C_STS_ASSUMPTION;
  endif;
  EmitStatements(i_c:l_rule:l_statements:l_count:l_note);
end-proc;

// ------------------------------------------------------------------
// Embedded SQL of an SQLRPG source (RPG/400 User's Guide, chapter 1): the
// delimiter /EXEC SQL in columns 7-15, the statement from column 16 and on lines
// with + in column 7 (up to column 74), the delimiter /END-EXEC on a line of its
// own. Returns *on when the line belongs to an SQL statement and was handled.
dcl-proc CalcSqlLine export;
  dcl-pi *n ind;
    i_line char(100) const;
    i_lineNo int(10) const;
  end-pi;

  dcl-s l_up char(100);
  dcl-s l_key char(9);

  l_up = %xlate(C_LOWER:C_UPPER:i_line);
  l_key = %subst(l_up:7:9);

  select;
    when l_key = '/EXEC SQL';
      if g_sqlOpen;
        SqlReject('EXEC SQL starts before the END-EXEC of the statement before');
      endif;
      g_sqlOpen = *on;
      g_sqlTooLong = *off;
      g_sqlCount = 0;
      SqlAdd(%trim(%subst(i_line:16:59)):i_line:i_lineNo);
      return *on;
    when l_key = '/END-EXEC';
      if not g_sqlOpen;
        ReviewSpec(i_lineNo:i_line:'END-EXEC without EXEC SQL');
        return *on;
      endif;
      SqlEnd(i_line:i_lineNo);
      return *on;
    when %subst(i_line:7:1) = '+';
      if not g_sqlOpen;
        ReviewSpec(i_lineNo:i_line:'SQL line (+ in column 7) without EXEC SQL');
        return *on;
      endif;
      SqlAdd(%trim(%subst(i_line:8:67)):i_line:i_lineNo);
      return *on;
    other;
      // Any other specification line ends a statement that was not closed.
      if g_sqlOpen;
        SqlReject('EXEC SQL is not closed by END-EXEC');
      endif;
      return *off;
  endsl;
end-proc;

// ------------------------------------------------------------------
dcl-proc SqlAdd;
  dcl-pi *n;
    i_text varchar(70) const;
    i_line char(100) const;
    i_lineNo int(10) const;
  end-pi;

  if g_sqlCount >= C_MAXSQL;
    g_sqlTooLong = *on;
    return;
  endif;
  g_sqlCount += 1;
  g_sqlText(g_sqlCount) = i_text;
  g_sqlLineNo(g_sqlCount) = i_lineNo;
  g_sqlRaw(g_sqlCount) = i_line;
end-proc;

// ------------------------------------------------------------------
// Position of a token (';' or '--') that is not inside a literal or a delimited
// name, 0 when there is none. Checked line by line: SQL has no literal that
// runs over two lines.
dcl-proc SqlFindOutside;
  dcl-pi *n int(10);
    i_text varchar(100) const;
    i_token varchar(2) const;
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_quote char(1) inz(' ');
  dcl-s l_char char(1);

  for l_index = 1 to %len(i_text);
    l_char = %subst(i_text:l_index:1);
    if l_quote <> ' ';
      if l_char = l_quote;
        l_quote = ' ';
      endif;
    elseif l_char = C_QUOTE or l_char = '"';
      l_quote = l_char;
    elseif l_index + %len(i_token) - 1 <= %len(i_text)
           and %subst(i_text:l_index:%len(i_token)) = i_token;
      return l_index;
    endif;
  endfor;
  return 0;
end-proc;

// ------------------------------------------------------------------
// Keeps the lines of the statement read so far as comments and reports them R.
dcl-proc SqlReject;
  dcl-pi *n;
    i_reason varchar(150) const;
  end-pi;

  dcl-s l_index int(10);

  for l_index = 1 to g_sqlCount;
    if l_index = 1;
      // Also writes the lines of indicators that were waiting for an operation.
      ReviewHere(g_sqlRaw(1):g_sqlLineNo(1):i_reason);
    else;
      Emit('// ' + RulDialectLabel() + ': ' + SpecText(g_sqlRaw(l_index))
           :g_sqlLineNo(l_index));
      RptItem(C_STS_REVIEW:g_sqlLineNo(l_index):SpecText(g_sqlRaw(l_index))
              :i_reason);
    endif;
  endfor;
  g_sqlOpen = *off;
  g_sqlTooLong = *off;
  g_sqlCount = 0;
end-proc;

// ------------------------------------------------------------------
// The END-EXEC line: the statement becomes one free-form EXEC SQL statement. The
// lines of the source stay lines of the output, so the SQL text is not changed.
dcl-proc SqlEnd;
  dcl-pi *n;
    i_line char(100) const;
    i_lineNo int(10) const;
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_first int(10) inz(0);
  dcl-s l_last int(10) inz(0);
  dcl-s l_text varchar(100);
  dcl-s l_all varchar(5000) inz('');
  dcl-s l_reason varchar(150) inz('');
  dcl-s l_note varchar(190) inz('');
  dcl-s l_status char(1);

  g_sqlOpen = *off;

  for l_index = 1 to g_sqlCount;
    if g_sqlText(l_index) <> '';
      if l_first = 0;
        l_first = l_index;
      endif;
      l_last = l_index;
    endif;
  endfor;

  select;
    when g_sqlTooLong;
      l_reason = 'More than ' + %char(C_MAXSQL) + ' lines in one SQL statement';
    when l_first = 0;
      l_reason = 'EXEC SQL without an SQL statement';
    when g_condLineCount > 0;
      l_reason = 'Conditioning indicators cannot be used with EXEC SQL';
    when g_stackCount > 0 and g_stackKind(g_stackCount) = 'CAS';
      l_reason = 'Only CASxx operations can be in a CAS group';
  endsl;
  if l_reason = '';
    for l_index = l_first to l_last;
      if SqlFindOutside(g_sqlText(l_index):';') > 0;
        l_reason = 'The SQL text contains a semicolon';
      endif;
    endfor;
  endif;
  if l_reason <> '';
    SqlReject(l_reason);
    ReviewSpec(i_lineNo:i_line:l_reason);
    return;
  endif;

  // The declarations of the result fields go before the first statement.
  if g_declAt = 0;
    AddOut('':g_sqlLineNo(1));
    g_declAt = OutCount();
  endif;
  g_hdrIndex = 0;

  for l_index = l_first to l_last;
    if g_sqlText(l_index) = '';
      iter;
    endif;
    l_text = g_sqlText(l_index);
    if l_index = l_first;
      Emit('exec sql ' + l_text:g_sqlLineNo(l_index));
    else;
      Emit(l_text:g_sqlLineNo(l_index):1);
    endif;
  endfor;
  // A comment (--) at the end of the last line would hide the semicolon.
  if SqlFindOutside(g_sqlText(l_last):'--') > 0;
    Emit(';':g_sqlLineNo(l_last):1);
  else;
    Emit(';':g_sqlLineNo(l_last));
  endif;

  // The report: each line of the source is converted; the notes go on the first.
  l_all = %xlate(C_LOWER:C_UPPER:g_sqlText(l_first));
  for l_index = l_first + 1 to l_last;
    l_all += ' ' + %xlate(C_LOWER:C_UPPER:g_sqlText(l_index));
  endfor;
  if %scan('WHENEVER':l_all) > 0 and %scan('GOTO':l_all) > 0;
    AddReason(l_note:'WHENEVER ... GOTO names a TAG label, and TAG is not converted');
  endif;
  l_status = C_STS_CONVERTED;
  if l_note <> '';
    l_status = C_STS_ASSUMPTION;
  endif;
  if not g_inSub and not g_cycleNoted;
    g_cycleNoted = *on;
    l_status = C_STS_ASSUMPTION;
    AddReason(l_note:RulConfig('CYCLE_NOTE':'The RPG cycle is not emulated'));
  endif;
  for l_index = 1 to g_sqlCount;
    if l_index = 1;
      RptItem(l_status:g_sqlLineNo(1):SpecText(g_sqlRaw(1)):l_note);
    else;
      RptItem(C_STS_CONVERTED:g_sqlLineNo(l_index):SpecText(g_sqlRaw(l_index)):'');
    endif;
  endfor;
  RptItem(C_STS_CONVERTED:i_lineNo:SpecText(i_line):'');
  g_sqlCount = 0;
end-proc;

// ------------------------------------------------------------------
// The end of the source: groups still open are reported, and the placeholder
// written before the first calculation becomes the declarations of the fields
// that result fields define.
dcl-proc CalcFinish export;
  dcl-pi *n;
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_total int(10);
  dcl-s l_text varchar(200);

  if g_sqlOpen;
    SqlReject('EXEC SQL is not closed by END-EXEC at the end of the source');
  endif;
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
  // The declarations of the result fields, then the prototypes of the CALLs.
  l_total = g_declCount + g_protoLineCount;
  if l_total = 0;
    OutSet(g_declAt:'');
    return;
  endif;
  for l_index = 1 to l_total;
    if l_index <= g_declCount;
      l_text = 'dcl-s ' + g_declName(l_index) + ' ' + g_declType(l_index) + ';';
    else;
      l_text = g_protoLine(l_index - g_declCount);
    endif;
    if l_index = 1;
      OutSet(g_declAt:l_text);
    else;
      OutInsertAfter(g_declAt + l_index - 2:l_text);
    endif;
  endfor;
end-proc;
