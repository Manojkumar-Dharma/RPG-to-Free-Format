**FREE
// IAcnvIfs - IFS stream file reader and writer (C stream APIs with text
// conversion). Module of service program IAcnvSrv.
//
// Reading uses O_TEXTDATA, so the data arrives in the job CCSID, converted
// from the file's own CCSID (that is "*DFT" for SRCCCSID).
// Writing creates the file with O_CCSID (TGTCCSID, or 1208 for *DFT) and
// converts from the job CCSID on write. An existing file that may be
// replaced is deleted first so that the new file gets the requested CCSID.
// One source and one target can be open at a time.

ctl-opt nomain option(*srcstmt:*nodebugio);

/copy IAcnvSrvP

dcl-c C_O_RDONLY 1;
dcl-c C_O_WRONLY 2;
dcl-c C_O_CREAT 8;
dcl-c C_O_CCSID 32;
dcl-c C_O_TEXTDATA 16777216;
dcl-c C_MODE_644 420;            // octal 0644
dcl-c C_LF x'25';                // EBCDIC line feed after text conversion
dcl-c C_CR x'0D';
dcl-c C_MAXPENDING 65535;
dcl-c C_MAXLINE 512;

dcl-pr sysOpen int(10) extproc('open');
  path pointer value options(*string);
  oflag int(10) value;
  mode uns(10) value options(*nopass);
  codepage uns(10) value options(*nopass);
end-pr;

dcl-pr sysRead int(10) extproc('read');
  fildes int(10) value;
  buf pointer value;
  nbyte uns(10) value;
end-pr;

dcl-pr sysWrite int(10) extproc('write');
  fildes int(10) value;
  buf pointer value;
  nbyte uns(10) value;
end-pr;

dcl-pr sysClose int(10) extproc('close');
  fildes int(10) value;
end-pr;

dcl-pr sysUnlink int(10) extproc('unlink');
  path pointer value options(*string);
end-pr;

dcl-s g_srcFd int(10) inz(-1);
dcl-s g_tgtFd int(10) inz(-1);
dcl-s g_buf char(32767);
dcl-s g_pending varchar(65535);
dcl-s g_eof ind inz(*off);
dcl-s g_lineNo int(10) inz(0);
dcl-s g_errId char(7) inz(*blanks);
dcl-s g_errData char(256) inz(*blanks);

// ------------------------------------------------------------------
dcl-proc IfsOpenSource export;
  dcl-pi *n int(10);
    i_desc likeds(IAcnvDesc_t) const;
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  if g_srcFd >= 0;
    IfsCloseSource();
  endif;

  g_srcFd = sysOpen(i_desc.path:C_O_RDONLY + C_O_TEXTDATA);
  if g_srcFd < 0;
    o_msgId = 'IAC0101';
    o_msgData = 'Cannot open ' + i_desc.path;
    return 1;
  endif;

  g_pending = '';
  g_eof = *off;
  g_lineNo = 0;
  g_errId = *blanks;
  g_errData = *blanks;
  return 0;
end-proc;

// ------------------------------------------------------------------
// Hands one line back: removes a trailing CR, enforces the maximum width.
dcl-proc Deliver;
  dcl-pi *n ind;
    i_line varchar(65535) const;
    o_text varchar(512);
    o_lineNo int(10);
  end-pi;

  dcl-s l_line varchar(65535);

  l_line = i_line;
  if %len(l_line) > 0 and %subst(l_line:%len(l_line):1) = C_CR;
    l_line = %subst(l_line:1:%len(l_line) - 1);
  endif;

  g_lineNo += 1;
  if %len(l_line) > C_MAXLINE;
    g_errId = 'IAC0101';
    g_errData = 'Line ' + %char(g_lineNo) + ' is longer than '
                + %char(C_MAXLINE) + ' characters';
    o_text = '';
    o_lineNo = g_lineNo;
    return *off;
  endif;

  o_text = l_line;
  o_lineNo = g_lineNo;
  return *on;
end-proc;

