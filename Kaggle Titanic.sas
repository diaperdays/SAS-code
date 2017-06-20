/************************************************************************************************/
/*									Kaggle Titanic Prediction									*/
/*									Written by: Charis Ackerson									*/
/*									13May2017													*/
/************************************************************************************************/									



/*
 
        / \
    __/    \_
   /_  -  \  \                      ,:',:`,:' 
  / / /     \ \                  __||_||_||_||___
 |    |     / |             ____[""""""""""""""""]___
 /   /     \   \            \ " '''''''''''''''''''' \
 ~~^~^~HZ~~^~^~^~~^~^~^~~jgs~^~^~^^~^~^~^~^~^~^~^~~^~^~^~^~~^~^

Kaggle Competition:
https://www.kaggle.com/c/titanic


Data Dictionary:
----------------

Variable					Definition					Key
--------					----------					----
survival					Survival					0 = No 
														1 = Yes

pclass						Ticket class				1 = 1st
														2 = 2nd
														3 = 3rd

sex							Sex							male
														female

Age							Age in years
	
sibsp						# of siblings / spouses aboard the Titanic	

parch						# of parents / children aboard the Titanic	

ticket						Ticket number	

fare						Passenger fare	

cabin						Cabin number
	
embarked					Port of Embarkation			C = Cherbourg
														Q = Queenstown
														S = Southampton


Variable Notes:
---------------

pclass: 
A proxy for socio-economic status (SES)
		1st = Upper		
		2nd = Middle
		3rd = Lower

age: 
Age is fractional if less than 1. If the age is estimated, is it in the form of xx.5

sibsp: 
The dataset defines family relations in this way.
	Sibling = brother, sister, stepbrother, stepsister
	Spouse = husband, wife (mistresses and fiancés were ignored)

parch: 
The dataset defines family relations in this way.
	Parent = mother, father
	Child = daughter, son, stepdaughter, stepson
	Some children traveled only with a nanny, therefore parch=0 for them.

*/

ods graphics on;


/*copy dataset*/
data kaggle.test_copy;
	set kaggle.test;
run;
/*NOTE: There were 418 observations read from the data set KAGGLE.TEST.
NOTE: The data set KAGGLE.TEST_COPY has 418 observations and 11 variables.*/


/*merge gender_submission with test for outcome variable (survival)*/
proc sql;
	create table
		kaggle.test_gender			as
	select
		g.survived												,
		g.passengerid				as 	gpID	label='gpID'	,
		t.passengerid				as 	tpID	label='tpID'	,
		t.pclass												,
		t.name													,
		t.sex													,
		t.age													,
		t.sibsp													,
		t.parch													,
		t.ticket												,
		t.fare													,
		t.cabin													,
		t.embarked
	from 
		kaggle.test					as 	t
			full outer join
		kaggle.gender_submissions	as 	g
	on
		g.passengerid				=
		t.passengerid
	;
quit;
/*NOTE: Table KAGGLE.TEST_GENDER created, with 418 rows and 13 columns.*/
/*passenger ID is a 1:1 ratio in gender_submission dataset and test dataset, no missing obs*/

/*get data dictionary*/
proc contents data=kaggle.test_gender;
run;

proc sort data=kaggle.test_gender;
	by survived;
run;

*Univariate, to check the distribution for continuous variables;
proc univariate data=kaggle.test_gender;
	by 		survived;
run;

/*Create qqplot, histogram for continuous variables*/
title 'Normal Q-Q Plot for Continuous Variables';
proc univariate data=kaggle.test_gender;
   qqplot tpid age sibsp parch ticket fare / normal (mu=est sigma=est) square ctext=blue odstitle = title;
run; 


/*Comparative histograms on outcome*/
 title 'Comparative plots';
      proc univariate data=kaggle.test_gender noprint;
        class survived;
        var tpid age sibsp parch ticket fare ;
        histogram tpid age sibsp parch ticket fare  / vscale=count normal(noprint);
        inset normal(mu sigma);
 run;
 title;



/* create a user-defined format to group missing and nonmissing */
proc format;
 value $missfmt ' '='Missing' other='Not Missing';
 value  missfmt  . ='Missing' other='Not Missing';
run;
 
proc freq data=kaggle.test_gender; 
format _CHAR_ $missfmt.; /* apply user-defined format for the duration of this PROC */
tables _CHAR_ / missing missprint nocum nopercent;
format _NUMERIC_ missfmt.;
tables _NUMERIC_ / missing missprint nocum nopercent;
run;

