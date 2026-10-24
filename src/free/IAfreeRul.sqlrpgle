**FREE
// IAfreeRul - the rule tables of IACNVFREE: reads IACNVOPC, IACNVCMP,
// IACNVRES, IACNVIND, IACNVNAM, IACNVBIF and IACNVCFG once into arrays and
// answers the lookups of the converter. The tables come from the JSON files in
// rules/ (see rules/IACNVRULES.sql). Module of program IACNVFREE.
// Target release V7R3.

ctl-opt nomain option(*srcstmt:*nodebugio);

/copy qcpysrc,IAcnvSrvP
/copy qcpysrc,IAfreeRulP

dcl-c C_LOWER 'abcdefghijklmnopqrstuvwxyz';
dcl-c C_UPPER 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
dcl-c C_MAXOPC 150;
dcl-c C_MAXCMP 12;
dcl-c C_MAXRES 40;
dcl-c C_MAXIND 250;
dcl-c C_MAXNAM 40;
dcl-c C_MAXBIF 40;
dcl-c C_MAXCFG 40;

dcl-ds g_opc likeds(IAfreeOpc_t) dim(C_MAXOPC);
dcl-s g_opcCount int(10) inz(0);
dcl-s g_cmpXx char(2) dim(C_MAXCMP);
dcl-s g_cmpOperator varchar(2) dim(C_MAXCMP);
dcl-s g_cmpCount int(10) inz(0);
dcl-s g_resCode varchar(4) dim(C_MAXRES);
dcl-s g_resTest varchar(100) dim(C_MAXRES);
dcl-s g_resCount int(10) inz(0);
dcl-ds g_ind likeds(IAfreeInd_t) dim(C_MAXIND);
dcl-s g_indCount int(10) inz(0);
dcl-ds g_nam likeds(IAfreeNam_t) dim(C_MAXNAM);
dcl-s g_namCount int(10) inz(0);
dcl-s g_bifName varchar(20) dim(C_MAXBIF);
dcl-s g_bifSince varchar(4) dim(C_MAXBIF);
dcl-s g_bifCount int(10) inz(0);
dcl-s g_cfgKey varchar(30) dim(C_MAXCFG);
dcl-s g_cfgValue varchar(200) dim(C_MAXCFG);
dcl-s g_cfgCount int(10) inz(0);

// ------------------------------------------------------------------
dcl-proc Upper;
  dcl-pi *n varchar(30);
    i_text varchar(30) const;
  end-pi;

  return %xlate(C_LOWER:C_UPPER:i_text);
end-proc;

// ------------------------------------------------------------------
dcl-proc Fail;
  dcl-pi *n int(10);
    i_table varchar(10) const;
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  o_msgId = 'IAC0104';
  o_msgData = i_table + ' (SQLCODE ' + %char(sqlcode) + ')';
  return 1;
end-proc;