// ------------------------------------------------------------------
// *ON when a line was returned. *OFF at end of file or on error; call
// IfsLastError afterwards to tell the two apart.
dcl-proc IfsReadLine export;
  dcl-pi *n ind;
    o_text varchar(512);
    o_lineNo int(10);
  end-pi;

  dcl-s l_pos int(10);
  dcl-s l_n int(10);
  dcl-s l_line varchar(65535);

  o_text = '';
  o_lineNo = g_lineNo;

  dow *on;
    l_pos = %scan(C_LF:g_pending);
    if l_pos > 0;
      l_line = %subst(g_pending:1:l_pos - 1);
      if l_pos >= %len(g_pending);
        g_pending = '';
      else;
        g_pending = %subst(g_pending:l_pos + 1);
      endif;
      return Deliver(l_line:o_text:o_lineNo);
    endif;

    if g_eof;
      if %len(g_pending) > 0;
        l_line = g_pending;
        g_pending = '';
        return Deliver(l_line:o_text:o_lineNo);
      endif;
      return *off;
    endif;

    l_n = sysRead(g_srcFd:%addr(g_buf):%size(g_buf));
    if l_n < 0;
      g_errId = 'IAC0101';
      g_errData = 'Read failed on the IFS source file';
      g_eof = *on;
      return *off;
    elseif l_n = 0;
      g_eof = *on;
    else;
      if %len(g_pending) + l_n > C_MAXPENDING;
        g_errId = 'IAC0101';
        g_errData = 'Line ' + %char(g_lineNo + 1) + ' is too long';
        g_eof = *on;
        g_pending = '';
        return *off;
      endif;
      g_pending += %subst(g_buf:1:l_n);
    endif;
  enddo;

  return *off;
end-proc;

// ------------------------------------------------------------------
// *ON when the last read stopped on an error (not on plain end of file).
dcl-proc IfsLastError export;
  dcl-pi *n ind;
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  o_msgId = g_errId;
  o_msgData = g_errData;
  return g_errId <> *blanks;
end-proc;

// ------------------------------------------------------------------
dcl-proc IfsCloseSource export;
  dcl-pi *n;
  end-pi;

  if g_srcFd >= 0;
    sysClose(g_srcFd);
    g_srcFd = -1;
  endif;
end-proc;

// ------------------------------------------------------------------
dcl-proc IfsOpenTarget export;
  dcl-pi *n int(10);
    i_desc likeds(IAcnvDesc_t) const;
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  dcl-s l_ccsid uns(10);

  if g_tgtFd >= 0;
    IfsCloseTarget();
  endif;

  if i_desc.exists;
    if sysUnlink(i_desc.path) < 0;
      o_msgId = 'IAC0102';
      o_msgData = 'Cannot replace ' + i_desc.path;
      return 1;
    endif;
  endif;

  l_ccsid = 1208;
  if i_desc.ccsid <> -1;
    l_ccsid = i_desc.ccsid;
  endif;

  g_tgtFd = sysOpen(i_desc.path
                 :C_O_WRONLY + C_O_CREAT + C_O_CCSID + C_O_TEXTDATA
                 :C_MODE_644:l_ccsid);
  if g_tgtFd < 0;
    o_msgId = 'IAC0102';
    o_msgData = 'Cannot create ' + i_desc.path;
    return 1;
  endif;
  return 0;
end-proc;

// ------------------------------------------------------------------
dcl-proc IfsWriteLine export;
  dcl-pi *n int(10);
    i_text varchar(512) const;
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  dcl-s l_out varchar(520);
  dcl-s l_n int(10);

  l_out = %trimr(i_text) + C_LF;
  l_n = sysWrite(g_tgtFd:%addr(l_out:*data):%len(l_out));
  if l_n <> %len(l_out);
    o_msgId = 'IAC0102';
    o_msgData = 'Write failed on the IFS target file';
    return 1;
  endif;
  return 0;
end-proc;

// ------------------------------------------------------------------
dcl-proc IfsCloseTarget export;
  dcl-pi *n;
  end-pi;

  if g_tgtFd >= 0;
    sysClose(g_tgtFd);
    g_tgtFd = -1;
  endif;
end-proc;
