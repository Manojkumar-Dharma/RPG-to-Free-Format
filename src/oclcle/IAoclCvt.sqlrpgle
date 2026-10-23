**FREE
// IAoclCvt - OCL36 to CLLE conversion logic (module of IAoclToCle).
//
// Converted in v1 (see docs/OCL-MAPPING.md for the rules and what is assumed):
//   comment lines, LOAD + RUN, FILE, LOCAL, TAG, GOTO, RETURN,
//   substitution expressions ?n?, ?USER?, ?WS?, procedure calls,
//   WAIT, PAUSE, NOHALT, CANCEL (without operands), LIBRARY, SESSION (APPC)
// Everything else is written as a CL comment and reported as REVIEW.
// The converted program is collected first, because the PGM statement and
// the DCLs depend on which substitution expressions were used.

ctl-opt nomain option(*srcstmt:*nodebugio);

/copy qcpysrc,IAcnvSrvP

dcl-c C_MAXBODY 5000;
dcl-c C_MAXITEMS 20;
dcl-c C_QUOTE '''';
dcl-c C_DQUOTE '''''';          // two apostrophes (an apostrophe inside text)
dcl-c C_MAXPARMITEMS 41;           // 40 call parameters plus one to detect more
dcl-c C_CALLPARMLEN 10;            // length every converted program declares
dcl-c C_ALLSCOPE '*LIBL';          // where DATAF1-'name,ALL' looks for files
dcl-c C_FDINITFLD 'PHRCDC';   // DSPFD initial records (unverified)
dcl-c C_MARKLIB 'QGPL';          // library of the ACTIVE- marker data areas
dcl-c C_MSGPREFIX 'USR';         // message id prefix of CRTS36MSGF (assumed)
dcl-c C_MAXACTIVE 10;
dcl-c C_DFTWIDTH 80;             // line width assumed when the target width is unknown
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
dcl-s g_width int(10);
dcl-s g_overriddenFiles varchar(300);       // FILE names overridden since the last CALL
dcl-c C_MAXSORT 200;
dcl-s g_sortMode ind;            // inside the data lines of a #GSORT step
dcl-s g_sortCond ind;            // the block contains IF/IFF/ELSE/END
dcl-s g_sortLines varchar(512) dim(C_MAXSORT);
dcl-s g_sortCnt int(10);
dcl-s g_sortNo int(10);
dcl-s g_sortFirst int(10);
dcl-s g_sortIn varchar(60) dim(8);
dcl-s g_sortOut varchar(60);
dcl-s g_sortInLib varchar(60) dim(8);
dcl-s g_sortSrcMbr varchar(60);
dcl-s g_sortSrcLib varchar(60);
dcl-s g_conditions ind;
dcl-c C_MAXTMP 600;
dcl-c C_MAXLDA 20;
dcl-s g_tempLines varchar(512) dim(C_MAXTMP);
dcl-s g_tempLineCount int(10);
dcl-s g_blockPosition int(10) dim(C_MAXLDA);
dcl-s g_blockLength int(10) dim(C_MAXLDA);
dcl-s g_blkCnt int(10);
dcl-s g_ldaPosition int(10) dim(C_MAXLDA);
dcl-s g_ldaLength int(10) dim(C_MAXLDA);
dcl-s g_ldaCnt int(10);
dcl-s g_sortOutLib varchar(60);
dcl-s g_sortExtra varchar(200);
dcl-s g_useSql ind;
// ' ' unused, 'P' passed, 'L' local (set by EVALUATE)
dcl-s g_parameterKind char(1) dim(40);
dcl-s g_parameterLength int(10) dim(40);
dcl-s g_useDate ind;
dcl-s g_ifLast varchar(500);     // condition of the IF line before (for ELSE)
dcl-s g_ifCtx varchar(500);      // condition context when that line was an ELSE IF
dcl-s g_tempVariableCount int(10);
dcl-s g_isSort ind;              // the pending LOAD is #GSORT
dcl-s g_oclWords varchar(800);          // ,NAME, list: OCL statement words
dcl-s g_ibmProcedures varchar(4000);    // ,NAME, list: IBM-supplied procedures
dcl-s g_fileSizeCount int(10);   // ?F'A,name'? and ?F'S,name'? results: &F1, &F2, ...
dcl-s g_initSizeCnt int(10);     // ?F'S,name'? uses (filled before the body)
dcl-s g_initSizeVar varchar(20) dim(40);
dcl-s g_initSizeName varchar(10) dim(40);
dcl-s g_initLine varchar(200) dim(600);
dcl-s g_initLineCnt int(10);
dcl-s g_dataf1Count int(10);     // DATAF1- flags: &D1, &D2, ...
dcl-s g_activeCount int(10);     // ACTIVE- flags: &A1, &A2, ...
dcl-s g_procName varchar(10);    // OCL procedure (source member) name
dcl-s g_useFileSize ind;         // &FSN and &FSD work variables are needed
dcl-s g_usePause ind;            // &PAUSERPY reply variable is needed
dcl-s g_libMode int(10);         // LIBRARY: 0 none, 1 SESSION-NO, 2 SESSION-YES
dcl-s g_sessionLib varchar(60);  // library set at exit by LIBRARY SESSION-YES
dcl-s g_user1Member varchar(60); // MEMBER USER1: first-level message file
dcl-s g_user2Member varchar(60); // MEMBER USER2: second-level message file
dcl-s g_msgLibrary varchar(60);  // MEMBER LIBRARY: library of the message files
dcl-s g_msgVarCount int(10);     // &Mn variables made for ?Mmic? expressions
dcl-s g_useMsgText ind;          // &MSGTXT work variable is needed
dcl-s g_useMsgOut ind;           // &MSGOUT message text variable is needed
dcl-s g_curLineNo int(10);       // line being converted (for report items)
dcl-s g_curText varchar(512);

// ------------------------------------------------------------------
dcl-proc ToUpper;
  dcl-pi *n varchar(512);
    i_text varchar(512) const;
  end-pi;

  return %xlate(C_LOWER:C_UPPER:i_text);
end-proc;

// ------------------------------------------------------------------
// Safe substring helpers: never fail on an empty string, a zero length or
// a start past the end (RPG %SUBST raises an error in those cases).
dcl-proc SafeSubstr;
  dcl-pi *n varchar(512);
    i_text varchar(512) const;
    i_from int(10) const;
    i_length int(10) const;
  end-pi;

  dcl-s l_from int(10);
  dcl-s l_length int(10);

  l_from = %max(i_from:1);
  l_length = i_length;
  if l_length <= 0 or l_from > %len(i_text);
    return '';
  endif;
  l_length = %min(l_length:%len(i_text) - l_from + 1);
  return %subst(i_text:l_from:l_length);
end-proc;

dcl-proc SafeSubstrToEnd;
  dcl-pi *n varchar(512);
    i_text varchar(512) const;
    i_from int(10) const;
  end-pi;

  dcl-s l_from int(10);

  l_from = %max(i_from:1);
  if l_from > %len(i_text);
    return '';
  endif;
  return %subst(i_text:l_from);
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
// Adds text as CL comment lines. The text is kept as it is (only "*/" is
// altered so it cannot end the comment). A line is split only when it would
// not fit the target width, preferably at a blank.
dcl-proc AddCommentKeepingText;
  dcl-pi *n;
    i_text varchar(512) const;
  end-pi;

  dcl-s l_rest varchar(512);
  dcl-s l_piece varchar(512);
  dcl-s l_maxTextWidth int(10);
  dcl-s l_cutPos int(10);
  dcl-s l_scanPos int(10);

  l_rest = %trimr(%scanrpl('*/':'* /':i_text));
  l_maxTextWidth = g_width - 6;             // room for the /* and */ delimiters
  if l_maxTextWidth < 10;
    l_maxTextWidth = 10;
  endif;
  dow %len(l_rest) > 0;
    if %len(l_rest) > l_maxTextWidth;
      l_cutPos = l_maxTextWidth;
      for l_scanPos = l_maxTextWidth downto 2;
        if SafeSubstr(l_rest:l_scanPos:1) = ' ';
          l_cutPos = l_scanPos - 1;         // break before the blank
          leave;
        endif;
      endfor;
      l_piece = SafeSubstr(l_rest:1:l_cutPos);
      l_rest = SafeSubstrToEnd(l_rest:l_cutPos + 1);
    else;
      l_piece = l_rest;
      l_rest = '';
    endif;
    AddBody('/*' + l_piece + ' */');
  enddo;
end-proc;

// ------------------------------------------------------------------
// Comment generated by the converter (text trimmed, one blank after /*).
dcl-proc AddComment;
  dcl-pi *n;
    i_text varchar(512) const;
  end-pi;

  if %len(%trim(i_text)) = 0;
    return;
  endif;
  AddCommentKeepingText(' ' + %trim(i_text));
end-proc;

// ------------------------------------------------------------------
// A procedure parameter ?n? (1 to 40 here; CL allows 40 parameters) is read.
// A parameter whose first use is a read is taken as passed by the caller.
dcl-proc MarkParameterUsed;
  dcl-pi *n;
    i_parameterNo int(10) const;
  end-pi;

  if g_parameterKind(i_parameterNo) = ' ';
    g_parameterKind(i_parameterNo) = 'P';
  endif;
  if g_parameterKind(i_parameterNo) = 'P';
    g_maxParm = %max(g_maxParm:i_parameterNo);
  endif;
end-proc;

// ------------------------------------------------------------------
// Local data area text: returns the CL variable and, when i_emit is *ON,
// writes the RTVDTAARA that fills it (right before the statement using it).
dcl-proc LdaVariableName;
  dcl-pi *n varchar(20);
    i_position int(10) const;
    i_length int(10) const;
    i_emit ind const;
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_found ind inz(*off);
  dcl-s l_name varchar(20);

  l_name = '&L' + %trim(%char(i_position)) + '_' + %trim(%char(i_length));
  for l_index = 1 to g_ldaCnt;
    if g_ldaPosition(l_index) = i_position and g_ldaLength(l_index) = i_length;
      l_found = *on;
    endif;
  endfor;
  if not l_found and g_ldaCnt < C_MAXLDA;
    g_ldaCnt += 1;
    g_ldaPosition(g_ldaCnt) = i_position;
    g_ldaLength(g_ldaCnt) = i_length;
  endif;
  if i_emit;
    AddBody('RTVDTAARA DTAARA(*LDA (' + %trim(%char(i_position)) + ' '
            + %trim(%char(i_length)) + ')) RTNVAR(' + l_name + ')');
  endif;
  return l_name;
end-proc;

// ------------------------------------------------------------------
// Parses L'p,n' (text of a ?L'p,n'? expression). *ON when valid.
dcl-proc ParseLdaExpression;
  dcl-pi *n ind;
    i_token varchar(60) const;
    o_position int(10);
    o_length int(10);
  end-pi;

  dcl-s l_upperToken varchar(60);
  dcl-s l_commaPos int(10);
  dcl-s l_positionText varchar(60);
  dcl-s l_lengthText varchar(60);

  l_upperToken = ToUpper(%trim(i_token));
  if %len(l_upperToken) < 6 or SafeSubstr(l_upperToken:1:2) <> 'L''' 
     or SafeSubstr(l_upperToken:%len(l_upperToken):1) <> '''';
    return *off;
  endif;
  l_commaPos = %scan(',':l_upperToken);
  if l_commaPos < 4;
    return *off;
  endif;
  l_positionText = SafeSubstr(l_upperToken:3:l_commaPos - 3);
  l_lengthText = SafeSubstr(l_upperToken:l_commaPos + 1:
                   %len(l_upperToken) - l_commaPos - 1);
  if %len(l_positionText) = 0 or %len(l_positionText) > 4
     or %len(l_lengthText) = 0 or %len(l_lengthText) > 3
     or %check('0123456789':l_positionText) > 0 or %check('0123456789':l_lengthText) > 0;
    return *off;
  endif;
  o_position = %int(l_positionText);
  o_length = %int(l_lengthText);
  return o_position >= 1 and o_length >= 1 and o_position + o_length <= 1025;
end-proc;

// ------------------------------------------------------------------
// ?F'A,name'? (actual number of data records, 8 digits with leading zeros).
// Writes the statements that fill a new variable &Fn and returns it, or
// '' when the expression is not converted: any form with a creation date.
// ?F'S,name'? is the initial record allocation (DSPFD), see WriteProgram.
// i_token is the upper-case text between the question marks.
dcl-proc FileSizeVariable;
  dcl-pi *n varchar(20);
    i_token varchar(60) const;
  end-pi;

  dcl-s l_inner varchar(60);
  dcl-s l_commaPos int(10);
  dcl-s l_type varchar(60);
  dcl-s l_name varchar(60);
  dcl-s l_variable varchar(20);

  if %len(i_token) < 6 or SafeSubstr(i_token:1:2) <> 'F'''
     or SafeSubstr(i_token:%len(i_token):1) <> '''';
    return '';
  endif;
  l_inner = SafeSubstr(i_token:3:%len(i_token) - 3);
  l_commaPos = %scan(',':l_inner);
  if l_commaPos < 2;
    return '';
  endif;
  l_type = %trim(SafeSubstr(l_inner:1:l_commaPos - 1));
  l_name = %trim(SafeSubstrToEnd(l_inner:l_commaPos + 1));
  if (l_type <> 'A' and l_type <> 'S') or %scan(',':l_name) > 0;   // T and the date form
    return '';
  endif;
  if %len(l_name) = 0 or %len(l_name) > 10
     or %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_#@$':l_name) > 0;
    return '';
  endif;

  if l_type = 'S';
    // Initial record allocation, read once before the body (see WriteProgram).
    if g_initSizeCnt >= 40;
      return '';
    endif;
    g_useFileSize = *on;
    g_fileSizeCount += 1;
    l_variable = '&F' + %trim(%char(g_fileSizeCount));
    g_initSizeCnt += 1;
    g_initSizeVar(g_initSizeCnt) = l_variable;
    g_initSizeName(g_initSizeCnt) = l_name;
    RptItem(C_STS_ASSUMPTION:g_curLineNo:g_curText
            :'File size ' + l_name + ' (allocated) taken as the initial number of '
            + 'records of the file (DSPFD, field ' + C_FDINITFLD + ', please check '
            + 'the field name); S/36 gave the size in blocks or records; 0 when '
            + 'the file is not found');
    return l_variable;
  endif;

  g_useFileSize = *on;
  g_fileSizeCount += 1;
  l_variable = '&F' + %trim(%char(g_fileSizeCount));
  AddBody('CHGVAR VAR(&FSN) VALUE(0)');
  AddBody('RTVMBRD FILE(' + l_name + ') MBR(*LAST) NBRCURRCD(&FSN)');
  AddBody('MONMSG MSGID(CPF0000) EXEC(CHGVAR VAR(&FSN) VALUE(0))');
  AddBody('IF COND(&FSN *GT 16777215) THEN(CHGVAR VAR(&FSN) VALUE(16777215))');
  AddBody('CHGVAR VAR(&FSD) VALUE(&FSN)');
  AddBody('CHGVAR VAR(' + l_variable + ') VALUE(&FSD)');
  RptItem(C_STS_ASSUMPTION:g_curLineNo:g_curText
          :'File size ' + l_name + ' read with RTVMBRD (NBRCURRCD, last member, '
          + 'library list); 0 when the file or member cannot be read');
  return l_variable;
end-proc;

// ------------------------------------------------------------------
// Maps the text inside ?...? to a CL variable and its length. Returns ''
// when the expression is not supported. Supported: ?n? (1-40), ?USER?,
// ?WS?, ?DATE?, ?L'p,n'?, ?F'A,name'?, ?Mmic?, ?M'mic,p,n'?.
dcl-proc ExpressionVariable;
  dcl-pi *n varchar(20);
    i_token varchar(60) const;
    o_length int(10);
  end-pi;

  dcl-s l_upperToken varchar(60);
  dcl-s l_number int(10);
  dcl-s l_position int(10);

  l_upperToken = ToUpper(%trim(i_token));
  o_length = 0;
  if %len(l_upperToken) > 0 and %len(l_upperToken) <= 2
     and %check('0123456789':l_upperToken) = 0;
    l_number = %int(l_upperToken);
    if l_number < 1 or l_number > 40;
      return '';
    endif;
    MarkParameterUsed(l_number);
    if g_parameterKind(l_number) = 'L';
      o_length = %max(g_parameterLength(l_number):1);
    else;
      o_length = 10;
    endif;
    return '&P' + %trim(%char(l_number));
  endif;
  if l_upperToken = 'USER';
    g_useUser = *on;
    o_length = 10;
    return '&USER';
  endif;
  if l_upperToken = 'WS';
    g_useWs = *on;
    o_length = 10;
    return '&WS';
  endif;
  if l_upperToken = 'DATE';
    g_useDate = *on;
    o_length = 6;
    return '&DATE';
  endif;
  if ParseLdaExpression(l_upperToken:l_position:l_number);
    o_length = l_number;
    return LdaVariableName(l_position:l_number:*on);
  endif;
  if SafeSubstr(l_upperToken:1:2) = 'F''';
    o_length = 8;
    return FileSizeVariable(l_upperToken);
  endif;
  if SafeSubstr(l_upperToken:1:1) = 'M' and %len(l_upperToken) > 1
     and (SafeSubstr(l_upperToken:2:1) = C_QUOTE
          or %check('0123456789':SafeSubstrToEnd(l_upperToken:2)) = 0);
    o_length = 75;
    return MessageMemberVariable(l_upperToken);
  endif;
  return '';
end-proc;

// ------------------------------------------------------------------
// A name or value that may contain ?...? expressions. A single expression
// becomes its CL variable; a mixture of text and expressions is built into
// a temporary variable by CHGVAR (written before the statement).
dcl-proc ConvertOperand;
  dcl-pi *n varchar(60);
    i_value varchar(200) const;
    o_isValid ind;
  end-pi;

  dcl-s l_rest varchar(200);
  dcl-s l_openMark int(10);
  dcl-s l_closeMark int(10);
  dcl-s l_literalText varchar(200);
  dcl-s l_variable varchar(20);
  dcl-s l_variableLength int(10);
  dcl-s l_expr varchar(400) inz('');
  dcl-s l_expressionCount int(10) inz(0);
  dcl-s l_tempVariable varchar(20);

  o_isValid = *on;
  if %scan('?':i_value) = 0;
    return ToUpper(i_value);
  endif;

  l_rest = i_value;
  dow %len(l_rest) > 0;
    l_openMark = %scan('?':l_rest);
    l_variable = '';
    if l_openMark = 0;
      l_literalText = l_rest;
      l_rest = '';
    else;
      l_closeMark = %scan('?':l_rest:l_openMark + 1);
      if l_closeMark = 0;
        o_isValid = *off;
        return '';
      endif;
      l_variable = ExpressionVariable(SafeSubstr(l_rest:l_openMark + 1:
                     l_closeMark - l_openMark - 1):l_variableLength);
      if l_variable = '';
        o_isValid = *off;
        return '';
      endif;
      if l_openMark > 1;
        l_literalText = SafeSubstr(l_rest:1:l_openMark - 1);
      else;
        l_literalText = '';
      endif;
      if l_closeMark >= %len(l_rest);
        l_rest = '';
      else;
        l_rest = SafeSubstrToEnd(l_rest:l_closeMark + 1);
      endif;
    endif;

    if %len(l_literalText) > 0;
      if l_expressionCount > 0;
        l_expr += ' *TCAT ';
      endif;
      l_expr += C_QUOTE + ToUpper(l_literalText) + C_QUOTE;
      l_expressionCount += 1;
    endif;
    if l_variable <> '';
      if l_expressionCount > 0;
        l_expr += ' *TCAT ';
      endif;
      l_expr += l_variable;
      l_expressionCount += 1;
    endif;
  enddo;

  if l_expressionCount = 1;
    return l_variable;                  // the value is one expression
  endif;
  g_tempVariableCount += 1;
  l_tempVariable = '&T' + %trim(%char(g_tempVariableCount));
  AddBody('CHGVAR VAR(' + l_tempVariable + ') VALUE(' + l_expr + ')');
  return l_tempVariable;
end-proc;

// ------------------------------------------------------------------
// Replaces ?n?, ?USER?, ?WS?, ?DATE? and ?L'p,n'?. o_open is *ON when some other ?...?
// expression is left (it cannot be converted).
dcl-proc SubstituteExpressions;
  dcl-pi *n varchar(512);
    i_text varchar(512) const;
    o_open ind;
  end-pi;

  dcl-s l_remaining varchar(512);
  dcl-s l_result varchar(512) inz('');
  dcl-s l_openMark int(10);
  dcl-s l_closeMark int(10);
  dcl-s l_token varchar(60);
  dcl-s l_variable varchar(20);
  dcl-s l_variableLength int(10);

  o_open = *off;
  l_remaining = i_text;

  dow *on;
    l_openMark = %scan('?':l_remaining);
    if l_openMark = 0;
      l_result += l_remaining;
      leave;
    endif;
    l_closeMark = %scan('?':l_remaining:l_openMark + 1);
    if l_closeMark = 0;
      o_open = *on;
      l_result += l_remaining;
      leave;
    endif;

    if l_openMark > 1;
      l_result += SafeSubstr(l_remaining:1:l_openMark - 1);
    endif;
    if l_closeMark = l_openMark + 1;          // "??" is not an expression
      o_open = *on;
      l_result += '??';
      if l_closeMark >= %len(l_remaining);
        leave;
      endif;
      l_remaining = SafeSubstrToEnd(l_remaining:l_closeMark + 1);
      iter;
    endif;
    l_token = ToUpper(SafeSubstr(l_remaining:l_openMark + 1:
                l_closeMark - l_openMark - 1));

    l_variable = ExpressionVariable(l_token:l_variableLength);
    if l_variable = '' or l_variableLength < 0;
      o_open = *on;
      l_result += SafeSubstr(l_remaining:l_openMark:l_closeMark - l_openMark + 1);
    else;
      // CL cannot put a variable inside a word or a quoted text.
      if (%len(l_result) > 0 and %scan(SafeSubstr(l_result:%len(l_result):1):' ,()') = 0)
         or (l_closeMark < %len(l_remaining)
         and %scan(SafeSubstr(l_remaining:l_closeMark + 1:1):' ,()') = 0);
        o_open = *on;
      endif;
      l_result += l_variable;
    endif;

    if l_closeMark >= %len(l_remaining);
      leave;
    endif;
    l_remaining = SafeSubstrToEnd(l_remaining:l_closeMark + 1);
  enddo;

  return l_result;
