**FREE
// IAcnvIfs - IFS stream file reader and writer (C stream APIs with text
// conversion). Module of service program IAcnvSrv.
//
// Reading with SRCCCSID(*DFT) uses O_TEXTDATA, so the data arrives in the job
// CCSID, converted from the file's own CCSID. With an explicit SRCCCSID the
// file is read as raw bytes, whatever its CCSID tag says, and every block is
// converted from that CCSID to the job CCSID with iconv (QtqIconvOpen); a
// character cut at the end of a block is kept for the next block.
// Writing creates the file with O_CCSID (TGTCCSID, or 1208 for *DFT) and
// converts from the job CCSID on write. An existing file that may be
// replaced is deleted first so that the new file gets the requested CCSID.
// One source and one target can be open at a time.

ctl-opt nomain option(*srcstmt:*nodebugio);

/copy qcpysrc,IAcnvSrvP

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
dcl-c C_RAWBLOCK 16000;          // bytes read at a time with an explicit CCSID
dcl-c C_MAXCARRY 8;              // most bytes of a cut character kept over

// iconv: a conversion descriptor is a structure passed and returned by value.
dcl-ds IAiconv_t qualified template;
  returnValue int(10);
  cd int(10) dim(12);
end-ds;

dcl-ds IAqtqCode_t qualified template;
  ccsid int(10);
  conversionAlt int(10);
  substitutionAlt int(10);
  shiftAlt int(10);
  inputLengthOp int(10);
  errorOption int(10);
  reserved char(8);
end-ds;

dcl-pr sysIconvOpen likeds(IAiconv_t) extproc('QtqIconvOpen');
  toCode likeds(IAqtqCode_t) const;
  fromCode likeds(IAqtqCode_t) const;
end-pr;

dcl-pr sysIconv int(10) extproc('iconv');
  cd likeds(IAiconv_t) value;
  inBuffer pointer;
  inBytesLeft uns(10);
  outBuffer pointer;
  outBytesLeft uns(10);
end-pr;

dcl-pr sysIconvClose int(10) extproc('iconv_close');
  cd likeds(IAiconv_t) value;
end-pr;

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
dcl-s g_srcConverts ind inz(*off);       // explicit SRCCCSID: raw read + iconv
dcl-ds g_srcCd likeds(IAiconv_t);
dcl-s g_rawBuffer char(32767);
dcl-s g_carry varchar(8) inz('');         // part of a character cut by a block
dcl-s g_convBuffer char(65535);
dcl-s g_tgtFd int(10) inz(-1);
dcl-s g_readBuffer char(32767);
dcl-s g_pending varchar(65535);
dcl-s g_endOfFile ind inz(*off);
dcl-s g_lineNo int(10) inz(0);
dcl-s g_errId char(7) inz(*blanks);
dcl-s g_errData char(256) inz(*blanks);

// ------------------------------------------------------------------
// Opens iconv from the given CCSID to the job CCSID (0). 0 when it worked.
dcl-proc OpenConverter;
  dcl-pi *n int(10);
    i_ccsid int(10) const;
  end-pi;

  dcl-ds l_to likeds(IAqtqCode_t) inz;
  dcl-ds l_from likeds(IAqtqCode_t) inz;

  l_to.ccsid = 0;
  l_from.ccsid = i_ccsid;
  g_srcCd = sysIconvOpen(l_to:l_from);
  if g_srcCd.returnValue = -1;
    return 1;
  endif;
  return 0;
end-proc;

// ------------------------------------------------------------------
// Converts the raw bytes just read (after the carried bytes) to the job CCSID
// and adds them to the pending text. 0 when it worked. A character cut at the
// end of the block stays in g_carry unless this is the last block.
dcl-proc ConvertRawBlock;
  dcl-pi *n int(10);
    i_bytes int(10) const;
    i_isLast ind const;
  end-pi;

  dcl-s l_input varchar(32775);
  dcl-s l_inPtr pointer;
  dcl-s l_outPtr pointer;
  dcl-s l_inLeft uns(10);
  dcl-s l_outLeft uns(10);
  dcl-s l_result int(10);
  dcl-s l_produced int(10);

  l_input = g_carry + %subst(g_rawBuffer:1:i_bytes);
  g_carry = '';
  if %len(l_input) = 0;
    return 0;
  endif;

  l_inPtr = %addr(l_input:*data);
  l_inLeft = %len(l_input);
  l_outPtr = %addr(g_convBuffer);
  l_outLeft = %size(g_convBuffer);
  l_result = sysIconv(g_srcCd:l_inPtr:l_inLeft:l_outPtr:l_outLeft);
  l_produced = %size(g_convBuffer) - l_outLeft;
  if l_produced > 0;
    if %len(g_pending) + l_produced > C_MAXPENDING;
      return 1;
    endif;
    g_pending += %subst(g_convBuffer:1:l_produced);
  endif;

  if l_result = -1 or l_inLeft > 0;
    // Only a short rest of a cut character may be kept for the next block.
    if i_isLast or l_inLeft > C_MAXCARRY;
      return 1;
    endif;
    g_carry = %subst(l_input:%len(l_input) - l_inLeft + 1:l_inLeft);
  endif;
  return 0;
