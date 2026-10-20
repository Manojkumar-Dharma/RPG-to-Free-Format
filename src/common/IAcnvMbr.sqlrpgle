**FREE
// IAcnvMbr - source member reader and writer (SQL aliases over the
// source physical file member). Module of service program IAcnvSrv.
//
// One source and one target can be open at a time. Aliases are created
// in QTEMP, so any record length works and the member is addressed
// directly (plain SQL cannot name a member of a multi-member file).
// Compile with CRTSQLRPGI ... OBJTYPE(*MODULE).

ctl-opt nomain option(*srcstmt:*nodebugio);

exec sql set option commit = *none, naming = *sys,
                    closqlcsr = *endactgrp, dlyprp = *yes;

/copy qcpysrc,IAcnvSrvP

dcl-pr QCmdExc extpgm('QCMDEXC');
  cmd char(3000) const options(*varsize);
  len packed(15:5) const;
end-pr;

dcl-s g_srcOpen ind inz(*off);
dcl-s g_tgtOpen ind inz(*off);
dcl-s g_tgtSeq packed(6:2) inz(0);
dcl-s g_tgtWidth int(10) inz(0);
dcl-s g_srcLine int(10) inz(0);

// ------------------------------------------------------------------
// Alias target text: unqualified for *LIBL / *CURLIB, else lib/file.
dcl-proc AliasFor;
  dcl-pi *n varchar(128);
    i_library char(10) const;
    i_file char(10) const;
    i_member char(10) const;
  end-pi;

  dcl-s l_forClause varchar(128);

  if %trim(i_library) = '*LIBL' or %trim(i_library) = '*CURLIB';
    l_forClause = '"' + %trim(i_file) + '"';
  else;
    l_forClause = '"' + %trim(i_library) + '"/"' + %trim(i_file) + '"';
  endif;
  return l_forClause + ' ("' + %trim(i_member) + '")';
end-proc;

// ------------------------------------------------------------------
dcl-proc SqlFail;
  dcl-pi *n int(10);
    i_msgId char(7) const;
    i_what varchar(100) const;
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  o_msgId = i_msgId;
  o_msgData = i_what + ' SQLCODE ' + %char(sqlcode) + ' SQLSTATE '
              + sqlstate;
  return 1;
end-proc;

// ------------------------------------------------------------------
dcl-proc MbrOpenSource export;
  dcl-pi *n int(10);
    i_desc likeds(IAcnvDesc_t) const;
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  dcl-s l_sqlText varchar(512);

  if g_srcOpen;
    MbrCloseSource();
  endif;

  exec sql drop alias qtemp/iacnvsrc;      // fine if it does not exist
  l_sqlText = 'create alias qtemp/iacnvsrc for '
          + AliasFor(i_desc.lib:i_desc.file:i_desc.mbr);
  exec sql prepare sAliasSrc from :l_sqlText;
  exec sql execute sAliasSrc;
  if sqlcode < 0;
    return SqlFail('IAC0101':'Create source alias':o_msgId:o_msgData);
  endif;

  exec sql declare cSrc cursor for
    select srcdta from qtemp/iacnvsrc a order by rrn(a);
  exec sql open cSrc;
  if sqlcode < 0;
    return SqlFail('IAC0101':'Open source cursor':o_msgId:o_msgData);
  endif;

  g_srcLine = 0;
  g_srcOpen = *on;
  return 0;
end-proc;

// ------------------------------------------------------------------
// *ON when a line was returned, *OFF at end of the member.
dcl-proc MbrReadLine export;
  dcl-pi *n ind;
    o_text varchar(512);
    o_lineNo int(10);
  end-pi;

  dcl-s l_data varchar(512);

  exec sql fetch cSrc into :l_data;
  if sqlcode <> 0;
    o_text = '';
    o_lineNo = g_srcLine;
    return *off;
  endif;

  g_srcLine += 1;
  o_text = %trimr(l_data);
  o_lineNo = g_srcLine;
  return *on;
end-proc;

// ------------------------------------------------------------------
dcl-proc MbrCloseSource export;
  dcl-pi *n;
  end-pi;

  if g_srcOpen;
    exec sql close cSrc;
    exec sql drop alias qtemp/iacnvsrc;
    g_srcOpen = *off;
  endif;
end-proc;