end-proc;

// ------------------------------------------------------------------
// Splits comma separated operands outside quotes. Returns the count.
dcl-proc SplitItems;
  dcl-pi *n int(10);
    i_text varchar(512) const;
    o_items varchar(200) dim(C_MAXITEMS);
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_itemCount int(10) inz(0);
  dcl-s l_currentItem varchar(200) inz('');
  dcl-s l_inQuote ind inz(*off);
  dcl-s l_char char(1);

  for l_index = 1 to %len(i_text);
    l_char = SafeSubstr(i_text:l_index:1);
    if l_char = C_QUOTE;
      l_inQuote = not l_inQuote;
    endif;
    if l_char = ',' and not l_inQuote;
      if l_itemCount < C_MAXITEMS;
        l_itemCount += 1;
        o_items(l_itemCount) = %trim(l_currentItem);
      endif;
      l_currentItem = '';
    else;
      l_currentItem += l_char;
    endif;
  endfor;

  if %len(%trim(l_currentItem)) > 0 and l_itemCount < C_MAXITEMS;
    l_itemCount += 1;
    o_items(l_itemCount) = %trim(l_currentItem);
  endif;
  return l_itemCount;
end-proc;

// ------------------------------------------------------------------
// Splits KEY-value. A plain value (no key) comes back with an empty key.
dcl-proc SplitKeyword;
  dcl-pi *n;
    i_item varchar(200) const;
    o_keyword varchar(60);
    o_value varchar(200);
  end-pi;

  dcl-s l_dashPos int(10);
  dcl-s l_keyword varchar(60);

  l_dashPos = %scan('-':i_item);
  if l_dashPos > 1;
    l_keyword = ToUpper(%trim(SafeSubstr(i_item:1:l_dashPos - 1)));
    if %scan(' ':l_keyword) = 0 and %scan(C_QUOTE:l_keyword) = 0;
      o_keyword = l_keyword;
      o_value = %trim(SafeSubstrToEnd(i_item:l_dashPos + 1));
      return;
    endif;
  endif;
  o_keyword = '';
  o_value = %trim(i_item);
end-proc;

// ------------------------------------------------------------------
dcl-proc IsValidName;
  dcl-pi *n ind;
    i_name varchar(60) const;
    i_maxLen int(10) const;
  end-pi;

  if %len(i_name) = 0 or %len(i_name) > i_maxLen;
    return *off;
  endif;
  if SafeSubstr(i_name:1:1) = '&';
    return *on;                  // a variable made by Subst
  endif;
  return %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_#@$':ToUpper(i_name)) = 0;
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
dcl-proc ConvertLoad;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_operands varchar(512) const;
  end-pi;

  dcl-s l_items varchar(200) dim(C_MAXITEMS);
  dcl-s l_itemCount int(10);
  dcl-s l_isValid ind;
  dcl-s l_name varchar(60);
  dcl-s l_library varchar(60);

  if g_pendLoad;
    ReviewLine(g_loadLine:g_loadText
               :'LOAD was not followed by RUN before the next LOAD');
    g_pendLoad = *off;
  endif;

  l_itemCount = SplitItems(i_operands:l_items);
  if l_itemCount < 1 or l_itemCount > 2;
    ReviewLine(i_lineNo:i_text
               :'LOAD operands not understood (expected program[,library])');
    return;
  endif;

  l_name = ConvertOperand(l_items(1):l_isValid);
  l_library = '';
  if l_isValid and l_itemCount = 2;
    l_library = ConvertOperand(l_items(2):l_isValid);
  endif;
  if not l_isValid;
    ReviewLine(i_lineNo:i_text:'LOAD uses an expression that is not converted');
    return;
  endif;
  if not IsValidName(l_name:10) or (l_library <> '' and not IsValidName(l_library:10));
    ReviewLine(i_lineNo:i_text:'Program or library name is not a valid name');
    return;
  endif;

  g_pendLoad = *on;
  g_isSort = (l_name = '#GSORT');
  g_loadName = l_name;
  g_loadLib = l_library;
  g_loadLine = i_lineNo;
  g_loadText = i_text;
end-proc;

// ------------------------------------------------------------------
dcl-proc ConvertRun;
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

  if g_isSort;
    g_sortMode = *on;
    g_sortCond = *off;
    g_sortCnt = 0;
    g_sortSrcMbr = '';
    g_sortSrcLib = '';
    g_conditions = *off;
    g_sortFirst = i_lineNo;
    g_pendLoad = *off;
    return;
  endif;

  l_call = 'CALL PGM(';
  if g_loadLib <> '';
    l_call += g_loadLib + '/';
  endif;
  l_call += g_loadName + ')';
  AddBody(l_call);
  g_pendLoad = *off;
  // A FILE statement lasts for one step: remove its overrides after the call.
  if %len(g_overriddenFiles) > 0;
    AddBody('DLTOVR FILE(' + %trim(g_overriddenFiles) + ')');
    g_overriddenFiles = '';
  endif;

  select;
    when %len(%trim(i_operands)) > 0;
      AddComment('OCL: ' + i_text);
      RptItem(C_STS_REVIEW:i_lineNo:i_text:'RUN operands are not converted');
    other;
      RptItem(C_STS_CONVERTED:g_loadLine:g_loadText:'');
  endsl;
end-proc;

// ------------------------------------------------------------------
// // FILE NAME-x[,LABEL-y][,LIBRARY-z][,DISP-...]  ->  OVRDBF
dcl-proc ConvertFile;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_operands varchar(512) const;
  end-pi;

  dcl-s l_items varchar(200) dim(C_MAXITEMS);
  dcl-s l_itemCount int(10);
  dcl-s l_itemIndex int(10);
  dcl-s l_isValid ind;
  dcl-s l_hasProblem ind inz(*off);
  dcl-s l_keyword varchar(60);
  dcl-s l_value varchar(200);
  dcl-s l_name varchar(60) inz('');
  dcl-s l_label varchar(60) inz('');
  dcl-s l_library varchar(60) inz('');
  dcl-s l_disp varchar(60) inz('');
  dcl-s l_other varchar(200) inz('');
  dcl-s l_command varchar(200);
  dcl-s l_isJobOverride ind inz(*off);
  dcl-s l_inputIndex int(10);

  l_itemCount = SplitItems(i_operands:l_items);
  if l_itemCount < 1;
    ReviewLine(i_lineNo:i_text:'FILE operands not understood');
    return;
  endif;

  for l_itemIndex = 1 to l_itemCount;
    SplitKeyword(l_items(l_itemIndex):l_keyword:l_value);
    l_isValid = *on;
    select;
      when l_keyword = 'NAME';
        l_name = ConvertOperand(l_value:l_isValid);
      when l_keyword = 'LABEL';
        l_label = ConvertOperand(l_value:l_isValid);
      when l_keyword = 'LIBRARY';
        l_library = ConvertOperand(l_value:l_isValid);
      when l_keyword = 'DISP';
        l_disp = ToUpper(l_value);
      other;
        if l_keyword = 'JOB' and ToUpper(l_value) = 'YES';
          // override for the whole job: not converted
          l_isJobOverride = *on;
        endif;
        if %len(l_other) > 0;
          l_other += ' ';
        endif;
        if l_keyword = '';
          l_other += l_value;
        else;
          l_other += l_keyword;
        endif;
    endsl;
    if not l_isValid;
      l_hasProblem = *on;
    endif;
  endfor;
  if l_hasProblem;
    ReviewLine(i_lineNo:i_text
               :'NAME, LABEL or LIBRARY uses an expression that is not converted');
    return;
  endif;

  if l_label = '';
    l_label = l_name;
  endif;
  if not IsValidName(l_name:10) or not IsValidName(l_label:10)
     or (l_library <> '' and not IsValidName(l_library:10));
    ReviewLine(i_lineNo:i_text:'NAME, LABEL or LIBRARY is missing or not a valid name');
    return;
  endif;

  // Files of a #GSORT step become FMTDTA INFILE/OUTFILE (see FinishSort).
  if g_isSort and g_pendLoad and l_name = 'WORK';
    RptItem(C_STS_CONVERTED:i_lineNo:i_text
            :'Sort work file is ignored on the AS/400 system');
    return;
  endif;
  if g_isSort and g_pendLoad and (l_name = 'OUTPUT'
     or l_name = 'INPUT' or (%len(l_name) = 6 and SafeSubstr(l_name:1:5) = 'INPUT'
     and %check('12345678':SafeSubstr(l_name:6:1)) = 0));
    if l_name <> 'OUTPUT';
      if l_name = 'INPUT';
        l_inputIndex = 1;
      else;
        l_inputIndex = %int(SafeSubstr(l_name:6:1));
      endif;
      g_sortIn(l_inputIndex) = l_label;
      g_sortInLib(l_inputIndex) = l_library;
    else;
      g_sortOut = l_label;
      g_sortOutLib = l_library;
      g_sortExtra = l_other;
    endif;
    RptItem(C_STS_CONVERTED:i_lineNo:i_text:'');
    return;
  endif;
  if l_disp = 'NEW';
    ReviewLine(i_lineNo:i_text
               :'DISP-NEW (creating the file) is not converted');
    return;
  endif;

  l_command = 'OVRDBF FILE(' + l_name + ') TOFILE(';
  if l_library <> '';
    l_command += l_library + '/';
  endif;
  l_command += l_label + ')';
  AddBody(l_command);
  if not l_isJobOverride;
    TrackOverride(l_name);
  endif;

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
// Remembers a file name so DLTOVR is written after the next CALL.
dcl-proc TrackOverride;
  dcl-pi *n;
    i_name varchar(60) const;
  end-pi;

  if %scan(' ' + i_name + ' ':' ' + g_overriddenFiles + ' ') = 0;
    if %len(g_overriddenFiles) > 0;
      g_overriddenFiles += ' ';
    endif;
    g_overriddenFiles += i_name;
  endif;
end-proc;

// ------------------------------------------------------------------
dcl-proc IsPlainNumber;
  dcl-pi *n ind;
    i_value varchar(200) const;
    i_allowPoint ind const;
  end-pi;

  if %len(i_value) = 0 or %len(i_value) > 9;
    return *off;
  endif;
  if i_allowPoint;
    return %check('0123456789.':i_value) = 0;
  endif;
  return %check('0123456789':i_value) = 0;
end-proc;

// ------------------------------------------------------------------
// // PRINTER [NAME-x][,DEVICE-d][,LINES-n][,CPI-n]...  ->  OVRPRTF
// Without NAME the session printer override FILE(*PRTF) is used.
// The keywords are mapped as in the table of the System/36 Environment
// Programming guide (chapter 17, "// PRINTER Override Printer File").
dcl-proc ConvertPrinter;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_operands varchar(512) const;
  end-pi;

  dcl-s l_items varchar(200) dim(C_MAXITEMS);
  dcl-s l_itemCount int(10);
  dcl-s l_itemIndex int(10);
  dcl-s l_isValid ind;
  dcl-s l_hasProblem ind inz(*off);
  dcl-s l_keyword varchar(60);
  dcl-s l_value varchar(200);
  dcl-s l_converted varchar(60);
  dcl-s l_file varchar(60) inz('*PRTF');
  dcl-s l_parms varchar(400) inz('');
  dcl-s l_parm varchar(100);
  dcl-s l_other varchar(200) inz('');
  dcl-s l_note varchar(200) inz('');
  dcl-s l_isShared ind inz(*off);
  dcl-s l_isYes ind;
  dcl-s l_isNo ind;
  dcl-s l_yesNo varchar(4);

  l_itemCount = SplitItems(i_operands:l_items);
  if l_itemCount < 1;
    ReviewLine(i_lineNo:i_text:'PRINTER operands not understood');
    return;
  endif;

  for l_itemIndex = 1 to l_itemCount;
    SplitKeyword(l_items(l_itemIndex):l_keyword:l_value);
    l_isValid = *on;
    l_parm = '';
    l_isYes = (ToUpper(l_value) = 'YES');
    l_isNo = (ToUpper(l_value) = 'NO');
    if l_isYes;
      l_yesNo = '*YES';
    else;
      l_yesNo = '*NO';
    endif;
    select;
      when l_keyword = 'NAME';
        l_file = ConvertOperand(l_value:l_isValid);
        if not l_isValid or not IsValidName(l_file:10);
          l_hasProblem = *on;
        endif;
      when l_keyword = 'DEVICE' or l_keyword = 'FORMS';
        l_converted = ConvertOperand(l_value:l_isValid);
        if not l_isValid or not IsValidName(l_converted:10);
          l_hasProblem = *on;
        elseif l_keyword = 'DEVICE';
          l_parm = 'DEV(' + l_converted + ')';
        else;
          l_parm = 'FORMTYPE(' + l_converted + ')';
        endif;
      when l_keyword = 'LINES' and IsPlainNumber(l_value:*off);
        l_parm = 'PAGESIZE(' + l_value + ' *N)';
      when l_keyword = 'LPI' and IsPlainNumber(l_value:*on);
        l_parm = 'LPI(' + l_value + ')';
      when l_keyword = 'CPI' and IsPlainNumber(l_value:*on);
        l_parm = 'CPI(' + l_value + ')';
      when l_keyword = 'COPIES' and IsPlainNumber(l_value:*off);
        l_parm = 'COPIES(' + l_value + ')';
      when l_keyword = 'ROTATE' and IsPlainNumber(l_value:*off);
        l_parm = 'PAGRTT(' + l_value + ')';
      when l_keyword = 'JUSTIFY' and IsPlainNumber(l_value:*off);
        l_parm = 'JUSTIFY(' + l_value + ')';
      when l_keyword = 'DRAWER' and (l_value = '1' or l_value = '2');
        l_parm = 'DRAWER(' + l_value + ')';
      when l_keyword = 'DRAWER' and l_value = '3';
        l_parm = 'DRAWER(*E1)';
      when l_keyword = 'PRIORITY' and l_value = '0';
        l_parm = 'OUTPTY(7) HOLD(*YES)';
      when l_keyword = 'PRIORITY' and %len(l_value) = 1
           and %check('12345':l_value) = 0;
        // S/36 priority 1 to 5 is AS/400 output priority 7 to 3
        l_parm = 'OUTPTY(' + %char(8 - %int(l_value)) + ')';
      when l_keyword = 'ALIGN' and (l_isYes or l_isNo);
        l_parm = 'ALIGN(' + l_yesNo + ')';
      when l_keyword = 'SPOOL' and (l_isYes or l_isNo);
        l_parm = 'SPOOL(' + l_yesNo + ')';
      when l_keyword = 'HOLD' and (l_isYes or l_isNo);
        l_parm = 'SAVE(' + l_yesNo + ')';
      when l_keyword = 'TEXT' and l_isYes;
        l_parm = 'PRTQLTY(*NLQ)';
      when l_keyword = 'TEXT' and l_isNo;
        l_parm = 'PRTQLTY(*DRAFT)';
      when l_keyword = 'EOFMSG' and l_isYes;
        l_parm = 'FORMFEED(*CONT)';
      when l_keyword = 'EOFMSG' and l_isNo;
        l_parm = 'FORMFEED(*CUT)';
      when l_keyword = 'DEFER' and l_isYes;
        l_parm = 'SCHEDULE(*FILEEND)';
      when l_keyword = 'DEFER' and l_isNo;
        l_parm = 'SCHEDULE(*IMMED)';
        l_note = 'DEFER-NO written as SCHEDULE(*IMMED)';
      when l_keyword = 'CONTINUE' and l_isYes;
        l_parm = 'SHARE(*YES)';
        l_isShared = *on;
        l_note = 'CONTINUE-YES: the override is kept until CONTINUE-NO';
      when l_keyword = 'CONTINUE' and l_isNo;
        l_parm = 'SHARE(*NO)';
      other;
        if %len(l_other) > 0;
          l_other += ' ';
        endif;
        l_other += %trim(l_items(l_itemIndex));
    endsl;
    if l_parm <> '';
      if %len(l_parms) > 0;
        l_parms += ' ';
      endif;
      l_parms += l_parm;
    endif;
  endfor;

  if l_hasProblem;
    ReviewLine(i_lineNo:i_text
               :'NAME, DEVICE or FORMS is not a valid name or uses an expression');
    return;
  endif;
  if %len(l_parms) = 0;
    if %len(l_other) > 0;
      ReviewLine(i_lineNo:i_text:'Keywords not converted: ' + l_other);
    else;
      RptItem(C_STS_CONVERTED:i_lineNo:i_text
              :'No printer attribute to override');
    endif;
    return;
  endif;

  AddBody('OVRPRTF FILE(' + l_file + ') ' + l_parms);
  // The override lasts for one job step (CONTINUE-YES: until CONTINUE-NO).
  if not l_isShared;
    TrackOverride(l_file);
  endif;

  select;
    when l_other <> '';
      AddComment('OCL: ' + i_text);
      RptItem(C_STS_REVIEW:i_lineNo:i_text
              :'Keywords not converted: ' + l_other);
    when l_note <> '';
      RptItem(C_STS_ASSUMPTION:i_lineNo:i_text:l_note);
    other;
      RptItem(C_STS_CONVERTED:i_lineNo:i_text:'');
  endsl;
end-proc;

// ------------------------------------------------------------------
// BLDFILE name,type,R|B,size,record-length[,key-length[,retention]]
// S (sequential) and D (direct) files become CRTPF in QTEMP, or in the
// library given as LIBRARY-x; a direct file is also initialised with
// INZPFM. Indexed files
// need a key and are not converted. The size is given in records (R or
// RECORDS) or blocks (B or BLOCKS, 2560 bytes each).
dcl-proc ConvertBldFile;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_operands varchar(512) const;
  end-pi;

  dcl-s l_items varchar(200) dim(C_MAXITEMS);
  dcl-s l_itemCount int(10);
  dcl-s l_itemIndex int(10);
  dcl-s l_isValid ind;
  dcl-s l_name varchar(60);
  dcl-s l_fileType varchar(10);
  dcl-s l_sizeType varchar(10);
  dcl-s l_recordLength int(10);
  dcl-s l_records int(20);
  dcl-s l_extend int(10);
  dcl-s l_retention varchar(10);
  dcl-s l_library varchar(60) inz('QTEMP');
  dcl-s l_keyword varchar(60);
  dcl-s l_value varchar(200);
  dcl-s l_other varchar(200) inz('');
  dcl-s l_note varchar(200) inz('');

  l_itemCount = SplitItems(i_operands:l_items);
  if l_itemCount < 5;
    ReviewLine(i_lineNo:i_text
               :'BLDFILE needs file name, type, size type, size and record length');
    return;
  endif;

  l_name = ConvertOperand(l_items(1):l_isValid);
  if not l_isValid or not IsValidName(l_name:10);
    ReviewLine(i_lineNo:i_text:'BLDFILE file name is not valid or uses an expression');
    return;
  endif;
  l_fileType = ToUpper(l_items(2));
  l_sizeType = ToUpper(l_items(3));
  if not IsPlainNumber(l_items(4):*off) or not IsPlainNumber(l_items(5):*off)
     or (l_sizeType <> 'R' and l_sizeType <> 'RECORDS'
         and l_sizeType <> 'B' and l_sizeType <> 'BLOCKS');
    ReviewLine(i_lineNo:i_text
               :'BLDFILE size type, size or record length is not understood');
    return;
  endif;
  l_recordLength = %int(l_items(5));
  if l_recordLength < 1 or l_recordLength > 32766;
    ReviewLine(i_lineNo:i_text:'BLDFILE record length is out of range');
    return;
  endif;
  if l_sizeType = 'R' or l_sizeType = 'RECORDS';
    l_records = %int(l_items(4));
  else;
    l_records = %int(l_items(4)) * 2560 / l_recordLength;
  endif;
  if l_records < 1 or l_records > 99999999;
    ReviewLine(i_lineNo:i_text:'BLDFILE size is out of range');
    return;
  endif;
  if l_fileType <> 'S' and l_fileType <> 'D';
    ReviewLine(i_lineNo:i_text
               :'Only sequential (S) and direct (D) files are converted');
    return;
  endif;

  // Optional items after the record length: key length, retention, others.
  if l_itemCount >= 6 and %len(l_items(6)) > 0
     and %scan('LIBRARY-':ToUpper(l_items(6))) <> 1;
    l_other = 'key length ' + l_items(6);
  endif;
  if l_itemCount >= 7 and %scan('LIBRARY-':ToUpper(l_items(7))) <> 1;
    l_retention = ToUpper(l_items(7));
    if %len(l_retention) > 0 and l_retention <> 'P' and l_retention <> 'T'
       and l_retention <> 'J';
      l_other += ' retention ' + l_retention;
    endif;
  endif;
  for l_itemIndex = 6 to l_itemCount;
    SplitKeyword(l_items(l_itemIndex):l_keyword:l_value);
    if l_keyword = 'LIBRARY';
      l_library = ConvertOperand(l_value:l_isValid);
      if not l_isValid or not IsValidName(l_library:10);
        ReviewLine(i_lineNo:i_text:'BLDFILE LIBRARY is not valid or uses an expression');
        return;
      endif;
    elseif l_itemIndex >= 8 and %len(l_items(l_itemIndex)) > 0;
      l_other += ' ' + l_items(l_itemIndex);
    endif;
  endfor;
  l_other = %trim(l_other);

  l_extend = %max(32767 / l_recordLength:1);
  AddBody('CRTPF FILE(' + l_library + '/' + l_name + ') RCDLEN('
          + %trim(%char(l_recordLength)) + ') SIZE('
          + %trim(%char(l_records)) + ' ' + %trim(%char(l_extend)) + ' 32767)');
  if l_fileType = 'D';
    AddBody('INZPFM FILE(' + l_library + '/' + l_name + ') RCDNBR('
            + %trim(%char(l_records)) + ')');
  endif;

  select;
    when l_other <> '';
      AddComment('OCL: ' + i_text);
      RptItem(C_STS_REVIEW:i_lineNo:i_text
              :'Not converted: ' + l_other);
    other;
      if l_note = '';
        l_note = 'File created in ' + l_library + '; extend '
                 + %trim(%char(l_extend)) + ' records as the guide default';
      endif;
      RptItem(C_STS_ASSUMPTION:i_lineNo:i_text:l_note);
  endsl;
