**FREE
// IAdspCvt - conversion module of IAcnvDspf.
// DSPF36: System/36 display format source (SFGR: S, H and D specifications,
//        SC41-4730 Appendix B) to AS/400 DDS for a display file.
// DSPF38: System/38 display DDS, copied line by line (see docs/DSPF-MAPPING.md).
// Bind with service program IAcnvSrv.

ctl-opt nomain option(*srcstmt:*nodebugio);

/copy qcpysrc,IAcnvSrvP

dcl-c C_MAXSRC 20000;
dcl-c C_MAXOUT 40000;
dcl-c C_MAXNAMES 600;
dcl-c C_QUOTE '''';
dcl-c C_LOWER 'abcdefghijklmnopqrstuvwxyz';
dcl-c C_UPPER 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
dcl-c C_KEYW 36;                   // width of the DDS keyword area (cols 45-80)

// Source records are 80 columns: columns 1-5 sequence, 6 type, 7-80 data.
dcl-s g_sourceLines char(80) dim(C_MAXSRC);
dcl-s g_sourceLineNos int(10) dim(C_MAXSRC);
dcl-s g_sourceCount int(10);
dcl-s g_outputLines varchar(80) dim(C_MAXOUT);
dcl-s g_outputCount int(10);
dcl-s g_overflow ind;

dcl-s g_formatOpen ind;
dcl-s g_fmtName varchar(10);
dcl-s g_override ind;              // the open format uses override
dcl-s g_lowerDft ind;              // S-spec column 21 = Y for the open format
dcl-s g_rightToLeft ind;           // file level CHECK(RLTB) was written
dcl-s g_rzRbDropped ind;           // CHECK(RZ/RB) left out because MF is on the field
dcl-s g_formatCount int(10);
dcl-s g_generatedFieldNo int(10);
dcl-s g_outputConstReported ind;   // the Y-output constant assumption is in the report
dcl-s g_fieldNames varchar(10) dim(C_MAXNAMES);
dcl-s g_fieldNameCount int(10);
dcl-s g_srcLineNo int(10);         // line number reported for the current item

// Keywords collected for one field: indicator ('' = always, else 2 digits).
dcl-c C_MAXKW 40;
dcl-s g_keywordIndicators varchar(2) dim(C_MAXKW);
dcl-s g_keywordTexts varchar(80) dim(C_MAXKW);
dcl-s g_keywordCount int(10);

// Subfile candidates (DSP-06): display lines in a row that make one, highest line checked.
dcl-c C_SFLMIN 4;
dcl-c C_MAXDSPLINE 27;

// Format names of the whole source, for help formats that are defined later.
dcl-c C_MAXFMT 300;
dcl-s g_srcFormatNames varchar(10) dim(C_MAXFMT);
dcl-s g_ddsFormatNames varchar(10) dim(C_MAXFMT);
dcl-s g_srcFormatCount int(10);
dcl-s g_formatHelpKey ind inz(*off);   // HELP keyword written for this format

// Message file for message fields (command parameter MSGF); blank when none.
dcl-s g_msgFile varchar(10) inz('');
dcl-s g_msgLib varchar(10) inz('*LIBL');
dcl-s g_msgFieldNo int(10) inz(0);  // generated MSGID fields: MSG1, MSG2, ...

// ------------------------------------------------------------------
// Safe substring helpers (RPG %SUBST fails on empty or out-of-range input).
dcl-proc SafeMidText;
  dcl-pi *n varchar(512);
    i_text varchar(512) const;
    i_from int(10) const;
    i_length int(10) const;
  end-pi;

  dcl-s l_length int(10);

  if i_length <= 0 or i_from < 1 or i_from > %len(i_text);
    return '';
  endif;
  l_length = %min(i_length:%len(i_text) - i_from + 1);
  return %subst(i_text:i_from:l_length);
end-proc;

// ------------------------------------------------------------------
// Columns a through b of a source record, trimmed.
dcl-proc ColumnText;
  dcl-pi *n varchar(80);
    i_record char(80) const;
    i_fromColumn int(10) const;
    i_toColumn int(10) const;
  end-pi;

  return %trim(%subst(i_record:i_fromColumn:i_toColumn - i_fromColumn + 1));
end-proc;

// ------------------------------------------------------------------
// -1 when the text is not a whole number (empty counts as not a number).
dcl-proc ToNumber;
  dcl-pi *n int(10);
    i_text varchar(20) const;
  end-pi;

  dcl-s l_trimmedText varchar(20);

  l_trimmedText = %trim(i_text);
  if %len(l_trimmedText) = 0 or %len(l_trimmedText) > 9;
    return -1;
  endif;
  if %check('0123456789':l_trimmedText) > 0;
    return -1;
  endif;
  return %int(l_trimmedText);
end-proc;

// ------------------------------------------------------------------
// Horizontal position: 1-99, or A0..D2 for 100-132.
dcl-proc DecodeColumn;
  dcl-pi *n int(10);
    i_text varchar(20) const;
  end-pi;

  dcl-s l_trimmedText varchar(20);
  dcl-s l_base int(10);
  dcl-s l_digit int(10);

  l_trimmedText = %trim(i_text);
  if %len(l_trimmedText) = 2 and %scan(%subst(l_trimmedText:1:1):'ABCD') > 0;
    l_base = 100 + (%scan(%subst(l_trimmedText:1:1):'ABCD') - 1) * 10;
    l_digit = ToNumber(%subst(l_trimmedText:2:1));
    if l_digit < 0;
      return -1;
    endif;
    return l_base + l_digit;
  endif;
  return ToNumber(l_trimmedText);
end-proc;

// ------------------------------------------------------------------
// Entry that is Y, N (or blank) or an indicator 01-99:
//   'N' none, 'Y' always, 'I' + 2 digits an indicator, '?' anything else.
dcl-proc ParseIndicatorSpec;
  dcl-pi *n varchar(3);
    i_text varchar(20) const;
  end-pi;

  dcl-s l_trimmedText varchar(20);
  dcl-s l_number int(10);

  l_trimmedText = %trim(%xlate(C_LOWER:C_UPPER:i_text));
  if l_trimmedText = '' or l_trimmedText = 'N';
    return 'N';
  endif;
  if l_trimmedText = 'Y';
    return 'Y';
  endif;
  l_number = ToNumber(l_trimmedText);
  if l_number >= 1 and l_number <= 99 and %len(l_trimmedText) <= 2;
    return 'I' + %subst('0' + %trim(%char(l_number)):%len(%trim(%char(l_number))):2);
  endif;
  return '?';
end-proc;

// ------------------------------------------------------------------
// The indicator digits of an IndSpec result ('' when none).
dcl-proc IndicatorNumber;
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
dcl-proc RightJustify;
  dcl-pi *n varchar(10);
    i_number int(10) const;
    i_width int(10) const;
  end-pi;

  dcl-s l_text varchar(10);

  l_text = %trim(%char(i_number));
  if %len(l_text) >= i_width;
    return l_text;
  endif;
  return %subst('          ':1:i_width - %len(l_text)) + l_text;
end-proc;

// ------------------------------------------------------------------
dcl-proc AddOutputLine;
  dcl-pi *n;
    i_record char(80) const;
  end-pi;

  if g_outputCount >= C_MAXOUT;
    g_overflow = *on;
    return;
  endif;
  g_outputCount += 1;
  g_outputLines(g_outputCount) = %trimr(i_record);
end-proc;

// ------------------------------------------------------------------
// One DDS line: A in column 6, optional condition (column 8 N, 9-10
// indicator), name type (17), name (19-28), length (30-34), data type (35),
// decimals (36-37), usage (38), line (39-41), position (42-44), keywords
// (45-80). Empty or zero arguments leave their columns blank.
dcl-proc BuildDdsLine;
  dcl-pi *n char(80);
    i_condition varchar(2) const;
    i_negated ind const;
    i_nameType char(1) const;
    i_name varchar(10) const;
    i_length int(10) const;
    i_dataType char(1) const;
    i_decimals int(10) const;
    i_usage char(1) const;
    i_lineNumber int(10) const;
    i_column int(10) const;
    i_keywords varchar(36) const;
  end-pi;

  dcl-s l_record char(80) inz(*blanks);

  %subst(l_record:6:1) = 'A';
  if %len(i_condition) = 2;
    if i_negated;
      %subst(l_record:8:1) = 'N';
    endif;
    %subst(l_record:9:2) = i_condition;
  endif;
  %subst(l_record:17:1) = i_nameType;
  if %len(i_name) > 0;
    %subst(l_record:19:%len(i_name)) = i_name;
  endif;
  if i_length > 0;
    %subst(l_record:30:5) = RightJustify(i_length:5);
  endif;
  %subst(l_record:35:1) = i_dataType;
  if i_decimals >= 0;
    %subst(l_record:36:2) = RightJustify(i_decimals:2);
  endif;
  %subst(l_record:38:1) = i_usage;
  if i_lineNumber > 0;
    %subst(l_record:39:3) = RightJustify(i_lineNumber:3);
  endif;
  if i_column > 0;
    %subst(l_record:42:3) = RightJustify(i_column:3);
  endif;
  if %len(i_keywords) > 0;
    %subst(l_record:45:%len(i_keywords)) = i_keywords;
  endif;
  return l_record;
end-proc;

// ------------------------------------------------------------------
// A keyword (or keyword text) on its own line, optionally conditioned by
// an indicator.
dcl-proc AddKeywordLine;
  dcl-pi *n;
    i_indicator varchar(2) const;
    i_text varchar(36) const;
  end-pi;

  AddOutputLine(BuildDdsLine(i_indicator:*off:' ':'':0:' ':-1:' ':0:0:i_text));
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
  dcl-s l_index int(10);
  dcl-s l_total int(10);
  dcl-s l_textStart int(10);
  dcl-s l_textEnd int(10);
  dcl-s l_first ind inz(*on);
  dcl-s l_line char(80);

  l_textStart = %len(i_prefix) + 2;
  l_full = i_prefix + C_QUOTE + %scanrpl(C_QUOTE:C_QUOTE + C_QUOTE:i_text)
           + C_QUOTE + i_suffix;
  l_total = %len(l_full);
  l_textEnd = l_total - %len(i_suffix) - 1;          // last char of the text part
  l_chunk = '';
  l_index = 1;

  dow l_index <= l_total;
    // the rest fits on one line: take it all
    if %len(l_chunk) + (l_total - l_index + 1) <= C_KEYW;
      l_chunk += SafeMidText(l_full:l_index:l_total - l_index + 1);
      leave;
    endif;
    l_unit = SafeMidText(l_full:l_index:1);
    if l_unit = C_QUOTE and l_index >= l_textStart and l_index <= l_textEnd;
      l_unit = C_QUOTE + C_QUOTE;           // doubled apostrophe stays whole
    endif;
    if %len(l_chunk) + %len(l_unit) > C_KEYW - 1;
      if l_first;
        l_line = i_front;
        %subst(l_line:45:%len(l_chunk) + 1) = l_chunk + '-';
        AddOutputLine(l_line);
        l_first = *off;
      else;
        AddKeywordLine('':l_chunk + '-');
      endif;
      l_chunk = '';
    endif;
    l_chunk += l_unit;
    l_index += %len(l_unit);
  enddo;

  if l_first;
    l_line = i_front;
    %subst(l_line:45:%len(l_chunk)) = l_chunk;
    AddOutputLine(l_line);
  else;
    AddKeywordLine('':l_chunk);
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
dcl-proc IsNameUsed;
  dcl-pi *n ind;
    i_name varchar(10) const;
  end-pi;

  dcl-s l_index int(10);

  for l_index = 1 to %min(g_fieldNameCount:C_MAXNAMES);
    if g_fieldNames(l_index) = i_name;
      return *on;
    endif;
  endfor;
  return *off;
end-proc;

dcl-proc RememberName;
  dcl-pi *n;
    i_name varchar(10) const;
  end-pi;

  if g_fieldNameCount < C_MAXNAMES;
    g_fieldNameCount += 1;
    g_fieldNames(g_fieldNameCount) = i_name;
  endif;
end-proc;

// ------------------------------------------------------------------
// Help format name of the form axxxxxnn (SC41-4730 Appendix B, H specification):
// a letter, five letters or digits and two digits.
dcl-proc IsHelpFormatName;
  dcl-pi *n ind;
    i_name varchar(10) const;
  end-pi;

  if %len(i_name) <> 8;
    return *off;
  endif;
  if %check(C_UPPER:%subst(i_name:1:1)) > 0;
    return *off;
  endif;
  if %check(C_UPPER + '0123456789':%subst(i_name:2:5)) > 0;
    return *off;
  endif;
  return %check('0123456789':%subst(i_name:7:2)) = 0;
end-proc;

// ------------------------------------------------------------------
// Keys listed in the key mask (S-spec columns 64-79) become DDS keywords.
// i_mode is column 27 (function keys) or 28 (command keys): blank = all
// enabled, Y = only the listed ones, N = all but the listed, R = retain.
dcl-proc IsKeyEnabled;
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

dcl-proc AddKeyKeywords;
  dcl-pi *n;
    i_record char(80) const;
  end-pi;

  dcl-c C_FKEYS 'PRINT   ROLLUP  ROLLDOWNCLEAR   HELP    HOME    ';
  dcl-c C_CMDLET 'ABCDEFGHIJKLMNPQRSTUVWXY';

  dcl-s l_mask varchar(20);
  dcl-s l_keyNo int(10);
  dcl-s l_keyword varchar(8);
  dcl-s l_keyDigits varchar(2);

  l_mask = %xlate(C_LOWER:C_UPPER:ColumnText(i_record:64:79));

  for l_keyNo = 1 to 6;
    if IsKeyEnabled(%subst(i_record:27:1):%scan(%char(l_keyNo):l_mask) > 0);
      l_keyword = %trim(%subst(C_FKEYS:(l_keyNo - 1) * 8 + 1:8));
      AddKeywordLine('':l_keyword);
      if l_keyword = 'HELP';
        g_formatHelpKey = *on;
      endif;
    endif;
  endfor;

  for l_keyNo = 1 to 24;
    if IsKeyEnabled(%subst(i_record:28:1)
                 :%scan(%subst(C_CMDLET:l_keyNo:1):l_mask) > 0);
      l_keyDigits = %subst('0' + %trim(%char(l_keyNo)):%len(%trim(%char(l_keyNo))):2);
      AddKeywordLine('':'CF' + l_keyDigits + '(' + l_keyDigits + ')');
    endif;
  endfor;
end-proc;

// ------------------------------------------------------------------
// S specification: start of a record format.
dcl-proc ConvertDisplayControl;
  dcl-pi *n;
    i_record char(80) const;
    i_lineNo int(10) const;
  end-pi;

  dcl-s l_name varchar(10);
  dcl-s l_ddsName varchar(10);
  dcl-s l_value varchar(20);
  dcl-s l_number int(10);
  dcl-s l_spec varchar(3);
  dcl-s l_status char(1) inz(C_STS_CONVERTED);
  dcl-s l_reason varchar(200) inz('');

  l_name = ColumnText(i_record:7:14);
  g_formatCount += 1;
  g_fieldNameCount = 0;
  g_generatedFieldNo = 0;
  g_msgFieldNo = 0;
  g_formatOpen = *on;

  if ValidDdsName(l_name);
    l_ddsName = l_name;
  else;
    l_ddsName = 'FMT' + %trim(%char(g_formatCount));
    l_status = C_STS_ASSUMPTION;
    l_reason = 'Format name not valid in DDS; ' + l_ddsName
            + ' used and the original kept as ALTNAME';
  endif;
  AddOutputLine(BuildDdsLine('':*off:'R':l_ddsName:0:' ':-1:' ':0:0:''));
  if l_ddsName <> l_name and %len(l_name) > 0;
    AddKeywordLine('':'ALTNAME(' + C_QUOTE + l_name + C_QUOTE + ')');
  endif;
  if IsHelpFormatName(l_name);
    AddKeywordLine('':'HLPSEQ(' + %subst(l_name:1:6) + ' '
                   + %trim(%char(%int(%subst(l_name:7:2)))) + ')');
    if l_status = C_STS_CONVERTED;
      l_status = C_STS_ASSUMPTION;
      l_reason = 'HLPSEQ added: group = first 6 characters, sequence = last 2 digits';
    endif;
  endif;

  // Start line (17-18)
  l_value = %xlate(C_LOWER:C_UPPER:ColumnText(i_record:17:18));
  if l_value = 'V';
    AddKeywordLine('':'SLNO(*VAR)');
  elseif l_value <> '';
    l_number = ToNumber(l_value);
    if l_number >= 1;
      AddKeywordLine('':'SLNO(' + %trim(%char(l_number)) + ')');
    else;
      l_status = C_STS_REVIEW;
      l_reason = 'Start line number is not valid';
    endif;
  endif;

  // Lines to clear (19-20)
  l_value = ColumnText(i_record:19:20);
  if l_value = '';
    AddKeywordLine('':'CLRL(*ALL)');
  else;
    l_number = ToNumber(l_value);
    if l_number = 0;
      AddKeywordLine('':'CLRL(*NO)');
    elseif l_number > 0;
      AddKeywordLine('':'CLRL(' + %trim(%char(l_number)) + ')');
    else;
      l_status = C_STS_REVIEW;
      l_reason = 'Lines to clear is not valid';
    endif;
  endif;

  g_lowerDft = %subst(i_record:21:1) = 'Y' or %subst(i_record:21:1) = 'y';
  if %subst(i_record:22:1) <> 'N' and %subst(i_record:22:1) <> 'n';
    AddKeywordLine('':'RTNDTA');
  endif;

  // Alarm (25-26), blink cursor (29-30), erase input (31-32),
  // override (33-34), suppress input (35-36): Y or an indicator.
  l_spec = ParseIndicatorSpec(ColumnText(i_record:25:26));
  if l_spec <> 'N';
    if l_spec = '?';
      l_status = C_STS_REVIEW;
      l_reason = 'Sound alarm entry is not Y, N or an indicator';
    else;
      AddKeywordLine(IndicatorNumber(l_spec):'ALARM');
    endif;
  endif;
  l_spec = ParseIndicatorSpec(ColumnText(i_record:29:30));
  if l_spec <> 'N' and l_spec <> '?';
    AddKeywordLine(IndicatorNumber(l_spec):'BLINK');
  endif;
  l_spec = ParseIndicatorSpec(ColumnText(i_record:31:32));
  if l_spec <> 'N' and l_spec <> '?';
    // DDS: OVERLAY must be specified whenever ERASEINP is (CPD7567, CPD8111).
    AddKeywordLine('':'OVERLAY');
    AddKeywordLine(IndicatorNumber(l_spec):'ERASEINP');
    if l_status = C_STS_CONVERTED;
      l_status = C_STS_ASSUMPTION;
      l_reason = 'Erase input: OVERLAY added (DDS requires it with ERASEINP);'
              + ' the display is no longer cleared before the format is shown';
    endif;
  endif;
  l_spec = ParseIndicatorSpec(ColumnText(i_record:33:34));
  g_override = (l_spec <> 'N' and l_spec <> '?');
  if g_override;
    // DDS has no OVERRIDE keyword (CPD7484). The record is written with PUTOVR
    // while the indicator is on; OVRDTA and OVRATR on the fields need it
    // (CPD7615).
    AddKeywordLine(IndicatorNumber(l_spec):'PUTOVR');
    if l_status = C_STS_CONVERTED;
      l_status = C_STS_ASSUMPTION;
      l_reason = 'Override: PUTOVR written, OVRDTA/OVRATR added on fields;'
              + ' check the behaviour';
    endif;
  endif;
  l_spec = ParseIndicatorSpec(ColumnText(i_record:35:36));
  if l_spec <> 'N' and l_spec <> '?';
    AddKeywordLine(IndicatorNumber(l_spec):'LOCK');
  endif;

  g_formatHelpKey = *off;
  AddKeyKeywords(i_record);
  AddKeywordLine('':'INVITE');

  if %subst(i_record:39:1) = 'Y' or %subst(i_record:39:1) = 'y';
    if l_status = C_STS_CONVERTED;
      l_status = C_STS_ASSUMPTION;
      l_reason = '132-column format: the file is created for both sizes';
    endif;
  endif;
  RptItem(l_status:i_lineNo:%trimr(i_record):l_reason);
end-proc;

// ------------------------------------------------------------------
// Attribute and check keywords of one D specification are collected, then
// written after the field (or constant) line.
dcl-proc CollectKeyword;
  dcl-pi *n;
    i_indicator varchar(2) const;
    i_text varchar(80) const;
  end-pi;

  if g_keywordCount < C_MAXKW;
    g_keywordCount += 1;
    g_keywordIndicators(g_keywordCount) = i_indicator;
    g_keywordTexts(g_keywordCount) = i_text;
  endif;
end-proc;

dcl-proc WriteCollectedKeywords;
  dcl-s l_index int(10);

  for l_index = 1 to g_keywordCount;
    AddKeywordLine(g_keywordIndicators(l_index):g_keywordTexts(l_index));
  endfor;
  g_keywordCount = 0;
end-proc;

// ------------------------------------------------------------------
// Display attributes: columns 37-48 and 49 and position cursor (32-33).
// Returns *ON when an indicator controls one of the attributes.
dcl-proc CollectAttrs;
  dcl-pi *n ind;
    i_record char(80) const;
    i_input ind const;
  end-pi;

  dcl-c C_ATTR 'HI BL ND RI UL ';
  dcl-s l_always varchar(30);
  dcl-s l_attrNo int(10);
  dcl-s l_column int(10);
  dcl-s l_spec varchar(3);
  dcl-s l_token varchar(2);
  dcl-s l_hasInd ind inz(*off);

  l_always = '';
  for l_attrNo = 1 to 5;
    l_column = 37 + l_attrNo * 2;                    // 39, 41, 43, 45, 47
    l_spec = ParseIndicatorSpec(ColumnText(i_record:l_column:l_column + 1));
    l_token = %subst(C_ATTR:(l_attrNo - 1) * 3 + 1:2);
    select;
      when l_spec = 'Y';
        l_always += ' ' + l_token;
      when %subst(l_spec:1:1) = 'I';
        CollectKeyword(IndicatorNumber(l_spec):'DSPATR(' + l_token + ')');
        l_hasInd = *on;
    endsl;
  endfor;
  if %subst(i_record:49:1) = 'Y' or %subst(i_record:49:1) = 'y';
    l_always += ' CS';
  endif;

  if i_input;
    l_spec = ParseIndicatorSpec(ColumnText(i_record:37:38));            // protect
    if l_spec = 'Y';
      l_always += ' PR';
    elseif %subst(l_spec:1:1) = 'I';
      CollectKeyword(IndicatorNumber(l_spec):'DSPATR(PR)');
    endif;
    l_spec = ParseIndicatorSpec(ColumnText(i_record:32:33));            // position cursor
    if l_spec = 'Y';
      l_always += ' PC';
    elseif %subst(l_spec:1:1) = 'I';
      CollectKeyword(IndicatorNumber(l_spec):'DSPATR(PC)');
    endif;
  endif;
  if %len(l_always) > 0;
    CollectKeyword('':'DSPATR(' + %trim(l_always) + ')');
  endif;
  return l_hasInd;
end-proc;

// ------------------------------------------------------------------
// CHECK, DUP and LOWER keywords of an input field.
// Returns *ON when CHECK(AB) was left out (see below).
dcl-proc CollectInput;
  dcl-pi *n ind;
    i_record char(80) const;
    i_numeric ind const;
  end-pi;

  dcl-s l_abDropped ind inz(*off);
  dcl-s l_checks varchar(30);
  dcl-s l_char char(1);

  g_rzRbDropped = *off;
  l_checks = '';
  if %subst(i_record:29:1) = 'Y';
    l_checks += ' ME';
  endif;
  if %subst(i_record:28:1) = 'Y';
    l_checks += ' MF';
  endif;
  l_char = %subst(i_record:30:1);
  if l_char = 'T';
    l_checks += ' M10';
  elseif l_char = 'E';
    l_checks += ' M11';
  endif;
  l_char = %subst(i_record:31:1);
  if l_char = 'Z' or l_char = 'B';
    // DDS: CHECK(MF) cannot be specified with RB or RZ (CPD7621).
    if %subst(i_record:28:1) = 'Y';
      g_rzRbDropped = *on;
    elseif l_char = 'Z';
      l_checks += ' RZ';
    else;
      l_checks += ' RB';
    endif;
  endif;
  if %subst(i_record:35:1) = 'Y';
    l_checks += ' FE';
  endif;
  if %subst(i_record:36:1) = 'Y';
    // DDS: at field level AB must be used with another validity checking
    // keyword (M10, M11 and so on); CHECK(AB) alone does not compile.
    if %scan('M10':l_checks) > 0 or %scan('M11':l_checks) > 0;
      l_checks += ' AB';
    else;
      l_abDropped = *on;
    endif;
  endif;
  if %len(l_checks) > 0;
    CollectKeyword('':'CHECK(' + %trim(l_checks) + ')');
  endif;
  if %subst(i_record:34:1) = 'Y';
    CollectKeyword('':'DUP');
  endif;
  if not i_numeric
     and (%subst(i_record:51:1) = 'Y'
          or (%subst(i_record:51:1) = ' ' and g_lowerDft));
    CollectKeyword('':'LOWER');
  endif;
  return l_abDropped;
end-proc;

// ------------------------------------------------------------------
// SFGR data type (D-spec column 27) to DDS data type.
dcl-proc DdsType;
  dcl-pi *n char(1);
    i_dataType char(1) const;
  end-pi;

  select;
    when i_dataType = 'A';
      return 'X';
    when i_dataType = 'M';
      return 'N';
    when i_dataType = 'N';
      return 'M';
    when i_dataType = 'S';
      return 'S';
    when i_dataType = 'R';
      return 'I';
    when i_dataType = 'D';
      return 'D';
    when i_dataType = 'K';
      // Katakana (W) is not valid in a right-to-left file (CPD7873).
      if g_rightToLeft;
        return 'A';
      endif;
      return 'W';
  endsl;
  return 'A';                       // blank, B, Z and the double-byte types
end-proc;


// ------------------------------------------------------------------
// D column 25 is an edit code (marked WSU only in SC41-4730, which has no entry
// values). It is written as EDTCDE on numeric output-capable fields (see
// ConvertFieldDefinition); on constants and message fields it is not used: the
// item is reported for review. Does not change a status that is already R.
dcl-proc ReportEditCode;
  dcl-pi *n;
    i_record char(80) const;
    io_status char(1);
    io_reason varchar(200);
  end-pi;

  if %subst(i_record:25:1) = ' ';
    return;
  endif;
  if io_status <> C_STS_REVIEW;
    io_status = C_STS_REVIEW;
    io_reason = %trim(io_reason + ' Edit code ' + %subst(i_record:25:1)
              + ' (column 25) is not used on this item and is ignored.');
  endif;
end-proc;

// ------------------------------------------------------------------
// Message id of a message field (D column 56 = M): columns 57-60 are the
// 4-character MIC (0-9, A-F), columns 61-62 the message member (U1 or blank,
// U2, P1, P2, M1, M2). $SFGR assumes the prefix USR (SC41-4730 B-24); the
// prefix of DBCS messages (MIC above A000) is USZ (chapter 15).
// Returns USRnnnn, or '' when the data is blank or not a valid MIC.
dcl-proc MessageIdOf;
  dcl-pi *n varchar(7);
    i_data varchar(512) const;
  end-pi;

  dcl-s l_mic varchar(4);

  if %len(i_data) < 4;
    return '';
  endif;
  l_mic = %xlate(C_LOWER:C_UPPER:%subst(i_data:1:4));
  if %check('0123456789ABCDEF':l_mic) > 0;
    return '';
  endif;
  if %scan(%subst(l_mic:1:1):'ABCDEF') > 0 and l_mic > 'A000';
    return 'USZ' + l_mic;
  endif;
  return 'USR' + l_mic;
end-proc;

// The message member (columns 61-62) when it is not U1 or blank, else ''.
dcl-proc OtherMessageMember;
  dcl-pi *n varchar(2);
    i_data varchar(512) const;
  end-pi;

  dcl-s l_member varchar(2);

  if %len(i_data) < 6;
    return '';
  endif;
  l_member = %trim(%xlate(C_LOWER:C_UPPER:%subst(i_data:5:2)));
  if l_member = 'U1';
    return '';
  endif;
  return l_member;
end-proc;

// ------------------------------------------------------------------
// MSGID(message-id [library/]file) on a generated output field (name MSGn) of
// the given length at a line and column: the message text is read from the
// message file when the program writes the record (the file is searched in
// the library list unless a library is given). The condition is an
// indicator, or NOT it; '' for none. Returns the field name.
dcl-proc AddMessageField;
  dcl-pi *n varchar(10);
    i_indicator varchar(2) const;
    i_negated ind const;
    i_line int(10) const;
    i_column int(10) const;
    i_length int(10) const;
    i_messageId varchar(7) const;
  end-pi;

  dcl-s l_head varchar(30);
  dcl-s l_tail varchar(30);
  dcl-s l_name varchar(10);
  dcl-s l_keyword varchar(36);

  g_msgFieldNo += 1;
  l_name = 'MSG' + %trim(%char(g_msgFieldNo));
  dow IsNameUsed(l_name);
    g_msgFieldNo += 1;
    l_name = 'MSG' + %trim(%char(g_msgFieldNo));
  enddo;
  RememberName(l_name);

  l_head = 'MSGID(' + i_messageId;
  if g_msgLib = '*LIBL';
    l_tail = g_msgFile + ')';
  else;
    l_tail = g_msgLib + '/' + g_msgFile + ')';
  endif;
  if %len(l_head) + 1 + %len(l_tail) <= C_KEYW;
    l_keyword = l_head + ' ' + l_tail;
    AddOutputLine(BuildDdsLine(i_indicator:i_negated:' ':l_name:i_length:'A':-1
                  :'O':i_line:i_column:l_keyword));
  else;
    AddOutputLine(BuildDdsLine(i_indicator:i_negated:' ':l_name:i_length:'A':-1
                  :'O':i_line:i_column:l_head + ' +'));
    AddKeywordLine('':l_tail);
  endif;
  return l_name;
end-proc;

// ------------------------------------------------------------------
// D specification: one field or constant. io_i is the index of the record
// and moves on when the constant continues on following records.
dcl-proc ConvertFieldDefinition;
  dcl-pi *n;
    io_index int(10);
  end-pi;

  // DDS edit codes: 1-4, A-D, J-Q, X-Z and the user-defined 5-9 (EDTCDE).
  dcl-c C_EDTCDES '1234ABCDJKLMNOPQXYZ56789';

  dcl-s l_record char(80);
  dcl-s l_lineNo int(10);
  dcl-s l_name varchar(10);
  dcl-s l_length int(10);
  dcl-s l_line int(10);
  dcl-s l_column int(10);
  dcl-s l_outputSpec varchar(3);
  dcl-s l_indicator varchar(2);
  dcl-s l_isInput ind;
  dcl-s l_dataType char(1);
  dcl-s l_ddsType char(1);
  dcl-s l_usage char(1);
  dcl-s l_data varchar(512);
  dcl-s l_msgField varchar(10);
  dcl-s l_cont ind;
  dcl-s l_numeric ind;
  dcl-s l_attrInd ind;
  dcl-s l_status char(1) inz(C_STS_CONVERTED);
  dcl-s l_reason varchar(200) inz('');
  dcl-s l_ctype char(1);
  dcl-s l_fieldLength int(10);
  dcl-s l_decimals int(10);
  dcl-s l_front char(80);
  dcl-s l_nameGenerated ind inz(*off);
  dcl-s l_reported ind inz(*off);
  dcl-s l_messageId varchar(7) inz('');
  dcl-s l_member varchar(2) inz('');
  dcl-s l_editCode char(1) inz(' ');
  dcl-s l_editOk ind inz(*off);
  dcl-s l_editDigits int(10) inz(0);
  dcl-s l_editNote varchar(120) inz('');
  dcl-s l_dualDefinition ind inz(*off);   // input/output field with output indicator
  dcl-s l_baseKeywordCount int(10) inz(0);
  dcl-s l_index int(10);

  l_record = g_sourceLines(io_index);
  l_lineNo = g_sourceLineNos(io_index);

  l_name = ColumnText(l_record:7:14);
  l_length = ToNumber(ColumnText(l_record:15:18));
  l_line = ToNumber(ColumnText(l_record:19:20));
  l_column = DecodeColumn(ColumnText(l_record:21:22));
  l_outputSpec = ParseIndicatorSpec(ColumnText(l_record:23:24));
  l_isInput = (%subst(l_record:26:1) = 'Y' or %subst(l_record:26:1) = 'y');
  l_dataType = %xlate(C_LOWER:C_UPPER:%subst(l_record:27:1));
  l_ctype = %xlate(C_LOWER:C_UPPER:%subst(l_record:56:1));

  // Constant data is columns 57-79; column 80 = X continues it in columns
  // 7-79 of the next record(s).
  l_data = %trimr(%subst(l_record:57:23));
  l_cont = (%subst(l_record:80:1) = 'X' or %subst(l_record:80:1) = 'x');
  dow l_cont and io_index < g_sourceCount;
    io_index += 1;
    l_data = %trimr(l_data + %subst(g_sourceLines(io_index):7:73));
    l_cont = (%subst(g_sourceLines(io_index):80:1) = 'X'
              or %subst(g_sourceLines(io_index):80:1) = 'x');
  enddo;

  if l_length < 1 or l_line < 1 or l_column < 1;
    RptItem(C_STS_REVIEW:l_lineNo:%trimr(l_record)
            :'Field length, line or column is missing or not valid');
    return;
  endif;
  if l_outputSpec = '?';
    RptItem(C_STS_REVIEW:l_lineNo:%trimr(l_record)
            :'Output data entry is not Y, N or an indicator');
    return;
  endif;
  l_indicator = IndicatorNumber(l_outputSpec);
  g_keywordCount = 0;

  // ----- constant text: neither an output field nor an input field -----
  // Output Y with constant text (not a message field) is also a constant: DDS
  // does not accept DFT on an output-only field without OVRDTA, which needs an
  // option indicator.
  if not l_isInput and (l_outputSpec = 'N'
     or (l_outputSpec = 'Y' and %len(l_data) > 0 and l_ctype <> 'M'));
    if %len(l_data) = 0;
      RptItem(C_STS_ASSUMPTION:l_lineNo:%trimr(l_record)
              :'Field has no constant text and no data; skipped');
      return;
    endif;
    l_front = BuildDdsLine('':*off:' ':'':0:' ':-1:' ':l_line:l_column:'');
    AddLiteral(l_front:'':l_data:'');
    l_attrInd = CollectAttrs(l_record:*off);
    if g_override and l_attrInd;
      CollectKeyword('':'OVRATR');
    endif;
    WriteCollectedKeywords();
    ReportEditCode(l_record:l_status:l_reason);
    if l_status = C_STS_REVIEW;
      RptItem(l_status:l_lineNo:%trimr(l_record):l_reason);
      return;
    endif;
    if l_outputSpec = 'Y' and not g_outputConstReported;
      g_outputConstReported = *on;
      RptItem(C_STS_ASSUMPTION:l_lineNo:%trimr(l_record)
              :'Output Y with constant text is written as a constant (first'
              + ' one reported); the program cannot send data to it');
    else;
      RptItem(C_STS_CONVERTED:l_lineNo:%trimr(l_record):'');
    endif;
    return;
  endif;

  // ----- message constant: output Y, constant type M with a message id -----
  l_messageId = '';
  if l_ctype = 'M';
    l_messageId = MessageIdOf(l_data);
  endif;
  if l_ctype = 'M' and not l_isInput and l_outputSpec = 'Y'
     and l_messageId <> '' and g_msgFile <> '';
    l_msgField = AddMessageField('':*off:l_line:l_column:l_length:l_messageId);
    l_attrInd = CollectAttrs(l_record:*off);
    if g_override and l_attrInd;
      CollectKeyword('':'OVRATR');
    endif;
    WriteCollectedKeywords();
    l_reason = 'Message ' + l_messageId + ' written as field ' + l_msgField
            + ' with MSGID (file of the MSGF parameter, read at run time)';
    l_member = OtherMessageMember(l_data);
    if l_member <> '';
      l_reason = l_reason + '; message member ' + l_member
              + ' is not U1 but the same file is used';
    endif;
    l_status = C_STS_ASSUMPTION;
    ReportEditCode(l_record:l_status:l_reason);
    RptItem(l_status:l_lineNo:%trimr(l_record):l_reason);
    return;
  endif;

  // ----- named field -----
  l_numeric = (l_dataType = 'S' or l_dataType = 'N' or l_dataType = 'D');
  l_ddsType = 'A';
  if l_isInput;
    l_ddsType = DdsType(l_dataType);
    if l_dataType = 'K' and l_ddsType = 'A';
      l_status = C_STS_ASSUMPTION;
      l_reason = 'Katakana (K) is not valid with right-to-left (CHECK(RLTB));'
              + ' written as A';
    endif;
  endif;

  // Edit code (column 25): EDTCDE is only valid on output-capable numeric
  // fields, written with data type Y and 0 decimals (the D specification has no
  // decimal positions). An input/output field must be signed numeric (data type
  // S) in the source.
  l_editCode = %xlate(C_LOWER:C_UPPER:%subst(l_record:25:1));
  l_editDigits = l_length;
  if l_isInput;
    l_editDigits -= 1;
  endif;
  if l_editCode <> ' ' and l_ctype <> 'M';
    select;
      when %scan(l_editCode:C_EDTCDES) = 0;
        l_editNote = 'Edit code ' + l_editCode + ' (column 25) is not a DDS'
                   + ' edit code; not written';
      // EDTCDE(Y) is a date edit: 3 to 6 or 8 digits, and 7 with two leading
      // zeros suppressed (CPD7560 otherwise).
      when l_editCode = 'Y' and (l_editDigits < 3 or l_editDigits > 8);
        l_editNote = 'Edit code Y (column 25) needs 3 to 8 digits; not written';
      when l_isInput and l_outputSpec = 'N';
        l_editNote = 'Edit code ' + l_editCode + ' (column 25) is on an'
                   + ' input-only field; not written';
      when l_isInput and l_ddsType <> 'S';
        l_editNote = 'Edit code ' + l_editCode + ' (column 25) needs data'
                   + ' type S on an input/output field; not written';
      other;
        l_editOk = *on;
    endsl;
  endif;
  // EDTCDE is only valid with data type Y or blank (IBM i DDS reference; CRTDSPF
  // gives CPD7554 with S). Y is zoned numeric without a sign position, so an
  // input/output field keeps the digits of its signed length (length - 1).
  if l_editOk;
    l_ddsType = 'Y';
  endif;

  l_fieldLength = l_length;
  l_decimals = -1;
  if l_ddsType = 'S' or l_ddsType = 'Y';
    l_decimals = 0;
    if l_isInput;
      l_fieldLength = l_length - 1;
      if l_fieldLength < 1;
        RptItem(C_STS_REVIEW:l_lineNo:%trimr(l_record)
                :'Signed numeric field needs a length of at least 2');
        return;
      endif;
    endif;
  endif;

  if l_isInput and l_outputSpec <> 'N';
    l_usage = 'B';
  elseif l_isInput;
    l_usage = 'I';
  else;
    l_usage = 'O';
  endif;

  if not (ValidDdsName(l_name) and not IsNameUsed(l_name));
    g_generatedFieldNo += 1;
    l_name = 'FLD' + %trim(%char(g_generatedFieldNo));
    dow IsNameUsed(l_name);
      g_generatedFieldNo += 1;
      l_name = 'FLD' + %trim(%char(g_generatedFieldNo));
    enddo;
    l_nameGenerated = *on;
  endif;
  RememberName(l_name);
  if l_nameGenerated;
    l_status = C_STS_ASSUMPTION;
    l_reason = 'Field name missing, duplicate or invalid in DDS; '
            + l_name + ' generated (fields are positional on S/36)';
  endif;
  if l_ctype = 'M';
    l_status = C_STS_REVIEW;
    select;
      when l_messageId = '';
        l_reason = 'Message field without a valid message id: the program'
                + ' supplies the message at run time (no DDS equivalent);'
                + ' kept as a program output field';
      when g_msgFile = '';
        l_reason = 'Message field ' + l_messageId + ': give the MSGF parameter'
                + ' to write MSGID; kept as a program output field';
      when l_isInput;
        l_reason = 'Message field that allows input: kept as an input/output'
                + ' field, the message is not written';
      when %subst(l_outputSpec:1:1) = 'I';
        l_status = C_STS_ASSUMPTION;
        l_reason = 'Program output field while the indicator is on; message '
                + l_messageId + ' (MSGID) while it is off';
      other;
        l_reason = 'Message field ' + l_messageId + ' with output N: kept as'
                + ' a program output field';
    endsl;
  endif;
  // DSP-03: an input/output field with an output indicator is defined twice
  // with the same name: input/output while the indicator is on (the program's
  // data is shown) and input only while it is off (no data is sent).
  l_dualDefinition = (l_usage = 'B' and %subst(l_outputSpec:1:1) = 'I');
  if l_dualDefinition and l_status <> C_STS_REVIEW;
    l_status = C_STS_ASSUMPTION;
    l_reason = 'Output indicator ' + l_indicator + ' on an input/output field:'
            + ' written twice with the same name, input/output while ' + l_indicator
            + ' is on and input only while it is off';
  endif;
  if l_usage = 'I' and %len(l_data) > 0;
    if l_status = C_STS_CONVERTED;
      l_status = C_STS_ASSUMPTION;
      l_reason = 'Constant data on an input-only field is not used';
    endif;
  endif;

  if l_editOk;
    if l_status = C_STS_CONVERTED;
      l_status = C_STS_ASSUMPTION;
      l_reason = 'Edit code ' + l_editCode + ' written as EDTCDE';
      if not l_isInput;
        l_reason = l_reason + '; output field written as zoned numeric (S, 0'
                 + ' decimals), the display grows by the editing characters';
      endif;
    endif;
  elseif l_editNote <> '';
    l_status = C_STS_REVIEW;
    if l_reason <> '';
      l_reason = l_reason + '; ';
    endif;
    l_reason = l_reason + l_editNote;
  endif;

  // The field record. A pure output field with an output indicator is
  // shown only while the indicator is on; the constant text (if any) is
  // shown while it is off.
  if (l_usage = 'O' or l_dualDefinition) and %subst(l_outputSpec:1:1) = 'I';
    AddOutputLine(BuildDdsLine(l_indicator:*off:' ':l_name:l_fieldLength:
                  l_ddsType:l_decimals:l_usage:l_line:l_column:''));
  else;
    AddOutputLine(BuildDdsLine('':*off:' ':l_name:l_fieldLength:
                  l_ddsType:l_decimals:l_usage:l_line:l_column:''));
  endif;

  l_attrInd = CollectAttrs(l_record:l_isInput);
  if l_isInput;
    if CollectInput(l_record:l_numeric) and l_status = C_STS_CONVERTED;
      l_status = C_STS_ASSUMPTION;
      l_reason = 'CHECK(AB) left out: DDS needs another validity checking'
              + ' keyword with it';
    endif;
    if g_rzRbDropped and l_status = C_STS_CONVERTED;
      l_status = C_STS_ASSUMPTION;
      l_reason = 'CHECK(RZ/RB) left out: DDS does not allow it with CHECK(MF)';
    endif;
  endif;
  l_baseKeywordCount = g_keywordCount;      // keywords the input-only copy shares
  if l_editOk;
    CollectKeyword('':'EDTCDE(' + l_editCode + ')');
  endif;
  if g_override;
    if l_attrInd;
      CollectKeyword('':'OVRATR');
    endif;
    if %subst(l_outputSpec:1:1) = 'I';
      CollectKeyword(l_indicator:'OVRDTA');
    endif;
  endif;
  if l_dualDefinition;
    // First definition (indicator on): all keywords. Second definition
    // (indicator off): input only, with the attributes and checks but without
    // EDTCDE (output only) and OVRDTA (output data).
    for l_index = 1 to g_keywordCount;
      AddKeywordLine(g_keywordIndicators(l_index):g_keywordTexts(l_index));
    endfor;
    AddOutputLine(BuildDdsLine(l_indicator:*on:' ':l_name:l_fieldLength:
                  l_ddsType:l_decimals:'I':l_line:l_column:''));
    g_keywordCount = l_baseKeywordCount;
  endif;
  WriteCollectedKeywords();

  // message shown while the output indicator is off
  if l_ctype = 'M' and l_usage = 'O' and %subst(l_outputSpec:1:1) = 'I'
     and l_messageId <> '' and g_msgFile <> '';
    l_msgField = AddMessageField(l_indicator:*on:l_line:l_column:l_length:l_messageId);
    l_attrInd = CollectAttrs(l_record:*off);
    WriteCollectedKeywords();
  endif;

  // constant shown while the output indicator is off
  if l_ctype <> 'M' and l_usage = 'O' and %subst(l_outputSpec:1:1) = 'I'
     and %len(l_data) > 0;
    l_front = BuildDdsLine(l_indicator:*on:' ':'':0:' ':-1:' ':l_line:l_column:'');
    AddLiteral(l_front:'':l_data:'');
    l_attrInd = CollectAttrs(l_record:*off);
    WriteCollectedKeywords();
  endif;

  if l_ctype = 'M';
    ReportEditCode(l_record:l_status:l_reason);
  endif;
  RptItem(l_status:l_lineNo:%trimr(l_record):l_reason);
end-proc;

// ------------------------------------------------------------------
// The first S specification decides the file-level keywords.
dcl-proc AddFileLevelKeywords;
  dcl-s l_index int(10);
  dcl-s l_has132 ind inz(*off);
  dcl-s l_rightToLeft ind inz(*off);
  dcl-s l_first ind inz(*on);

  for l_index = 1 to g_sourceCount;
    if %subst(g_sourceLines(l_index):6:1) = 'S'
       and %subst(g_sourceLines(l_index):7:1) <> '*';
      if %subst(g_sourceLines(l_index):39:1) = 'Y'
         or %subst(g_sourceLines(l_index):39:1) = 'y';
        l_has132 = *on;
      endif;
      if l_first and (%subst(g_sourceLines(l_index):40:1) = 'Y'
                      or %subst(g_sourceLines(l_index):40:1) = 'y');
        l_rightToLeft = *on;
      endif;
      l_first = *off;
    endif;
  endfor;

  if l_has132;
    AddKeywordLine('':'DSPSIZ(24 80 *DS3 27 132 *DS4)');
  else;
    AddKeywordLine('':'DSPSIZ(24 80 *DS3)');
  endif;
  AddKeywordLine('':'INDARA');
  g_rightToLeft = l_rightToLeft;
  if l_rightToLeft;
    AddKeywordLine('':'CHECK(RLTB)');
  endif;
  RptItem(C_STS_ASSUMPTION:0:'File-level DDS'
          :'DSPSIZ and INDARA added (CHECK(RLTB) for right-to-left); '
          + 'INVITE added to every format');
end-proc;

// ------------------------------------------------------------------
// A keyword line conditioned by an indicator, or by NOT the indicator.
dcl-proc AddCondKeywordLine;
  dcl-pi *n;
    i_indicator varchar(2) const;
    i_negated ind const;
    i_text varchar(36) const;
  end-pi;

  AddOutputLine(BuildDdsLine(i_indicator:i_negated:' ':'':0:' ':-1:' ':0:0:i_text));
end-proc;

// ------------------------------------------------------------------
// Every S specification name and the DDS format name it gets (the same rule
// as ConvertDisplayControl), so an H specification can refer to a help format
// that is defined further down in the source.
dcl-proc CollectFormatNames;
  dcl-s l_index int(10);
  dcl-s l_count int(10) inz(0);
  dcl-s l_name varchar(10);

  g_srcFormatCount = 0;
  for l_index = 1 to g_sourceCount;
    if %xlate(C_LOWER:C_UPPER:%subst(g_sourceLines(l_index):6:1)) = 'S'
       and %subst(g_sourceLines(l_index):7:1) <> '*';
      l_count += 1;
      if g_srcFormatCount < C_MAXFMT;
        g_srcFormatCount += 1;
        l_name = ColumnText(g_sourceLines(l_index):7:14);
        g_srcFormatNames(g_srcFormatCount) = l_name;
        if ValidDdsName(l_name);
          g_ddsFormatNames(g_srcFormatCount) = l_name;
        else;
          g_ddsFormatNames(g_srcFormatCount) = 'FMT' + %trim(%char(l_count));
        endif;
      endif;
    endif;
  endfor;
end-proc;

// The DDS name of a format of this source, '' when there is none.
dcl-proc FindFormatDdsName;
  dcl-pi *n varchar(10);
    i_name varchar(10) const;
  end-pi;

  dcl-s l_index int(10);

  for l_index = 1 to g_srcFormatCount;
    if g_srcFormatNames(l_index) = i_name;
      return g_ddsFormatNames(l_index);
    endif;
  endfor;
  return '';
end-proc;

// ------------------------------------------------------------------
// H specification: one help area. Written after the S specification (and
// before the first D specification) as record-level help keywords:
//   H  HLPARA(row col row col) or HLPARA(*NONE) for a null area (the H is in
//      column 17), then HLPRCD(format [lib/file]) for a help format or
//      HLPDOC(label doc folder) for an online document, then HLPBDY (not with
//      HLPDOC) when column 50-51 asks.
// Suppress selection (44-45, an indicator) conditions HLPRCD/HLPDOC by NOT the
// indicator (HLPARA takes no option indicator). Restore display (47-48) has no
// DDS keyword and is reported, not written.
dcl-proc ConvertHelpDefinition;
  dcl-pi *n;
    i_record char(80) const;
    i_lineNo int(10) const;
  end-pi;

  dcl-s l_name varchar(10);
  dcl-s l_file varchar(10);
  dcl-s l_library varchar(10);
  dcl-s l_ddsName varchar(10);
  dcl-s l_error varchar(100) inz('');
  dcl-s l_note varchar(250) inz('');
  dcl-s l_reason varchar(400);
  dcl-s l_text varchar(20);
  dcl-s l_spec varchar(3);
  dcl-s l_isDocument ind inz(*off);
  dcl-s l_hasArea ind inz(*off);
  dcl-s l_upperRow int(10);
  dcl-s l_upperColumn int(10);
  dcl-s l_lowerRow int(10);
  dcl-s l_lowerColumn int(10);
  dcl-s l_suppress varchar(2) inz('');
  dcl-s l_boundary char(1) inz('N');          // N none, Y always, I indicator
  dcl-s l_boundaryIndicator varchar(2) inz('');
  dcl-s l_restore char(1) inz('D');           // D default, N never, I indicator
  dcl-s l_restoreIndicator varchar(2) inz('');
  dcl-s l_areaText varchar(36);
  dcl-s l_head varchar(30) inz('');
  dcl-s l_tail varchar(30) inz('');
  dcl-s l_outputRecord char(80);

  l_name = ColumnText(i_record:7:14);
  l_file = ColumnText(i_record:16:23);
  l_library = ColumnText(i_record:25:32);

  // Column 53: online document (Y) or help format (blank or N)
  l_text = %xlate(C_LOWER:C_UPPER:ColumnText(i_record:53:53));
  select;
    when l_text = 'Y';
      l_isDocument = *on;
    when l_text = '' or l_text = 'N';
      l_isDocument = *off;
    other;
      l_error = 'Online document entry (column 53) is not Y or N';
  endsl;

  if l_error = '' and l_name = '';
    l_error = 'Help format name or help text label (columns 7-14) is blank';
  endif;

  // Help area corners (34-37 and 39-42): both given, or both blank (null area)
  if l_error = '';
    l_hasArea = ColumnText(i_record:34:37) <> '' or ColumnText(i_record:39:42) <> '';
    if l_hasArea;
      l_upperRow = ToNumber(ColumnText(i_record:34:35));
      l_upperColumn = DecodeColumn(ColumnText(i_record:36:37));
      l_lowerRow = ToNumber(ColumnText(i_record:39:40));
      l_lowerColumn = DecodeColumn(ColumnText(i_record:41:42));
      if l_upperRow < 1 or l_upperRow > 27 or l_lowerRow < 1 or l_lowerRow > 27
         or l_upperColumn < 1 or l_upperColumn > 132
         or l_lowerColumn < 1 or l_lowerColumn > 132;
        l_error = 'Help area row or column is missing or not valid';
      elseif l_lowerRow < l_upperRow or l_lowerColumn < l_upperColumn;
        l_error = 'Help area lower right corner is above or left of the upper left';
      endif;
    endif;
  endif;

  // Suppress selection (44-45): blank or an indicator (Y and N are not allowed)
  if l_error = '';
    l_spec = ParseIndicatorSpec(ColumnText(i_record:44:45));
    if l_spec = 'Y' or l_spec = '?';
      l_error = 'Suppress selection (columns 44-45) must be blank or an indicator';
    else;
      l_suppress = IndicatorNumber(l_spec);
    endif;
  endif;

  // Restore display format (47-48): Y or blank, N, or an indicator
  if l_error = '';
    l_text = %xlate(C_LOWER:C_UPPER:ColumnText(i_record:47:48));
    if l_text = '' or l_text = 'Y';
      l_restore = 'D';
    elseif l_text = 'N';
      l_restore = 'N';
    else;
      l_spec = ParseIndicatorSpec(l_text);
      if %len(l_spec) = 3 and %subst(l_spec:1:1) = 'I';
        l_restore = 'I';
        l_restoreIndicator = IndicatorNumber(l_spec);
      else;
        l_error = 'Restore display format (columns 47-48) is not Y, N or an indicator';
      endif;
    endif;
  endif;

  // Boundary (50-51): blank or N, Y, or an indicator
  if l_error = '';
    l_spec = ParseIndicatorSpec(ColumnText(i_record:50:51));
    select;
      when l_spec = 'Y';
        l_boundary = 'Y';
      when l_spec = '?';
        l_error = 'Boundary (columns 50-51) is not Y, N or an indicator';
      when l_spec <> 'N';
        l_boundary = 'I';
        l_boundaryIndicator = IndicatorNumber(l_spec);
    endsl;
  endif;

  // What the area shows
  if l_error = '';
    if l_isDocument;
      if l_file = '' or l_library = '';
        l_error = 'Online document needs a document name and a folder name';
      elseif %len(l_name) > 8 or %scan(',':l_name) > 0 or %scan(' ':l_name) > 0
             or %scan(C_QUOTE:l_name) > 0;
        l_error = 'Help text label is not valid (1-8 characters, no comma or quote)';
      else;
        l_head = 'HLPDOC(' + l_name + ' ' + l_file + ' ' + l_library + ')';
      endif;
    elseif l_file = '' and l_library <> '';
      l_error = 'Help library given without a help display file name';
    elseif l_file = '';
      l_ddsName = FindFormatDdsName(l_name);
      if l_ddsName = '' and ValidDdsName(l_name);
        l_ddsName = l_name;
        l_note = 'Help format is not in this source; name used as it is';
      endif;
      if l_ddsName = '';
        l_error = 'Help format is not in this source and its name is not valid in DDS';
      else;
        l_head = 'HLPRCD(' + l_ddsName + ')';
      endif;
    elseif not ValidDdsName(l_name) or not ValidDdsName(l_file)
           or (l_library <> '' and not ValidDdsName(l_library));
      // $SFGR ignores it too: the other file's DDS format name is not known
      l_error = 'Help format in another file: a name is not valid in DDS (ignored)';
    else;
      l_head = 'HLPRCD(' + l_name;
      if l_library <> '';
        l_tail = l_library + '/' + l_file + ')';
      else;
        l_tail = l_file + ')';
      endif;
      if %len(l_head) + 1 + %len(l_tail) <= C_KEYW;
        l_head = l_head + ' ' + l_tail;
        l_tail = '';
      endif;
    endif;
  endif;

  if l_error <> '';
    l_outputRecord = i_record;
    %subst(l_outputRecord:1:5) = *blanks;
    %subst(l_outputRecord:6:1) = 'A';
    %subst(l_outputRecord:7:1) = '*';
    AddOutputLine(l_outputRecord);
    RptItem(C_STS_REVIEW:i_lineNo:%trimr(i_record):l_error);
    return;
  endif;

  if l_hasArea;
    l_areaText = 'HLPARA(' + %trim(%char(l_upperRow)) + ' '
               + %trim(%char(l_upperColumn)) + ' '
               + %trim(%char(l_lowerRow)) + ' '
               + %trim(%char(l_lowerColumn)) + ')';
  else;
    l_areaText = 'HLPARA(*NONE)';
  endif;
  // Help areas need the HELP keyword without a response indicator (IBM i DDS
  // reference, HELP): added to the format when the S specification gave none.
  if not g_formatHelpKey;
    AddKeywordLine('':'HELP');
    g_formatHelpKey = *on;
  endif;
  // The H in column 17 starts the help specification; HLPARA takes no option
  // indicator, so the suppress indicator goes on HLPRCD / HLPDOC (indicator off
  // = help active).
  AddOutputLine(BuildDdsLine('':*off:'H':'':0:' ':-1:' ':0:0:l_areaText));
  if l_tail = '';
    AddCondKeywordLine(l_suppress:*on:l_head);
  else;
    AddCondKeywordLine(l_suppress:*on:l_head + ' +');
    AddKeywordLine('':l_tail);
  endif;
  // HLPDOC cannot be used with HLPBDY or HLPRTN (IBM i DDS reference).
  if l_isDocument and l_boundary <> 'N';
    l_note = 'Boundary (columns 50-51) not written: HLPBDY cannot be used with HLPDOC';
  else;
    select;
      when l_boundary = 'Y';
        AddKeywordLine('':'HLPBDY');
      when l_boundary = 'I';
        AddKeywordLine(l_boundaryIndicator:'HLPBDY');
    endsl;
  endif;
  if l_restore <> 'D';
    if l_note <> '';
      l_note = l_note + '; ';
    endif;
    l_note = l_note + 'Restore display (columns 47-48) not written: no DDS '
           + 'keyword (RSTDSP is a CRTDSPF parameter)';
  endif;

  if l_isDocument;
    l_reason = 'Written as HLPARA and HLPDOC';
  else;
    l_reason = 'Written as HLPARA and HLPRCD';
  endif;
  l_reason = l_reason + '; keywords assumed, compile to confirm';
  if l_note <> '';
    l_reason = l_reason + '; ' + l_note;
  endif;
  RptItem(C_STS_ASSUMPTION:i_lineNo:%trimr(i_record):l_reason);
end-proc;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// DSP-06, RV-42: subfile candidates. In the D records of one format (from the first
// record after the S record to the last before the next S record) the lines that
// have the same fields at the same positions (column, length, output entry, input,
// data type; names, text and line number do not count) on C_SFLMIN or more
// consecutive display lines are reported once as R. The output is not changed:
// SFL and SFLCTL are only made when a real example shows how the program was changed.
dcl-proc CheckSubfileRows;
  dcl-pi *n;
    i_first int(10) const;
    i_last int(10) const;
  end-pi;

  dcl-s l_sig varchar(400) dim(C_MAXDSPLINE);
  dcl-s l_rec int(10) dim(C_MAXDSPLINE);
  dcl-s l_k int(10);
  dcl-s l_line int(10);
  dcl-s l_record char(80);
  dcl-s l_isField ind;
  dcl-s l_isConst ind;
  dcl-s l_cont ind inz(*off);
  dcl-s l_wasCont ind inz(*off);
  dcl-s l_ctype char(1);
  dcl-s l_run int(10);
  dcl-s l_start int(10);
  dcl-s l_out varchar(3);
  dcl-s l_inp char(1);

  for l_k = 1 to C_MAXDSPLINE;
    l_sig(l_k) = '';
    l_rec(l_k) = 0;
  endfor;
  for l_k = i_first + 1 to i_last;
    l_record = g_sourceLines(l_k);
    if %xlate(C_LOWER:C_UPPER:%subst(l_record:6:1)) <> 'D'
       or %subst(l_record:7:1) = '*';
      iter;
    endif;
    // Column 80 X: the next D record continues the constant text, it is no field.
    l_wasCont = l_cont;
    l_cont = (%subst(l_record:80:1) = 'X' or %subst(l_record:80:1) = 'x');
    if l_wasCont;
      iter;
    endif;
    l_line = ToNumber(ColumnText(l_record:19:20));
    if l_line < 1 or l_line > C_MAXDSPLINE;
      iter;
    endif;
    l_out = ParseIndicatorSpec(ColumnText(l_record:23:24));
    l_inp = %xlate(C_LOWER:C_UPPER:%subst(l_record:26:1));
    l_ctype = %xlate(C_LOWER:C_UPPER:%subst(l_record:56:1));
    // A constant is a label, not a field of the row. Same rule as
    // ConvertFieldDefinition: no input, and output N, or output Y with constant
    // text that is not a message (real members show borders as output Y text).
    l_isConst = l_inp <> 'Y' and (l_out = 'N'
                or (l_out = 'Y' and %trim(%subst(l_record:57:23)) <> ''
                    and l_ctype <> 'M'));
    l_isField = (l_inp = 'Y' or (l_out <> 'N' and l_out <> '')) and not l_isConst;
    if not l_isField;
      iter;
    endif;
    if l_rec(l_line) = 0;
      l_rec(l_line) = l_k;
    endif;
    l_sig(l_line) += ColumnText(l_record:21:22) + '/' + ColumnText(l_record:15:18)
                     + '/' + l_out + '/' + l_inp + '/'
                     + %xlate(C_LOWER:C_UPPER:%subst(l_record:27:1)) + ';';
  endfor;

  l_run = 0;
  l_start = 0;
  for l_k = 1 to C_MAXDSPLINE + 1;
    if l_k <= C_MAXDSPLINE and l_sig(l_k) <> ''
       and l_k > 1 and l_sig(l_k) = l_sig(l_k - 1);
      l_run += 1;
    else;
      if l_run >= C_SFLMIN;
        ReportSubfileRun(l_rec(l_start):l_start:l_start + l_run - 1);
      endif;
      l_run = 1;
      l_start = l_k;
    endif;
  endfor;
end-proc;

// ------------------------------------------------------------------
dcl-proc ReportSubfileRun;
  dcl-pi *n;
    i_index int(10) const;
    i_firstLine int(10) const;
    i_lastLine int(10) const;
  end-pi;

  if i_index < 1;
    return;
  endif;
  RptItem(C_STS_REVIEW:g_sourceLineNos(i_index):%trimr(g_sourceLines(i_index))
          :'Display lines ' + %char(i_firstLine) + ' to ' + %char(i_lastLine)
           + ' repeat the same fields at the same positions: a subfile candidate. '
           + 'The format is converted as written; SFL and SFLCTL are not made');
end-proc;

// ------------------------------------------------------------------
dcl-proc ConvertDsp36;
  dcl-s l_index int(10);
  dcl-s l_fmtFirst int(10) inz(0);
  dcl-s l_record char(80);
  dcl-s l_recordType char(1);
  dcl-s l_outputRecord char(80);

  g_formatOpen = *off;
  g_formatCount = 0;
  g_override = *off;
  AddFileLevelKeywords();
  CollectFormatNames();

  l_index = 1;
  dow l_index <= g_sourceCount;
    l_record = g_sourceLines(l_index);
    l_recordType = %xlate(C_LOWER:C_UPPER:%subst(l_record:6:1));
    select;
      when l_record = *blanks;
        // blank line: nothing to convert
      when %subst(l_record:1:4) = '*DDS' and %subst(l_record:7:1) = '*';
        l_outputRecord = l_record;
        %subst(l_outputRecord:6:1) = 'A';
        %subst(l_outputRecord:7:1) = ' ';
        AddOutputLine(l_outputRecord);
        RptItem(C_STS_CONVERTED:g_sourceLineNos(l_index):%trimr(l_record):'');
      when %subst(l_record:7:1) = '*';
        // comment: DDS comment, text from column 8 unchanged
        l_outputRecord = l_record;
        %subst(l_outputRecord:1:5) = *blanks;
        %subst(l_outputRecord:6:1) = 'A';
        AddOutputLine(l_outputRecord);
        RptItem(C_STS_CONVERTED:g_sourceLineNos(l_index):%trimr(l_record):'');
      when l_recordType = 'S';
        if l_fmtFirst > 0;
          CheckSubfileRows(l_fmtFirst:l_index - 1);
        endif;
        l_fmtFirst = l_index;
        ConvertDisplayControl(l_record:g_sourceLineNos(l_index));
      when l_recordType = 'H';
        if not g_formatOpen;
          RptItem(C_STS_REVIEW:g_sourceLineNos(l_index):%trimr(l_record)
                  :'H specification before the first S specification');
        else;
          ConvertHelpDefinition(l_record:g_sourceLineNos(l_index));
        endif;
      when l_recordType = 'D';
        if not g_formatOpen;
          RptItem(C_STS_REVIEW:g_sourceLineNos(l_index):%trimr(l_record)
                  :'D specification before the first S specification');
        else;
          ConvertFieldDefinition(l_index);
        endif;
      other;
        l_outputRecord = l_record;
        %subst(l_outputRecord:1:5) = *blanks;
        %subst(l_outputRecord:6:1) = 'A';
        %subst(l_outputRecord:7:1) = '*';
        AddOutputLine(l_outputRecord);
        RptItem(C_STS_REVIEW:g_sourceLineNos(l_index):%trimr(l_record)
                :'Record type in column 6 is not S, H or D');
    endsl;
    l_index += 1;
  enddo;
  if l_fmtFirst > 0;
    CheckSubfileRows(l_fmtFirst:g_sourceCount);
  endif;
end-proc;

// ------------------------------------------------------------------
// DSPF38: System/38 display DDS is valid input to CRTDSPF as it is.
dcl-proc CopyDsp38;
  dcl-s l_index int(10);

  for l_index = 1 to g_sourceCount;
    AddOutputLine(g_sourceLines(l_index));
    RptItem(C_STS_CONVERTED:g_sourceLineNos(l_index):%trimr(g_sourceLines(l_index)):'');
  endfor;
  RptItem(C_STS_ASSUMPTION:0:'DSPF38 source'
          :'Copied unchanged; compile with CRTDSPF to confirm');
end-proc;

// ------------------------------------------------------------------
dcl-proc DspConvert export;
  dcl-pi *n int(10);
    i_source likeds(IAcnvDesc_t) const;
    i_target likeds(IAcnvDesc_t) const;
    i_msgFile char(10) const;
    i_msgLib char(10) const;
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  dcl-s l_text varchar(512);
  dcl-s l_lineNo int(10);
  dcl-s l_index int(10);
  dcl-s l_lines int(10);
  dcl-s l_status char(1);
  dcl-s l_longCnt int(10) inz(0);
  dcl-s l_type varchar(10);

  g_sourceCount = 0;
  g_outputCount = 0;
  g_overflow = *off;
  g_override = *off;
  g_lowerDft = *off;
  g_keywordCount = 0;
  g_outputConstReported = *off;
  g_msgFile = %trim(i_msgFile);
  g_msgLib = %trim(i_msgLib);
  if g_msgLib = '';
    g_msgLib = '*LIBL';
  endif;

  if OpenSource(i_source:o_msgId:o_msgData) <> 0;
    return 1;
  endif;
  dow ReadLine(l_text:l_lineNo);
    if g_sourceCount >= C_MAXSRC;
      g_overflow = *on;
      leave;
    endif;
    g_sourceCount += 1;
    g_sourceLines(g_sourceCount) = l_text;
    g_sourceLineNos(g_sourceCount) = l_lineNo;
    if %len(%trimr(l_text)) > 80;
      l_longCnt += 1;
      RptItem(C_STS_REVIEW:l_lineNo:%trimr(l_text)
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

  l_type = %trim(%xlate(C_LOWER:C_UPPER:i_source.type));
  if l_type = 'DSPF38';
    CopyDsp38();
  else;
    ConvertDsp36();
  endif;
  if g_overflow;
    o_msgId = 'IAC0101';
    o_msgData = 'The converted DDS has more than ' + %char(C_MAXOUT) + ' lines';
    return 1;
  endif;

  if OpenTarget(i_target:o_msgId:o_msgData) <> 0;
    return 1;
  endif;
  for l_index = 1 to g_outputCount;
    if WriteText(g_outputLines(l_index):C_WRAP_NONE:l_lines:l_status:o_msgId:o_msgData)
       <> 0;
      CloseTarget();
      return 1;
    endif;
  endfor;
  CloseTarget();
  return 0;
end-proc;