// ------------------------------------------------------------------
dcl-proc RulLoad export;
  dcl-pi *n int(10);
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  dcl-ds l_opc likeds(IAfreeOpc_t);
  dcl-ds l_ind likeds(IAfreeInd_t);
  dcl-ds l_nam likeds(IAfreeNam_t);
  dcl-s l_xx char(2);
  dcl-s l_operator varchar(2);
  dcl-s l_code varchar(4);
  dcl-s l_test varchar(100);
  dcl-s l_name varchar(20);
  dcl-s l_since varchar(4);
  dcl-s l_key varchar(30);
  dcl-s l_value varchar(200);

  g_opcCount = 0;
  g_cmpCount = 0;
  g_resCount = 0;
  g_indCount = 0;
  g_namCount = 0;
  g_bifCount = 0;
  g_cfgCount = 0;

  exec sql declare opcCursor cursor for
    select opcode, xx, kind, factor1, factor2, result, ind1, ind2, ind3,
           halfadjust, status, template, templatenof1, bifs, reason
      from IACNVOPC order by opcode;
  exec sql open opcCursor;
  if sqlcode < 0;
    return Fail('IACNVOPC':o_msgId:o_msgData);
  endif;
  dow *on;
    exec sql fetch opcCursor into :l_opc;
    if sqlcode < 0;
      exec sql close opcCursor;
      return Fail('IACNVOPC':o_msgId:o_msgData);
    endif;
    if sqlcode = 100 or g_opcCount >= C_MAXOPC;
      leave;
    endif;
    g_opcCount += 1;
    g_opc(g_opcCount) = l_opc;
  enddo;
  exec sql close opcCursor;

  exec sql declare cmpCursor cursor for
    select xx, operator from IACNVCMP order by xx;
  exec sql open cmpCursor;
  if sqlcode < 0;
    return Fail('IACNVCMP':o_msgId:o_msgData);
  endif;
  dow *on;
    exec sql fetch cmpCursor into :l_xx, :l_operator;
    if sqlcode < 0;
      exec sql close cmpCursor;
      return Fail('IACNVCMP':o_msgId:o_msgData);
    endif;
    if sqlcode = 100 or g_cmpCount >= C_MAXCMP;
      leave;
    endif;
    g_cmpCount += 1;
    g_cmpXx(g_cmpCount) = l_xx;
    g_cmpOperator(g_cmpCount) = l_operator;
  enddo;
  exec sql close cmpCursor;

  exec sql declare resCursor cursor for
    select code, test from IACNVRES order by code;
  exec sql open resCursor;
  if sqlcode < 0;
    return Fail('IACNVRES':o_msgId:o_msgData);
  endif;
  dow *on;
    exec sql fetch resCursor into :l_code, :l_test;
    if sqlcode < 0;
      exec sql close resCursor;
      return Fail('IACNVRES':o_msgId:o_msgData);
    endif;
    if sqlcode = 100 or g_resCount >= C_MAXRES;
      leave;
    endif;
    g_resCount += 1;
    g_resCode(g_resCount) = l_code;
    g_resTest(g_resCount) = l_test;
  enddo;
  exec sql close resCursor;

  exec sql declare indCursor cursor for
    select name, class, freeform, cycle, reason from IACNVIND order by name;
  exec sql open indCursor;
  if sqlcode < 0;
    return Fail('IACNVIND':o_msgId:o_msgData);
  endif;
  dow *on;
    exec sql fetch indCursor into :l_ind;
    if sqlcode < 0;
      exec sql close indCursor;
      return Fail('IACNVIND':o_msgId:o_msgData);
    endif;
    if sqlcode = 100 or g_indCount >= C_MAXIND;
      leave;
    endif;
    g_indCount += 1;
    g_ind(g_indCount) = l_ind;
  enddo;
  exec sql close indCursor;

  exec sql declare namCursor cursor for
    select name, freeform, kind, status, reason from IACNVNAM order by name;
  exec sql open namCursor;
  if sqlcode < 0;
    return Fail('IACNVNAM':o_msgId:o_msgData);
  endif;
  dow *on;
    exec sql fetch namCursor into :l_nam;
    if sqlcode < 0;
      exec sql close namCursor;
      return Fail('IACNVNAM':o_msgId:o_msgData);
    endif;
    if sqlcode = 100 or g_namCount >= C_MAXNAM;
      leave;
    endif;
    g_namCount += 1;
    g_nam(g_namCount) = l_nam;
  enddo;
  exec sql close namCursor;

  exec sql declare bifCursor cursor for
    select name, since from IACNVBIF order by name;
  exec sql open bifCursor;
  if sqlcode < 0;
    return Fail('IACNVBIF':o_msgId:o_msgData);
  endif;
  dow *on;
    exec sql fetch bifCursor into :l_name, :l_since;
    if sqlcode < 0;
      exec sql close bifCursor;
      return Fail('IACNVBIF':o_msgId:o_msgData);
    endif;
    if sqlcode = 100 or g_bifCount >= C_MAXBIF;
      leave;
    endif;
    g_bifCount += 1;
    g_bifName(g_bifCount) = l_name;
    g_bifSince(g_bifCount) = l_since;
  enddo;
  exec sql close bifCursor;

  exec sql declare cfgCursor cursor for
    select cfgkey, cfgvalue from IACNVCFG order by cfgkey;
  exec sql open cfgCursor;
  if sqlcode < 0;
    return Fail('IACNVCFG':o_msgId:o_msgData);
  endif;
  dow *on;
    exec sql fetch cfgCursor into :l_key, :l_value;
    if sqlcode < 0;
      exec sql close cfgCursor;
      return Fail('IACNVCFG':o_msgId:o_msgData);
    endif;
    if sqlcode = 100 or g_cfgCount >= C_MAXCFG;
      leave;
    endif;
    g_cfgCount += 1;
    g_cfgKey(g_cfgCount) = l_key;
    g_cfgValue(g_cfgCount) = l_value;
  enddo;
  exec sql close cfgCursor;

  if g_opcCount = 0 or g_indCount = 0;
    o_msgId = 'IAC0104';
    o_msgData = 'The tables are empty: run rules/IACNVRULES.sql';
    return 1;
  endif;
  return 0;
