**FREE
// IAcnvTyp - source/target type tables for the converters.
// Module of service program IAcnvSrv. To support a new type, add it to
// the matching list constant below; nothing else changes.
// Lists are '|' delimited and upper case; comparison ignores case.

ctl-opt nomain option(*srcstmt:*nodebugio);

/copy qcpysrc,IAcnvSrvP

dcl-c C_SRC_OCL '|OCL36|';
dcl-c C_SRC_DSPF '|DSP36|DSP38|';
dcl-c C_SRC_FREE '|RPG36|RPG38|RPG3|RPG4|RPG|RPGLE|SQLRPGLE|';

dcl-c C_TGT_OCL '|CLLE|';
dcl-c C_TGT_DSPF '|DSPF|';
dcl-c C_TGT_FREE '|RPGLE|SQLRPGLE|';

dcl-c C_LOWER 'abcdefghijklmnopqrstuvwxyz';
dcl-c C_UPPER 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

// ------------------------------------------------------------------
dcl-proc InList;
  dcl-pi *n ind;
    i_list varchar(100) const;
    i_type char(10) const;
  end-pi;

  dcl-s l_key varchar(12);

  if %len(%trim(i_type)) = 0;
    return *off;
  endif;

  l_key = '|' + %trim(%xlate(C_LOWER:C_UPPER:i_type)) + '|';
  return %scan(l_key:i_list) > 0;
end-proc;

// ------------------------------------------------------------------
dcl-proc IsValidSrcType export;
  dcl-pi *n ind;
    i_converter int(10) const;
    i_type char(10) const;
  end-pi;

  select;
    when i_converter = C_CNV_OCL;
      return InList(C_SRC_OCL:i_type);
    when i_converter = C_CNV_DSPF;
      return InList(C_SRC_DSPF:i_type);
    when i_converter = C_CNV_FREE;
      return InList(C_SRC_FREE:i_type);
  endsl;
  return *off;
end-proc;

// ------------------------------------------------------------------
dcl-proc IsValidTgtType export;
  dcl-pi *n ind;
    i_converter int(10) const;
    i_type char(10) const;
  end-pi;

  select;
    when i_converter = C_CNV_OCL;
      return InList(C_TGT_OCL:i_type);
    when i_converter = C_CNV_DSPF;
      return InList(C_TGT_DSPF:i_type);
    when i_converter = C_CNV_FREE;
      return InList(C_TGT_FREE:i_type);
  endsl;
  return *off;
end-proc;

// ------------------------------------------------------------------
dcl-proc DefaultTgtType export;
  dcl-pi *n char(10);
    i_converter int(10) const;
  end-pi;

  select;
    when i_converter = C_CNV_OCL;
      return 'CLLE';
    when i_converter = C_CNV_DSPF;
      return 'DSPF';
    when i_converter = C_CNV_FREE;
      return 'RPGLE';
  endsl;
  return *blanks;
end-proc;
