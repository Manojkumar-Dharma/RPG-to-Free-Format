**FREE
// IAcnvSys - system helpers used by validation: library/file/member
// existence checks (CHKOBJ) and IFS checks (access, opendir/readdir).
// Module of service program IAcnvSrv.

ctl-opt nomain option(*srcstmt:*nodebugio);

/copy IAcnvSrvP

dcl-c C_LOWER 'abcdefghijklmnopqrstuvwxyz';
dcl-c C_UPPER 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
dcl-c C_NAMECHARS 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_#@$';

dcl-pr QCmdExc extpgm('QCMDEXC');
  cmd char(3000) const options(*varsize);
  len packed(15:5) const;
end-pr;

dcl-pr access int(10) extproc('access');
  path pointer value options(*string);
  mode int(10) value;
end-pr;

dcl-pr opendir pointer extproc('opendir');
  dirname pointer value options(*string);
end-pr;

dcl-pr readdir pointer extproc('readdir');
  dirp pointer value;
end-pr;

dcl-pr closedir int(10) extproc('closedir');
  dirp pointer value;
end-pr;

// Directory entry layout as returned by readdir().
dcl-ds dirent_t qualified template;
  reserved1 char(16);
  fileno_gen_id uns(10);
  fileno uns(10);
  reclen uns(10);
  reserved3 int(10);
  reserved4 char(8);
  nlsinfo char(12);
  namelen uns(10);
  name char(640);
end-ds;

// Message API (used by SendMessage below).
dcl-pr QMHSNDPM extpgm('QMHSNDPM');
  msgId char(7) const;
  msgFile char(20) const;
  msgData char(256) const options(*varsize);
  msgDataLen int(10) const;
  msgType char(10) const;
  stackEntry char(10) const;
  stackCounter int(10) const;
  msgKey char(4);
  error char(16) options(*varsize);
end-pr;

dcl-ds g_apiError qualified;
  bytesProvided int(10) inz(16);
  bytesAvailable int(10);
  exceptionId char(7);
  reserved char(1);
end-ds;

// ------------------------------------------------------------------
// A name is safe when it is a special value (*LIBL, *CURLIB ...) made of
// letters after the asterisk, or a plain object name. Anything else is
// refused before it can reach a command string.
dcl-proc IsSafeName export;
  dcl-pi *n ind;
    i_name char(10) const;
  end-pi;

  dcl-s l_name varchar(10);
  dcl-s l_body varchar(10);
  dcl-s l_i int(10);

  l_name = %trim(%xlate(C_LOWER:C_UPPER:i_name));
  if %len(l_name) = 0;
    return *off;
  endif;

  if %subst(l_name:1:1) = '*';
    l_body = %subst(l_name:2);
    if %len(l_body) = 0;
      return *off;
    endif;
    return %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ':l_body) = 0;
  endif;

  // A plain name cannot start with a digit.
  if %scan(%subst(l_name:1:1):'0123456789') > 0;
    return *off;
  endif;
  return %check(C_NAMECHARS:l_name) = 0;
end-proc;

// ------------------------------------------------------------------
// *ON when the library/file (and member, when given) exists.
// Inputs must already have passed IsSafeName.
dcl-proc ChkQsysObj export;
  dcl-pi *n ind;
    i_lib char(10) const;
    i_file char(10) const;
    i_mbr char(10) const;
  end-pi;

  dcl-s l_cmd char(256);

  select;
    when %len(%trim(i_file)) = 0;
      // Library only.
      if %trim(i_lib) = '*LIBL' or %trim(i_lib) = '*CURLIB';
        return *on;
      endif;
      l_cmd = 'CHKOBJ OBJ(QSYS/' + %trim(i_lib) + ') OBJTYPE(*LIB)';
    when %len(%trim(i_mbr)) = 0;
      l_cmd = 'CHKOBJ OBJ(' + %trim(i_lib) + '/' + %trim(i_file)
            + ') OBJTYPE(*FILE)';
    other;
      l_cmd = 'CHKOBJ OBJ(' + %trim(i_lib) + '/' + %trim(i_file)
            + ') OBJTYPE(*FILE) MBR(' + %trim(i_mbr) + ')';
  endsl;

  monitor;
    QCmdExc(l_cmd:%len(%trimr(l_cmd)));
  on-error;
    return *off;
  endmon;
  return *on;
