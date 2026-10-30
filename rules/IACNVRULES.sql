-- IACNVRULES - creates and loads the rule tables of IACNVFREE from the JSON
-- files in this directory.
--
-- Run it again after every change to a JSON file:
--   RUNSQLSTM SRCSTMF('REPO/rules/IACNVRULES.sql') COMMIT(*NONE) NAMING(*SYS)
--             DFTRDBCOL(MYLIB)
-- Before running, change the path in the SET statement below to the rules
-- directory of the repo in the IFS (with the trailing slash). The tables are
-- created in MYLIB (the DFTRDBCOL value); put MYLIB on the library list so
-- that IACNVFREE finds them. The JSON files are the source of truth: never
-- edit a table by hand.
--
-- Needs JSON_TABLE (Db2 for i, IBM i 7.3 with a recent Db2 PTF group level,
-- or 7.4 or later; the minimum level has not been checked on a system) and
-- GET_CLOB_FROM_FILE. The JSON files must be UTF-8 (CCSID 1208) text.
-- Without JSON_TABLE: run IACNVRULES_INSERT.sql instead (generated from this
-- file and the JSON files by tools/GenRulesInsert.py; run the script after
-- every change to a JSON file or to this file).

CREATE OR REPLACE VARIABLE IARULESDIR VARCHAR(512) DEFAULT '';
SET IARULESDIR = '/home/REPO/rules/';

-- Operation codes of all source dialects and the free-form syntax of each.
-- DIALECTS lists the dialects the row applies to: 2 = RPG II (RPG36),
-- 3 = RPG III (RPG38 and RPG), 4 = RPG IV fixed form (RPGLE, SQLRPGLE). An
-- operation code can have several rows with different DIALECTS.
-- Sources: SC09-1818 (RPG II), SC09-1817 (RPG III), SC09-2508 (RPG IV).
-- XX = 'Y' for IFxx, DOWxx, DOUxx and CASxx (OPCODE then holds IF, DOW, DOU
-- or CAS). FACTOR1, FACTOR2 and RESULT are R (required), O (optional) or -
-- (blank). IND1 to IND3 name the test of columns 54-55, 56-57 and 58-59
-- (a row of IACNVRES). STATUS is the status of a converted operation: C
-- converted, A converted with an assumption, R not converted. TEMPLATE is the
-- free-form statement ({F1}, {F2}, {RES}, {n}); TEMPLATENOF1 is used when
-- factor 1 is blank.
CREATE OR REPLACE TABLE IACNVOPC (
  OPCODE        VARCHAR(10)  NOT NULL,
  DIALECTS      VARCHAR(4)   NOT NULL,
  XX            CHAR(1)      NOT NULL,
  KIND          VARCHAR(10)  NOT NULL,
  FACTOR1       CHAR(1)      NOT NULL,
  FACTOR2       CHAR(1)      NOT NULL,
  RESULT        CHAR(1)      NOT NULL,
  IND1          VARCHAR(4)   NOT NULL,
  IND2          VARCHAR(4)   NOT NULL,
  IND3          VARCHAR(4)   NOT NULL,
  HALFADJUST    CHAR(1)      NOT NULL,
  STATUS        CHAR(1)      NOT NULL,
  TEMPLATE      VARCHAR(200) NOT NULL,
  TEMPLATENOF1  VARCHAR(200) NOT NULL,
  BIFS          VARCHAR(100) NOT NULL,
  REASON        VARCHAR(200) NOT NULL,
  SOURCE        VARCHAR(100) NOT NULL,
  PRIMARY KEY (OPCODE, DIALECTS)
) RCDFMT IACNVOPCR;

INSERT INTO IACNVOPC
SELECT J.OPCODE, J.DIALECTS, J.XX, J.KIND, J.FACTOR1, J.FACTOR2, J.RESULT,
       J.IND1, J.IND2, J.IND3, J.HALFADJUST, J.STATUS, J.TEMPLATE,
       J.TEMPLATENOF1, J.BIFS, J.REASON, J.SOURCE
  FROM JSON_TABLE(GET_CLOB_FROM_FILE(IARULESDIR CONCAT 'opcodes.json'),
         '$[*]' COLUMNS(
           OPCODE       VARCHAR(10)  PATH '$.opcode',
           DIALECTS     VARCHAR(4)   PATH '$.dialects',
           XX           CHAR(1)      PATH '$.xx',
           KIND         VARCHAR(10)  PATH '$.kind',
           FACTOR1      CHAR(1)      PATH '$.factor1',
           FACTOR2      CHAR(1)      PATH '$.factor2',
           RESULT       CHAR(1)      PATH '$.result',
           IND1         VARCHAR(4)   PATH '$.ind1',
           IND2         VARCHAR(4)   PATH '$.ind2',
           IND3         VARCHAR(4)   PATH '$.ind3',
           HALFADJUST   CHAR(1)      PATH '$.halfAdjust',
           STATUS       CHAR(1)      PATH '$.status',
           TEMPLATE     VARCHAR(200) PATH '$.template',
           TEMPLATENOF1 VARCHAR(200) PATH '$.templateNoF1',
           BIFS         VARCHAR(100) PATH '$.bifs',
           REASON       VARCHAR(200) PATH '$.reason',
           SOURCE       VARCHAR(100) PATH '$.source')) AS J;