// ------------------------------------------------------------------
// Creates the member when missing (ADDPFM) or empties it when it exists
// and REPLACE(*YES) was validated (CLRPFM), then opens it for writing.
// o_width returns the data width of the target's SRCDTA column.
dcl-proc MbrOpenTarget export;
  dcl-pi *n int(10);
    i_desc likeds(IAcnvDesc_t) const;
    o_width int(10);
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  dcl-s l_command char(512);
  dcl-s l_sqlText varchar(512);
  dcl-s l_library varchar(10);
  dcl-s l_file varchar(10);
  dcl-s l_width int(10);

  if g_tgtOpen;
    MbrCloseTarget();
  endif;

  l_command = 'ADDPFM FILE(' + %trim(i_desc.lib) + '/' + %trim(i_desc.file)
        + ') MBR(' + %trim(i_desc.mbr) + ') SRCTYPE('
        + %trim(i_desc.type) + ')';
  if i_desc.exists;
    l_command = 'CLRPFM FILE(' + %trim(i_desc.lib) + '/'
          + %trim(i_desc.file) + ') MBR(' + %trim(i_desc.mbr) + ')';
  endif;

  monitor;
    QCmdExc(l_command:%len(%trimr(l_command)));
  on-error;
    o_msgId = 'IAC0102';
    o_msgData = 'Could not prepare target member: ' + %trimr(l_command);
    return 1;
  endmon;

  // Record width of the target source file.
  l_library = %trim(i_desc.lib);
  l_file = %trim(i_desc.file);
  exec sql select character_maximum_length into :l_width
    from qsys2/syscolumns
    where system_table_schema = :l_library
      and system_table_name = :l_file
      and system_column_name = 'SRCDTA';
  if sqlcode <> 0 or l_width < 1;
    o_msgId = 'IAC0102';
    o_msgData = 'Target is not a source file (no SRCDTA column): '
                + l_library + '/' + l_file;
    return 1;
  endif;

  exec sql drop alias qtemp/iacnvtgt;      // fine if it does not exist
  l_sqlText = 'create alias qtemp/iacnvtgt for '
          + AliasFor(i_desc.lib:i_desc.file:i_desc.mbr);
  exec sql prepare sAliasTgt from :l_sqlText;
  exec sql execute sAliasTgt;
  if sqlcode < 0;
    return SqlFail('IAC0102':'Create target alias':o_msgId:o_msgData);
  endif;

  exec sql prepare sInsert from
    'insert into qtemp/iacnvtgt (srcseq, srcdat, srcdta) values(?, 0, ?)';
  if sqlcode < 0;
    return SqlFail('IAC0102':'Prepare insert':o_msgId:o_msgData);
  endif;

  g_tgtSeq = 0;
  g_tgtWidth = l_width;
  g_tgtOpen = *on;
  o_width = l_width;
  return 0;
end-proc;

// ------------------------------------------------------------------
// The caller wraps lines to the width first; a longer line is an error.
dcl-proc MbrWriteLine export;
  dcl-pi *n int(10);
    i_text varchar(512) const;
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  dcl-s l_data varchar(512);

  if %len(i_text) > g_tgtWidth;
    o_msgId = 'IAC0102';
    o_msgData = 'Line is longer than the target width '
                + %char(g_tgtWidth);
    return 1;
  endif;

  g_tgtSeq += 1;
  l_data = i_text;
  exec sql execute sInsert using :g_tgtSeq, :l_data;
  if sqlcode < 0;
    return SqlFail('IAC0102':'Insert line':o_msgId:o_msgData);
  endif;
  return 0;
end-proc;

// ------------------------------------------------------------------
dcl-proc MbrCloseTarget export;
  dcl-pi *n;
  end-pi;

  if g_tgtOpen;
    exec sql drop alias qtemp/iacnvtgt;
    g_tgtOpen = *off;
  endif;
end-proc;

// ------------------------------------------------------------------
// Data width of the target source file's SRCDTA column, 0 when the file
// is not a source file or cannot be queried. Does not touch the member.
dcl-proc MbrTargetWidth export;
  dcl-pi *n int(10);
    i_desc likeds(IAcnvDesc_t) const;
  end-pi;

  dcl-s l_library varchar(10);
  dcl-s l_file varchar(10);
  dcl-s l_width int(10) inz(0);

  l_library = %trim(i_desc.lib);
  l_file = %trim(i_desc.file);
  exec sql select character_maximum_length into :l_width
    from qsys2/syscolumns
    where system_table_schema = :l_library
      and system_table_name = :l_file
      and system_column_name = 'SRCDTA';
  if sqlcode <> 0;
    return 0;
  endif;
  return l_width;
end-proc;
