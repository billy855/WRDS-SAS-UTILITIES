OPTIONS SASAUTOS=('/wrds/wrdsmacros/', SASAUTOS) MAUTOSOURCE SOURCE NOCENTER LS=80 PS=MAX;
%INCLUDE "~/UTILITIES/UTILITIES.GENERAL.sas";


LIBNAME HOME "/scratch/uvanl";

LIBNAME AMA_L "/wrds/bvd/sasdata/ama_l";
LIBNAME AMA_S "/wrds/bvd/sasdata/ama_s";
LIBNAME AMA_M "/wrds/bvd/sasdata/ama_m";
LIBNAME AMA_V "/wrds/bvd/sasdata/ama_v";

LIBNAME BVD (AMA_L AMA_M AMA_V AMA_S);


PROC CONTENTS 
    DATA=BVD.FINANCIALS_L
    VARNUM
    DETAILS;
RUN;

/* CREATE A RANDOM SAMPLE                                                     */
DATA AFIN;
    SET BVD.FINANCIALS_VLMS;

    IF RANUNI(123456789) <= 0.01;
RUN;

PROC SQL;
    CREATE TABLE CHAR AS
        SELECT DISTINCT _CHARACTER_
        FROM AMA.FINANCIALS_V;
QUIT;
RUN;

DATA CHAR;
    SET AMA.FINANCIALS_V (KEEP = _CHARACTER_);

    LENGTH _ALL_ $ 4;
RUN;    

PROC CONTENTS DATA=CHAR;RUN;

DATA ENTRYEXIT;
	SET AMA.FINANCIALS_L (KEEP=IDNR CLOSDATE)
            AMA.FINANCIALS_S (KEEP=IDNR CLOSDATE)
            AMA.FINANCIALS_M (KEEP=IDNR CLOSDATE)
            AMA.FINANCIALS_V (KEEP=IDNR CLOSDATE);
RUN;

PROC SORT DATA=ENTRYEXIT;
	BY IDNR CLOSDATE;
RUN;

PROC PRINT DATA=ENTRYEXIT (OBS=100); RUN;

DATA ENTRY EXIT;
	SET ENTRYEXIT;
	BY IDNR;
	IF FIRST.IDNR AND NOT LAST.IDNR THEN DO;
		ENTRY = CLOSDATE;
		OUTPUT ENTRY;
	END; ELSE IF LAST.IDNR AND NOT FIRST.IDNR THEN DO;
		EXIT = CLOSDATE;
		OUTPUT EXIT;
	END;
RUN;

DATA ENTRYEXIT;
	SET ENTRYEXIT;
	BY IDNR;
	
	IF FIRST.IDNR THEN DO;
		ENTRY = 1;
	END; ELSE DO;
		ENTRY = 0;
	END;

	IF LAST.IDNR THEN DO;
		EXIT = 1;
	END; ELSE DO;
		EXIT = 0;
	END;

	OUTPUT ENTRYEXIT;

RUN;


PROC SORT DATA=ENTRYEXIT; BY CLOSDATE; RUN;
DATA HOME.ENTRYEXITBYDATE;
	SET ENTRYEXIT (KEEP = CLOSDATE ENTRY EXIT);
	BY CLOSDATE;
	
	RETAIN TOTEXIT TOTENTRY;
	
	IF FIRST.CLOSDATE THEN DO;
		TOTEXIT = 0;
		TOTENTRY = 0;
	END; ELSE DO;
		TOTEXIT + EXIT;
		TOTENTRY + ENTRY;
	END;
	
	IF LAST.CLOSDATE THEN DO;
		OUTPUT;
	END;
RUN;
	
PROC PRINT DATA=HOME.ENTRYEXITBYDATE (OBS=1000);RUN;

/* FILL THE GAPS IN THE DATA                                                  */
PROC EXPAND
    DATA =  HOME.ENTRYEXITBYDATE
    OUT = HOME.ENTRYEXITBYDATE_GAPFILL
    TO = DAY
    METHOD = NONE;
    
    ID CLOSDATE;
RUN;

PROC PRINT DATA=HOME.ENTRYEXITBYDATE_GAPFILL (OBS=1000);
RUN;

PROC EXPAND
	DATA = HOME.ENTRYEXITBYDATE_GAPFILL
	OUT = HOME.ENTRYEXITBYQTR
	FROM = DAY
	TO = YEAR
        METHOD = AGGREGATE;
	
	ID CLOSDATE;
	
	CONVERT TOTEXIT  / TRANSFORMIN = (SETMISS 0) OBSERVED=(TOTAL);
        CONVERT TOTENTRY / TRANSFORMIN = (SETMISS 0) OBSERVED=(TOTAL);
RUN;

PROC PRINT DATA=HOME.ENTRYEXITBYQTR;
RUN;

	
PROC CONTENTS
    DATA = BVD.FINANCIALS_VLMS
    VARNUM
    DETAILS;
RUN;

PROC MEANS
    DATA = BVD.FINANCIALS_VLMS (KEEP = PRMA SOLR);

    OUTPUT
        OUT = STATS;    
RUN;

PROC TSCSREG DATA = BVD.FINANCIALS_VLMS;
    ID IDNR CLOSDATE;
    MODEL PRMA = SOLR / FIXONE;
RUN;


PROC SORT
    DATA = BVD.FINANCIALS_VLMS (KEEP = IDNR CLOSDATE PRMA SOLR)
    OUT = REGDATA;

    BY  IDNR CLOSDATE;
RUN;

PROC REG DATA=BVD.FINANCIALS_VLMS;
    MODEL PRMA = SOLR;
RUN;



/* CHECK THE OWNERSHIP DB                                                     */
PROC SQL;
    CREATE TABLE DATASETS AS
        SELECT *
        FROM DICTIONARY.TABLES;
QUIT;    
RUN;

PROC PRINT DATA=DATASETS (OBS=100); RUN;
