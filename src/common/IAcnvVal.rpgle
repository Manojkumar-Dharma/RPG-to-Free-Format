**FREE
// IAcnvVal - ValidateIO: validation and resolution of the common
// converter parameters (design document section 3).
// Module of service program IAcnvSrv.
//
// Order of checks (first failure wins):
//   1 mandatory parameters   2 types   3 location rules
//   4 existence              5 same-file guard   6 CCSID / REPLACE values

ctl-opt nomain option(*srcstmt:*nodebugio);

/copy 'IAcnvSrvP.rpgleinc'

dcl-c C_LOWER 'abcdefghijklmnopqrstuvwxyz';
dcl-c C_UPPER 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

// ------------------------------------------------------------------
dcl-proc Up;
  dcl-pi *n char(10);
    i_text char(10) const;
  end-pi;

  return %xlate(C_LOWER:C_UPPER:i_text);
end-proc;

// ------------------------------------------------------------------
// Sets the message and returns 1 so callers can write: return Fail(...)
dcl-proc Fail;
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
    i_dir varchar(1024) const;
  end-pi;

  dcl-s l_dir varchar(1024);

  l_dir = %trim(i_dir);
  if %len(l_dir) > 0 and %subst(l_dir:%len(l_dir):1) <> '/';
    l_dir += '/';
  endif;
  return l_dir;
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
    o_src likeds(IAcnvDesc_t);
    o_tgt likeds(IAcnvDesc_t);
    o_msgId char(7);
    o_msgData char(256);
  end-pi;

  dcl-ds l_src likeds(IAcnvDesc_t);
  dcl-ds l_tgt likeds(IAcnvDesc_t);
  dcl-s l_srcMbr char(10);
  dcl-s l_tgtMbr char(10);
  dcl-s l_tgtType char(10);
  dcl-s l_tgtLib char(10);
  dcl-s l_srcIfsGiven ind;
  dcl-s l_tgtIfsGiven ind;
  dcl-s l_dir varchar(1024);
  dcl-s l_name varchar(256);
  dcl-s l_first varchar(256);
  dcl-s l_list varchar(512);
  dcl-s l_count int(10);
  dcl-s l_replaceYes ind;

  clear l_src;
  clear l_tgt;
  clear o_src;
  clear o_tgt;
  o_msgId = *blanks;
  o_msgData = *blanks;

  // ---- 1 mandatory parameters -----------------------------------------
  if IsBlank(i_parm.srcMbr);
    return Fail('IAC0001':'SRCMBR':o_msgId:o_msgData);
  endif;
  if IsBlank(i_parm.srcType);
    return Fail('IAC0001':'SRCTYPE':o_msgId:o_msgData);
  endif;
  if IsBlank(i_parm.tgtMbr);
    return Fail('IAC0001':'TGTMBR':o_msgId:o_msgData);
  endif;

  // ---- 2 types ----------------------------------------------------------
  if not IsValidSrcType(i_converter:i_parm.srcType);
    return Fail('IAC0004':%trim(i_parm.srcType):o_msgId:o_msgData);
  endif;

  l_tgtType = i_parm.tgtType;
  if IsBlank(l_tgtType) or Up(l_tgtType) = '*DFT';
    l_tgtType = DefaultTgtType(i_converter);
  endif;
  if not IsValidTgtType(i_converter:l_tgtType);
    return Fail('IAC0005':%trim(l_tgtType):o_msgId:o_msgData);
  endif;

  l_src.type = Up(i_parm.srcType);
  l_tgt.type = Up(l_tgtType);

  // ---- 3 location rules ---------------------------------------------------
  l_srcIfsGiven = %len(%trim(i_parm.srcIfs)) > 0;
  l_tgtIfsGiven = %len(%trim(i_parm.tgtIfs)) > 0;

  // Source side
  if not IsBlank(i_parm.srcLib) and not IsBlank(i_parm.srcFile)
     and not l_srcIfsGiven;
    l_src.mode = C_MODE_MBR;
  elseif IsBlank(i_parm.srcLib) and IsBlank(i_parm.srcFile)
     and l_srcIfsGiven;
    l_src.mode = C_MODE_IFS;
  else;
    return Fail('IAC0002':'SRC':o_msgId:o_msgData);
  endif;

  // Target side (*SRCLIB is a given library when the source is a member)
  l_tgtLib = i_parm.tgtLib;
  if Up(l_tgtLib) = '*SRCLIB';
    if l_src.mode <> C_MODE_MBR;
      return Fail('IAC0015':'*SRCLIB':o_msgId:o_msgData);
    endif;
    l_tgtLib = i_parm.srcLib;
  endif;

  if not IsBlank(l_tgtLib) and not IsBlank(i_parm.tgtFile)
     and not l_tgtIfsGiven;
    l_tgt.mode = C_MODE_MBR;
  elseif IsBlank(l_tgtLib) and IsBlank(i_parm.tgtFile)
     and l_tgtIfsGiven;
    l_tgt.mode = C_MODE_IFS;
  else;
    return Fail('IAC0003':'TGT':o_msgId:o_msgData);
  endif;

  // Member names (*SRCMBR copies the source member name)
  l_srcMbr = i_parm.srcMbr;
  l_tgtMbr = i_parm.tgtMbr;
  if Up(l_tgtMbr) = '*SRCMBR';
    l_tgtMbr = l_srcMbr;
  endif;

  // Names that will go into a command or a path must be well formed.
  if l_src.mode = C_MODE_MBR;
    l_src.lib = Up(i_parm.srcLib);
    l_src.file = Up(i_parm.srcFile);
    l_src.mbr = Up(l_srcMbr);
    if not IsSafeName(l_src.lib);
      return Fail('IAC0016':%trim(l_src.lib):o_msgId:o_msgData);
    endif;
    if not IsSafeName(l_src.file);
      return Fail('IAC0016':%trim(l_src.file):o_msgId:o_msgData);
    endif;
    if not IsSafeName(l_src.mbr);
      return Fail('IAC0016':%trim(l_src.mbr):o_msgId:o_msgData);
    endif;
  else;
    l_src.mbr = l_srcMbr;
    if not IsGoodFileBase(l_src.mbr);
      return Fail('IAC0016':%trim(l_src.mbr):o_msgId:o_msgData);
    endif;
  endif;

  if l_tgt.mode = C_MODE_MBR;
    l_tgt.lib = Up(l_tgtLib);
    l_tgt.file = Up(i_parm.tgtFile);
    l_tgt.mbr = Up(l_tgtMbr);
    if not IsSafeName(l_tgt.lib);
      return Fail('IAC0016':%trim(l_tgt.lib):o_msgId:o_msgData);
    endif;
    if not IsSafeName(l_tgt.file);
      return Fail('IAC0016':%trim(l_tgt.file):o_msgId:o_msgData);
    endif;
    if not IsSafeName(l_tgt.mbr);
      return Fail('IAC0016':%trim(l_tgt.mbr):o_msgId:o_msgData);
    endif;
  else;
    l_tgt.mbr = l_tgtMbr;
    if not IsGoodFileBase(l_tgt.mbr);
      return Fail('IAC0016':%trim(l_tgt.mbr):o_msgId:o_msgData);
    endif;
  endif;

  // ---- 4 existence -----------------------------------------------------------
  l_replaceYes = Up(i_parm.replace) = '*YES';
  l_tgt.replaceOk = l_replaceYes;

  // Source
  if l_src.mode = C_MODE_MBR;
    if not ChkQsysObj(l_src.lib:' ':' ');
      return Fail('IAC0006':'library ' + %trim(l_src.lib)
                  :o_msgId:o_msgData);
    endif;
    if not ChkQsysObj(l_src.lib:l_src.file:' ');
      return Fail('IAC0006':'file ' + %trim(l_src.lib) + '/'
                  + %trim(l_src.file):o_msgId:o_msgData);
    endif;
    if not ChkQsysObj(l_src.lib:l_src.file:l_src.mbr);
      return Fail('IAC0006':'member ' + %trim(l_src.lib) + '/'
                  + %trim(l_src.file) + '(' + %trim(l_src.mbr) + ')'
                  :o_msgId:o_msgData);
    endif;
    l_src.exists = *on;
  else;
    l_dir = NormDir(i_parm.srcIfs);
    if not DirExists(l_dir);
      return Fail('IAC0007':'directory ' + l_dir:o_msgId:o_msgData);
    endif;
    l_name = %trim(i_parm.srcMbr) + '.' + %trim(i_parm.srcType);
    if IfsAccess(l_dir + l_name:4);
      l_first = l_name;
    else;
      l_count = FindIfsName(l_dir:l_name:l_first:l_list);
      if l_count = 0;
        return Fail('IAC0007':l_dir + l_name:o_msgId:o_msgData);
      elseif l_count > 1;
        return Fail('IAC0008':l_list:o_msgId:o_msgData);
      endif;
    endif;
    l_src.path = l_dir + l_first;
    if not IfsAccess(l_src.path:4);
      return Fail('IAC0007':l_src.path:o_msgId:o_msgData);
    endif;
    l_src.exists = *on;
  endif;

  // Target
  if l_tgt.mode = C_MODE_MBR;
    if not ChkQsysObj(l_tgt.lib:' ':' ');
      return Fail('IAC0009':'library ' + %trim(l_tgt.lib)
                  :o_msgId:o_msgData);
    endif;
    if not ChkQsysObj(l_tgt.lib:l_tgt.file:' ');
      return Fail('IAC0009':'file ' + %trim(l_tgt.lib) + '/'
                  + %trim(l_tgt.file):o_msgId:o_msgData);
    endif;
    l_tgt.exists = ChkQsysObj(l_tgt.lib:l_tgt.file:l_tgt.mbr);
    if l_tgt.exists and not l_replaceYes;
      return Fail('IAC0011':'member ' + %trim(l_tgt.lib) + '/'
                  + %trim(l_tgt.file) + '(' + %trim(l_tgt.mbr) + ')'
                  :o_msgId:o_msgData);
    endif;
  else;
    l_dir = NormDir(i_parm.tgtIfs);
    if not DirExists(l_dir) or not IfsAccess(l_dir:2);
      return Fail('IAC0010':l_dir:o_msgId:o_msgData);
    endif;
    l_name = %trim(l_tgt.mbr) + '.' + %trim(l_tgtType);
    l_count = FindIfsName(l_dir:l_name:l_first:l_list);
    if l_count > 1;
      return Fail('IAC0008':l_list:o_msgId:o_msgData);
    endif;
    if l_count = 1;
      l_tgt.exists = *on;
      if not l_replaceYes;
        return Fail('IAC0011':l_dir + l_first:o_msgId:o_msgData);
      endif;
      l_name = l_first;      // keep the existing name's letter case
    endif;
    l_tgt.path = l_dir + l_name;
  endif;

  // ---- 5 same-file guard -------------------------------------------------------
  if l_src.mode = C_MODE_MBR and l_tgt.mode = C_MODE_MBR;
    if l_src.lib = l_tgt.lib and l_src.file = l_tgt.file
       and l_src.mbr = l_tgt.mbr;
      return Fail('IAC0012':%trim(l_src.lib) + '/' + %trim(l_src.file)
                  + '(' + %trim(l_src.mbr) + ')':o_msgId:o_msgData);
    endif;
  elseif l_src.mode = C_MODE_IFS and l_tgt.mode = C_MODE_IFS;
    if %xlate(C_LOWER:C_UPPER:l_src.path)
       = %xlate(C_LOWER:C_UPPER:l_tgt.path);
      return Fail('IAC0012':l_src.path:o_msgId:o_msgData);
    endif;
  endif;

  // ---- 6 CCSID and REPLACE values ---------------------------------------------------
  if i_parm.srcCcsid <> -1 and (i_parm.srcCcsid < 1
     or i_parm.srcCcsid > 65535);
    return Fail('IAC0013':%char(i_parm.srcCcsid):o_msgId:o_msgData);
  endif;
  if i_parm.tgtCcsid <> -1 and (i_parm.tgtCcsid < 1
     or i_parm.tgtCcsid > 65535);
    return Fail('IAC0013':%char(i_parm.tgtCcsid):o_msgId:o_msgData);
  endif;
  if Up(i_parm.replace) <> '*NO' and Up(i_parm.replace) <> '*YES'
     and not IsBlank(i_parm.replace);
    return Fail('IAC0014':%trim(i_parm.replace):o_msgId:o_msgData);
  endif;

  l_src.ccsid = i_parm.srcCcsid;
  l_tgt.ccsid = i_parm.tgtCcsid;
  o_src = l_src;
  o_tgt = l_tgt;
  return 0;
end-proc;
