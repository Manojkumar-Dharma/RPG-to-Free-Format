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
/copy qcpysrc,IAfreeCalP

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
dcl-c C_MAXSTMT 40;
dcl-c C_MAXSQL 200;
dcl-c C_MAXKL 100;
dcl-c C_MAXPL 40;
dcl-c C_MAXCALL 100;
dcl-c C_MAXPM 400;
dcl-c C_MAXPROTO 40;
dcl-c C_MAXPLINE 300;
dcl-c C_MAXFLD 1000;
dcl-c C_MAXARR 200;
dcl-c C_MAXDT 100;

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

// The RPG cycle skeleton (FREE-36). State: blank none, P pending (nothing written
// yet), D the cycle loop is open (detail calculations), T the subroutine of the total
// calculations is open, E the cycle is closed. g_cycHasTotals and g_cycPreMax come
// from CalcPrescan (total calculation lines; highest control level used).
dcl-s g_cycState char(1) inz(' ');
dcl-s g_cycChecked ind inz(*off);
dcl-s g_cycFile varchar(8) inz('');
dcl-s g_cycRec varchar(12) inz('');
dcl-s g_cycMax int(10) inz(0);
dcl-s g_cycHasTotals ind inz(*off);
dcl-s g_cycPreMax int(10) inz(0);
dcl-s g_cycUsesRt ind inz(*off);
dcl-s g_cycNoPrim ind inz(*off);          // RV-60: the cycle without a primary file

// GOTO, CABxx and TAG (RV-14): the calculation lines in order, with what the
// planner decided for each of them (BuildJumpPlan). Kinds: O group (IF, SELEC),
// L loop (DO, DOW, DOU), M middle (ELSE, WHxx, OTHER), C end of a group, S BEGSR,
// E ENDSR, G GOTO or CABxx, T TAG, Z LEAVE or ITER, X any other operation.
// Actions of a G: K skip (IF), B back to a TAG (end of a loop), R RETURN or LEAVESR,
// V LEAVE; blank when the jump is not converted.
dcl-c C_MAXJV 1500;
dcl-c C_MAXIV 400;
dcl-s g_jvCount int(10);
dcl-s g_jvUnsafe ind;
dcl-s g_jvPlanned ind;
dcl-s g_jvPending ind;
dcl-s g_jvLineNo int(10) dim(C_MAXJV);
dcl-s g_jvLine char(100) dim(C_MAXJV);
dcl-s g_jvKind char(1) dim(C_MAXJV);
dcl-s g_jvLabel varchar(14) dim(C_MAXJV);
dcl-s g_jvCondF ind dim(C_MAXJV);       // G: conditioned (CABxx, indicators, group)
dcl-s g_jvGroupF ind dim(C_MAXJV);      // G: lines of indicators before it
dcl-s g_jvBad ind dim(C_MAXJV);         // not convertible (level, indicators, label)
dcl-s g_jvDepth int(10) dim(C_MAXJV);   // open groups before the line
dcl-s g_jvBody int(10) dim(C_MAXJV);    // 0 main, else the index of the BEGSR
dcl-s g_jvAct char(1) dim(C_MAXJV);
dcl-s g_jvPeer int(10) dim(C_MAXJV);    // G: the index of its TAG
dcl-s g_jvCond varchar(300) dim(C_MAXJV);   // G of a loop: the condition
dcl-s g_jvLoopAt ind dim(C_MAXJV);      // T: a loop starts here
dcl-s g_jvFail ind dim(C_MAXJV);        // G: not written (the IF is not open)
dcl-s g_jvUnconv int(10) dim(C_MAXJV);  // T: GOTO or CABxx to it that stay R
dcl-s g_jvPre ind dim(C_MAXJV);         // the condition comes from the caller (RPG IV)
dcl-s g_jvCondPre varchar(300) dim(C_MAXJV);
dcl-s g_jvSql ind dim(C_MAXJV);         // G: the implicit jump of an SQL WHENEVER (RV-37)

// WHENEVER ... GOTO of embedded SQL (RV-37). The scan before the conversion follows
// the three conditions in source order (1 SQLERROR, 2 NOT FOUND, 3 SQLWARNING): a
// WHENEVER holds for every executable SQL statement after it, whatever the order of
// execution is. Each such statement gets one jump event for every condition that
// has a label; the key of the event is the negative number from SqlKey, so it
// cannot meet the line number of a real line.
dcl-c C_WHEN_N 3;
dcl-s g_wnLabel varchar(14) dim(C_WHEN_N);   // '' when the condition is not active
dcl-s g_wnBad ind dim(C_WHEN_N);             // active but the WHENEVER was not understood
dcl-s g_ssOpen ind;                          // scan: an SQL statement is being read
dcl-s g_ssLines int(10);
dcl-s g_ssFirstNo int(10);
dcl-s g_ssHead varchar(200);                 // the first 200 positions of its text
dcl-s g_ssHasText ind;
dcl-s g_ssBlocked ind;                       // the conversion will reject the statement
dcl-s g_ssOver ind;                          // more events than C_MAXJV: the tests are lost

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

// The fields DEFN *NAMVAR associates with a data area: the field, the quoted name of
// the data area, whether the DTAARA keyword is in place and the line of the DEFN.
dcl-s g_dtName varchar(10) dim(C_MAXDT);
dcl-s g_dtExt varchar(20) dim(C_MAXDT);
dcl-s g_dtApplied ind dim(C_MAXDT);
dcl-s g_dtLineNo int(10) dim(C_MAXDT);
dcl-s g_dtText varchar(75) dim(C_MAXDT);
dcl-s g_dtCount int(10);

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

  dcl-s l_n int(10);

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
  g_dtCount = 0;
  g_jvCount = 0;
  g_jvUnsafe = *off;
  g_jvPlanned = *off;
  g_jvPending = *off;
  for l_n = 1 to C_WHEN_N;
    g_wnLabel(l_n) = '';
    g_wnBad(l_n) = *off;
  endfor;
  g_ssOpen = *off;
  g_ssLines = 0;
  g_ssFirstNo = 0;
  g_ssHead = '';
  g_ssHasText = *off;
  g_ssBlocked = *off;
  g_ssOver = *off;
  g_cycState = ' ';
  g_cycChecked = *off;
  g_cycFile = '';
  g_cycRec = '';
  g_cycMax = 0;
  g_cycHasTotals = *off;
  g_cycPreMax = 0;
  g_cycUsesRt = *off;
  g_cycNoPrim = *off;
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
  dcl-s l_columns int(10) inz(0);

  l_width = %int(RulConfig('INDENT':'2'));
  l_levels = g_depth;
  if %parms >= 1;
    l_levels += i_extra;
  endif;
  if l_levels > 0 and l_width > 0;
    l_columns = l_levels * l_width;
  endif;
  // RPG IV: the groups are kept by IAfreeFx4, two positions a level as there
  // (RV-59); the depth is 0 for RPG II and III.
  l_columns += 2 * Fx4Depth();
  if l_columns <= 0;
    return '';
  endif;
  return %subst('                                                            '
                :1:%min(l_columns:60));
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
      elseif l_rule.cycle = 'Y' and not IndCycleOk(l_rule.class:*off);
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
  ApplyPendingDtaara(Up(i_name));
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
  if l_ind.cycle = 'Y' and not IndCycleOk(l_ind.class:*on);
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

  // The causes of a report line are joined by ' | ' (IAcnvRpt counts each one on
  // its own); a cause can hold '; ' itself.
  if %len(io_text) > 0;
    io_text += ' | ';
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
  dcl-s l_levelTerm varchar(10) inz('');

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

  // The RPG cycle skeleton: the loop opens before the first detail calculation, the
  // total calculations go to a subroutine, both close before a BEGSR (FREE-36).
  CycBefore(l_up:i_lineNo);

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
    when CycTotalLevel(l_c.level);
      // Total calculation of the cycle skeleton: the level indicator is a condition.
      if l_c.level <> 'L0';
        l_levelTerm = '*in' + Low(l_c.level);
      endif;
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
  if l_levelTerm <> '';
    if l_list <> '';
      l_list = l_levelTerm + ' and ' + l_list;
    else;
      l_list = l_levelTerm;
    endif;
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
  // GOTO, CABxx and TAG: some patterns become IF, DOU/DOW and LEAVE (RV-14).
  if l_rule.kind = 'GOTO' or l_rule.kind = 'JUMP' or l_rule.kind = 'TAG';
    ConvertJump(l_c:l_rule);
    return;
  endif;
  // EXFMT and READC of the display file (RV-12): converted when the source has a
  // WORKSTN file; the other WORKSTN operations (ACQ, REL, NEXT, POST) stay R.
  // The table says A (converted with a WORKSTN file); without one the line is R.
  if l_rule.kind = 'FILE' and (l_rule.opcode = 'EXFMT' or l_rule.opcode = 'READC'
     or l_rule.opcode = 'ACQ' or l_rule.opcode = 'REL' or l_rule.opcode = 'NEXT'
     or l_rule.opcode = 'POST');
    if WorkstnFile() <> '';
      l_rule.status = C_STS_CONVERTED;
      l_rule.reason = '';
    else;
      l_rule.status = 'R';
      l_rule.reason = l_rule.opcode + ' needs a WORKSTN file in the source (RV-12)';
    endif;
  endif;
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
  if l_rule.opcode = 'IN' or l_rule.opcode = 'OUT';
    g_hdrIndex = 0;
    ConvertDataArea(l_c:l_rule);
    return;
  endif;
  if l_rule.opcode = 'OCUR';
    g_hdrIndex = 0;
    ConvertOcur(l_c:l_rule);
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
// GOTO, CABxx and TAG (review item RV-14). CalcJumpScan keeps the calculation
// lines in order; BuildJumpPlan decides, before the first one is written, which
// jumps are one of three patterns of structured code (everything else stays R):
//   skip      a GOTO or CABxx with a condition to a later TAG of the same group:
//             IF NOT (condition); ... ENDIF; at the TAG
//   to the end a GOTO or CABxx to a TAG that is the last statement of the
//             subroutine or of the program: LEAVESR or RETURN
//   loop      a GOTO or CABxx back to an earlier TAG of the same group: DOU NOT
//             (condition) (DOW *ON without a condition) at the TAG and ENDDO at
//             the jump; a GOTO to the TAG right after the loop inside it is LEAVE
// The statements between the two ends must keep their groups whole (no ELSE of
// the group of the jump, no BEGSR or ENDSR, no TAG that another jump outside
// needs), and the ends of two patterns must not cross.
dcl-proc CalcJumpScan export;
  dcl-pi *n;
    i_line char(100) const;
    i_lineNo int(10) const;
  end-pi;

  dcl-ds l_rule likeds(IAfreeOpc_t);
  dcl-s l_xx char(2);
  dcl-s l_up char(100);
  dcl-s l_op varchar(5);
  dcl-s l_level char(2);
  dcl-s l_kind char(1);
  dcl-s l_label varchar(14) inz('');
  dcl-s l_cond ind inz(*off);
  dcl-s l_bad ind inz(*off);
  dcl-s l_group ind inz(*off);

  l_up = %xlate(C_LOWER:C_UPPER:i_line);
  if %subst(l_up:6:1) <> 'C';
    return;
  endif;
  // The lines of an embedded SQL statement: the WHENEVER jumps (RV-37).
  CalcSqlJumpScan(i_line:i_lineNo);
  if %subst(l_up:7:1) = '*' or %subst(l_up:7:1) = '/' or %subst(l_up:7:1) = '+';
    return;
  endif;
  if %trim(Fld(i_line:'ALLC')) = '';
    return;
  endif;
  l_level = Fld(l_up:'LEVEL');
  // A line of indicators without an operation belongs to the next operation.
  if %trim(Fld(i_line:'BODY')) = ''
     and (%trim(Fld(i_line:'CONDALL')) <> '' or l_level = 'AN' or l_level = 'OR');
    g_jvPending = *on;
    return;
  endif;
  l_op = %trim(Fld(l_up:'OPERATION'));
  if l_op = '';
    return;
  endif;
  l_group = g_jvPending;
  g_jvPending = *off;
  if g_jvCount >= C_MAXJV;
    g_jvUnsafe = *on;
    return;
  endif;

  l_kind = 'X';
  if RulOpcode(l_op:l_rule:l_xx);
    select;
      when l_rule.kind = 'IF' or l_rule.kind = 'SELEC';
        l_kind = 'O';
      when l_rule.kind = 'DO' or l_rule.kind = 'DOW' or l_rule.kind = 'DOU';
        l_kind = 'L';
      when l_rule.kind = 'CASE';
        g_jvUnsafe = *on;
      when l_rule.kind = 'WHEN' or l_rule.kind = 'OTHER' or l_rule.kind = 'ELSE';
        l_kind = 'M';
      when l_rule.kind = 'END';
        l_kind = 'C';
      when l_rule.kind = 'ANDOR';
        return;
      when l_rule.kind = 'LOOPCTL';
        l_kind = 'Z';
      when l_rule.kind = 'SUBR' and l_rule.opcode = 'BEGSR';
        l_kind = 'S';
      when l_rule.kind = 'SUBR' and l_rule.opcode = 'ENDSR';
        l_kind = 'E';
      when l_rule.kind = 'GOTO' or l_rule.kind = 'JUMP';
        l_kind = 'G';
        if l_rule.kind = 'JUMP';
          l_label = Up(%trim(Fld(i_line:'RESULT')));
          l_cond = *on;
          if %trim(Fld(l_up:'RES1')) <> '' or %trim(Fld(l_up:'RES2')) <> ''
             or %trim(Fld(l_up:'RES3')) <> '' or RulComparison(l_xx) = '';
            l_bad = *on;
          endif;
        else;
          l_label = Up(%trim(Fld(i_line:'FACTOR2')));
        endif;
      when l_rule.kind = 'TAG';
        l_kind = 'T';
        l_label = Up(%trim(Fld(i_line:'FACTOR1')));
    endsl;
  endif;
  if l_kind = 'G' or l_kind = 'T';
    if l_label = '' or (l_level <> '  ' and l_level <> 'SR' and l_level <> 'AN'
                        and l_level <> 'OR');
      l_bad = *on;
    endif;
    if %trim(Fld(l_up:'IND1')) <> '' or %trim(Fld(l_up:'IND2')) <> ''
       or %trim(Fld(l_up:'IND3')) <> '';
      l_cond = *on;
      if l_kind = 'T';
        l_bad = *on;
      endif;
    endif;
    if l_group;
      l_cond = *on;
    endif;
  endif;

  g_jvCount += 1;
  g_jvLineNo(g_jvCount) = i_lineNo;
  g_jvLine(g_jvCount) = i_line;
  g_jvKind(g_jvCount) = l_kind;
  g_jvLabel(g_jvCount) = l_label;
  g_jvCondF(g_jvCount) = l_cond;
  g_jvGroupF(g_jvCount) = l_group;
  g_jvBad(g_jvCount) = l_bad;
  g_jvDepth(g_jvCount) = 0;
  g_jvBody(g_jvCount) = 0;
  g_jvAct(g_jvCount) = ' ';
  g_jvPeer(g_jvCount) = 0;
  g_jvCond(g_jvCount) = '';
  g_jvLoopAt(g_jvCount) = *off;
  g_jvFail(g_jvCount) = *off;
  g_jvUnconv(g_jvCount) = 0;
  g_jvPre(g_jvCount) = *off;
  g_jvCondPre(g_jvCount) = '';
  g_jvSql(g_jvCount) = *off;
