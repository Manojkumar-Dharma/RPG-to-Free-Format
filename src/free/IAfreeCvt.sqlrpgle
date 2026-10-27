**FREE
// IAfreeCvt - converter RPG36 (System/36-compatible RPG II) to fully
// free-form RPGLE (IACNVFREE).
// FREE-03: control (H) and file description (F) specifications, comment
// lines and the compiler directives /EJECT, /TITLE and /SPACE.
// FREE-04: input (I) specifications, as data structures.
// FREE-05: calculation (C) specifications, converted by module IAfreeCalc with
// the rule tables read by IAfreeRul (rules/*.json).
// FREE-08: file operations of the C specifications (module IAfreeCalc), which
// need the files declared here (FileInfo).
// FREE-07: extension (E) specifications for arrays and tables, and their
// compile-time data. Everything else (L, O specifications) is kept as a comment
// and reported R; those are later items (FREE-06). The rules are in
// docs/RPG-MAPPING.md. Module of program IACNVFREE. Target release V7R3.

ctl-opt nomain option(*srcstmt:*nodebugio);

/copy qcpysrc,IAcnvSrvP
/copy qcpysrc,IAfreeRulP
/copy qcpysrc,IAfreeCalP
/copy qcpysrc,IAfreeFx4P
/copy qcpysrc,IAfreeOutP

dcl-c C_MAXSRC 20000;
dcl-c C_MAXOUT 40000;
dcl-c C_MAXFILES 100;
dcl-c C_MAXNAMES 3000;
dcl-c C_MAXBLOCK 600;
dcl-c C_MAXCT 200;
dcl-c C_MAXDS 100;
dcl-c C_MAXREN 200;
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

// The renamed fields of externally described files (RV-30).
dcl-s g_renFile varchar(8) dim(C_MAXREN);
dcl-s g_renExt varchar(10) dim(C_MAXREN);
dcl-s g_renNew varchar(6) dim(C_MAXREN);
dcl-s g_renCount int(10);
// The record format names of the record lines of externally described files
// (WRITE and UPDAT name a record format, FREE-25).
dcl-s g_fmtName varchar(8) dim(C_MAXREN);
dcl-s g_fmtFile varchar(8) dim(C_MAXREN);
dcl-s g_fmtCount int(10);
dcl-s g_fileKeyed ind dim(C_MAXFILES);
dcl-s g_fileCount int(10);
// Names defined so far (files, data structures, fields) and the line of each.
dcl-s g_nameList varchar(12) dim(C_MAXNAMES);
dcl-s g_nameLines int(10) dim(C_MAXNAMES);
dcl-s g_nameCount int(10);
// Lines of the data structure being built.
dcl-s g_blockText varchar(200) dim(C_MAXBLOCK);
dcl-s g_blockLineNos int(10) dim(C_MAXBLOCK);
dcl-s g_blockCount int(10);
// Compile-time arrays and tables in the order of the E specifications ('' for one
// that was not converted) and the number of ** data sections met so far.
dcl-s g_ctNames varchar(6) dim(C_MAXCT);
dcl-s g_ctCount int(10);
dcl-s g_ctSection int(10);
// The named data structures (I specifications) and the output line of their
// first line, so DEFN *NAMVAR can add the DTAARA keyword.
dcl-s g_dsNames varchar(10) dim(C_MAXDS);
dcl-s g_dsOut int(10) dim(C_MAXDS);
dcl-s g_dsOccurs ind dim(C_MAXDS);
dcl-s g_dsCount int(10);

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
  g_renCount = 0;
  g_fmtCount = 0;
  g_nameCount = 0;
  g_blockCount = 0;
  g_ctCount = 0;
  g_ctSection = 0;
  g_dsCount = 0;
  clear g_dsOccurs;

  select;
    when %trim(%xlate(C_LOWER:C_UPPER:i_source.type)) = 'RPG36';
      g_dialect = '2';
    when %trim(%xlate(C_LOWER:C_UPPER:i_source.type)) = 'RPG38'
         or %trim(%xlate(C_LOWER:C_UPPER:i_source.type)) = 'RPG'
         or %trim(%xlate(C_LOWER:C_UPPER:i_source.type)) = 'SQLRPG';
      g_dialect = '3';
    when %trim(%xlate(C_LOWER:C_UPPER:i_source.type)) = 'RPGLE'
         or %trim(%xlate(C_LOWER:C_UPPER:i_source.type)) = 'SQLRPGLE';
      g_dialect = '4';
    other;
      o_msgId = 'IAC0103';
      o_msgData = %trim(i_source.type)
                  + ' (only RPG36, RPG38, RPG, SQLRPG, RPGLE and SQLRPGLE are converted)';
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
  Fx4Start();
  OutStart();
  if g_dialect <> '4';
    for l_index = 1 to g_sourceCount;
      CalcPrescan(g_sourceLines(l_index));
    endfor;
  endif;
  ConvertSource();
  if g_dialect = '4';
    Fx4Flush();
  endif;
  CalcFinish();
  if g_dialect <> '4';
    AddDdsComments();
  endif;
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
      // A ** record starts the data of the next compile-time array or table; the
      // records after it are compile-time data, copied as is.
      when %subst(l_line:1:2) = '**';
        l_data = *on;
        ConvertDataHeader(l_lineNo:l_line);
      when l_data;
        AddOut(%trimr(l_line):l_lineNo);
      when %trim(%subst(l_line:6:75)) = '';
        AddOut('':l_lineNo);
      when %subst(l_line:7:1) = '*';
        AddOut('//' + %trimr(%subst(l_line:8:73)):l_lineNo);
      // SQLRPG, SQLRPGLE: C/EXEC SQL, C+ lines and C/END-EXEC become EXEC SQL.
      when SqlHere(l_form:l_line:l_lineNo);
      // RPG IV fixed form: H, F, D, P, C specifications, directives, /FREE blocks.
      when g_dialect = '4';
        Fx4Line(l_index:l_lineNo:l_line:l_extra);
      when %subst(l_line:7:1) = '/';
        ConvertDirective(l_lineNo:l_line);
      when l_form = 'H';
        ConvertHeader(l_lineNo:l_line);
      when l_form = 'F';
        l_extra = ConvertFile(l_index:l_lineNo:l_line);
      when l_form = 'I';
        l_extra = ConvertInput(l_index:l_lineNo:l_line);
      when l_form = 'E';
        ConvertExtension(l_lineNo:l_line);
      other;
        select;
          when l_form = 'L';
            l_reason = 'L (line counter) specification not converted yet';
          when l_form = 'C';
            l_reason = '';
          when l_form = 'O' and g_dialect <> '4';
            l_reason = '';
          when l_form = 'O';
            l_reason = 'O specification not converted yet (FREE-06)';
          other;
            l_reason = 'Unknown specification type in column 6';
        endsl;
        if l_form = 'C';
          CalcLine(l_line:l_lineNo);
        elseif l_form = 'O' and g_dialect <> '4';
          l_extra = OutLine(l_index:l_lineNo:l_line);
        else;
          ReviewSpec(l_lineNo:l_line:l_reason);
        endif;
    endsl;

    l_index += 1 + l_extra;
  enddo;