end-proc;

// ------------------------------------------------------------------
dcl-proc FindOpcodeRow;
  dcl-pi *n int(10);
    i_name varchar(10) const;
    i_xx char(1) const;
  end-pi;

  dcl-s l_index int(10);

  for l_index = 1 to g_opcCount;
    if g_opc(l_index).opcode = i_name and g_opc(l_index).xx = i_xx;
      return l_index;
    endif;
  endfor;
  return 0;
end-proc;

// ------------------------------------------------------------------
dcl-proc RulOpcode export;
  dcl-pi *n ind;
    i_name varchar(10) const;
    o_rule likeds(IAfreeOpc_t);
    o_xx char(2);
  end-pi;

  dcl-s l_name varchar(10);
  dcl-s l_base varchar(10);
  dcl-s l_index int(10);

  o_xx = '';
  l_name = %trim(Upper(i_name));
  l_index = FindOpcodeRow(l_name:'N');
  if l_index > 0;
    o_rule = g_opc(l_index);
    return *on;
  endif;

  // CAS with a blank xx.
  if l_name = 'CAS';
    l_index = FindOpcodeRow('CAS':'Y');
    if l_index > 0;
      o_rule = g_opc(l_index);
      return *on;
    endif;
  endif;

  // IFxx, DOWxx, DOUxx, CASxx.
  if %len(l_name) >= 4;
    o_xx = %subst(l_name:%len(l_name) - 1:2);
    l_base = %subst(l_name:1:%len(l_name) - 2);
    if RulComparison(o_xx) <> '';
      l_index = FindOpcodeRow(l_base:'Y');
      if l_index > 0;
        o_rule = g_opc(l_index);
        return *on;
      endif;
    endif;
  endif;
  o_xx = '';
  return *off;
end-proc;

// ------------------------------------------------------------------
dcl-proc RulComparison export;
  dcl-pi *n varchar(2);
    i_xx char(2) const;
  end-pi;

  dcl-s l_index int(10);

  for l_index = 1 to g_cmpCount;
    if g_cmpXx(l_index) = i_xx;
      return g_cmpOperator(l_index);
    endif;
  endfor;
  return '';
end-proc;

// ------------------------------------------------------------------
dcl-proc RulResultTest export;
  dcl-pi *n varchar(100);
    i_code varchar(4) const;
  end-pi;

  dcl-s l_index int(10);

  for l_index = 1 to g_resCount;
    if g_resCode(l_index) = i_code;
      return g_resTest(l_index);
    endif;
  endfor;
  return '';
end-proc;

// ------------------------------------------------------------------
dcl-proc RulIndicator export;
  dcl-pi *n ind;
    i_name char(2) const;
    o_rule likeds(IAfreeInd_t);
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_name char(2);

  l_name = %xlate(C_LOWER:C_UPPER:i_name);
  for l_index = 1 to g_indCount;
    if g_ind(l_index).name = l_name;
      o_rule = g_ind(l_index);
      return *on;
    endif;
  endfor;
  return *off;
end-proc;

// ------------------------------------------------------------------
dcl-proc RulName export;
  dcl-pi *n ind;
    i_name varchar(10) const;
    o_rule likeds(IAfreeNam_t);
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_name varchar(10);

  l_name = %trim(Upper(i_name));
  for l_index = 1 to g_namCount;
    if g_nam(l_index).name = l_name;
      o_rule = g_nam(l_index);
      return *on;
    endif;
  endfor;
  return *off;
end-proc;

// ------------------------------------------------------------------
dcl-proc RulBifSince export;
  dcl-pi *n varchar(4);
    i_name varchar(20) const;
  end-pi;

  dcl-s l_index int(10);
  dcl-s l_name varchar(20);

  l_name = %trim(Upper(i_name));
  for l_index = 1 to g_bifCount;
    if g_bifName(l_index) = l_name;
      return g_bifSince(l_index);
    endif;
  endfor;
  return '';
end-proc;

// ------------------------------------------------------------------
dcl-proc RulConfig export;
  dcl-pi *n varchar(200);
    i_key varchar(30) const;
    i_default varchar(200) const;
  end-pi;

  dcl-s l_index int(10);

  for l_index = 1 to g_cfgCount;
    if g_cfgKey(l_index) = i_key;
      return g_cfgValue(l_index);
    endif;
  endfor;
  return i_default;
end-proc;
