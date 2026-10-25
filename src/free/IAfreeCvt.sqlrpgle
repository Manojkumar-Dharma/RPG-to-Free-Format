**FREE
// IAfreeCvt - converter RPG36 (System/36-compatible RPG II) to fully
// free-form RPGLE (IACNVFREE).
// FREE-03: control (H) and file description (F) specifications, comment
// lines and the compiler directives /EJECT, /TITLE and /SPACE.
// FREE-04: input (I) specifications, as data structures.
// FREE-05: calculation (C) specifications, converted by module IAfreeCalc with
// the rule tables read by IAfreeRul (rules/*.json). Everything else (E, L, O
// specifications, compile-time data) is kept as a comment and reported R;
// those are later items (FREE-06, FREE-07). The rules are in
// docs/RPG-MAPPING.md. Module of program IACNVFREE. Target release V7R3.

ctl-opt nomain option(*srcstmt:*nodebugio);

/copy qcpysrc,IAcnvSrvP
/copy qcpysrc,IAfreeRulP
/copy qcpysrc,IAfreeCalcP

dcl-c C_MAXSRC 20000;
dcl-c C_MAXOUT 40000;
dcl-c C_MAXFILES 100;
dcl-c C_MAXNAMES 3000;
dcl-c C_MAXBLOCK 600;
dcl-c C_LOWER 'abcdefghijklmnopqrstuvwxyz';
dcl-c C_UPPER 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
dcl-c C_DIGITS '0123456789';
dcl-c C_QUOTE '''';

dcl-s g_sourceLines char(100) dim(C_MAXSRC);
dcl-s g_sourceLineNos int(10) dim(C_MAXSRC);
dcl-s g_sourceCount int(10);
dcl-s g_outputLines varchar(200) dim(C_MAXOUT);
dcl-s g_outputLineNos int(10) dim(C_MAXOUT);
dcl-s g_outputCount int(10);
dcl-s g_overflow ind;
dcl-s g_headerSeen ind;
dcl-s g_dialect char(1) inz('2');
// Files declared by converted file descriptions, for the input specifications.
dcl-s g_fileNames varchar(8) dim(C_MAXFILES);
dcl-s g_fileLens int(10) dim(C_MAXFILES);
dcl-s g_fileDevices char(1) dim(C_MAXFILES);
dcl-s g_fileTypes char(1) dim(C_MAXFILES);
dcl-s g_fileHasLayout ind dim(C_MAXFILES);
dcl-s g_fileCount int(10);
// Names defined so far (files, data structures, fields) and the line of each.
dcl-s g_nameList varchar(12) dim(C_MAXNAMES);
dcl-s g_nameLines int(10) dim(C_MAXNAMES);
dcl-s g_nameCount int(10);
// Lines of the data structure being built.
dcl-s g_blockText varchar(200) dim(C_MAXBLOCK);
dcl-s g_blockLineNos int(10) dim(C_MAXBLOCK);
dcl-s g_blockCount int(10);

// ------------------------------------------------------------------
dcl-proc FreeConvert export;
  dcl-pi *n int(10);
    i_source likeds(IAcnvDesc_t) const;
    i_target likeds(IAcnvDesc_t) const;
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  dcl-s l_text varchar(512);
  dcl-s l_lineNo int(10);
  dcl-s l_index int(10);
  dcl-s l_lines int(10);
  dcl-s l_status char(1);

  g_sourceCount = 0;
  g_outputCount = 0;
  g_overflow = *off;
  g_headerSeen = *off;
  g_fileCount = 0;
  g_nameCount = 0;
  g_blockCount = 0;

  select;
    when %trim(%xlate(C_LOWER:C_UPPER:i_source.type)) = 'RPG36';
      g_dialect = '2';
    when %trim(%xlate(C_LOWER:C_UPPER:i_source.type)) = 'RPG38'
         or %trim(%xlate(C_LOWER:C_UPPER:i_source.type)) = 'RPG'
         or %trim(%xlate(C_LOWER:C_UPPER:i_source.type)) = 'SQLRPG';
      g_dialect = '3';
    other;
      o_msgId = 'IAC0103';
      o_msgData = %trim(i_source.type)
                  + ' (only RPG36, RPG38, RPG and SQLRPG are converted so far)';
      return 1;
  endsl;

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

  if RulLoad(g_dialect:o_msgId:o_msgData) <> 0;
    return 1;
  endif;

  AddOut('**FREE':0);
  CalcStart();
  ConvertSource();
  CalcFinish();
  if g_overflow;
    o_msgId = 'IAC0101';
    o_msgData = 'The converted source has more than ' + %char(C_MAXOUT) + ' lines';
    return 1;
  endif;

  if OpenTarget(i_target:o_msgId:o_msgData) <> 0;
    return 1;
  endif;
  for l_index = 1 to g_outputCount;
    if WriteText(g_outputLines(l_index):C_WRAP_FREE:l_lines:l_status:o_msgId:o_msgData)
       <> 0;
      CloseTarget();
      return 1;
    endif;
    if l_status = C_STS_REVIEW;
      RptItem(C_STS_REVIEW:g_outputLineNos(l_index):g_outputLines(l_index)
              :'Line is longer than the target and has no safe place to break');
    endif;
  endfor;
  CloseTarget();
  return 0;
end-proc;

// ------------------------------------------------------------------
// One pass over the source lines. Columns follow the RPG II coding forms:
// 1-5 sequence, 6 form type, 7 comment asterisk, 75-80 program identification.
dcl-proc ConvertSource;
  dcl-pi *n;
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_lineNo int(10);
  dcl-s l_line char(100);
  dcl-s l_up char(100);
  dcl-s l_form char(1);
  dcl-s l_data ind inz(*off);
  dcl-s l_extra int(10);
  dcl-s l_reason varchar(100);

  l_index = 1;
  dow l_index <= g_sourceCount and not g_overflow;
    l_line = g_sourceLines(l_index);
    l_up = %xlate(C_LOWER:C_UPPER:l_line);
    l_lineNo = g_sourceLineNos(l_index);
    l_form = %subst(l_up:6:1);
    l_extra = 0;

    select;
      // After the ** record everything is compile-time data: copied as is.
      when l_data;
        AddOut(%trimr(l_line):l_lineNo);
      when %subst(l_line:1:2) = '**';
        l_data = *on;
        AddOut(%trimr(l_line):l_lineNo);
        RptItem(C_STS_REVIEW:l_lineNo:%trimr(l_line)
                :'Compile-time data is kept as is; arrays are not converted yet');
      when %trim(%subst(l_line:6:75)) = '';
        AddOut('':l_lineNo);
      when %subst(l_line:7:1) = '*';
        AddOut('//' + %trimr(%subst(l_line:8:73)):l_lineNo);
      // SQLRPG: C/EXEC SQL, C+ lines and C/END-EXEC become EXEC SQL statements.
      when SqlHere(l_form:l_line:l_lineNo);
      when %subst(l_line:7:1) = '/';
        ConvertDirective(l_lineNo:l_line);
      when l_form = 'H';
        ConvertHeader(l_lineNo:l_line);
      when l_form = 'F';
        l_extra = ConvertFile(l_index:l_lineNo:l_line);
      when l_form = 'I';
        l_extra = ConvertInput(l_index:l_lineNo:l_line);
      other;
        select;
          when l_form = 'E';
            l_reason = 'E (extension) specification not converted yet';
          when l_form = 'L';
            l_reason = 'L (line counter) specification not converted yet';
          when l_form = 'C';
            l_reason = '';
          when l_form = 'O';
            l_reason = 'O specification not converted yet (FREE-06)';
          other;
            l_reason = 'Unknown specification type in column 6';
        endsl;
        if l_form = 'C';
          CalcLine(l_line:l_lineNo);
        else;
          ReviewSpec(l_lineNo:l_line:l_reason);
        endif;
    endsl;

    l_index += 1 + l_extra;
  enddo;
end-proc;

// ------------------------------------------------------------------
// An SQLRPG line of an embedded SQL statement (RPG III dialect, C specification
// type): handled by IAfreeCalc. Returns *off for every other line.
dcl-proc SqlHere;
  dcl-pi *n ind;
    i_form char(1) const;
    i_line char(100) const;
    i_lineNo int(10) const;
  end-pi;

  if i_form <> 'C';
    return *off;
  endif;
  if g_dialect <> '3';
    return *off;
  endif;
  return CalcSqlLine(i_line:i_lineNo);
end-proc;

// ------------------------------------------------------------------
// /EJECT, /TITLE and /SPACE are valid in fully free-form source and are kept.
dcl-proc ConvertDirective;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_line char(100) const;
  end-pi;

  dcl-s l_text varchar(80);
  dcl-s l_word varchar(10);
  dcl-s l_blank int(10);

  l_text = %trim(%subst(i_line:7:68));
  l_blank = %scan(' ':l_text);
  if l_blank = 0;
    l_word = %xlate(C_LOWER:C_UPPER:l_text);
  else;
    l_word = %xlate(C_LOWER:C_UPPER:%subst(l_text:1:l_blank - 1));
  endif;

  if l_word = '/EJECT' or l_word = '/TITLE' or l_word = '/SPACE';
    AddOut(l_text:i_lineNo);
    RptItem(C_STS_CONVERTED:i_lineNo:l_text:'');
  else;
    ReviewSpec(i_lineNo:i_line:'Compiler directive ' + l_word + ' is not converted');
  endif;
end-proc;

// ------------------------------------------------------------------
// H: control specification (RPG II guide, chapter 18) to ctl-opt (Reference,
// ctl-opt keywords). Columns 7-14 (size), 10-12, 16-17, 22-25, 27-36, 38-40,
// 42, 44, 46-56 and 58-74 have no relevance on the AS/400 system.
dcl-proc ConvertHeader;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_line char(100) const;
  end-pi;

  dcl-s l_up char(100);
  dcl-s l_kw varchar(300) inz('');
  dcl-s l_note varchar(190) inz('');
  dcl-s l_review varchar(190) inz('');
  dcl-s l_symbol char(1);
  dcl-s l_dateFmt char(1);
  dcl-s l_dateSep char(1);
  dcl-s l_invert char(1);
  dcl-s l_format varchar(4);
  dcl-s l_sep varchar(1);
  dcl-s l_progId varchar(6);
  dcl-s l_dateOk ind inz(*on);
  dcl-s l_status char(1);
  dcl-s l_reason varchar(200);

  if g_headerSeen;
    ReviewSpec(i_lineNo:i_line
               :'More than one control specification; only the first is converted');
    return;
  endif;
  g_headerSeen = *on;
  l_up = %xlate(C_LOWER:C_UPPER:i_line);

  // Column 15: DEBUG.
  if %subst(l_up:15:1) = '1';
    AppendKeyword(l_kw:'debug(*dump)');
    AppendText(l_note:'column 15: the DEBUG operation itself is a C specification '
               + 'item');
  endif;

  // Column 18: currency symbol.
  l_symbol = %subst(i_line:18:1);
  if l_symbol <> ' ';
    if %scan(%xlate(C_LOWER:C_UPPER:l_symbol):'0*,&.-CR') > 0;
      AppendText(l_review:'Currency symbol (column 18) ' + l_symbol
                 + ' is not allowed');
    elseif l_symbol = C_QUOTE;
      AppendKeyword(l_kw:'cursym(' + C_QUOTE + C_QUOTE + C_QUOTE + C_QUOTE + ')');
    else;
      AppendKeyword(l_kw:'cursym(' + C_QUOTE + l_symbol + C_QUOTE + ')');
    endif;
  endif;

  // Columns 19-21: date format, date edit, inverted print.
  l_dateFmt = %subst(l_up:19:1);
  l_dateSep = %subst(i_line:20:1);
  l_invert = %subst(l_up:21:1);
  if l_dateFmt <> ' ' and l_dateFmt <> 'M' and l_dateFmt <> 'D' and l_dateFmt <> 'Y';
    AppendText(l_review:'Date format (column 19) must be blank, M, D or Y');
    l_dateOk = *off;
  endif;
  if l_invert <> ' ' and l_invert <> 'D' and l_invert <> 'I' and l_invert <> 'J';
    AppendText(l_review:'Inverted print (column 21) must be blank, D, I or J');
    l_dateOk = *off;
  endif;
  if l_dateOk and (l_dateFmt <> ' ' or l_dateSep <> ' ' or l_invert <> ' ');
    select;
      when l_dateFmt = 'M';
        l_format = '*MDY';
      when l_dateFmt = 'D';
        l_format = '*DMY';
      when l_dateFmt = 'Y';
        l_format = '*YMD';
      other;
        if l_invert = 'D' or l_invert = 'I' or l_invert = 'J';
          l_format = '*DMY';
        else;
          l_format = '*MDY';
        endif;
    endsl;
    if l_dateSep = ' ';
      if (l_dateFmt = 'Y' or l_dateFmt = ' ') and (l_invert = 'I' or l_invert = 'J');
        l_sep = '.';
      else;
        l_sep = '/';
      endif;
    else;
      l_sep = l_dateSep;
    endif;
    if l_sep = '(' or l_sep = ')' or l_sep = C_QUOTE;
      AppendText(l_review:'Date separator (column 20) is not valid');
    else;
      AppendKeyword(l_kw:'datedit(' + l_format + l_sep + ')');
    endif;
  endif;
  if l_invert = 'I';
    AppendKeyword(l_kw:'decedit(' + C_QUOTE + ',' + C_QUOTE + ')');
  elseif l_invert = 'J';
    AppendKeyword(l_kw:'decedit(' + C_QUOTE + '0,' + C_QUOTE + ')');
  endif;

  // Column 26: alternate collating sequence needs its table (not converted).
  if %subst(l_up:26:1) = 'S';
    AppendText(l_review:'Alternate collating sequence (column 26) needs its '
               + 'table');
  endif;
  // Column 37: inquiry. Blank and I behave the same; B is S/36 specific.
  if %subst(l_up:37:1) = 'B';
    AppendText(l_review:'Inquiry B (column 37) is a System/36 environment function');
  endif;
  // Column 41: 1P forms position.
  if %subst(l_up:41:1) = '1';
    AppendKeyword(l_kw:'formsalign(*yes)');
  endif;
  // Column 43: file translation needs its table (not converted).
  if %subst(l_up:43:1) = 'F';
    AppendText(l_review:'File translation (column 43) needs its table');
  endif;
  // Column 45: nonprint characters has no equivalent.
  if %subst(l_up:45:1) = '1';
    AppendText(l_note:'column 45 (nonprint characters) has no equivalent and is '
               + 'ignored');
  endif;
  // Column 57: transparent literals (double-byte data).
  if %subst(l_up:57:1) = '1';
    AppendText(l_review:'Transparent literals (column 57) are not converted');
  endif;
  // Columns 75-80: program name, set on the compile command in RPG IV.
  l_progId = %trim(%subst(i_line:75:6));
  if %len(l_progId) > 0;
    AppendText(l_note:'program name ' + l_progId + ' is set on the compile command');
  endif;

  if l_kw <> '';
    AddOut('ctl-opt ' + l_kw + ';':i_lineNo);
  endif;
  if l_review <> '';
    AddOut('// ' + RulDialectLabel() + ': ' + %trimr(%subst(i_line:6:69)):i_lineNo);
    l_status = C_STS_REVIEW;
  elseif l_note <> '';
    l_status = C_STS_ASSUMPTION;
  else;
    l_status = C_STS_CONVERTED;
  endif;
  l_reason = l_review;
  if l_note <> '';
    if l_reason <> '';
      l_reason += '; ';
    endif;
    l_reason += l_note;
  endif;
  RptItem(l_status:i_lineNo:%trimr(%subst(i_line:6:69)):l_reason);
end-proc;

// ------------------------------------------------------------------
// F: file description specification (RPG II guide, chapter 19) to dcl-f
// (Reference, Tables 105 and 106). DISK and PRINTER files only. Returns the
// number of continuation records that follow the specification and were
// consumed with it.
dcl-proc ConvertFile;
  dcl-pi *n int(10);
    i_index int(10) const;
    i_lineNo int(10) const;
    i_line char(100) const;
  end-pi;

  dcl-s l_up char(100);
  dcl-s l_extra int(10);
  dcl-s l_name varchar(8);
  dcl-s l_type char(1);
  dcl-s l_desig char(1);
  dcl-s l_eof char(1);
  dcl-s l_seq char(1);
  dcl-s l_fmt char(1);
  dcl-s l_recLen varchar(4);
  dcl-s l_mode char(1);
  dcl-s l_keyLen varchar(2);
  dcl-s l_addr char(1);
  dcl-s l_org char(1);
  dcl-s l_ovf varchar(2);
  dcl-s l_keyStart varchar(4);
  dcl-s l_ext char(1);
  dcl-s l_device varchar(7);
  dcl-s l_add char(1);
  dcl-s l_cond varchar(2);
  dcl-s l_usage varchar(40);
  dcl-s l_stmt varchar(200);
  dcl-s l_note varchar(190) inz('');
  dcl-s l_cont1 int(10);

  l_up = %xlate(C_LOWER:C_UPPER:i_line);
  l_extra = CountContinuations(i_index);
  l_name = %trim(%subst(l_up:7:8));
  l_type = %subst(l_up:15:1);
  l_desig = %subst(l_up:16:1);
  l_eof = %subst(l_up:17:1);
  l_seq = %subst(l_up:18:1);
  l_fmt = %subst(l_up:19:1);
  l_recLen = %trim(%subst(l_up:24:4));
  l_mode = %subst(l_up:28:1);
  l_keyLen = %trim(%subst(l_up:29:2));
  l_addr = %subst(l_up:31:1);
  l_org = %subst(l_up:32:1);
  l_ovf = %trim(%subst(l_up:33:2));
  l_keyStart = %trim(%subst(l_up:35:4));
  l_ext = %subst(l_up:39:1);
  l_device = %trim(%subst(l_up:40:7));
  l_add = %subst(l_up:66:1);
  l_cond = %trim(%subst(l_up:71:2));

  // Continuation records (RECNO, SUBR exit, NUM, FMTS, INFSR ...): the whole
  // file is kept as comments so that no option is lost silently.
  if l_extra > 0 or %subst(l_up:53:1) = 'K';
    ReviewSpec(i_lineNo:i_line
               :'Continuation records (RECNO, SUBR exit, NUM, FMTS, INFSR) are not '
                + 'converted');
    for l_cont1 = 1 to l_extra;
      ReviewSpec(g_sourceLineNos(i_index + l_cont1):g_sourceLines(i_index + l_cont1)
                 :'Continuation of the file description above');
    endfor;
    return l_extra;
  endif;

  select;
    when not IsFileName(l_name);
      ReviewSpec(i_lineNo:i_line:'File name (columns 7-14) is not valid');
      return 0;
    when l_type <> 'I' and l_type <> 'O' and l_type <> 'U' and l_type <> 'C';
      ReviewSpec(i_lineNo:i_line:'File type (column 15) must be I, O, U or C');
      return 0;
    when l_device <> 'DISK' and l_device <> 'PRINTER';
      if l_device = 'WORKSTN';
        ReviewSpec(i_lineNo:i_line:'Device WORKSTN is not converted yet: it needs '
                   + 'the display file and the format I/O');
      elseif l_device = '';
        ReviewSpec(i_lineNo:i_line:'Device (columns 40-46) is blank');
      else;
        ReviewSpec(i_lineNo:i_line:'Device ' + l_device + ' is not converted yet');
      endif;
      return 0;
    when l_fmt <> ' ' and l_fmt <> 'F' and not (g_dialect = '3' and l_fmt = 'E');
      ReviewSpec(i_lineNo:i_line
                 :'Record format (column 19) ' + l_fmt + ' is not converted');
      return 0;
    when l_seq <> ' ';
      ReviewSpec(i_lineNo:i_line
                 :'Sequence checking (column 18) is not supported in free-form');
      return 0;
    when l_cond <> '' and not IsExternalIndicator(l_cond)
         and not (g_dialect = '3' and l_cond = 'UC');
      ReviewSpec(i_lineNo:i_line:'File condition (columns 71-72) ' + l_cond
                 + ' must be U1 to U8 (or UC in RPG III)');
      return 0;
    when ToInt(l_recLen) < 1 and l_fmt <> 'E';
      ReviewSpec(i_lineNo:i_line:'Record length (columns 24-27) is missing');
      return 0;
    when g_dialect = '3' and l_fmt = 'E' and (l_recLen <> '' or l_keyLen <> ''
         or l_org <> ' ' or l_keyStart <> '' or (l_addr <> ' ' and l_addr <> 'K'));
      ReviewSpec(i_lineNo:i_line:'Record length, key length, organization and key '
                 + 'start must be blank for an externally described file');
      return 0;
    when g_dialect = '3' and (l_desig = 'C' or l_desig = 'D');
      ReviewSpec(i_lineNo:i_line:'File designation (column 16) ' + l_desig
                 + ' is not valid in RPG III');
      return 0;
  endsl;

  if l_device = 'PRINTER';
    ConvertPrinterFile(i_lineNo:i_line:l_name:l_type:l_desig:l_mode:l_keyLen:l_addr
                       :l_org:l_ovf:l_keyStart:l_ext:l_add:l_cond);
    return 0;
  endif;

  // ---- DISK ----
  select;
    when l_ext <> ' ';
      ReviewSpec(i_lineNo:i_line
                 :'Extension or line counter specification (column 39) is not converted');
      return 0;
    when l_ovf <> '';
      ReviewSpec(i_lineNo:i_line:'Overflow indicator is only for PRINTER files');
      return 0;
    when l_desig = 'P' or l_desig = 'S';
      ReviewSpec(i_lineNo:i_line:'Primary and secondary files (the RPG cycle) are '
                 + 'not supported in free-form');
      return 0;
    when l_desig = 'R' or l_desig = 'T';
      ReviewSpec(i_lineNo:i_line
                 :'Record address and table files are not supported in free-form');
      return 0;
    when l_desig <> ' ' and l_desig <> 'F' and l_desig <> 'C' and l_desig <> 'D';
      ReviewSpec(i_lineNo:i_line
                 :'File designation (column 16) ' + l_desig + ' is not valid');
      return 0;
    when l_org = 'T';
      ReviewSpec(i_lineNo:i_line
                 :'Address output file organization (T) is not supported');
      return 0;
    when l_mode = 'L';
      ReviewSpec(i_lineNo:i_line
                 :'Limits processing (column 28 L) is not supported in free-form');
      return 0;
    when l_mode <> ' ' and l_mode <> 'R';
      ReviewSpec(i_lineNo:i_line
                 :'Mode of processing (column 28) ' + l_mode + ' is not valid');
      return 0;
    when l_addr = 'I';
      ReviewSpec(i_lineNo:i_line
                 :'Record address type I (address output file) is not supported');
      return 0;
    when l_add <> ' ' and l_add <> 'A' and l_add <> 'U';
      ReviewSpec(i_lineNo:i_line
                 :'File addition (column 66) ' + l_add + ' is not valid');
      return 0;
    when l_type = 'C';
      ReviewSpec(i_lineNo:i_line:'A combined file is not valid for a DISK file');
      return 0;
    when l_type = 'O' and (l_desig = 'C' or l_mode = 'R');
      ReviewSpec(i_lineNo:i_line:'Direct file load is not supported in free-form');
      return 0;
    when l_type = 'O' and l_desig <> ' ';
      ReviewSpec(i_lineNo:i_line
                 :'An output file must have a blank file designation (column 16)');
      return 0;
    when l_type = 'O' and l_add = 'A';
      ReviewSpec(i_lineNo:i_line
                 :'Output with file addition is not supported in free-form');
      return 0;
    when (l_type = 'I' or l_type = 'U') and l_desig = ' ';
      ReviewSpec(i_lineNo:i_line
                 :'An input or update file needs a designation (F, C or D; F in '
                  + 'RPG III)');
      return 0;
  endsl;

  if l_fmt = 'E';
    l_stmt = 'dcl-f ' + l_name;
  else;
    l_stmt = 'dcl-f ' + l_name + ' disk(' + %trim(%char(ToInt(l_recLen))) + ')';
  endif;

  select;
    when l_type = 'I' and l_add = 'A';
      l_usage = '*input:*output';
    when l_type = 'I';
      l_usage = '*input';
    when l_type = 'U' and l_add = 'A';
      l_usage = '*update:*delete:*output';
    when l_type = 'U';
      l_usage = '*update:*delete';
    other;
      l_usage = '*output';
  endsl;
  l_stmt += ' usage(' + l_usage + ')';

  if l_org = 'I';
    select;
      when l_addr = 'P';
        ReviewSpec(i_lineNo:i_line
                   :'Packed key (column 31 P) is not supported in free-form');
        return 0;
      when l_addr = ' ';
        ReviewSpec(i_lineNo:i_line:'Indexed file processed consecutively or by '
                   + 'relative record number: free-form KEYED reads in key order');
        return 0;
      when l_addr <> 'A';
        ReviewSpec(i_lineNo:i_line:'Record address type (column 31) ' + l_addr
                   + ' is not valid');
        return 0;
      when ToInt(l_keyLen) < 1;
        ReviewSpec(i_lineNo:i_line:'Key length (columns 29-30) is missing');
        return 0;
      when l_keyStart = 'EXTK';
        ReviewSpec(i_lineNo:i_line:'Noncontiguous key (EXTK) is not supported');
        return 0;
      when ToInt(l_keyStart) < 1;
        ReviewSpec(i_lineNo:i_line:'Key start (columns 35-38) is missing');
        return 0;
    endsl;
    l_stmt += ' keyed(*char:' + %trim(%char(ToInt(l_keyLen))) + ') keyloc('
              + %trim(%char(ToInt(l_keyStart))) + ')';
    AppendText(l_note:'zoned-decimal key (column 31 A) declared as a character key');
  elseif l_fmt = 'E' and l_addr = 'K';
    l_stmt += ' keyed';
  elseif l_keyLen <> '' or l_keyStart <> '' or l_addr <> ' ';
    ReviewSpec(i_lineNo:i_line:'Key entries given for a file that is not indexed');
    return 0;
  endif;

  if l_cond = 'UC';
    l_stmt += ' usropn';
    AppendText(l_note:'UC: the file is not opened at start; OPEN and CLOSE are '
               + 'converted with the file operations (FREE-08)');
  elseif l_cond <> '';
    l_stmt += ' extind(*IN' + l_cond + ')';
  endif;
  l_stmt += ';';

  if l_type = 'U';
    AppendText(l_note:'*DELETE added: fixed-form update files can delete records');
  endif;
  if l_desig = 'C';
    AppendText(l_note:'chained file declared as a full-procedural file: use it only '
               + 'with CHAIN');
  endif;
  if l_desig = 'D';
    AppendText(l_note:'demand file declared as a full-procedural file: use it only '
               + 'with READ');
  endif;
  if l_eof <> ' ';
    AppendText(l_note:'end of file entry (column 17) ignored');
  endif;

  AddOut(l_stmt:i_lineNo);
  if l_fmt = 'E';
    RegisterFile(l_name:0:'X':l_type:i_lineNo);
  else;
    RegisterFile(l_name:ToInt(l_recLen):'D':l_type:i_lineNo);
  endif;
  if l_note = '';
    RptItem(C_STS_CONVERTED:i_lineNo:%trimr(%subst(i_line:6:69)):'');
  else;
    RptItem(C_STS_ASSUMPTION:i_lineNo:%trimr(%subst(i_line:6:69)):l_note);
  endif;
  return 0;
end-proc;

// ------------------------------------------------------------------
// PRINTER file: declared externally described. The printer file is made from
// the O specifications (FREE-06), so the record length is not used here.
dcl-proc ConvertPrinterFile;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_line char(100) const;
    i_name varchar(8) const;
    i_type char(1) const;
    i_desig char(1) const;
    i_mode char(1) const;
    i_keyLen varchar(2) const;
    i_addr char(1) const;
    i_org char(1) const;
    i_ovf varchar(2) const;
    i_keyStart varchar(4) const;
    i_ext char(1) const;
    i_add char(1) const;
    i_cond varchar(2) const;
  end-pi;

  dcl-s l_stmt varchar(200);
  dcl-s l_note varchar(190) inz('');

  select;
    when i_type <> 'O' or i_desig <> ' ';
      ReviewSpec(i_lineNo:i_line
                 :'A printer file must be an output file with a blank designation');
      return;
    when i_mode <> ' ' or i_keyLen <> '' or i_addr <> ' ' or i_org <> ' '
         or i_keyStart <> '' or i_add <> ' ';
      ReviewSpec(i_lineNo:i_line:'Entries that are only valid for DISK files');
      return;
    when i_ovf <> '' and not IsOverflowIndicator(i_ovf);
      ReviewSpec(i_lineNo:i_line:'Overflow indicator ' + i_ovf + ' is not valid');
      return;
    when i_ext = 'E';
      ReviewSpec(i_lineNo:i_line
                 :'Extension specification (column 39 E) is not converted');
      return;
  endsl;

  l_stmt = 'dcl-f ' + i_name + ' printer';
  if i_ovf <> '';
    l_stmt += ' oflind(*IN' + i_ovf + ')';
  endif;
  if i_cond = 'UC';
    l_stmt += ' usropn';
  elseif i_cond <> '';
    l_stmt += ' extind(*IN' + i_cond + ')';
  endif;
  l_stmt += ';';

  if i_ext = 'L';
    AppendText(l_note:'line counter specification is converted with the O '
               + 'specifications (FREE-06)');
  endif;
  AppendText(l_note:'declared externally described: the printer file comes from the O '
             + 'specifications (FREE-06)');
  AddOut(l_stmt:i_lineNo);
  RegisterFile(i_name:0:'P':i_type:i_lineNo);
  RptItem(C_STS_ASSUMPTION:i_lineNo:%trimr(%subst(i_line:6:69)):l_note);
end-proc;

// ------------------------------------------------------------------
// Number of continuation records (form type F, no file name, K in column 53)
// right after the file description at i_index.
dcl-proc CountContinuations;
  dcl-pi *n int(10);
    i_index int(10) const;
  end-pi;

  dcl-s l_next int(10);
  dcl-s l_count int(10) inz(0);
  dcl-s l_up char(100);

  l_next = i_index + 1;
  dow l_next <= g_sourceCount;
    l_up = %xlate(C_LOWER:C_UPPER:g_sourceLines(l_next));
    if %subst(l_up:6:1) = 'F' and %subst(l_up:7:8) = *blanks
       and %subst(l_up:53:1) = 'K';
      l_count += 1;
      l_next += 1;
    else;
      leave;
    endif;
  enddo;
  return l_count;
end-proc;

// ------------------------------------------------------------------
// Keeps a specification as a comment and reports it R.
dcl-proc ReviewSpec export;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_line char(100) const;
    i_reason varchar(190) const;
  end-pi;

  AddOut('// ' + RulDialectLabel() + ': ' + %trimr(%subst(i_line:6:69)):i_lineNo);
  RptItem(C_STS_REVIEW:i_lineNo:%trimr(%subst(i_line:6:69)):i_reason);
end-proc;

// ------------------------------------------------------------------
dcl-proc AddOut export;
  dcl-pi *n;
    i_text varchar(200) const;
    i_lineNo int(10) const;
  end-pi;

  if g_outputCount >= C_MAXOUT;
    g_overflow = *on;
    return;
  endif;
  g_outputCount += 1;
  g_outputLines(g_outputCount) = i_text;
  g_outputLineNos(g_outputCount) = i_lineNo;
end-proc;

// ------------------------------------------------------------------
// Adds text to a list separated by '; ' (report reasons).
dcl-proc AppendText;
  dcl-pi *n;
    io_text varchar(190);
    i_add varchar(150) const;
  end-pi;

  if %len(io_text) > 0;
    io_text += '; ';
  endif;
  io_text += i_add;
end-proc;

// ------------------------------------------------------------------
// Adds a keyword to a list separated by blanks (ctl-opt).
dcl-proc AppendKeyword;
  dcl-pi *n;
    io_text varchar(300);
    i_add varchar(100) const;
  end-pi;

  if %len(io_text) > 0;
    io_text += ' ';
  endif;
  io_text += i_add;
end-proc;

// ------------------------------------------------------------------
dcl-proc IsNumber;
  dcl-pi *n ind;
    i_text varchar(20) const;
  end-pi;

  return %len(i_text) > 0 and %check(C_DIGITS:i_text) = 0;
end-proc;

// ------------------------------------------------------------------
// RPG II file name: a letter, then letters and digits (1 to 8 characters).
dcl-proc IsFileName;
  dcl-pi *n ind;
    i_text varchar(20) const;
  end-pi;

  return IsRpgName(i_text:8);
end-proc;

// ------------------------------------------------------------------
// RPG II name: a letter, then letters and digits, at most i_max characters.
dcl-proc IsRpgName;
  dcl-pi *n ind;
    i_text varchar(20) const;
    i_max int(10) const;
  end-pi;

  if %len(i_text) = 0 or %len(i_text) > i_max;
    return *off;
  endif;
  return %check(C_UPPER:%subst(i_text:1:1)) = 0
         and %check(C_UPPER + C_DIGITS:i_text) = 0;
end-proc;

// ------------------------------------------------------------------
// The value of a number, or 0 when the text is empty or not all digits.
dcl-proc ToInt;
  dcl-pi *n int(10);
    i_text varchar(20) const;
  end-pi;

  if not IsNumber(i_text);
    return 0;
  endif;
  return %int(i_text);
end-proc;

// ------------------------------------------------------------------
// External indicator of a file condition: U1 to U8.
dcl-proc IsExternalIndicator;
  dcl-pi *n ind;
    i_text varchar(20) const;
  end-pi;

  if %len(i_text) <> 2;
    return *off;
  endif;
  if %subst(i_text:1:1) <> 'U';
    return *off;
  endif;
  return %check('12345678':%subst(i_text:2:1)) = 0;
end-proc;

// ------------------------------------------------------------------
// Overflow indicator of a printer file: OA to OG or OV.
dcl-proc IsOverflowIndicator;
  dcl-pi *n ind;
    i_text varchar(20) const;
  end-pi;

  if %len(i_text) <> 2;
    return *off;
  endif;
  if %subst(i_text:1:1) <> 'O';
    return *off;
  endif;
  return %scan(%subst(i_text:2:1):'ABCDEFGV') > 0;
end-proc;

// ------------------------------------------------------------------
// Number of output lines so far (module IAfreeCalc remembers positions).
dcl-proc OutCount export;
  dcl-pi *n int(10);
  end-pi;

  return g_outputCount;
end-proc;

// ------------------------------------------------------------------
// Replaces the text of an output line.
dcl-proc OutSet export;
  dcl-pi *n;
    i_index int(10) const;
    i_text varchar(200) const;
  end-pi;

  if i_index >= 1 and i_index <= g_outputCount;
    g_outputLines(i_index) = i_text;
  endif;
end-proc;

// ------------------------------------------------------------------
// Inserts a line after the given one; the later lines move down.
dcl-proc OutInsertAfter export;
  dcl-pi *n;
    i_index int(10) const;
    i_text varchar(200) const;
  end-pi;

  dcl-s l_index int(10);

  if g_outputCount >= C_MAXOUT;
    g_overflow = *on;
    return;
  endif;
  for l_index = g_outputCount downto i_index + 1;
    g_outputLines(l_index + 1) = g_outputLines(l_index);
    g_outputLineNos(l_index + 1) = g_outputLineNos(l_index);
  endfor;
  g_outputCount += 1;
  g_outputLines(i_index + 1) = i_text;
  g_outputLineNos(i_index + 1) = g_outputLineNos(i_index);
end-proc;

// ------------------------------------------------------------------
// I: input specifications (RPG II guide, chapter 23) to data structures.
// A block is a record line (a file name or DS) followed by its field lines.
//   - File record layout, one record type and no cycle entries:
//       dcl-ds FILE_REC len(record length); dcl-subf ... pos(from); end-ds;
//     Free-form READ and CHAIN of a program-described file name this data
//     structure (done with the C specifications, FREE-05).
//   - DS line: dcl-ds NAME; (or *n when it has no name) with its subfields.
// Everything driven by the cycle is reported R and kept as comments: record
// identification codes, record-identifying indicators, AND/OR lines, sequence
// checking, look-ahead fields, control levels, matching fields, field record
// relations and field indicators. Returns the number of lines after the first
// one that belong to the block.
dcl-proc ConvertInput;
  dcl-pi *n int(10);
    i_index int(10) const;
    i_lineNo int(10) const;
    i_line char(100) const;
  end-pi;

  dcl-s l_up char(100);
  dcl-s l_nextUp char(100);
  dcl-s l_last int(10);
  dcl-s l_next int(10);
  dcl-s l_k int(10);
  dcl-s l_multi ind inz(*off);
  dcl-s l_kind char(1);
  dcl-s l_name varchar(8);
  dcl-s l_reason varchar(190) inz('');
  dcl-s l_file int(10) inz(0);
  dcl-s l_recLen int(10) inz(0);
  dcl-s l_dsName varchar(12) inz('');
  dcl-s l_head varchar(100);
  dcl-s l_note varchar(190) inz('');
  dcl-s l_fields int(10) inz(0);
  dcl-s l_stmt varchar(200);
  dcl-s l_fieldReason varchar(190);
  dcl-s l_status char(1);

  l_up = %xlate(C_LOWER:C_UPPER:i_line);

  // A field or AND/OR line with no record line before it.
  if IsInputField(l_up);
    ReviewSpec(i_lineNo:i_line:'Field line without a record or data structure line');
    return 0;
  endif;
  if IsInputContinuation(l_up);
    ReviewSpec(i_lineNo:i_line:'AND/OR line without a record line');
    return 0;
  endif;

  // The block ends before the next record line. Comment and blank lines
  // belong to it only when more field lines follow.
  l_last = i_index;
  l_next = i_index + 1;
  dow l_next <= g_sourceCount;
    l_nextUp = %xlate(C_LOWER:C_UPPER:g_sourceLines(l_next));
    if IsInputField(l_nextUp);
      l_last = l_next;
    elseif IsInputContinuation(l_nextUp);
      l_multi = *on;
      l_last = l_next;
    elseif not IsCommentOrBlank(l_nextUp);
      leave;
    endif;
    l_next += 1;
  enddo;

  l_name = %trim(%subst(l_up:7:8));
  select;
    when %subst(l_up:19:2) = 'DS';
      l_kind = 'D';
    when %subst(l_up:19:2) = '**';
      l_kind = 'L';
    other;
      l_kind = 'F';
  endsl;

  // ---- the record line ----
  select;
    when l_multi;
      l_reason = 'More than one record type (AND/OR lines) is not supported in '
                 + 'free-form';
    when l_kind = 'L';
      l_reason = 'Look-ahead fields are not supported in free-form';
    when %trim(%subst(l_up:21:21)) <> '';
      l_reason = 'Record identification codes (more than one record type) are not '
                 + 'supported in free-form';
    when %subst(l_up:42:1) <> ' ' or %trim(%subst(l_up:43:28)) <> '';
      l_reason = 'Field entries on the record line are not valid';
    when l_last - i_index + 2 > C_MAXBLOCK;
      l_reason = 'The record layout has more than ' + %char(C_MAXBLOCK) + ' lines';
    when l_kind = 'D';
      if %trim(%subst(l_up:15:3)) <> '';
        l_reason = 'Sequence entries on a data structure line are not valid';
      elseif %subst(l_up:18:1) <> ' '
             and not (g_dialect = '3' and %subst(l_up:18:1) = 'I');
        l_reason = 'Data structure option ' + %subst(l_up:18:1)
                   + ' (local data area, program status or data area) is not '
                   + 'converted';
      elseif l_name <> '' and not IsRpgName(l_name:6);
        l_reason = 'Data structure name is not valid';
      elseif l_name <> '' and FindName(l_name) > 0;
        l_reason = 'Data structure name ' + l_name + ' is already used at line '
                   + %char(FindName(l_name));
      endif;
    other;
      if %subst(l_up:15:2) <> '  ' and %check(C_UPPER:%subst(l_up:15:2)) > 0;
        l_reason = 'Sequence checking (columns 15-16) is not supported in free-form';
      elseif %trim(%subst(l_up:17:2)) <> '';
        l_reason = 'Number or option entries (columns 17-18) are not valid without '
                   + 'sequence checking';
      elseif %trim(%subst(l_up:19:2)) <> '';
        l_reason = 'Record-identifying indicator ' + %trim(%subst(l_up:19:2))
                   + ' is not set by free-form I/O';
      else;
        l_file = FindFile(l_name);
        if l_file = 0;
          l_reason = 'File ' + l_name
                     + ' is not declared by a converted file description';
        elseif g_fileDevices(l_file) = 'X';
          l_reason = 'File ' + l_name + ' is externally described: field renames '
                     + 'and the record identifying entries of external files are '
                     + 'not converted yet';
        elseif g_fileDevices(l_file) <> 'D';
          l_reason = 'File ' + l_name + ' is not a DISK input or update file';
        elseif g_fileTypes(l_file) <> 'I' and g_fileTypes(l_file) <> 'U';
          l_reason = 'File ' + l_name + ' is not a DISK input or update file';
        elseif g_fileHasLayout(l_file);
          l_reason = 'File ' + l_name + ' already has a record layout (more than '
                     + 'one record type)';
        else;
          l_recLen = g_fileLens(l_file);
        endif;
      endif;
  endsl;

  if l_reason <> '';
    ReviewBlock(i_index:l_last:l_reason);
    return l_last - i_index;
  endif;

  // ---- the data structure ----
  g_blockCount = 0;
  if l_kind = 'F';
    l_dsName = l_name + '_REC';
    l_head = 'dcl-ds ' + l_dsName + ' len(' + %trim(%char(l_recLen)) + ');';
    l_note = 'record layout of file ' + l_name + ' declared as data structure '
             + l_dsName + ': READ and CHAIN of the file must name it (FREE-05)';
  elseif l_name = '';
    l_head = 'dcl-ds *n;';
  else;
    l_head = 'dcl-ds ' + l_name + ';';
  endif;
  if l_kind = 'D' and %subst(l_up:18:1) = 'I';
    l_head = %subst(l_head:1:%len(l_head) - 1) + ' inz;';
  endif;
  BlockAdd(l_head:i_lineNo);

  for l_k = i_index + 1 to l_last;
    l_nextUp = %xlate(C_LOWER:C_UPPER:g_sourceLines(l_k));
    if IsCommentOrBlank(l_nextUp);
      if %subst(l_nextUp:7:1) = '*';
        BlockAdd('//' + %trimr(%subst(g_sourceLines(l_k):8:73)):g_sourceLineNos(l_k));
      else;
        BlockAdd('':g_sourceLineNos(l_k));
      endif;
    elseif ConvertInputField(g_sourceLines(l_k):l_recLen:l_stmt:l_fieldReason);
      DefineName(%trim(%subst(l_nextUp:53:6)):g_sourceLineNos(l_k));
      l_fields += 1;
      BlockAdd(l_stmt:g_sourceLineNos(l_k));
      RptItem(C_STS_CONVERTED:g_sourceLineNos(l_k)
              :%trimr(%subst(g_sourceLines(l_k):6:69)):'');
    else;
      BlockAdd('// ' + RulDialectLabel() + ': ' + %trimr(%subst(g_sourceLines(l_k):6:69))
               :g_sourceLineNos(l_k));
      RptItem(C_STS_REVIEW:g_sourceLineNos(l_k)
              :%trimr(%subst(g_sourceLines(l_k):6:69)):l_fieldReason);
    endif;
  endfor;

  // No subfield could be converted: the whole block stays as comments. The
  // field lines were reported with their own reasons.
  if l_fields = 0;
    for l_k = i_index to l_last;
      l_nextUp = %xlate(C_LOWER:C_UPPER:g_sourceLines(l_k));
      if IsCommentOrBlank(l_nextUp);
        if %subst(l_nextUp:7:1) = '*';
          AddOut('//' + %trimr(%subst(g_sourceLines(l_k):8:73)):g_sourceLineNos(l_k));
        else;
          AddOut('':g_sourceLineNos(l_k));
        endif;
      else;
        AddOut('// ' + RulDialectLabel() + ': ' + %trimr(%subst(g_sourceLines(l_k):6:69))
               :g_sourceLineNos(l_k));
      endif;
    endfor;
    RptItem(C_STS_REVIEW:i_lineNo:%trimr(%subst(i_line:6:69))
            :'No subfield could be converted');
    return l_last - i_index;
  endif;

  BlockAdd('end-ds;':g_sourceLineNos(l_last));
  for l_k = 1 to g_blockCount;
    AddOut(g_blockText(l_k):g_blockLineNos(l_k));
  endfor;

  if l_kind = 'F';
    g_fileHasLayout(l_file) = *on;
    DefineName(l_dsName:i_lineNo);
  elseif l_name <> '';
    DefineName(l_name:i_lineNo);
  endif;

  if l_note = '';
    l_status = C_STS_CONVERTED;
  else;
    l_status = C_STS_ASSUMPTION;
  endif;
  RptItem(l_status:i_lineNo:%trimr(%subst(i_line:6:69)):l_note);
  return l_last - i_index;
end-proc;

// ------------------------------------------------------------------
// One field line of an input block: name, location, type. o_stmt is the
// subfield statement, or o_reason says why the line cannot be converted.
// Columns: 43 packed or binary, 44-47 from, 48-51 to, 52 decimal positions,
// 53-58 field name, 59-70 control level, matching, relation, indicators.
dcl-proc ConvertInputField;
  dcl-pi *n ind;
    i_line char(100) const;
    i_recLen int(10) const;
    o_stmt varchar(200);
    o_reason varchar(190);
  end-pi;

  dcl-s l_up char(100);
  dcl-s l_packBin char(1);
  dcl-s l_dec char(1);
  dcl-s l_from int(10);
  dcl-s l_to int(10);
  dcl-s l_len int(10);
  dcl-s l_digits int(10);
  dcl-s l_name varchar(6);
  dcl-s l_type varchar(30);

  o_stmt = '';
  o_reason = '';
  l_up = %xlate(C_LOWER:C_UPPER:i_line);
  l_packBin = %subst(l_up:43:1);
  l_dec = %subst(l_up:52:1);
  l_from = ToInt(%trim(%subst(l_up:44:4)));
  l_to = ToInt(%trim(%subst(l_up:48:4)));
  l_name = %trim(%subst(l_up:53:6));
  l_len = l_to - l_from + 1;

  select;
    when l_packBin <> ' ' and l_packBin <> 'P' and l_packBin <> 'B';
      o_reason = 'Packed or binary entry (column 43) must be blank, P or B';
    when l_from < 1 or l_to < l_from;
      o_reason = 'Field location (columns 44-51) is not valid';
    when l_dec <> ' ' and %check(C_DIGITS:l_dec) > 0;
      o_reason = 'Decimal positions (column 52) are not valid';
    when not IsRpgName(l_name:6);
      o_reason = 'Field name (columns 53-58) is not valid';
    when IsReservedName(l_name);
      o_reason = 'Field name ' + l_name + ' is a special word';
    when FindName(l_name) > 0;
      o_reason = 'Field ' + l_name + ' is already defined at line '
                 + %char(FindName(l_name));
    when %trim(%subst(l_up:59:12)) <> '';
      o_reason = 'Control level, matching fields, field record relation or field '
                 + 'indicators are not supported in free-form';
    when i_recLen > 0 and l_to > i_recLen;
      o_reason = 'Field ends past the record length ' + %char(i_recLen);
  endsl;
  if o_reason <> '';
    return *off;
  endif;

  select;
    when l_packBin = ' ' and l_dec = ' ';
      if l_len > 256;
        o_reason = 'An alphanumeric field is longer than 256 characters';
      else;
        l_type = 'char(' + %trim(%char(l_len)) + ')';
      endif;
    when l_dec = ' ';
      o_reason = 'A numeric field needs decimal positions (column 52)';
    when l_packBin = ' ';
      if l_len > 15;
        o_reason = 'A zoned field is longer than 15 digits';
      elseif ToInt(%trim(l_dec)) > l_len;
        o_reason = 'Decimal positions are more than the length';
      else;
        l_type = 'zoned(' + %trim(%char(l_len)) + ':' + l_dec + ')';
      endif;
    when l_packBin = 'P';
      l_digits = 2 * l_len - 1;
      if l_len > 8;
        o_reason = 'A packed field is longer than 8 bytes';
      elseif ToInt(%trim(l_dec)) > l_digits;
        o_reason = 'Decimal positions are more than the length';
      else;
        l_type = 'packed(' + %trim(%char(l_digits)) + ':' + l_dec + ')';
      endif;
    other;
      if l_len = 2;
        l_digits = 4;
      else;
        l_digits = 9;
      endif;
      if l_len <> 2 and l_len <> 4;
        o_reason = 'A binary field must be 2 or 4 bytes long';
      elseif ToInt(%trim(l_dec)) > l_digits;
        o_reason = 'Decimal positions are more than the length';
      else;
        l_type = 'bindec(' + %trim(%char(l_digits)) + ':' + l_dec + ')';
      endif;
  endsl;
  if o_reason <> '';
    return *off;
  endif;

  o_stmt = '  dcl-subf ' + l_name + ' ' + l_type + ' pos('
           + %trim(%char(l_from)) + ');';
  return *on;
end-proc;

// ------------------------------------------------------------------
// Keeps a whole input block as comments and reports it R: the first line with
// the reason, the other lines as part of it. Comment and blank lines stay.
dcl-proc ReviewBlock;
  dcl-pi *n;
    i_first int(10) const;
    i_last int(10) const;
    i_reason varchar(190) const;
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_line char(100);
  dcl-s l_up char(100);

  for l_k = i_first to i_last;
    l_line = g_sourceLines(l_k);
    l_up = %xlate(C_LOWER:C_UPPER:l_line);
    if IsCommentOrBlank(l_up);
      if %subst(l_up:7:1) = '*';
        AddOut('//' + %trimr(%subst(l_line:8:73)):g_sourceLineNos(l_k));
      else;
        AddOut('':g_sourceLineNos(l_k));
      endif;
    elseif l_k = i_first;
      ReviewSpec(g_sourceLineNos(l_k):l_line:i_reason);
    else;
      ReviewSpec(g_sourceLineNos(l_k):l_line
                 :'Part of the record layout above that is not converted');
    endif;
  endfor;
end-proc;

// ------------------------------------------------------------------
// A field line: form type I, columns 7-42 blank, something in columns 43-70.
dcl-proc IsInputField;
  dcl-pi *n ind;
    i_up char(100) const;
  end-pi;

  if %subst(i_up:6:1) <> 'I';
    return *off;
  endif;
  if %subst(i_up:7:36) <> *blanks;
    return *off;
  endif;
  return %trim(%subst(i_up:43:28)) <> '';
end-proc;

// ------------------------------------------------------------------
// An AND or OR line: form type I, columns 7-13 blank, AND or OR from column 14.
dcl-proc IsInputContinuation;
  dcl-pi *n ind;
    i_up char(100) const;
  end-pi;

  if %subst(i_up:6:1) <> 'I';
    return *off;
  endif;
  if %subst(i_up:7:7) <> *blanks;
    return *off;
  endif;
  return %subst(i_up:14:2) = 'OR' or %subst(i_up:14:3) = 'AND';
end-proc;

// ------------------------------------------------------------------
dcl-proc IsCommentOrBlank;
  dcl-pi *n ind;
    i_up char(100) const;
  end-pi;

  return %subst(i_up:7:1) = '*' or %trim(%subst(i_up:6:75)) = '';
end-proc;

// ------------------------------------------------------------------
// Words that cannot be used as input field names: page numbering and the
// program date fields.
dcl-proc IsReservedName;
  dcl-pi *n ind;
    i_text varchar(20) const;
  end-pi;

  return %scan('|' + i_text + '|'
               :'|PAGE|PAGE1|PAGE2|PAGE3|PAGE4|PAGE5|PAGE6|PAGE7|UDATE|UDAY|UMONTH'
               + '|UYEAR|') > 0;
end-proc;

// ------------------------------------------------------------------
// Files declared by converted file descriptions.
dcl-proc RegisterFile;
  dcl-pi *n;
    i_name varchar(8) const;
    i_recLen int(10) const;
    i_device char(1) const;
    i_type char(1) const;
    i_lineNo int(10) const;
  end-pi;

  if g_fileCount >= C_MAXFILES;
    return;
  endif;
  g_fileCount += 1;
  g_fileNames(g_fileCount) = i_name;
  g_fileLens(g_fileCount) = i_recLen;
  g_fileDevices(g_fileCount) = i_device;
  g_fileTypes(g_fileCount) = i_type;
  g_fileHasLayout(g_fileCount) = *off;
  DefineName(i_name:i_lineNo);
end-proc;

// ------------------------------------------------------------------
// The number of the file in the table, or 0.
dcl-proc FindFile;
  dcl-pi *n int(10);
    i_name varchar(8) const;
  end-pi;

  dcl-s l_i int(10);

  for l_i = 1 to g_fileCount;
    if g_fileNames(l_i) = i_name;
      return l_i;
    endif;
  endfor;
  return 0;
end-proc;

// ------------------------------------------------------------------
// The line where a name was defined, or 0 when it is not defined.
dcl-proc FindName;
  dcl-pi *n int(10);
    i_name varchar(12) const;
  end-pi;

  dcl-s l_i int(10);

  for l_i = 1 to g_nameCount;
    if g_nameList(l_i) = i_name;
      return g_nameLines(l_i);
    endif;
  endfor;
  return 0;
end-proc;

// ------------------------------------------------------------------
dcl-proc DefineName;
  dcl-pi *n;
    i_name varchar(12) const;
    i_lineNo int(10) const;
  end-pi;

  if g_nameCount >= C_MAXNAMES;
    return;
  endif;
  g_nameCount += 1;
  g_nameList(g_nameCount) = i_name;
  g_nameLines(g_nameCount) = i_lineNo;
end-proc;

// ------------------------------------------------------------------
// Adds a line to the data structure being built.
dcl-proc BlockAdd;
  dcl-pi *n;
    i_text varchar(200) const;
    i_lineNo int(10) const;
  end-pi;

  if g_blockCount >= C_MAXBLOCK;
    return;
  endif;
  g_blockCount += 1;
  g_blockText(g_blockCount) = i_text;
  g_blockLineNos(g_blockCount) = i_lineNo;
end-proc;