end-proc;

// ------------------------------------------------------------------
// mode: 4 = read, 2 = write, 0 = exists
dcl-proc IfsAccess export;
  dcl-pi *n ind;
    i_path varchar(1024) const;
    i_mode int(10) const;
  end-pi;

  return access(i_path:i_mode) = 0;
end-proc;

// ------------------------------------------------------------------
// Case-insensitive search of directory i_dir for i_name.
// Returns the number of matches. o_first gets the first match and o_list
// all matches (blank separated, truncated if long).
dcl-proc FindIfsName export;
  dcl-pi *n int(10);
    i_dir varchar(1024) const;
    i_name varchar(256) const;
    o_first varchar(256);
    o_list varchar(512);
  end-pi;

  dcl-s l_dirp pointer;
  dcl-s l_entp pointer;
  dcl-ds l_ent likeds(dirent_t) based(l_entp);
  dcl-s l_want varchar(256);
  dcl-s l_have varchar(256);
  dcl-s l_count int(10) inz(0);

  o_first = '';
  o_list = '';
  l_want = %xlate(C_LOWER:C_UPPER:i_name);

  l_dirp = opendir(i_dir);
  if l_dirp = *null;
    return 0;
  endif;

  l_entp = readdir(l_dirp);
  dow l_entp <> *null;
    if l_ent.namelen > 0 and l_ent.namelen <= 256;
      l_have = %subst(l_ent.name:1:l_ent.namelen);
      if %xlate(C_LOWER:C_UPPER:l_have) = l_want;
        l_count += 1;
        if l_count = 1;
          o_first = l_have;
        endif;
        if %len(o_list) + %len(l_have) + 1 <= 512;
          if %len(o_list) > 0;
            o_list += ' ';
          endif;
          o_list += l_have;
        endif;
      endif;
    endif;
    l_entp = readdir(l_dirp);
  enddo;

  closedir(l_dirp);
  return l_count;
end-proc;

// ------------------------------------------------------------------
// *ON when the directory can be opened (it exists and is readable).
dcl-proc DirExists export;
  dcl-pi *n ind;
    i_dir varchar(1024) const;
  end-pi;

  dcl-s l_dirp pointer;

  l_dirp = opendir(i_dir);
  if l_dirp = *null;
    return *off;
  endif;
  closedir(l_dirp);
  return *on;
end-proc;

// ------------------------------------------------------------------
// Messages to the caller from message file IACNVMSG (found in *LIBL).
dcl-proc SendMessage;
  dcl-pi *n;
    i_msgId char(7) const;
    i_msgData char(256) const;
    i_msgType char(10) const;
  end-pi;

  dcl-s l_key char(4);

  g_apiError.bytesProvided = 16;
  QMHSNDPM(i_msgId:'IACNVMSG  *LIBL':i_msgData:%len(i_msgData)
           :i_msgType:'*PGMBDY':1:l_key:g_apiError);
end-proc;

// Sends an escape message, which ends the calling program with an error.
dcl-proc SendEscape export;
  dcl-pi *n;
    i_msgId char(7) const;
    i_msgData char(256) const;
  end-pi;

  SendMessage(i_msgId:i_msgData:'*ESCAPE');
end-proc;

// Sends a completion message to the caller's job log / command line.
dcl-proc SendCompletion export;
  dcl-pi *n;
    i_msgId char(7) const;
    i_msgData char(256) const;
  end-pi;

  SendMessage(i_msgId:i_msgData:'*COMP');
end-proc;
