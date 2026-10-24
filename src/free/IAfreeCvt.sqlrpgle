**FREE
// IAfreeCvt - converter RPG36 (System/36-compatible RPG II) to fully
// free-form RPGLE (IACNVFREE).
// FREE-03: control (H) and file description (F) specifications, comment
// lines and the compiler directives /EJECT, /TITLE and /SPACE. Everything
// else (E, L, I, C, O specifications, compile-time data) is kept as a comment
// and reported R; those are later items (FREE-04 to FREE-06). The rules are in
// docs/RPG-MAPPING.md. Module of program IACNVFREE. Target release V7R3.

ctl-opt nomain option(*srcstmt:*nodebugio);

/copy qcpysrc,IAcnvSrvP

dcl-c C_MAXSRC 20000;
dcl-c C_MAXOUT 40000;
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

  if %trim(%xlate(C_LOWER:C_UPPER:i_source.type)) <> 'RPG36';
    o_msgId = 'IAC0103';
    o_msgData = %trim(i_source.type) + ' (only RPG36 is converted so far)';
    return 1;
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

  AddOut('**FREE':0);
  ConvertSource();
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
      when %subst(l_line:7:1) = '/';
        ConvertDirective(l_lineNo:l_line);
      when l_form = 'H';
        ConvertHeader(l_lineNo:l_line);
      when l_form = 'F';
        l_extra = ConvertFile(l_index:l_lineNo:l_line);
      other;
        select;
          when l_form = 'E';
            l_reason = 'E (extension) specification not converted yet';
          when l_form = 'L';
            l_reason = 'L (line counter) specification not converted yet';
          when l_form = 'I';
            l_reason = 'I specification not converted yet (FREE-04)';
          when l_form = 'C';
            l_reason = 'C specification not converted yet (FREE-05)';
          when l_form = 'O';
            l_reason = 'O specification not converted yet (FREE-06)';
          other;
            l_reason = 'Unknown specification type in column 6';
        endsl;
        ReviewSpec(l_lineNo:l_line:l_reason);
    endsl;

    l_index += 1 + l_extra;
  enddo;
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
    AddOut('// RPG II: ' + %trimr(%subst(i_line:6:69)):i_lineNo);
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
    when l_fmt <> ' ' and l_fmt <> 'F';
      ReviewSpec(i_lineNo:i_line
                 :'Record format (column 19) ' + l_fmt + ' is not converted');
      return 0;
    when l_seq <> ' ';
      ReviewSpec(i_lineNo:i_line
                 :'Sequence checking (column 18) is not supported in free-form');
      return 0;
    when l_cond <> '' and not IsExternalIndicator(l_cond);
      ReviewSpec(i_lineNo:i_line:'File condition (columns 71-72) ' + l_cond
                 + ' must be U1 to U8');
      return 0;
    when ToInt(l_recLen) < 1;
      ReviewSpec(i_lineNo:i_line:'Record length (columns 24-27) is missing');
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
                 :'An input or update file needs a designation (F, C or D)');
      return 0;
  endsl;

  l_stmt = 'dcl-f ' + l_name + ' disk(' + %trim(%char(ToInt(l_recLen))) + ')';

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
  elseif l_keyLen <> '' or l_keyStart <> '' or l_addr <> ' ';
    ReviewSpec(i_lineNo:i_line:'Key entries given for a file that is not indexed');
    return 0;
  endif;

  if l_cond <> '';
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
  if i_cond <> '';
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
dcl-proc ReviewSpec;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_line char(100) const;
    i_reason varchar(190) const;
  end-pi;

  AddOut('// RPG II: ' + %trimr(%subst(i_line:6:69)):i_lineNo);
  RptItem(C_STS_REVIEW:i_lineNo:%trimr(%subst(i_line:6:69)):i_reason);
end-proc;

// ------------------------------------------------------------------
dcl-proc AddOut;
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

  if %len(i_text) = 0 or %len(i_text) > 8;
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