/*create matrix of missing and not missing values*/
title 'Missing & Not missing values by variable';
proc iml;
use kaggle.test_gender;
read all var _NUM_ into x[colname=nNames]; 
n = countn(x,"col");
nmiss = countmiss(x,"col");
 
read all var _CHAR_ into x[colname=cNames]; 
close kaggle.test_gender;
c = countn(x,"col");
cmiss = countmiss(x,"col");
 
/* combine results for num and char into a single table */
Names = cNames || nNames;
rNames = {"    Missing", "Not Missing"};
cnt = (cmiss // c) || (nmiss // n);
print cnt[r=rNames c=Names label=""];

quit;

/******* END missingness algorithms ********/

/* Make cabin be usable data*/

/**** START dummy variables ********/


/*find quartiles for continuous variables (excluding sibsp, cabin and parch)*/
proc univariate data=kaggle.test_gender;
	var age ticket fare sibsp parch;
run;


*frequency tables for categorical & dichotomous variables*;
proc freq data=kaggle.test_gender; 
	tables (sex pclass embarked)*survived/norow nocol;
run;



/*	Rough determination of scale */ 
/************************SPLINES***********************************************************/
ods trace on;

/*************************** AGE ********************************/
*non-transformed data - constant connection -3 knots(quartiles);
proc logistic descending data=kaggle.test_gender;
  effect ages=spline(age/knotmethod=list(22 27 39) basis=tpf(noint) degree=0);
  model survived=ages; 
effectplot;
run; 

*Non-transformed data - linear connection -3 knots(quartiles);
proc logistic descending data=kaggle.test_gender;
  effect ages=spline(age/knotmethod=list(22 27 39) basis=tpf(noint) degree=1);
  model survived=ages; 
effectplot;
run; 

*Non-transformed data - cubic connection -3 knots(quartiles);
proc logistic descending data=kaggle.test_gender;
  effect ages=spline(age/knotmethod=list(22 27 39) basis=tpf(noint) naturalcubic);
  model survived=ages; 
effectplot;
run; 


/*************************** Sibsp ********************************/
*non-transformed data - constant connection -3 knots(quartiles);
proc logistic descending data=kaggle.test_gender;
  effect sibsps=spline(sibsp/knotmethod=list(0 0 1) basis=tpf(noint) degree=0);
  model survived=sibsps; 
effectplot;
run; 

*Non-transformed data - linear connection -3 knots(quartiles);
proc logistic descending data=kaggle.test_gender;
  effect sibsps=spline(sibsp/knotmethod=list(0 0 1) basis=tpf(noint) degree=1);
  model survived=sibsps; 
effectplot;
run; 


/*************************** parch ********************************/
*non-transformed data - constant connection -3 knots(quartiles);
proc logistic descending data=kaggle.test_gender;
  effect parchs=spline(parch/knotmethod=list(0 0 1) basis=tpf(noint) degree=0);
  model survived=parchs; 
effectplot;
run; 

*Non-transformed data - linear connection -3 knots(quartiles);
proc logistic descending data=kaggle.test_gender;
  effect parchs=spline(parch/knotmethod=list(0 0 1) basis=tpf(noint) degree=1);
  model survived=parchs; 
effectplot;
run; 


/*begin here*/




/*************************** ticket ********************************/
*non-transformed data - constant connection -3 knots(quartiles);
proc logistic descending data=kaggle.test_gender;
  effect tickets=spline(ticket/knotmethod=list(17469.5 230136.0 347083.0) basis=tpf(noint) degree=0);
  model survived=tickets; 
effectplot;
run; 

*Non-transformed data - linear connection -3 knots(quartiles);
proc logistic descending data=kaggle.test_gender;
  effect tickets=spline(ticket/knotmethod=list(17469.5 230136.0 347083.0) basis=tpf(noint) degree=1);
  model survived=tickets; 
effectplot;
run; 

*Non-transformed data - cubic connection -3 knots(quartiles);
proc logistic descending data=kaggle.test_gender;
  effect tickets=spline(ticket/knotmethod=list(17469.5 230136.0 347083.0) basis=tpf(noint) naturalcubic);
  model survived=tickets; 
effectplot;
run; 



/*************************** fare ********************************/
*non-transformed data - constant connection -3 knots(quartiles);
proc logistic descending data=kaggle.test_gender;
  effect fares=spline(fare/knotmethod=list(7.8958 14.4542 31.5) basis=tpf(noint) degree=0);
  model survived=fares; 
effectplot;
run; 

*Non-transformed data - linear connection -3 knots(quartiles);
proc logistic descending data=kaggle.test_gender;
  effect fares=spline(fare/knotmethod=list(7.8958 14.4542 31.5) basis=tpf(noint) degree=1);
  model survived=fares; 
effectplot;
run; 

*Non-transformed data - cubic connection -3 knots(quartiles);
proc logistic descending data=kaggle.test_gender;
  effect fares=spline(fare/knotmethod=list(7.8958 14.4542 31.5) basis=tpf(noint) naturalcubic);
  model survived=fares; 
effectplot;
run; 





/*make categorical dummy variables or collapse for:
Dataset:

	Original					Transformed
kaggle.test_gender			kaggle.test_gender2
------------------			-------------------
age					-->		age2 
age					-->		age3
ticket				--> 	ticket2
ticket				--> 	ticket3
fare				-->		fare2
fare				-->		fare3
sibsp				-->		sibsp2
sibsp				-->		sibsp3
parch				-->		parch2
parch				-->		parch3
sex					-->		sex2

/*name dataset kaggle.test_gender2 so as to not mess up original dataset;*/
data kaggle.test_gender2 (drop=gpid); 
	set kaggle.test_gender; 
		*make age categorical by quartiles, min/max: age-->age2;
		if 				0			<=	age		<=	21.9 		then age2		=	1;		/* Q1 */
			else if 	22.0		<	age		<=	26.9 		then age2		=	2;		/* Q2 */
			else if 	27.0		<	age		<= 	38.9		then age2		=	3;		/* Q3 */
			else if 	39.0		<	age		<=	77.0		then age2		=	4;		/* Q4 */
			
		*make age categorical by median, age --> age3;
		if 				0			<=	age		<=	26.9		then age3		=	1;		/*median*/
			else if 	27.0		<	age		<=	77.0 		then age3		=	2;

		*make ticket categorical by quartiles, min/max;
		if 				0			<=	ticket	<=	17469.4 	then ticket2	=	1;		/* Q1 */
			else if 	17469.5		<	ticket	<=	230135.9 	then ticket2	=	2;		/* Q2 */
			else if 	230136.0	<	ticket	<=	347082.9 	then ticket2	=	3;		/* Q3 */
			else if 	347083.0	<	ticket	<=	3101298.0	then ticket2	=	4;		/* Q4 */
		
		*make ticket categorical by median, ticket --> ticket3;
		if 				0			<=	ticket	<=	230135.9 	then ticket3	=	1;		/* median */
			else if 	230136.0	<=	ticket	<	3101298.0 	then ticket3	=	2;
		

		*make fare categorical by quartiles, min/max;
		if 				0			<=	fare	<=	7.8957		then fare2	=	1;		/* Q1 */
			else if 	7.8958		<	fare	<=	14.4541 	then fare2	=	2;		/* Q2 */
			else if 	14.4542		<	fare	<=	31.49		then fare2	=	3;		/* Q3 */
			else if 	31.5		<	fare	<=	512.33		then fare2	=	4;		/* Q4 */
		
		*make fare categorical by median, fare --> fare3;
		if 				0			<=	fare	<=	14.4542 	then fare3	=	1;		/* median */
			else if 	14.4543		<=	fare	<	512.33	 	then fare3	=	2;

		*collapse sibsp at quartiles;
		if 								sibsp	=	0 			then sibsp2		=	0;		/* no sibling/spouse */
			else if 					sibsp	=	1 			then sibsp2		=	1;		/* one sibling/spouse */
			else if 					sibsp 	=	2 			then sibsp2		=	2;		/* two sibling/spouse */
			else if 					sibsp	in 	(3,4,5)		then sibsp2		= 	3;		/* lower order multiple sibling/spouse */
			else if 					sibsp 	in 	(6,7,8,9)	then sibsp2		=	4;		/* higher order multiple sibling/spouse */
		
		*make sibsp categorical by median, sibsp --> sibsp3;
		if 				0			<=	sibsp	<=	1 	then sibsp3	=	1;		/* median */
			else if 	2			<=	sibsp	<	9	then sibsp3	=	2;

		*collapse parch (parch=0 is traveled with nanny, so keep separate) - of note, median is = 0, Q4 is = 9 *;	
		if 								parch	=	0 			then parch2		=	0;		/* traveled with nanny */
			else if 					parch	=	1 			then parch2		=	1;		/* one child */
			else if 					parch 	=	2 			then parch2		=	2;		/* two children */
			else if 					parch	in 	(3,4,5)		then parch2		= 	3;		/* lower order multiple children */
			else if 					parch 	in 	(6,7,8,9)	then parch2		=	4;		/* higher order multiple children */

			
		*make parch categorical by median, parch --> parch3;
		if 				0			<=	parch	<=	1 	then parch3	=	1;		/* median */
			else if 	2			<=	parch	<	9	then parch3	=	2;

		if 								sex		=	'male'		then sex2		=	0;
			else if						sex		= 	'female'	then sex2		=	1;

run;



************************* DESIGN VARIABLE PLOTS***************************;

************** Design variable plot AGE – Univariate******************;
 *Design variables plots for continuous model covariates;
proc univariate  data=kaggle.test_gender2;
	var age2;
run;

proc logistic descending data=kaggle.test_gender2;
	class age2/param=ref ref=first;
	model survived=age2;
run;

/*calculate midpoints for age*/
data kaggle.age_midpoints;
	input Q1 Q2 Q3 Q4;
	midpoint1 = (Q1 + 0) / 2;
	midpoint2 = (Q2 + Q1) / 2;
	midpoint3 = (Q3 + Q2) / 2;
	midpoint4 = (Q4 + Q3) / 2;
	datalines;
	22.0 27.0 39.0 76.0
	;
run;

proc print data=kaggle.age_midpoints;
	var midpoint1 midpoint2 midpoint3 midpoint4;
	title 'Midpoints for Age';
run;

/*		age category midpoints		design variable coefficients*/
data kaggle.dvplot_age;
	input mp coeff;
	cards;
		11							0
		24.5						-0.5529
		33.0						-0.0182
		57.5						-0.1736
run;

title 'Design Variable Plot for Age';
axis1 minor=none label=(f=swiss h=2.5 'age');
axis2 minor=none label=(f=swiss h=2.5 a=90 'ln(or) ');
goptions ftext=swissb htext=2.0 hsize=6 in vsize= 6 in;
symbol1 c=black v=dot i=stepjc;

proc gplot data=kaggle.dvplot_age;
	plot coeff*mp/haxis=axis1 vaxis=axis2;
	run;
quit;


************** Design variable plot ticket – Univariate******************;
 *Design variables plots for continuous model covariates;
proc univariate  data=kaggle.test_gender2;
	var ticket2;
run;

proc logistic descending data=kaggle.test_gender2;
	class ticket2/param=ref ref=first;
	model survived=ticket2;
run;

/*calculate midpoints for ticket*/
data kaggle.ticket_midpoints;
	input Q1 Q2 Q3 Q4;
	midpoint1 = (Q1 + 0) / 2;
	midpoint2 = (Q2 + Q1) / 2;
	midpoint3 = (Q3 + Q2) / 2;
	midpoint4 = (Q4 + Q3) / 2;
	datalines;
	16966 235509 347077 3101266
	;
run;

proc print data=kaggle.ticket_midpoints;
	var midpoint1 midpoint2 midpoint3 midpoint4;
	title 'Midpoints for ticket';
run;

/*		ticket category midpoints		design variable coefficients*/
data kaggle.dvplot_ticket;
	input mp coeff;
	cards;
		8483							0
		126237.5						0.4363
		291293							-0.1782
		1724171.5						0.2999
run;

title 'Design Variable Plot for ticket';
axis1 minor=none label=(f=swiss h=2.5 'ticket');
axis2 minor=none label=(f=swiss h=2.5 a=90 'ln(or) ');
goptions ftext=swissb htext=2.0 hsize=6 in vsize= 6 in;
symbol1 c=black v=dot i=stepjc;

proc gplot data=kaggle.dvplot_ticket;
	plot coeff*mp/haxis=axis1 vaxis=axis2;
	run;
quit;

 

************** Design variable plot fare – Univariate******************;
 *Design variables plots for continuous model covariates;
proc univariate  data=kaggle.test_gender2;
	var fare2;
run;

proc logistic descending data=kaggle.test_gender2;
	class fare2/param=ref ref=first;
	model survived=fare2;
run;

/*calculate midpoints for fare*/
data kaggle.fare_midpoints;
	input Q1 Q2 Q3 Q4;
	midpoint1 = (Q1 + 0) / 2;
	midpoint2 = (Q2 + Q1) / 2;
	midpoint3 = (Q3 + Q2) / 2;
	midpoint4 = (Q4 + Q3) / 2;
	datalines;
	1 3 4 4
	;
run;

proc print data=kaggle.fare_midpoints;
	var midpoint1 midpoint2 midpoint3 midpoint4;
	title 'Midpoints for fare';
run;

/*		fare category midpoints		design variable coefficients*/
data kaggle.dvplot_fare;
	input mp coeff;
	cards;
		0.5							0
		2							-0.111
		3.5				            0.4919
		4						    1.0463
run;

title 'Design Variable Plot for fare';
axis1 minor=none label=(f=swiss h=2.5 'fare');
axis2 minor=none label=(f=swiss h=2.5 a=90 'ln(or) ');
goptions ftext=swissb htext=2.0 hsize=6 in vsize= 6 in;
symbol1 c=black v=dot i=stepjc;

proc gplot data=kaggle.dvplot_fare;
	plot coeff*mp/haxis=axis1 vaxis=axis2;
	run;
quit;

************** Design variable plot sibsp – Univariate******************;
 *Design variables plots for continuous model covariates;
proc univariate  data=kaggle.test_gender2;
	var sibsp2;
run;

proc logistic descending data=kaggle.test_gender2;
	class sibsp2/param=ref ref=first;
	model survived=sibsp2;
run;

/*calculate midpoints for sibsp*/
data kaggle.sibsp_midpoints;
	input Q1 Q2 Q3 Q4;
	midpoint1 = (Q1 + 0) / 2;
	midpoint2 = (Q2 + Q1) / 2;
	midpoint3 = (Q3 + Q2) / 2;
	midpoint4 = (Q4 + Q3) / 2;
	datalines;
	0 0 1 4
	;
run;

proc print data=kaggle.sibsp_midpoints;
	var midpoint1 midpoint2 midpoint3 midpoint4;
	title 'Midpoints for sibsp';
run;

/*		sibsp category midpoints		design variable coefficients*/
data kaggle.dvplot_sibsp;
	input mp coeff;
	cards;
		0								0
		0								0.5080
		0.5								0.1025
		2.5								0.7956
run;

title 'Design Variable Plot for sibsp';
axis1 minor=none label=(f=swiss h=2.5 'sibsp');
axis2 minor=none label=(f=swiss h=2.5 a=90 'ln(or) ');
goptions ftext=swissb htext=2.0 hsize=6 in vsize= 6 in;
symbol1 c=black v=dot i=stepjc;

proc gplot data=kaggle.dvplot_sibsp;
	plot coeff*mp/haxis=axis1 vaxis=axis2;
	run;
quit;



************** Design variable plot parch – Univariate******************;
 *Design variables plots for continuous model covariates;
proc univariate  data=kaggle.test_gender2;
	var parch2;
run;

proc logistic descending data=kaggle.test_gender2;
	class parch2/param=ref ref=first;
	model survived=parch2;
run;

/*calculate midpoints for parch*/
data kaggle.parch_midpoints;
	input Q1 Q2 Q3 Q4;
	midpoint1 = (Q1 + 0) / 2;
	midpoint2 = (Q2 + Q1) / 2;
	midpoint3 = (Q3 + Q2) / 2;
	midpoint4 = (Q4 + Q3) / 2;
	datalines;
	0 0 0 4
	;
run;

proc print data=kaggle.parch_midpoints;
	var midpoint1 midpoint2 midpoint3 midpoint4;
	title 'Midpoints for parch';
run;

/*		parch category midpoints		design variable coefficients*/
data kaggle.dvplot_parch;
	input mp coeff;
	cards;
		0								0.9750
		0								1.2514
		0								1.5135
		4								0.1278
run;

title 'Design Variable Plot for parch';
axis1 minor=none label=(f=swiss h=2.5 'parch');
axis2 minor=none label=(f=swiss h=2.5 a=90 'ln(or) ');
goptions ftext=swissb htext=2.0 hsize=6 in vsize= 6 in;
symbol1 c=black v=dot i=stepjc;

proc gplot data=kaggle.dvplot_parch;
	plot coeff*mp/haxis=axis1 vaxis=axis2;
	run;
quit;