end-proc;

// ------------------------------------------------------------------
// E: extension specifications (RPG II guide, chapter 20; RPG/400 reference,
// chapter 9) for arrays and tables. Columns: 11-18 from file, 19-26 to file,
// 27-32 name, 33-35 entries per record, 36-39 entries per array, 40-42 length of
// an entry, 43 packed/binary, 44 decimal positions, 45 sequence; 46-51 name of
// the second array of an alternating pair with 52-54 length, 55 packed/binary,
// 56 decimal positions, 57 sequence.
//   dcl-s NAME char(len) dim(n);                      run-time array
//   dcl-s NAME zoned(len:dec) dim(n) perrcd(k) ctdata; compile-time array
//   dcl-s ALT type dim(n) alt(NAME);                   alternating array
// The data of a compile-time array stays after the source, under a **CTDATA
// record (see ConvertDataHeader). A sign on the left or right (L or R in column 43
// or 55) is EXTFMT(L) or EXTFMT(R): the length of the entry includes the sign, the
// free-form length does not. Arrays loaded from a file (columns 11-18) and
// arrays written at the end of the job (19-26) need the FROMFILE and TOFILE
// keywords, which are not allowed in a free-form definition (a fixed-form D
// specification would be needed); packed and binary data (P, B) is only for
// such prerun-time arrays; record address files are not supported. All are
// reported R.
dcl-proc ConvertExtension;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_line char(100) const;
  end-pi;

  dcl-s l_up char(100);
  dcl-s l_name varchar(6);
  dcl-s l_alt varchar(6);
  dcl-s l_ent varchar(3);
  dcl-s l_dim varchar(4);
  dcl-s l_type varchar(30);
  dcl-s l_altType varchar(30);
  dcl-s l_stmt varchar(200);
  dcl-s l_altStmt varchar(200);
  dcl-s l_reason varchar(190) inz('');
  dcl-s l_note varchar(190) inz('');
  dcl-s l_status char(1);
  dcl-s l_compile ind inz(*off);
  dcl-s l_from varchar(8);
  dcl-s l_to varchar(8);
  dcl-s l_fmt1 char(1);
  dcl-s l_fmt2 char(1);
  dcl-s l_len1 char(3);
  dcl-s l_len2 char(3);
  dcl-s l_ext1 varchar(14) inz('');
  dcl-s l_ext2 varchar(14) inz('');

  l_up = %xlate(C_LOWER:C_UPPER:i_line);
  l_name = %trim(%subst(l_up:27:6));
  l_alt = %trim(%subst(l_up:46:6));
  l_ent = %trim(%subst(l_up:33:3));
  l_dim = %trim(%subst(l_up:36:4));
  l_from = %trim(%subst(l_up:11:8));
  l_to = %trim(%subst(l_up:19:8));
  l_fmt1 = %subst(l_up:43:1);
  l_fmt2 = %subst(l_up:55:1);
  l_len1 = %subst(l_up:40:3);
  l_len2 = %subst(l_up:52:3);

  select;
    when l_name = '' and (l_from <> '' or l_to <> '');
      l_reason = 'Record address files are not supported in free-form';
    when not IsRpgName(l_name:6) or IsReservedName(l_name);
      l_reason = 'Array or table name (columns 27-32) is not valid';
    when FindName(l_name) > 0;
      l_reason = 'Name ' + l_name + ' is already defined at line '
                 + %char(FindName(l_name));
    when not IsNumber(l_dim) or ToInt(l_dim) < 1;
      l_reason = 'Number of entries per array (columns 36-39) is not valid';
    when l_ent <> '' and (not IsNumber(l_ent) or ToInt(l_ent) < 1);
      l_reason = 'Number of entries per record (columns 33-35) is not valid';
    when l_from <> '';
      l_reason = 'FROMFILE (an array loaded from file ' + l_from + ' at the start of '
                 + 'the program) is not allowed in a free-form definition: it needs '
                 + 'a fixed-form D specification, or the array must be loaded by '
                 + 'READ operations';
    when l_to <> '';
      l_reason = 'TOFILE (an array written to file ' + l_to + ' at the end of the '
                 + 'program) is not allowed in a free-form definition: it needs '
                 + 'a fixed-form D specification, or the array must be written by '
                 + 'WRITE operations';
    when l_fmt1 = 'P' or l_fmt1 = 'B' or l_fmt2 = 'P' or l_fmt2 = 'B';
      l_reason = 'Packed and binary data (columns 43 and 55) is only for arrays '
                 + 'loaded from a file, which are not allowed in free-form';
    when (l_fmt1 <> ' ' and l_fmt1 <> 'L' and l_fmt1 <> 'R')
         or (l_fmt2 <> ' ' and l_fmt2 <> 'L' and l_fmt2 <> 'R');
      l_reason = 'The data format (columns 43 and 55) must be blank, L or R';
    when (l_fmt1 <> ' ' or l_fmt2 <> ' ') and l_ent = '';
      l_reason = 'A sign on the left or right (L, R) is only for compile-time '
                 + 'arrays and tables';
    when l_fmt1 <> ' ' and %subst(l_up:44:1) = ' ';
      l_reason = 'A sign on the left or right (L, R) is only for numeric arrays';
    when l_fmt2 <> ' ' and %subst(l_up:56:1) = ' ';
      l_reason = 'A sign on the left or right (L, R) is only for numeric arrays';
  endsl;

  // L and R: the length of the entry includes the sign; EXTFMT(L) and EXTFMT(R)
  // give the digits only.
  if l_reason = '' and l_fmt1 <> ' ';
    if not IsNumber(%trim(l_len1)) or ToInt(%trim(l_len1)) < 2;
      l_reason = 'The length of an entry with a sign (columns 40-42) must be 2 or '
                 + 'more';
    else;
      l_len1 = %trim(%char(ToInt(%trim(l_len1)) - 1));
      l_ext1 = ' extfmt(' + l_fmt1 + ')';
    endif;
  endif;
  if l_reason = '' and l_fmt2 <> ' ';
    if not IsNumber(%trim(l_len2)) or ToInt(%trim(l_len2)) < 2;
      l_reason = 'The length of an entry with a sign (columns 52-54) must be 2 or '
                 + 'more';
    else;
      l_len2 = %trim(%char(ToInt(%trim(l_len2)) - 1));
      l_ext2 = ' extfmt(' + l_fmt2 + ')';
    endif;
  endif;

  // The type of the entries; the alternating array has its own type.
  if l_reason = '';
    l_reason = ArrayType(l_len1:%subst(l_up:44:1):%subst(l_up:45:1):l_type);
  endif;
  if l_reason = '' and l_alt <> '';
    select;
      when l_ent = '';
        l_reason = 'An alternating array needs the entries per record (columns '
                   + '33-35)';
      when not IsRpgName(l_alt:6) or IsReservedName(l_alt) or l_alt = l_name;
        l_reason = 'Alternating array name (columns 46-51) is not valid';
      when FindName(l_alt) > 0;
        l_reason = 'Name ' + l_alt + ' is already defined at line '
                   + %char(FindName(l_alt));
      other;
        l_reason = ArrayType(l_len2:%subst(l_up:56:1)
                             :%subst(l_up:57:1):l_altType);
    endsl;
  endif;

  if l_reason <> '';
    ReviewSpec(i_lineNo:i_line:l_reason);
    // A compile-time array that is not converted still owns a data section.
    if l_from = '' and l_ent <> '';
      AddCompileTime('');
    endif;
    return;
  endif;

  l_compile = (l_ent <> '');
  l_stmt = 'dcl-s ' + l_name + ' ' + l_type + ' dim(' + %trim(%char(ToInt(l_dim)))
           + ')';
  if l_compile;
    l_stmt += ' perrcd(' + %trim(%char(ToInt(l_ent))) + ')' + l_ext1 + ' ctdata';
    AddCompileTime(l_name);
  endif;
  select;
    when %subst(l_up:45:1) = 'A';
      l_stmt += ' ascend';
    when %subst(l_up:45:1) = 'D';
      l_stmt += ' descend';
  endsl;
  AddOut(l_stmt + ';':i_lineNo);
  DefineName(l_name:i_lineNo);
  DefineArrayField(l_name:l_len1:%subst(l_up:44:1));
  CalcDefineArray(l_name:%subst(l_up:45:1):ToInt(l_dim):l_alt);

  if l_alt <> '';
    l_altStmt = 'dcl-s ' + l_alt + ' ' + l_altType + ' dim('
                + %trim(%char(ToInt(l_dim))) + ')';
    select;
      when %subst(l_up:57:1) = 'A';
        l_altStmt += ' ascend';
      when %subst(l_up:57:1) = 'D';
        l_altStmt += ' descend';
    endsl;
    l_altStmt += l_ext2 + ' alt(' + l_name + ')';
    AddOut(l_altStmt + ';':i_lineNo);
    DefineName(l_alt:i_lineNo);
    DefineArrayField(l_alt:l_len2:%subst(l_up:56:1));
    CalcDefineArray(l_alt:%subst(l_up:57:1):ToInt(l_dim):'');
  endif;

  l_status = C_STS_CONVERTED;
  if l_ext1 <> '' or l_ext2 <> '';
    l_status = C_STS_ASSUMPTION;
    l_note = 'EXTFMT: the length of the entry in columns 40-42 (or 52-54) includes '
             + 'the sign, the declared digits are one less; the data records are '
             + 'kept as they are';
  endif;
  if %subst(l_name:1:3) = 'TAB';
    l_status = C_STS_ASSUMPTION;
    if l_note <> '';
      l_note += '; ';
    endif;
    l_note += 'Table ' + l_name + ' is declared as an array with the index field '
             + l_name + '_IDX: the table name in a calculation means the entry '
             + 'found by the last LOKUP, written ' + l_name + '(' + l_name
             + '_IDX)';
  endif;
  RptItem(l_status:i_lineNo:%trimr(%subst(i_line:6:69)):l_note);