end-proc;

// ------------------------------------------------------------------
// // LOCAL OFFSET-n,DATA-'text'[,AREA-USER]  ->  CHGDTAARA on *LDA
// IBM's guide shows OFFSET as a 1-based position (for example OFFSET-1).
// The local data area is the S/36 local data area, so *LDA is assumed.
dcl-proc ConvertLocal;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_operands varchar(512) const;
  end-pi;

  dcl-s l_items varchar(200) dim(C_MAXITEMS);
  dcl-s l_itemCount int(10);
  dcl-s l_itemIndex int(10);
  dcl-s l_keyword varchar(60);
  dcl-s l_value varchar(200);
  dcl-s l_offset varchar(60) inz('');
  dcl-s l_data varchar(200) inz('');
  dcl-s l_hasData ind inz(*off);
  dcl-s l_other ind inz(*off);
  dcl-s l_open ind;
  dcl-s l_checkedText varchar(512);
  dcl-s l_dataLength int(10);
  dcl-s l_offsetNumber int(10);
  dcl-s l_variable varchar(20);

  l_itemCount = SplitItems(i_operands:l_items);
  for l_itemIndex = 1 to l_itemCount;
    SplitKeyword(l_items(l_itemIndex):l_keyword:l_value);
    select;
      when l_keyword = 'OFFSET';
        l_offset = l_value;
      when l_keyword = 'DATA';
        l_data = l_value;
        l_hasData = *on;
      when l_keyword = 'AREA' and ToUpper(l_value) = 'USER';
        // accepted, no effect on the output
      other;
        l_other = *on;
    endsl;
  endfor;

  if l_itemCount < 1 or l_other or not l_hasData
     or %len(l_offset) = 0 or %len(l_offset) > 5
     or %check('0123456789':l_offset) > 0;
    ReviewLine(i_lineNo:i_text
               :'LOCAL needs OFFSET-n and DATA-value (AREA-USER allowed) only');
    return;
  endif;
  l_offsetNumber = %int(l_offset);
  if l_offsetNumber < 1;
    ReviewLine(i_lineNo:i_text:'OFFSET 0 is not a valid 1-based position');
    return;
  endif;

  // Strip the quotes round the data.
  if %len(l_data) >= 2 and SafeSubstr(l_data:1:1) = C_QUOTE
     and SafeSubstr(l_data:%len(l_data):1) = C_QUOTE;
    l_data = SafeSubstr(l_data:2:%len(l_data) - 2);
  endif;

  // DATA that is one expression (?DATE?, ?USER?, ?L'p,n'?) uses its variable.
  if %len(l_data) >= 3 and SafeSubstr(l_data:1:1) = '?'
     and SafeSubstr(l_data:%len(l_data):1) = '?'
     and %scan('?':l_data:2) = %len(l_data);
    l_variable = ExpressionVariable(SafeSubstr(l_data:2:%len(l_data) - 2):l_dataLength);
    if l_variable <> '' and SafeSubstr(l_variable:1:2) <> '&P';
      AddBody('CHGDTAARA DTAARA(*LDA (' + %trim(%char(l_offsetNumber)) + ' '
              + %trim(%char(l_dataLength)) + ')) VALUE(' + l_variable + ')');
      RptItem(C_STS_ASSUMPTION:i_lineNo:i_text
              :'OFFSET taken as a 1-based position in the local data area (*LDA)'
              + '; value comes from ' + SafeSubstr(l_data:1:%len(l_data)));
      return;
    endif;
  endif;

  // Other substitution inside the data cannot be expressed by CHGDTAARA VALUE.
  l_checkedText = SubstituteExpressions(l_data:l_open);
  if l_open or l_checkedText <> l_data or %len(l_data) = 0;
    ReviewLine(i_lineNo:i_text
               :'DATA is empty or uses a substitution expression');
    return;
  endif;

  l_dataLength = %len(%scanrpl('''''':' ':l_data));
  AddBody('CHGDTAARA DTAARA(*LDA (' + %trim(%char(l_offsetNumber)) + ' '
          + %trim(%char(l_dataLength)) + ')) VALUE(' + C_QUOTE + l_data
          + C_QUOTE + ')');
  RptItem(C_STS_ASSUMPTION:i_lineNo:i_text
          :'OFFSET taken as a 1-based position in the local data area (*LDA)');
end-proc;