end-proc;

// ------------------------------------------------------------------
// The index of the event of the source line, 0 when there is none.
dcl-proc JvFind;
  dcl-pi *n int(10);
    i_lineNo int(10) const;
  end-pi;

  dcl-s l_k int(10);

  for l_k = 1 to g_jvCount;
    if g_jvLineNo(l_k) = i_lineNo;
      return l_k;
    endif;
  endfor;
  return 0;
end-proc;

// ------------------------------------------------------------------
// The only TAG of a label: its index, 0 when there is none, -1 when there are
// several or the TAG cannot be converted.
dcl-proc JvTag;
  dcl-pi *n int(10);
    i_label varchar(14) const;
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_found int(10) inz(0);

  for l_k = 1 to g_jvCount;
    if g_jvKind(l_k) = 'T' and g_jvLabel(l_k) = i_label;
      if l_found <> 0;
        return -1;
      endif;
      l_found = l_k;
    endif;
  endfor;
  if l_found > 0 and g_jvBad(l_found);
    return -1;
  endif;
  return l_found;
end-proc;

// ------------------------------------------------------------------
// *ON when nothing that runs follows the TAG in its subroutine or in the main
// part of the program (only other TAGs and whole subroutines do), and the TAG is
// not inside a group.
dcl-proc JvIsLast;
  dcl-pi *n ind;
    i_t int(10) const;
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_base int(10) inz(0);

  if g_jvBody(i_t) <> 0;
    l_base = 1;
  endif;
  if g_jvDepth(i_t) <> l_base;
    return *off;
  endif;
  l_k = i_t + 1;
  dow l_k <= g_jvCount;
    select;
      when g_jvKind(l_k) = 'T';
      when g_jvKind(l_k) = 'S' and g_jvBody(i_t) = 0;
        dow l_k < g_jvCount and g_jvKind(l_k) <> 'E';
          l_k += 1;
        enddo;
      when g_jvKind(l_k) = 'E' and g_jvBody(i_t) <> 0;
        return *on;
      other;
        return *off;
    endsl;
    l_k += 1;
  enddo;
  return *on;
end-proc;

// ------------------------------------------------------------------
// The statements between event i_a and event i_b (the two ends of a pattern at the
// same depth in the same body) keep their groups whole: no ELSE, WHEN or END of the
// group of the ends, no BEGSR or ENDSR, and no TAG that a jump outside of the two
// ends needs. For a loop a LEAVE or ITER has to be inside a loop of its own.
dcl-proc JvRegionOk;
  dcl-pi *n ind;
    i_a int(10) const;
    i_b int(10) const;
    i_loop ind const;
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_g int(10);
  dcl-s l_d int(10);
  dcl-s l_stack char(1) dim(60);
  dcl-s l_top int(10) inz(0);
  dcl-s l_s int(10);
  dcl-s l_hasLoop ind;

  l_d = g_jvDepth(i_a);
  if g_jvDepth(i_b) <> l_d or g_jvBody(i_a) <> g_jvBody(i_b);
    return *off;
  endif;
  for l_k = i_a + 1 to i_b - 1;
    select;
      when g_jvKind(l_k) = 'S' or g_jvKind(l_k) = 'E';
        return *off;
      when g_jvKind(l_k) = 'M' or g_jvKind(l_k) = 'C';
        if g_jvDepth(l_k) < l_d + 1;
          return *off;
        endif;
      when g_jvDepth(l_k) < l_d;
        return *off;
    endsl;
    select;
      when g_jvKind(l_k) = 'O' or g_jvKind(l_k) = 'L';
        if l_top < 60;
          l_top += 1;
          l_stack(l_top) = g_jvKind(l_k);
        endif;
      when g_jvKind(l_k) = 'C';
        if l_top > 0;
          l_top -= 1;
        endif;
      when g_jvKind(l_k) = 'Z' and i_loop;
        l_hasLoop = *off;
        for l_s = 1 to l_top;
          if l_stack(l_s) = 'L';
            l_hasLoop = *on;
          endif;
        endfor;
        if not l_hasLoop;
          return *off;
        endif;
    endsl;
    if g_jvKind(l_k) = 'T';
      for l_g = 1 to g_jvCount;
        if g_jvKind(l_g) = 'G' and g_jvLabel(l_g) = g_jvLabel(l_k)
           and (l_g < i_a or l_g > i_b);
          return *off;
        endif;
      endfor;
    endif;
  endfor;
  return *on;
end-proc;

// ------------------------------------------------------------------
// The number of backward GOTO or CABxx (after the TAG) to a TAG.
dcl-proc JvBackCount;
  dcl-pi *n int(10);
    i_t int(10) const;
  end-pi;

  dcl-s l_g int(10);
  dcl-s l_n int(10) inz(0);

  for l_g = i_t + 1 to g_jvCount;
    if g_jvKind(l_g) = 'G' and g_jvLabel(l_g) = g_jvLabel(i_t);
      l_n += 1;
    endif;
  endfor;
  return l_n;
end-proc;

// ------------------------------------------------------------------
// The condition of a CABxx as free-form text (factor 1 operator factor 2) or the
// reason it cannot be written.
dcl-proc CabCompare;
  dcl-pi *n varchar(190);
    i_line char(100) const;
    o_text varchar(190);
  end-pi;

  dcl-ds l_rule likeds(IAfreeOpc_t);
  dcl-s l_xx char(2);
  dcl-s l_up char(100);
  dcl-s l_operator varchar(2);
  dcl-s l_f1 varchar(30);
  dcl-s l_f2 varchar(30);
  dcl-s l_c1 varchar(30);
  dcl-s l_c2 varchar(30);
  dcl-s l_reason varchar(150) inz('');

  o_text = '';
  l_up = %xlate(C_LOWER:C_UPPER:i_line);
  if not RulOpcode(%trim(Fld(l_up:'OPERATION')):l_rule:l_xx)
     or l_rule.kind <> 'JUMP';
    return 'The line is not a CABxx';
  endif;
  l_operator = RulComparison(l_xx);
  if l_operator = '';
    return 'CAB needs xx: GT, LT, EQ, NE, GE or LE';
  endif;
  if %trim(Fld(l_up:'RES1')) <> '' or %trim(Fld(l_up:'RES2')) <> ''
     or %trim(Fld(l_up:'RES3')) <> '';
    return 'Resulting indicators of CABxx are not converted';
  endif;
  l_f1 = %trim(Fld(i_line:'FACTOR1'));
  l_f2 = %trim(Fld(i_line:'FACTOR2'));
  if l_f1 = '' or l_f2 = '';
    return 'CABxx needs factor 1 and factor 2';
  endif;
  if not ConvOperand(l_f1:l_c1:l_reason);
    return l_reason;
  endif;
  if not ConvOperand(l_f2:l_c2:l_reason);
    return l_reason;
  endif;
  o_text = l_c1 + ' ' + l_operator + ' ' + l_c2;
  return '';
end-proc;

// ------------------------------------------------------------------
// The condition of a GOTO or CABxx line without lines of indicators before it:
// its own indicators and the comparison. '' or the reason in o_reason.
dcl-proc JumpCondition;
  dcl-pi *n varchar(300);
    i_line char(100) const;
    o_reason varchar(190);
  end-pi;

  dcl-s l_terms varchar(150);
  dcl-s l_cmp varchar(190);
  dcl-s l_reason varchar(150) inz('');
  dcl-s l_cond varchar(300);

  o_reason = '';
  l_terms = LineTerms(i_line:l_reason);
  if l_reason <> '';
    o_reason = l_reason;
    return '';
  endif;
  l_cond = l_terms;
  if %subst(%xlate(C_LOWER:C_UPPER:%trim(Fld(i_line:'OPERATION'))):1:3) = 'CAB';
    l_reason = CabCompare(i_line:l_cmp);
    if l_reason <> '';
      o_reason = l_reason;
      return '';
    endif;
    if l_cond <> '';
      l_cond += ' and ';
    endif;
    l_cond += l_cmp;
  endif;
  return l_cond;
end-proc;

// ------------------------------------------------------------------
// The opposite of a condition: a single indicator test is turned round, anything
// else is put in parentheses after NOT.
dcl-proc Negate;
  dcl-pi *n varchar(310);
    i_cond varchar(300) const;
  end-pi;

  if %len(i_cond) > 4 and %subst(i_cond:1:4) = 'not '
     and %scan(' ':i_cond:5) = 0;
    return %subst(i_cond:5);
  endif;
  if %scan(' ':i_cond) = 0;
    return 'not ' + i_cond;
  endif;
  return 'not (' + i_cond + ')';
end-proc;