end-proc;

// ------------------------------------------------------------------
// The entries of an array are known to MOVE and MOVEL by their length and type.
dcl-proc DefineArrayField;
  dcl-pi *n;
    i_name varchar(6) const;
    i_length char(3) const;
    i_decimals char(1) const;
  end-pi;

  if i_decimals = ' ';
    CalcDefineField(i_name:'C':ToInt(%trim(i_length)):0);
  else;
    CalcDefineField(i_name:'N':ToInt(%trim(i_length)):%int(i_decimals));
  endif;
end-proc;

// ------------------------------------------------------------------
// The free-form type of the entries of an array: char(length) when the decimal
// positions are blank, zoned(length:decimals) otherwise, and the sequence entry.
// Returns the reason when the entries cannot be converted, '' otherwise.
dcl-proc ArrayType;
  dcl-pi *n varchar(190);
    i_length char(3) const;
    i_decimals char(1) const;
    i_sequence char(1) const;
    o_type varchar(30);
  end-pi;

  dcl-s l_len varchar(3);
  dcl-s l_numeric ind;

  o_type = '';
  l_len = %trim(i_length);
  l_numeric = (i_decimals <> ' ');
  if not IsNumber(l_len);
    return 'Length of entry is not valid';
  endif;
  if ToInt(l_len) < 1;
    return 'Length of entry is not valid';
  endif;
  if i_sequence <> ' ' and i_sequence <> 'A' and i_sequence <> 'D';
    return 'Sequence (A or D) is not valid';
  endif;

  if l_numeric;
    if %check(C_DIGITS:i_decimals) > 0;
      return 'Decimal positions are not valid';
    endif;
    if ToInt(l_len) > 15;
      return 'A numeric entry is longer than 15 digits';
    endif;
    if %int(i_decimals) > ToInt(l_len);
      return 'Decimal positions are more than the length';
    endif;
    o_type = 'zoned(' + %trim(%char(ToInt(l_len))) + ':' + i_decimals + ')';
  else;
    if ToInt(l_len) > 256;
      return 'An alphanumeric entry is longer than 256 characters';
    endif;
    o_type = 'char(' + %trim(%char(ToInt(l_len))) + ')';
  endif;
  return '';
end-proc;

// ------------------------------------------------------------------
dcl-proc AddCompileTime;
  dcl-pi *n;
    i_name varchar(6) const;
  end-pi;

  if g_ctCount >= C_MAXCT;
    return;
  endif;
  g_ctCount += 1;
  g_ctNames(g_ctCount) = i_name;
end-proc;