end-proc;

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

  g_srcConverts = (i_desc.ccsid <> -1);
  if g_srcConverts;
    if OpenConverter(i_desc.ccsid) <> 0;
      o_msgId = 'IAC0017';
      o_msgData = %char(i_desc.ccsid);
      return 1;
    endif;
    g_srcFd = sysOpen(i_desc.path:C_O_RDONLY);
  else;
    g_srcFd = sysOpen(i_desc.path:C_O_RDONLY + C_O_TEXTDATA);
  endif;
  if g_srcFd < 0;
    if g_srcConverts;
      sysIconvClose(g_srcCd);
      g_srcConverts = *off;
    endif;
    o_msgId = 'IAC0101';
    o_msgData = 'Cannot open ' + i_desc.path;
    return 1;
  endif;
  g_carry = '';

  g_pending = '';
  g_endOfFile = *off;
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
    if %len(l_line) = 1;
      l_line = '';
    else;
      l_line = %subst(l_line:1:%len(l_line) - 1);
    endif;
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

  dcl-s l_lineFeedPos int(10);
  dcl-s l_bytesRead int(10);
  dcl-s l_line varchar(65535);

  o_text = '';
  o_lineNo = g_lineNo;

  dow *on;
    l_lineFeedPos = %scan(C_LF:g_pending);
    if l_lineFeedPos > 0;
      if l_lineFeedPos > 1;
        l_line = %subst(g_pending:1:l_lineFeedPos - 1);
      else;
        l_line = '';
      endif;
      if l_lineFeedPos >= %len(g_pending);
        g_pending = '';
      else;
        g_pending = %subst(g_pending:l_lineFeedPos + 1);
      endif;
      return Deliver(l_line:o_text:o_lineNo);
    endif;

    if g_endOfFile;
      if %len(g_pending) > 0;
        l_line = g_pending;
        g_pending = '';
        return Deliver(l_line:o_text:o_lineNo);
      endif;
      return *off;
    endif;

    if g_srcConverts;
      l_bytesRead = sysRead(g_srcFd:%addr(g_rawBuffer):C_RAWBLOCK);
      if l_bytesRead < 0;
        g_errId = 'IAC0101';
        g_errData = 'Read failed on the IFS source file';
        g_endOfFile = *on;
        return *off;
      endif;
      if ConvertRawBlock(%max(l_bytesRead:0):(l_bytesRead = 0)) <> 0;
        g_errId = 'IAC0101';
        g_errData = 'Cannot convert near line ' + %char(g_lineNo + 1)
                    + ' from the source CCSID';
        g_endOfFile = *on;
        g_pending = '';
        return *off;
      endif;
      if l_bytesRead = 0;
        g_endOfFile = *on;
      endif;
      iter;
    endif;

    l_bytesRead = sysRead(g_srcFd:%addr(g_readBuffer):%size(g_readBuffer));
    if l_bytesRead < 0;
      g_errId = 'IAC0101';
      g_errData = 'Read failed on the IFS source file';
      g_endOfFile = *on;
      return *off;
    elseif l_bytesRead = 0;
      g_endOfFile = *on;
    else;
      if %len(g_pending) + l_bytesRead > C_MAXPENDING;
        g_errId = 'IAC0101';
        g_errData = 'Line ' + %char(g_lineNo + 1) + ' is too long';
        g_endOfFile = *on;
        g_pending = '';
        return *off;
      endif;
      g_pending += %subst(g_readBuffer:1:l_bytesRead);
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
  if g_srcConverts;
    sysIconvClose(g_srcCd);
    g_srcConverts = *off;
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

  dcl-s l_outputLine varchar(520);
  dcl-s l_bytesWritten int(10);

  l_outputLine = %trimr(i_text) + C_LF;
  l_bytesWritten = sysWrite(g_tgtFd:%addr(l_outputLine:*data):%len(l_outputLine));
  if l_bytesWritten <> %len(l_outputLine);
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