// ------------------------------------------------------------------
// Decides, once, what becomes of every GOTO, CABxx and TAG (see CalcJumpScan).
dcl-proc BuildJumpPlan;
  dcl-pi *n;
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_g int(10);
  dcl-s l_t int(10);
  dcl-s l_i int(10);
  dcl-s l_j int(10);
  dcl-s l_depth int(10) inz(0);
  dcl-s l_body int(10) inz(0);
  dcl-s l_ivType char(1) dim(C_MAXIV);
  dcl-s l_ivA int(10) dim(C_MAXIV);
  dcl-s l_ivB int(10) dim(C_MAXIV);
  dcl-s l_ivG int(10) dim(C_MAXIV);
  dcl-s l_ivOn ind dim(C_MAXIV);
  dcl-s l_ivCount int(10) inz(0);
  dcl-s l_cond varchar(300);
  dcl-s l_reason varchar(190);
  dcl-s l_changed ind;
  dcl-s l_best int(10);
  dcl-s l_ok ind;

  g_jvPlanned = *on;
  if g_jvUnsafe or g_jvCount = 0;
    return;
  endif;

  // The depth (open groups) before every line, and the subroutine it is in.
  for l_k = 1 to g_jvCount;
    g_jvDepth(l_k) = l_depth;
    g_jvBody(l_k) = l_body;
    select;
      when g_jvKind(l_k) = 'O' or g_jvKind(l_k) = 'L';
        l_depth += 1;
      when g_jvKind(l_k) = 'S';
        if l_body <> 0 or l_depth <> 0;
          g_jvUnsafe = *on;
        endif;
        l_body = l_k;
        g_jvBody(l_k) = l_k;
        l_depth += 1;
      when g_jvKind(l_k) = 'E';
        if l_body = 0 or l_depth <> 1;
          g_jvUnsafe = *on;
        endif;
        l_body = 0;
        l_depth = 0;
      when g_jvKind(l_k) = 'C';
        l_depth -= 1;
        if l_depth < 0;
          g_jvUnsafe = *on;
          l_depth = 0;
        endif;
    endsl;
  endfor;
  if l_depth <> 0 or g_jvUnsafe;
    g_jvUnsafe = *on;
    return;
  endif;

  // Every jump: to the end, skip forward or loop back.
  for l_k = 1 to g_jvCount;
    if g_jvKind(l_k) <> 'G' or g_jvBad(l_k);
      iter;
    endif;
    l_t = JvTag(g_jvLabel(l_k));
    if l_t <= 0;
      iter;
    endif;
    g_jvPeer(l_k) = l_t;
    select;
      when l_t > l_k and g_jvBody(l_k) = g_jvBody(l_t) and JvIsLast(l_t);
        g_jvAct(l_k) = 'R';
      when l_t > l_k and g_jvCondF(l_k) and JvRegionOk(l_k:l_t:*off)
           and l_ivCount < C_MAXIV;
        l_ivCount += 1;
        l_ivType(l_ivCount) = 'K';
        l_ivA(l_ivCount) = l_k;
        l_ivB(l_ivCount) = l_t;
        l_ivG(l_ivCount) = l_k;
        l_ivOn(l_ivCount) = *on;
      // No loop for the implicit jump of a WHENEVER (RV-37): it would repeat an
      // SQL statement until it succeeds, which nobody meant.
      when l_t < l_k and JvBackCount(l_t) = 1 and not g_jvGroupF(l_k)
           and not g_jvSql(l_k)
           and JvRegionOk(l_t:l_k:*on) and l_ivCount < C_MAXIV;
        l_cond = '';
        l_reason = '';
        if g_jvCondF(l_k) and g_jvPre(l_k);
          l_cond = g_jvCondPre(l_k);
        elseif g_jvCondF(l_k);
          l_cond = JumpCondition(g_jvLine(l_k):l_reason);
        endif;
        if l_reason = '';
          g_jvCond(l_k) = l_cond;
          l_ivCount += 1;
          l_ivType(l_ivCount) = 'B';
          l_ivA(l_ivCount) = l_t;
          l_ivB(l_ivCount) = l_k;
          l_ivG(l_ivCount) = l_k;
          l_ivOn(l_ivCount) = *on;
        endif;
    endsl;
  endfor;

  // Two patterns whose ends cross cannot both be written.
  l_changed = *on;
  dow l_changed;
    l_changed = *off;
    for l_i = 1 to l_ivCount;
      if not l_ivOn(l_i);
        iter;
      endif;
      for l_j = 1 to l_ivCount;
        if l_j <> l_i and l_ivOn(l_j) and l_ivA(l_i) < l_ivA(l_j)
           and l_ivA(l_j) < l_ivB(l_i) and l_ivB(l_i) < l_ivB(l_j);
          l_ivOn(l_j) = *off;
          l_changed = *on;
        endif;
      endfor;
    endfor;
  enddo;
  for l_i = 1 to l_ivCount;
    if l_ivOn(l_i);
      l_g = l_ivG(l_i);
      if l_ivType(l_i) = 'K';
        g_jvAct(l_g) = 'K';
      else;
        g_jvAct(l_g) = 'B';
        g_jvLoopAt(l_ivA(l_i)) = *on;
      endif;
    else;
      g_jvCond(l_ivG(l_i)) = '';
    endif;
  endfor;

  // A jump inside a loop to the TAG right after the loop leaves the loop.
  for l_k = 1 to g_jvCount;
    if g_jvKind(l_k) <> 'G' or g_jvBad(l_k) or g_jvAct(l_k) <> ' '
       or g_jvPeer(l_k) <= l_k;
      iter;
    endif;
    l_t = g_jvPeer(l_k);
    l_best = 0;
    l_g = 0;
    for l_i = 1 to g_jvCount;
      if g_jvKind(l_i) = 'G' and g_jvAct(l_i) = 'B' and l_i > l_k
         and g_jvPeer(l_i) < l_k and g_jvPeer(l_i) > l_best;
        l_best = g_jvPeer(l_i);
        l_g = l_i;
      endif;
    endfor;
    if l_g = 0;
      iter;
    endif;
    l_ok = l_t > l_g and g_jvDepth(l_t) = g_jvDepth(l_best)
           and g_jvBody(l_t) = g_jvBody(l_best);
    if l_ok;
      for l_i = l_g + 1 to l_t - 1;
        if g_jvKind(l_i) <> 'T';
          l_ok = *off;
        endif;
      endfor;
    endif;
    // No loop of its own between the start of the loop and the jump.
    if l_ok;
      l_ok = JvInsideNoLoop(l_best:l_k);
    endif;
    if l_ok;
      g_jvAct(l_k) = 'V';
    endif;
  endfor;

  // The jumps to a TAG that stay R.
  for l_k = 1 to g_jvCount;
    if g_jvKind(l_k) = 'G' and g_jvAct(l_k) = ' ';
      for l_i = 1 to g_jvCount;
        if g_jvKind(l_i) = 'T' and g_jvLabel(l_i) = g_jvLabel(l_k);
          g_jvUnconv(l_i) += 1;
        endif;
      endfor;
    endif;
  endfor;
end-proc;

// ------------------------------------------------------------------
// *ON when no loop group (DO, DOW, DOU) that begins after event i_a is still open
// at event i_b: a LEAVE written for the loop of i_a is the one that is meant.
dcl-proc JvInsideNoLoop;
  dcl-pi *n ind;
    i_a int(10) const;
    i_b int(10) const;
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_top int(10) inz(0);
  dcl-s l_s int(10);
  dcl-s l_stack char(1) dim(60);

  for l_k = i_a + 1 to i_b - 1;
    select;
      when g_jvKind(l_k) = 'O' or g_jvKind(l_k) = 'L';
        if l_top < 60;
          l_top += 1;
          l_stack(l_top) = g_jvKind(l_k);
        endif;
      when g_jvKind(l_k) = 'C';
        if l_top > 0;
          l_top -= 1;
        endif;
    endsl;
  endfor;
  for l_s = 1 to l_top;
    if l_stack(l_s) = 'L';
      return *off;
    endif;
  endfor;
  return *on;
end-proc;

// ------------------------------------------------------------------
// The jumps of an RPG IV source (RV-14): IAfreeFx4 reads its own columns and gives
// each GOTO, CABxx, TAG and group operation to the planner here. i_kind as in
// CalcJumpScan (O, L, M, C, S, E, Z, G, T, X); i_cond is the whole condition of a
// GOTO or CABxx as free-form text (its indicator and the comparison).
dcl-proc JumpEvent export;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_kind char(1) const;
    i_label varchar(14) const;
    i_condF ind const;
    i_bad ind const;
    i_cond varchar(300) const;
  end-pi;

  if g_jvCount >= C_MAXJV;
    g_jvUnsafe = *on;
    return;
  endif;
  g_jvCount += 1;
  g_jvLineNo(g_jvCount) = i_lineNo;
  g_jvLine(g_jvCount) = '';
  g_jvKind(g_jvCount) = i_kind;
  g_jvLabel(g_jvCount) = i_label;
  g_jvCondF(g_jvCount) = i_condF;
  g_jvGroupF(g_jvCount) = *off;
  g_jvBad(g_jvCount) = i_bad;
  g_jvDepth(g_jvCount) = 0;
  g_jvBody(g_jvCount) = 0;
  g_jvAct(g_jvCount) = ' ';
  g_jvPeer(g_jvCount) = 0;
  g_jvCond(g_jvCount) = '';
  g_jvLoopAt(g_jvCount) = *off;
  g_jvFail(g_jvCount) = *off;
  g_jvUnconv(g_jvCount) = 0;
  g_jvPre(g_jvCount) = *on;
  g_jvCondPre(g_jvCount) = i_cond;
  g_jvSql(g_jvCount) = *off;
end-proc;

// ------------------------------------------------------------------
// The source has something the planner cannot follow (a /FREE block, CASxx): no
// jump is converted.
dcl-proc JumpUnsafe export;
  dcl-pi *n;
  end-pi;

  g_jvUnsafe = *on;
end-proc;

// ------------------------------------------------------------------
dcl-proc JumpNegate export;
  dcl-pi *n varchar(310);
    i_cond varchar(300) const;
  end-pi;

  return Negate(i_cond);
end-proc;

// ------------------------------------------------------------------
// What the plan decided for the line (a jump or a TAG). *OFF when the line is not
// converted. o_act of a jump: K skip, B end of a loop, R end of the subroutine or
// program, V leave. For a TAG: o_loop and o_loopCond (the loop that starts here),
// o_kEnds (the IFs of skips that end here), o_unconv (jumps to it that stay R).
dcl-proc JumpInfo export;
  dcl-pi *n ind;
    i_lineNo int(10) const;
    o_kind char(1);
    o_act char(1);
    o_label varchar(14);
    o_cond varchar(300);
    o_inSub ind;
    o_loop ind;
    o_loopCond varchar(300);
    o_kEnds int(10);
    o_unconv int(10);
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_g int(10);

  o_kind = ' ';
  o_act = ' ';
  o_label = '';
  o_cond = '';
  o_inSub = *off;
  o_loop = *off;
  o_loopCond = '';
  o_kEnds = 0;
  o_unconv = 0;
  if not g_jvPlanned;
    BuildJumpPlan();
  endif;
  l_k = JvFind(i_lineNo);
  if l_k = 0 or g_jvUnsafe or g_jvBad(l_k);
    return *off;
  endif;
  o_kind = g_jvKind(l_k);
  o_label = g_jvLabel(l_k);
  o_inSub = (g_jvBody(l_k) <> 0);
  if g_jvKind(l_k) = 'G';
    o_act = g_jvAct(l_k);
    o_cond = g_jvCondPre(l_k);
    return *on;
  endif;
  o_unconv = g_jvUnconv(l_k);
  o_loop = g_jvLoopAt(l_k);
  for l_g = 1 to g_jvCount;
    if g_jvKind(l_g) = 'G' and g_jvPeer(l_g) = l_k and not g_jvFail(l_g);
      if g_jvAct(l_g) = 'K';
        o_kEnds += 1;
      elseif g_jvAct(l_g) = 'B';
        o_loopCond = g_jvCond(l_g);
      endif;
    endif;
  endfor;
  return *on;
end-proc;

// ------------------------------------------------------------------
// GOTO, CABxx and TAG as the plan of BuildJumpPlan decided; what is not planned
// stays R (kept as a comment).
dcl-proc ConvertJump;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  dcl-c C_JUMP_R 'GOTO, CABxx or TAG outside the converted patterns (RV-14)';
  dcl-s l_k int(10);
  dcl-s l_g int(10);
  dcl-s l_t int(10);
  dcl-s l_cond varchar(300);
  dcl-s l_cmp varchar(190);
  dcl-s l_reason varchar(190);
  dcl-s l_word varchar(10);
  dcl-s l_note varchar(190);
  dcl-s l_failed ind;

  g_hdrIndex = 0;
  if not g_jvPlanned;
    BuildJumpPlan();
  endif;
  l_k = JvFind(i_c.lineNo);
  if l_k = 0 or g_jvUnsafe or g_jvBad(l_k);
    ReviewHere(i_c.line:i_c.lineNo:C_JUMP_R);
    return;
  endif;

  // ---- TAG ------------------------------------------------------------------
  if g_jvKind(l_k) = 'T';
    // The skip of a jump that was written closes here.
    for l_g = 1 to l_k - 1;
      if g_jvKind(l_g) = 'G' and g_jvAct(l_g) = 'K' and g_jvPeer(l_g) = l_k
         and not g_jvFail(l_g) and g_stackCount > 0
         and g_stackKind(g_stackCount) = 'JMP';
        Pop();
        Emit('endif;':i_c.lineNo);
      endif;
    endfor;
    // A loop starts here.
    if g_jvLoopAt(l_k);
      l_g = 0;
      for l_t = l_k + 1 to g_jvCount;
        if g_jvKind(l_t) = 'G' and g_jvAct(l_t) = 'B' and g_jvPeer(l_t) = l_k;
          l_g = l_t;
        endif;
      endfor;
      if l_g > 0 and g_jvCond(l_g) <> '';
        Emit('dou ' + Negate(g_jvCond(l_g)) + ';':i_c.lineNo);
        l_word = 'DOU';
      else;
        Emit('dow *on;':i_c.lineNo);
        l_word = 'DOW';
      endif;
      if not Push(l_word:1:0:'');
        Emit('// Groups are nested too deep':i_c.lineNo);
      endif;
      RptItem(C_STS_ASSUMPTION:i_c.lineNo:SpecText(i_c.line)
              :'A TAG starts a loop that ends at the jump back');
      return;
    endif;
    if g_jvUnconv(l_k) > 0;
      ReviewHere(i_c.line:i_c.lineNo:'A GOTO or CABxx to ' + g_jvLabel(l_k)
                 + ' is not converted');
      return;
    endif;
    Emit('// TAG ' + g_jvLabel(l_k):i_c.lineNo);
    RptItem(C_STS_CONVERTED:i_c.lineNo:SpecText(i_c.line):'');
    return;
  endif;

  // ---- GOTO and CABxx --------------------------------------------------------
  if g_jvAct(l_k) = ' ';
    ReviewHere(i_c.line:i_c.lineNo:C_JUMP_R);
    return;
  endif;

  // The end of a loop: ENDDO, the condition is on the DOU at the TAG.
  if g_jvAct(l_k) = 'B';
    if g_stackCount > 0 and (g_stackKind(g_stackCount) = 'DOU'
                             or g_stackKind(g_stackCount) = 'DOW');
      Pop();
      Emit('enddo;':i_c.lineNo);
      RptItem(C_STS_ASSUMPTION:i_c.lineNo:SpecText(i_c.line)
              :'Jump back to a TAG became the end of a loop');
    else;
      ReviewHere(i_c.line:i_c.lineNo:C_JUMP_R);
    endif;
    return;
  endif;

  // The condition: lines of indicators and own indicators (i_c.cond) and the
  // comparison of CABxx.
  l_cond = i_c.cond;
  l_failed = *off;
  if i_rule.kind = 'JUMP';
    l_reason = CabCompare(i_c.line:l_cmp);
    if l_reason <> '';
      l_failed = *on;
    else;
      if l_cond <> '';
        l_cond += ' and ';
      endif;
      l_cond += l_cmp;
    endif;
  endif;
  if l_failed;
    g_jvFail(l_k) = *on;
    ReviewHere(i_c.line:i_c.lineNo:l_reason);
    return;
  endif;

  select;
    when g_jvAct(l_k) = 'K';
      Emit('if ' + Negate(l_cond) + ';':i_c.lineNo);
      if not Push('JMP':1:0:'');
        g_jvFail(l_k) = *on;
        Emit('// Groups are nested too deep':i_c.lineNo);
      endif;
      RptItem(C_STS_ASSUMPTION:i_c.lineNo:SpecText(i_c.line)
              :'Jump forward to a TAG became an IF around the lines'
              + ' up to the TAG');
    when g_jvAct(l_k) = 'R' or g_jvAct(l_k) = 'V';
      if g_jvAct(l_k) = 'V';
        l_word = 'leave';
        l_note = 'Jump to the TAG after the loop became LEAVE';
      elseif g_inSub;
        l_word = 'leavesr';
        l_note = 'Jump to the last TAG of the subroutine became LEAVESR';
      elseif g_cycState = 'D';
        l_word = 'iter';
        l_note = 'Jump to the last TAG of the detail calculations became ITER '
                 + '(the next cycle of the RPG cycle skeleton)';
      else;
        l_word = 'return';
        l_note = 'Jump to the last TAG of the program became RETURN';
      endif;
      if l_cond = '';
        Emit(l_word + ';':i_c.lineNo);
      else;
        Emit('if ' + l_cond + ';':i_c.lineNo);
        Emit(l_word + ';':i_c.lineNo:1);
        Emit('endif;':i_c.lineNo);
      endif;
      RptItem(C_STS_ASSUMPTION:i_c.lineNo:SpecText(i_c.line):l_note);
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
      if not RulIndicator(l_name:l_ind)
         or (l_ind.cycle = 'Y' and not IndCycleOk(l_ind.class:*on));
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
  dcl-ds l_rule likeds(IAfreeOpc_t);
  dcl-s l_isTable ind;
  dcl-s l_seq char(1);
  dcl-s l_dim int(10);
  dcl-s l_alt varchar(10);

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
  // SORTA and XFOOT are A only because the array might not come from an E
  // specification of this member; when it does, nothing is assumed: C.
  l_rule = i_rule;
  if (i_rule.opcode = 'SORTA' or i_rule.opcode = 'XFOOT')
     and ArrayInfo(i_c.factor2:l_isTable:l_seq:l_dim:l_alt) and not l_isTable;
    l_rule.status = C_STS_CONVERTED;
    l_rule.reason = '';
  endif;
  EmitStatements(i_c:l_rule:l_statements:l_count:'');
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
// FREE-49: an indicator that belongs to the RPG cycle can be used once the cycle
// skeleton is written: a control level (L1 to L9) as a conditioning indicator, the
// return indicator RT as a conditioning or resulting indicator.
dcl-proc IndCycleOk;
  dcl-pi *n ind;
    i_class varchar(12) const;
    i_resulting ind const;
  end-pi;

  if g_cycState = ' ';
    return *off;
  endif;
  if %trim(i_class) = 'RETURN';
    return *on;
  endif;
  return not i_resulting and %trim(i_class) = 'CONTROLLEVEL';
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
  if l_ind.cycle = 'Y' and not IndCycleOk(l_ind.class:*on);
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
  dcl-s l_j int(10);
  dcl-s l_cond varchar(200);
  dcl-s l_after varchar(120);
  dcl-s l_before varchar(250);
  dcl-s l_total int(10) inz(0);
  dcl-s l_n int(10);
  dcl-s l_reason varchar(190);
  dcl-s l_tmp varchar(250) dim(C_MAXSTMT);
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
    if OutExceptDisk(l_name:l_k);
      // A record of a DISK file (RV-62): the statements come from IAfreeOut.
      l_n = OutDiskStatements(l_name:l_k:l_tmp:l_reason);
      if l_n = 0;
        ReviewHere(i_c.line:i_c.lineNo:'EXCPT ' + l_name + ': ' + l_reason);
        return;
      endif;
      if l_total + l_n > C_MAXSTMT;
        ReviewHere(i_c.line:i_c.lineNo:'EXCPT ' + l_name + ' writes too many '
                   + 'statements for one calculation');
        return;
      endif;
      for l_j = 1 to l_n;
        l_total += 1;
        l_statements(l_total) = l_tmp(l_j);
      endfor;
      CalcRecordDs(OutExceptFile(l_name:l_k));
      iter;
    endif;
    l_cond = OutExceptCond(l_name:l_k);
    l_after = OutExceptAfter(l_name:l_k);
    if l_after <> '';
      l_after = '; ' + l_after;
    endif;
    l_before = OutExceptBefore(l_name:l_k);
    if l_before <> '';
      l_before += '; ';
    endif;
    l_total += 1;
    if l_total > C_MAXSTMT;
      ReviewHere(i_c.line:i_c.lineNo:'EXCPT ' + l_name + ' writes too many '
                 + 'statements for one calculation');
      return;
    endif;
    if l_cond = '';
      l_statements(l_total) = l_before + 'write ' + OutExceptFormat(l_name:l_k)
                              + l_after;
    else;
      l_statements(l_total) = 'if ' + l_cond + '; ' + l_before + 'write '
                              + OutExceptFormat(l_name:l_k) + l_after + '; endif';
    endif;
  endfor;
  EmitStatements(i_c:i_rule:l_statements:l_total:'');
