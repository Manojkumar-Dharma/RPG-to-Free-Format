**FREE
// IAcnvVal - ValidateIO: validation and resolution of the common
// converter parameters (design document section 3).
// Module of service program IAcnvSrv.
//
// Order of checks (first failure wins):
//   1 mandatory parameters   2 types   3 location rules
//   4 existence              5 same-file guard   6 CCSID / REPLACE values

ctl-opt nomain option(*srcstmt:*nodebugio);

/copy qcpysrc,IAcnvSrvP

dcl-c C_LOWER 'abcdefghijklmnopqrstuvwxyz';
dcl-c C_UPPER 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

// ------------------------------------------------------------------
dcl-proc ToUpper10;
  dcl-pi *n char(10);
    i_text char(10) const;
  end-pi;

  return %xlate(C_LOWER:C_UPPER:i_text);
end-proc;

// ------------------------------------------------------------------
// Sets the message and returns 1 so callers can write: return Fail(...)
dcl-proc FailValidation;
  dcl-pi *n int(10);
    i_msgId char(7) const;
    i_msgData varchar(256) const;
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  o_msgId = i_msgId;
  o_msgData = i_msgData;
  return 1;
end-proc;

// ------------------------------------------------------------------
dcl-proc IsBlank;
  dcl-pi *n ind;
    i_text char(10) const;
  end-pi;

  return %len(%trim(i_text)) = 0;
end-proc;

// ------------------------------------------------------------------
// Directory with exactly one trailing slash.
dcl-proc NormDir;
  dcl-pi *n varchar(1024);
    i_directory varchar(1024) const;
  end-pi;

  dcl-s l_directory varchar(1024);

  l_directory = %trim(i_directory);
  if %len(l_directory) > 0 and %subst(l_directory:%len(l_directory):1) <> '/';
    l_directory += '/';
  endif;
  return l_directory;
end-proc;

// ------------------------------------------------------------------
// A member name used as an IFS file name must not climb out of the
// directory or contain blanks inside.
dcl-proc IsGoodFileBase;
  dcl-pi *n ind;
    i_name char(10) const;
  end-pi;

  dcl-s l_name varchar(10);

  l_name = %trim(i_name);
  if %len(l_name) = 0 or %scan('/':l_name) > 0 or %scan(' ':l_name) > 0;
    return *off;
  endif;
  return %subst(l_name:1:1) <> '.';
end-proc;

