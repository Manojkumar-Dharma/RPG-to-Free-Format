**FREE
// IAfreeOut - O specifications (RPG II, RPG III) to a printer file DDS source and
// WRITE statements (FREE-06). Exception records (type E) of one PRINTER file
// become record formats; EXCPT in a calculation writes them. Heading, detail and
// total records belong to the RPG cycle and are reported R, as are edited
// numeric fields (first increment), relative end positions and the other
// entries without a DDS equivalent. The rules are in docs/RPG-MAPPING.md.
// Module of program IACNVFREE. Target release V7R3.

ctl-opt nomain option(*srcstmt:*nodebugio);

/copy qcpysrc,IAcnvSrvP
/copy qcpysrc,IAfreeCalP
/copy qcpysrc,IAfreeFx4P
/copy qcpysrc,IAfreeOutP

dcl-c C_LOWER 'abcdefghijklmnopqrstuvwxyz';
dcl-c C_UPPER 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
dcl-c C_DIGITS '0123456789';
dcl-c C_QUOTE '''';
dcl-c C_MAXGRP 300;
dcl-c C_MAXFLD 2500;
dcl-c C_MAXDDS 4000;
dcl-c C_MAXPRT 9;

dcl-pr CalcDeclare;
  i_text varchar(100) const;
end-pr;

dcl-pr CalcFieldInfo ind;
  i_name varchar(10) const;
  o_kind char(1);
  o_length int(10);
  o_decimals int(10);
end-pr;

// Output records (a record line with its field lines).
dcl-s g_gFile varchar(8) dim(C_MAXGRP);
dcl-s g_gName varchar(10) dim(C_MAXGRP);
dcl-s g_gFmt varchar(10) dim(C_MAXGRP);
dcl-s g_gStart int(10) dim(C_MAXGRP);
dcl-s g_gEnd int(10) dim(C_MAXGRP);
dcl-s g_gOk ind dim(C_MAXGRP);
dcl-s g_gReason varchar(150) dim(C_MAXGRP);
dcl-s g_gCond varchar(200) dim(C_MAXGRP);
dcl-s g_gOr varchar(200) dim(C_MAXGRP);      // finished OR terms: (a) or (b)
dcl-s g_gType char(1) dim(C_MAXGRP);         // E exception, H heading, D detail, T total
dcl-s g_gKeys varchar(60) dim(C_MAXGRP);     // SPACEB, SPACEA, SKIPB, SKIPA
dcl-s g_gFirst int(10) dim(C_MAXGRP);
dcl-s g_gFields int(10) dim(C_MAXGRP);
dcl-s g_gDisk ind dim(C_MAXGRP);             // record of a program described DISK file (RV-62)
dcl-s g_gAct char(1) dim(C_MAXGRP);          // disk: W write (blank or ADD), D delete (DEL)
dcl-s g_gRecLen int(10) dim(C_MAXGRP);       // disk: record length
dcl-s g_gPlace int(10) dim(C_MAXGRP);        // fields before the first *PLACE (RV-61)
dcl-s g_gCount int(10) inz(0);
// Output fields and constants.
dcl-s g_fName varchar(14) dim(C_MAXFLD);
dcl-s g_fEdit char(1) dim(C_MAXFLD);
dcl-s g_fEnd int(10) dim(C_MAXFLD);
dcl-s g_fConst varchar(30) dim(C_MAXFLD);
dcl-s g_fCond varchar(30) dim(C_MAXFLD);
dcl-s g_fReason varchar(120) dim(C_MAXFLD);
dcl-s g_fBlank ind dim(C_MAXFLD);           // blank after (column 39)
dcl-s g_fSpecial char(1) dim(C_MAXFLD);     // P PAGE, J UDATE, S *DATE, D UDAY/UMONTH/UYEAR, E array element
dcl-s g_fAlias varchar(10) dim(C_MAXFLD);   // DDS name of a field that is assigned before the write (RV-61)
dcl-s g_fSrc varchar(40) dim(C_MAXFLD);     // the value of that field: 'IA_E1 = ARR(3)'
dcl-s g_fFmt char(1) dim(C_MAXFLD);         // data format (column 44)
dcl-s g_aliasNo int(10) inz(0);
dcl-s g_fCount int(10) inz(0);
// The DDS source.
dcl-s g_dds varchar(80) dim(C_MAXDDS);
dcl-s g_ddsCount int(10) inz(0);
dcl-s g_ddsNo int(10) dim(C_MAXDDS);         // the printer file (number) of each DDS line
dcl-s g_pName varchar(8) dim(C_MAXPRT);      // printer files with a converted record (RV-62)
dcl-s g_pCount int(10) inz(0);
dcl-s g_curFile int(10) inz(0);
dcl-s g_built ind inz(*off);
// RPG IV output specifications (RV-56): Norm4 turns the line into the RPG II/III
// column layout for the rest of the module; the names are longer there and are
// kept here, with the reason when an entry does not fit the layout.
dcl-s g_n4 ind inz(*off);
dcl-s g_n4File varchar(10) inz('');
dcl-s g_n4Name varchar(14) inz('');
dcl-s g_n4Exc varchar(10) inz('');
dcl-s g_n4Reason varchar(150) inz('');

// ------------------------------------------------------------------
dcl-proc Up;
  dcl-pi *n varchar(100);
    i_text varchar(100) const;
  end-pi;

  return %xlate(C_LOWER:C_UPPER:i_text);
end-proc;

// ------------------------------------------------------------------
dcl-proc OutStart export;
  dcl-pi *n;
  end-pi;

  g_gCount = 0;
  g_fCount = 0;
  g_ddsCount = 0;
  g_pCount = 0;
  g_curFile = 0;
  g_built = *off;
end-proc;

// ------------------------------------------------------------------
// The text of columns i_from to i_to of a line, trimmed.
dcl-proc Cols;
  dcl-pi *n varchar(100);
    i_line char(100) const;
    i_from int(10) const;
    i_to int(10) const;
  end-pi;

  return %trim(%subst(i_line:i_from:i_to - i_from + 1));
end-proc;

// ------------------------------------------------------------------
dcl-proc IsOLine;
  dcl-pi *n ind;
    i_line char(100) const;
  end-pi;

  return Up(%subst(i_line:6:1)) = 'O' and %subst(i_line:7:1) <> '*'
         and %subst(i_line:7:1) <> '/' and %trim(%subst(i_line:7:68)) <> '';
end-proc;

// ------------------------------------------------------------------
// A valid indicator for an output condition (SC09-1817 chapter 10): 01-99,
// KA-KN, KP-KY, H1-H9, U1-U8, OA-OG, OV. L1-L9, LR, MR, RT and 1P belong to the
// RPG cycle (RT: see CycleTerm).
dcl-proc IsOutIndicator;
  dcl-pi *n ind;
    i_ind varchar(2) const;
  end-pi;

  dcl-s l_a char(1);
  dcl-s l_b char(1);

  if %len(i_ind) <> 2;
    return *off;
  endif;
  l_a = %subst(i_ind:1:1);
  l_b = %subst(i_ind:2:1);
  select;
    when %check(C_DIGITS:i_ind) = 0;
      return i_ind <> '00';
    when l_a = 'K';
      return (l_b >= 'A' and l_b <= 'N') or (l_b >= 'P' and l_b <= 'Y');
    when l_a = 'H';
      return l_b >= '1' and l_b <= '9';
    when l_a = 'U';
      return l_b >= '1' and l_b <= '8';
    when l_a = 'O';
      return (l_b >= 'A' and l_b <= 'G') or l_b = 'V';
  endsl;
  return *off;
end-proc;

// ------------------------------------------------------------------
// The output indicators of columns 23-31 (three of N + two characters) as a
// free-form condition. o_reason is set for an indicator that cannot be used.
// The indicators of the RPG cycle on the record line of a heading, detail or total
// record (RV-60): L1-L9 and LR as *INLn, RT as *INRT (FREE-50: the cycle skeleton
// tests it after LR, as step 11 of the cycle does), 1P (heading and detail only) as
// IA_FIRST, the first record of the cycle skeleton. '' for anything else (MR stays R
// until the skeleton sets it).
dcl-proc CycleTerm;
  dcl-pi *n varchar(10);
    i_ind varchar(2) const;
    i_type char(1) const;
  end-pi;

  if i_type <> 'H' and i_type <> 'D' and i_type <> 'T';
    return '';
  endif;
  if i_ind = 'LR';
    return '*inlr';
  endif;
  if i_ind = 'RT';
    return '*inrt';
  endif;
  if %subst(i_ind:1:1) = 'L' and %check('123456789':%subst(i_ind:2:1)) = 0;
    return '*inl' + %subst(i_ind:2:1);
  endif;
  if i_ind = '1P' and i_type <> 'T';
    return 'IA_FIRST';
  endif;
  return '';
end-proc;

// ------------------------------------------------------------------
dcl-proc IndicatorCond;
  dcl-pi *n varchar(200);
    i_line char(100) const;
    o_reason varchar(150);
    i_type char(1) const;
  end-pi;

  dcl-s l_slot int(10);
  dcl-s l_col int(10);
  dcl-s l_not varchar(1);
  dcl-s l_ind varchar(2);
  dcl-s l_text varchar(200) inz('');
  dcl-s l_term varchar(10);

  o_reason = '';
  for l_slot = 0 to 2;
    l_col = 23 + 3 * l_slot;
    l_not = Up(%trim(%subst(i_line:l_col:1)));
    l_ind = Up(%trim(%subst(i_line:l_col + 1:2)));
    if l_ind = '' and l_not = '';
      iter;
    endif;
    if l_ind = '' or (l_not <> '' and l_not <> 'N');
      o_reason = 'Output indicator entry in columns ' + %char(l_col) + '-'
                 + %char(l_col + 2) + ' is not valid';
      return '';
    endif;
    l_term = CycleTerm(l_ind:i_type);
    if l_term = '' and not IsOutIndicator(l_ind);
      o_reason = 'Output indicator ' + l_ind + ' belongs to the RPG cycle and is '
                 + 'not converted';
      return '';
    endif;
    if l_term = '';
      l_term = '*in' + l_ind;
    endif;
    if %len(l_text) > 0;
      l_text += ' and ';
    endif;
    if l_not = 'N';
      l_text += 'not ';
    endif;
    l_text += l_term;
  endfor;
  return l_text;
end-proc;

// ------------------------------------------------------------------
// A skip entry (columns 19-20 or 21-22) as the number of the DDS keyword.
dcl-proc SkipNumber;
  dcl-pi *n varchar(3);
    i_text varchar(2) const;
  end-pi;

  dcl-s l_a char(1);
  dcl-s l_b char(1);

  if i_text = '' or i_text = '0' or i_text = '00';
    return '';
  endif;
  if %check(C_DIGITS:i_text) = 0;
    return %char(%int(i_text));
  endif;
  if %len(i_text) = 2;
    l_a = %subst(i_text:1:1);
    l_b = %subst(i_text:2:1);
    if l_a = 'A' and l_b >= '0' and l_b <= '9';
      return %char(100 + %int(l_b));
    endif;
    if l_a = 'B' and l_b >= '0' and l_b <= '2';
      return %char(110 + %int(l_b));
    endif;
  endif;
  return '?';
end-proc;

// ------------------------------------------------------------------
dcl-proc IsConstant;
  dcl-pi *n ind;
    i_text varchar(30) const;
  end-pi;

  return %len(i_text) > 1 and %subst(i_text:1:1) = C_QUOTE
         and %subst(i_text:%len(i_text):1) = C_QUOTE;
end-proc;

// ------------------------------------------------------------------
// PAGE, PAGE1-PAGE7, UDATE, UDAY, UMONTH, UYEAR, *PLACE and the like, array
// elements (FLD,1 or FLD(1)) and any name that starts with *.
dcl-proc IsSpecialName;
  dcl-pi *n ind;
    i_name varchar(10) const;
  end-pi;

  if i_name = '';
    return *off;
  endif;
  if %subst(i_name:1:1) = '*' or %scan(',':i_name) > 0 or %scan('(':i_name) > 0;
    return *on;
  endif;
  if i_name = 'UDATE' or i_name = 'UDAY' or i_name = 'UMONTH' or i_name = 'UYEAR';
    return *on;
  endif;
  if %len(i_name) >= 4 and %subst(i_name:1:4) = 'PAGE';
    return *on;
  endif;
  return *off;
end-proc;

// ------------------------------------------------------------------
// RPG IV output specifications (SC09-2508, program described files) as an RPG II/III
// line (record line: file 7-14, type 15, ADD/DEL 16-18, spacing 17-22, indicators
// 23-31, EXCPT name 32-37; field line: indicators 23-31, name 32-37, edit code 38,
// blank after 39, end 40-43, format 44, constant 45-70). The long names stay in
// g_n4File, g_n4Name and g_n4Exc. A source of RPG II or III is returned unchanged.
dcl-proc Norm4;
  dcl-pi *n char(100);
    i_line char(100) const;
  end-pi;

  dcl-s l_out char(100) inz(' ');
  dcl-s l_t varchar(30);
  dcl-s l_ao varchar(3);

  g_n4 = *off;
  g_n4File = '';
  g_n4Name = '';
  g_n4Exc = '';
  g_n4Reason = '';
  if SrcDialect() <> '4' or not IsOLine(i_line);
    return i_line;
  endif;
  g_n4 = *on;
  %subst(l_out:6:1) = %subst(i_line:6:1);
  %subst(l_out:23:9) = %subst(i_line:21:9);
  l_ao = Up(Cols(i_line:16:18));
  select;
    // ---- a field line: columns 7-20 blank ----
    when Cols(i_line:7:20) = '';
      g_n4Name = Up(Cols(i_line:30:43));
      if g_n4Name <> '';
        l_t = %subst(g_n4Name:1:%min(6:%len(g_n4Name)));
        %subst(l_out:32:%len(l_t)) = l_t;
      endif;
      %subst(l_out:38:1) = %subst(i_line:44:1);
      %subst(l_out:39:1) = %subst(i_line:45:1);
      %subst(l_out:44:1) = %subst(i_line:52:1);
      if %subst(i_line:46:1) <> ' ';
        g_n4Reason = 'Entry in column 46 is not converted';
      endif;
      l_t = Cols(i_line:47:51);
      if %len(l_t) > 4;
        g_n4Reason = 'End position (columns 47-51) ' + l_t + ' has more than 4 '
                     + 'characters';
      elseif %len(l_t) > 0;
        %subst(l_out:44 - %len(l_t):%len(l_t)) = l_t;
      endif;
      l_t = Cols(i_line:53:80);
      if %len(l_t) > 26;
        g_n4Reason = 'The constant or edit word (columns 53-80) is longer than 26 '
                     + 'characters';
      elseif %len(l_t) > 0;
        %subst(l_out:45:%len(l_t)) = l_t;
      endif;
    // ---- an AND or OR line ----
    when Cols(i_line:7:15) = '' and (l_ao = 'AND' or l_ao = 'OR');
      %subst(l_out:14:3) = %subst(i_line:16:3);
    // ---- a record line ----
    other;
      g_n4File = Up(Cols(i_line:7:16));
      l_t = %subst(g_n4File:1:%min(8:%len(g_n4File)));
      if %len(l_t) > 0;
        %subst(l_out:7:%len(l_t)) = l_t;
      endif;
      %subst(l_out:15:1) = %subst(i_line:17:1);
      %subst(l_out:16:3) = %subst(i_line:18:3);
      g_n4Exc = Up(Cols(i_line:30:39));
      if g_n4Exc <> '';
        l_t = %subst(g_n4Exc:1:%min(6:%len(g_n4Exc)));
        %subst(l_out:32:%len(l_t)) = l_t;
      endif;
      Norm4Space(i_line:l_out);
  endsl;
  return l_out;
end-proc;

// ------------------------------------------------------------------
// Space before and after (columns 40-42 and 43-45, 0 to 3) and skip before and after
// (columns 46-48 and 49-51, up to 99) of an RPG IV record line, into the RPG II/III
// columns 17, 18, 19-20 and 21-22. They share columns with ADD and DEL.
dcl-proc Norm4Space;
  dcl-pi *n;
    i_line char(100) const;
    io_out char(100);
  end-pi;

  dcl-s l_sb varchar(10);
  dcl-s l_sa varchar(10);
  dcl-s l_kb varchar(10);
  dcl-s l_ka varchar(10);

  l_sb = Cols(i_line:40:42);
  l_sa = Cols(i_line:43:45);
  l_kb = Cols(i_line:46:48);
  l_ka = Cols(i_line:49:51);
  if l_sb = '' and l_sa = '' and l_kb = '' and l_ka = '';
    return;
  endif;
  if Cols(i_line:18:20) <> '';
    g_n4Reason = 'ADD, DEL or fetch overflow (columns 18-20) together with spacing '
                 + 'or skipping is not converted';
    return;
  endif;
  select;
    when %len(l_sb) > 1 or (l_sb <> '' and %check('0123':l_sb) > 0);
      g_n4Reason = 'Space before (columns 40-42) ' + l_sb + ' is not 0 to 3';
    when %len(l_sa) > 1 or (l_sa <> '' and %check('0123':l_sa) > 0);
      g_n4Reason = 'Space after (columns 43-45) ' + l_sa + ' is not 0 to 3';
    when %len(l_kb) > 2 or %check(C_DIGITS:l_kb) > 0
         or %len(l_ka) > 2 or %check(C_DIGITS:l_ka) > 0;
      g_n4Reason = 'Skip before or after (columns 46-51) is not 1 to 99';
    other;
      if l_sb <> '';
        %subst(io_out:17:1) = l_sb;
      endif;
      if l_sa <> '';
        %subst(io_out:18:1) = l_sa;
      endif;
      if l_kb <> '';
        %subst(io_out:21 - %len(l_kb):%len(l_kb)) = l_kb;
      endif;
      if l_ka <> '';
        %subst(io_out:23 - %len(l_ka):%len(l_ka)) = l_ka;
      endif;
  endsl;
end-proc;

// ------------------------------------------------------------------
// The file name, the EXCPT name and the field name of the line that Norm4 read last:
// the long names of RPG IV, else the columns of RPG II and III.
dcl-proc LineFile;
  dcl-pi *n varchar(14);
    i_line char(100) const;
  end-pi;

  if g_n4;
    return g_n4File;
  endif;
  return Up(Cols(i_line:7:14));
end-proc;

dcl-proc LineExc;
  dcl-pi *n varchar(14);
    i_line char(100) const;
  end-pi;

  if g_n4;
    return g_n4Exc;
  endif;
  return Up(Cols(i_line:32:37));
end-proc;

dcl-proc LineField;
  dcl-pi *n varchar(14);
    i_line char(100) const;
  end-pi;

  if g_n4;
    return g_n4Name;
  endif;
  return Up(Cols(i_line:32:37));
end-proc;

// ------------------------------------------------------------------
// Kind, length and decimals of a field: RPG II and III from the calculations, RPG IV
// from the D specifications and the result fields.
dcl-proc FieldInfoAny;
  dcl-pi *n ind;
    i_name varchar(14) const;
    o_kind char(1);
    o_length int(10);
    o_decimals int(10);
  end-pi;

  if SrcDialect() = '4';
    return Fx4FieldInfo(i_name:o_kind:o_length:o_decimals);
  endif;
  return CalcFieldInfo(i_name:o_kind:o_length:o_decimals);
end-proc;

// ------------------------------------------------------------------
// Parses all O specifications once (the EXCPT operations in the calculations
// come before them in the source and need the record format names).
dcl-proc OutBuild;
  dcl-pi *n;
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_line char(100);
  dcl-s l_g int(10) inz(0);
  dcl-s l_file varchar(8) inz('');
  dcl-s l_type char(1);
  dcl-s l_ao varchar(3);
  dcl-s l_reason varchar(150);
  dcl-s l_cond varchar(200);
  dcl-s l_cycle ind;
  dcl-s l_device char(1);
  dcl-s l_ftype char(1);
  dcl-s l_recDs varchar(12);
  dcl-s l_keyed ind;
  dcl-s l_sb varchar(2);
  dcl-s l_sa varchar(2);
  dcl-s l_kb varchar(3);
  dcl-s l_ka varchar(3);
  dcl-s l_keys varchar(60);
  dcl-s l_name varchar(10);
  dcl-s l_k int(10);
  dcl-s l_total int(10);
  dcl-s l_seq int(10);
  dcl-s l_end varchar(5);
  dcl-s l_fmt char(1);
  dcl-s l_const varchar(30);
  dcl-s l_used ind;
  dcl-s l_relative ind;
  dcl-s l_digits varchar(5);
  dcl-s l_disk ind;
  dcl-s l_diskWhy varchar(150);
  dcl-s l_ad varchar(3);
  dcl-s l_act char(1);
  dcl-s l_recLen int(10);
  dcl-s l_out ind;
  dcl-s l_upd ind;

  if g_built;
    return;
  endif;
  // The cycle skeleton decides whether heading, detail and total records can be
  // written; it may build this table itself (total records), so ask before g_built.
  l_cycle = CalcCycleActive();
  if g_built;
    return;
  endif;
  g_built = *on;

  for l_index = 1 to SrcCount();
    l_line = Norm4(SrcLine(l_index));
    if not IsOLine(l_line);
      iter;
    endif;

    // ---- a field line: columns 7-22 blank ----
    if Cols(l_line:7:22) = '';
      if l_g = 0 or g_fCount >= C_MAXFLD;
        iter;
      endif;
      if LineField(l_line) = '*PLACE';
        PlaceExpand(l_g:l_line);
        g_gEnd(l_g) = l_index;
        iter;
      endif;
      g_fCount += 1;
      g_fName(g_fCount) = LineField(l_line);
      g_fEdit(g_fCount) = Up(%subst(l_line:38:1));
      g_fConst(g_fCount) = Cols(l_line:45:70);
      g_fReason(g_fCount) = g_n4Reason;
      g_fEnd(g_fCount) = 0;
      g_fBlank(g_fCount) = *off;
      g_fSpecial(g_fCount) = ' ';
      g_fAlias(g_fCount) = '';
      g_fSrc(g_fCount) = '';
      l_end = Cols(l_line:40:43);
      l_fmt = %subst(Up(%subst(l_line:44:1) + ' '):1:1);
      g_fFmt(g_fCount) = l_fmt;
      l_cond = IndicatorCond(l_line:l_reason:' ');
      g_fCond(g_fCount) = l_cond;
      l_relative = (%subst(l_end:1:1) = '+');
      l_digits = l_end;
      if l_relative;
        l_digits = %trim(%subst(l_end:2));
      endif;
      select;
        when g_fName(g_fCount) = 'PAGE'
             or (%len(g_fName(g_fCount)) = 5
                 and %subst(g_fName(g_fCount):1:4) = 'PAGE'
                 and %scan(%subst(g_fName(g_fCount):5:1):'1234567') > 0);
          // PAGE and PAGE1 to PAGE7 (RV-61): page numbers, one for each kind of page.
          g_fSpecial(g_fCount) = 'P';
        when g_fName(g_fCount) = 'UDAY' or g_fName(g_fCount) = 'UMONTH'
             or g_fName(g_fCount) = 'UYEAR';
          // Part of the program date (RV-61): a field of 2 digits that is assigned
          // before the write (DDS has no keyword for a part of the date).
          g_fSpecial(g_fCount) = 'D';
          g_fAlias(g_fCount) = 'IA_' + g_fName(g_fCount);
          g_fSrc(g_fCount) = g_fName(g_fCount);
        when ArrayBase(g_fName(g_fCount)) <> '';
          // An array element ARR,3 or ARR,I (RV-61): a work field assigned before
          // the write.
          g_fSpecial(g_fCount) = 'E';
          g_aliasNo += 1;
          g_fAlias(g_fCount) = 'IA_E' + %char(g_aliasNo);
          g_fSrc(g_fCount) = ArrayBase(g_fName(g_fCount)) + '('
                             + ArrayIndex(g_fName(g_fCount)) + ')';
        when g_fName(g_fCount) = 'UDATE';
          g_fSpecial(g_fCount) = 'J';
        when g_fName(g_fCount) = '*DATE';
          g_fSpecial(g_fCount) = 'S';
      endsl;
      select;
        when g_fReason(g_fCount) <> '';
        when l_reason <> '';
          g_fReason(g_fCount) = l_reason;
        when l_digits = '' or %check(C_DIGITS:l_digits) > 0;
          g_fReason(g_fCount) = 'End position (columns 40-43) ' + l_end
                                + ' is not a plain or relative position';
        when l_relative and (g_gFields(l_g) = 0 or g_fEnd(g_fCount - 1) = 0);
          g_fReason(g_fCount) = 'A relative end position needs an end position '
                                + 'before it in the same record';
        when l_fmt <> ' ' and not (g_gDisk(l_g) and (l_fmt = 'P' or l_fmt = 'B'));
          if l_fmt = 'P' or l_fmt = 'B';
            g_fReason(g_fCount) = 'Data format ' + l_fmt + ' (column 44): packed '
                                  + 'and binary fields cannot be printed, only '
                                  + 'written to disk or ICF (SC09-1818); a DISK '
                                  + 'record needs a packed or binary subfield in '
                                  + 'the record data structure: not converted';
          else;
            g_fReason(g_fCount) = 'Data format ' + l_fmt + ' (column 44) is not '
                                  + 'valid: the manual allows blank, P and B';
          endif;
        when Up(%subst(l_line:39:1)) <> ' ' and Up(%subst(l_line:39:1)) <> 'B';
          g_fReason(g_fCount) = 'Entry ' + %subst(l_line:39:1) + ' in column 39 '
                                + 'is not valid';
        when Up(%subst(l_line:39:1)) = 'B'
             and (g_fSpecial(g_fCount) = 'D' or g_fSpecial(g_fCount) = 'E');
          g_fReason(g_fCount) = 'Blank after of ' + g_fName(g_fCount) + ' (a part '
                                + 'of the date or an array element) is not '
                                + 'converted';
        when Up(%subst(l_line:39:1)) = 'B' and g_fName(g_fCount) = '';
          g_fReason(g_fCount) = 'Blank after (column 39) needs a field';
        when g_fName(g_fCount) = '' and not IsConstant(g_fConst(g_fCount));
          g_fReason(g_fCount) = 'A field line needs a field name or a constant';
        when g_fName(g_fCount) <> '' and g_fConst(g_fCount) <> ''
             and not ((g_fEdit(g_fCount) = ' ' and IsConstant(g_fConst(g_fCount)))
                      or (g_fEdit(g_fCount) <> ' '
                          and (g_fConst(g_fCount) = '''*'''
                               or g_fConst(g_fCount) = '''$''')));
          g_fReason(g_fCount) = 'The entry in columns 45-70 is not an edit word, '
                                + 'a * or a $ with an edit code';
        when g_fSpecial(g_fCount) = ' ' and IsSpecialName(g_fName(g_fCount));
          g_fReason(g_fCount) = 'Field ' + g_fName(g_fCount) + ' (special word, '
                                + 'array element or table) is not converted';
        when g_fName(g_fCount) <> '' and g_fEdit(g_fCount) <> ' '
             and %scan(g_fEdit(g_fCount):'1234ABCDJKLMNOPQXZY') = 0;
          g_fReason(g_fCount) = 'Edit code ' + g_fEdit(g_fCount) + ' is not '
                                + 'converted (user-defined codes depend on the '
                                + 'system)';
        when g_fEdit(g_fCount) = 'Y' and g_fSpecial(g_fCount) <> 'J'
             and g_fSpecial(g_fCount) <> 'S';
          g_fReason(g_fCount) = 'Edit code Y of a field other than UDATE or *DATE '
                                + 'is not converted';
      endsl;
      if g_fReason(g_fCount) = '';
        if l_relative;
          g_fEnd(g_fCount) = g_fEnd(g_fCount - 1) + %int(l_digits);
        else;
          g_fEnd(g_fCount) = %int(l_digits);
        endif;
        g_fBlank(g_fCount) = (Up(%subst(l_line:39:1)) = 'B');
      endif;
      g_gFields(l_g) += 1;
      g_gEnd(l_g) = l_index;
      iter;
    endif;

    // ---- AND and OR lines ----
    l_ao = Up(Cols(l_line:14:16));
    if l_ao = 'AND' or l_ao = 'OR';
      if l_g > 0;
        l_cond = IndicatorCond(l_line:l_reason:g_gType(l_g));
        if l_reason <> '' and g_gReason(l_g) = '';
          g_gReason(l_g) = l_reason;
        elseif l_ao = 'OR';
          // The terms before are closed: (a) or (b); AND lines go to the last term.
          if (l_cond = '' or g_gCond(l_g) = '') and g_gReason(l_g) = '';
            g_gReason(l_g) = 'An OR line needs indicators, and so does the line '
                             + 'before it';
          elseif g_gReason(l_g) = '';
            if g_gOr(l_g) <> '';
              g_gOr(l_g) += ' or ';
            endif;
            g_gOr(l_g) += '(' + g_gCond(l_g) + ')';
            g_gCond(l_g) = l_cond;
          endif;
        elseif l_cond <> '';
          if g_gCond(l_g) <> '';
            g_gCond(l_g) += ' and ';
          endif;
          g_gCond(l_g) += l_cond;
        endif;
        g_gEnd(l_g) = l_index;
      endif;
      iter;
    endif;

    // ---- a record line ----
    if g_gCount >= C_MAXGRP;
      iter;
    endif;
    g_gCount += 1;
    l_g = g_gCount;
    if LineFile(l_line) <> '';
      l_file = LineFile(l_line);
    endif;
    l_type = %subst(Up(%subst(l_line:15:1) + ' '):1:1);
    g_gFile(l_g) = l_file;
    g_gName(l_g) = LineExc(l_line);
    g_gFmt(l_g) = '';
    g_gStart(l_g) = l_index;
    g_gEnd(l_g) = l_index;
    g_gReason(l_g) = '';
    g_gFirst(l_g) = g_fCount + 1;
    g_gFields(l_g) = 0;
    g_gType(l_g) = l_type;
    g_gOr(l_g) = '';
    g_gCond(l_g) = IndicatorCond(l_line:l_reason:l_type);
    g_gKeys(l_g) = '';
    g_gDisk(l_g) = *off;
    g_gAct(l_g) = ' ';
    g_gRecLen(l_g) = 0;
    g_gPlace(l_g) = 0;

    // A program described DISK file (RV-62): exception records only; blank or ADD
    // writes the record, DEL deletes the record read.
    l_disk = *off;
    l_diskWhy = '';
    l_act = ' ';
    l_recLen = 0;
    l_device = ' ';
    l_ftype = ' ';
    if l_file <> '' and %len(l_file) <= 8;
      if FileInfo(l_file:l_device:l_ftype:l_recDs:l_keyed) and l_device = 'D';
        l_disk = *on;
      endif;
    endif;
    if l_disk;
      l_ad = Up(Cols(l_line:16:18));
      if not FileOutInfo(l_file:l_recLen:l_out:l_upd);
        l_diskWhy = 'File ' + l_file + ' has no record length';
      else;
        select;
          when l_type <> 'E' and not l_cycle;
            l_diskWhy = 'Heading, detail and total records of a DISK file are written '
                        + 'by the RPG cycle skeleton (one program described primary '
                        + 'file): not converted without it, only exception records (E)';
          when l_ad = '' and l_ftype = 'O';
            l_act = 'W';
          when l_ad = '' and l_ftype = 'U' and l_recDs = '';
            l_diskWhy = 'Update of the record read needs the record layout of '
                        + 'file ' + l_file + ' (I specification, FREE-04)';
          when l_ad = '' and l_ftype = 'U';
            l_act = 'U';
          when l_ad = '';
            l_diskWhy = 'An input file with file addition needs ADD (columns 16-18)';
          when l_ad = 'ADD' and l_out;
            l_act = 'W';
          when l_ad = 'ADD';
            l_diskWhy = 'ADD needs a file with file addition (column 66 A)';
          when l_ad = 'DEL' and l_ftype = 'U';
            l_act = 'D';
          when l_ad = 'DEL';
            l_diskWhy = 'DEL needs an update file';
          other;
            l_diskWhy = 'Entry ' + l_ad + ' in columns 16-18 is not converted';
        endsl;
      endif;
    endif;
    select;
      when g_n4Reason <> '';
        g_gReason(l_g) = g_n4Reason;
      when l_reason <> '';
        g_gReason(l_g) = l_reason;
      when l_type <> 'E' and l_type <> 'H' and l_type <> 'D' and l_type <> 'T';
        g_gReason(l_g) = 'Record type ' + l_type + ' (column 15) is not valid';
      when l_disk and l_diskWhy <> '';
        g_gReason(l_g) = l_diskWhy;
      when l_type <> 'E' and not l_cycle and not l_disk;
        g_gReason(l_g) = 'Heading, detail and total records are written by the '
                         + 'RPG cycle skeleton (one program described primary '
                         + 'file): not converted without it';
      when Cols(l_line:16:18) <> '' and not l_disk;
        g_gReason(l_g) = 'Entry in columns 16-18 (ADD, DEL, fetch overflow, '
                         + 'release) is not converted';
      when l_file = '' or %len(l_file) > 8;
        g_gReason(l_g) = 'The file name of the output record is missing or too long';
      when l_disk;
        g_gDisk(l_g) = *on;
        g_gAct(l_g) = l_act;
        g_gRecLen(l_g) = l_recLen;
      when not FileInfo(l_file:l_device:l_ftype:l_recDs:l_keyed)
           or l_device <> 'P';
        g_gReason(l_g) = 'File ' + l_file + ' is not a PRINTER file declared by a '
                         + 'converted file description';
      when PrinterNumber(l_file) = 0 and g_pCount >= C_MAXPRT;
        g_gReason(l_g) = 'More than ' + %char(C_MAXPRT) + ' printer files in one '
                         + 'source';
    endsl;

    // Spacing and skipping.
    l_sb = Cols(l_line:17:17);
    l_sa = Cols(l_line:18:18);
    l_kb = SkipNumber(Cols(l_line:19:20));
    l_ka = SkipNumber(Cols(l_line:21:22));
    if l_disk;
      // Columns 16-18 hold ADD or DEL: no spacing or skipping on a DISK file.
      l_sb = '';
      l_sa = '';
    endif;
    if g_gReason(l_g) = '' and (l_sb <> '' and (%check('0123':l_sb) > 0)
       or l_sa <> '' and (%check('0123':l_sa) > 0) or l_kb = '?' or l_ka = '?');
      g_gReason(l_g) = 'Space or skip entry (columns 17-22) is not valid';
    endif;
    l_keys = '';
    if l_kb <> '' and l_kb <> '?';
      l_keys += 'SKIPB(' + l_kb + ') ';
    endif;
    if l_sb <> '' and l_sb <> '0';
      l_keys += 'SPACEB(' + l_sb + ') ';
    endif;
    if l_ka <> '' and l_ka <> '?';
      l_keys += 'SKIPA(' + l_ka + ') ';
    endif;
    // A blank space-after entry means no spacing in RPG; DDS spaces one line by
    // default, so the keyword is always given.
    if l_sa = '';
      l_sa = '0';
    endif;
    l_keys += 'SPACEA(' + l_sa + ')';
    g_gKeys(l_g) = l_keys;
    if g_gReason(l_g) = '' and not l_disk;
      if PrinterNumber(l_file) = 0;
        g_pCount += 1;
        g_pName(g_pCount) = l_file;
      endif;
    endif;
  endfor;

  // Terms of OR lines: (a) or (b) or (c).
  for l_k = 1 to g_gCount;
    if g_gOr(l_k) <> '';
      g_gCond(l_k) = g_gOr(l_k) + ' or (' + g_gCond(l_k) + ')';
    endif;
  endfor;

  // Format names: the EXCPT name, with a two-digit number when the name is used
  // for more than one record.
  for l_k = 1 to g_gCount;
    g_gOk(l_k) = (g_gReason(l_k) = '');
  endfor;
  for l_k = 1 to g_gCount;
    if not g_gOk(l_k) or g_gType(l_k) <> 'E';
      iter;
    endif;
    l_name = g_gName(l_k);
    if l_name = '';
      l_name = 'EXCPT';
    endif;
    l_total = 0;
    l_seq = 0;
    for l_index = 1 to g_gCount;
      if g_gOk(l_index) and g_gType(l_index) = 'E'
         and g_gName(l_index) = g_gName(l_k);
        l_total += 1;
        if l_index <= l_k;
          l_seq += 1;
        endif;
      endif;
    endfor;
    if l_total = 1;
      g_gFmt(l_k) = l_name;
    else;
      g_gFmt(l_k) = l_name + %subst('0' + %char(l_seq):%len('0' + %char(l_seq))
                    - 1:2);
    endif;
  endfor;
  // Heading, detail and total records: HEAD01, DETAIL01, TOTAL01 and so on, a name
  // that no other format has.
  for l_k = 1 to g_gCount;
    if not g_gOk(l_k) or g_gType(l_k) = 'E';
      iter;
    endif;
    select;
      when g_gType(l_k) = 'H';
        l_name = 'HEAD';
      when g_gType(l_k) = 'D';
        l_name = 'DETAIL';
      other;
        l_name = 'TOTAL';
    endsl;
    l_seq = 0;
    dou not l_used;
      l_seq += 1;
      g_gFmt(l_k) = l_name + %subst('0' + %char(l_seq):%len('0' + %char(l_seq))
                    - 1:2);
      l_used = *off;
      for l_index = 1 to g_gCount;
        if l_index <> l_k and g_gOk(l_index) and g_gFmt(l_index) = g_gFmt(l_k);
          l_used = *on;
        endif;
      endfor;
    enddo;
  endfor;
end-proc;

// ------------------------------------------------------------------
dcl-proc OutExceptCount export;
  dcl-pi *n int(10);
    i_name varchar(10) const;
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_count int(10) inz(0);

  OutBuild();
  for l_k = 1 to g_gCount;
    if g_gOk(l_k) and g_gType(l_k) = 'E' and g_gName(l_k) = Up(i_name);
      l_count += 1;
    endif;
  endfor;
  return l_count;
end-proc;

// ------------------------------------------------------------------
dcl-proc OutGroupNumber;
  dcl-pi *n int(10);
    i_name varchar(10) const;
    i_number int(10) const;
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_count int(10) inz(0);

  for l_k = 1 to g_gCount;
    if g_gOk(l_k) and g_gType(l_k) = 'E' and g_gName(l_k) = Up(i_name);
      l_count += 1;
      if l_count = i_number;
        return l_k;
      endif;
    endif;
  endfor;
  return 0;
end-proc;

// ------------------------------------------------------------------
dcl-proc OutExceptFormat export;
  dcl-pi *n varchar(10);
    i_name varchar(10) const;
    i_number int(10) const;
  end-pi;

  dcl-s l_g int(10);

  l_g = OutGroupNumber(i_name:i_number);
  if l_g = 0;
    return '';
  endif;
  return g_gFmt(l_g);
end-proc;

// ------------------------------------------------------------------
dcl-proc OutExceptCond export;
  dcl-pi *n varchar(200);
    i_name varchar(10) const;
    i_number int(10) const;
  end-pi;

  dcl-s l_g int(10);

  l_g = OutGroupNumber(i_name:i_number);
  if l_g = 0;
    return '';
  endif;
  return g_gCond(l_g);
end-proc;

// ------------------------------------------------------------------
// The records the cycle skeleton writes (RV-60): part S is step 1 (heading and
// detail records, source order), part T the total time (total records).
dcl-proc OutCycleGroup;
  dcl-pi *n int(10);
    i_part char(1) const;
    i_number int(10) const;
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_count int(10) inz(0);

  OutBuild();
  for l_k = 1 to g_gCount;
    if g_gOk(l_k) and ((i_part = 'S' and (g_gType(l_k) = 'H' or g_gType(l_k) = 'D'))
                       or (i_part = 'T' and g_gType(l_k) = 'T'));
      l_count += 1;
      if l_count = i_number;
        return l_k;
      endif;
    endif;
  endfor;
  if i_number = 0;
    return l_count;
  endif;
  return 0;
end-proc;

// ------------------------------------------------------------------
dcl-proc OutCycleCount export;
  dcl-pi *n int(10);
    i_part char(1) const;
  end-pi;

  return OutCycleGroup(i_part:0);
end-proc;

// ------------------------------------------------------------------
dcl-proc OutCycleFormat export;
  dcl-pi *n varchar(10);
    i_part char(1) const;
    i_number int(10) const;
  end-pi;

  dcl-s l_g int(10);

  l_g = OutCycleGroup(i_part:i_number);
  if l_g = 0;
    return '';
  endif;
  return g_gFmt(l_g);
end-proc;

// ------------------------------------------------------------------
// FREE-54: *on when the nth heading, detail or total record of the part is a record
// of a program described DISK file (statements, no DDS format).
dcl-proc OutCycleDisk export;
  dcl-pi *n ind;
    i_part char(1) const;
    i_number int(10) const;
  end-pi;

  dcl-s l_g int(10);

  l_g = OutCycleGroup(i_part:i_number);
  if l_g = 0;
    return *off;
  endif;
  return g_gDisk(l_g);
end-proc;

// ------------------------------------------------------------------
// FREE-54: the file whose record data structure (FILE_OUT) the nth DISK record of
// the part uses; '' for an update, which uses FILE_REC of the I specifications.
dcl-proc OutCycleFile export;
  dcl-pi *n varchar(8);
    i_part char(1) const;
    i_number int(10) const;
  end-pi;

  dcl-s l_g int(10);

  l_g = OutCycleGroup(i_part:i_number);
  if l_g = 0 or not g_gDisk(l_g) or g_gAct(l_g) = 'U';
    return '';
  endif;
  return g_gFile(l_g);
end-proc;

// ------------------------------------------------------------------
// FREE-54: the statements of the nth DISK record of the part (as OutDiskStatements
// for an EXCPT). Returns the number of statements, 0 with the reason when the
// record cannot be written.
dcl-proc OutCycleStatements export;
  dcl-pi *n int(10);
    i_part char(1) const;
    i_number int(10) const;
    o_stmts varchar(250) dim(40);
    o_reason varchar(190);
  end-pi;

  dcl-s l_g int(10);

  o_reason = '';
  l_g = OutCycleGroup(i_part:i_number);
  if l_g = 0 or not g_gDisk(l_g);
    o_reason = 'No heading, detail or total record of a DISK file with this number';
    return 0;
  endif;
  return DiskBuild(l_g:o_stmts:o_reason);
end-proc;

// ------------------------------------------------------------------
dcl-proc OutCycleCond export;
  dcl-pi *n varchar(200);
    i_part char(1) const;
    i_number int(10) const;
  end-pi;

  dcl-s l_g int(10);

  l_g = OutCycleGroup(i_part:i_number);
  if l_g = 0;
    return '';
  endif;
  return g_gCond(l_g);
end-proc;

// ------------------------------------------------------------------
// One O specification line in the conversion pass: a record line starts a group,
// the group is converted (reported) with all its lines.
dcl-proc OutLine export;
  dcl-pi *n int(10);
    i_index int(10) const;
    i_lineNo int(10) const;
    i_line char(100) const;
  end-pi;

  dcl-s l_g int(10) inz(0);
  dcl-s l_k int(10);
  dcl-s l_j int(10);
  dcl-s l_note varchar(190);

  OutBuild();
  for l_k = 1 to g_gCount;
    if g_gStart(l_k) = i_index;
      l_g = l_k;
      leave;
    endif;
  endfor;
  if l_g = 0;
    ReviewSpec(i_lineNo:i_line:'Output specification line outside an output '
               + 'record');
    return 0;
  endif;

  if g_gOk(l_g);
    // Written to the DDS at the end: reported when the DDS is built.
    return g_gEnd(l_g) - i_index;
  endif;
  ReviewSpec(i_lineNo:i_line:g_gReason(l_g));
  for l_j = i_index + 1 to g_gEnd(l_g);
    ReviewSpec(SrcLineNo(l_j):SrcLine(l_j):'Part of the output record above that '
               + 'is not converted');
  endfor;
  return g_gEnd(l_g) - i_index;
end-proc;

// ------------------------------------------------------------------
dcl-proc RightText;
  dcl-pi *n varchar(10);
    i_text varchar(10) const;
    i_width int(10) const;
  end-pi;

  if %len(i_text) >= i_width;
    return i_text;
  endif;
  return %subst('          ':1:i_width - %len(i_text)) + i_text;
end-proc;

// ------------------------------------------------------------------
// The length of a character constant ('' doubled counts once).
dcl-proc ConstLength;
  dcl-pi *n int(10);
    i_const varchar(30) const;
  end-pi;

  dcl-s l_k int(10) inz(2);
  dcl-s l_len int(10) inz(0);

  dow l_k < %len(i_const);
    l_len += 1;
    if %subst(i_const:l_k:1) = C_QUOTE;
      l_k += 1;
    endif;
    l_k += 1;
  enddo;
  return l_len;
end-proc;

// ------------------------------------------------------------------
dcl-proc AddDds;
  dcl-pi *n;
    i_text varchar(80) const;
  end-pi;

  if g_ddsCount < C_MAXDDS;
    g_ddsCount += 1;
    g_dds(g_ddsCount) = i_text;
    g_ddsNo(g_ddsCount) = g_curFile;
  endif;
end-proc;

// ------------------------------------------------------------------
// The conditioning indicators of a DDS line (columns 8-16) from a free-form
// condition '*in01 and not *in02'.
dcl-proc DdsCond;
  dcl-pi *n varchar(9);
    i_cond varchar(80) const;
  end-pi;

  dcl-s l_rest varchar(80);
  dcl-s l_and int(10);
  dcl-s l_term varchar(20);
  dcl-s l_out varchar(9) inz('');

  l_rest = i_cond;
  dow l_rest <> '';
    l_and = %scan(' and ':l_rest);
    if l_and = 0;
      l_term = l_rest;
      l_rest = '';
    else;
      l_term = %subst(l_rest:1:l_and - 1);
      l_rest = %subst(l_rest:l_and + 5);
    endif;
    if %subst(l_term:1:4) = 'not ';
      l_out += 'N' + %xlate(C_LOWER:C_UPPER:%subst(l_term:8:2));
    else;
      l_out += ' ' + %xlate(C_LOWER:C_UPPER:%subst(l_term:4:2));
    endif;
  enddo;
  return l_out;
end-proc;

// ------------------------------------------------------------------
dcl-proc DdsRow;
  dcl-pi *n varchar(80);
    i_cond varchar(9) const;
    i_name varchar(10) const;
    i_len varchar(5) const;
    i_type varchar(1) const;
    i_dec varchar(2) const;
    i_pos varchar(3) const;
    i_text varchar(40) const;
  end-pi;

  dcl-s l_row char(80) inz(' ');

  %subst(l_row:6:1) = 'A';
  if i_cond <> '';
    %subst(l_row:8:%len(i_cond)) = i_cond;
  endif;
  if i_name <> '';
    %subst(l_row:19:%len(i_name)) = i_name;
  endif;
  if i_len <> '';
    %subst(l_row:30:5) = RightText(i_len:5);
  endif;
  if i_type <> '';
    %subst(l_row:35:1) = i_type;
    if i_name <> '';
      %subst(l_row:38:1) = 'O';
    endif;
  endif;
  if i_dec <> '';
    %subst(l_row:36:2) = RightText(i_dec:2);
  endif;
  if i_pos <> '';
    %subst(l_row:42:3) = RightText(i_pos:3);
  endif;
  if i_text <> '';
    %subst(l_row:45:%len(i_text)) = i_text;
  endif;
  return %trimr(l_row);
end-proc;

// ------------------------------------------------------------------
// The field name in the DDS: *DATE becomes SYSDATE.
dcl-proc DdsName;
  dcl-pi *n varchar(10);
    i_field int(10) const;
  end-pi;

  if g_fSpecial(i_field) = 'S';
    return 'SYSDATE';
  endif;
  if g_fAlias(i_field) <> '';
    return g_fAlias(i_field);
  endif;
  return g_fName(i_field);
end-proc;

// ------------------------------------------------------------------
// The edit code or edit word of a numeric output field (RV-61): the printed width
// and the DDS keywords. Returns the reason when it cannot be converted.
dcl-proc NumericEdit;
  dcl-pi *n varchar(150);
    i_field int(10) const;
    i_digits int(10) const;
    i_decimals int(10) const;
    o_width int(10);
    o_keyword varchar(40);
  end-pi;

  dcl-s l_code char(1);
  dcl-s l_currency ind inz(*off);
  dcl-s l_fill varchar(2) inz('');
  dcl-s l_keyword varchar(80) inz('');

  o_width = i_digits;
  o_keyword = '';
  l_code = g_fEdit(i_field);
  if g_fSpecial(i_field) = 'P' and (l_code <> ' ' or g_fConst(i_field) <> '');
    return 'PAGE has its own editing: an edit code or edit word is not converted';
  endif;
  select;
    when g_fSpecial(i_field) = 'P';
      l_keyword = 'PAGNBR EDTCDE(Z)';
    when g_fSpecial(i_field) = 'J';
      l_keyword = 'DATE(*JOB)';
    when g_fSpecial(i_field) = 'S';
      l_keyword = 'DATE(*SYS)';
  endsl;
  select;
    when l_code <> ' ';
      if g_fConst(i_field) = '''$''';
        l_currency = *on;
        l_fill = ' $';
      elseif g_fConst(i_field) = '''*''';
        l_fill = ' *';
      endif;
      if l_code = 'Y';
        o_width = 8;
      else;
        o_width = EditWidth(l_code:i_digits:i_decimals:l_currency);
        if o_width = 0;
          return 'Edit code ' + l_code + ' is not converted';
        endif;
      endif;
      if l_keyword <> '';
        l_keyword += ' ';
      endif;
      l_keyword += 'EDTCDE(' + l_code + l_fill + ')';
    when g_fConst(i_field) <> '';
      o_width = EditWordLength(g_fConst(i_field));
      if l_keyword <> '';
        l_keyword += ' ';
      endif;
      l_keyword += 'EDTWRD(' + g_fConst(i_field) + ')';
  endsl;
  if %len(l_keyword) > 40 or o_width < 1;
    return 'The edit word is too long for one DDS line';
  endif;
  o_keyword = l_keyword;
  return '';
end-proc;

// ------------------------------------------------------------------
// The printed width of an edited numeric field (RV-61): digits, the decimal point,
// the commas of the codes 1, 2, A, B, J, K, N and O, the sign (CR, minus) and a
// floating currency symbol. i_code X and Z print the digits only. 0 when the code
// is not converted.
dcl-proc EditWidth;
  dcl-pi *n int(10);
    i_code char(1) const;
    i_digits int(10) const;
    i_decimals int(10) const;
    i_currency ind const;
  end-pi;

  dcl-s l_width int(10);
  dcl-s l_integer int(10);

  if i_code = 'X' or i_code = 'Z';
    return i_digits;
  endif;
  if %scan(i_code:'1234ABCDJKLMNOPQ') = 0;
    return 0;
  endif;
  l_width = i_digits;
  if i_decimals > 0;
    l_width += 1;
  endif;
  l_integer = i_digits - i_decimals;
  if %scan(i_code:'12ABJKNO') > 0 and l_integer > 3;
    l_width += (l_integer - 1) / 3;
  endif;
  select;
    when %scan(i_code:'ABCD') > 0;
      l_width += 2;
    when %scan(i_code:'JKLMNOPQ') > 0;
      l_width += 1;
  endsl;
  if i_currency;
    l_width += 1;
  endif;
  return l_width;
end-proc;

// ------------------------------------------------------------------
// The length of an edit word between its apostrophes (a doubled apostrophe is one).
dcl-proc EditWordLength;
  dcl-pi *n int(10);
    i_text varchar(30) const;
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_len int(10) inz(0);

  l_k = 2;
  dow l_k < %len(i_text);
    l_len += 1;
    if %subst(i_text:l_k:2) = '''''';
      l_k += 1;
    endif;
    l_k += 1;
  enddo;
  return l_len;
end-proc;

// ------------------------------------------------------------------
// ARR,3 or ARR,I of RPG II/III: the array name, '' for any other name.
dcl-proc ArrayBase;
  dcl-pi *n varchar(14);
    i_name varchar(14) const;
  end-pi;

  dcl-s l_comma int(10);

  l_comma = %scan(',':i_name);
  if l_comma < 2 or l_comma = %len(i_name)
     or %check(C_DIGITS + C_UPPER + '#$@_':%subst(i_name:1:l_comma - 1)) > 0
     or %check(C_DIGITS + C_UPPER + '#$@_':%subst(i_name:l_comma + 1)) > 0;
    return '';
  endif;
  return %subst(i_name:1:l_comma - 1);
end-proc;

// ------------------------------------------------------------------
dcl-proc ArrayIndex;
  dcl-pi *n varchar(14);
    i_name varchar(14) const;
  end-pi;

  return %subst(i_name:%scan(',':i_name) + 1);
end-proc;

// ------------------------------------------------------------------
// *PLACE (RV-61): the fields before the first *PLACE of the record are written again,
// ending at the end position of the line: each of them is a copy with its own DDS
// name, assigned before the write. The group moves by the end position less the end
// of its last field (Table 18 and Figure 228 of SC09-1818).
dcl-proc PlaceExpand;
  dcl-pi *n;
    i_g int(10) const;
    i_line char(100) const;
  end-pi;

  dcl-s l_reason varchar(150) inz('');
  dcl-s l_iReason varchar(150) inz('');
  dcl-s l_cond varchar(200);
  dcl-s l_end varchar(5);
  dcl-s l_n int(10);
  dcl-s l_f int(10);
  dcl-s l_new int(10);
  dcl-s l_last int(10) inz(0);
  dcl-s l_shift int(10);

  if g_gPlace(i_g) = 0;
    g_gPlace(i_g) = g_gFields(i_g);
  endif;
  l_n = g_gPlace(i_g);
  l_end = Cols(i_line:40:43);
  l_cond = IndicatorCond(i_line:l_iReason:' ');
  for l_f = g_gFirst(i_g) to g_gFirst(i_g) + l_n - 1;
    if g_fReason(l_f) <> '' and l_reason = '';
      l_reason = g_fReason(l_f);
    endif;
    if g_fSpecial(l_f) = 'P' or g_fSpecial(l_f) = 'J' or g_fSpecial(l_f) = 'S';
      l_reason = 'PAGE, UDATE and *DATE cannot be repeated by *PLACE';
    endif;
    if g_fEnd(l_f) > l_last;
      l_last = g_fEnd(l_f);
    endif;
  endfor;
  select;
    when l_reason <> '';
    when g_n4Reason <> '';
      l_reason = g_n4Reason;
    when l_iReason <> '';
      l_reason = l_iReason;
    when l_cond <> '';
      l_reason = 'Output indicators on a *PLACE line are not converted';
    when %subst(i_line:44:1) <> ' ' or %subst(i_line:38:1) <> ' '
         or %subst(i_line:39:1) <> ' ' or Cols(i_line:45:70) <> '';
      l_reason = 'A *PLACE line has only the end position (columns 40-43)';
    when l_end = '' or %check(C_DIGITS:l_end) > 0 or %int(l_end) < 1
         or %int(l_end) > 256;
      l_reason = 'End position of *PLACE is not 1 to 256';
    when l_n = 0;
      l_reason = '*PLACE has no field before it in the record';
    when g_fCount + l_n > C_MAXFLD;
      l_reason = 'Too many fields for *PLACE';
  endsl;
  if l_reason <> '';
    if g_gReason(i_g) = '';
      g_gReason(i_g) = l_reason;
    endif;
    return;
  endif;

  l_shift = %int(l_end) - l_last;
  for l_f = g_gFirst(i_g) to g_gFirst(i_g) + l_n - 1;
    g_fCount += 1;
    l_new = g_fCount;
    g_fName(l_new) = g_fName(l_f);
    g_fEdit(l_new) = g_fEdit(l_f);
    g_fConst(l_new) = g_fConst(l_f);
    g_fCond(l_new) = g_fCond(l_f);
    g_fReason(l_new) = '';
    g_fBlank(l_new) = *off;
    g_fSpecial(l_new) = g_fSpecial(l_f);
    g_fFmt(l_new) = g_fFmt(l_f);
    g_fEnd(l_new) = g_fEnd(l_f) + l_shift;
    g_fAlias(l_new) = '';
    g_fSrc(l_new) = '';
    if g_fName(l_f) <> '';
      g_aliasNo += 1;
      g_fAlias(l_new) = 'IA_P' + %char(g_aliasNo);
      g_fSrc(l_new) = g_fSrc(l_f);
      if g_fSrc(l_f) = '';
        g_fSrc(l_new) = g_fName(l_f);
      endif;
    endif;
    g_gFields(i_g) += 1;
  endfor;
end-proc;

// ------------------------------------------------------------------
// The assignments before the write of a record (RV-61): 'IA_E1 = ARR(3); ...' for
// array elements, the parts of the date and the copies of *PLACE; '' when none.
dcl-proc GroupBefore;
  dcl-pi *n varchar(250);
    i_group int(10) const;
  end-pi;

  dcl-s l_f int(10);
  dcl-s l_text varchar(250) inz('');

  for l_f = g_gFirst(i_group) to g_gFirst(i_group) + g_gFields(i_group) - 1;
    if g_fAlias(l_f) <> '' and g_fSrc(l_f) <> '' and g_fReason(l_f) = '';
      if %len(l_text) + %len(g_fAlias(l_f)) + %len(g_fSrc(l_f)) + 5 > 250;
        return l_text + 'x';
      endif;
      if l_text <> '';
        l_text += '; ';
      endif;
      l_text += g_fAlias(l_f) + ' = ' + g_fSrc(l_f);
    endif;
  endfor;
  return l_text;
end-proc;

// ------------------------------------------------------------------
dcl-proc OutExceptBefore export;
  dcl-pi *n varchar(250);
    i_name varchar(10) const;
    i_number int(10) const;
  end-pi;

  dcl-s l_g int(10);

  l_g = OutGroupNumber(i_name:i_number);
  if l_g = 0;
    return '';
  endif;
  return GroupBefore(l_g);
end-proc;

// ------------------------------------------------------------------
dcl-proc OutCycleBefore export;
  dcl-pi *n varchar(250);
    i_part char(1) const;
    i_number int(10) const;
  end-pi;

  dcl-s l_g int(10);

  l_g = OutCycleGroup(i_part:i_number);
  if l_g = 0;
    return '';
  endif;
  return GroupBefore(l_g);
end-proc;

// ------------------------------------------------------------------
// The statements that clear the fields with blank after (column 39) of a record,
// 'clear A; clear B', '' when there is none.
dcl-proc GroupAfter;
  dcl-pi *n varchar(120);
    i_group int(10) const;
  end-pi;

  dcl-s l_f int(10);
  dcl-s l_text varchar(120) inz('');

  for l_f = g_gFirst(i_group) to g_gFirst(i_group) + g_gFields(i_group) - 1;
    if g_fBlank(l_f) and g_fName(l_f) <> '';
      if l_text <> '';
        l_text += '; ';
      endif;
      l_text += 'clear ' + g_fName(l_f);
    endif;
  endfor;
  return l_text;
end-proc;

// ------------------------------------------------------------------
dcl-proc OutExceptAfter export;
  dcl-pi *n varchar(120);
    i_name varchar(10) const;
    i_number int(10) const;
  end-pi;

  dcl-s l_g int(10);

  l_g = OutGroupNumber(i_name:i_number);
  if l_g = 0;
    return '';
  endif;
  return GroupAfter(l_g);
end-proc;

// ------------------------------------------------------------------
dcl-proc OutCycleAfter export;
  dcl-pi *n varchar(120);
    i_part char(1) const;
    i_number int(10) const;
  end-pi;

  dcl-s l_g int(10);

  l_g = OutCycleGroup(i_part:i_number);
  if l_g = 0;
    return '';
  endif;
  return GroupAfter(l_g);
end-proc;

// ------------------------------------------------------------------
dcl-proc CycleNote;
  dcl-pi *n varchar(120);
    i_type char(1) const;
  end-pi;

  select;
    when i_type = 'H' or i_type = 'D';
      return '; written at the start of each cycle of the cycle skeleton (step 1, '
             + 'output of the previous record)';
    when i_type = 'T';
      return '; written at the end of the subroutine IA_TOTALS (total time)';
  endsl;
  return '';
end-proc;

// ------------------------------------------------------------------
// Builds the DDS of the converted groups. A group whose fields are not known
// well enough is reported R (its EXCPT writes a format that is not generated).
dcl-proc OutFinish export;
  dcl-pi *n int(10);
  end-pi;

  dcl-s l_g int(10);
  dcl-s l_f int(10);
  dcl-s l_first int(10);
  dcl-s l_last int(10);
  dcl-s l_kind char(1);
  dcl-s l_len int(10);
  dcl-s l_dec int(10);
  dcl-s l_start int(10);
  dcl-s l_prevStart int(10);
  dcl-s l_reason varchar(190);
  dcl-s l_rows varchar(80) dim(100);
  dcl-s l_rowCount int(10);
  dcl-s l_rec varchar(80);
  dcl-s l_note varchar(190);
  dcl-s l_j int(10);
  dcl-s l_type varchar(1);
  dcl-s l_decText varchar(2);
  dcl-s l_status char(1);
  dcl-s l_keys varchar(60);
  dcl-s l_word varchar(20);
  dcl-s l_blank int(10);
  dcl-s l_width int(10);
  dcl-s l_keyword varchar(40);
  dcl-s l_special char(1);
  dcl-s l_known ind;
  dcl-s l_p int(10);
  dcl-s l_head ind;

  OutBuild();
  g_ddsCount = 0;
  // Pass 0 reports the DISK records, pass n builds the DDS of the nth printer file.
  for l_p = 0 to g_pCount;
  g_curFile = l_p;
  l_head = *off;
  for l_g = 1 to g_gCount;
    if not g_gOk(l_g);
      iter;
    endif;
    if g_gDisk(l_g);
      if l_p = 0;
        DiskFinish(l_g);
      endif;
      iter;
    endif;
    if l_p = 0 or g_gFile(l_g) <> g_pName(l_p);
      iter;
    endif;
    l_reason = '';
    l_rowCount = 0;
    l_prevStart = 0;
    l_first = g_gFirst(l_g);
    l_last = l_first + g_gFields(l_g) - 1;
    for l_f = l_first to l_last;
      l_keyword = '';
      l_special = ' ';
      select;
        when g_fReason(l_f) <> '';
          l_reason = g_fReason(l_f);
        when g_fName(l_f) = '';
          // A constant: 'text' ending at the end position.
          l_len = ConstLength(g_fConst(l_f));
          l_width = l_len;
          l_start = g_fEnd(l_f) - l_len + 1;
          l_type = '';
          l_decText = '';
        other;
          l_known = *on;
          select;
            when g_fSpecial(l_f) = 'P';
              l_kind = 'N';
              l_len = 4;
              l_dec = 0;
            when g_fSpecial(l_f) = 'J' or g_fSpecial(l_f) = 'S';
              l_kind = 'N';
              l_len = 6;
              l_dec = 0;
            when g_fSpecial(l_f) = 'D';
              l_kind = 'N';
              l_len = 2;
              l_dec = 0;
            when g_fSpecial(l_f) = 'E';
              l_known = FieldInfoAny(ArrayBase(g_fName(l_f)):l_kind:l_len:l_dec);
            other;
              l_known = FieldInfoAny(g_fName(l_f):l_kind:l_len:l_dec);
          endsl;
          l_width = l_len;
          if not l_known;
            l_reason = 'Field ' + g_fName(l_f) + ' has no known length and type';
          elseif l_kind <> 'N' and (g_fEdit(l_f) <> ' ' or g_fConst(l_f) <> '');
            l_reason = 'Edit code or edit word of the character field '
                       + g_fName(l_f) + ' is not valid';
          else;
            l_reason = NumericEdit(l_f:l_len:l_dec:l_width:l_keyword);
          endif;
          if l_reason = '';
            l_start = g_fEnd(l_f) - l_width + 1;
            if l_kind = 'N';
              l_type = 'S';
              l_decText = %char(l_dec);
            else;
              l_type = 'A';
              l_decText = '';
            endif;
            l_special = g_fSpecial(l_f);
            if l_special = 'D' or l_special = 'E';
              l_special = ' ';
            endif;
          endif;
      endsl;
      if l_reason = '' and l_start < 1;
        l_reason = 'Field ' + g_fName(l_f) + ' starts before position 1';
      endif;
      if l_reason = '' and %len(GroupBefore(l_g)) > 200;
        l_reason = 'Too many fields with an assignment before the write for one '
                   + 'statement: split the record';
      endif;
      if l_reason = '' and l_start <= l_prevStart and l_rowCount > 0;
        l_reason = 'Fields are not in ascending position order';
      endif;
      if l_reason <> '';
        leave;
      endif;
      l_prevStart = l_start + l_width - 1;
      if l_rowCount < 100;
        l_rowCount += 1;
        if g_fName(l_f) = '';
          l_rows(l_rowCount) = DdsRow(DdsCond(g_fCond(l_f)):'':'':'':'':
                                      %char(l_start):g_fConst(l_f));
        else;
          l_rows(l_rowCount) = DdsRow(DdsCond(g_fCond(l_f)):DdsName(l_f)
                                      :%char(l_len):l_type:l_decText
                                      :%char(l_start):l_keyword);
          if l_special <> ' ';
            // PAGNBR and DATE fields are supplied by the system: no usage.
            %subst(l_rows(l_rowCount):38:1) = ' ';
          endif;
        endif;
      endif;
    endfor;

    if l_reason <> '';
      g_gOk(l_g) = *off;
      RptItem(C_STS_REVIEW:SrcLineNo(g_gStart(l_g)):%trimr(%subst(
              SrcLine(g_gStart(l_g)):6:75))
              :'DDS record format ' + g_gFmt(l_g) + ' is not generated: '
              + l_reason + '; the write of this format is in the converted source: '
              + 'fix by hand');
      iter;
    endif;

    if not l_head;
      l_head = *on;
      AddDds('     A* Printer file ' + g_pName(l_p) + ': generated by IACNVFREE from '
             + 'the O specifications');
    endif;
    // The record line carries the first keyword, one more line for each other.
    l_keys = g_gKeys(l_g);
    l_blank = %scan(' ':l_keys);
    if l_blank = 0;
      l_word = l_keys;
      l_keys = '';
    else;
      l_word = %subst(l_keys:1:l_blank - 1);
      l_keys = %subst(l_keys:l_blank + 1);
    endif;
    l_rec = DdsRow('':g_gFmt(l_g):'':'':'':'':l_word);
    %subst(l_rec:17:1) = 'R';
    AddDds(l_rec);
    dow l_keys <> '';
      l_blank = %scan(' ':l_keys);
      if l_blank = 0;
        l_word = l_keys;
        l_keys = '';
      else;
        l_word = %subst(l_keys:1:l_blank - 1);
        l_keys = %subst(l_keys:l_blank + 1);
      endif;
      AddDds(DdsRow('':'':'':'':'':'':l_word));
    enddo;
    for l_j = 1 to l_rowCount;
      AddDds(l_rows(l_j));
    endfor;
    RptItem(C_STS_ASSUMPTION:SrcLineNo(g_gStart(l_g)):%trimr(%subst(
            SrcLine(g_gStart(l_g)):6:75))
            :'Record format of the printer file DDS (comments at the end of the '
            + 'converted source); the DDS is not tested: check line and position '
            + 'entries'
            + CycleNote(g_gType(l_g)));
    for l_j = g_gStart(l_g) + 1 to g_gEnd(l_g);
      RptItem(C_STS_CONVERTED:SrcLineNo(l_j):%trimr(%subst(SrcLine(l_j):6:75)):'');
    endfor;
  endfor;
  endfor;
  return g_ddsCount;
end-proc;

// ------------------------------------------------------------------
// RV-62: the kind of the nth record of an EXCPT name: *on for a record of a
// program described DISK file (statements, no DDS).
dcl-proc OutExceptDisk export;
  dcl-pi *n ind;
    i_name varchar(10) const;
    i_number int(10) const;
  end-pi;

  dcl-s l_g int(10);

  l_g = OutGroupNumber(i_name:i_number);
  if l_g = 0;
    return *off;
  endif;
  return g_gDisk(l_g);
end-proc;

// ------------------------------------------------------------------
// RV-62: the file of the nth record of an EXCPT name.
dcl-proc OutExceptFile export;
  dcl-pi *n varchar(8);
    i_name varchar(10) const;
    i_number int(10) const;
  end-pi;

  dcl-s l_g int(10);

  l_g = OutGroupNumber(i_name:i_number);
  if l_g = 0 or g_gAct(l_g) = 'U';
    return '';      // an update uses FILE_REC of the I specifications
  endif;
  return g_gFile(l_g);
end-proc;

// ------------------------------------------------------------------
// RV-62: the statements of the nth record of an EXCPT name for a DISK file:
// 'FILE_OUT = *blanks', one %subst assignment for each field or constant,
// 'write FILE FILE_OUT' or 'delete FILE', the clear of the blank after fields,
// inside an if when the record has output indicators. Returns the number of
// statements, 0 with the reason when the record cannot be converted.
dcl-proc OutDiskStatements export;
  dcl-pi *n int(10);
    i_name varchar(10) const;
    i_number int(10) const;
    o_stmts varchar(250) dim(40);
    o_reason varchar(190);
  end-pi;

  dcl-s l_g int(10);

  o_reason = '';
  l_g = OutGroupNumber(i_name:i_number);
  if l_g = 0 or not g_gDisk(l_g);
    o_reason = 'No output record of a DISK file with this name';
    return 0;
  endif;
  return DiskBuild(l_g:o_stmts:o_reason);
end-proc;

// ------------------------------------------------------------------
dcl-proc DiskBuild;
  dcl-pi *n int(10);
    i_g int(10) const;
    o_stmts varchar(250) dim(40);
    o_reason varchar(190);
  end-pi;

  dcl-s l_f int(10);
  dcl-s l_count int(10) inz(0);
  dcl-s l_acc varchar(250) inz('');
  dcl-s l_one varchar(120);
  dcl-s l_ds varchar(12);
  dcl-s l_kind char(1);
  dcl-s l_len int(10);
  dcl-s l_dec int(10);
  dcl-s l_start int(10);
  dcl-s l_after varchar(120);
  dcl-s l_known ind;
  dcl-s l_cond varchar(200);
  dcl-s l_pb varchar(12);
  dcl-s l_digits int(10);

  o_reason = '';
  l_ds = g_gFile(i_g) + '_OUT';
  if g_gAct(i_g) = 'U';
    l_ds = g_gFile(i_g) + '_REC';
  endif;
  l_cond = g_gCond(i_g);

  if l_cond <> '';
    l_count += 1;
    o_stmts(l_count) = 'if ' + l_cond;
  endif;

  if g_gAct(i_g) = 'D';
    if g_gFields(i_g) > 0;
      o_reason = 'A DEL record has fields: not converted';
      return 0;
    endif;
    l_count += 1;
    o_stmts(l_count) = 'delete ' + g_gFile(i_g);
  else;
    // An update keeps the bytes of the record read that no field names.
    l_acc = '';
    if g_gAct(i_g) <> 'U';
      l_acc = l_ds + ' = *blanks';
    endif;
    for l_f = g_gFirst(i_g) to g_gFirst(i_g) + g_gFields(i_g) - 1;
      if g_fReason(l_f) <> '';
        o_reason = g_fReason(l_f);
        return 0;
      endif;
      if g_fCond(l_f) <> '';
        o_reason = 'Output indicators on a field of a DISK record are not '
                   + 'converted';
        return 0;
      endif;
      if g_fName(l_f) = '';
        // A constant ending at the end position.
        l_len = ConstLength(g_fConst(l_f));
        l_start = g_fEnd(l_f) - l_len + 1;
        l_one = '%subst(' + l_ds + ':' + %char(l_start) + ':' + %char(l_len)
                + ') = ' + g_fConst(l_f);
      else;
        if g_fSpecial(l_f) <> ' ';
          o_reason = 'PAGE, UDATE and *DATE in a DISK record are not converted';
          return 0;
        endif;
        if g_fEdit(l_f) <> ' ' or g_fConst(l_f) <> '';
          o_reason = 'Edit codes and edit words of the field ' + g_fName(l_f)
                     + ' are not converted for a DISK file';
          return 0;
        endif;
        l_known = FieldInfoAny(g_fName(l_f):l_kind:l_len:l_dec);
        if not l_known;
          o_reason = 'Field ' + g_fName(l_f) + ' has no known length and type '
                     + 'at this point (define it before the EXCPT)';
          return 0;
        endif;
        l_digits = l_len;
        l_start = g_fEnd(l_f) - l_len + 1;
        if g_fFmt(l_f) = 'P' or g_fFmt(l_f) = 'B';
          // Packed or binary output (RV-61): a work field in a data structure of
          // its own, moved into the record bytes.
          l_pb = 'IA_' + g_fFmt(l_f) + %char(l_f);
          select;
            when l_kind <> 'N';
              o_reason = 'Data format ' + g_fFmt(l_f) + ' of the character field '
                         + g_fName(l_f) + ' is not valid';
              return 0;
            when g_fFmt(l_f) = 'P';
              l_len = l_len / 2 + 1;
              CalcDeclare('dcl-ds ' + l_pb + 'D; ' + l_pb + ' packed('
                          + %char(l_digits) + ':' + %char(l_dec) + '); end-ds;');
            when l_dec > 0 or l_digits > 9;
              o_reason = 'Binary output of ' + g_fName(l_f) + ' with decimal '
                         + 'positions or more than 9 digits is not converted';
              return 0;
            when l_digits <= 4;
              l_len = 2;
              CalcDeclare('dcl-ds ' + l_pb + 'D; ' + l_pb + ' int(5); end-ds;');
            other;
              l_len = 4;
              CalcDeclare('dcl-ds ' + l_pb + 'D; ' + l_pb + ' int(10); end-ds;');
          endsl;
          l_start = g_fEnd(l_f) - l_len + 1;
          l_one = l_pb + ' = ' + g_fName(l_f) + '; %subst(' + l_ds + ':'
                  + %char(l_start) + ':' + %char(l_len) + ') = ' + l_pb + 'D';
        elseif l_kind = 'N';
          l_one = '%subst(' + l_ds + ':' + %char(l_start) + ':' + %char(l_len)
                  + ') = %editc(' + g_fName(l_f) + ':''X'')';
        else;
          l_one = '%subst(' + l_ds + ':' + %char(l_start) + ':' + %char(l_len)
                  + ') = ' + g_fName(l_f);
        endif;
      endif;
      if l_start < 1 or l_start + l_len - 1 > g_gRecLen(i_g);
        o_reason = 'A field of the record is outside the record length '
                   + %char(g_gRecLen(i_g));
        return 0;
      endif;
      if %len(l_acc) + %len(l_one) + 2 > 240;
        l_count += 1;
        o_stmts(l_count) = l_acc;
        l_acc = l_one;
      elseif l_acc = '';
        l_acc = l_one;
      else;
        l_acc += '; ' + l_one;
      endif;
      if l_count >= 34;
        o_reason = 'The record has too many fields for one EXCPT';
        return 0;
      endif;
    endfor;
    if l_acc <> '';
      l_count += 1;
      o_stmts(l_count) = l_acc;
    endif;
    l_after = GroupAfter(i_g);
    l_count += 1;
    if g_gAct(i_g) = 'U';
      o_stmts(l_count) = 'update ' + g_gFile(i_g) + ' ' + l_ds;
    else;
      o_stmts(l_count) = 'write ' + g_gFile(i_g) + ' ' + l_ds;
    endif;
    if l_after <> '';
      l_count += 1;
      o_stmts(l_count) = l_after;
    endif;
  endif;

  if l_cond <> '';
    l_count += 1;
    o_stmts(l_count) = 'endif';
  endif;
  return l_count;
end-proc;

// ------------------------------------------------------------------
// The report of a DISK record at the end of the conversion (RV-62).
dcl-proc DiskFinish;
  dcl-pi *n;
    i_g int(10) const;
  end-pi;

  dcl-s l_stmts varchar(250) dim(40);
  dcl-s l_reason varchar(190);
  dcl-s l_count int(10);
  dcl-s l_j int(10);

  l_count = DiskBuild(i_g:l_stmts:l_reason);
  if l_count = 0;
    g_gOk(i_g) = *off;
    RptItem(C_STS_REVIEW:SrcLineNo(g_gStart(i_g)):%trimr(%subst(
            SrcLine(g_gStart(i_g)):6:75))
            :'Output record of the DISK file ' + g_gFile(i_g) + ' is not '
            + 'converted: ' + l_reason + '; the EXCPT that writes it is reported '
            + 'separately');
    return;
  endif;
  RptItem(C_STS_ASSUMPTION:SrcLineNo(g_gStart(i_g)):%trimr(%subst(
          SrcLine(g_gStart(i_g)):6:75))
          :'Record of a DISK file written by the EXCPT with a data structure'
          + ' (fields placed by '
          + '%SUBST at their end positions, numeric fields as zoned digits '
          + 'with %EDITC code X; data format P and B through a work field)' + CycleNote(g_gType(i_g)) + '; not tested');
  for l_j = g_gStart(i_g) + 1 to g_gEnd(i_g);
    RptItem(C_STS_CONVERTED:SrcLineNo(l_j):%trimr(%subst(SrcLine(l_j):6:75)):'');
  endfor;
end-proc;

// ------------------------------------------------------------------
dcl-proc OutDdsLine export;
  dcl-pi *n varchar(80);
    i_index int(10) const;
  end-pi;

  if i_index < 1 or i_index > g_ddsCount;
    return '';
  endif;
  return g_dds(i_index);
end-proc;

// ------------------------------------------------------------------
dcl-proc PrinterNumber;
  dcl-pi *n int(10);
    i_file varchar(8) const;
  end-pi;

  dcl-s l_k int(10);

  for l_k = 1 to g_pCount;
    if g_pName(l_k) = i_file;
      return l_k;
    endif;
  endfor;
  return 0;
end-proc;

// ------------------------------------------------------------------
// The number of printer files that have DDS lines (after OutFinish).
dcl-proc OutDdsFileCount export;
  dcl-pi *n int(10);
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_count int(10) inz(0);

  for l_k = 1 to g_pCount;
    if OutDdsLineCount(l_k) > 0;
      l_count += 1;
    endif;
  endfor;
  return l_count;
end-proc;

// ------------------------------------------------------------------
// The name of the nth printer file with DDS lines.
dcl-proc OutDdsFileName export;
  dcl-pi *n varchar(8);
    i_number int(10) const;
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_count int(10) inz(0);

  for l_k = 1 to g_pCount;
    if OutDdsLineCount(l_k) > 0;
      l_count += 1;
      if l_count = i_number;
        return g_pName(l_k);
      endif;
    endif;
  endfor;
  return '';
end-proc;

// ------------------------------------------------------------------
// The number of DDS lines of a printer file, by its name.
dcl-proc OutDdsLineCount export;
  dcl-pi *n int(10);
    i_number int(10) const;
  end-pi;

  dcl-s l_k int(10);
  dcl-s l_count int(10) inz(0);

  for l_k = 1 to g_ddsCount;
    if g_ddsNo(l_k) = i_number;
      l_count += 1;
    endif;
  endfor;
  return l_count;
end-proc;

// ------------------------------------------------------------------
// The printer file (its position among those with DDS lines) of a DDS line.
dcl-proc OutDdsLineFile export;
  dcl-pi *n varchar(8);
    i_index int(10) const;
  end-pi;

  if i_index < 1 or i_index > g_ddsCount;
    return '';
  endif;
  return g_pName(g_ddsNo(i_index));
end-proc;

// ------------------------------------------------------------------
dcl-proc OutDdsFile export;
  dcl-pi *n varchar(8);
  end-pi;

  if g_ddsCount = 0;
    return '';
  endif;
  return OutDdsFileName(1);
end-proc;