// ------------------------------------------------------------------
// // EVALUATE Pn[,len]=expression ...   (items separated by blanks)
// Parameters are CL variables. A parameter first assigned here (before any
// ?n? read) is a local variable; one read first is a passed parameter.
// Converted: a text or number constant, ?USER?, ?WS?, ?DATE?, ?L'p,n'?,
// ?n?. Arithmetic and other expressions are reported for review.
dcl-proc ConvertEvaluate;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_operands varchar(512) const;
  end-pi;

  dcl-s l_charIndex int(10);
  dcl-s l_char char(1);
  dcl-s l_inQuote ind inz(*off);
  dcl-s l_item varchar(300) inz('');
  dcl-s l_items varchar(300) dim(C_MAXITEMS);
  dcl-s l_itemCount int(10) inz(0);
  dcl-s l_itemIndex int(10);
  dcl-s l_equalPos int(10);
  dcl-s l_target varchar(60);
  dcl-s l_expr varchar(300);
  dcl-s l_commaPos int(10);
  dcl-s l_numberText varchar(10);
  dcl-s l_lenStr varchar(10);
  dcl-s l_parameterNo int(10);
  dcl-s l_length int(10);
  dcl-s l_value varchar(300);
  dcl-s l_variable varchar(20);
  dcl-s l_valueLength int(10);
  dcl-s l_numeric ind;
  dcl-s l_comment varchar(300) inz('');
  dcl-s l_hasProblem ind inz(*off);
  dcl-s l_note ind inz(*off);

  // Split at blanks outside apostrophes and outside ?...? expressions.
  dcl-s l_inExpression ind inz(*off);
  for l_charIndex = 1 to %len(i_operands);
    l_char = SafeSubstr(i_operands:l_charIndex:1);
    if l_char = C_QUOTE;
      l_inQuote = not l_inQuote;
    elseif l_char = '?' and not l_inQuote;
      l_inExpression = not l_inExpression;
    endif;
    if l_char = ' ' and not l_inQuote and not l_inExpression;
      if %len(l_item) > 0 and l_itemCount < C_MAXITEMS;
        l_itemCount += 1;
        l_items(l_itemCount) = l_item;
      endif;
      l_item = '';
    else;
      l_item += l_char;
    endif;
  endfor;
  if %len(l_item) > 0 and l_itemCount < C_MAXITEMS;
    l_itemCount += 1;
    l_items(l_itemCount) = l_item;
  endif;

  for l_itemIndex = 1 to l_itemCount;
    l_equalPos = %scan('=':l_items(l_itemIndex));
    if SafeSubstr(ToUpper(l_items(l_itemIndex)):1:1) <> 'P' or l_equalPos < 3;
      // Not an assignment: anything not recognised is a comment.
      if %len(l_comment) > 0;
        l_comment += ' ';
      endif;
      l_comment += l_items(l_itemIndex);
      iter;
    endif;

    l_target = SafeSubstr(l_items(l_itemIndex):2:l_equalPos - 2);
    l_expr = SafeSubstrToEnd(l_items(l_itemIndex):l_equalPos + 1);
    l_commaPos = %scan(',':l_target);
    if l_commaPos = 0;
      l_numberText = l_target;
      l_lenStr = '';
    else;
      l_numberText = SafeSubstr(l_target:1:l_commaPos - 1);
      l_lenStr = SafeSubstrToEnd(l_target:l_commaPos + 1);
    endif;
    if %len(l_numberText) = 0 or %len(l_numberText) > 2
       or %check('0123456789':l_numberText) > 0
       or (%len(l_lenStr) > 0 and (%len(l_lenStr) > 2
       or %check('0123456789':l_lenStr) > 0));
      ReviewLine(i_lineNo:i_text
                 :'EVALUATE item ' + l_items(l_itemIndex)
                 + ' is not converted (parameter number or length is an expression)');
      l_hasProblem = *on;
      iter;
    endif;
    l_parameterNo = %int(l_numberText);
    l_length = 0;
    if %len(l_lenStr) > 0;
      l_length = %int(l_lenStr);
    endif;
    if l_parameterNo < 1 or l_parameterNo > 40;
      ReviewLine(i_lineNo:i_text
                 :'EVALUATE parameter P' + l_numberText + ' is outside 1 to 40');
      l_hasProblem = *on;
      iter;
    endif;

    // The value
    l_variable = '';
    l_value = '';
    l_numeric = *off;
    l_valueLength = 0;
    select;
      when l_expr = '''''';
        l_value = ' ';
        l_valueLength = 1;
      when %len(l_expr) >= 5 and SafeSubstr(l_expr:1:2) = C_QUOTE + '?'
           and SafeSubstr(l_expr:%len(l_expr) - 1:2) = '?' + C_QUOTE
           and %scan('?':l_expr:3) = %len(l_expr) - 1;
        // '?expr?': one expression written inside apostrophes, for example
        // '?L'201,2'?'. The apostrophes only quote the expression.
        l_variable = ExpressionVariable(
              SafeSubstr(l_expr:3:%len(l_expr) - 4):l_valueLength);
        if l_variable = '';
          ReviewLine(i_lineNo:i_text
                     :'EVALUATE value ' + l_expr + ' is not converted');
          l_hasProblem = *on;
          iter;
        endif;
      when %len(l_expr) >= 2 and SafeSubstr(l_expr:1:1) = C_QUOTE
           and SafeSubstr(l_expr:%len(l_expr):1) = C_QUOTE;
        l_value = SafeSubstr(l_expr:2:%len(l_expr) - 2);
        l_valueLength = %len(%scanrpl('''''':' ':l_value));
      when SafeSubstr(l_expr:1:1) = '?';
        if %len(l_expr) >= 3 and %scan('?':l_expr:2) = %len(l_expr);
          l_variable = ExpressionVariable(
                SafeSubstr(l_expr:2:%len(l_expr) - 2):l_valueLength);
        endif;
        if l_variable = '';
          ReviewLine(i_lineNo:i_text
                     :'EVALUATE value ' + l_expr + ' is not converted');
          l_hasProblem = *on;
          iter;
        endif;
      when %scan('?':l_expr) > 0 or %scan('+':l_expr) > 0
           or %scan('\':l_expr) > 0 or %scan('/':l_expr) > 0
           or %scan('(':l_expr) > 0 or %scan('-':l_expr) > 0
           or %scan('*':l_expr) > 0 or %len(l_expr) = 0;
        ReviewLine(i_lineNo:i_text
                   :'EVALUATE value ' + l_expr
                   + ' (arithmetic or mixed expression) is not converted');
        l_hasProblem = *on;
        iter;
      other;
        l_value = l_expr;
        l_numeric = %check('0123456789':l_expr) = 0;
        if l_numeric;
          // digits only: leading zeros dropped, or padded/cut to the length
          dow %len(l_value) > 1 and SafeSubstr(l_value:1:1) = '0';
            l_value = SafeSubstrToEnd(l_value:2);
          enddo;
          if l_length > 0;
            if %len(l_value) > l_length;
              l_value = SafeSubstrToEnd(l_value:%len(l_value) - l_length + 1);
            else;
              l_value = SafeSubstr('000000000000000':1:
                          l_length - %len(l_value)) + l_value;
            endif;
          endif;
        endif;
        l_valueLength = %len(l_value);
    endsl;

    if g_parameterKind(l_parameterNo) = ' ';
      g_parameterKind(l_parameterNo) = 'L';
    endif;
    if g_parameterKind(l_parameterNo) = 'L';
      g_parameterLength(l_parameterNo) =
         %max(g_parameterLength(l_parameterNo):%max(l_valueLength:1));
    else;
      l_note = *on;
    endif;

    if l_variable <> '';
      AddBody('CHGVAR VAR(&P' + %trim(%char(l_parameterNo))
              + ') VALUE(' + l_variable + ')');
    else;
      AddBody('CHGVAR VAR(&P' + %trim(%char(l_parameterNo)) + ') VALUE(' + C_QUOTE
              + l_value + C_QUOTE + ')');
    endif;
  endfor;

  if %len(l_comment) > 0;
    AddComment(l_comment);
  endif;
  if not l_hasProblem;
    if l_note;
      RptItem(C_STS_ASSUMPTION:i_lineNo:i_text
              :'Assigned parameter is also passed by the caller (CHAR(10))');
    else;
      RptItem(C_STS_CONVERTED:i_lineNo:i_text:'');
    endif;
  endif;
end-proc;

// ------------------------------------------------------------------
// // TAG name  and  // GOTO name
dcl-proc ConvertTagGoto;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_isTag ind const;
    i_operands varchar(512) const;
  end-pi;

  dcl-s l_label varchar(60);
  dcl-s l_extra varchar(512) inz('');
  dcl-s l_blankPos int(10);

  l_label = ToUpper(%trim(i_operands));
  l_blankPos = %scan(' ':l_label);
  if l_blankPos > 0;                      // text after the label is a comment
    l_extra = %trim(SafeSubstrToEnd(%trim(i_operands):l_blankPos + 1));
    l_label = SafeSubstr(l_label:1:l_blankPos - 1);
  endif;
  if not IsValidName(l_label:10) or %scan(' ':l_label) > 0
     or SafeSubstr(l_label:1:1) = '&';
    ReviewLine(i_lineNo:i_text:'Label is not a valid CL label (10 characters)');
    return;
  endif;

  if i_isTag;
    AddBody(l_label + ':');
  else;
    AddBody('GOTO CMDLBL(' + l_label + ')');
  endif;
  if %len(l_extra) > 0;
    AddComment(l_extra);
  endif;
  RptItem(C_STS_CONVERTED:i_lineNo:i_text:'');
end-proc;

// ------------------------------------------------------------------
// Text for a CL literal piece: every quote doubled once for the SQL
// statement and once more for the CL literal.
dcl-proc QuoteSpec;
  dcl-pi *n varchar(512);
    i_text varchar(512) const;
  end-pi;

  return %scanrpl(C_QUOTE:C_QUOTE + C_QUOTE + C_QUOTE + C_QUOTE:i_text);
end-proc;

// ------------------------------------------------------------------
dcl-proc AddTempLine;
  dcl-pi *n;
    i_text varchar(512) const;
  end-pi;

  if g_tempLineCount >= C_MAXTMP;
    g_overflow = *on;
    return;
  endif;
  g_tempLineCount += 1;
  g_tempLines(g_tempLineCount) = i_text;
end-proc;

// ------------------------------------------------------------------
// Maps the inside of a ?...? expression to a CL variable name.
// ?1? to ?9? -> &P1..&P9, ?L'p,n'? -> &Lp_n (local data area text).
// Returns '' when the expression is not supported.
dcl-proc SortSpecVariable;
  dcl-pi *n varchar(20);
    i_token varchar(60) const;
  end-pi;

  dcl-s l_upperToken varchar(60);
  dcl-s l_commaPos int(10);
  dcl-s l_positionText varchar(60);
  dcl-s l_lengthText varchar(60);
  dcl-s l_position int(10);
  dcl-s l_length int(10);
  dcl-s l_index int(10);
  dcl-s l_found ind;

  l_upperToken = ToUpper(%trim(i_token));
  if %len(l_upperToken) = 1 and %check('123456789':l_upperToken) = 0;
    MarkParameterUsed(%int(l_upperToken));
    return '&P' + l_upperToken;
  endif;

  if %len(l_upperToken) >= 6 and SafeSubstr(l_upperToken:1:2) = 'L''' 
     and SafeSubstr(l_upperToken:%len(l_upperToken):1) = '''';
    l_commaPos = %scan(',':l_upperToken);
    if l_commaPos < 4;
      return '';
    endif;
    l_positionText = SafeSubstr(l_upperToken:3:l_commaPos - 3);
    l_lengthText = SafeSubstr(l_upperToken:l_commaPos + 1:
                   %len(l_upperToken) - l_commaPos - 1);
    if %len(l_positionText) = 0 or %len(l_positionText) > 4 or %len(l_lengthText) = 0
       or %len(l_lengthText) > 3 or %check('0123456789':l_positionText) > 0
       or %check('0123456789':l_lengthText) > 0;
      return '';
    endif;
    l_position = %int(l_positionText);
    l_length = %int(l_lengthText);
    if l_position < 1 or l_length < 1 or l_position + l_length > 1025;
      return '';
    endif;

    l_found = *off;
    for l_index = 1 to g_blkCnt;
      if g_blockPosition(l_index) = l_position and g_blockLength(l_index) = l_length;
        l_found = *on;
      endif;
    endfor;
    if not l_found and g_blkCnt < C_MAXLDA;
      g_blkCnt += 1;
      g_blockPosition(g_blkCnt) = l_position;
      g_blockLength(g_blkCnt) = l_length;
    endif;
    l_found = *off;
    for l_index = 1 to g_ldaCnt;
      if g_ldaPosition(l_index) = l_position and g_ldaLength(l_index) = l_length;
        l_found = *on;
      endif;
    endfor;
    if not l_found and g_ldaCnt < C_MAXLDA;
      g_ldaCnt += 1;
      g_ldaPosition(g_ldaCnt) = l_position;
      g_ldaLength(g_ldaCnt) = l_length;
    endif;
    return '&L' + %trim(%char(l_position)) + '_' + %trim(%char(l_length));
  endif;
  return '';
end-proc;

// ------------------------------------------------------------------
// Writes the two statements that insert one specification line into the
// QTEMP source member. ?...? expressions inside the line are replaced by
// the value of a CL variable. Returns *OFF when an expression is not
// supported (o_why says which).
dcl-proc BuildSortInsert;
  dcl-pi *n ind;
    i_member varchar(10) const;
    i_sequence int(10) const;
    i_spec varchar(512) const;
    o_reason varchar(100);
  end-pi;

  dcl-s l_stmt varchar(512);
  dcl-s l_rest varchar(512);
  dcl-s l_openMark int(10);
  dcl-s l_closeMark int(10);
  dcl-s l_literalText varchar(512);
  dcl-s l_variable varchar(20);
  dcl-s l_piecePos int(10);
  dcl-s l_literalLength int(10);
  dcl-s l_piece varchar(512);

  l_stmt = 'CHGVAR VAR(&SQL) VALUE(' + C_QUOTE + 'INSERT INTO QTEMP/'
           + i_member + ' VALUES(' + %trim(%char(i_sequence)) + ',0,'
           + C_QUOTE + C_QUOTE + C_QUOTE;
  l_rest = i_spec;
  dow %len(l_rest) > 0;
    l_openMark = %scan('?':l_rest);
    if l_openMark = 0;
      l_literalText = l_rest;
      l_rest = '';
    else;
      l_closeMark = %scan('?':l_rest:l_openMark + 1);
      if l_closeMark = 0;
        o_reason = 'Unmatched ? in a specification line';
        return *off;
      endif;
      l_variable = SortSpecVariable(SafeSubstr(l_rest:l_openMark + 1:
                     l_closeMark - l_openMark - 1));
      if l_variable = '';
        o_reason = 'Substitution expression '
                + SafeSubstr(l_rest:l_openMark:
                    l_closeMark - l_openMark + 1)
                + ' is not supported in sort specifications';
        return *off;
      endif;
      if l_openMark > 1;
        l_literalText = SafeSubstr(l_rest:1:l_openMark - 1);
      else;
        l_literalText = '';
      endif;
      l_rest = SafeSubstrToEnd(l_rest:l_closeMark + 1);
    endif;

    // The literal part is cut into short pieces joined by *CAT so the CL
    // line can wrap between them.
    l_piecePos = 1;
    l_literalLength = %len(l_literalText);
    dow l_piecePos <= l_literalLength;
      l_piece = SafeSubstr(l_literalText:l_piecePos:
                  %min(30:l_literalLength - l_piecePos + 1));
      l_stmt += ' *CAT ' + C_QUOTE + QuoteSpec(l_piece) + C_QUOTE;
      l_piecePos += 30;
    enddo;
    if l_openMark > 0;
      l_stmt += ' *CAT ' + l_variable;
    endif;
  enddo;
  l_stmt += ' *CAT ' + C_QUOTE + C_QUOTE + C_QUOTE + ')' + C_QUOTE + ')';
  AddTempLine(l_stmt);
  AddTempLine('RUNSQL SQL(&SQL) COMMIT(*NONE) NAMING(*SYS)');
  return *on;
end-proc;

// ------------------------------------------------------------------
// Analyses a conditional line  // IF|IFT|IFF cond spec   or  // ELSE spec.
// o_kind: 'I' (IF, IFT), 'F' (IFF) or 'E' (ELSE). For IF/IFF the condition
// must be  ?expr?/value  or  ?expr?=value. o_spec is the text after the
// condition (one blank separates them), empty when there is none.
dcl-proc ParseSortCondition;
  dcl-pi *n ind;
    i_line varchar(512) const;
    o_kind char(1);
    o_variable varchar(20);
    o_literal varchar(128);
    o_spec varchar(512);
    o_reason varchar(100);
  end-pi;

  dcl-s l_lineText varchar(512);
  dcl-s l_textStart int(10);
  dcl-s l_keywordEnd int(10);
  dcl-s l_keyword varchar(10);
  dcl-s l_cond varchar(512);
  dcl-s l_left varchar(512);
  dcl-s l_right varchar(512);
  dcl-s l_charIndex int(10);
  dcl-s l_inQuote ind;
  dcl-s l_inExpression ind;
  dcl-s l_char char(1);
  dcl-s l_split int(10);
  dcl-s l_firstWords varchar(10);

  o_variable = '';
  o_literal = '';
  o_spec = '';
  l_lineText = %trimr(i_line);
  l_textStart = 3;
  dow l_textStart <= %len(l_lineText) and SafeSubstr(l_lineText:l_textStart:1) = ' ';
    l_textStart += 1;
  enddo;
  l_keywordEnd = %scan(' ':l_lineText:l_textStart);
  if l_keywordEnd = 0;
    l_keyword = ToUpper(SafeSubstrToEnd(l_lineText:l_textStart));
    l_keywordEnd = %len(l_lineText) + 1;
  else;
    l_keyword = ToUpper(SafeSubstr(l_lineText:l_textStart:l_keywordEnd - l_textStart));
  endif;

  if l_keyword = 'ELSE';
    o_kind = 'E';
    if l_keywordEnd < %len(l_lineText);
      o_spec = SafeSubstrToEnd(l_lineText:l_keywordEnd + 1);
    endif;
  else;
    if l_keyword = 'IF' or l_keyword = 'IFT';
      o_kind = 'I';
    else;
      o_kind = 'F';
    endif;
    l_textStart = l_keywordEnd;
    dow l_textStart <= %len(l_lineText) and SafeSubstr(l_lineText:l_textStart:1) = ' ';
      l_textStart += 1;
    enddo;
    // The condition ends at the first blank outside apostrophes.
    l_inQuote = *off;
    l_charIndex = l_textStart;
    dow l_charIndex <= %len(l_lineText);
      if SafeSubstr(l_lineText:l_charIndex:1) = C_QUOTE;
        l_inQuote = not l_inQuote;
      endif;
      if SafeSubstr(l_lineText:l_charIndex:1) = ' ' and not l_inQuote;
        leave;
      endif;
      l_charIndex += 1;
    enddo;
    l_cond = SafeSubstr(l_lineText:l_textStart:l_charIndex - l_textStart);
    if l_charIndex < %len(l_lineText);
      o_spec = SafeSubstrToEnd(l_lineText:l_charIndex + 1);
    endif;

    // Split at the first / or = outside ?...? and apostrophes.
    l_split = 0;
    l_inQuote = *off;
    l_inExpression = *off;
    for l_charIndex = 1 to %len(l_cond);
      l_char = SafeSubstr(l_cond:l_charIndex:1);
      if l_char = C_QUOTE;
        l_inQuote = not l_inQuote;
      elseif l_char = '?' and not l_inQuote;
        l_inExpression = not l_inExpression;
      elseif (l_char = '/' or l_char = '=') and not l_inQuote and not l_inExpression;
        l_split = l_charIndex;
        leave;
      endif;
    endfor;
    if l_split < 3;
      o_reason = 'Condition is not of the form ?expression?/value';
      return *off;
    endif;
    l_left = SafeSubstr(l_cond:1:l_split - 1);
    if l_split < %len(l_cond);
      l_right = SafeSubstrToEnd(l_cond:l_split + 1);
    else;
      l_right = '';
    endif;
    if %len(l_left) < 3 or SafeSubstr(l_left:1:1) <> '?'
       or SafeSubstr(l_left:%len(l_left):1) <> '?';
      o_reason = 'Left side of the condition is not a substitution expression';
      return *off;
    endif;
    o_variable = SortSpecVariable(SafeSubstr(l_left:2:%len(l_left) - 2));
    if o_variable = '';
      o_reason = 'Condition expression ' + l_left + ' is not supported';
      return *off;
    endif;
    if %scan('?':l_right) > 0;
      o_reason = 'Right side of the condition uses an expression';
      return *off;
    endif;
    if %len(l_right) >= 2 and SafeSubstr(l_right:1:1) = C_QUOTE
       and SafeSubstr(l_right:%len(l_right):1) = C_QUOTE;
      l_right = %scanrpl('''''':'''':SafeSubstr(l_right:2:%len(l_right) - 2));
    endif;
    if %len(l_right) = 0;
      l_right = ' ';
    endif;
    o_literal = l_right;
  endif;

  // A nested IF in the statement part is not converted.
  l_firstWords = ToUpper(SafeSubstr(%trim(o_spec) + '    ':1:4));
  if SafeSubstr(l_firstWords:1:3) = 'IF ' or SafeSubstr(l_firstWords:1:4) = 'IFF '
     or SafeSubstr(l_firstWords:1:4) = 'IFT ' or SafeSubstr(l_firstWords:1:5) = 'ELSE ';
    o_reason = 'Nested IF/ELSE on one line is not converted';
    return *off;
  endif;
  return *on;
end-proc;

// ------------------------------------------------------------------
// Writes the collected #GSORT step as FMTDTA. The specification lines
// (copied unchanged) are inserted into a QTEMP source member by CL at run
// time, so conditional lines (// IF, // IFF, // ELSE) can test the local
// data area or a parameter when the program runs. Anything that cannot be
// converted leaves the whole block as comments.
dcl-proc WriteSortStep;
  dcl-pi *n;
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_memberName varchar(10);
  dcl-s l_kind char(1);
  dcl-s l_variable varchar(20);
  dcl-s l_literal varchar(128);
  dcl-s l_spec varchar(512);
  dcl-s l_reason varchar(100);
  dcl-s l_isValid ind inz(*on);
  dcl-s l_lastKind char(1) inz(' ');
  dcl-s l_lastVar varchar(20) inz('');
  dcl-s l_lastLit varchar(128) inz('');
  dcl-s l_cond varchar(200);
  dcl-s l_operator varchar(5);
  dcl-s l_sequence int(10) inz(0);
  dcl-s l_inputList varchar(300) inz('');
  dcl-s l_inCnt int(10) inz(0);
  dcl-s l_outputName varchar(130);
  dcl-s l_command varchar(512);
  dcl-s l_hasCond ind inz(*off);
  dcl-s l_fileReference varchar(130);

  g_sortMode = *off;
  g_sortNo += 1;
  l_memberName = 'IASORT' + %trim(%char(g_sortNo));
  g_blkCnt = 0;
  g_tempLineCount = 0;

  // Files
  for l_index = 1 to 8;
    if g_sortIn(l_index) <> '';
      l_fileReference = g_sortIn(l_index);
      if g_sortInLib(l_index) <> '';
        l_fileReference = g_sortInLib(l_index) + '/' + g_sortIn(l_index);
      endif;
      l_inCnt += 1;
      if l_inCnt = 1;
        l_inputList = l_fileReference;
      else;
        l_inputList += ' ' + l_fileReference;
      endif;
    endif;
  endfor;
  if g_sortOut <> '' and g_sortOutLib <> '';
    l_outputName = g_sortOutLib + '/' + g_sortOut;
  else;
    l_outputName = g_sortOut;
  endif;
  if l_inCnt = 0 or g_sortOut = '';
    l_isValid = *off;
    l_reason = 'FILE NAME-INPUT and NAME-OUTPUT are both needed';
  endif;
  if l_isValid and g_sortSrcMbr = '' and g_sortCnt = 0;
    l_isValid = *off;
    l_reason = 'No sort specification lines found';
  endif;

  // Specification lines
  if l_isValid and g_sortSrcMbr = '';
    for l_index = 1 to g_sortCnt;
      l_hasCond = *off;
      if %len(%trim(g_sortLines(l_index))) >= 2
         and SafeSubstr(%trim(g_sortLines(l_index)):1:2) = '//';
        if not ParseSortCondition(g_sortLines(l_index):l_kind:l_variable:
                 l_literal:l_spec:l_reason);
          l_isValid = *off;
          leave;
        endif;
        l_hasCond = *on;
        if l_kind = 'E';
          if l_lastKind = ' ';
            l_isValid = *off;
            l_reason = 'ELSE without a preceding IF on the line before';
            leave;
          endif;
          l_variable = l_lastVar;
          l_literal = l_lastLit;
          if l_lastKind = 'I';
            l_kind = 'F';
          else;
            l_kind = 'I';
          endif;
          l_lastKind = ' ';
        else;
          l_lastKind = l_kind;
          l_lastVar = l_variable;
          l_lastLit = l_literal;
        endif;
        if %len(%trim(l_spec)) = 0;
          l_isValid = *off;
          l_reason = 'IF/ELSE line has no specification text after the condition';
          leave;
        endif;
        // The statement part supplies columns 4 onward of the line.
        l_spec = %trimr('   ' + l_spec);
        if %len(l_spec) < 6 or (SafeSubstr(l_spec:6:1) <> 'H'
           and SafeSubstr(l_spec:6:1) <> 'I' and SafeSubstr(l_spec:6:1) <> 'F');
          l_isValid = *off;
          l_reason = 'Text after the condition is not a sort specification';
          leave;
        endif;
      else;
        l_spec = g_sortLines(l_index);
        l_lastKind = ' ';
      endif;

      l_sequence += 1;
      if l_hasCond;
        if l_kind = 'I';
          l_operator = '*EQ';
        else;
          l_operator = '*NE';
        endif;
        l_cond = l_variable + ' ' + l_operator + ' ' + C_QUOTE
                 + %scanrpl(C_QUOTE:C_QUOTE + C_QUOTE:l_literal) + C_QUOTE;
        AddTempLine('IF COND(' + l_cond + ') THEN(DO)');
      endif;
      if not BuildSortInsert(l_memberName:l_sequence:l_spec:l_reason);
        l_isValid = *off;
        leave;
      endif;
      if l_hasCond;
        AddTempLine('ENDDO');
      endif;
    endfor;
  endif;

  if g_sortSrcMbr <> '' and g_sortSrcLib = '#LIBRARY';
    l_isValid = *off;
    l_reason = 'SOURCE with #LIBRARY is not converted';
  endif;

  if not l_isValid or g_overflow;
    AddComment('OCL: sort step (#GSORT) not converted');
    for l_index = 1 to g_sortCnt;
      AddCommentKeepingText(' ' + g_sortLines(l_index));
    endfor;
    RptItem(C_STS_REVIEW:g_sortFirst:'#GSORT step':l_reason);
    return;
  endif;

  g_useSql = *on;
  if g_sortSrcMbr <> '';
    AddBody('FMTDTA INFILE(' + %trim(l_inputList) + ') OUTFILE(' + l_outputName
            + ') SRCFILE(' + g_sortSrcLib + '/QS36SRC) SRCMBR('
            + g_sortSrcMbr + ')');
    RptItem(C_STS_ASSUMPTION:g_sortFirst:'#GSORT step'
            :'// SOURCE member read from file QS36SRC in the named library');
  else;
    for l_index = 1 to g_blkCnt;
      AddBody('RTVDTAARA DTAARA(*LDA (' + %trim(%char(g_blockPosition(l_index))) + ' '
              + %trim(%char(g_blockLength(l_index))) + ')) RTNVAR(&L'
              + %trim(%char(g_blockPosition(l_index))) + '_'
              + %trim(%char(g_blockLength(l_index))) + ')');
    endfor;
    AddBody('DLTF FILE(QTEMP/' + l_memberName + ')');
    AddBody('MONMSG MSGID(CPF2105)');
    AddBody('CRTSRCPF FILE(QTEMP/' + l_memberName + ') RCDLEN(112) MBR(' + l_memberName
            + ') CCSID(65535)');
    for l_index = 1 to g_tempLineCount;
      AddBody(g_tempLines(l_index));
    endfor;
    l_command = 'FMTDTA INFILE(';
    if l_inCnt > 1;
      l_command += '(' + %scanrpl(' ':') (':%trim(l_inputList)) + ')';
    else;
      l_command += %trim(l_inputList);
    endif;
    l_command += ') OUTFILE(' + l_outputName + ') SRCFILE(QTEMP/'
             + l_memberName + ') SRCMBR('
             + l_memberName + ')';
    AddBody(l_command);
    RptItem(C_STS_ASSUMPTION:g_sortFirst:'#GSORT step'
            :'Mapped to FMTDTA; specification lines are copied unchanged into '
            + 'QTEMP/' + l_memberName + ' (CCSID 65535) by RUNSQL');
  endif;

  if g_conditions;
    RptItem(C_STS_ASSUMPTION:g_sortFirst:'#GSORT conditions'
            :'IF/IFF/ELSE compared as text; statement text taken to start at '
            + 'column 4 of the specification line');
  endif;
  if g_sortExtra <> '';
    RptItem(C_STS_REVIEW:g_sortFirst:'FILE NAME-OUTPUT'
            :'Output file keywords not converted: ' + g_sortExtra
            + '. Create the output file before FMTDTA if it does not exist');
  endif;
end-proc;

// ------------------------------------------------------------------
// The data lines of a #GSORT step are collected until // END, /*, // SOURCE
// or the next statement. Returns *ON when the line was taken as part of
// the block.
dcl-proc CollectSortLine;
  dcl-pi *n ind;
    i_lineNo int(10) const;
    i_text varchar(512) const;
  end-pi;

  dcl-s l_lineText varchar(512);
  dcl-s l_keyword varchar(60);
  dcl-s l_textStart int(10);
  dcl-s l_keywordEnd int(10);
  dcl-s l_items varchar(200) dim(C_MAXITEMS);
  dcl-s l_itemCount int(10);

  l_lineText = %trim(i_text);
  if %len(l_lineText) = 0;
    return *on;
  endif;

  if %len(l_lineText) >= 2 and SafeSubstr(l_lineText:1:2) = '//';
    // The keyword follows the slashes after optional blanks (// IF ...).
    l_textStart = 3;
    dow l_textStart <= %len(l_lineText) and SafeSubstr(l_lineText:l_textStart:1) = ' ';
      l_textStart += 1;
    enddo;
    l_keywordEnd = %scan(' ':l_lineText:l_textStart);
    if l_keywordEnd = 0;
      l_keyword = ToUpper(SafeSubstrToEnd(l_lineText:l_textStart));
      l_textStart = 0;
    else;
      l_keyword = ToUpper(SafeSubstr(l_lineText:l_textStart:l_keywordEnd - l_textStart));
      l_textStart = l_keywordEnd;
    endif;
    select;
      when l_keyword = 'END';             // ends the inline data of the step
        WriteSortStep();
        RptItem(C_STS_CONVERTED:i_lineNo:i_text:'');
        return *on;
      when l_keyword = 'SOURCE';          // specifications come from a member
        if l_textStart > 0;
          l_itemCount = SplitItems(
                %trim(SafeSubstrToEnd(l_lineText:l_textStart + 1)):l_items);
        else;
          l_itemCount = 0;
        endif;
        if l_itemCount = 2;
          g_sortSrcMbr = ToUpper(l_items(1));
          g_sortSrcLib = ToUpper(l_items(2));
        endif;
        WriteSortStep();
        RptItem(C_STS_CONVERTED:i_lineNo:i_text:'');
        return *on;
      when l_keyword = 'IF' or l_keyword = 'IFT' or l_keyword = 'IFF'
           or l_keyword = 'ELSE';
        g_conditions = *on;
        if g_sortCnt < C_MAXSORT;
          g_sortCnt += 1;
          g_sortLines(g_sortCnt) = %trimr(i_text);
        else;
          g_overflow = *on;
        endif;
        return *on;
      other;
        WriteSortStep();
        return *off;
    endsl;
  endif;

  if SafeSubstr(l_lineText:1:1) = '/' and %len(l_lineText) >= 2
     and (SafeSubstr(l_lineText:2:1) = '*' or SafeSubstr(l_lineText:2:1) = '&');
    WriteSortStep();
    RptItem(C_STS_CONVERTED:i_lineNo:i_text:'');
    return *on;
  endif;

  if g_sortCnt < C_MAXSORT;
    g_sortCnt += 1;
    g_sortLines(g_sortCnt) = %trimr(i_text);
  else;
    g_overflow = *on;
  endif;
  return *on;
end-proc;

// ------------------------------------------------------------------
// Removes a trailing comment  /\ text \/  (outside quotes) from the
// statement text and returns its text (empty when there is none).
dcl-proc StripTrailingComment;
  dcl-pi *n varchar(512);
    io_statement varchar(512);
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_inQuote ind inz(*off);
  dcl-s l_comment varchar(512) inz('');

  for l_index = 1 to %len(io_statement) - 1;
    if SafeSubstr(io_statement:l_index:1) = C_QUOTE;
      l_inQuote = not l_inQuote;
    endif;
    if not l_inQuote and SafeSubstr(io_statement:l_index:2) = '/\';
      l_comment = %trim(SafeSubstrToEnd(io_statement:l_index + 2));
      io_statement = %trim(SafeSubstr(io_statement:1:l_index - 1));
      if %len(l_comment) >= 2 and SafeSubstr(l_comment:%len(l_comment) - 1:2) = '\/';
        l_comment = %trim(SafeSubstr(l_comment:1:%len(l_comment) - 2));
      endif;
      return l_comment;
    endif;
  endfor;
  return '';
end-proc;

// ------------------------------------------------------------------
// One operand of a condition as a CL operand: a variable for a single
// ?...? expression, otherwise a quoted constant. '' when not supported.
dcl-proc ConditionOperand;
  dcl-pi *n varchar(60);
    i_text varchar(200) const;
  end-pi;

  dcl-s l_variableLength int(10);
  dcl-s l_value varchar(200);

  if %len(i_text) = 0;
    return C_QUOTE + ' ' + C_QUOTE;
  endif;
  if SafeSubstr(i_text:1:1) = '?';
    if %len(i_text) >= 3 and SafeSubstr(i_text:%len(i_text):1) = '?'
       and %scan('?':i_text:2) = %len(i_text);
      return ExpressionVariable(SafeSubstr(i_text:2:%len(i_text) - 2):l_variableLength);
    endif;
    return '';
  endif;
  if %scan('?':i_text) > 0;
    return '';
  endif;
  l_value = i_text;
  if %len(l_value) >= 2 and SafeSubstr(l_value:1:1) = C_QUOTE
     and SafeSubstr(l_value:%len(l_value):1) = C_QUOTE;
    // inner text, doubled quotes kept
    l_value = SafeSubstr(l_value:2:%len(l_value) - 2);
  else;
    l_value = %scanrpl(C_QUOTE:C_QUOTE + C_QUOTE:l_value);
  endif;
  if %len(l_value) = 0;
    l_value = ' ';
  endif;
  return C_QUOTE + l_value + C_QUOTE;
end-proc;

// ------------------------------------------------------------------
// DATAF1-name: true when the file (with at least one member) or the library
// exists. Writes the CHKOBJ statements that set a logical variable &Dn and
// returns it, or '' for the forms not converted: 'name,date' and 'name,ALL'.
dcl-proc DataFileCondition;
  dcl-pi *n varchar(200);
    i_operand varchar(300) const;
  end-pi;

  dcl-s l_text varchar(300);
  dcl-s l_name varchar(60);
  dcl-s l_flag varchar(10);
  dcl-s l_isValid ind;
  dcl-s l_commaPos int(10);
  dcl-s l_allForm ind inz(*off);
  dcl-s l_rest varchar(300);
  dcl-s l_keyword varchar(60);
  dcl-s l_libraries varchar(200) inz('');
  dcl-s l_restComma int(10);

  l_text = i_operand;
  if %len(l_text) >= 2 and SafeSubstr(l_text:1:1) = C_QUOTE
     and SafeSubstr(l_text:%len(l_text):1) = C_QUOTE;
    l_text = SafeSubstr(l_text:2:%len(l_text) - 2);
  endif;
  // 'name,ALL' and 'name,ALL,library1,library2,...' are converted (the
  // libraries are searched as well as the library list); 'name,date' is not.
  l_commaPos = %scan(',':l_text);
  if l_commaPos > 0;
    l_rest = %trim(SafeSubstrToEnd(l_text:l_commaPos + 1));
    l_restComma = %scan(',':l_rest);
    if l_restComma = 0;
      l_keyword = l_rest;
    else;
      l_keyword = %trim(SafeSubstr(l_rest:1:l_restComma - 1));
      l_libraries = %trim(SafeSubstrToEnd(l_rest:l_restComma + 1));
    endif;
    if ToUpper(l_keyword) <> 'ALL';
      return '';
    endif;
    l_allForm = *on;
    l_text = %trim(SafeSubstr(l_text:1:l_commaPos - 1));
  endif;
  if %len(l_text) = 0 or %scan(C_QUOTE:l_text) > 0;
    return '';
  endif;
  if %scan('?':l_text) = 0
     and (%len(l_text) > 10
          or %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_#@$':ToUpper(l_text)) > 0);
    return '';
  endif;
  l_name = ConvertOperand(l_text:l_isValid);
  if not l_isValid or l_name = '';
    return '';
  endif;
  if l_allForm;
    return DataFileAllCondition(l_name:l_libraries);
  endif;

  g_dataf1Count += 1;
  l_flag = '&D' + %trim(%char(g_dataf1Count));
  AddBody('CHGVAR VAR(' + l_flag + ') VALUE(''1'')');
  AddBody('CHKOBJ OBJ(' + l_name + ') OBJTYPE(*FILE) MBR(*FIRST)');
  AddBody('MONMSG MSGID(CPF0000) EXEC(CHGVAR VAR(' + l_flag + ') VALUE(''0''))');
  AddBody('IF COND(*NOT ' + l_flag + ') THEN(DO)');
  AddBody('CHGVAR VAR(' + l_flag + ') VALUE(''1'')');
  AddBody('CHKOBJ OBJ(QSYS/' + l_name + ') OBJTYPE(*LIB)');
  AddBody('MONMSG MSGID(CPF0000) EXEC(CHGVAR VAR(' + l_flag + ') VALUE(''0''))');
  AddBody('ENDDO');
  RptItem(C_STS_ASSUMPTION:g_curLineNo:g_curText
          :'DATAF1 tested with CHKOBJ on the library list (file with a member, '
          + 'or library)');
  return l_flag;
end-proc;

// ------------------------------------------------------------------
// DATAF1-'name,ALL[,library1,...]': true when a file or library whose name
// starts with the text exists (SC41-4731, "DATAF1 (Files and Libraries on
// Disk) Condition"). Files are looked for in C_ALLSCOPE (the library list)
// and in the extra libraries given, libraries in QSYS.
// DSPOBJD with a generic name writes them to QTEMP/IAOBJD and RTVMBRD counts
// the rows. Returns the logical variable &Dn.
dcl-proc DataFileAllCondition;
  dcl-pi *n varchar(200);
    i_name varchar(60) const;
    i_libraries varchar(200) const;     // extra libraries, comma separated
  end-pi;

  dcl-s l_flag varchar(10);
  dcl-s l_generic varchar(60);
  dcl-s l_libraryItems varchar(200) dim(C_MAXITEMS);
  dcl-s l_libraryNames varchar(60) dim(C_MAXITEMS);
  dcl-s l_libraryCount int(10);
  dcl-s l_index int(10);
  dcl-s l_isValid ind;

  l_libraryCount = SplitItems(i_libraries:l_libraryItems);
  for l_index = 1 to l_libraryCount;
    l_libraryNames(l_index) = ConvertOperand(l_libraryItems(l_index):l_isValid);
    if not l_isValid or not IsValidName(l_libraryNames(l_index):10);
      return '';
    endif;
  endfor;

  g_dataf1Count += 1;
  l_flag = '&D' + %trim(%char(g_dataf1Count));
  g_useFileSize = *on;                     // &FSN is used for the row count
  if SafeSubstr(i_name:1:1) = '&';         // a variable: add the * at run time
    g_tempVariableCount += 1;
    l_generic = '&T' + %trim(%char(g_tempVariableCount));
    AddBody('CHGVAR VAR(' + l_generic + ') VALUE(' + i_name + ' *TCAT ''*'')');
  else;
    l_generic = i_name + '*';
  endif;
  AddBody('CHGVAR VAR(' + l_flag + ') VALUE(''0'')');
  AddBody('DLTF FILE(QTEMP/IAOBJD)');
  AddBody('MONMSG MSGID(CPF0000)');
  AddBody('DSPOBJD OBJ(' + C_ALLSCOPE + '/' + l_generic + ') OBJTYPE(*FILE) '
          + 'OUTPUT(*OUTFILE) OUTFILE(QTEMP/IAOBJD) OUTMBR(*FIRST *REPLACE)');
  AddBody('MONMSG MSGID(CPF0000)');
  for l_index = 1 to l_libraryCount;
    AddBody('DSPOBJD OBJ(' + l_libraryNames(l_index) + '/' + l_generic
            + ') OBJTYPE(*FILE) OUTPUT(*OUTFILE) OUTFILE(QTEMP/IAOBJD) '
            + 'OUTMBR(*FIRST *ADD)');
    AddBody('MONMSG MSGID(CPF0000)');
  endfor;
  AddBody('DSPOBJD OBJ(QSYS/' + l_generic + ') OBJTYPE(*LIB) '
          + 'OUTPUT(*OUTFILE) OUTFILE(QTEMP/IAOBJD) OUTMBR(*FIRST *ADD)');
  AddBody('MONMSG MSGID(CPF0000)');
  AddBody('CHGVAR VAR(&FSN) VALUE(0)');
  AddBody('RTVMBRD FILE(QTEMP/IAOBJD) MBR(*FIRST) NBRCURRCD(&FSN)');
  AddBody('MONMSG MSGID(CPF0000) EXEC(CHGVAR VAR(&FSN) VALUE(0))');
  AddBody('IF COND(&FSN *GT 0) THEN(CHGVAR VAR(' + l_flag + ') VALUE(''1''))');
  RptItem(C_STS_ASSUMPTION:g_curLineNo:g_curText
          :'DATAF1 name,ALL tested with DSPOBJD on names starting with the text '
          + '(files in ' + C_ALLSCOPE
          + %trimr(' and ' + %trim(i_libraries)) + ', libraries in QSYS)');
  return l_flag;
end-proc;

// ------------------------------------------------------------------
// ACTIVE-name or ACTIVE-'name1,name2,...': true when any of the procedures
// is running. Every converted program holds a shared lock on a marker data
// area named after its OCL procedure (see WriteProgram), so the test tries
// an exclusive ALCOBJ on it: CPF1002 means the procedure is running.
// Writes the statements that set a logical variable &An and returns it, or
// '' when a name cannot be used.
dcl-proc ActiveCondition;
  dcl-pi *n varchar(200);
    i_operand varchar(300) const;
  end-pi;

  dcl-s l_text varchar(300);
  dcl-s l_rest varchar(300);
  dcl-s l_item varchar(60);
  dcl-s l_name varchar(60);
  dcl-s l_names varchar(60) dim(C_MAXACTIVE);
  dcl-s l_nameCnt int(10) inz(0);
  dcl-s l_commaPos int(10);
  dcl-s l_index int(10);
  dcl-s l_flag varchar(10);
  dcl-s l_isValid ind;

  l_text = i_operand;
  if %len(l_text) >= 2 and SafeSubstr(l_text:1:1) = C_QUOTE
     and SafeSubstr(l_text:%len(l_text):1) = C_QUOTE;
    l_text = SafeSubstr(l_text:2:%len(l_text) - 2);
  endif;
  if %len(l_text) = 0;
    return '';
  endif;

  l_rest = l_text;
  dow *on;
    l_commaPos = %scan(',':l_rest);
    if l_commaPos = 0;
      l_item = %trim(l_rest);
    else;
      l_item = %trim(SafeSubstr(l_rest:1:l_commaPos - 1));
    endif;
    if %len(l_item) = 0 or %scan(C_QUOTE:l_item) > 0 or l_nameCnt >= C_MAXACTIVE;
      return '';
    endif;
    if %scan('?':l_item) = 0
       and (%len(l_item) > 10
            or %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_#@$':ToUpper(l_item)) > 0);
      return '';
    endif;
    l_nameCnt += 1;
    l_names(l_nameCnt) = l_item;
    if l_commaPos = 0;
      leave;
    endif;
    l_rest = SafeSubstrToEnd(l_rest:l_commaPos + 1);
  enddo;

  g_activeCount += 1;
  l_flag = '&A' + %trim(%char(g_activeCount));
  AddBody('CHGVAR VAR(' + l_flag + ') VALUE(''0'')');
  for l_index = 1 to l_nameCnt;
    l_name = ConvertOperand(l_names(l_index):l_isValid);
    if not l_isValid or l_name = '';
      return '';
    endif;
    AddBody('ALCOBJ OBJ((' + C_MARKLIB + '/' + l_name + ' *DTAARA *EXCL)) WAIT(0)');
    AddBody('MONMSG MSGID(CPF1002) EXEC(CHGVAR VAR(' + l_flag + ') VALUE(''1''))');
    AddBody('MONMSG MSGID(CPF0000)');
    AddBody('DLCOBJ OBJ((' + C_MARKLIB + '/' + l_name + ' *DTAARA *EXCL))');
    AddBody('MONMSG MSGID(CPF0000)');
  endfor;
  RptItem(C_STS_ASSUMPTION:g_curLineNo:g_curText
          :'ACTIVE tested with an exclusive ALCOBJ on the marker data area '
          + C_MARKLIB + '/name; the procedure must hold a shared lock on it');
  return l_flag;
end-proc;

// ------------------------------------------------------------------
// A condition string as a CL expression: value1/value2 and value1=value2
// (equal, compared as text) and SWITCHn-0 / SWITCHn-1. '' when the
// condition is not supported.
dcl-proc ConditionExpression;
  dcl-pi *n varchar(200);
    i_cond varchar(300) const;
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_char char(1);
  dcl-s l_inQuote ind inz(*off);
  dcl-s l_inExpression ind inz(*off);
  dcl-s l_split int(10) inz(0);
  dcl-s l_left varchar(200);
  dcl-s l_right varchar(200);
  dcl-s l_leftOperand varchar(60);
  dcl-s l_rightOperand varchar(60);
  dcl-s l_mask varchar(8);
  dcl-s l_upperCondition varchar(300);

  l_upperCondition = ToUpper(i_cond);
  if %len(l_upperCondition) > 7 and SafeSubstr(l_upperCondition:1:7) = 'ACTIVE-';
    return ActiveCondition(SafeSubstrToEnd(i_cond:8));
  endif;
  if %len(l_upperCondition) > 7 and SafeSubstr(l_upperCondition:1:7) = 'DATAF1-';
    return DataFileCondition(SafeSubstrToEnd(i_cond:8));
  endif;
  if %len(l_upperCondition) = 9 and SafeSubstr(l_upperCondition:1:6) = 'SWITCH'
     and %check('12345678':SafeSubstr(l_upperCondition:7:1)) = 0
     and SafeSubstr(l_upperCondition:8:1) = '-'
     and %check('01':SafeSubstr(l_upperCondition:9:1)) = 0;
    l_mask = 'XXXXXXXX';
    %subst(l_mask:%int(%subst(l_upperCondition:7:1)):1) =
       SafeSubstr(l_upperCondition:9:1);
    return '%SWITCH(' + l_mask + ')';
  endif;

  for l_index = 1 to %len(i_cond);
    l_char = SafeSubstr(i_cond:l_index:1);
    if l_char = C_QUOTE;
      l_inQuote = not l_inQuote;
    elseif l_char = '?' and not l_inQuote;
      l_inExpression = not l_inExpression;
    elseif (l_char = '/' or l_char = '=') and not l_inQuote and not l_inExpression;
      l_split = l_index;
      leave;
    endif;
  endfor;
  if l_split = 0;
    return '';
  endif;
  if l_split > 1;
    l_left = SafeSubstr(i_cond:1:l_split - 1);
  else;
    l_left = '';
  endif;
  if l_split < %len(i_cond);
    l_right = SafeSubstrToEnd(i_cond:l_split + 1);
  else;
    l_right = '';
  endif;
  l_leftOperand = ConditionOperand(l_left);
  l_rightOperand = ConditionOperand(l_right);
  if l_leftOperand = '' or l_rightOperand = '';
    return '';
  endif;
  return l_leftOperand + ' *EQ ' + l_rightOperand;
end-proc;

// ------------------------------------------------------------------
// The opposite of a CL condition. A single comparison (a *EQ b) becomes
// a *NE b; a logical variable (&D1) becomes *NOT &D1; anything else is
// wrapped in *NOT (...).
dcl-proc NegateCondition;
  dcl-pi *n varchar(200);
    i_cond varchar(200) const;
  end-pi;

  dcl-s l_eqPos int(10);

  l_eqPos = %scan(' *EQ ':i_cond);
  if l_eqPos > 0 and %scan(' *EQ ':i_cond:l_eqPos + 1) = 0
     and %scan(' *AND ':i_cond) = 0 and %scan(' *OR ':i_cond) = 0
     and %scan('*NOT':i_cond) = 0 and %scan('%':i_cond) = 0
     and %scan('(':i_cond) = 0;
    return SafeSubstr(i_cond:1:l_eqPos) + '*NE ' + SafeSubstrToEnd(i_cond:l_eqPos + 5);
  endif;
  if SafeSubstr(i_cond:1:1) = '&' and %scan(' ':i_cond) = 0;
    return '*NOT ' + i_cond;
  endif;
  return '*NOT (' + i_cond + ')';
end-proc;

// ------------------------------------------------------------------
// Takes the leading IF / IFT / IFF / ELSE words off the statement text and
// returns the CL condition they make (empty when there are none). An ELSE
// must be the first word and refers to the IF on the line before it.
// Returns *OFF (with o_why) when a condition cannot be converted.
dcl-proc ParseIfPrefix;
  dcl-pi *n ind;
    io_statement varchar(512);
    o_cond varchar(500);
    o_reason varchar(100);
  end-pi;

  dcl-s l_keyword varchar(10);
  dcl-s l_blankPos int(10);
  dcl-s l_index int(10);
  dcl-s l_inQuote ind;
  dcl-s l_conditionToken varchar(300);
  dcl-s l_converted varchar(200);
  dcl-s l_lineLast varchar(500) inz('');
  dcl-s l_elseCond varchar(500) inz('');
  dcl-s l_sawIf ind inz(*off);
  dcl-s l_sawElse ind inz(*off);

  o_cond = '';
  dow *on;
    l_blankPos = %scan(' ':io_statement);
    if l_blankPos = 0;
      l_keyword = ToUpper(io_statement);
    else;
      l_keyword = ToUpper(SafeSubstr(io_statement:1:%min(l_blankPos - 1:10)));
    endif;

    if l_keyword = 'ELSE';
      if l_sawIf or l_sawElse or g_ifLast = '';
        o_reason = 'ELSE does not directly follow an IF line';
        g_ifLast = '';
        g_ifCtx = '';
        return *off;
      endif;
      if g_ifCtx = '';
        l_elseCond = '*NOT (' + g_ifLast + ')';
      else;
        l_elseCond = '(' + g_ifCtx + ') *AND *NOT (' + g_ifLast + ')';
      endif;
      o_cond = l_elseCond;
      l_sawElse = *on;
      if l_blankPos = 0;
        io_statement = '';
      else;
        io_statement = %trim(SafeSubstrToEnd(io_statement:l_blankPos + 1));
      endif;

    elseif l_keyword = 'IF' or l_keyword = 'IFT' or l_keyword = 'IFF';
      if l_blankPos = 0;
        o_reason = 'IF without a condition';
        g_ifLast = '';
        g_ifCtx = '';
        return *off;
      endif;
      io_statement = %trim(SafeSubstrToEnd(io_statement:l_blankPos + 1));
      l_inQuote = *off;
      l_index = 1;
      dow l_index <= %len(io_statement);
        if SafeSubstr(io_statement:l_index:1) = C_QUOTE;
          l_inQuote = not l_inQuote;
        endif;
        if SafeSubstr(io_statement:l_index:1) = ' ' and not l_inQuote;
          leave;
        endif;
        l_index += 1;
      enddo;
      l_conditionToken = SafeSubstr(io_statement:1:l_index - 1);
      if l_index > %len(io_statement);
        io_statement = '';
      else;
        io_statement = %trim(SafeSubstrToEnd(io_statement:l_index + 1));
      endif;
      l_converted = ConditionExpression(l_conditionToken);
      if l_converted = '';
        o_reason = 'Condition ' + l_conditionToken + ' is not converted';
        g_ifLast = '';
        g_ifCtx = '';
        return *off;
      endif;
      if l_keyword = 'IFF';
        l_converted = NegateCondition(l_converted);
      endif;
      if l_lineLast = '';
        l_lineLast = l_converted;
      else;
        l_lineLast = '(' + l_lineLast + ') *AND (' + l_converted + ')';
      endif;
      if o_cond = '';
        o_cond = l_converted;
      else;
        o_cond = '(' + o_cond + ') *AND (' + l_converted + ')';
      endif;
      l_sawIf = *on;

    else;
      leave;
    endif;
  enddo;

  if l_sawIf;
    g_ifLast = l_lineLast;
    if l_sawElse;
      g_ifCtx = l_elseCond;
    else;
      g_ifCtx = '';
    endif;
  else;
    g_ifLast = '';
    g_ifCtx = '';
  endif;
  return *on;
end-proc;

// ------------------------------------------------------------------
// Cuts operands at the first blank outside apostrophes: what follows is a
// comment. Returns the comment text.
dcl-proc SplitStatementTail;
  dcl-pi *n varchar(512);
    io_operands varchar(512);
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_inQuote ind inz(*off);
  dcl-s l_tail varchar(512);

  for l_index = 1 to %len(io_operands);
    if SafeSubstr(io_operands:l_index:1) = C_QUOTE;
      l_inQuote = not l_inQuote;
    endif;
    if SafeSubstr(io_operands:l_index:1) = ' ' and not l_inQuote;
      l_tail = %trim(SafeSubstrToEnd(io_operands:l_index + 1));
      io_operands = SafeSubstr(io_operands:1:l_index - 1);
      return l_tail;
    endif;
  endfor;
  return '';
end-proc;

// ------------------------------------------------------------------
// // SWITCH nnnnnnnn   (0 off, 1 on, X unchanged)
dcl-proc ConvertSwitch;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_operands varchar(512) const;
  end-pi;

  dcl-s l_switches varchar(512);

  l_switches = ToUpper(%trim(i_operands));
  if %len(l_switches) <> 8 or %check('01X':l_switches) > 0;
    ReviewLine(i_lineNo:i_text:'SWITCH needs 8 characters of 0, 1 or X');
    return;
  endif;
  AddBody('CHGJOB SWS(' + l_switches + ')');
  RptItem(C_STS_ASSUMPTION:i_lineNo:i_text
          :'S/36 UPSI switches taken as the job switches (CHGJOB SWS)');
end-proc;

// ------------------------------------------------------------------
// The names a procedure call must not be mistaken for: OCL statement words
// and the IBM-supplied procedures of SC41-4731, chapter 4.
dcl-proc InitReservedNames;
  g_oclWords = ',';
  g_oclWords += 'ABEND,ALLOCATE,ATTR,CANCEL,CHANGE,COMM,COMPILE,DATE,DEALLOC,DEBUG,';
  g_oclWords += 'EVOKE,FILE,FILELIB,FORMS,IMAGE,INCLUDE,INFOMSG,JOBQ,LIBRARY,LOAD,';
  g_oclWords += 'LOCAL,LOG,MEMBER,MENU,MSG,NOHALT,OFF,POWER,PRINTER,PROMPT,REGION,';
  g_oclWords += 'RESERVE,RUN,RUN400,SESSION,SETDEV,START,STOP,SWITCH,SYSLIST,TIMERSET,';
  g_oclWords += 'VARY,WAIT,WORKSTN,END,SOURCE,TAG,GOTO,IF,IFF,IFT,ELSE,EVALUATE,';
  g_oclWords += 'RETURN,PAUSE,SCRATCH,BLDFILE,';
  g_ibmProcedures = ',';
  g_ibmProcedures += '#STRTUP1,#STRTUP2,ALERT,ALOCFLDR,ALOCLIBR,ALTERCOM,ALTERSDL,';
  g_ibmProcedures += 'APAR,APPNINFO,ARCHIVE,ASM,ASMLOAD,ASMSAVE,AUTO,AUTOC,BACKUP,';
  g_ibmProcedures += 'BALPRINT,BASIC,BASICP,BASICR,BASICS,BASLOAD,BASSAVE,BGUATTR,';
  g_ibmProcedures += 'BGUCHART,BGUDATA,BGUGRAPH,BGULOAD,BGUSAVE,BLDFILE,BLDGRAPH,';
  g_ibmProcedures += 'BLDINDEX,BLDLIBR,BLDMENU,BUILD,CACHE,CATALOG,CGU,CGULOAD,';
  g_ibmProcedures += 'CGUSAVE,CHGXLATE,CHNGEMEM,CLRPF,CNFIGICF,CNFIGSSP,CNFIGX25,';
  g_ibmProcedures += 'COBLOAD,COBOL,COBOLC,COBOLCG,COBOLG,COBOLONL,COBOLP,COBSAVE,';
  g_ibmProcedures += 'COBSDA,COBSEU,COMPRESS,CONDENSE,COPYDATA,COPYDIAG,COPYI1,';
  g_ibmProcedures += 'COPYPRT,CREATE,CSALL,DATE,DEFINEID,DEFINEPN,DEFINLOC,DEFINX21,';
  g_ibmProcedures += 'DEFINX25,DEFSUBD,DELETE,DELNRD,DFA,DFU,DFULOAD,DFUSAVE,DICTLOAD,';
  g_ibmProcedures += 'DICTSAVE,DISABLE,DISPLAY,DLSLOAD,DLSSAVE,DOCCNV,DOCPLOAD,';
  g_ibmProcedures += 'DOCPSAVE,DSPLOCKS,DSPMNU,DSPSYS,DSU,DSULOAD,DSUSAVE,DUMP,';
  g_ibmProcedures += 'EDITNRD,EM3270,ENABLE,ENTER,ENTER#,EP3270,EPDOWNL,EPLMRG,ERAP,';
  g_ibmProcedures += 'ERR,ES3270,EXTRACT,FORMAT,FROMLIBR,HELP,HISTCOPY,HISTCRT,';
  g_ibmProcedures += 'HISTORY,ICFDEBUG,ICVERIFY,IDDU,IDDUDCT,IDDUDFN,IDDUDISK,';
  g_ibmProcedures += 'IDDULINK,IDDUPRT,IDDURBLD,IDDUXLAT,IGC,INIT,INIT9332,INITDIAG,';
  g_ibmProcedures += 'INQUIRY,INQUIRY#,IPL,ITF,IWLOAD,IWPTLOAD,IWPTSAVE,IWSAVE,JOBSTR,';
  g_ibmProcedures += 'KEYS,KEYSORT,LANLOAD,LANSAVE,LIBRLIBR,LINES,LIST,LIST#,LISTDATA,';
  g_ibmProcedures += 'LISTFILE,LISTLIBR,LISTNRD,LOAD3601,LOG,LRTRLOAD,LRTRSAVE,';
  g_ibmProcedures += 'MAINTX25,MCSCONV,MOVEFLDR,MS3270,MSDOWNL,MSGFILE,MSRJE,NOHALT,';
  g_ibmProcedures += 'OFCBPRT,OFCCAL,OFCCANCL,OFCCOMM,OFCCONV,OFCDATA,OFCDFLT,OFCDIR,';
  g_ibmProcedures += 'OFCFILE,OFCGRP,OFCINSTL,OFCLDF,OFCLOAD,OFCMAIL,OFCMAINT,OFCMSG,';
  g_ibmProcedures += 'OFCQ,OFCSAVE,OFCSRCH,OFCSTART,OFCSTAT,OFCUSER,OLINK,OLPDLOAD,';
  g_ibmProcedures += 'OLPDSAVE,ORGANIZE,OVERRIDE,PASSTHRU,PASSWORD,PATCH,PCEXCH,';
  g_ibmProcedures += 'PCEXEC,PCOLOAD,PCOPROF,PCOSAVE,PCU,POST,PRINT,PRINTKEY,PROBLEM,';
  g_ibmProcedures += 'PROFLOAD,PROFSAVE,PRTGRAPH,PTF,QRY,QRYDE,QRYLOAD,QRYRUN,QRYSAVE,';
  g_ibmProcedures += 'READINFO,REBLD,RELOAD,RENAME,REQUESTX,RESPONSE,RESTEXTN,';
  g_ibmProcedures += 'RESTFLDR,RESTLIBR,RESTNRD,RESTORE,RETRIEVE,RGZFILE,RJFILE,';
  g_ibmProcedures += 'RJTABLE,ROLLKEYS,RPG,RPGC,RPGLOAD,RPGONL,RPGP,RPGR,RPGSAVE,';
  g_ibmProcedures += 'RPGSDA,RPGSEU,RPGX,SAVE,SAVEEXTN,SAVEFLDR,SAVELIBR,SAVENRD,SDA,';
  g_ibmProcedures += 'SDALOAD,SDASAVE,SECDEF,SECEDIT,SECLIST,SECREST,SECSAVE,SERVICE,';
  g_ibmProcedures += 'SERVLOG,SET,SETALERT,SETCOMM,SETDUMP,SEU,SEULOAD,SEUSAVE,';
  g_ibmProcedures += 'SHRFLOAD,SHRFSAVE,SLIB,SMF,SMFDATA,SMFPRINT,SMFSTOP,SOFTWARE,';
  g_ibmProcedures += 'SORT,SPECIFY,SRTX,SRTXBLD,SRTXLOAD,SRTXSAVE,STARTM,STATEST,';
  g_ibmProcedures += 'STOPGRP,STOPM,STRTGRP,SWDLOAD,SWDSAVE,SWITCH,SYSLIST,TAPECOPY,';
  g_ibmProcedures += 'TAPEINIT,TAPESTAT,TEXTCONV,TEXTDCT,TEXTDOC,TEXTFLDR,TEXTLOAD,';
  g_ibmProcedures += 'TEXTOBJ,TEXTPROF,TEXTPRTQ,TEXTREL,TEXTSAVE,TIMER,TOLIBR,TRACE,';
  g_ibmProcedures += 'TRANSFER,TRNMGR,UPDATE,UPDATE#,WRKSPL,WRKUSER,WSFLOAD,WSFSAVE,';
  g_ibmProcedures += 'XREST,XSAVE,';
end-proc;

// ------------------------------------------------------------------
// Classifies the first word of a line (NAME or NAME,LIBRARY):
// 'U' a name that can be a user procedure, 'I' an IBM-supplied procedure,
// 'O' an OCL statement word or something that is not a name.
dcl-proc ClassifyProcedureName;
  dcl-pi *n char(1);
    i_word varchar(60) const;
  end-pi;

  dcl-s l_name varchar(60);
  dcl-s l_commaPos int(10);

  l_commaPos = %scan(',':i_word);
  if l_commaPos > 0;
    l_name = ToUpper(SafeSubstr(i_word:1:l_commaPos - 1));
  else;
    l_name = ToUpper(i_word);
  endif;
  if %len(l_name) = 0 or %len(l_name) > 10
     or %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ#@$':SafeSubstr(l_name:1:1)) > 0
     or %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#@$_':l_name) > 0;
    return 'O';
  endif;
  if %scan(',' + l_name + ',':g_oclWords) > 0;
    return 'O';
  endif;
  if %scan(',' + l_name + ',':g_ibmProcedures) > 0;
    return 'I';
  endif;
  return 'U';
end-proc;

// ------------------------------------------------------------------
// Splits the data of a procedure call at commas outside quotes. An omitted
// parameter comes back as an empty item. Returns the count (at most
// C_MAXPARMITEMS).
dcl-proc SplitParameters;
  dcl-pi *n int(10);
    i_text varchar(512) const;
    o_items varchar(200) dim(C_MAXPARMITEMS);
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_itemCount int(10) inz(0);
  dcl-s l_currentItem varchar(200) inz('');
  dcl-s l_inQuote ind inz(*off);
  dcl-s l_char char(1);

  if %len(%trim(i_text)) = 0;
    return 0;
  endif;
  for l_index = 1 to %len(i_text);
    l_char = SafeSubstr(i_text:l_index:1);
    if l_char = C_QUOTE;
      l_inQuote = not l_inQuote;
    endif;
    if l_char = ',' and not l_inQuote;
      if l_itemCount < C_MAXPARMITEMS;
        l_itemCount += 1;
        o_items(l_itemCount) = %trim(l_currentItem);
      endif;
      l_currentItem = '';
    else;
      l_currentItem += l_char;
    endif;
  endfor;
  if l_itemCount < C_MAXPARMITEMS;
    l_itemCount += 1;
    o_items(l_itemCount) = %trim(l_currentItem);
  endif;
  return l_itemCount;
end-proc;

// ------------------------------------------------------------------
dcl-proc BlankPad;
  dcl-pi *n varchar(10);
    i_count int(10) const;
  end-pi;

  dcl-s l_pad varchar(10) inz('');

  dow %len(l_pad) < i_count and %len(l_pad) < 10;
    l_pad += ' ';
  enddo;
  return l_pad;
end-proc;

// ------------------------------------------------------------------
// One parameter of a procedure call as a CL value. The called program
// declares every parameter CHAR(10), so text is padded to 10 characters
// (an omitted parameter is 10 blanks) and a value that is shorter than 10
// is first moved into a temporary variable. o_isValid is *OFF with the
// reason in o_reason when the parameter cannot be converted.
dcl-proc ConvertCallParameter;
  dcl-pi *n varchar(120);
    i_item varchar(200) const;
    o_isValid ind;
    o_reason varchar(100);
  end-pi;

  dcl-s l_item varchar(200);
  dcl-s l_content varchar(200);
  dcl-s l_variable varchar(20);
  dcl-s l_variableLength int(10);
  dcl-s l_valueLength int(10);
  dcl-s l_questionCount int(10);
  dcl-s l_tempVariable varchar(20);
  dcl-s l_isQuoted ind;

  o_isValid = *on;
  o_reason = '';
  l_item = %trim(i_item);

  if %len(l_item) = 0;                    // omitted parameter
    return C_QUOTE + BlankPad(C_CALLPARMLEN) + C_QUOTE;
  endif;

  l_questionCount = %len(l_item) - %len(%scanrpl('?':'':l_item));
  if l_questionCount > 0;
    if l_questionCount = 2 and SafeSubstr(l_item:1:1) = '?'
       and SafeSubstr(l_item:%len(l_item):1) = '?' and %len(l_item) > 2;
      l_variable = ExpressionVariable(SafeSubstr(l_item:2:%len(l_item) - 2)
                                      :l_variableLength);
      if l_variable = '';
        o_isValid = *off;
        o_reason = 'Parameter uses an expression that is not converted';
        return '';
      endif;
      if l_variableLength >= C_CALLPARMLEN;
        return l_variable;
      endif;
      // A shorter variable would be read past its end: copy it first.
      g_tempVariableCount += 1;
      l_tempVariable = '&T' + %trim(%char(g_tempVariableCount));
      AddBody('CHGVAR VAR(' + l_tempVariable + ') VALUE(' + l_variable + ')');
      return l_tempVariable;
    endif;
    l_variable = ConvertOperand(l_item:o_isValid);
    if not o_isValid;
      o_reason = 'Parameter uses an expression that is not converted';
      return '';
    endif;
    return l_variable;
  endif;

  l_isQuoted = %len(l_item) >= 2 and SafeSubstr(l_item:1:1) = C_QUOTE
               and SafeSubstr(l_item:%len(l_item):1) = C_QUOTE;
  if l_isQuoted;
    l_content = SafeSubstr(l_item:2:%len(l_item) - 2);
  else;
    l_content = l_item;
  endif;
  // A quote inside the text must be doubled (as in CL).
  if %scan(C_QUOTE:%scanrpl(C_DQUOTE:'':l_content)) > 0
     or (not l_isQuoted and %scan(C_QUOTE:l_content) > 0);
    o_isValid = *off;
    o_reason = 'Parameter text with an apostrophe is not understood';
    return '';
  endif;
  l_valueLength = %len(%scanrpl(C_DQUOTE:C_QUOTE:l_content));
  if l_valueLength > C_CALLPARMLEN;
    o_isValid = *off;
    o_reason = 'Parameter is longer than ' + %char(C_CALLPARMLEN)
               + ' characters (the called program declares CHAR('
               + %char(C_CALLPARMLEN) + '))';
    return '';
  endif;
  return C_QUOTE + l_content
         + BlankPad(C_CALLPARMLEN - l_valueLength) + C_QUOTE;
end-proc;

// ------------------------------------------------------------------
// Procedure call:  name[,library] [parameters]  or  // name[,library] [parameters]
// The called procedure is taken to be converted to a program of the same name,
// so the call becomes CALL PGM([library/]name) PARM(...).
dcl-proc ConvertProcedureCall;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_target varchar(60) const;
    i_data varchar(512) const;
  end-pi;

  dcl-s l_names varchar(200) dim(C_MAXITEMS);
  dcl-s l_nameCount int(10);
  dcl-s l_parms varchar(200) dim(C_MAXPARMITEMS);
  dcl-s l_parmCount int(10);
  dcl-s l_index int(10);
  dcl-s l_isValid ind;
  dcl-s l_reason varchar(100);
  dcl-s l_name varchar(60);
  dcl-s l_library varchar(60);
  dcl-s l_value varchar(120);
  dcl-s l_parmList varchar(512) inz('');
  dcl-s l_call varchar(512);
  dcl-s l_note varchar(100);

  if g_pendLoad;
    ReviewLine(g_loadLine:g_loadText
               :'LOAD was not followed by RUN before a procedure call');
    g_pendLoad = *off;
  endif;

  l_nameCount = SplitItems(i_target:l_names);
  if l_nameCount < 1 or l_nameCount > 2;
    ReviewLine(i_lineNo:i_text
               :'Procedure call operands not understood (expected name[,library])');
    return;
  endif;
  l_name = ConvertOperand(l_names(1):l_isValid);
  l_library = '';
  if l_isValid and l_nameCount = 2;
    l_library = ConvertOperand(l_names(2):l_isValid);
  endif;
  if not l_isValid;
    ReviewLine(i_lineNo:i_text
               :'Procedure call uses an expression that is not converted');
    return;
  endif;
  if not IsValidName(l_name:10) or (l_library <> '' and not IsValidName(l_library:10));
    ReviewLine(i_lineNo:i_text:'Procedure or library name is not a valid name');
    return;
  endif;

  l_parmCount = SplitParameters(i_data:l_parms);
  if l_parmCount > 40;
    ReviewLine(i_lineNo:i_text:'More than 40 parameters (CL allows 40 here)');
    return;
  endif;
  for l_index = 1 to l_parmCount;
    l_value = ConvertCallParameter(l_parms(l_index):l_isValid:l_reason);
    if not l_isValid;
      ReviewLine(i_lineNo:i_text:l_reason);
      return;
    endif;
    if %len(l_parmList) + %len(l_value) > 440;
      ReviewLine(i_lineNo:i_text:'Procedure call is too long to convert');
      return;
    endif;
    if l_index > 1;
      l_parmList += ' ';
    endif;
    l_parmList += l_value;
  endfor;

  l_call = 'CALL PGM(';
  if l_library <> '';
    l_call += l_library + '/';
  endif;
  l_call += l_name + ')';
  if l_parmCount > 0;
    l_call += ' PARM(' + l_parmList + ')';
  endif;
  AddBody(l_call);

  l_note = 'Procedure ' + l_name + ' called as a program of the same name';
  if l_parmCount > 0;
    l_note += '; parameters passed as CHAR(' + %char(C_CALLPARMLEN) + ')';
  endif;
  if g_afterRun;
    l_note += '; follows RUN, so remove it if it is program data';
  endif;
  RptItem(C_STS_ASSUMPTION:i_lineNo:i_text:l_note);
end-proc;

// ------------------------------------------------------------------
// WAIT TIME-hhmmss or WAIT INTERVAL-hhmmss (SC41-4731, chapter 5).
// TIME becomes DLYJOB RSMTIME(hhmmss), INTERVAL becomes DLYJOB DLY(seconds).
dcl-proc ConvertWait;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_operands varchar(512) const;
  end-pi;

  dcl-s l_operand varchar(512);
  dcl-s l_keyword varchar(20);
  dcl-s l_value varchar(20);
  dcl-s l_dashPos int(10);
  dcl-s l_hours int(10);
  dcl-s l_minutes int(10);
  dcl-s l_seconds int(10);
  dcl-s l_total int(10);

  l_operand = ToUpper(%trim(i_operands));
  l_dashPos = %scan('-':l_operand);
  if l_dashPos < 2;
    ReviewLine(i_lineNo:i_text:'WAIT needs TIME-hhmmss or INTERVAL-hhmmss');
    return;
  endif;
  l_keyword = SafeSubstr(l_operand:1:l_dashPos - 1);
  l_value = SafeSubstrToEnd(l_operand:l_dashPos + 1);
  if (l_keyword <> 'TIME' and l_keyword <> 'INTERVAL')
     or %len(l_value) <> 6 or %check('0123456789':l_value) > 0;
    ReviewLine(i_lineNo:i_text:'WAIT needs TIME-hhmmss or INTERVAL-hhmmss (6 digits)');
    return;
  endif;

  l_hours = %int(SafeSubstr(l_value:1:2));
  l_minutes = %int(SafeSubstr(l_value:3:2));
  l_seconds = %int(SafeSubstr(l_value:5:2));
  if l_hours > 24 or l_minutes > 59 or l_seconds > 59
     or (l_hours = 24 and (l_minutes > 0 or l_seconds > 0));
    ReviewLine(i_lineNo:i_text
               :'WAIT value out of range (hh 00-24, mm and ss 00-59, 240000 at most)');
    return;
  endif;

  if l_keyword = 'TIME';
    // 240000 and 000000 are the same time of day.
    if l_hours = 24;
      l_value = '000000';
    endif;
    AddBody('DLYJOB RSMTIME(' + l_value + ')');
    RptItem(C_STS_ASSUMPTION:i_lineNo:i_text
            :'WAIT TIME as DLYJOB RSMTIME; time already passed means next day (to test)');
  else;
    l_total = l_hours * 3600 + l_minutes * 60 + l_seconds;
    if l_total = 0;
      AddComment('OCL: ' + %trim(i_text) + ' (no wait)');
      RptItem(C_STS_ASSUMPTION:i_lineNo:i_text:'WAIT INTERVAL of zero: no delay written');
      return;
    endif;
    AddBody('DLYJOB DLY(' + %trim(%char(l_total)) + ')');
    RptItem(C_STS_CONVERTED:i_lineNo:i_text:'');
  endif;
end-proc;

// ------------------------------------------------------------------
// PAUSE ['message text'] (SC41-4731, chapter 3). The operator replies 0 to
// continue. TOUSR(*REQUESTER) sends to the display station of an interactive
// job and to the system operator for a batch job, as the reference describes.
dcl-proc ConvertPause;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_operands varchar(512) const;
  end-pi;

  dcl-s l_value varchar(600);
  dcl-s l_reason varchar(100);

  if %len(%trim(i_operands)) = 0;
    l_value = C_QUOTE + 'PAUSE -- when ready, enter 0 to continue' + C_QUOTE;
  else;
    l_value = MessageTextValue(i_operands:500:l_reason);
    if l_reason <> '';
      ReviewLine(i_lineNo:i_text:l_reason);
      return;
    endif;
  endif;

  g_usePause = *on;
  AddBody('SNDUSRMSG MSG(' + l_value + ') VALUES(' + C_QUOTE
          + '0' + C_QUOTE + ') MSGTYPE(*INQ) TOUSR(*REQUESTER) MSGRPY(&PAUSERPY)');
  RptItem(C_STS_ASSUMPTION:i_lineNo:i_text
          :'PAUSE as an inquiry message, reply 0 continues (SNDUSRMSG not tested yet)');
end-proc;

// ------------------------------------------------------------------
// NOHALT level[,JOB|SESSION|SYSTEM] (SC41-4731, chapter 5, and the RESPONSE
// procedure). The reference says OS/400 does not use the severity level; the
// reply is chosen per job. Level 0 asks for a reply, levels 1 to 4 use the
// default reply. Inside a procedure JOB is assumed.
dcl-proc ConvertNohalt;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_operands varchar(512) const;
  end-pi;

  dcl-s l_operand varchar(512);
  dcl-s l_level varchar(512);
  dcl-s l_scope varchar(512);
  dcl-s l_commaPos int(10);

  l_operand = ToUpper(%trim(i_operands));
  l_commaPos = %scan(',':l_operand);
  if l_commaPos = 0;
    l_level = l_operand;
    l_scope = 'JOB';
  else;
    l_level = SafeSubstr(l_operand:1:l_commaPos - 1);
    l_scope = SafeSubstrToEnd(l_operand:l_commaPos + 1);
    if %len(l_scope) = 0;
      l_scope = 'JOB';
    endif;
  endif;

  if %len(l_level) <> 1 or %check('01234':l_level) > 0;
    ReviewLine(i_lineNo:i_text:'NOHALT severity level must be 0, 1, 2, 3 or 4');
    return;
  endif;
  if l_scope = 'SESSION' or l_scope = 'SYSTEM';
    ReviewLine(i_lineNo:i_text
               :'NOHALT ' + l_scope
                + ' (level for later jobs) cannot be set from a CL program');
    return;
  endif;
  if l_scope <> 'JOB';
    ReviewLine(i_lineNo:i_text:'NOHALT second operand must be JOB, SESSION or SYSTEM');
    return;
  endif;

  if l_level = '0';
    AddBody('CHGJOB INQMSGRPY(*RQD)');
  else;
    AddBody('CHGJOB INQMSGRPY(*DFT)');
  endif;
  RptItem(C_STS_ASSUMPTION:i_lineNo:i_text
          :'NOHALT 1 to 4 all as default reply (the severity level is not kept)');
end-proc;

// ------------------------------------------------------------------
// CANCEL without operands (SC41-4731, chapter 3): cancels the procedure.
// CANCEL PRT,... (chapter 5) cancels spool file entries and is not converted.
dcl-proc ConvertCancel;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_operands varchar(512) const;
  end-pi;

  if %len(%trim(i_operands)) > 0;
    ReviewLine(i_lineNo:i_text
               :'CANCEL of spool file entries (PRT) is not converted in this version');
    return;
  endif;

  AddCurLibExit();
  AddBody('DLCOBJ OBJ((' + C_MARKLIB + '/' + g_procName + ' *DTAARA *SHRRD))');
  AddBody('MONMSG MSGID(CPF0000)');
  AddBody('RETURN');
  RptItem(C_STS_ASSUMPTION:i_lineNo:i_text
          :'CANCEL written as RETURN; abnormal end, return to keyboard not reproduced');
end-proc;

// ------------------------------------------------------------------
// LIBRARY NAME-library[,SESSION-NO|YES] (SC41-4731, chapter 5). The current
// library of the procedure becomes the OS/400 current library. SESSION-NO
// lasts until the procedure ends, so the original one is put back at every
// exit (see AddCurLibExit). SESSION-YES does not change the library of the
// running procedure, only the one the display station keeps afterwards, so it
// is set at every exit. NAME-0 (only #LIBRARY searched) is *CRTDFT.
dcl-proc ConvertLibrary;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_operands varchar(512) const;
  end-pi;

  dcl-s l_items varchar(200) dim(C_MAXITEMS);
  dcl-s l_itemCount int(10);
  dcl-s l_itemIndex int(10);
  dcl-s l_isValid ind;
  dcl-s l_hasProblem ind inz(*off);
  dcl-s l_keyword varchar(60);
  dcl-s l_value varchar(200);
  dcl-s l_name varchar(60) inz('');
  dcl-s l_session varchar(60) inz('NO');
  dcl-s l_target varchar(60);
  dcl-s l_newMode int(10);

  if g_pendLoad;
    ReviewLine(i_lineNo:i_text:'LIBRARY between LOAD and RUN is not allowed');
    return;
  endif;

  l_itemCount = SplitItems(i_operands:l_items);
  if l_itemCount < 1;
    ReviewLine(i_lineNo:i_text:'LIBRARY needs NAME-library');
    return;
  endif;

  for l_itemIndex = 1 to l_itemCount;
    SplitKeyword(l_items(l_itemIndex):l_keyword:l_value);
    l_isValid = *on;
    select;
      when l_keyword = 'NAME';
        l_name = ConvertOperand(l_value:l_isValid);
      when l_keyword = 'SESSION';
        l_session = ToUpper(l_value);
      other;
        l_hasProblem = *on;
    endsl;
    if not l_isValid;
      l_hasProblem = *on;
    endif;
  endfor;
  if l_hasProblem or l_name = '' or (l_session <> 'NO' and l_session <> 'YES');
    ReviewLine(i_lineNo:i_text
               :'LIBRARY operands not understood (NAME-library, SESSION-NO or YES)');
    return;
  endif;

  if l_name = '0';
    l_target = '*CRTDFT';
  else;
    if not IsValidName(l_name:10);
      ReviewLine(i_lineNo:i_text:'LIBRARY name is not a valid name');
      return;
    endif;
    l_target = l_name;
  endif;

  if l_session = 'YES';
    l_newMode = 2;
  else;
    l_newMode = 1;
  endif;
  if g_libMode <> 0 and g_libMode <> l_newMode;
    ReviewLine(i_lineNo:i_text
               :'LIBRARY with SESSION-NO and SESSION-YES in one procedure');
    return;
  endif;
  g_libMode = l_newMode;

  if l_session = 'NO';
    AddBody('CHGCURLIB CURLIB(' + l_target + ')');
    RptItem(C_STS_ASSUMPTION:i_lineNo:i_text
            :'LIBRARY as CHGCURLIB, original library put back at exit (to test)');
  else;
    g_sessionLib = l_target;
    AddComment('OCL: ' + %trim(i_text) + ' (CHGCURLIB is written at each exit)');
    RptItem(C_STS_ASSUMPTION:i_lineNo:i_text
            :'LIBRARY SESSION-YES as CHGCURLIB at exit, session library (to test)');
  endif;
end-proc;

// ------------------------------------------------------------------
// The lines every exit of the procedure (RETURN, CANCEL, the end) writes for
// the LIBRARY statement: put the original current library back (SESSION-NO)
// or set the session library (SESSION-YES).
dcl-proc AddCurLibExit;
  select;
    when g_libMode = 1;
      AddBody('CHGCURLIB CURLIB(&OLDCURLIB)');
      AddBody('MONMSG MSGID(CPF0000)');
    when g_libMode = 2;
      AddBody('CHGCURLIB CURLIB(' + g_sessionLib + ')');
      AddBody('MONMSG MSGID(CPF0000)');
  endsl;
end-proc;

// ------------------------------------------------------------------
// SESSION SYMID-id,LOCATION-name[,GROUP-mode][,APPCNET-YES|NO]: the APPC form
// (SC41-4730, chapter 13, Figure 13-10). Written between LOAD and RUN, so the
// override is written before the CALL. The reference says an OVRICFDEVE run
// from a CL program applies only while that program runs. The other
// communications types (BSCEL, asynchronous, finance, retail, SNUF) are not
// converted.
dcl-proc ConvertSession;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_operands varchar(512) const;
  end-pi;

  dcl-s l_items varchar(200) dim(C_MAXITEMS);
  dcl-s l_itemCount int(10);
  dcl-s l_itemIndex int(10);
  dcl-s l_isValid ind;
  dcl-s l_hasProblem ind inz(*off);
  dcl-s l_otherType ind inz(*off);
  dcl-s l_keyword varchar(60);
  dcl-s l_value varchar(200);
  dcl-s l_symbolic varchar(60) inz('');
  dcl-s l_location varchar(60) inz('');
  dcl-s l_group varchar(60) inz('');
  dcl-s l_appcNet varchar(60) inz('');
  dcl-s l_command varchar(200);

  if not g_pendLoad;
    ReviewLine(i_lineNo:i_text:'SESSION must be between LOAD and RUN');
    return;
  endif;

  l_itemCount = SplitItems(i_operands:l_items);
  if l_itemCount < 1;
    ReviewLine(i_lineNo:i_text:'SESSION needs SYMID and LOCATION');
    return;
  endif;

  for l_itemIndex = 1 to l_itemCount;
    SplitKeyword(l_items(l_itemIndex):l_keyword:l_value);
    l_isValid = *on;
    select;
      when l_keyword = 'SYMID';
        l_symbolic = ConvertOperand(l_value:l_isValid);
      when l_keyword = 'LOCATION';
        l_location = ConvertOperand(l_value:l_isValid);
      when l_keyword = 'GROUP';
        l_group = ConvertOperand(l_value:l_isValid);
      when l_keyword = 'APPCNET';
        l_appcNet = ToUpper(l_value);
      other;
        l_otherType = *on;
    endsl;
    if not l_isValid;
      l_hasProblem = *on;
    endif;
  endfor;

  if l_otherType;
    ReviewLine(i_lineNo:i_text
               :'SESSION for a communications type other than APPC is not converted');
    return;
  endif;
  if l_hasProblem or l_symbolic = '' or l_location = ''
     or (l_appcNet <> '' and l_appcNet <> 'YES' and l_appcNet <> 'NO');
    ReviewLine(i_lineNo:i_text
               :'SESSION operands not understood (SYMID, LOCATION, GROUP, APPCNET)');
    return;
  endif;
  if not IsValidName(l_location:10) or (l_group <> '' and not IsValidName(l_group:10))
     or (SafeSubstr(l_symbolic:1:1) <> '&' and %len(l_symbolic) <> 2);
    ReviewLine(i_lineNo:i_text
               :'SESSION SYMID (2 characters), LOCATION or GROUP is not valid');
    return;
  endif;

  l_command = 'OVRICFDEVE PGMDEV(' + l_symbolic + ') RMTLOCNAME(' + l_location + ')';
  if l_group <> '';
    l_command += ' MODE(' + l_group + ')';
  endif;
  AddBody(l_command);
  RptItem(C_STS_ASSUMPTION:i_lineNo:i_text
          :'SESSION as OVRICFDEVE; PGMDEV(digit first) and override end to test');
end-proc;

// ------------------------------------------------------------------
// ?Mmic? and ?M'mic,position,length'? (SC41-4731, chapter 3): text of a
// message in the current first-level (USER1) message member, a message file
// on the AS/400 system. RTVMSG fills a work variable, &Mn gets the whole text
// or the part asked for. i_token is the upper-case text between the question
// marks. Returns '' when it cannot be converted (no MEMBER USER1 before it).
dcl-proc MessageMemberVariable;
  dcl-pi *n varchar(20);
    i_token varchar(60) const;
  end-pi;

  dcl-s l_rest varchar(60);
  dcl-s l_inner varchar(60);
  dcl-s l_mic varchar(60);
  dcl-s l_first int(10);
  dcl-s l_second int(10);
  dcl-s l_position int(10) inz(0);
  dcl-s l_length int(10) inz(0);
  dcl-s l_variable varchar(20);

  l_rest = SafeSubstrToEnd(i_token:2);
  if %len(l_rest) = 0 or g_user1Member = '';
    return '';
  endif;
  if SafeSubstr(l_rest:1:1) = C_QUOTE;
    if %len(l_rest) < 9 or SafeSubstr(l_rest:%len(l_rest):1) <> C_QUOTE;
      return '';
    endif;
    l_inner = SafeSubstr(l_rest:2:%len(l_rest) - 2);
    l_first = %scan(',':l_inner);
    l_second = %scan(',':l_inner:l_first + 1);
    if l_first <> 5 or l_second = 0;
      return '';
    endif;
    l_mic = SafeSubstr(l_inner:1:4);
    if %check('0123456789':SafeSubstr(l_inner:6:l_second - 6)) > 0
       or %check('0123456789':SafeSubstrToEnd(l_inner:l_second + 1)) > 0
       or l_second = 6 or l_second = %len(l_inner);
      return '';
    endif;
    l_position = %int(SafeSubstr(l_inner:6:l_second - 6));
    l_length = %int(SafeSubstrToEnd(l_inner:l_second + 1));
    if l_position < 1 or l_length < 1 or l_position > 75 or l_position + l_length > 76;
      return '';
    endif;
  else;
    l_mic = l_rest;
  endif;
  if %len(l_mic) <> 4 or %check('0123456789':l_mic) > 0;
    return '';
  endif;

  g_useMsgText = *on;
  g_msgVarCount += 1;
  l_variable = '&M' + %trim(%char(g_msgVarCount));
  AddBody('RTVMSG MSGID(' + C_MSGPREFIX + l_mic + ') MSGF(' + MessageFileName()
          + ') MSG(&MSGTXT)');
  AddBody('MONMSG MSGID(CPF0000) EXEC(CHGVAR VAR(&MSGTXT) VALUE(' + C_QUOTE + ' '
          + C_QUOTE + '))');
  if l_position > 0;
    AddBody('CHGVAR VAR(' + l_variable + ') VALUE(%SST(&MSGTXT '
            + %trim(%char(l_position)) + ' ' + %trim(%char(l_length)) + '))');
  else;
    AddBody('CHGVAR VAR(' + l_variable + ') VALUE(&MSGTXT)');
  endif;
  RptItem(C_STS_ASSUMPTION:g_curLineNo:g_curText
          :'Message ' + C_MSGPREFIX + l_mic + ' read with RTVMSG from the USER1 '
          + 'message file; prefix ' + C_MSGPREFIX + ' assumed (to test)');
  return l_variable;
end-proc;

// ------------------------------------------------------------------
// The USER1 message file as MSGF operand: library/name, or the name alone
// when the library list is searched.
dcl-proc MessageFileName;
  dcl-pi *n varchar(60);
  end-pi;

  if g_msgLibrary <> '';
    return g_msgLibrary + '/' + g_user1Member;
  endif;
  return g_user1Member;
end-proc;

// ------------------------------------------------------------------
// The message text of PAUSE, // * and // ** statements: inside apostrophes,
// an apostrophe in the text doubled, ?...? expressions allowed. Returns the
// CL value: a quoted text, or &MSGOUT after a CHGVAR (written before the
// statement) when the text holds expressions. o_reason is empty when fine.
// An expression that holds apostrophes, such as ?M'0014,1,8'?, is not read as
// text.
dcl-proc MessageTextValue;
  dcl-pi *n varchar(600);
    i_operand varchar(512) const;
    i_maxLength int(10) const;
    o_reason varchar(100);
  end-pi;

  dcl-s l_text varchar(512);
  dcl-s l_inner varchar(512);
  dcl-s l_rest varchar(512);
  dcl-s l_literal varchar(512);
  dcl-s l_expr varchar(2000) inz('');
  dcl-s l_openMark int(10);
  dcl-s l_closeMark int(10);
  dcl-s l_variable varchar(20);
  dcl-s l_variableLength int(10);
  dcl-s l_index int(10);
  dcl-s l_quotes int(10);
  dcl-s l_pieces int(10) inz(0);
  dcl-s l_lastWasVariable ind inz(*off);

  o_reason = '';
  l_text = %trim(i_operand);
  if %len(l_text) < 2 or SafeSubstr(l_text:1:1) <> C_QUOTE
     or SafeSubstr(l_text:%len(l_text):1) <> C_QUOTE;
    o_reason = 'Message text must be inside apostrophes';
    return '';
  endif;
  l_inner = SafeSubstr(l_text:2:%len(l_text) - 2);
  if %len(l_inner) > i_maxLength;
    o_reason = 'Message text is longer than ' + %trim(%char(i_maxLength))
               + ' characters';
    return '';
  endif;

  if %scan('?':l_inner) = 0;
    l_quotes = 0;
    for l_index = 1 to %len(l_inner);
      if SafeSubstr(l_inner:l_index:1) = C_QUOTE;
        l_quotes += 1;
      endif;
    endfor;
    if %rem(l_quotes:2) <> 0;
      o_reason = 'Message text has an apostrophe that is not doubled';
      return '';
    endif;
    return C_QUOTE + l_inner + C_QUOTE;
  endif;

  l_rest = l_inner;
  dow %len(l_rest) > 0;
    l_openMark = %scan('?':l_rest);
    if l_openMark = 0;
      l_literal = l_rest;
      l_rest = '';
      l_variable = '';
    else;
      l_closeMark = %scan('?':l_rest:l_openMark + 1);
      if l_closeMark = 0;
        o_reason = 'Message text has a ? that does not close an expression';
        return '';
      endif;
      if l_openMark > 1;
        l_literal = SafeSubstr(l_rest:1:l_openMark - 1);
      else;
        l_literal = '';
      endif;
      l_variable = ExpressionVariable(SafeSubstr(l_rest:l_openMark + 1:
                     l_closeMark - l_openMark - 1):l_variableLength);
      if l_variable = '';
        o_reason = 'Expression in the message text is not converted: '
                   + SafeSubstr(l_rest:l_openMark:l_closeMark - l_openMark + 1);
        return '';
      endif;
      if l_closeMark >= %len(l_rest);
        l_rest = '';
      else;
        l_rest = SafeSubstrToEnd(l_rest:l_closeMark + 1);
      endif;
    endif;

    if %len(l_literal) > 0;
      l_quotes = 0;
      for l_index = 1 to %len(l_literal);
        if SafeSubstr(l_literal:l_index:1) = C_QUOTE;
          l_quotes += 1;
        endif;
      endfor;
      if %rem(l_quotes:2) <> 0;
        o_reason = 'Message text has an apostrophe that is not doubled';
        return '';
      endif;
      if l_pieces > 0;
        if l_lastWasVariable;
          l_expr += ' *TCAT ';
        else;
          l_expr += ' *CAT ';
        endif;
      endif;
      l_expr += C_QUOTE + l_literal + C_QUOTE;
      l_pieces += 1;
      l_lastWasVariable = *off;
    endif;
    if l_variable <> '';
      if l_pieces > 0;
        if l_lastWasVariable;
          l_expr += ' *TCAT ';
        else;
          l_expr += ' *CAT ';
        endif;
      endif;
      l_expr += l_variable;
      l_pieces += 1;
      l_lastWasVariable = *on;
    endif;
  enddo;

  g_useMsgOut = *on;
  AddBody('CHGVAR VAR(&MSGOUT) VALUE(' + l_expr + ')');
  return '&MSGOUT';
end-proc;

// ------------------------------------------------------------------
// MEMBER USER1-m,USER2-m,LIBRARY-lib,PROGRAM1-m,PROGRAM2-m (SC41-4731,
// chapter 5). A message member is a message file on the AS/400 system. Only
// this procedure's // * and // ** statements and ?Mmic? expressions use the
// names kept here; 0 means no current member. PROGRAM1 and PROGRAM2 are IBM
// licensed program messages and are accepted but not used.
dcl-proc ConvertMember;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_operands varchar(512) const;
  end-pi;

  dcl-s l_items varchar(200) dim(C_MAXITEMS);
  dcl-s l_itemCount int(10);
  dcl-s l_itemIndex int(10);
  dcl-s l_isValid ind;
  dcl-s l_hasProblem ind inz(*off);
  dcl-s l_keyword varchar(60);
  dcl-s l_value varchar(200);
  dcl-s l_name varchar(60);
  dcl-s l_user1 varchar(60);
  dcl-s l_user2 varchar(60);
  dcl-s l_library varchar(60);
  dcl-s l_user1Given ind inz(*off);
  dcl-s l_user2Given ind inz(*off);
  dcl-s l_libraryGiven ind inz(*off);

  l_itemCount = SplitItems(i_operands:l_items);
  if l_itemCount < 1;
    ReviewLine(i_lineNo:i_text:'MEMBER needs USER1, USER2 or LIBRARY');
    return;
  endif;

  for l_itemIndex = 1 to l_itemCount;
    SplitKeyword(l_items(l_itemIndex):l_keyword:l_value);
    l_isValid = *on;
    select;
      when l_keyword = 'USER1' or l_keyword = 'USER2' or l_keyword = 'LIBRARY';
        l_name = ConvertOperand(l_value:l_isValid);
        if l_name <> '0' and not IsValidName(l_name:10);
          l_isValid = *off;
        endif;
        if l_keyword = 'USER1';
          l_user1 = l_name;
          l_user1Given = *on;
        elseif l_keyword = 'USER2';
          l_user2 = l_name;
          l_user2Given = *on;
        else;
          l_library = l_name;
          l_libraryGiven = *on;
        endif;
      when l_keyword = 'PROGRAM1' or l_keyword = 'PROGRAM2';
        // IBM licensed program messages: not used here
      other;
        l_hasProblem = *on;
    endsl;
    if not l_isValid;
      l_hasProblem = *on;
    endif;
  endfor;
  if l_hasProblem;
    ReviewLine(i_lineNo:i_text:'MEMBER operands not understood or not valid names');
    return;
  endif;

  if l_user1Given;
    if l_user1 = '0';
      g_user1Member = '';
    else;
      g_user1Member = l_user1;
    endif;
  endif;
  if l_user2Given;
    if l_user2 = '0';
      g_user2Member = '';
    else;
      g_user2Member = l_user2;
    endif;
  endif;
  if l_libraryGiven;
    if l_library = '0';
      g_msgLibrary = '';
    else;
      g_msgLibrary = l_library;
    endif;
  endif;

  RptItem(C_STS_ASSUMPTION:i_lineNo:i_text
          :'MEMBER kept for the // * statements and ?Mmic? of this procedure; '
          + 'programs that read the current message member are not changed');
end-proc;

// ------------------------------------------------------------------
// // * (informational message) and // ** (system console message), SC41-4731,
// chapter 3. Text in apostrophes or a 4-digit message id code of the USER1
// message member. // * goes to the requester (the console for a batch job),
// // ** to QSYSOPR and waits for the reply 0, like PAUSE.
dcl-proc ConvertMessage;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
    i_operands varchar(512) const;
    i_isConsole ind const;
  end-pi;

  dcl-s l_operand varchar(512);
  dcl-s l_value varchar(600);
  dcl-s l_reason varchar(100);
  dcl-s l_command varchar(700);
  dcl-s l_note varchar(100);

  l_operand = %trim(i_operands);
  if %len(l_operand) = 0;
    ReviewLine(i_lineNo:i_text:'Message statement without a message id or text');
    return;
  endif;

  if SafeSubstr(l_operand:1:1) = C_QUOTE;
    if i_isConsole;
      l_value = MessageTextValue(l_operand:504:l_reason);
    else;
      l_value = MessageTextValue(l_operand:505:l_reason);
    endif;
    if l_reason <> '';
      ReviewLine(i_lineNo:i_text:l_reason);
      return;
    endif;
    l_command = 'SNDUSRMSG MSG(' + l_value + ')';
    l_note = 'Message text sent with SNDUSRMSG (not tested yet)';
  else;
    if %len(l_operand) <> 4 or %check('0123456789':l_operand) > 0;
      ReviewLine(i_lineNo:i_text
                 :'Message id code must be 4 digits or text in apostrophes');
      return;
    endif;
    if g_user1Member = '';
      ReviewLine(i_lineNo:i_text
                 :'Message id code needs a MEMBER USER1 statement before it');
      return;
    endif;
    l_command = 'SNDUSRMSG MSGID(' + C_MSGPREFIX + l_operand + ') MSGF('
                + MessageFileName() + ')';
    l_note = 'Message id ' + C_MSGPREFIX + l_operand + ' assumed (prefix '
             + C_MSGPREFIX + ' from CRTS36MSGF; not tested yet)';
  endif;

  if i_isConsole;
    g_usePause = *on;
    l_command += ' VALUES(' + C_QUOTE + '0' + C_QUOTE
                 + ') MSGTYPE(*INQ) TOMSGQ(*SYSOPR) MSGRPY(&PAUSERPY)';
  else;
    l_command += ' TOUSR(*REQUESTER)';
  endif;
  AddBody(l_command);
  RptItem(C_STS_ASSUMPTION:i_lineNo:i_text:l_note);
end-proc;

// ------------------------------------------------------------------
dcl-proc ProcessStatement;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
  end-pi;

  dcl-s l_statement varchar(512);
  dcl-s l_keyword varchar(60);
  dcl-s l_operands varchar(512);
  dcl-s l_blankPos int(10);
  dcl-s l_comment varchar(512);
  dcl-s l_tail varchar(512);
  dcl-s l_cond varchar(500);
  dcl-s l_reason varchar(100);
  dcl-s l_start int(10);
  dcl-s l_index int(10);
  dcl-s l_hasClLines ind;

  g_afterRun = *off;
  l_statement = %trim(SafeSubstrToEnd(%trim(i_text):3));
  l_comment = StripTrailingComment(l_statement);
  if %len(l_statement) = 0;
    ReviewLine(i_lineNo:i_text:'Empty OCL statement');
    return;
  endif;

  if not ParseIfPrefix(l_statement:l_cond:l_reason);
    ReviewLine(i_lineNo:i_text:l_reason);
    return;
  endif;
  if %len(l_statement) = 0;
    ReviewLine(i_lineNo:i_text:'IF or ELSE without a statement');
    return;
  endif;
  l_start = g_bodyCnt;

  l_blankPos = %scan(' ':l_statement);
  if l_blankPos = 0;
    l_keyword = ToUpper(l_statement);
    l_operands = '';
  else;
    l_keyword = ToUpper(SafeSubstr(l_statement:1:l_blankPos - 1));
    l_operands = %trim(SafeSubstrToEnd(l_statement:l_blankPos + 1));
  endif;
  if l_keyword <> 'EVALUATE' and %len(l_operands) > 0;
    l_tail = SplitStatementTail(l_operands);      // text after the operands is a comment
    if %len(l_tail) > 0;
      if %len(l_comment) > 0;
        l_comment = l_tail + ' ' + l_comment;
      else;
        l_comment = l_tail;
      endif;
    endif;
  endif;

  select;
    when l_cond <> '' and (l_keyword = 'LOAD' or l_keyword = 'RUN' or l_keyword = 'FILE'
         or l_keyword = 'TAG' or l_keyword = 'MEMBER');
      ReviewLine(i_lineNo:i_text
                 :'A conditional ' + l_keyword + ' statement is not converted');
    when l_keyword = 'LOAD';
      ConvertLoad(i_lineNo:i_text:l_operands);
    when l_keyword = 'RUN';
      ConvertRun(i_lineNo:i_text:l_operands);
    when l_keyword = 'FILE';
      ConvertFile(i_lineNo:i_text:l_operands);
    when l_keyword = 'PRINTER';
      ConvertPrinter(i_lineNo:i_text:l_operands);
    when l_keyword = 'BLDFILE';
      ConvertBldFile(i_lineNo:i_text:l_operands);
    when l_keyword = 'LOCAL';
      ConvertLocal(i_lineNo:i_text:l_operands);
    when l_keyword = 'EVALUATE';
      ConvertEvaluate(i_lineNo:i_text:l_operands);
    when l_keyword = 'TAG';
      ConvertTagGoto(i_lineNo:i_text:*on:l_operands);
    when l_keyword = 'GOTO';
      ConvertTagGoto(i_lineNo:i_text:*off:l_operands);
    when l_keyword = 'SWITCH';
      ConvertSwitch(i_lineNo:i_text:l_operands);
    when l_keyword = 'WAIT';
      ConvertWait(i_lineNo:i_text:l_operands);
    when l_keyword = 'PAUSE';
      ConvertPause(i_lineNo:i_text:l_operands);
    when l_keyword = 'NOHALT';
      ConvertNohalt(i_lineNo:i_text:l_operands);
    when l_keyword = 'CANCEL';
      ConvertCancel(i_lineNo:i_text:l_operands);
    when l_keyword = 'LIBRARY';
      ConvertLibrary(i_lineNo:i_text:l_operands);
    when l_keyword = 'SESSION';
      ConvertSession(i_lineNo:i_text:l_operands);
    when l_keyword = 'MEMBER';
      ConvertMember(i_lineNo:i_text:l_operands);
    when l_keyword = '*' or l_keyword = '**';
      ConvertMessage(i_lineNo:i_text:l_operands:l_keyword = '**');
    when l_keyword = 'RETURN' and %len(l_operands) = 0;
      AddCurLibExit();
      AddBody('DLCOBJ OBJ((' + C_MARKLIB + '/' + g_procName + ' *DTAARA *SHRRD))');
      AddBody('MONMSG MSGID(CPF0000)');
      AddBody('RETURN');
      RptItem(C_STS_CONVERTED:i_lineNo:i_text:'');
    other;
      select;
        when ClassifyProcedureName(l_keyword) = 'U';
          ConvertProcedureCall(i_lineNo:i_text:l_keyword:l_operands);
        when ClassifyProcedureName(l_keyword) = 'I';
          ReviewLine(i_lineNo:i_text:'IBM-supplied procedure ' + l_keyword
                     + ' is not converted');
        other;
          ReviewLine(i_lineNo:i_text
                     :'OCL statement ' + l_keyword + ' is not converted in this version');
      endsl;
  endsl;

  // A condition wraps what the statement wrote into IF ... THEN(DO).
  if l_cond <> '' and g_bodyCnt > l_start;
    l_hasClLines = *off;
    for l_index = l_start + 1 to g_bodyCnt;
      if %len(g_body(l_index)) < 2 or SafeSubstr(g_body(l_index):1:2) <> '/*';
        l_hasClLines = *on;
      endif;
    endfor;
    if l_hasClLines and g_bodyCnt = l_start + 1
       and %len(g_body(g_bodyCnt)) + %len(l_cond) < 440;
      // one statement: IF COND(...) THEN(statement)
      g_body(g_bodyCnt) = 'IF COND(' + l_cond + ') THEN(' + g_body(g_bodyCnt) + ')';
      RptItem(C_STS_ASSUMPTION:i_lineNo:i_text
              :'IF/IFF/ELSE condition compared as text');
    elseif l_hasClLines and g_bodyCnt + 2 <= C_MAXBODY;
      for l_index = g_bodyCnt downto l_start + 1;
        g_body(l_index + 1) = g_body(l_index);
      endfor;
      g_body(l_start + 1) = 'IF COND(' + l_cond + ') THEN(DO)';
      g_bodyCnt += 1;
      AddBody('ENDDO');
      RptItem(C_STS_ASSUMPTION:i_lineNo:i_text
              :'IF/IFF/ELSE condition compared as text');
    elseif l_hasClLines;
      g_overflow = *on;
    endif;
  endif;

  if %len(l_comment) > 0;
    AddComment(l_comment);
  endif;
end-proc;

// ------------------------------------------------------------------
// A line without // that starts like a command name is taken as a CL (or
// S/36 environment) command and copied with substitution applied.
dcl-proc PassThroughClLine;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
  end-pi;

  dcl-s l_blankPos int(10);
  dcl-s l_command varchar(60);
  dcl-s l_clLine varchar(512);
  dcl-s l_open ind;
  dcl-s l_operands varchar(512);
  dcl-s l_tail varchar(512);

  l_blankPos = %scan(' ':i_text);
  if l_blankPos = 0;
    l_command = ToUpper(i_text);
  else;
    l_command = ToUpper(SafeSubstr(i_text:1:l_blankPos - 1));
  endif;
  // Without a keyword in parentheses the line is a procedure call.
  if %scan('(':i_text) = 0 and ClassifyProcedureName(l_command) <> 'O'
     and l_command <> 'BLDFILE' and l_command <> 'NOHALT';
    if ClassifyProcedureName(l_command) = 'I';
      ReviewLine(i_lineNo:i_text:'IBM-supplied procedure ' + l_command
                 + ' is not converted');
      return;
    endif;
    if l_blankPos > 0;
      l_operands = %trim(SafeSubstrToEnd(i_text:l_blankPos + 1));
    else;
      l_operands = '';
    endif;
    l_tail = SplitStatementTail(l_operands);
    ConvertProcedureCall(i_lineNo:i_text:l_command:l_operands);
    AddComment(l_tail);
    return;
  endif;

  if %len(l_command) > 10 or %len(l_command) = 0
     or %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ':SafeSubstr(l_command:1:1)) > 0
     or %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#@$':l_command) > 0;
    ReviewLine(i_lineNo:i_text:'Line is not an OCL statement or a command');
    return;
  endif;

  if l_command = 'NOHALT' and l_blankPos > 0 and %scan('(':i_text) = 0;
    // The NOHALT procedure takes the same operands as the OCL statement.
    l_operands = %trim(SafeSubstrToEnd(i_text:l_blankPos + 1));
    l_tail = SplitStatementTail(l_operands);
    ConvertNohalt(i_lineNo:i_text:l_operands);
    AddComment(l_tail);
    return;
  endif;

  if l_command = 'BLDFILE' and l_blankPos > 0;
    l_operands = %trim(SafeSubstrToEnd(i_text:l_blankPos + 1));
    l_tail = SplitStatementTail(l_operands);
    ConvertBldFile(i_lineNo:i_text:l_operands);
    AddComment(l_tail);
    return;
  endif;

  l_clLine = SubstituteExpressions(i_text:l_open);
  if l_open;
    ReviewLine(i_lineNo:i_text
               :'Command uses a substitution expression that is not converted');
    return;
  endif;
  AddBody(l_clLine);
  RptItem(C_STS_ASSUMPTION:i_lineNo:i_text
          :'Copied as a command; check that command ' + l_command + ' exists');
end-proc;

// ------------------------------------------------------------------
dcl-proc ProcessLine;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_text varchar(512) const;
  end-pi;

  dcl-s l_trimmedLine varchar(512);
  dcl-s l_commentText varchar(512);
  dcl-s l_first2 varchar(2);
  dcl-s l_last2 varchar(2);

  l_trimmedLine = %trim(i_text);
  g_curLineNo = i_lineNo;
  g_curText = i_text;

  if g_sortMode;
    if CollectSortLine(i_lineNo:i_text);
      return;
    endif;
  endif;

  l_first2 = '';
  l_last2 = '';
  if %len(l_trimmedLine) >= 2;
    l_first2 = SafeSubstr(l_trimmedLine:1:2);
    l_last2 = SafeSubstr(l_trimmedLine:%len(l_trimmedLine) - 1:2);
  endif;

  select;
    when %len(l_trimmedLine) = 0;
      AddBody('');
    when %len(l_trimmedLine) >= 4 and l_first2 = '/*' and l_last2 = '*/';
      // Already a CL comment: keep the text.
      AddCommentKeepingText(%trimr(SafeSubstr(l_trimmedLine:3:%len(l_trimmedLine) - 4)));
      RptItem(C_STS_CONVERTED:i_lineNo:i_text:'');
    when SafeSubstr(l_trimmedLine:1:1) = '*';
      // Keep the comment text exactly as written (after the asterisk).
      if %len(l_trimmedLine) > 1;
        l_commentText = %trimr(SafeSubstrToEnd(l_trimmedLine:2));
      else;
        l_commentText = '';
      endif;
      if %len(%trim(l_commentText)) = 0;
        AddBody('');
      else;
        AddCommentKeepingText(l_commentText);
      endif;
      RptItem(C_STS_CONVERTED:i_lineNo:i_text:'');
    when l_first2 = '/*' or l_first2 = '/&';
      g_afterRun = *off;
      ReviewLine(i_lineNo:i_text
                 :'End-of-data or end-of-job marker is not converted');
    when l_first2 = '//';
      ProcessStatement(i_lineNo:i_text);
    other;
      PassThroughClLine(i_lineNo:l_trimmedLine);
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
dcl-proc AddInitLine;
  dcl-pi *n;
    i_text varchar(200) const;
  end-pi;

  if g_initLineCnt < %elem(g_initLine);
    g_initLineCnt += 1;
    g_initLine(g_initLineCnt) = i_text;
  endif;
end-proc;

// ------------------------------------------------------------------
// Statements that fill the ?F'S,name'? variables: one DSPFD into
// QTEMP/IAFD for all the files, then one read of the outfile.
dcl-proc WriteInitSizes;
  dcl-pi *n int(10);
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_line varchar(512);
  dcl-s l_var varchar(20);

  AddInitLine('DLTF FILE(QTEMP/IAFD)');
  AddInitLine('MONMSG MSGID(CPF0000)');
  for l_index = 1 to g_initSizeCnt;
    AddInitLine('CHGVAR VAR(' + g_initSizeVar(l_index) + ') VALUE(''00000000'')');
    AddInitLine('DSPFD FILE(' + g_initSizeName(l_index) + ') TYPE(*ATR) FILEATR(*PF) '
                + 'OUTPUT(*OUTFILE) OUTFILE(QTEMP/IAFD) OUTMBR(*FIRST *ADD)');
    AddInitLine('MONMSG MSGID(CPF0000)');
  endfor;
  AddInitLine('OVRDBF FILE(QAFDPHY) TOFILE(QTEMP/IAFD)');
  AddInitLine('SZREAD: RCVF');
  AddInitLine('MONMSG MSGID(CPF0000) EXEC(GOTO CMDLBL(SZEND))');
  for l_index = 1 to g_initSizeCnt;
    l_var = g_initSizeVar(l_index);
    AddInitLine('IF COND(&PHFILE *EQ ''' + g_initSizeName(l_index) + ''') THEN(DO)');
    AddInitLine('CHGVAR VAR(&FSN) VALUE(&' + C_FDINITFLD + ')');
    AddInitLine('IF COND(&FSN *GT 99999999) THEN(CHGVAR VAR(&FSN) VALUE(99999999))');
    AddInitLine('CHGVAR VAR(&FSD) VALUE(&FSN)');
    AddInitLine('CHGVAR VAR(' + l_var + ') VALUE(&FSD)');
    AddInitLine('ENDDO');
  endfor;
  AddInitLine('GOTO CMDLBL(SZREAD)');
  AddInitLine('SZEND: DLTOVR FILE(QAFDPHY)');
  AddInitLine('MONMSG MSGID(CPF0000)');
  for l_index = 1 to g_initLineCnt;
    if WriteCl(g_initLine(l_index):o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endfor;
  return 0;
end-proc;

// ------------------------------------------------------------------
dcl-proc WriteProgram;
  dcl-pi *n int(10);
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_line varchar(512);
  dcl-s l_parms varchar(512);

  l_line = 'PGM';
  if g_maxParm > 0;
    l_parms = '';
    for l_index = 1 to g_maxParm;
      if l_index > 1;
        l_parms += ' ';
      endif;
      l_parms += '&P' + %trim(%char(l_index));
    endfor;
    l_line += ' PARM(' + l_parms + ')';
  endif;
  if WriteCl(l_line:o_msgId:o_msgData) <> 0;
    return 1;
  endif;

  for l_index = 1 to g_maxParm;
    if WriteCl('DCL VAR(&P' + %trim(%char(l_index)) + ') TYPE(*CHAR) LEN(10)'
               :o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endfor;
  // Parameters set by EVALUATE and not passed by the caller are local.
  for l_index = g_maxParm + 1 to 40;
    if g_parameterKind(l_index) = 'L';
      if WriteCl('DCL VAR(&P' + %trim(%char(l_index)) + ') TYPE(*CHAR) LEN('
                 + %trim(%char(%max(g_parameterLength(l_index):1))) + ')'
                 :o_msgId:o_msgData) <> 0;
        return 1;
      endif;
    endif;
  endfor;
  for l_index = 1 to g_tempVariableCount;
    if WriteCl('DCL VAR(&T' + %trim(%char(l_index)) + ') TYPE(*CHAR) LEN(50)'
               :o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endfor;
  if g_useMsgText;
    if WriteCl('DCL VAR(&MSGTXT) TYPE(*CHAR) LEN(132)':o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endif;
  for l_index = 1 to g_msgVarCount;
    if WriteCl('DCL VAR(&M' + %trim(%char(l_index)) + ') TYPE(*CHAR) LEN(75)'
               :o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endfor;
  if g_useMsgOut;
    if WriteCl('DCL VAR(&MSGOUT) TYPE(*CHAR) LEN(512)':o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endif;
  for l_index = 1 to g_fileSizeCount;
    if WriteCl('DCL VAR(&F' + %trim(%char(l_index)) + ') TYPE(*CHAR) LEN(8)'
               :o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endfor;
  if g_useFileSize;
    if WriteCl('DCL VAR(&FSN) TYPE(*DEC) LEN(10 0)':o_msgId:o_msgData) <> 0;
      return 1;
    endif;
    if WriteCl('DCL VAR(&FSD) TYPE(*DEC) LEN(8 0)':o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endif;
  for l_index = 1 to g_activeCount;
    if WriteCl('DCL VAR(&A' + %trim(%char(l_index)) + ') TYPE(*LGL) LEN(1)'
               :o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endfor;
  for l_index = 1 to g_dataf1Count;
    if WriteCl('DCL VAR(&D' + %trim(%char(l_index)) + ') TYPE(*LGL) LEN(1)'
               :o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endfor;
  if g_usePause;
    if WriteCl('DCL VAR(&PAUSERPY) TYPE(*CHAR) LEN(1)':o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endif;
  if g_libMode = 1;
    if WriteCl('DCL VAR(&OLDCURLIB) TYPE(*CHAR) LEN(10)':o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endif;
  if g_useDate;
    if WriteCl('DCL VAR(&DATE) TYPE(*CHAR) LEN(6)':o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endif;
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
  for l_index = 1 to g_ldaCnt;
    if WriteCl('DCL VAR(&L' + %trim(%char(g_ldaPosition(l_index))) + '_'
               + %trim(%char(g_ldaLength(l_index))) + ') TYPE(*CHAR) LEN('
               + %trim(%char(g_ldaLength(l_index))) + ')':o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endfor;
  if g_useSql;
    if WriteCl('DCL VAR(&SQL) TYPE(*CHAR) LEN(400)':o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endif;
  if g_initSizeCnt > 0;
    if WriteCl('DCLF FILE(QSYS/QAFDPHY) RCDFMT(QWHFDPHY)':o_msgId:o_msgData) <> 0;
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
  if g_libMode = 1;
    // Keep the current library of the caller; *NONE goes back as *CRTDFT.
    if WriteCl('RTVJOBA CURLIB(&OLDCURLIB)':o_msgId:o_msgData) <> 0;
      return 1;
    endif;
    if WriteCl('IF COND(&OLDCURLIB *EQ ''*NONE'') THEN(CHGVAR VAR(&OLDCURLIB)'
               + ' VALUE(''*CRTDFT''))':o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endif;
  if g_useDate;
    if WriteCl('RTVSYSVAL SYSVAL(QDATE) RTNVAR(&DATE)':o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endif;

  // Marker lock for the ACTIVE- test of other procedures (shared, job scope).
  if WriteCl('CRTDTAARA DTAARA(' + C_MARKLIB + '/' + g_procName
             + ') TYPE(*CHAR) LEN(1)':o_msgId:o_msgData) <> 0;
    return 1;
  endif;
  if WriteCl('MONMSG MSGID(CPF0000)':o_msgId:o_msgData) <> 0;
    return 1;
  endif;
  if WriteCl('ALCOBJ OBJ((' + C_MARKLIB + '/' + g_procName
             + ' *DTAARA *SHRRD)) WAIT(0)':o_msgId:o_msgData) <> 0;
    return 1;
  endif;
  if WriteCl('MONMSG MSGID(CPF0000)':o_msgId:o_msgData) <> 0;
    return 1;
  endif;

  if g_initSizeCnt > 0 and WriteInitSizes(o_msgId:o_msgData) <> 0;
    return 1;
  endif;

  AddCurLibExit();
  for l_index = 1 to g_bodyCnt;
    if WriteCl(g_body(l_index):o_msgId:o_msgData) <> 0;
      return 1;
    endif;
  endfor;

  if WriteCl('DLCOBJ OBJ((' + C_MARKLIB + '/' + g_procName + ' *DTAARA *SHRRD))'
             :o_msgId:o_msgData) <> 0;
    return 1;
  endif;
  if WriteCl('MONMSG MSGID(CPF0000)':o_msgId:o_msgData) <> 0;
    return 1;
  endif;
  if WriteCl('ENDPGM':o_msgId:o_msgData) <> 0;
    return 1;
  endif;
  return 0;
end-proc;

// ------------------------------------------------------------------
dcl-proc OclConvert export;
  dcl-pi *n int(10);
    i_source likeds(IAcnvDesc_t) const;
    i_target likeds(IAcnvDesc_t) const;
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  dcl-s l_text varchar(512);
  dcl-s l_next varchar(512);
  dcl-s l_trimmedLine varchar(512);
  dcl-s l_nextTrimmed varchar(512);
  dcl-s l_lineNo int(10);
  dcl-s l_first int(10);
  dcl-s l_returnCode int(10);

  InitReservedNames();
  g_bodyCnt = 0;
  g_overflow = *off;
  g_maxParm = 0;
  g_parameterKind(*) = ' ';
  g_parameterLength(*) = 0;
  g_useDate = *off;
  g_tempVariableCount = 0;
  g_ldaCnt = 0;
  g_ifLast = '';
  g_ifCtx = '';
  g_useUser = *off;
  g_useWs = *off;
  g_pendLoad = *off;
  g_afterRun = *off;
  g_overriddenFiles = '';
  g_sortMode = *off;
  g_sortNo = 0;
  g_sortCnt = 0;
  g_sortIn(*) = '';
  g_sortInLib(*) = '';
  g_sortSrcMbr = '';
  g_sortSrcLib = '';
  g_conditions = *off;
  g_ldaCnt = 0;
  g_blkCnt = 0;
  g_sortOut = '';
  g_sortOutLib = '';
  g_sortExtra = '';
  g_useSql = *off;
  g_isSort = *off;
  g_fileSizeCount = 0;
  g_initSizeCnt = 0;
  g_initLineCnt = 0;
  g_activeCount = 0;
  g_procName = ToUpper(%trim(i_source.mbr));
  g_dataf1Count = 0;
  g_useFileSize = *off;
  g_usePause = *off;
  g_libMode = 0;
  g_sessionLib = '';
  g_user1Member = '';
  g_user2Member = '';
  g_msgLibrary = '';
  g_msgVarCount = 0;
  g_useMsgText = *off;
  g_useMsgOut = *off;
  g_curLineNo = 0;
  g_curText = '';
  g_width = TargetWidthFor(i_target);
  if g_width <= 0;
    g_width = C_DFTWIDTH;
  endif;

  if OpenSource(i_source:o_msgId:o_msgData) <> 0;
    return 1;
  endif;

  dow ReadLine(l_text:l_lineNo);
    l_first = l_lineNo;
    l_trimmedLine = %trim(l_text);

    // A statement continues when it ends with a comma.
    if %len(l_trimmedLine) >= 2 and SafeSubstr(l_trimmedLine:1:2) = '//';
      dow %len(l_trimmedLine) > 0
          and SafeSubstr(l_trimmedLine:%len(l_trimmedLine):1) = ',';
        if not ReadLine(l_next:l_lineNo);
          leave;
        endif;
        l_nextTrimmed = %trim(l_next);
        if %len(l_nextTrimmed) >= 2 and SafeSubstr(l_nextTrimmed:1:2) = '//';
          l_nextTrimmed = %trim(SafeSubstrToEnd(l_nextTrimmed:3));
        endif;
        l_trimmedLine += l_nextTrimmed;
      enddo;
    endif;

    if %len(l_trimmedLine) >= 2 and SafeSubstr(l_trimmedLine:1:2) = '//';
      ProcessLine(l_first:l_trimmedLine);
    else;
      ProcessLine(l_first:l_text);   // comments keep their exact text
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

  if g_sortMode;
    WriteSortStep();
  endif;
  if g_pendLoad;
    ReviewLine(g_loadLine:g_loadText:'LOAD was never followed by RUN');
    g_pendLoad = *off;
  endif;
  if g_maxParm > 0;
    RptItem(C_STS_ASSUMPTION:0:'Parameters ?n?'
            :'Declared as CHAR(10); check the lengths the callers pass');
  endif;

  if OpenTarget(i_target:o_msgId:o_msgData) <> 0;
    return 1;
  endif;
  l_returnCode = WriteProgram(o_msgId:o_msgData);
  CloseTarget();
  return l_returnCode;
end-proc;