end-proc;

// ------------------------------------------------------------------
// A declaration the output records need (RV-61: the packed or binary work field of a
// DISK record), added once with the other declarations before the first calculation.
dcl-proc CalcDeclare export;
  dcl-pi *n;
    i_text varchar(100) const;
  end-pi;

  dcl-s l_index int(10);

  for l_index = 1 to g_protoLineCount;
    if g_protoLine(l_index) = i_text;
      return;
    endif;
  endfor;
  if g_protoLineCount >= C_MAXPLINE;
    return;
  endif;
  g_protoLineCount += 1;
  g_protoLine(g_protoLineCount) = i_text;
end-proc;

// ------------------------------------------------------------------
// RV-62: the record data structure FILE_OUT of an output DISK file, declared once
// with the other declarations before the first calculation.
dcl-proc CalcRecordDs;
  dcl-pi *n;
    i_file varchar(8) const;
  end-pi;

  dcl-s l_text varchar(100);
  dcl-s l_index int(10);
  dcl-s l_length int(10);
  dcl-s l_out ind;
  dcl-s l_upd ind;

  if not FileOutInfo(i_file:l_length:l_out:l_upd) or l_length < 1;
    return;
  endif;
  l_text = 'dcl-ds ' + i_file + '_OUT len(' + %char(l_length) + ') end-ds;';
  for l_index = 1 to g_protoLineCount;
    if g_protoLine(l_index) = l_text;
      return;
    endif;
  endfor;
  if g_protoLineCount >= C_MAXPLINE;
    return;
  endif;
  g_protoLineCount += 1;
  g_protoLine(g_protoLineCount) = l_text;
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
dcl-proc IsDataAreaName;
  dcl-pi *n ind;
    i_upper varchar(30) const;
  end-pi;

  dcl-s l_index int(10);

  for l_index = 1 to g_dtCount;
    if g_dtName(l_index) = i_upper;
      return *on;
    endif;
  endfor;
  return *off;
end-proc;

// ------------------------------------------------------------------
// The DTAARA keyword for a field that a result field declares after the DEFN.
dcl-proc ApplyPendingDtaara;
  dcl-pi *n;
    i_upper varchar(30) const;
  end-pi;

  dcl-s l_index int(10);

  for l_index = 1 to g_dtCount;
    if g_dtName(l_index) = i_upper and not g_dtApplied(l_index);
      g_declType(g_declCount) += ' dtaara(' + g_dtExt(l_index) + ')';
      g_dtApplied(l_index) = *on;
      RptItem(C_STS_CONVERTED:g_dtLineNo(l_index):g_dtText(l_index):'');
    endif;
  endfor;
end-proc;

// ------------------------------------------------------------------
// DEFN *NAMVAR (RPG/400 reference, DEFN): the field or data structure in the result
// field is associated with the data area named in factor 2 (*LDA, *PDA, or the
// name of the data area; blank: the name of the result field). The DTAARA keyword
// goes on the declaration of the field: a data structure of the I specifications,
// or a field that a result field with a length declares (also after the DEFN).
// IN, OUT and UNLCK name the field (see ConvertDataArea).
dcl-proc ConvertNamvar;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
  end-pi;

  dcl-s l_reason varchar(190) inz('');
  dcl-s l_field varchar(30);
  dcl-s l_ext varchar(30);
  dcl-s l_quoted varchar(20);
  dcl-s l_index int(10);
  dcl-s l_applied ind inz(*off);

  l_field = Up(i_c.result);
  l_ext = Up(i_c.factor2);
  if l_ext = '';
    l_ext = l_field;
  endif;
  select;
    when i_c.result = '' or not IsName(i_c.result) or %scan(',':i_c.result) > 0;
      l_reason = 'The result field of DEFN *NAMVAR must be the name of a field or '
                 + 'data structure';
    when i_c.length <> '' or i_c.decimals <> ' ';
      l_reason = 'DEFN *NAMVAR has no length: the field is defined elsewhere';
    when l_ext <> '*LDA' and l_ext <> '*PDA' and not IsName(l_ext);
      l_reason = 'The data area name ' + i_c.factor2 + ' is not valid (a name, '
                 + '*LDA or *PDA)';
    when IsDataAreaName(l_field);
      l_reason = l_field + ' is already associated with a data area';
    when g_dtCount >= C_MAXDT;
      l_reason = 'Too many data areas';
  endsl;
  if l_reason <> '';
    ReviewHere(i_c.line:i_c.lineNo:l_reason);
    return;
  endif;

  l_quoted = C_QUOTE + l_ext + C_QUOTE;
  g_dtCount += 1;
  g_dtName(g_dtCount) = l_field;
  g_dtExt(g_dtCount) = l_quoted;
  g_dtApplied(g_dtCount) = *off;
  g_dtLineNo(g_dtCount) = i_c.lineNo;
  g_dtText(g_dtCount) = SpecText(i_c.line);

  // A field that a result field declared before the DEFN.
  for l_index = 1 to g_declCount;
    if g_declName(l_index) = l_field and not l_applied;
      g_declType(l_index) += ' dtaara(' + l_quoted + ')';
      l_applied = *on;
    endif;
  endfor;
  if not l_applied;
    l_applied = CvtDtaaraDs(l_field:l_quoted);
  endif;
  if l_applied;
    g_dtApplied(g_dtCount) = *on;
    RptItem(C_STS_CONVERTED:i_c.lineNo:SpecText(i_c.line):'');
  endif;
end-proc;

// ------------------------------------------------------------------
// IN and OUT (RPG/400 reference, IN and OUT): in(e) *lock NAME; The name is the
// result field of the DEFN *NAMVAR, or *NAMVAR for all data areas (written
// *dtaara). *LOCK in factor 1 is not allowed for the local data area and the
// PIP data area. The error indicator becomes the (e) extender and %error.
dcl-proc ConvertDataArea;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  dcl-s l_name varchar(30);
  dcl-s l_stmt varchar(100);
  dcl-s l_ind varchar(20) inz('');
  dcl-s l_ext varchar(3) inz('');
  dcl-s l_reason varchar(190) inz('');
  dcl-s l_index int(10);
  dcl-s l_statements varchar(250) dim(C_MAXSTMT);
  dcl-s l_count int(10) inz(1);

  l_name = Up(i_c.factor2);
  select;
    when i_c.result1 <> '  ' or i_c.result3 <> '  ';
      l_reason = 'Only the error indicator (columns 56-57) is used by '
                 + i_rule.opcode;
    when i_c.halfAdjust <> ' ';
      l_reason = 'Operation extender ' + i_c.halfAdjust + ' is not allowed for '
                 + i_rule.opcode;
    when i_c.result <> '';
      l_reason = 'The result field is not used by ' + i_rule.opcode;
    when Up(i_c.factor1) <> '' and Up(i_c.factor1) <> '*LOCK';
      l_reason = 'Factor 1 of ' + i_rule.opcode + ' must be *LOCK or blank';
    when l_name <> '*NAMVAR' and not IsDataAreaName(l_name);
      l_reason = i_c.factor2 + ' is not defined as a data area by a DEFN *NAMVAR';
  endsl;
  if l_reason = '' and Up(i_c.factor1) = '*LOCK' and l_name <> '*NAMVAR';
    for l_index = 1 to g_dtCount;
      if g_dtName(l_index) = l_name
         and (g_dtExt(l_index) = C_QUOTE + '*LDA' + C_QUOTE
              or g_dtExt(l_index) = C_QUOTE + '*PDA' + C_QUOTE);
        l_reason = '*LOCK is not allowed for the local data area or the PIP data '
                   + 'area';
      endif;
    endfor;
  endif;
  if l_reason = '' and i_c.result2 <> '  ';
    l_reason = IndicatorName(i_c.result2:l_ind);
    l_ext = '(e)';
  endif;
  if l_reason <> '';
    ReviewHere(i_c.line:i_c.lineNo:l_reason);
    return;
  endif;

  l_stmt = %xlate(C_UPPER:C_LOWER:i_rule.opcode) + l_ext;
  if Up(i_c.factor1) = '*LOCK';
    l_stmt += ' *lock';
  endif;
  if l_name = '*NAMVAR';
    l_stmt += ' *dtaara';
  else;
    l_stmt += ' ' + i_c.factor2;
  endif;
  l_statements(1) = l_stmt;
  if l_ind <> '';
    l_count = 2;
    l_statements(2) = l_ind + ' = %error';
  endif;
  EmitStatements(i_c:i_rule:l_statements:l_count:'');
end-proc;

