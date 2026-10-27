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

dcl-pr CalcFieldInfo ind;
  i_name varchar(10) const;
  o_kind char(1);
  o_length int(10);
  o_decimals int(10);
end-pr;

// Output records (a record line with its field lines).
dcl-s g_gFile varchar(8) dim(C_MAXGRP);
dcl-s g_gName varchar(6) dim(C_MAXGRP);
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
dcl-s g_gCount int(10) inz(0);
// Output fields and constants.
dcl-s g_fName varchar(10) dim(C_MAXFLD);
dcl-s g_fEdit char(1) dim(C_MAXFLD);
dcl-s g_fEnd int(10) dim(C_MAXFLD);
dcl-s g_fConst varchar(30) dim(C_MAXFLD);
dcl-s g_fCond varchar(30) dim(C_MAXFLD);
dcl-s g_fReason varchar(120) dim(C_MAXFLD);
dcl-s g_fBlank ind dim(C_MAXFLD);           // blank after (column 39)
dcl-s g_fSpecial char(1) dim(C_MAXFLD);     // P PAGE, J UDATE, S *DATE
dcl-s g_fCount int(10) inz(0);
// The DDS source.
dcl-s g_dds varchar(80) dim(C_MAXDDS);
dcl-s g_ddsCount int(10) inz(0);
dcl-s g_ddsFile varchar(8) inz('');
dcl-s g_built ind inz(*off);

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
  g_ddsFile = '';
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
// RPG cycle.
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
// record (RV-60): L1-L9 and LR as *INLn, 1P (heading and detail only) as IA_FIRST,
// the first record of the cycle skeleton. '' for anything else.
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
    l_line = SrcLine(l_index);
    if not IsOLine(l_line);
      iter;
    endif;

    // ---- a field line: columns 7-22 blank ----
    if Cols(l_line:7:22) = '';
      if l_g = 0 or g_fCount >= C_MAXFLD;
        iter;
      endif;
      g_fCount += 1;
      g_fName(g_fCount) = Up(Cols(l_line:32:37));
      g_fEdit(g_fCount) = Up(%subst(l_line:38:1));
      g_fConst(g_fCount) = Cols(l_line:45:70);
      g_fReason(g_fCount) = '';
      g_fEnd(g_fCount) = 0;
      g_fBlank(g_fCount) = *off;
      g_fSpecial(g_fCount) = ' ';
      l_end = Cols(l_line:40:43);
      l_fmt = %subst(Up(%subst(l_line:44:1) + ' '):1:1);
      l_cond = IndicatorCond(l_line:l_reason:' ');
      g_fCond(g_fCount) = l_cond;
      l_relative = (%subst(l_end:1:1) = '+');
      l_digits = l_end;
      if l_relative;
        l_digits = %trim(%subst(l_end:2));
      endif;
      select;
        when g_fName(g_fCount) = 'PAGE';
          g_fSpecial(g_fCount) = 'P';
        when g_fName(g_fCount) = 'UDATE';
          g_fSpecial(g_fCount) = 'J';
        when g_fName(g_fCount) = '*DATE';
          g_fSpecial(g_fCount) = 'S';
      endsl;
      select;
        when l_reason <> '';
          g_fReason(g_fCount) = l_reason;
        when l_digits = '' or %check(C_DIGITS:l_digits) > 0;
          g_fReason(g_fCount) = 'End position (columns 40-43) ' + l_end
                                + ' is not a plain or relative position';
        when l_relative and (g_gFields(l_g) = 0 or g_fEnd(g_fCount - 1) = 0);
          g_fReason(g_fCount) = 'A relative end position needs an end position '
                                + 'before it in the same record';
        when l_fmt <> ' ';
          g_fReason(g_fCount) = 'Data format ' + l_fmt + ' (column 44) is not '
                                + 'converted';
        when Up(%subst(l_line:39:1)) <> ' ' and Up(%subst(l_line:39:1)) <> 'B';
          g_fReason(g_fCount) = 'Entry ' + %subst(l_line:39:1) + ' in column 39 '
                                + 'is not valid';
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
    if Cols(l_line:7:14) <> '';
      l_file = Up(Cols(l_line:7:14));
    endif;
    l_type = %subst(Up(%subst(l_line:15:1) + ' '):1:1);
    g_gFile(l_g) = l_file;
    g_gName(l_g) = Up(Cols(l_line:32:37));
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
    select;
      when l_reason <> '';
        g_gReason(l_g) = l_reason;
      when l_type <> 'E' and l_type <> 'H' and l_type <> 'D' and l_type <> 'T';
        g_gReason(l_g) = 'Record type ' + l_type + ' (column 15) is not valid';
      when l_type <> 'E' and not l_cycle;
        g_gReason(l_g) = 'Heading, detail and total records are written by the '
                         + 'RPG cycle skeleton (one program described primary '
                         + 'file): not converted without it';
      when Cols(l_line:16:18) <> '';
        g_gReason(l_g) = 'Entry in columns 16-18 (ADD, DEL, fetch overflow, '
                         + 'release) is not converted';
      when l_file = '' or %len(l_file) > 8;
        g_gReason(l_g) = 'The file name of the output record is missing or too long';
      when not FileInfo(l_file:l_device:l_ftype:l_recDs:l_keyed)
           or l_device <> 'P';
        g_gReason(l_g) = 'File ' + l_file + ' is not a PRINTER file declared by a '
                         + 'converted file description';
      when g_ddsFile <> '' and g_ddsFile <> l_file;
        g_gReason(l_g) = 'A second printer file in one source: the printer DDS '
                         + 'is made for ' + g_ddsFile + ' only';
    endsl;

    // Spacing and skipping.
    l_sb = Cols(l_line:17:17);
    l_sa = Cols(l_line:18:18);
    l_kb = SkipNumber(Cols(l_line:19:20));
    l_ka = SkipNumber(Cols(l_line:21:22));
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
    if g_gReason(l_g) = '';
      g_ddsFile = l_file;
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
    i_name varchar(6) const;
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
    i_name varchar(6) const;
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
    i_name varchar(6) const;
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
    i_name varchar(6) const;
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
    i_name varchar(6) const;
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

  OutBuild();
  g_ddsCount = 0;
  for l_g = 1 to g_gCount;
    if not g_gOk(l_g);
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
            other;
              l_known = CalcFieldInfo(g_fName(l_f):l_kind:l_len:l_dec);
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
          endif;
      endsl;
      if l_reason = '' and l_start < 1;
        l_reason = 'Field ' + g_fName(l_f) + ' starts before position 1';
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

    if g_ddsCount = 0;
      AddDds('     A* Printer file ' + g_ddsFile + ': generated by IACNVFREE from '
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
            SrcLine(g_gStart(l_g)):6:75)):'Record format ' + g_gFmt(l_g)
            + ' of the printer file DDS (comments at the end of the converted '
            + 'source); the DDS is not tested: check line and position entries'
            + CycleNote(g_gType(l_g)));
    for l_j = g_gStart(l_g) + 1 to g_gEnd(l_g);
      RptItem(C_STS_CONVERTED:SrcLineNo(l_j):%trimr(%subst(SrcLine(l_j):6:75)):'');
    endfor;
  endfor;
  return g_ddsCount;
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
dcl-proc OutDdsFile export;
  dcl-pi *n varchar(8);
  end-pi;

  if g_ddsCount = 0;
    return '';
  endif;
  return g_ddsFile;
end-proc;