-- Column map of each specification type per dialect: the columns of every
-- field. FROMCOL is the first column (1 based), LEN the number of columns.
-- The converter reads fields through this table, never by fixed column.
CREATE OR REPLACE TABLE IACNVLAY (
  DIALECT   CHAR(1)      NOT NULL,
  SPEC      CHAR(1)      NOT NULL,
  FIELD     VARCHAR(12)  NOT NULL,
  FROMCOL   INTEGER      NOT NULL,
  LEN       INTEGER      NOT NULL,
  SOURCE    VARCHAR(100) NOT NULL,
  PRIMARY KEY (DIALECT, SPEC, FIELD)
) RCDFMT IACNVLAYR;

INSERT INTO IACNVLAY
SELECT J.DIALECT, J.SPEC, J.FIELD, J.FROMCOL, J.LEN, J.SOURCE
  FROM JSON_TABLE(GET_CLOB_FROM_FILE(IARULESDIR CONCAT 'layouts.json'),
         '$[*]' COLUMNS(
           DIALECT CHAR(1)      PATH '$.dialect',
           SPEC    CHAR(1)      PATH '$.spec',
           FIELD   VARCHAR(12)  PATH '$.field',
           FROMCOL INTEGER      PATH '$.from',
           LEN     INTEGER      PATH '$.length',
           SOURCE  VARCHAR(100) PATH '$.source')) AS J;

-- The xx of IFxx, DOWxx, DOUxx and CASxx and its comparison operator.
CREATE OR REPLACE TABLE IACNVCMP (
  XX        CHAR(2)      NOT NULL PRIMARY KEY,
  OPERATOR  VARCHAR(2)   NOT NULL,
  SOURCE    VARCHAR(100) NOT NULL
) RCDFMT IACNVCMPR;

INSERT INTO IACNVCMP
SELECT J.XX, J.OPERATOR, J.SOURCE
  FROM JSON_TABLE(
         GET_CLOB_FROM_FILE(IARULESDIR CONCAT 'rpg36-comparisons.json'),
         '$[*]' COLUMNS(
           XX       CHAR(2)      PATH '$.xx',
           OPERATOR VARCHAR(2)   PATH '$.operator',
           SOURCE   VARCHAR(100) PATH '$.source')) AS J;

-- The test a resulting indicator stands for ({RES}, {F1}, {F2}).
CREATE OR REPLACE TABLE IACNVRES (
  CODE    VARCHAR(4)   NOT NULL PRIMARY KEY,
  TEST    VARCHAR(100) NOT NULL,
  SOURCE  VARCHAR(100) NOT NULL
) RCDFMT IACNVRESR;

INSERT INTO IACNVRES
SELECT J.CODE, J.TEST, J.SOURCE
  FROM JSON_TABLE(GET_CLOB_FROM_FILE(IARULESDIR CONCAT 'rpg36-results.json'),
         '$[*]' COLUMNS(
           CODE   VARCHAR(4)   PATH '$.code',
           TEST   VARCHAR(100) PATH '$.test',
           SOURCE VARCHAR(100) PATH '$.source')) AS J;

-- Every indicator name and its free-form name. CYCLE = 'Y': the indicator
-- belongs to the RPG cycle and the line is reported R.
CREATE OR REPLACE TABLE IACNVIND (
  NAME      CHAR(2)      NOT NULL PRIMARY KEY,
  CLASS     VARCHAR(12)  NOT NULL,
  FREEFORM  VARCHAR(10)  NOT NULL,
  CYCLE     CHAR(1)      NOT NULL,
  REASON    VARCHAR(100) NOT NULL,
  SOURCE    VARCHAR(100) NOT NULL
) RCDFMT IACNVINDR;