// ------------------------------------------------------------------
// A ** record (the first one separates the source from the compile-time data):
// the data records after it belong to the next compile-time array or table in the
// order of the E specifications. It becomes **CTDATA name. The data records are
// copied as they are.
dcl-proc ConvertDataHeader;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_line char(100) const;
  end-pi;

  g_ctSection += 1;
  if g_dialect = '4';
    AddOut(%trimr(i_line):i_lineNo);
    RptItem(C_STS_ASSUMPTION:i_lineNo:%trimr(i_line)
            :'Compile-time data section kept as is: check its name');
  elseif g_ctSection <= g_ctCount and g_ctNames(g_ctSection) <> '';
    AddOut('**CTDATA ' + g_ctNames(g_ctSection):i_lineNo);
    RptItem(C_STS_CONVERTED:i_lineNo:%trimr(i_line)
            :'');
  else;
    AddOut(%trimr(i_line):i_lineNo);
    RptItem(C_STS_REVIEW:i_lineNo:%trimr(i_line)
            :'This data section belongs to no converted compile-time array or '
             + 'table: kept as is');
  endif;
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
  if g_dialect <> '3' and g_dialect <> '4';
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
// A name of the continuation options: letters, digits and $ # @ _, 1 to 10
// characters, not starting with a digit or an underscore.
dcl-proc ContName;
  dcl-pi *n ind;
    i_text varchar(10) const;
  end-pi;

  dcl-c C_FIRST 'ABCDEFGHIJKLMNOPQRSTUVWXYZ$#@';
  dcl-c C_REST 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789$#@_';

  if %len(i_text) < 1;
    return *off;
  endif;
  return (%check(C_FIRST:%subst(i_text:1:1)) = 0
          and %check(C_REST:i_text) = 0);
end-proc;

// ------------------------------------------------------------------
// The continuation records of a file description (RV-32): the options of
// columns 54-59 (with the entry of columns 60-67) as keywords of dcl-f. The
// main line may carry one itself (K in column 53). Returns '' or the reason
// the file is not converted. DISK files: COMIT, INFDS, INFSR, RECNO, RENAME and
// IGNORE (externally described); PRINTER files: INFDS and INFSR. The options
// of WORKSTN and SPECIAL files and PRTCTL are not converted.
dcl-proc ContinuationKeywords;
  dcl-pi *n varchar(190);
    i_index int(10) const;
    i_line char(100) const;
    i_extra int(10) const;
    i_device varchar(7) const;
    i_fmt char(1) const;
    o_keywords varchar(200);
    o_note varchar(190);
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_up char(100);
  dcl-s l_opt varchar(6);
  dcl-s l_arg varchar(8);
  dcl-s l_ext varchar(10);
  dcl-s l_seen varchar(100) inz('|');
  dcl-s l_disk ind;

  o_keywords = '';
  o_note = '';
  l_disk = (i_device = 'DISK');
  for l_k = 0 to i_extra;
    if l_k = 0;
      l_up = %xlate(C_LOWER:C_UPPER:i_line);
      if %subst(l_up:53:1) <> 'K';
        iter;
      endif;
    else;
      l_up = %xlate(C_LOWER:C_UPPER:g_sourceLines(i_index + l_k));
      if %trim(%subst(l_up:29:18)) <> '' or %trim(%subst(l_up:68:7)) <> '';
        return 'Columns 29-52 and 68-74 of a continuation record must be blank';
      endif;
    endif;
    l_opt = %trim(%subst(l_up:54:6));
    l_arg = %trim(%subst(l_up:60:8));
    l_ext = %trim(%subst(l_up:19:10));
    if l_opt = '';
      return 'Continuation record without an option (columns 54-59)';
    endif;
    if l_ext <> '' and l_opt <> 'RENAME' and l_opt <> 'IGNORE';
      return 'Columns 19-28 of a continuation record are only for RENAME and IGNORE';
    endif;
    if l_opt <> 'RENAME' and l_opt <> 'IGNORE' and %scan('|' + l_opt + '|':l_seen) > 0;
      return 'Continuation option ' + l_opt + ' is given twice';
    endif;
    l_seen += l_opt + '|';

    select;
      when l_opt = 'COMIT';
        if not l_disk or l_arg <> '';
          return 'COMIT is converted for DISK files, with columns 60-67 blank';
        endif;
        o_keywords += ' commit';
      when l_opt = 'INFDS';
        if not ContName(l_arg);
          return 'INFDS needs a data structure name in columns 60-65';
        endif;
        o_keywords += ' infds(' + l_arg + ')';
        AppendText(o_note:'INFDS ' + l_arg + ' must be declared with the layout of'
                   + ' the file information data structure (I specification)');
      when l_opt = 'INFSR';
        if l_arg <> '*PSSR' and not ContName(l_arg);
          return 'INFSR needs a subroutine name or *PSSR in columns 60-65';
        endif;
        if l_arg = '*PSSR';
          o_keywords += ' infsr(*pssr)';
        else;
          o_keywords += ' infsr(' + l_arg + ')';
        endif;
      when l_opt = 'RECNO';
        if not l_disk or not ContName(l_arg);
          return 'RECNO is converted for DISK files, with a field name in columns'
                 + ' 60-65';
        endif;
        o_keywords += ' recno(' + l_arg + ')';
        AppendText(o_note:'RECNO field ' + l_arg + ' must be a numeric field without'
                   + ' decimals defined in the program');
      when l_opt = 'RENAME';
        if not l_disk or i_fmt <> 'E' or not ContName(l_ext) or not ContName(l_arg);
          return 'RENAME is converted for externally described DISK files, with the'
                 + ' external name in columns 19-28 and the new name in 60-67';
        endif;
        o_keywords += ' rename(' + l_ext + ':' + l_arg + ')';
      when l_opt = 'IGNORE';
        if not l_disk or i_fmt <> 'E' or not ContName(l_ext) or l_arg <> '';
          return 'IGNORE is converted for externally described DISK files, with the'
                 + ' record format in columns 19-28';
        endif;
        o_keywords += ' ignore(' + l_ext + ')';
      when l_opt = 'PRTCTL';
        return 'PRTCTL needs a program-described printer file: the printer file is'
               + ' declared externally described here';
      when l_opt = 'ID' or l_opt = 'IND' or l_opt = 'NUM' or l_opt = 'PASS'
           or l_opt = 'SAVDS' or l_opt = 'SFILE' or l_opt = 'SLN'
           or l_opt = 'PLIST';
        return 'Continuation option ' + l_opt + ' is for WORKSTN or SPECIAL files,'
               + ' which are not converted yet';
      other;
        return 'Continuation option ' + l_opt + ' is not known';
    endsl;
  endfor;
  return '';