// ------------------------------------------------------------------
// OCUR (RPG/400 reference, OCUR): factor 2 is a multiple-occurrence data
// structure. Factor 1 sets the current occurrence, the result field receives it.
// Free-form: %OCCUR(ds) = factor 1; and result = %OCCUR(ds);. The error
// indicator (occurrence out of range) is not converted. Factor 1 that names a
// data structure is not converted either.
dcl-proc ConvertOcur;
  dcl-pi *n;
    i_c likeds(Calc_t) const;
    i_rule likeds(IAfreeOpc_t) const;
  end-pi;

  dcl-s l_ds varchar(30);
  dcl-s l_reason varchar(190) inz('');
  dcl-s l_statements varchar(250) dim(C_MAXSTMT);
  dcl-s l_count int(10) inz(0);

  l_ds = Up(i_c.factor2);
  select;
    when i_c.result1 <> '  ' or i_c.result2 <> '  ' or i_c.result3 <> '  ';
      l_reason = 'The error indicator of OCUR (occurrence out of range) is not '
                 + 'converted: use MONITOR with the %OCCUR assignment';
    when i_c.halfAdjust <> ' ';
      l_reason = 'Operation extender ' + i_c.halfAdjust + ' is not allowed for OCUR';
    when not CvtIsOccursDs(l_ds);
      l_reason = i_c.factor2 + ' is not a data structure with a number of '
                 + 'occurrences (columns 44-47 of the data structure line)';
    when i_c.factor1 = '' and i_c.result = '';
      l_reason = 'OCUR needs factor 1 or a result field';
    when i_c.factor1 <> '' and CvtIsOccursDs(Up(i_c.factor1));
      l_reason = 'Factor 1 is a data structure: setting the occurrence from '
                 + 'another data structure is not converted';
    when i_c.result <> '' and i_c.decimals <> ' ' and i_c.decimals <> '0';
      l_reason = 'The result field of OCUR must have no decimal positions';
  endsl;
  if l_reason = '' and i_c.result <> '';
    l_reason = DeclareResult(i_c.result:i_c.length:i_c.decimals:*on);
  endif;
  if l_reason <> '';
    ReviewHere(i_c.line:i_c.lineNo:l_reason);
    return;
  endif;

  if i_c.factor1 <> '';
    l_count += 1;
    l_statements(l_count) = '%occur(' + i_c.factor2 + ') = ' + i_c.factor1;
  endif;
  if i_c.result <> '';
    l_count += 1;
    l_statements(l_count) = i_c.result + ' = %occur(' + i_c.factor2 + ')';
  endif;
  EmitStatements(i_c:i_rule:l_statements:l_count:'');
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
      ConvertNamvar(i_c);
      return;
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
    l_note = 'A table: the entry found is kept in an index field NAME_IDX, '
             + 'which the references to the table name use';
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
  CycScan(l_up);
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
  dcl-s l_copy varchar(250) inz('');
  dcl-s l_back varchar(250) inz('');
  dcl-s l_formatFile varchar(8) inz('');
  dcl-s l_reason varchar(190) inz('');
  dcl-s l_note varchar(190) inz('');
  dcl-s l_slot int(10);
  dcl-s l_isArea ind inz(*off);
  dcl-s l_devOp ind inz(*off);
  dcl-s l_wsFile varchar(8) inz('');
  dcl-s l_wsFormat ind inz(*off);
  dcl-s l_test varchar(250);
  dcl-s l_code varchar(4);
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
    when l_op = 'EXFMT';
      l_free = 'exfmt';
    when l_op = 'READC';
      l_free = 'readc';
    // FREE-71 (RV-12): the operations of a multiple device WORKSTN file.
    when l_op = 'ACQ';
      l_free = 'acq';
    when l_op = 'REL';
      l_free = 'rel';
    when l_op = 'NEXT';
      l_free = 'next';
    when l_op = 'POST';
      l_free = 'post';
    other;
      l_reason = l_op + ' is not converted';
  endsl;
  l_devOp = (l_op = 'ACQ' or l_op = 'REL' or l_op = 'NEXT' or l_op = 'POST');
  l_keyOp = (l_op = 'CHAIN' or l_op = 'READE' or l_op = 'REDPE' or l_op = 'SETLL'
             or l_op = 'SETGT' or l_op = 'DELET');
  l_dsOp = (l_op = 'CHAIN' or l_op = 'READ' or l_op = 'READE' or l_op = 'READP'
            or l_op = 'REDPE' or l_op = 'UPDAT' or l_op = 'WRITE');

  // The file (COMIT and ROLBK name none; UNLCK can name a data area).
  l_isArea = (l_op = 'UNLCK' and IsDataAreaName(Up(i_c.factor2)));
  if l_reason = '' and l_op <> 'COMIT' and l_op <> 'ROLBK' and not l_isArea;
    l_name = %trim(%xlate(C_LOWER:C_UPPER:i_c.factor2));
    // WRITE and UPDAT of an externally described file name a record format
    // (record line of the I specifications): the file of the format is used.
    if l_op = 'WRITE' or l_op = 'UPDAT';
      l_formatFile = FormatFile(l_name);
      if l_formatFile <> '';
        l_name = l_formatFile;
      endif;
    endif;
    l_wsFile = WorkstnFile();
    if not FileInfo(l_name:l_device:l_type:l_recDs:l_keyed);
      // A record format of the display file (RV-12): the DDS is not read.
      if l_wsFile <> '' and l_wsFile <> '*MANY'
         and (l_op = 'EXFMT' or l_op = 'READC' or l_op = 'WRITE' or l_op = 'UPDAT'
              or l_op = 'CHAIN' or l_op = 'READ' or l_op = 'DELET');
        l_device = 'W';
        l_wsFormat = *on;
        AddReason(l_note:'A record format is taken as a format of the '
                  + 'display file (its DDS is not read)');
      elseif l_wsFile = '*MANY' and (l_op = 'EXFMT' or l_op = 'READC');
        l_reason = 'More than one WORKSTN file: the display file of record format '
                   + l_name + ' is not known';
      else;
        l_reason = 'File ' + i_c.factor2 + ' is not declared by a converted file '
                   + 'description (a record format name is converted only when an I '
                   + 'specification names it)';
      endif;
    elseif l_device <> 'D' and l_device <> 'X' and l_device <> 'W';
      l_reason = 'File ' + l_name + ' is not a DISK file';
    elseif (l_op = 'EXFMT' or l_op = 'READC');
      l_reason = l_op + ' needs a record format of the display file, not the file '
                 + l_name;
    elseif l_devOp and l_device <> 'W';
      l_reason = l_op + ' needs a WORKSTN file, not the file ' + l_name;
    endif;
  endif;
  if l_reason = '' and l_devOp and l_op <> 'POST' and i_c.factor1 = '';
    l_reason = l_op + ' without a program device in factor 1';
  endif;
  if l_reason = '' and l_op = 'POST' and i_c.result <> '';
    l_reason = 'POST with an INFDS name in the result field is not converted: '
               + 'free-form uses the INFDS keyword of the file';
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
    if l_devOp and i_c.factor1 <> '';
      l_stmt += ' ' + i_c.factor1C;
      AddReason(l_note:l_op + ' of a multiple device WORKSTN file (program device '
                + 'in factor 1): check');
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
    // The renamed fields of an externally described file (I specifications,
    // RV-30) are copies: copied back to the external fields before the record
    // is written or updated, as the first statement (FREE-25).
    if l_device = 'X' and (l_op = 'WRITE' or l_op = 'UPDAT');
      l_back = FileRenamesBack(l_name);
    endif;
    l_count = 0;
    if l_back <> '';
      l_count += 1;
      l_statements(l_count) = l_back;
      AddReason(l_note:'The renamed fields of the file (I specification) '
                + 'are copied to the external fields before the operation');
    endif;
    l_count += 1;
    l_statements(l_count) = l_stmt;
    for l_slot = 1 to 3;
      // The end of file and no record tests of a record format name no file.
      l_test = '';
      if l_wsFormat;
        select;
          when l_slot = 1;
            l_code = i_rule.ind1;
          when l_slot = 2;
            l_code = i_rule.ind2;
          other;
            l_code = i_rule.ind3;
        endsl;
        if l_code = 'EOF';
          l_test = '%eof';
        elseif l_code = 'NR';
          l_test = 'not %found';
        endif;
      endif;
      l_reason = ResultStatement(i_c:i_rule:l_slot:l_ind:l_test);
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

  // The renamed fields of an externally described file (I specifications, RV-30)
  // are copies: set after an input operation that read a record.
  if l_device = 'X' and (l_op = 'CHAIN' or l_op = 'READ' or l_op = 'READE'
                         or l_op = 'READP' or l_op = 'REDPE');
    l_copy = FileRenames(l_name);
    if l_copy <> '';
      l_count += 1;
      if l_op = 'CHAIN';
        l_statements(l_count) = 'if %found(' + l_name + ')';
      else;
        l_statements(l_count) = 'if not %eof(' + l_name + ')';
      endif;
      l_count += 1;
      l_statements(l_count) = '  ' + l_copy;
      l_count += 1;
      l_statements(l_count) = 'endif';
      AddReason(l_note:'The renamed fields of the file (I specification) '
                + 'are copied after the operation when a record was read');
    endif;
  endif;

  // The note: a character key of a program-described file.
  if l_keyOp and l_device = 'D' and l_keyed and l_key <> '';
    if %subst(l_key:1:1) <> C_QUOTE;
      AddReason(l_note:'The key of the file is declared as a '
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
  dcl-s l_n int(10);
  dcl-s l_k int(10);

  // A statement that is not written must not leave a skip of RV-37 open at its TAG.
  if g_sqlCount > 0;
    for l_n = 1 to C_WHEN_N;
      l_k = JvFind(SqlKey(g_sqlLineNo(1):l_n));
      if l_k > 0;
        g_jvFail(l_k) = *on;
      endif;
    endfor;
  endif;
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
// WHENEVER ... GOTO of embedded SQL (RV-37). The precompiler adds a jump to the label
// after every executable SQL statement that follows the WHENEVER in the source.
// Free form has no label to jump to, so the jump is written out: after each such
// statement an IF tests SQLCODE and the planner of RV-14 decides what the IF does
// (skip the lines up to the TAG, or LEAVESR, RETURN or ITER when the TAG is the end
// of the subroutine or the program). The WHENEVER statement itself is kept as a
// comment: the precompiler would otherwise add its own jump to a label that does
// not exist any more. A jump back to an earlier TAG is not converted (no loop is
// built for it): the statement then stays, with a comment and an R in the report.
// ------------------------------------------------------------------
// The key of the jump event of an SQL statement: the line of its EXEC SQL and the
// condition (1 SQLERROR, 2 NOT FOUND, 3 SQLWARNING) as a negative number, so it can
// not be the number of a source line.
dcl-proc SqlKey;
  dcl-pi *n int(10);
    i_lineNo int(10) const;
    i_n int(10) const;
  end-pi;

  return 0 - (i_lineNo * 4 + i_n);
end-proc;

// ------------------------------------------------------------------
dcl-proc WhenName;
  dcl-pi *n varchar(10);
    i_n int(10) const;
  end-pi;

  select;
    when i_n = 1;
      return 'SQLERROR';
    when i_n = 2;
      return 'NOT FOUND';
  endsl;
  return 'SQLWARNING';
end-proc;

// ------------------------------------------------------------------
// The test of a condition after an SQL statement (SQL Reference: SQLCODE below 0 is
// an error, 100 is no row, SQLWARN0 = 'W' or another positive SQLCODE is a warning).
dcl-proc WhenTest;
  dcl-pi *n varchar(80);
    i_n int(10) const;
  end-pi;

  select;
    when i_n = 1;
      return 'sqlcode < 0';
    when i_n = 2;
      return 'sqlcode = 100';
  endsl;
  return 'sqlwarn0 = ''W'' or (sqlcode > 0 and sqlcode <> 100)';
end-proc;

// ------------------------------------------------------------------
// Upper case, without a comment, one blank between the words.
dcl-proc Squeeze;
  dcl-pi *n varchar(200);
    i_text varchar(200) const;
  end-pi;

  dcl-s l_t varchar(200);
  dcl-s l_p int(10);

  l_t = %trim(%xlate(C_LOWER:C_UPPER:i_text));
  l_p = %scan('  ':l_t);
  dow l_p > 0;
    l_t = %subst(l_t:1:l_p) + %triml(%subst(l_t:l_p + 1));
    l_p = %scan('  ':l_t);
  enddo;
  return l_t;
end-proc;

// ------------------------------------------------------------------
// The text from position i_from, '' when the text is shorter.
dcl-proc Tail;
  dcl-pi *n varchar(200);
    i_text varchar(200) const;
    i_from int(10) const;
  end-pi;

  if i_from > %len(i_text);
    return '';
  endif;
  return %subst(i_text:i_from);
end-proc;

// ------------------------------------------------------------------
// Adds a line of an SQL statement to its head (the first 200 positions), without
// the -- comment at its end.
dcl-proc HeadAdd;
  dcl-pi *n;
    io_head varchar(200);
    i_text varchar(100) const;
  end-pi;

  dcl-s l_text varchar(100);
  dcl-s l_p int(10);

  l_text = %trimr(i_text);
  l_p = SqlFindOutside(l_text:'--');
  if l_p = 1;
    return;
  elseif l_p > 1;
    l_text = %trimr(%subst(l_text:1:l_p - 1));
  endif;
  // The head keeps the first words only (they decide the kind of statement); it can
  // not grow past its 200 positions: room for a line of 70 after 120.
  if l_text = '' or %len(io_head) >= 120;
    return;
  endif;
  if io_head <> '';
    io_head += ' ';
  endif;
  io_head += l_text;
end-proc;

// ------------------------------------------------------------------
// 'W' for a WHENEVER, 'N' for a statement that is not executed (INCLUDE, DECLARE
// of a cursor or statement, BEGIN and END DECLARE SECTION, SET OPTION: the
// precompiler adds no jump after them), 'X' for every other statement.
dcl-proc SqlKind;
  dcl-pi *n char(1);
    i_head varchar(200) const;
  end-pi;

  dcl-s l_t varchar(200);
  dcl-s l_p int(10);
  dcl-s l_word varchar(20);

  l_t = Squeeze(i_head);
  l_p = %scan(' ':l_t);
  if l_p = 0;
    l_word = l_t;
  else;
    l_word = %subst(l_t:1:l_p - 1);
  endif;
  select;
    when l_word = 'WHENEVER';
      return 'W';
    when l_word = 'INCLUDE' or l_word = 'BEGIN' or l_word = 'END';
      return 'N';
    when l_word = 'DECLARE' and %scan('DECLARE GLOBAL ':l_t) <> 1;
      return 'N';
    when l_word = 'SET' and %scan('SET OPTION':l_t) = 1;
      return 'N';
  endsl;
  return 'X';
end-proc;

// ------------------------------------------------------------------
// WHENEVER {NOT FOUND | SQLERROR | SQLWARNING} {CONTINUE | GOTO label | GO TO label}.
// Returns *off when the statement is not of that form. o_n is the condition
// (1 SQLERROR, 2 NOT FOUND, 3 SQLWARNING), o_goto *on for GOTO.
dcl-proc WheneverParse;
  dcl-pi *n ind;
    i_text varchar(200) const;
    o_n int(10);
    o_goto ind;
    o_label varchar(14);
  end-pi;

  dcl-s l_t varchar(200);
  dcl-s l_rest varchar(200);

  o_n = 0;
  o_goto = *off;
  o_label = '';
  l_t = Squeeze(i_text);
  if %len(l_t) < 9 or %subst(l_t:1:9) <> 'WHENEVER ';
    return *off;
  endif;
  l_rest = Tail(l_t:10);
  select;
    when %len(l_rest) >= 9 and %subst(l_rest:1:9) = 'NOT FOUND';
      o_n = 2;
      l_rest = %triml(Tail(l_rest:10));
    when %len(l_rest) >= 8 and %subst(l_rest:1:8) = 'SQLERROR';
      o_n = 1;
      l_rest = %triml(Tail(l_rest:9));
    when %len(l_rest) >= 10 and %subst(l_rest:1:10) = 'SQLWARNING';
      o_n = 3;
      l_rest = %triml(Tail(l_rest:11));
    other;
      return *off;
  endsl;
  if l_rest = 'CONTINUE';
    return *on;
  endif;
  select;
    when %len(l_rest) > 5 and %subst(l_rest:1:5) = 'GOTO ';
      l_rest = %triml(Tail(l_rest:6));
    when %len(l_rest) > 6 and %subst(l_rest:1:6) = 'GO TO ';
      l_rest = %triml(Tail(l_rest:7));
    other;
      return *off;
  endsl;
  if %len(l_rest) = 0 or %len(l_rest) > 14 or not IsName(l_rest);
    return *off;
  endif;
  o_goto = *on;
  o_label = l_rest;
  return *on;
end-proc;

// ------------------------------------------------------------------
// The scan before the conversion (called for every source line, RPG III from
// CalcJumpScan, RPG IV from IAfreeFx4): follows the WHENEVER statements in source
// order and gives the planner one jump event for each executable SQL statement and
// each condition that has a label. It repeats the checks that make SqlEnd reject a
// statement (no event is made for one that is rejected).
dcl-proc CalcSqlJumpScan export;
  dcl-pi *n;
    i_line char(100) const;
    i_lineNo int(10) const;
  end-pi;

  dcl-s l_up char(100);
  dcl-s l_key char(9);

  if RulDialect() <> '3' and RulDialect() <> '4';
    return;
  endif;
  l_up = %xlate(C_LOWER:C_UPPER:i_line);
  if %subst(l_up:6:1) <> 'C' or %subst(l_up:7:1) = '*';
    return;
  endif;
  l_key = %subst(l_up:7:9);
  select;
    when l_key = '/EXEC SQL';
      g_ssOpen = *on;
      g_ssLines = 0;
      g_ssFirstNo = i_lineNo;
      g_ssHead = '';
      g_ssHasText = *off;
      // Lines of indicators before it make the conversion reject it.
      g_ssBlocked = g_jvPending;
      g_jvPending = *off;
      SqlScanText(%trim(%subst(i_line:16:59)));
    when l_key = '/END-EXEC';
      if g_ssOpen;
        SqlScanEnd();
      endif;
    when %subst(i_line:7:1) = '+';
      if g_ssOpen;
        SqlScanText(%trim(%subst(i_line:8:67)));
      endif;
    other;
      // Any other specification ends a statement that was not closed.
      g_ssOpen = *off;
  endsl;
end-proc;

// ------------------------------------------------------------------
dcl-proc SqlScanText;
  dcl-pi *n;
    i_text varchar(70) const;
  end-pi;

  g_ssLines += 1;
  if g_ssLines > C_MAXSQL;
    g_ssBlocked = *on;
  endif;
  if i_text <> '';
    g_ssHasText = *on;
    if SqlFindOutside(i_text:';') > 0;
      g_ssBlocked = *on;
    endif;
    HeadAdd(g_ssHead:i_text);
  endif;
end-proc;

// ------------------------------------------------------------------
dcl-proc SqlScanEnd;
  dcl-pi *n;
  end-pi;

  dcl-s l_n int(10);
  dcl-s l_goto ind;
  dcl-s l_label varchar(14);

  g_ssOpen = *off;
  if g_ssBlocked or not g_ssHasText;
    return;
  endif;
  select;
    when SqlKind(g_ssHead) = 'W';
      if WheneverParse(g_ssHead:l_n:l_goto:l_label);
        g_wnBad(l_n) = *off;
        if l_goto;
          g_wnLabel(l_n) = l_label;
        else;
          g_wnLabel(l_n) = '';
        endif;
      else;
        // Not understood: no condition is known any more, every statement after it
        // gets a note instead of a test.
        for l_n = 1 to C_WHEN_N;
          g_wnLabel(l_n) = '?';
          g_wnBad(l_n) = *on;
        endfor;
      endif;
    when SqlKind(g_ssHead) = 'X';
      // Every executable statement is an event, also when no WHENEVER is active:
      // a TAG is the last statement of a subroutine or program only when no SQL
      // statement (cleanup, ROLLBACK) follows it either.
      SqlJumpEvent(0);
      for l_n = 1 to C_WHEN_N;
        if g_wnLabel(l_n) <> '';
          SqlJumpEvent(l_n);
        endif;
      endfor;
  endsl;
end-proc;

// ------------------------------------------------------------------
dcl-proc SqlJumpEvent;
  dcl-pi *n;
    i_n int(10) const;
  end-pi;

  // i_n = 0: the statement itself (kind X, no jump), 1 to 3: a condition with a label.
  // A full table: the tests of a condition are lost, so no jump of the source is
  // converted; a plain statement only stops the jumps to the end (the planner can
  // not know that nothing follows the TAG), see SqlJumpWrite.
  if g_jvCount >= C_MAXJV;
    if i_n > 0;
      g_jvUnsafe = *on;
    endif;
    g_ssOver = *on;
    return;
  endif;
  g_jvCount += 1;
  g_jvLineNo(g_jvCount) = SqlKey(g_ssFirstNo:i_n);
  g_jvLine(g_jvCount) = '';
  if i_n = 0;
    g_jvKind(g_jvCount) = 'X';
    g_jvLabel(g_jvCount) = '';
    g_jvBad(g_jvCount) = *off;
  else;
    g_jvKind(g_jvCount) = 'G';
    g_jvLabel(g_jvCount) = g_wnLabel(i_n);
    g_jvBad(g_jvCount) = g_wnBad(i_n);
  endif;
  g_jvCondF(g_jvCount) = *on;
  g_jvGroupF(g_jvCount) = *off;
  g_jvDepth(g_jvCount) = 0;
  g_jvBody(g_jvCount) = 0;
  g_jvAct(g_jvCount) = ' ';
  g_jvPeer(g_jvCount) = 0;
  g_jvCond(g_jvCount) = '';
  g_jvLoopAt(g_jvCount) = *off;
  g_jvFail(g_jvCount) = *off;
  g_jvUnconv(g_jvCount) = 0;
  g_jvPre(g_jvCount) = *on;
  if i_n = 0;
    g_jvCondPre(g_jvCount) = '';
  else;
    g_jvCondPre(g_jvCount) = WhenTest(i_n);
  endif;
  g_jvSql(g_jvCount) = *on;
end-proc;

// ------------------------------------------------------------------
// Writes what the plan decided for one condition after an SQL statement that has
// just been written. Returns *off when nothing could be written (a comment is
// written instead and the note says why).
dcl-proc SqlJumpWrite;
  dcl-pi *n ind;
    i_lineNo int(10) const;
    i_n int(10) const;
    i_outNo int(10) const;
    io_note varchar(190);
  end-pi;

  dcl-s l_key int(10);
  dcl-s l_k int(10);
  dcl-s l_kind char(1);
  dcl-s l_act char(1);
  dcl-s l_label varchar(14);
  dcl-s l_cond varchar(300);
  dcl-s l_inSub ind;
  dcl-s l_loop ind;
  dcl-s l_loopCond varchar(300);
  dcl-s l_kEnds int(10);
  dcl-s l_unconv int(10);
  dcl-s l_word varchar(10);
  dcl-s l_what varchar(60);
  dcl-s l_room ind;

  l_key = SqlKey(i_lineNo:i_n);
  l_k = JvFind(l_key);
  if l_k = 0;
    // No event: the table was full (g_ssOver) or the source has no event for this
    // statement. A condition that is in force must not be dropped without a word.
    if g_wnLabel(i_n) <> '' and g_ssOver;
      Emit('// WHENEVER ' + WhenName(i_n) + ' GOTO ' + g_wnLabel(i_n)
           + ' is not converted: test SQLCODE here':i_outNo);
      AddReason(io_note:'WHENEVER ' + WhenName(i_n) + ' GOTO is not converted '
                + '(RV-37): too many jumps and SQL statements in the source');
      return *off;
    endif;
    return *on;
  endif;
  // A WHENEVER that was not understood: one comment for all three conditions.
  if g_jvBad(l_k);
    if i_n = 1;
      Emit('// A WHENEVER before this statement is not understood: test SQLCODE '
           + 'here':i_outNo);
      AddReason(io_note:'A WHENEVER before this statement is not understood '
                + '(RV-37): test SQLCODE by hand');
      return *off;
    endif;
    return *on;
  endif;
  l_what = 'WHENEVER ' + WhenName(i_n) + ' GOTO ' + g_jvLabel(l_k);
  if not JumpInfo(l_key:l_kind:l_act:l_label:l_cond:l_inSub:l_loop:l_loopCond
                  :l_kEnds:l_unconv)
     or (l_act <> 'K' and l_act <> 'R')
     or (l_act = 'R' and g_ssOver);
    Emit('// ' + l_what + ' is not converted: test SQLCODE here':i_outNo);
    AddReason(io_note:l_what + ' is not converted (RV-37): TAG is missing, before '
              + 'the statement, or not in a pattern that can be written');
    return *off;
  endif;

  if l_act = 'K';
    // Room first: when the group cannot be opened nothing may be written, or the IF
    // would have no ENDIF. The IF is written before the group is opened, so it
    // stands at the depth of the statement.
    l_room = (g_stackCount < C_MAXSTACK);
    if RulDialect() = '4';
      l_room = Fx4SkipOpen(*off);
    endif;
    if not l_room;
      g_jvFail(l_k) = *on;
      Emit('// ' + l_what + ' is not converted: groups nested too deep':i_outNo);
      AddReason(io_note:l_what + ' is not converted (RV-37): groups nested too '
                + 'deep');
      return *off;
    endif;
    Emit('if ' + Negate(l_cond) + ';':i_outNo);
    if RulDialect() = '4';
      Fx4SkipOpen(*on);
    else;
      Push('JMP':1:0:'');
    endif;
    AddReason(io_note:'WHENEVER ... GOTO became an IF around the lines up to '
              + 'the TAG');
    return *on;
  endif;

  if l_inSub;
    l_word = 'leavesr';
    AddReason(io_note:'WHENEVER ... GOTO became a LEAVESR (the TAG is the last '
              + 'statement of the subroutine)');
  elseif RulDialect() = '3' and g_cycState = 'D';
    l_word = 'iter';
    AddReason(io_note:'WHENEVER ... GOTO became an ITER (the TAG is the last '
              + 'statement of the detail calculations)');
  else;
    l_word = 'return';
    AddReason(io_note:'WHENEVER ... GOTO became a RETURN (the TAG is the last '
              + 'statement of the program)');
  endif;
  Emit('if ' + l_cond + ';':i_outNo);
  Emit(l_word + ';':i_outNo:1);
  Emit('endif;':i_outNo);
  return *on;
end-proc;

// ------------------------------------------------------------------
// A WHENEVER that is understood: kept as a comment, the tests of SQLCODE written
// after the following statements take its place.
dcl-proc SqlWhenever;
  dcl-pi *n;
    i_first int(10) const;
    i_last int(10) const;
    i_n int(10) const;
    i_goto ind const;
    i_label varchar(14) const;
    i_line char(100) const;
    i_lineNo int(10) const;
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_note varchar(190);

  for l_index = i_first to i_last;
    if g_sqlText(l_index) = '';
      iter;
    endif;
    if l_index = i_first;
      Emit('// exec sql ' + g_sqlText(l_index):g_sqlLineNo(l_index));
    else;
      Emit('//   ' + g_sqlText(l_index):g_sqlLineNo(l_index));
    endif;
  endfor;
  if i_goto;
    l_note = 'WHENEVER ... GOTO is replaced by a test of SQLCODE after each SQL '
             + 'statement that follows (RV-37)';
  else;
    l_note = 'WHENEVER ... CONTINUE: no test of SQLCODE for this condition in '
             + 'the statements that follow (RV-37)';
  endif;
  for l_index = 1 to g_sqlCount;
    if l_index = 1;
      RptItem(C_STS_ASSUMPTION:g_sqlLineNo(1):SpecText(g_sqlRaw(1)):l_note);
    else;
      RptItem(C_STS_CONVERTED:g_sqlLineNo(l_index):SpecText(g_sqlRaw(l_index)):'');
    endif;
  endfor;
  RptItem(C_STS_CONVERTED:i_lineNo:SpecText(i_line):'');
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
  dcl-s l_head varchar(200) inz('');
  dcl-s l_kind char(1);
  dcl-s l_n int(10);
  dcl-s l_wgoto ind;
  dcl-s l_wlabel varchar(14);
  dcl-s l_jumpBad ind inz(*off);
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
      l_reason = 'Conditioning indicators cannot be used with EXEC SQL (the '
                 + 'delimiter fills columns 7-15): put it in an IFxx group';
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

  // WHENEVER (RV-37): a WHENEVER that is understood is kept as a comment, the tests
  // of SQLCODE after the statements that follow take its place.
  for l_index = l_first to l_last;
    HeadAdd(l_head:g_sqlText(l_index));
  endfor;
  l_kind = SqlKind(l_head);
  if l_kind = 'W' and WheneverParse(l_head:l_n:l_wgoto:l_wlabel);
    g_hdrIndex = 0;
    SqlWhenever(l_first:l_last:l_n:l_wgoto:l_wlabel:i_line:i_lineNo);
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

  // A WHENEVER that is not of the form WHENEVER condition CONTINUE or GOTO label
  // stays as written (it is still in force for the precompiler) and is reported.
  if l_kind = 'W';
    AddReason(l_note:'WHENEVER is not understood and kept as written: a GOTO to a '
              + 'label of the RPG source does not exist in free form (RV-37)');
    l_jumpBad = *on;
  endif;

  // The tests of SQLCODE for the WHENEVER ... GOTO that are in force (RV-37).
  if l_kind = 'X';
    for l_n = 1 to C_WHEN_N;
      if not SqlJumpWrite(g_sqlLineNo(1):l_n:g_sqlLineNo(l_last):l_note);
        l_jumpBad = *on;
      endif;
    endfor;
  endif;

  // The report: each line of the source is converted; the notes go on the first.
  l_status = C_STS_CONVERTED;
  if l_note <> '';
    l_status = C_STS_ASSUMPTION;
  endif;
  if l_jumpBad;
    l_status = C_STS_REVIEW;
  endif;
  if not g_inSub and not g_cycleNoted;
    g_cycleNoted = *on;
    if l_status <> C_STS_REVIEW;
      l_status = C_STS_ASSUMPTION;
    endif;
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
// FREE-36, RPG cycle skeleton (SC09-1818 chapter 1, the program cycle). For a
// program with one program-described primary file the loop is written as
//   dow *on;  [output of the previous record: not part of it yet]
//     if *inlr; leave; endif;  control levels off;  read FILE IA_NEXT;
//     if %eof(FILE); *inlr = *on; leave; endif;
//     control break (IA_NEXT against the record), total calculations unless it is
//     the first record, FILE_REC = IA_NEXT, the detail calculations;
//   enddo;  *inlr = *on; all control levels on; total calculations.
// The total calculations (control level in columns 7-8) are the subroutine
// IA_TOTALS, called for a break and after the loop. The new record is read into
// IA_NEXT so the total calculations still see the fields of the previous record.
dcl-proc CycScan;
  dcl-pi *n;
    i_up char(100) const;
  end-pi;

  dcl-s l_level char(2);
  dcl-s l_slot int(10);
  dcl-s l_n int(10);

  l_level = Fld(i_up:'LEVEL');
  if l_level = 'LR' or (%subst(l_level:1:1) = 'L'
     and %check('0123456789':%subst(l_level:2:1)) = 0);
    g_cycHasTotals = *on;
  endif;
  l_n = LevelOf(l_level);
  if l_n > g_cycPreMax;
    g_cycPreMax = l_n;
  endif;
  for l_slot = 1 to 3;
    l_n = LevelOf(Fld(i_up:'IND' + %char(l_slot)));
    if l_n > g_cycPreMax;
      g_cycPreMax = l_n;
    endif;
    // FREE-49: RT as conditioning or resulting indicator.
    if Fld(i_up:'IND' + %char(l_slot)) = 'RT' or Fld(i_up:'RES' + %char(l_slot)) = 'RT';
      g_cycUsesRt = *on;
    endif;
  endfor;
end-proc;

// ------------------------------------------------------------------
// FREE-60: the prescan of the cycle skeleton for an RPG IV C specification (levels in
// columns 7-8, RT as conditioning indicator or in the result indicator columns 71-76).
dcl-proc CalcCycleScan export;
  dcl-pi *n;
    i_line char(100) const;
  end-pi;

  dcl-s l_up char(100);

  l_up = %xlate(C_LOWER:C_UPPER:i_line);
  if %subst(l_up:6:1) <> 'C' or %subst(l_up:7:1) = '*' or %subst(l_up:7:1) = '/'
     or %subst(l_up:7:1) = '+';
    return;
  endif;
  CycScan(l_up);
  if Fld(l_up:'HI') = 'RT' or Fld(l_up:'LO') = 'RT' or Fld(l_up:'EQ') = 'RT';
    g_cycUsesRt = *on;
  endif;
end-proc;

// ------------------------------------------------------------------
// FREE-60: called by IAfreeFx4 before an RPG IV C specification is converted: opens
// and closes the parts of the cycle skeleton as CalcLine does for RPG II and III. The
// operations that only declare (KLIST, KFLD, PLIST, PARM, DEFINE) leave the
// skeleton as it is, so their declarations stay before the loop.
dcl-proc CalcCycleBefore export;
  dcl-pi *n;
    i_line char(100) const;
    i_lineNo int(10) const;
  end-pi;

  dcl-s l_up char(100);
  dcl-s l_op varchar(10);

  l_up = %xlate(C_LOWER:C_UPPER:i_line);
  g_lastLineNo = i_lineNo;
  if %trim(%subst(l_up:7:74)) = '' or %subst(l_up:7:1) = '*'
     or %subst(l_up:7:1) = '/' or %subst(l_up:7:1) = '+';
    return;
  endif;
  l_op = %trim(Fld(l_up:'OPERATION'));
  if l_op = 'KLIST' or l_op = 'KFLD' or l_op = 'PLIST' or l_op = 'PARM'
     or l_op = 'DEFN' or l_op = 'DEFINE';
    return;
  endif;
  if g_declAt = 0;
    AddOut('':i_lineNo);
    g_declAt = OutCount();
  endif;
  CycBefore(l_up:i_lineNo);
end-proc;

// ------------------------------------------------------------------
// The control level 1 to 9 of an indicator name such as L2, else 0 (L0, LR, 01).
dcl-proc LevelOf;
  dcl-pi *n int(10);
    i_name char(2) const;
  end-pi;

  if %subst(i_name:1:1) <> 'L';
    return 0;
  endif;
  if %check('123456789':%subst(i_name:2:1)) > 0;
    return 0;
  endif;
  return %int(%subst(i_name:2:1));
end-proc;

// ------------------------------------------------------------------
dcl-proc CycTotalLevel;
  dcl-pi *n ind;
    i_level char(2) const;
  end-pi;

  return g_cycState <> ' '
         and (i_level = 'LR' or (%subst(i_level:1:1) = 'L'
              and %check('0123456789':%subst(i_level:2:1)) = 0));
end-proc;

// ------------------------------------------------------------------
// Decides once whether the skeleton is written: there must be a primary file with a
// record layout.
dcl-proc CycInit;
  dcl-pi *n;
  end-pi;

  dcl-s l_count int(10);
  dcl-s l_k int(10);
  dcl-s l_name varchar(6);
  dcl-s l_level int(10);

  g_cycChecked = *on;
  if not CycleInfo(g_cycFile:g_cycRec:l_count);
    // RV-60: no primary file at all, with heading, detail or total records: one
    // cycle after the other without a read, until the program sets LR on.
    if g_cycFile = '' and CycleNoPrimary();
      g_cycNoPrim = *on;
      g_cycMax = g_cycPreMax;
      g_cycState = 'P';
      if OutCycleCount('T') > 0;
        g_cycHasTotals = *on;
      endif;
    endif;
    return;
  endif;
  g_cycMax = g_cycPreMax;
  for l_k = 1 to l_count;
    if CycleControl(l_k:l_name:l_level) and l_level > g_cycMax;
      g_cycMax = l_level;
    endif;
  endfor;
  g_cycState = 'P';
  // Total records of the O specifications are written at the end of IA_TOTALS
  // (RV-60), so the subroutine exists for them.
  if OutCycleCount('T') > 0;
    g_cycHasTotals = *on;
  endif;
end-proc;

// ------------------------------------------------------------------
// *ON when the cycle skeleton is written (see IAfreeOut: heading, detail and total
// records need it).
dcl-proc CalcCycleActive export;
  dcl-pi *n ind;
  end-pi;

  if not g_cycChecked;
    CycInit();
  endif;
  return g_cycState <> ' ';
end-proc;

// ------------------------------------------------------------------
// The records of the O specifications the skeleton writes: part S at the start of
// the cycle (step 1, heading and detail), part T at the end of IA_TOTALS.
// FREE-68: the overflow indicators (OA to OG, OV) that condition records of one part of
// the cycle output, written as 'oa,ov' (not with N), and the number of the last record
// that uses one. In the RPG cycle the overflow lines are written (total lines, then
// heading and detail lines) and the overflow indicator is set off (SC09-1818, Handling
// Overflow, step 5); the printer file only sets it on.
dcl-proc CycOverflowList;
  dcl-pi *n varchar(40);
    i_part char(1) const;
    o_last int(10);
  end-pi;

  dcl-s l_names varchar(16) inz('oaobocodoeofogov');
  dcl-s l_list varchar(40) inz('');
  dcl-s l_cond varchar(200);
  dcl-s l_name varchar(2);
  dcl-s l_k int(10);
  dcl-s l_i int(10);
  dcl-s l_p int(10);

  o_last = 0;
  for l_k = 1 to OutCycleCount(i_part);
    if OutCycleDisk(i_part:l_k);
      iter;
    endif;
    l_cond = OutCycleCond(i_part:l_k);
    for l_i = 1 to 8;
      l_name = %subst(l_names:l_i * 2 - 1:2);
      l_p = %scan('*in' + l_name:l_cond);
      if l_p > 0 and not (l_p > 4 and %subst(l_cond:l_p - 4:4) = 'not ');
        if %scan(l_name:l_list) = 0;
          if l_list <> '';
            l_list += ',';
          endif;
          l_list += l_name;
        endif;
        o_last = l_k;
      endif;
    endfor;
  endfor;
  return l_list;
end-proc;

// ------------------------------------------------------------------
dcl-proc CycOutput;
  dcl-pi *n;
    i_part char(1) const;
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_count int(10);
  dcl-s l_cond varchar(200);
  dcl-s l_format varchar(10);
  dcl-s l_after varchar(120);
  dcl-s l_before varchar(250);
  dcl-s l_j int(10);
  dcl-s l_n int(10);
  dcl-s l_reason varchar(190);
  dcl-s l_stmts varchar(250) dim(40);
  dcl-s l_ovf varchar(40);
  dcl-s l_ovfLast int(10);
  dcl-s l_ovfOther int(10);
  dcl-s l_x int(10);

  // FREE-68: the overflow indicator is set off after the last record of the heading
  // and detail part that it conditions, and after the last total record only when no
  // heading or detail record uses it (both are printed before it is set off).
  l_ovf = CycOverflowList(i_part:l_ovfLast);
  if i_part = 'T' and CycOverflowList('S':l_ovfOther) <> '';
    l_ovf = '';
  endif;

  l_count = OutCycleCount(i_part);
  for l_k = 1 to l_count;
    // FREE-54: a record of a program described DISK file is written with the
    // statements of IAfreeOut (FILE_OUT = *blanks, %subst assignments, write).
    if OutCycleDisk(i_part:l_k);
      l_n = OutCycleStatements(i_part:l_k:l_stmts:l_reason);
      if l_n = 0;
        Emit('// output record of a DISK file not converted: ' + l_reason
             :g_lastLineNo);
        RptItem(C_STS_REVIEW:g_lastLineNo:'Cycle skeleton':'Output record of a DISK '
                + 'file is not written: ' + l_reason);
      else;
        CalcRecordDs(OutCycleFile(i_part:l_k));
        for l_j = 1 to l_n;
          Emit(l_stmts(l_j) + ';':g_lastLineNo);
        endfor;
      endif;
      iter;
    endif;
    l_cond = OutCycleCond(i_part:l_k);
    l_format = OutCycleFormat(i_part:l_k);
    l_after = OutCycleAfter(i_part:l_k);
    if l_after <> '';
      l_after = '; ' + l_after;
    endif;
    l_before = OutCycleBefore(i_part:l_k);
    if l_before <> '';
      l_before += '; ';
    endif;
    if l_cond = '';
      Emit(l_before + 'write ' + l_format + l_after + ';':g_lastLineNo);
    else;
      Emit('if ' + l_cond + ';':g_lastLineNo);
      Emit(l_before + 'write ' + l_format + l_after + ';':g_lastLineNo:1);
      Emit('endif;':g_lastLineNo);
    endif;
    if l_ovf <> '' and l_k = l_ovfLast;
      for l_x = 1 to %len(l_ovf);
        if %subst(l_ovf:l_x:1) <> ',' and (l_x = 1 or %subst(l_ovf:l_x - 1:1) = ',');
          Emit('*in' + %subst(l_ovf:l_x:2) + ' = *off;':g_lastLineNo);
        endif;
      endfor;
    endif;
  endfor;
end-proc;

// ------------------------------------------------------------------
// Called before every calculation line: opens and closes the parts of the skeleton.
dcl-proc CycBefore;
  dcl-pi *n;
    i_up char(100) const;
    i_lineNo int(10) const;
  end-pi;

  dcl-s l_level char(2);
  dcl-s l_op varchar(5);

  if not g_cycChecked;
    CycInit();
  endif;
  if g_cycState = ' ' or g_cycState = 'E';
    return;
  endif;
  l_level = Fld(i_up:'LEVEL');
  l_op = %trim(Fld(i_up:'OPERATION'));
  select;
    when l_op = 'BEGSR';
      CycClose();
    when CycTotalLevel(l_level);
      if g_cycState = 'P';
        CycOpen();
      endif;
      if g_cycState = 'D';
        CycCloseLoop();
        CycBeginTotals();
      endif;
    when l_level = 'AN' or l_level = 'OR';
    other;
      if g_cycState = 'P';
        CycOpen();
      elseif g_cycState = 'T';
        CycEndTotals();
      endif;
  endsl;
end-proc;

// ------------------------------------------------------------------
// FREE-49: the record types of the primary file. The record just read (IA_NEXT)
// decides the record type; the record identifying indicator of that type is set and
// those of the other types are off. A record that matches no type halts the RPG
// cycle; that is not converted (marked in the code).
dcl-proc CycTypeTest;
  dcl-pi *n;
  end-pi;

  dcl-s l_n int(10);
  dcl-s l_k int(10);
  dcl-s l_cond varchar(200);
  dcl-s l_ind char(2);
  dcl-s l_other ind inz(*off);

  l_n = CycleTypeCount();
  if l_n = 0;
    return;
  endif;
  Emit('// record identifying codes: the record just read decides the record type '
       + '(FREE-49)':g_lastLineNo);
  for l_k = 1 to l_n;
    if CycleType(l_k:l_cond:l_ind) and l_ind <> '  ';
      Emit('*in' + l_ind + ' = *off;':g_lastLineNo);
    endif;
  endfor;
  Emit('select;':g_lastLineNo);
  g_depth += 1;
  for l_k = 1 to l_n;
    if CycleType(l_k:l_cond:l_ind);
      if l_cond = '';
        Emit('other;':g_lastLineNo);
        l_other = *on;
      else;
        Emit('when ' + l_cond + ';':g_lastLineNo);
      endif;
      if l_ind <> '  ';
        Emit('*in' + l_ind + ' = *on;':g_lastLineNo:1);
      endif;
    endif;
  endfor;
  if not l_other;
    Emit('other;':g_lastLineNo);
    Emit('// no record identification code matches: the RPG cycle halts here (not '
         + 'converted)':g_lastLineNo:1);
  endif;
  g_depth -= 1;
  Emit('endsl;':g_lastLineNo);
end-proc;

// ------------------------------------------------------------------
// FREE-49: the control fields of a primary file with record types are compared with
// the value of the last record of their own type (IA_P_name), because the fields
// of the record of another type hold other bytes. Declares them and keeps them.
dcl-proc CycKeepControl;
  dcl-pi *n;
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_count int(10);
  dcl-s l_name varchar(6);
  dcl-s l_level int(10);
  dcl-s l_type int(10);
  dcl-s l_cond varchar(200);
  dcl-s l_ind char(2);
  dcl-s l_file varchar(8);
  dcl-s l_rec varchar(12);

  if CycleTypeCount() = 0 or not CycleInfo(l_file:l_rec:l_count);
    return;
  endif;
  for l_k = 1 to l_count;
    if CycleControl(l_k:l_name:l_level);
      l_type = CycleControlType(l_k);
      DeclareHidden('IA_P_' + l_name:'like(' + l_name + ')');
      if l_type > 0 and CycleType(l_type:l_cond:l_ind) and l_cond <> '';
        Emit('if ' + l_cond + ';':g_lastLineNo);
        Emit('IA_P_' + l_name + ' = IA_NEXT.' + l_name + ';':g_lastLineNo:1);
        Emit('endif;':g_lastLineNo);
      else;
        Emit('IA_P_' + l_name + ' = IA_NEXT.' + l_name + ';':g_lastLineNo);
      endif;
    endif;
  endfor;
end-proc;

// ------------------------------------------------------------------
dcl-proc CycBreakTest;
  dcl-pi *n;
  end-pi;

  dcl-s l_lvl int(10);
  dcl-s l_k int(10);
  dcl-s l_count int(10);
  dcl-s l_name varchar(6);
  dcl-s l_level int(10);
  dcl-s l_cond varchar(300);
  dcl-s l_found ind;
  dcl-s l_file varchar(8);
  dcl-s l_rec varchar(12);
  dcl-s l_type int(10);
  dcl-s l_tcond varchar(200);
  dcl-s l_tind char(2);
  dcl-s l_typed ind;
  dcl-s l_term varchar(190);

  if not CycleInfo(l_file:l_rec:l_count) or l_count = 0;
    return;
  endif;
  l_typed = (CycleTypeCount() > 0);
  Emit('if IA_FIRST;':g_lastLineNo);
  g_depth += 1;
  Emit('// the first record: a control break of every control level':g_lastLineNo);
  CycLevels(*on:g_cycMax);
  g_depth -= 1;
  Emit('else;':g_lastLineNo);
  g_depth += 1;
  Emit('select;':g_lastLineNo);
  g_depth += 1;
  for l_lvl = g_cycMax downto 1;
    l_cond = '';
    l_found = *off;
    for l_k = 1 to l_count;
      if CycleControl(l_k:l_name:l_level) and l_level = l_lvl;
        if l_typed;
          // FREE-49: only a record of the type that has the field is compared,
          // with the value of the last record of that type.
          l_type = CycleControlType(l_k);
          l_term = 'IA_NEXT.' + l_name + ' <> IA_P_' + l_name;
          if l_type > 0 and CycleType(l_type:l_tcond:l_tind) and l_tcond <> '';
            l_term = '(' + l_tcond + ') and ' + l_term;
          endif;
          if %len(l_term) > 176;
            RptItem(C_STS_REVIEW:g_lastLineNo:'Control field ' + l_name
                    :'The record identification codes are too long for the control '
                     + 'break test');
          else;
            Emit('when ' + l_term + ';':g_lastLineNo);
            g_depth += 1;
            CycLevels(*on:l_lvl);
            g_depth -= 1;
          endif;
        else;
          l_found = *on;
          if l_cond <> '';
            l_cond += ' or ';
          endif;
          l_cond += 'IA_NEXT.' + l_name + ' <> ' + l_name;
        endif;
      endif;
    endfor;
    if l_found;
      Emit('when ' + l_cond + ';':g_lastLineNo);
      g_depth += 1;
      CycLevels(*on:l_lvl);
      g_depth -= 1;
    endif;
  endfor;
  g_depth -= 1;
  Emit('endsl;':g_lastLineNo);
  g_depth -= 1;
  Emit('endif;':g_lastLineNo);
  CycKeepControl();
end-proc;

// ------------------------------------------------------------------
// *INL1 to *INLn on or off, one statement each.
dcl-proc CycLevels;
  dcl-pi *n;
    i_on ind const;
    i_upTo int(10) const;
  end-pi;

  dcl-s l_lvl int(10);

  for l_lvl = 1 to i_upTo;
    if i_on;
      Emit('*inl' + %char(l_lvl) + ' = *on;':g_lastLineNo);
    else;
      Emit('*inl' + %char(l_lvl) + ' = *off;':g_lastLineNo);
    endif;
  endfor;
end-proc;

// ------------------------------------------------------------------
dcl-proc CycOpen;
  dcl-pi *n;
  end-pi;

  if g_declAt = 0;
    AddOut('':g_lastLineNo);
    g_declAt = OutCount();
  endif;
  DeclareHidden('IA_FIRST':'ind inz(*on)');
  if not g_cycNoPrim and g_protoLineCount < C_MAXPLINE;
    g_protoLineCount += 1;
    g_protoLine(g_protoLineCount) = 'dcl-ds IA_NEXT likeds(' + g_cycRec + ');';
  endif;
  g_cycleNoted = *on;
  if g_cycNoPrim;
    Emit('// RPG cycle skeleton (IACNVFREE): the program cycle without a primary '
         + 'file, it repeats until the program sets LR on (check)':g_lastLineNo);
  else;
    Emit('// RPG cycle skeleton (IACNVFREE): the program cycle of file ' + g_cycFile
         + ' (check)':g_lastLineNo);
  endif;
  Emit('dow *on;':g_lastLineNo);
  g_depth += 1;
  if OutCycleCount('S') = 0;
    Emit('// step 1: heading and detail output of the previous record belongs here '
         + '(O specifications)':g_lastLineNo);
  else;
    Emit('// step 1: heading and detail output of the previous record (1P: first '
         + 'cycle)':g_lastLineNo);
    CycOutput('S');
  endif;
  Emit('if *inlr;':g_lastLineNo);
  Emit('leave;':g_lastLineNo:1);
  Emit('endif;':g_lastLineNo);
  if g_cycUsesRt;
    Emit('// RT (return indicator): back to the caller, LR stays off (FREE-49)'
         :g_lastLineNo);
    Emit('if *inrt;':g_lastLineNo);
    Emit('*inrt = *off;':g_lastLineNo:1);
    Emit('return;':g_lastLineNo:1);
    Emit('endif;':g_lastLineNo);
  endif;
  CycLevels(*off:g_cycMax);
  if not g_cycNoPrim;
    Emit('read ' + g_cycFile + ' IA_NEXT;':g_lastLineNo);
    Emit('if %eof(' + g_cycFile + ');':g_lastLineNo);
    Emit('*inlr = *on;':g_lastLineNo:1);
    Emit('leave;':g_lastLineNo:1);
    Emit('endif;':g_lastLineNo);
    CycTypeTest();
    CycBreakTest();
  endif;
  if g_cycHasTotals;
    Emit('if not IA_FIRST;':g_lastLineNo);
    Emit('exsr IA_TOTALS;':g_lastLineNo:1);
    Emit('endif;':g_lastLineNo);
  endif;
  if not g_cycNoPrim;
    Emit(g_cycRec + ' = IA_NEXT;':g_lastLineNo);
  endif;
  Emit('IA_FIRST = *off;':g_lastLineNo);
  g_cycState = 'D';
  if g_cycNoPrim;
    RptItem(C_STS_ASSUMPTION:g_lastLineNo:'RPG cycle'
            :'Cycle skeleton written without a primary file (RV-60): the '
             + 'detail calculations repeat until the program sets LR on; '
             + 'heading and detail records are written at the start of each '
             + 'cycle, total records at the end');
  else;
    RptItem(C_STS_ASSUMPTION:g_lastLineNo:'RPG cycle'
            :'Cycle skeleton written for the primary file: read, control '
             + 'break, total calculations and detail calculations; heading, '
             + 'detail and total records of a converted printer file are '
             + 'written in it (RV-60)');
  endif;
end-proc;

// ------------------------------------------------------------------
// The end of the loop and the last cycle (LR): all control levels on, the totals.
dcl-proc CycCloseLoop;
  dcl-pi *n;
  end-pi;

  g_depth -= 1;
  if g_depth < 0;
    g_depth = 0;
  endif;
  Emit('enddo;':g_lastLineNo);
  Emit('// last cycle: LR turns on all control levels, then the total calculations'
       :g_lastLineNo);
  Emit('*inlr = *on;':g_lastLineNo);
  CycLevels(*on:g_cycMax);
  if g_cycHasTotals;
    Emit('exsr IA_TOTALS;':g_lastLineNo);
  endif;
  g_cycState = 'E';
end-proc;

// ------------------------------------------------------------------
dcl-proc CycBeginTotals;
  dcl-pi *n;
  end-pi;

  Emit('':g_lastLineNo);
  Emit('// total calculations (control levels and LR): for a break and at the end'
       :g_lastLineNo);
  Emit('begsr IA_TOTALS;':g_lastLineNo);
  g_depth += 1;
  g_inSub = *on;
  g_cycState = 'T';
end-proc;

// ------------------------------------------------------------------
dcl-proc CycEndTotals;
  dcl-pi *n;
  end-pi;

  if OutCycleCount('T') > 0;
    Emit('// total output (step 7): the total records of the O specifications'
         :g_lastLineNo);
    CycOutput('T');
  endif;
  g_depth -= 1;
  if g_depth < 0;
    g_depth = 0;
  endif;
  Emit('endsr;':g_lastLineNo);
  g_inSub = *off;
  g_cycState = 'E';
end-proc;

// ------------------------------------------------------------------
// Closes whatever is open (before the first BEGSR and at the end of the source).
dcl-proc CycClose;
  dcl-pi *n;
  end-pi;

  if g_cycState = 'P';
    CycOpen();
  endif;
  if g_cycState = 'D';
    CycCloseLoop();
    if g_cycHasTotals;
      // Total calculations after the first subroutine are not part of the skeleton.
      CycBeginTotals();
      CycEndTotals();
    endif;
  elseif g_cycState = 'T';
    CycEndTotals();
  endif;
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

  // The cycle skeleton is written even when there is no calculation line.
  if not g_cycChecked;
    CycInit();
  endif;
  if g_cycState = 'P' or g_cycState = 'D' or g_cycState = 'T';
    CycClose();
  endif;
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

  for l_index = 1 to g_dtCount;
    if not g_dtApplied(l_index);
      RptItem(C_STS_REVIEW:g_dtLineNo(l_index):g_dtText(l_index)
              :'The field ' + g_dtName(l_index) + ' must be a data structure of '
               + 'the I specifications or a field defined by a result field: '
               + 'DTAARA cannot be added');
    endif;
  endfor;

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