INSERT INTO IACNVIND
SELECT J.NAME, J.CLASS, J.FREEFORM, J.CYCLE, J.REASON, J.SOURCE
  FROM JSON_TABLE(GET_CLOB_FROM_FILE(IARULESDIR CONCAT 'rpg36-indicators.json'),
         '$[*]' COLUMNS(
           NAME     CHAR(2)      PATH '$.name',
           CLASS    VARCHAR(12)  PATH '$.class',
           FREEFORM VARCHAR(10)  PATH '$.freeForm',
           CYCLE    CHAR(1)      PATH '$.cycle',
           REASON   VARCHAR(100) PATH '$.reason',
           SOURCE   VARCHAR(100) PATH '$.source')) AS J;

-- Figurative constants and special names used in factors.
CREATE OR REPLACE TABLE IACNVNAM (
  NAME      VARCHAR(10)  NOT NULL PRIMARY KEY,
  FREEFORM  VARCHAR(10)  NOT NULL,
  KIND      VARCHAR(10)  NOT NULL,
  STATUS    CHAR(1)      NOT NULL,
  REASON    VARCHAR(100) NOT NULL,
  SOURCE    VARCHAR(100) NOT NULL
) RCDFMT IACNVNAMR;

INSERT INTO IACNVNAM
SELECT J.NAME, J.FREEFORM, J.KIND, J.STATUS, J.REASON, J.SOURCE
  FROM JSON_TABLE(GET_CLOB_FROM_FILE(IARULESDIR CONCAT 'rpg36-names.json'),
         '$[*]' COLUMNS(
           NAME     VARCHAR(10)  PATH '$.name',
           FREEFORM VARCHAR(10)  PATH '$.freeForm',
           KIND     VARCHAR(10)  PATH '$.kind',
           STATUS   CHAR(1)      PATH '$.status',
           REASON   VARCHAR(100) PATH '$.reason',
           SOURCE   VARCHAR(100) PATH '$.source')) AS J;

-- Built-in functions the templates use, and the release that added each.
CREATE OR REPLACE TABLE IACNVBIF (
  NAME    VARCHAR(20)  NOT NULL PRIMARY KEY,
  SINCE   VARCHAR(4)   NOT NULL,
  USEDBY  VARCHAR(60)  NOT NULL,
  NOTE    VARCHAR(100) NOT NULL,
  SOURCE  VARCHAR(100) NOT NULL
) RCDFMT IACNVBIFR;

INSERT INTO IACNVBIF
SELECT J.NAME, J.SINCE, J.USEDBY, J.NOTE, J.SOURCE
  FROM JSON_TABLE(GET_CLOB_FROM_FILE(IARULESDIR CONCAT 'rpg36-bifs.json'),
         '$[*]' COLUMNS(
           NAME   VARCHAR(20)  PATH '$.name',
           SINCE  VARCHAR(4)   PATH '$.since',
           USEDBY VARCHAR(60)  PATH '$.use',
           NOTE   VARCHAR(100) PATH '$.note',
           SOURCE VARCHAR(100) PATH '$.source')) AS J;

-- Settings of the conversion.
CREATE OR REPLACE TABLE IACNVCFG (
  CFGKEY       VARCHAR(30)  NOT NULL PRIMARY KEY,
  CFGVALUE     VARCHAR(200) NOT NULL,
  DESCRIPTION  VARCHAR(200) NOT NULL
) RCDFMT IACNVCFGR;

INSERT INTO IACNVCFG
SELECT J.CFGKEY, J.CFGVALUE, J.DESCRIPTION
  FROM JSON_TABLE(GET_CLOB_FROM_FILE(IARULESDIR CONCAT 'rpg36-config.json'),
         '$[*]' COLUMNS(
           CFGKEY      VARCHAR(30)  PATH '$.key',
           CFGVALUE    VARCHAR(200) PATH '$.value',
           DESCRIPTION VARCHAR(200) PATH '$.description')) AS J;

-- Check: the counts of the rows loaded.
SELECT 'IACNVOPC' AS TABLE_NAME, COUNT(*) AS ROWS FROM IACNVOPC
UNION ALL SELECT 'IACNVLAY', COUNT(*) FROM IACNVLAY
UNION ALL SELECT 'IACNVCMP', COUNT(*) FROM IACNVCMP
UNION ALL SELECT 'IACNVRES', COUNT(*) FROM IACNVRES
UNION ALL SELECT 'IACNVIND', COUNT(*) FROM IACNVIND
UNION ALL SELECT 'IACNVNAM', COUNT(*) FROM IACNVNAM
UNION ALL SELECT 'IACNVBIF', COUNT(*) FROM IACNVBIF
UNION ALL SELECT 'IACNVCFG', COUNT(*) FROM IACNVCFG;