end-proc;

// ------------------------------------------------------------------
// F: file description specification (RPG II guide, chapter 19) to dcl-f
// (Reference, Tables 105 and 106). DISK and PRINTER files only. Returns the
// number of continuation records that follow the specification and were
// consumed with it: their options are converted with it (RV-32) or all the
// records are kept as comments.
dcl-proc ConvertFile;
  dcl-pi *n int(10);
    i_index int(10) const;
    i_lineNo int(10) const;
    i_line char(100) const;
  end-pi;

  dcl-s l_up char(100);
  dcl-s l_extra int(10);
  dcl-s l_k int(10);
  dcl-s l_ok ind inz(*off);
  dcl-s l_keywords varchar(200) inz('');
  dcl-s l_note varchar(190) inz('');
  dcl-s l_reason varchar(190) inz('');

  l_up = %xlate(C_LOWER:C_UPPER:i_line);
  l_extra = CountContinuations(i_index);
  if l_extra > 0 or %subst(l_up:53:1) = 'K';
    l_reason = ContinuationKeywords(i_index:i_line:l_extra:%trim(%subst(l_up:40:7))
                                    :%subst(l_up:19:1):l_keywords:l_note);
    if l_reason <> '';
      ReviewSpec(i_lineNo:i_line:l_reason);
      for l_k = 1 to l_extra;
        ReviewSpec(g_sourceLineNos(i_index + l_k):g_sourceLines(i_index + l_k)
                   :'Continuation of the file description above');
      endfor;
      return l_extra;
    endif;
  endif;

  ConvertFileLine(i_lineNo:i_line:l_keywords:l_note:l_ok);
  for l_k = 1 to l_extra;
    if l_ok;
      RptItem(C_STS_CONVERTED:g_sourceLineNos(i_index + l_k)
              :%trimr(%subst(g_sourceLines(i_index + l_k):6:69)):'');
    else;
      ReviewSpec(g_sourceLineNos(i_index + l_k):g_sourceLines(i_index + l_k)
                 :'Continuation of the file description above');
    endif;
  endfor;
  return l_extra;
end-proc;