// ------------------------------------------------------------------
dcl-proc ValidateIO export;
  dcl-pi *n int(10);
    i_converter int(10) const;
    i_parm likeds(IAcnvParm_t) const;
    o_source likeds(IAcnvDesc_t);
    o_target likeds(IAcnvDesc_t);
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  dcl-ds l_source likeds(IAcnvDesc_t);
  dcl-ds l_target likeds(IAcnvDesc_t);
  dcl-s l_srcMbr char(10);
  dcl-s l_tgtMbr char(10);
  dcl-s l_tgtType char(10);
  dcl-s l_tgtLib char(10);
  dcl-s l_tgtFile char(10);
  dcl-s l_srcIfsGiven ind;
  dcl-s l_tgtIfsGiven ind;
  dcl-s l_tgtIfs varchar(1024);
  dcl-s l_directory varchar(1024);
  dcl-s l_name varchar(256);
  dcl-s l_first varchar(256);
  dcl-s l_list varchar(512);
  dcl-s l_count int(10);
  dcl-s l_replaceYes ind;

  clear l_source;
  clear l_target;
  clear o_source;
  clear o_target;
  o_msgId = *blanks;
  o_msgData = *blanks;

  // ---- 1 mandatory parameters -----------------------------------------
  if IsBlank(i_parm.srcMbr);
    return FailValidation('IAC0001':'SRCMBR':o_msgId:o_msgData);
  endif;
  if IsBlank(i_parm.srcType);
    return FailValidation('IAC0001':'SRCTYPE':o_msgId:o_msgData);
  endif;
  if IsBlank(i_parm.tgtMbr);
    return FailValidation('IAC0001':'TGTMBR':o_msgId:o_msgData);
  endif;

  // ---- 2 types ----------------------------------------------------------
  if not IsValidSrcType(i_converter:i_parm.srcType);
    return FailValidation('IAC0004':%trim(i_parm.srcType):o_msgId:o_msgData);
  endif;

  l_tgtType = i_parm.tgtType;
  if IsBlank(l_tgtType) or ToUpper10(l_tgtType) = '*DFT';
    l_tgtType = DefaultTgtType(i_converter);
  endif;
  if not IsValidTgtType(i_converter:l_tgtType);
    return FailValidation('IAC0005':%trim(l_tgtType):o_msgId:o_msgData);
  endif;

  l_source.type = ToUpper10(i_parm.srcType);
  l_target.type = ToUpper10(l_tgtType);

  // ---- 3 location rules ---------------------------------------------------
  l_srcIfsGiven = %len(%trim(i_parm.srcIfs)) > 0;
  l_tgtIfs = %trim(i_parm.tgtIfs);
  if %xlate(C_LOWER:C_UPPER:l_tgtIfs) = '*SRC';
    // *SRC: the target goes into the source directory
    if not l_srcIfsGiven;
      return FailValidation('IAC0019':'TGTIFS(*SRC)':o_msgId:o_msgData);
    endif;
    l_tgtIfs = %trim(i_parm.srcIfs);
  endif;
  l_tgtIfsGiven = %len(l_tgtIfs) > 0;

  // Source side
  if not IsBlank(i_parm.srcLib) and not IsBlank(i_parm.srcFile)
     and not l_srcIfsGiven;
    l_source.mode = C_MODE_MBR;
  elseif IsBlank(i_parm.srcLib) and IsBlank(i_parm.srcFile)
     and l_srcIfsGiven;
    l_source.mode = C_MODE_IFS;
  else;
    return FailValidation('IAC0002':'SRC':o_msgId:o_msgData);
  endif;

  // Target side (*SRCLIB is a given library when the source is a member)
  l_tgtLib = i_parm.tgtLib;
  if ToUpper10(l_tgtLib) = '*SRCLIB';
    if l_source.mode <> C_MODE_MBR;
      return FailValidation('IAC0015':'*SRCLIB':o_msgId:o_msgData);
    endif;
    // The library the source file is really in (resolves *LIBL / *CURLIB).
    l_tgtLib = ResolveLib(ToUpper10(i_parm.srcLib):ToUpper10(i_parm.srcFile));
  endif;
  l_tgtFile = i_parm.tgtFile;
  if ToUpper10(l_tgtFile) = '*SRCFILE';
    if l_source.mode <> C_MODE_MBR;
      return FailValidation('IAC0015':'*SRCFILE':o_msgId:o_msgData);
    endif;
    l_tgtFile = i_parm.srcFile;
  endif;

  if not IsBlank(l_tgtLib) and not IsBlank(l_tgtFile)
     and not l_tgtIfsGiven;
    l_target.mode = C_MODE_MBR;
  elseif IsBlank(l_tgtLib) and IsBlank(l_tgtFile)
     and l_tgtIfsGiven;
    l_target.mode = C_MODE_IFS;
  else;
    return FailValidation('IAC0003':'TGT':o_msgId:o_msgData);
  endif;

  // A member target needs a real library: its record width is read from it.
  if l_target.mode = C_MODE_MBR and %len(%trim(l_tgtLib)) > 0
     and %subst(%trim(l_tgtLib):1:1) = '*';
    return FailValidation('IAC0018':%trim(l_tgtLib):o_msgId:o_msgData);
  endif;

  // Member names (*SRCMBR copies the source member name)
  l_srcMbr = i_parm.srcMbr;
  l_tgtMbr = i_parm.tgtMbr;
  if ToUpper10(l_tgtMbr) = '*SRCMBR';
    l_tgtMbr = l_srcMbr;
  endif;

  // Names that will go into a command or a path must be well formed.
  if l_source.mode = C_MODE_MBR;
    l_source.lib = ToUpper10(i_parm.srcLib);
    l_source.file = ToUpper10(i_parm.srcFile);
    l_source.mbr = ToUpper10(l_srcMbr);
    if not IsSafeName(l_source.lib);
      return FailValidation('IAC0016':%trim(l_source.lib):o_msgId:o_msgData);
    endif;
    if not IsSafeName(l_source.file);
      return FailValidation('IAC0016':%trim(l_source.file):o_msgId:o_msgData);
    endif;
    if not IsSafeName(l_source.mbr);
      return FailValidation('IAC0016':%trim(l_source.mbr):o_msgId:o_msgData);
    endif;
  else;
    l_source.mbr = l_srcMbr;
    if not IsGoodFileBase(l_source.mbr);
      return FailValidation('IAC0016':%trim(l_source.mbr):o_msgId:o_msgData);
    endif;
  endif;

  if l_target.mode = C_MODE_MBR;
    l_target.lib = ToUpper10(l_tgtLib);
    l_target.file = ToUpper10(l_tgtFile);
    l_target.mbr = ToUpper10(l_tgtMbr);
    if not IsSafeName(l_target.lib);
      return FailValidation('IAC0016':%trim(l_target.lib):o_msgId:o_msgData);
    endif;
    if not IsSafeName(l_target.file);
      return FailValidation('IAC0016':%trim(l_target.file):o_msgId:o_msgData);
    endif;
    if not IsSafeName(l_target.mbr);
      return FailValidation('IAC0016':%trim(l_target.mbr):o_msgId:o_msgData);
    endif;
  else;
    l_target.mbr = l_tgtMbr;
    if not IsGoodFileBase(l_target.mbr);
      return FailValidation('IAC0016':%trim(l_target.mbr):o_msgId:o_msgData);
    endif;
  endif;

  // ---- 3b source and target must not be the same -------------------------------
  // Checked before anything else is looked at, so REPLACE(*YES) and
  // REPLACE(*NO) both give this message instead of touching the source.
  if l_source.mode = C_MODE_MBR and l_target.mode = C_MODE_MBR;
    if ResolveLib(l_source.lib:l_source.file) = l_target.lib
       and l_source.file = l_target.file and l_source.mbr = l_target.mbr;
      return FailValidation('IAC0012':%trim(l_target.lib) + '/' + %trim(l_target.file)
                  + '(' + %trim(l_target.mbr) + ')':o_msgId:o_msgData);
    endif;
  elseif l_source.mode = C_MODE_IFS and l_target.mode = C_MODE_IFS;
    if %xlate(C_LOWER:C_UPPER:NormDir(i_parm.srcIfs)
              + %trim(l_source.mbr) + '.' + %trim(l_source.type))
       = %xlate(C_LOWER:C_UPPER:NormDir(l_tgtIfs)
                + %trim(l_target.mbr) + '.' + %trim(l_target.type));
      return FailValidation('IAC0012':NormDir(i_parm.srcIfs) + %trim(l_source.mbr)
                  + '.' + %trim(l_source.type):o_msgId:o_msgData);
    endif;
  endif;

  // ---- 4 existence -----------------------------------------------------------
  l_replaceYes = ToUpper10(i_parm.replace) = '*YES';
  l_target.replaceOk = l_replaceYes;

  // Source
  if l_source.mode = C_MODE_MBR;
    if not ChkQsysObj(l_source.lib:' ':' ');
      return FailValidation('IAC0006':'library ' + %trim(l_source.lib)
                  :o_msgId:o_msgData);
    endif;
    if not ChkQsysObj(l_source.lib:l_source.file:' ');
      return FailValidation('IAC0006':'file ' + %trim(l_source.lib) + '/'
                  + %trim(l_source.file):o_msgId:o_msgData);
    endif;
    if not ChkQsysObj(l_source.lib:l_source.file:l_source.mbr);
      return FailValidation('IAC0006':'member ' + %trim(l_source.lib) + '/'
                  + %trim(l_source.file) + '(' + %trim(l_source.mbr) + ')'
                  :o_msgId:o_msgData);
    endif;
    l_source.exists = *on;
  else;
    l_directory = NormDir(i_parm.srcIfs);
    if not DirExists(l_directory);
      return FailValidation('IAC0007':'directory ' + l_directory:o_msgId:o_msgData);
    endif;
    l_name = %trim(i_parm.srcMbr) + '.' + %trim(i_parm.srcType);
    if IfsAccess(l_directory + l_name:4);
      l_first = l_name;
    else;
      l_count = FindIfsName(l_directory:l_name:l_first:l_list);
      if l_count = 0;
        return FailValidation('IAC0007':l_directory + l_name:o_msgId:o_msgData);
      elseif l_count > 1;
        return FailValidation('IAC0008':l_list:o_msgId:o_msgData);
      endif;
    endif;
    l_source.path = l_directory + l_first;
    if not IfsAccess(l_source.path:4);
      return FailValidation('IAC0007':l_source.path:o_msgId:o_msgData);
    endif;
    l_source.exists = *on;
  endif;

  // Target
  if l_target.mode = C_MODE_MBR;
    if not ChkQsysObj(l_target.lib:' ':' ');
      return FailValidation('IAC0009':'library ' + %trim(l_target.lib)
                  :o_msgId:o_msgData);
    endif;
    if not ChkQsysObj(l_target.lib:l_target.file:' ');
      return FailValidation('IAC0009':'file ' + %trim(l_target.lib) + '/'
                  + %trim(l_target.file):o_msgId:o_msgData);
    endif;
    l_target.exists = ChkQsysObj(l_target.lib:l_target.file:l_target.mbr);
    if l_target.exists and not l_replaceYes;
      return FailValidation('IAC0011':'member ' + %trim(l_target.lib) + '/'
                  + %trim(l_target.file) + '(' + %trim(l_target.mbr) + ')'
                  :o_msgId:o_msgData);
    endif;
  else;
    l_directory = NormDir(l_tgtIfs);
    if not DirExists(l_directory) or not IfsAccess(l_directory:2);
      return FailValidation('IAC0010':l_directory:o_msgId:o_msgData);
    endif;
    l_name = %trim(l_target.mbr) + '.' + %trim(l_tgtType);
    l_count = FindIfsName(l_directory:l_name:l_first:l_list);
    if l_count > 1;
      return FailValidation('IAC0008':l_list:o_msgId:o_msgData);
    endif;
    if l_count = 1;
      l_target.exists = *on;
      if not l_replaceYes;
        return FailValidation('IAC0011':l_directory + l_first:o_msgId:o_msgData);
      endif;
      l_name = l_first;      // keep the existing name's letter case
    endif;
    l_target.path = l_directory + l_name;
  endif;

  // ---- 5 same-file guard -------------------------------------------------------
  if l_source.mode = C_MODE_MBR and l_target.mode = C_MODE_MBR;
    if l_source.lib = l_target.lib and l_source.file = l_target.file
       and l_source.mbr = l_target.mbr;
      return FailValidation('IAC0012':%trim(l_source.lib) + '/' + %trim(l_source.file)
                  + '(' + %trim(l_source.mbr) + ')':o_msgId:o_msgData);
    endif;
  elseif l_source.mode = C_MODE_IFS and l_target.mode = C_MODE_IFS;
    if %xlate(C_LOWER:C_UPPER:l_source.path)
       = %xlate(C_LOWER:C_UPPER:l_target.path);
      return FailValidation('IAC0012':l_source.path:o_msgId:o_msgData);
    endif;
  endif;

  // ---- 6 CCSID and REPLACE values ---------------------------------------------------
  if i_parm.srcCcsid <> -1 and (i_parm.srcCcsid < 1
     or i_parm.srcCcsid > 65535);
    return FailValidation('IAC0013':%char(i_parm.srcCcsid):o_msgId:o_msgData);
  endif;
  // Explicit input CCSID for stream files needs raw read plus iconv, which
  // is a later piece of work. *DFT uses the file's own CCSID.
  if l_source.mode = C_MODE_IFS and i_parm.srcCcsid <> -1;
    return FailValidation('IAC0017':%char(i_parm.srcCcsid):o_msgId:o_msgData);
  endif;
  if i_parm.tgtCcsid <> -1 and (i_parm.tgtCcsid < 1
     or i_parm.tgtCcsid > 65535);
    return FailValidation('IAC0013':%char(i_parm.tgtCcsid):o_msgId:o_msgData);
  endif;
  if ToUpper10(i_parm.replace) <> '*NO' and ToUpper10(i_parm.replace) <> '*YES'
     and not IsBlank(i_parm.replace);
    return FailValidation('IAC0014':%trim(i_parm.replace):o_msgId:o_msgData);
  endif;

  l_source.ccsid = i_parm.srcCcsid;
  l_target.ccsid = i_parm.tgtCcsid;
  o_source = l_source;
  o_target = l_target;
  return 0;
end-proc;
