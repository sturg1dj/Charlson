/***************************************************************************************************
* Macro to assign Charlson values to claims 
*
* Some housekeeping needs to be done first.
* 1) If there are a mix of ICD9 variables and ICD10 variables
* then the lookup table needs a version variable which will 
* be put in ver spot. Otherwise just put 9 or 10. If no version
* variable either create it OR separate then combine. 
*
* input = dataset containing population
* id = patient id
* start = date of index event
* prior = look back days (positive number eg 366 for a year)
* lookup = table you are getting other claims from
* dxvar = name of the variable that containst DX
* ver = ICD version
* NumDx = number of DX variables per line. Assumes one, if more than one * then converts to one per line
* dateVar = The date variable in lookup table
* Out = Name of output dataset
*********************************************************************************************************/





%macro charlson(input=,
                   id=,
				start=,
				prior=,
				lookup=,
				dxVar=,
				ver=,
				NumDx=1,
				dateVar=,
				out=);

libname charlson 'F:\Code Library\SAS\Charlson';

proc sql noprint;
select compress(quote(code))
  into :charlson_codes separated by ' '
  from charlson.charlson_combine_codes
;
quit;

%if &numdx NE 1 %then %do;


	data _A;
	set &lookup;

	array dx[&NumDx] &dxvar.1-&dxvar.&numDx;

	do I = 1 to &numDx;
		if dx[i] in (&charlson_codes) then do;
			chCode = dx[i];
			chDate = &dateVar;
			ver = &ver.;
			output;
		end;
	end;

	keep &id chCode chDate ver;
	run;
%end;

%else %do;
	data _A;
	set &lookup;
		where &dxvar. in (&charlson_codes);
			chCode = &dxvar.;
			chDate = &dateVar;
			ver = &ver.;
	keep &id chCode chDate ver;
	run;

%end;

	proc sql;
	create table _b as
	select A.&id,
	       A.&start,
		   A.&start. - &prior. as Anchor,
		   B.chcode,
		   b.chDate,
		   b.ver
	  from &input A,
	       _A B
	 where A.&id = B.&id
	   and B.chDate BETWEEN a.&start - &prior. AND a.&start - 1;
	quit;

	proc sql;
	create table &out. as
	select distinct 
           A.*,
	       B.description,
		   B.group,
		   B.charlson
	  from _b a,
	  	   charlson.charlson_combine_codes b
	 where a.chcode = (case when b.ver = 9 then b.code else compress(catx(' ',substr(b.code,1,1),compress(b.code,,'a'))) end)
	   and a.ver = b.ver
;
	quit; 

	proc datasets noprint;
	delete _:;
	run;

%mend;

/*
%charlson(input=jarman,
             id=bene_id,
		  start=start,
		 prior=366,
		 lookup=test2,
		  dxVar=code,
			ver=ver,
		   NumDx=1,
		 dateVar=start,
			out=optTest);

*/