// ------------------------------------------------------------------
// One file description line to dcl-f; i_keywords are the keywords of its
// continuation records. o_ok is on when the line was converted.
dcl-proc ConvertFileLine;
  dcl-pi *n;
    i_lineNo int(10) const;
    i_line char(100) const;
    i_keywords varchar(200) const;
    i_contNote varchar(190) const;
    o_ok ind;
  end-pi;

  dcl-s l_up char(100);
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

  l_up = %xlate(C_LOWER:C_UPPER:i_line);
  o_ok = *off;
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

  select;
    when not IsFileName(l_name);
      ReviewSpec(i_lineNo:i_line:'File name (columns 7-14) is not valid');
      return;
    when l_type <> 'I' and l_type <> 'O' and l_type <> 'U' and l_type <> 'C';
      ReviewSpec(i_lineNo:i_line:'File type (column 15) must be I, O, U or C');
      return;
    when l_device <> 'DISK' and l_device <> 'PRINTER';
      if l_device = 'WORKSTN';
        ReviewSpec(i_lineNo:i_line:'Device WORKSTN is not converted yet: it needs '
                   + 'the display file and the format I/O');
      elseif l_device = '';
        ReviewSpec(i_lineNo:i_line:'Device (columns 40-46) is blank');
      else;
        ReviewSpec(i_lineNo:i_line:'Device ' + l_device + ' is not converted yet');
      endif;
      return;
    when l_fmt <> ' ' and l_fmt <> 'F' and not (g_dialect = '3' and l_fmt = 'E');
      ReviewSpec(i_lineNo:i_line
                 :'Record format (column 19) ' + l_fmt + ' is not converted');
      return;
    when l_seq <> ' ';
      ReviewSpec(i_lineNo:i_line
                 :'Sequence checking (column 18) is not supported in free-form');
      return;
    when l_cond <> '' and not IsExternalIndicator(l_cond)
         and not (g_dialect = '3' and l_cond = 'UC');
      ReviewSpec(i_lineNo:i_line:'File condition (columns 71-72) ' + l_cond
                 + ' must be U1 to U8 (or UC in RPG III)');
      return;
    when ToInt(l_recLen) < 1 and l_fmt <> 'E';
      ReviewSpec(i_lineNo:i_line:'Record length (columns 24-27) is missing');
      return;
    when g_dialect = '3' and l_fmt = 'E' and (l_recLen <> '' or l_keyLen <> ''
         or l_org <> ' ' or l_keyStart <> '' or (l_addr <> ' ' and l_addr <> 'K'));
      ReviewSpec(i_lineNo:i_line:'Record length, key length, organization and key '
                 + 'start must be blank for an externally described file');
      return;
    when g_dialect = '3' and (l_desig = 'C' or l_desig = 'D');
      ReviewSpec(i_lineNo:i_line:'File designation (column 16) ' + l_desig
                 + ' is not valid in RPG III');
      return;
  endsl;

  if l_device = 'PRINTER';
    ConvertPrinterFile(i_lineNo:i_line:l_name:l_type:l_desig:l_mode:l_keyLen:l_addr
                       :l_org:l_ovf:l_keyStart:l_ext:l_add:l_cond:i_keywords
                       :i_contNote:o_ok);
    return;
  endif;

  // ---- DISK ----
  select;
    when l_ext <> ' ';
      ReviewSpec(i_lineNo:i_line
                 :'Extension or line counter specification (column 39) is not converted');
      return;
    when l_ovf <> '';
      ReviewSpec(i_lineNo:i_line:'Overflow indicator is only for PRINTER files');
      return;
    when l_desig = 'P' or l_desig = 'S';
      ReviewSpec(i_lineNo:i_line:'Primary and secondary files (the RPG cycle) are '
                 + 'not supported in free-form');
      return;
    when l_desig = 'R' or l_desig = 'T';
      ReviewSpec(i_lineNo:i_line
                 :'Record address and table files are not supported in free-form');
      return;
    when l_desig <> ' ' and l_desig <> 'F' and l_desig <> 'C' and l_desig <> 'D';
      ReviewSpec(i_lineNo:i_line
                 :'File designation (column 16) ' + l_desig + ' is not valid');
      return;
    when l_org = 'T';
      ReviewSpec(i_lineNo:i_line
                 :'Address output file organization (T) is not supported');
      return;
    when l_mode = 'L';
      ReviewSpec(i_lineNo:i_line
                 :'Limits processing (column 28 L) is not supported in free-form');
      return;
    when l_mode <> ' ' and l_mode <> 'R';
      ReviewSpec(i_lineNo:i_line
                 :'Mode of processing (column 28) ' + l_mode + ' is not valid');
      return;
    when l_addr = 'I';
      ReviewSpec(i_lineNo:i_line
                 :'Record address type I (address output file) is not supported');
      return;
    when l_add <> ' ' and l_add <> 'A' and l_add <> 'U';
      ReviewSpec(i_lineNo:i_line
                 :'File addition (column 66) ' + l_add + ' is not valid');
      return;
    when l_type = 'C';
      ReviewSpec(i_lineNo:i_line:'A combined file is not valid for a DISK file');
      return;
    when l_type = 'O' and (l_desig = 'C' or l_mode = 'R');
      ReviewSpec(i_lineNo:i_line:'Direct file load is not supported in free-form');
      return;
    when l_type = 'O' and l_desig <> ' ';
      ReviewSpec(i_lineNo:i_line
                 :'An output file must have a blank file designation (column 16)');
      return;
    when l_type = 'O' and l_add = 'A';
      ReviewSpec(i_lineNo:i_line
                 :'Output with file addition is not supported in free-form');
      return;
    when (l_type = 'I' or l_type = 'U') and l_desig = ' ';
      ReviewSpec(i_lineNo:i_line
                 :'An input or update file needs a designation (F, C or D; F in '
                  + 'RPG III)');
      return;
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
        return;
      when l_addr = ' ';
        ReviewSpec(i_lineNo:i_line:'Indexed file processed consecutively or by '
                   + 'relative record number: free-form KEYED reads in key order');
        return;
      when l_addr <> 'A';
        ReviewSpec(i_lineNo:i_line:'Record address type (column 31) ' + l_addr
                   + ' is not valid');
        return;
      when ToInt(l_keyLen) < 1;
        ReviewSpec(i_lineNo:i_line:'Key length (columns 29-30) is missing');
        return;
      when l_keyStart = 'EXTK';
        ReviewSpec(i_lineNo:i_line:'Noncontiguous key (EXTK) is not supported');
        return;
      when ToInt(l_keyStart) < 1;
        ReviewSpec(i_lineNo:i_line:'Key start (columns 35-38) is missing');
        return;
    endsl;
    l_stmt += ' keyed(*char:' + %trim(%char(ToInt(l_keyLen))) + ') keyloc('
              + %trim(%char(ToInt(l_keyStart))) + ')';
    AppendText(l_note:'zoned-decimal key (column 31 A) declared as a character key');
  elseif l_fmt = 'E' and l_addr = 'K';
    l_stmt += ' keyed';
  elseif l_keyLen <> '' or l_keyStart <> '' or l_addr <> ' ';
    ReviewSpec(i_lineNo:i_line:'Key entries given for a file that is not indexed');
    return;
  endif;

  if l_cond = 'UC';
    l_stmt += ' usropn';
    AppendText(l_note:'UC: the file is not opened at start; OPEN and CLOSE are '
               + 'converted with the file operations (FREE-08)');
  elseif l_cond <> '';
    l_stmt += ' extind(*IN' + l_cond + ')';
  endif;
  l_stmt += i_keywords + ';';
  if i_contNote <> '';
    AppendText(l_note:i_contNote);
  endif;

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
    RegisterFile(l_name:0:'X':l_type:i_lineNo:(l_addr = 'K'));
  else;
    RegisterFile(l_name:ToInt(l_recLen):'D':l_type:i_lineNo:(l_org = 'I'));
  endif;
  o_ok = *on;
  if l_note = '';
    RptItem(C_STS_CONVERTED:i_lineNo:%trimr(%subst(i_line:6:69)):'');
  else;
    RptItem(C_STS_ASSUMPTION:i_lineNo:%trimr(%subst(i_line:6:69)):l_note);
  endif;
  return;
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
    i_keywords varchar(200) const;
    i_contNote varchar(190) const;
    o_ok ind;
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
  l_stmt += i_keywords + ';';
  if i_contNote <> '';
    AppendText(l_note:i_contNote);
  endif;

  if i_ext = 'L';
    AppendText(l_note:'line counter specification is converted with the O '
               + 'specifications (FREE-06)');
  endif;
  AppendText(l_note:'declared externally described: the printer file comes from the O '
             + 'specifications (FREE-06)');
  AddOut(l_stmt:i_lineNo);
  RegisterFile(i_name:0:'P':i_type:i_lineNo:*off);
  o_ok = *on;
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
// The printer file DDS made from the exception output records (FREE-06) is kept
// as comments at the end of the converted source: copy it into a DDS source
// member and create the printer file from it.
dcl-proc AddDdsComments;
  dcl-pi *n;
  end-pi;

  dcl-s l_count int(10);
  dcl-s l_k int(10);

  l_count = OutFinish();
  if l_count = 0;
    return;
  endif;
  AddOut('':0);
  AddOut('// Printer file ' + OutDdsFile() + ': DDS source made from the O '
         + 'specifications.':0);
  AddOut('// Copy these lines (without the // and the first blank) into a DDS '
         + 'source member and run':0);
  AddOut('// CRTPRTF FILE(' + OutDdsFile() + ') SRCFILE(...) before compiling '
         + 'this program.':0);
  for l_k = 1 to l_count;
    AddOut('//' + OutDdsLine(l_k):0);
  endfor;
end-proc;

// ------------------------------------------------------------------
// Source access for IAfreeFx4.
dcl-proc SrcCount export;
  dcl-pi *n int(10);
  end-pi;

  return g_sourceCount;
end-proc;

dcl-proc SrcLine export;
  dcl-pi *n char(100);
    i_index int(10) const;
  end-pi;

  return g_sourceLines(i_index);
end-proc;

dcl-proc SrcLineNo export;
  dcl-pi *n int(10);
    i_index int(10) const;
  end-pi;

  return g_sourceLineNos(i_index);
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
// DEFN *NAMVAR on a data structure of the I specifications: the line dcl-ds NAME;
// gets the DTAARA keyword (i_external is the quoted name of the data area).
// Returns *off when the data structure is not known or has the keyword already.
dcl-proc CvtDtaaraDs export;
  dcl-pi *n ind;
    i_name varchar(10) const;
    i_external varchar(20) const;
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_line varchar(200);

  for l_index = 1 to g_dsCount;
    if g_dsNames(l_index) = i_name;
      l_line = g_outputLines(g_dsOut(l_index));
      if %scan('dtaara(':l_line) > 0 or %len(l_line) < 2;
        return *off;
      endif;
      OutSet(g_dsOut(l_index):%subst(l_line:1:%len(l_line) - 1) + ' dtaara('
             + i_external + ');');
      return *on;
    endif;
  endfor;
  return *off;
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
  dcl-s l_occurs varchar(4) inz('');
  dcl-s l_occursOk ind inz(*on);

  l_up = %xlate(C_LOWER:C_UPPER:i_line);
  // Columns 44-47: a whole number from 1 to 9999, or blank.
  l_occurs = %trim(%subst(l_up:44:4));
  l_occursOk = *on;
  if l_occurs <> '';
    if %check(C_DIGITS:l_occurs) > 0;
      l_occursOk = *off;
    elseif %dec(l_occurs:5:0) < 1;
      l_occursOk = *off;
    endif;
  endif;

  // A field or AND/OR line with no record line before it.
  if IsInputField(l_up);
    ReviewSpec(i_lineNo:i_line:'Field line without a record or data structure line');
    return 0;
  endif;
  // A record line of an externally described file: only the renames (RV-30).
  if %subst(l_up:19:2) <> 'DS' and %subst(l_up:19:2) <> '**'
     and not IsInputContinuation(l_up);
    l_file = ExternalFileOf(%trim(%subst(l_up:7:8)));
    if l_file > 0;
      return ConvertInputExternal(i_index:i_lineNo:i_line:l_file);
    endif;
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
    when l_kind = 'D' and g_dialect = '3'
         and (%subst(l_up:42:2) <> '  ' or %trim(%subst(l_up:48:23)) <> ''
              or not l_occursOk);
      l_reason = 'Only the number of occurrences (columns 44-47) is converted on a '
                 + 'data structure line';
    when l_kind = 'D' and g_dialect = '3';
      // columns 44-47: number of occurrences (checked above)
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
  if l_kind = 'D' and l_occurs <> '';
    l_head = %subst(l_head:1:%len(l_head) - 1) + ' occurs(' + %char(%dec(l_occurs:5:0))
             + ');';
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
  if l_kind = 'D' and l_name <> '' and g_dsCount < C_MAXDS;
    g_dsCount += 1;
    g_dsNames(g_dsCount) = %xlate(C_LOWER:C_UPPER:l_name);
    g_dsOut(g_dsCount) = g_outputCount + 1;
    g_dsOccurs(g_dsCount) = (l_occurs <> '');
  endif;
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
// Whether a data structure has a number of occurrences (columns 44-47).
dcl-proc CvtIsOccursDs export;
  dcl-pi *n ind;
    i_name varchar(10) const;
  end-pi;

  dcl-s l_index int(10);

  for l_index = 1 to g_dsCount;
    if g_dsNames(l_index) = i_name;
      return g_dsOccurs(l_index);
    endif;
  endfor;
  return *off;
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
  // The length and type are needed by MOVE and MOVEL.
  select;
    when l_packBin = ' ' and l_dec = ' ';
      CalcDefineField(l_name:'C':l_len:0);
    when l_packBin = 'P' or l_packBin = 'B';
      CalcDefineField(l_name:'N':l_digits:ToInt(%trim(l_dec)));
    other;
      CalcDefineField(l_name:'N':l_len:ToInt(%trim(l_dec)));
  endsl;
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
    i_keyed ind const;
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
  g_fileKeyed(g_fileCount) = i_keyed;
  DefineName(i_name:i_lineNo);
end-proc;

// ------------------------------------------------------------------
// What the file operations of IAfreeCalc need to know about a file declared by a
// converted F specification: device (D disk, X externally described disk, P
// printer), type, the name of its record layout data structure ('' when it has
// none) and whether it is keyed. Returns *off for a file that is not declared.
dcl-proc FileInfo export;
  dcl-pi *n ind;
    i_name varchar(8) const;
    o_device char(1);
    o_type char(1);
    o_recDs varchar(12);
    o_keyed ind;
  end-pi;

  dcl-s l_file int(10);

  l_file = FindFile(i_name);
  if l_file = 0;
    return *off;
  endif;
  o_device = g_fileDevices(l_file);
  o_type = g_fileTypes(l_file);
  o_recDs = '';
  if g_fileHasLayout(l_file);
    o_recDs = i_name + '_REC';
  endif;
  o_keyed = g_fileKeyed(l_file);
  return *on;
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
// The externally described file a record line of the I specifications belongs
// to (RV-30): the file named in columns 7-14, or the only externally described
// file of the program (the line names a record format). 0 when there is none.
dcl-proc ExternalFileOf;
  dcl-pi *n int(10);
    i_name varchar(8) const;
  end-pi;

  dcl-s l_i int(10);
  dcl-s l_found int(10) inz(0);
  dcl-s l_count int(10) inz(0);

  l_i = FindFile(i_name);
  if l_i > 0;
    if g_fileDevices(l_i) = 'X';
      return l_i;
    endif;
    return 0;
  endif;
  for l_i = 1 to g_fileCount;
    if g_fileDevices(l_i) = 'X';
      l_count += 1;
      l_found = l_i;
    endif;
  endfor;
  if l_count = 1;
    return l_found;
  endif;
  return 0;
end-proc;

// ------------------------------------------------------------------
// The renamed fields of a file as assignments (NEW = EXT; ...), for the input
// operations of ConvertFileOp. '' when the file has none.
dcl-proc FileRenames export;
  dcl-pi *n varchar(250);
    i_name varchar(8) const;
  end-pi;

  dcl-s l_i int(10);
  dcl-s l_text varchar(250) inz('');

  for l_i = 1 to g_renCount;
    if g_renFile(l_i) = i_name;
      if l_text <> '';
        l_text += '; ';
      endif;
      l_text += g_renNew(l_i) + ' = ' + g_renExt(l_i);
    endif;
  endfor;
  return l_text;
end-proc;

// ------------------------------------------------------------------
// The renamed fields of a file as assignments back to the external fields
// (EXT = NEW; ...), for WRITE and UPDAT of ConvertFileOp (FREE-25). '' when the
// file has none.
dcl-proc FileRenamesBack export;
  dcl-pi *n varchar(250);
    i_name varchar(8) const;
  end-pi;

  dcl-s l_i int(10);
  dcl-s l_text varchar(250) inz('');

  for l_i = 1 to g_renCount;
    if g_renFile(l_i) = i_name;
      if l_text <> '';
        l_text += '; ';
      endif;
      l_text += g_renExt(l_i) + ' = ' + g_renNew(l_i);
    endif;
  endfor;
  return l_text;
end-proc;

// ------------------------------------------------------------------
// The externally described file a record format name belongs to (the record
// line of its I specifications), '' when the name is not a known record format.
dcl-proc FormatFile export;
  dcl-pi *n varchar(8);
    i_name varchar(8) const;
  end-pi;

  dcl-s l_i int(10);

  for l_i = 1 to g_fmtCount;
    if g_fmtName(l_i) = i_name;
      return g_fmtFile(l_i);
    endif;
  endfor;
  return '';
end-proc;

// ------------------------------------------------------------------
// One field line of an externally described record (RV-30). A rename (external
// name in columns 21-30, program name in 53-58) is a copy: dcl-s NEW like(EXT),
// set after each input operation of the file (ConvertFileOp). Control levels,
// matching fields and field indicators (columns 59-70) are not converted.
// Returns '' or the reason the line is not converted.
dcl-proc ConvertExternalField;
  dcl-pi *n varchar(190);
    i_lineNo int(10) const;
    i_line char(100) const;
    i_file int(10) const;
  end-pi;

  dcl-s l_up char(100);
  dcl-s l_ext varchar(10);
  dcl-s l_new varchar(6);

  l_up = %xlate(C_LOWER:C_UPPER:i_line);
  l_ext = %trim(%subst(l_up:21:10));
  l_new = %trim(%subst(l_up:53:6));
  select;
    when %trim(%subst(l_up:7:14)) <> '';
      return 'Columns 7-20 of a field line of an externally described file must be'
             + ' blank';
    when %trim(%subst(l_up:31:22)) <> '';
      return 'Columns 31-52 of a field line of an externally described file must be'
             + ' blank';
    when %trim(%subst(l_up:59:12)) <> '';
      return 'Control levels, matching fields and field indicators of an externally'
             + ' described file are not converted';
    when l_new = '' or not IsRpgName(l_new:6);
      return 'The field name (columns 53-58) is not a valid name';
    when l_ext = '' or l_ext = l_new;
      return '';
    when not ContName(l_ext);
      return 'The external field name ' + l_ext + ' is not a valid name';
    when FindName(l_new) > 0;
      return 'Field name ' + l_new + ' is already used at line '
             + %char(FindName(l_new));
    when g_renCount >= C_MAXREN
         or %len(FileRenames(g_fileNames(i_file))) + %len(l_ext) + %len(l_new) + 8
            > 230;
      return 'Too many renamed fields for file ' + g_fileNames(i_file);
  endsl;

  g_renCount += 1;
  g_renFile(g_renCount) = g_fileNames(i_file);
  g_renExt(g_renCount) = l_ext;
  g_renNew(g_renCount) = l_new;
  DefineName(l_new:i_lineNo);
  AddOut('dcl-s ' + l_new + ' like(' + l_ext + ');':i_lineNo);
  return '';
end-proc;

// ------------------------------------------------------------------
// The I specifications of an externally described file (RV-30): the record line
// (the record format name) and its field lines. Only the renames are converted.
dcl-proc ConvertInputExternal;
  dcl-pi *n int(10);
    i_index int(10) const;
    i_lineNo int(10) const;
    i_line char(100) const;
    i_file int(10) const;
  end-pi;

  dcl-s l_up char(100);
  dcl-s l_nextUp char(100);
  dcl-s l_last int(10);
  dcl-s l_next int(10);
  dcl-s l_k int(10);
  dcl-s l_multi ind inz(*off);
  dcl-s l_reason varchar(190) inz('');
  dcl-s l_text varchar(80);
  dcl-s l_format varchar(8);

  l_up = %xlate(C_LOWER:C_UPPER:i_line);
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

  select;
    when l_multi;
      l_reason = 'More than one record type (AND/OR lines) is not supported in '
                 + 'free-form';
    when %trim(%subst(l_up:15:4)) <> '';
      l_reason = 'Sequence, number and option entries (columns 15-18) are not valid '
                 + 'for an externally described record';
    when %trim(%subst(l_up:19:2)) <> '';
      l_reason = 'Record-identifying indicator ' + %trim(%subst(l_up:19:2))
                 + ' is not set by free-form I/O';
    when %trim(%subst(l_up:21:54)) <> '';
      l_reason = 'Columns 21-74 of the record line of an externally described '
                 + 'file must be blank';
    when not ContName(%trim(%subst(l_up:7:8)));
      l_reason = 'The record format name is not valid';
  endsl;
  if l_reason <> '';
    ReviewBlock(i_index:l_last:l_reason);
    return l_last - i_index;
  endif;

  // The record line names a record format (not a file): WRITE and UPDAT of the
  // format are converted with the file's renamed fields copied back (FREE-25).
  l_format = %trim(%subst(l_up:7:8));
  if FindFile(l_format) = 0 and g_fmtCount < C_MAXREN and FormatFile(l_format) = '';
    g_fmtCount += 1;
    g_fmtName(g_fmtCount) = l_format;
    g_fmtFile(g_fmtCount) = g_fileNames(i_file);
  endif;

  RptItem(C_STS_CONVERTED:i_lineNo:%trimr(%subst(i_line:6:69)):'');
  for l_k = i_index + 1 to l_last;
    l_nextUp = %xlate(C_LOWER:C_UPPER:g_sourceLines(l_k));
    l_text = %trimr(%subst(g_sourceLines(l_k):6:69));
    if IsCommentOrBlank(l_nextUp);
      if %subst(l_nextUp:7:1) = '*';
        AddOut('//' + %trimr(%subst(g_sourceLines(l_k):8:73)):g_sourceLineNos(l_k));
      else;
        AddOut('':g_sourceLineNos(l_k));
      endif;
    else;
      l_reason = ConvertExternalField(g_sourceLineNos(l_k):g_sourceLines(l_k)
                                      :i_file);
      if l_reason = '';
        if %trim(%subst(l_nextUp:21:10)) = '' or %trim(%subst(l_nextUp:21:10))
           = %trim(%subst(l_nextUp:53:6));
          RptItem(C_STS_CONVERTED:g_sourceLineNos(l_k):l_text:'');
        else;
          RptItem(C_STS_ASSUMPTION:g_sourceLineNos(l_k):l_text
                  :'The renamed field is a copy (dcl-s like): it is set after each'
                  + ' READ and CHAIN of the file; a change of it is not written back');
        endif;
      else;
        AddOut('// ' + RulDialectLabel() + ': ' + l_text:g_sourceLineNos(l_k));
        RptItem(C_STS_REVIEW:g_sourceLineNos(l_k):l_text:l_reason);
      endif;
    endif;
  endfor;
  return l_last - i_index;
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
