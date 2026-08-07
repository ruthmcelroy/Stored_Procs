USE TML_DW
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_PopulateStratsTable
AS
BEGIN

-- =============================================================================
-- Procedure:   sp_PopulateStratsTable
-- Schema:      dbo
-- Database:    TML_DW
-- Purpose:     Drop and recreate the applicants data.
-- Owner:       Data Engineering Team
-- Dependencies:
--   Tables:    DPR_DW.dbo.DIM_CO_Application, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAApplicant, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAApplication, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMADeposit, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMALoanDetails, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAProperty, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAPropertySummary, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAPropertySurveyDetails, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMARequirement, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMASecurity, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMASecurityValuation, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAValuation, TML_DW.dbo.dups, TML_DW.dbo.fn_DailyRates, TML_DW.dbo.fn_Litigations, TML_DW.dbo.log_StoredProcedureErrors, TML_DW.dbo.log_StoredProcedureRuns, TML_DW.dbo.s, TML_DW.dbo.tbl_AffordabilityLatest, TML_DW.dbo.tbl_AffordabilityScores, TML_DW.dbo.tbl_Applicants, TML_DW.dbo.tbl_Applications, TML_DW.dbo.tbl_ApplicationsFunctionDaily, TML_DW.dbo.tbl_ArrearsDaily, TML_DW.dbo.tbl_CovidTracker, TML_DW.dbo.tbl_CreditRefLatest, TML_DW.dbo.tbl_DailyCheck, TML_DW.dbo.tbl_Overrides, TML_DW.dbo.tbl_PaymentHolidays, TML_DW.dbo.tbl_PaymentProfiles, TML_DW.dbo.tbl_ProductHistory, TML_DW.dbo.tbl_Products, TML_DW.dbo.tbl_ProductsReportRanking, TML_DW.dbo.tbl_PropertyDetails, TML_DW.dbo.tbl_Referrals, TML_DW.dbo.tbl_Strats
--   Procs:     TML_DW.dbo.sp_Insert_ErrorLog, TML_DW.dbo.sp_OverrideTableValues
--   Views:     TML_DW.dbo.vw_ApplicationFees, TML_DW.dbo.vw_ApplicationReportStatus, TML_DW.dbo.vw_DebtConsolidation, TML_DW.dbo.vw_DepositSources, TML_DW.dbo.vw_IntermediaryTree, TML_DW.dbo.vw_MissPaymentsSecuredUnsecuredLoans, TML_DW.dbo.vw_PaymentSchedule, TML_DW.dbo.vw_PortfolioCount, TML_DW.dbo.vw_ReportingCategories, TML_DW.dbo.vw_UnsecuredSecuredDefaults, TML_DW.dbo.vw_Valuations
--   Functions: TML_DW.dbo.fn_DailyRates, TML_DW.dbo.fn_Litigations
-- =============================================================================
-- Legacy Change Log
-- =============================================================================
-- Cutover Note:
-- From 2026-06-19 onwards, new change history is maintained in Azure DevOps
-- using Pull Requests, linked Work Items, commit messages, and file history.
--
-- Original legacy change log retained for reference only. Do not update this
-- section going forward.
--
-- 
-- *******************************************************************************************************************
-- Name:		sp_PopulateStratsTable
-- Info:		Drop and recreate the applicants data.
-- 			Used lots of places and allows index for faster querying than complex view
-- *******************************************************************************************************************
-- ChangeNo	Developer		Date		JiraNo		Detail
-- 
-- 001			N Sharkie		2018-04-30				Created
-- 002			N Sharkie		2018-05-08				Removed Income Multiple for BTL
-- 003			N Sharkie		2018-05-08				Added in logging of end time
-- 004			N Sharkie		2018-05-11				Added RN score Category Grouping
-- 005			N Sharkie		2018-05-15				Added additoinal columns for BTL Con Limits
-- 006			N Sharkie		2018-06-05				Put in correct ICR data.
-- 007			N Sharkie		2018-06-06				changed build structure to add pk and avoid duplication issues, fixed Multiple flag
-- 008			N Sharkie		2018-06-15				Added ProductFeature & Over 65 flag, fixed ICR issue
-- 008			N Sharkie		2018-06-29				Updated ICR Formuls. Now uses stress test rates
-- 009			N Sharkie		2018-07-09				Added in join to vw_PortfolioCount
-- 010			N Sharkie		2018-07-16				Added in Monthly Rental Income  additional ICR grouping - broader ranges
-- 011			N Sharkie		2018-07-27				Added in Interest Rate and associated grouping info
-- 012			N Sharkie		2018-08-02				Completed cases now used stressed value and not current rate for ICR
-- 013			N Sharkie		2018-09-12				AgeAtApp columns updated to use DIP date from apps that ever    reached app
-- 014			N Sharkie		2018-10-23				Tier Asset Class exludes neww RL prodcuts
-- 015			N Sharkie		2018-10-26				Customer LTV & Valuation added
-- 016			N Sharkie		2019-01-31				Added some additional columns to allow use in warranties report
-- 017			N Sharkie		2019-02-06				Added COBDate column
-- 018			N Sharkie		2019-02-13				Added feed error checks to avoid empty tables & Tidied ICR calculaltion to CTE at start. Easier for joins later.
-- 019			N Sharkie		2019-03-07				Updated Income Multiple Flag column. Now 4.5 for all
-- 020			N Sharkie		2019-03-11				Moved all Stress Test Calculations to CTE at beginning
-- 021			N Sharkie		2019-04-04				Changed income columns to use affordability latest instead of DPR values
-- 022			N Sharkie		2019-04-18				Added join to affordability scores and new columns from
-- 023			N Sharkie		2019-05-31				updated to use new tbl_AffordabilityScores table
-- 024			N Sharkie		2019-07-10				Income multiple group join updated to use the affordability incomes
-- 025			R Callan		2019-08-22				Change Report Status to included a Redeemed option
-- 026			R Callan		2019-08-28				Added Securitised field to be included and Reversion Date added
-- 027			N Sharkie		2019-09-10				Added call to override procedure
-- 028			R Callan		2019-10-18				Added join to tbl_Products and added ProductRange column to select statement
-- 029			N Sharkie		2019-10-29				Now using new income columns in affordability latest table and added income multiple calc to CTE
-- 030			N Sharkie		2019-11-22				Updated Retirement flag logic - added extra retirement info column and general lending into retirement indicator. Also now using tbl_CredRefLatest instead of view
-- 031			R Callan		2019-12-16				Changed the logic on how the interest rate is calculation to bring interest rate for redeemed BTL apps.
-- 032			R Callan		2020-01-16				Added in new column for CustomerBTLLTVSegment and relevant join. Updated the LEFT OUTER JOIN #groups grp_ltvSegCust
-- 													to have cast and round function the Calculation to bring back 2 decamil places.
-- 033			R Callan		2020-02-04				IncomeMulitple within Calcs CTE updated to so NULL value show as 0.00
-- 034			N Sharkie		2020-02-06				Multiple Flag updated to use income multiple with tax credits included
-- 035			N Sharkie		2020-03-10				Update to FTBTL to check there is no porftolio as well.
-- 036			R Callan		2020-03-17				Update Referrals join to use tbl_Referral instead of the vw_Referrals
-- 037			N Sharkie		2020-03-18				Added override for Rental incomes
-- 038			N Sharkie		2020-04-24				Added payment holiday flag
-- 039			N Sharkie		2020-07-13				Added covid tracker info - additioanl joins and columns
-- 040			N Sharkie		2020-07-29				Additions to deferral status column
-- 041			N Sharkie		2020-09-23				Added SecuritisationStatus column
-- 042			N Sharkie		2020-10-22				Updated logoc for FTBTL and stress test rate to use cte which had been missed
-- 043			R Callan		2021-01-06				Added in UnderwritingMandateLevel and UWMandateLevelOrder which is used in the conversion reporting
-- 044			R Callan		2021-01-21				Added in columns for NoBOIVA_3yr (Count) and ValueBOIVA_3yr (Value) and new column for YoungestBorrower
-- 													for use in the ConLimits report.
-- 045			N Sharkie		2021-03-10				updated stress test rate for residentil
-- 046			R Callan		2021-03-10				updated with new fields for InArrears and RevertNotRedeemed for Strats prameters
-- 047			R Callan		2021-03-18				Changed InArrears to be TrueArrearsRatio
-- 048			R Callan		2021-03-19				Removeing the InArrears/TrueArrearsRatio moved to the sp_Strats instead
-- 049			R Callan		2021-04-13				Amned RevertNotRedeemed to expand the option in the paramater to allow tie up to the
-- 													Redemeptions and Reversions report.
-- 050			R Callan		2021-04-14				Changed the RevertNotRedeemed to fix a spelling issue
-- 051			N Sharkie		2021-08-27				Added Monthly rental values from property details table for rental and ICR columns
-- 052			R Callan		2022-04-10				Updated the join for the BuilderVendorDeposit to have Distinct in the select. Underwriter put in two entires which broker the daily load.
-- 053			N Sharkie		2022-06-20				changed to use apps in temp table instead of using in big query
-- 054			N Sharkie		2022-07-06				added dbo schema to the proc name and when dropping and recreating the table at end
-- 055			R Callan		2022-12-07				Adding in the SecuritisationTag andSecuritisationFlag for use in the Strats reports
-- 056			N Sharkie		2023-04-01				Added code to identify adjusted BTL rental apps which would fail after base rate increase
-- 057			R Ronald		2023-02-01				Added ICRAdjusted column to calculate ICR for accounts with adjusted rental income. Changed join on reportinggroups (#Groups} to group by adjusted ICR
-- 058			R Callan		2023-05-30				Updated to fix missing TMLScore default value off 464 put if NULL.   Change to the
-- 													IncomeMultiple to fix divide by zero issue by changing the check to ISNULL(aff.GrossIncomeIncludingCreditsTotal, 0) = 0
-- 													and updating the #apps temp table to only have one application ref of M001415492 (pre upgraded declined app they tired to bring back)
-- 059			K Cowie			2023-08-31				Update to ICR to include calculation for Residential2 loans and added in new join to vw_paymentschedule
-- 060			R Callan		2023-10-20				Updated the EquityGiftedDeposit join to vw_DepositSources as bring back duplicate records.  Join changed
-- 													to select from the view and group of amount by applciation refence.
-- 061			R Callan		2023-10-24				Columns being moved from sp_Strats to the populate scirpt as needed for the Power BI report and should be here.
-- 													New temp tables added for performance. #creditref,#Arrears, #Arrears24, #mpsul, #usd.  Changed the name to Populate Strats Table.
-- 													Option (Recomplie) added after the #apps temp table to help with performance.  Columns added from the #apps, join to the Products table and cref join
-- 													UADate, ProductDateActive, NoDebtManagementPlans.
-- 													New temp table #Strats2 added which takes the data from #Strats and used to add on the new joins, done to help with performance.
-- 													Error checking section amended to look at new temp table #Strats2 instead of the original one #Strats.
-- 													StressTestRate reversionrate for residential has been change from 3 to 1
-- 062			K Cowie			2023-10-31				Added in to the where clause in the pay join in the calcs CTE AND tapps.ApplicationRef <> 'M001383127' to exclude
-- 													redeemed case which has an issue as not closed properly and causing divide by 0 issue - this is only temp until fixed
-- 063			N Sharkie		2023-11-03				added join to product history table in calcs CTE to get original product details and not pick up PT products
-- 064			R Callan		2023-11-24				Updated ProductRange and ReferralFlag to have ISNULL around them as data missing from the Strats Report.
-- 													ISNULL then ProductRange = Unknown and ReferralFlag = 0
-- 065			G Thirupathi	2024-01-29				Set the default value to 0 instead of NULL for InitialTermYears  & InitialTermMonths (tagged with (0129))
-- 066			N Sharkie		2024-02-08				Tidied up to imnprove run time - See JIRA TMLBIBAU-6969 for details.
-- 067			M Lee			2024-06-21				Added CASE statements to LIRFlags, LendingIntoRetirement and RetirementFlag columns to assess
-- 													loan type and use the appropriate columns from the customer table dependent on whether it's 24AM or not.
-- 068			G Thirupathi	2024-07-15				Updated the Repayment Type to be populated from the Applications Table instead of DIMCO
-- 													Added PT Date column (JIRA 8041)
-- 069			R Callan		2024-07-17				temp #usd table section update to remove vw_UnsecredSecuredDefaults and use vw_UnsecuredSecuredDefaults instead.
-- 070			M Lee			2024-09-12				Changed contents of temp table #Arrears24 so that it uses query from tbl_PaymentProfiles in place of old fn_GetArrears(24)
-- 													Brings in more unsecured loan account types for consideration for impaired flag in line with MLAR requirements.
-- 071			H Rielly		2024-12-10		9838	Update to include BML Placeholders and Origination Source Column
-- 072			H Rielly		2025-06-19		17796	Update BML temp tables to fix joins and allow BML data to come in to table.
-- 073			G Thirupathi	2025-07-01		18084	Updated AnnualRentalIncome to match TML logic by calculating it as MonthlyRentalIncome * 12 where it was previously NULL
-- 													Added the TML_DW prefix to any missing references.
-- 074		    K Seshasayee	2025-07-25		18538   INNER JOIN at line 1844 amended to align with dev script.
-- 075			N Sharkie		2025-11-21		20958	Fix for too large lease term
-- 076			R Callan		2026-03-12		22546	Changes for performance See Jira 22546 for full details.   Changes add temp tables, removed select * to show columns
-- 													required.   Change GetApplicaitons Function to use the table instead.  Change joins from tables to the temp tables.
-- 													Change date formatting.
-- 077			R Callan		2026-03-23		22930   Adding in temp table #visa for TML. New column called HasWorkingVisa for both TML and BML
-- 													TML will populated form the new temp table.  BML will be 0 until the underlying
-- 													data issues are fixed. New column HasWorkingVisa added to the final selects.
-- 													Temp table #apps updated to use table instead of function.
-- 													BML loan amount and BML residential LTV segment update statements added to bring
-- 													back the data for these columns.
-- 													All commented code that is no longer required has been removed.
-- ******************************************************************************************************************
-- 
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- get runtime - use for logging end time
DECLARE @runTime DATETIME = GETDATE();
DECLARE @procedureName SYSNAME = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID);

BEGIN TRY
---------------------------------------------------------------------------------------------------
--LOGGING
---------------------------------------------------------------------------------------------------
/*
LOGGING INFORMATION 
-- update parameters when creating
*/

-- get runtime - use for logging end time

INSERT INTO TML_DW.dbo.log_StoredProcedureRuns (ProcedureName, ProcedureUse, ParametersUsed, RunTime)
VALUES (@procedureName
		  , 'ETL' 
		  , NULL
		  , @runTime
	   );

---------------------------------------------------------------------------------------------------
-- QUERY SECTION
---------------------------------------------------------------------------------------------------
/*
    internal 
*/
DECLARE @cobDate DATE = DATEADD(d, -1, GETDATE())
DECLARE @cobid INT;
SET @cobid = CONVERT(int, CONVERT(char(8), @cobDate, 112));

DECLARE @endDate DATE; 
SET @endDate = DATEADD(day, -1, getDate());

DECLARE @endcob INT;
SET @endcob = CONVERT(int, CONVERT(char(8), @endDate, 112));
---------------------------------------------------------------------------------------------


IF OBJECT_ID('tempdb..#groups') IS NOT NULL
DROP TABLE #groups;

SELECT CategoryGroup, CategoryName, MinValue, MaxValue, Orderno INTO #groups
FROM TML_DW.dbo.vw_ReportingCategories;

CREATE CLUSTERED INDEX IDX_Groups1 ON #groups(CategoryGroup);
CREATE INDEX IDX_Groups2 ON #groups(OrderNo);
----------------------------------------------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#apps') IS NOT NULL
DROP TABLE #apps;

SELECT ReportDate, COBID
	, ApplicationRef = ApplicationRef COLLATE DATABASE_DEFAULT
	, DIM_CO_Application_DWSK, Environment, LoanType, RepaymentType, LatestStatus, Applicants
	, CustomerType, MortgageType, ProductCode, Product, ProductTier, ProductMaxLTV, ProductFeature
	, TermInMonths, AppInterestRate, LoanAmount, OpeningCapitalBalance, OriginalLTV, CILTV
	, RNScore, TMLScore, FirstTimeBuyer, SelfEmployedFlag, DIPCreatedDate, DIPSubmitDate
	, DipAcceptDate, UADate, AppDate, FirstOfferDate, LatestOfferDate, ExpectedCompDate
	, CompDate, AccountNo, AccountClosedDate, ReversionDate, RevertedFlag, CurrentBalance
	, ActualCurrentBalance, InterestRate, ReversionRate, SCDStatus, Securitised, SecuritisationTag
	, SecuritisationStatus, SecuritisationFlag, PTDate, OriginationSource
INTO #apps	
FROM TML_DW.dbo.tbl_ApplicationsFunctionDaily
WHERE  ApplicationRef NOT IN ('M001415492')
--WHERE ApplicationRef = 'M001342559'

OPTION (RECOMPILE);

CREATE CLUSTERED INDEX IDX_App1 ON #apps(ApplicationRef);
----------------------------------------------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#tapps') IS NOT NULL
DROP TABLE #tapps;

SELECT ApplicationRef, AccountNo, PTDate, LoanType, RepaymentType, LoanAmount, AppInterestRate
	, ProductCode, Product, AppDate, DipAcceptDate
INTO #tapps
FROM TML_DW.dbo.tbl_Applications

CREATE CLUSTERED INDEX IDX_TApp1 ON #tapps(ApplicationRef);
----------------------------------------------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#dimcapps') IS NOT NULL
DROP TABLE #dimcapps;

SELECT ApplicationRef = dapp.ApplicationRef COLLATE DATABASE_DEFAULT , dapp.IsRegulated, dapp.IsDebtConsolidation, dapp.IsHomeImprovement, dapp.IsSharedOwnership, dapp.IsCapitalRaising
			, dapp.SCDStatus
INTO #dimcapps
FROM DPR_DW.dbo.DIM_CO_Application dapp 
INNER JOIN #apps app ON app.ApplicationRef = dapp.ApplicationRef COLLATE DATABASE_DEFAULT 
								AND dapp.SCDStatus = 'C'

----------------------------------------------------------------------------------------------------------------------
-- Credit calcs
IF OBJECT_ID('tempdb..#creditref') IS NOT NULL
DROP TABLE #creditref;

SELECT cr.ApplicationRef 
, NoBo6m = SUM(cr.App1_BONo_6m + cr.App2_BONo_6m + cr.App3_BONo_6m + cr.App4_BONo_6m), BoVal6m = SUM(cr.App1_BOVal_6m + cr.App2_BOVal_6m + cr.App3_BOVal_6m + cr.App4_BOVal_6m)
, NoBo1yr = SUM(cr.App1_BONo_1yr + cr.App2_BONo_1yr + cr.App3_BONo_1yr + cr.App4_BONo_1yr), BoVal1yr = SUM(cr.App1_BOVal_1yr + cr.App2_BOVal_1yr + cr.App3_BOVal_1yr + cr.App4_BOVal_1yr)
, NoBo2yr = SUM(cr.App1_BONo_2yr + cr.App2_BONo_2yr + cr.App3_BONo_2yr + cr.App4_BONo_2yr), BoVal2yr = SUM(cr.App1_BOVal_2yr + cr.App2_BOVal_2yr + cr.App3_BOVal_2yr + cr.App4_BOVal_2yr)
, NoBo3yr = SUM(cr.App1_BONo_3yr + cr.App2_BONo_3yr + cr.App3_BONo_3yr + cr.App4_BONo_3yr), BoVal3yr = SUM(cr.App1_BOVal_3yr + cr.App2_BOVal_3yr + cr.App3_BOVal_3yr + cr.App4_BOVal_3yr)
, NoBo4yr = SUM(cr.App1_BONo_4yr + cr.App2_BONo_4yr + cr.App3_BONo_4yr + cr.App4_BONo_4yr), BoVal4yr = SUM(cr.App1_BOVal_4yr + cr.App2_BOVal_4yr + cr.App3_BOVal_4yr + cr.App4_BOVal_4yr)
, NoBo6yr = SUM(cr.App1_BONo_6yr + cr.App2_BONo_6yr + cr.App3_BONo_6yr + cr.App4_BONo_6yr), BoVal6yr = SUM(cr.App1_BOVal_6yr + cr.App2_BOVal_6yr + cr.App3_BOVal_6yr + cr.App4_BOVal_6yr)
, NoIVA1yr = SUM(cr.App1_IVANo_1yr + cr.App2_IVANo_1yr + cr.App3_IVANo_1yr + cr.App4_IVANo_1yr), IVAVal1yr = SUM(cr.App1_IVAVal_1yr + cr.App2_IVAVal_1yr + cr.App3_IVAVal_1yr + cr.App4_IVAVal_1yr)
, NoIVA2yr = SUM(cr.App1_IVANo_2yr + cr.App2_IVANo_2yr + cr.App3_IVANo_2yr + cr.App4_IVANo_2yr), IVAVal2yr = SUM(cr.App1_IVAVal_2yr + cr.App2_IVAVal_2yr + cr.App3_IVAVal_2yr + cr.App4_IVAVal_2yr)
, NoIVA3yr = SUM(cr.App1_IVANo_3yr + cr.App2_IVANo_3yr + cr.App3_IVANo_3yr + cr.App4_IVANo_3yr), IVAVal3yr = SUM(cr.App1_IVAVal_3yr + cr.App2_IVAVal_3yr + cr.App3_IVAVal_3yr + cr.App4_IVAVal_3yr)
, NoIVA6yr = SUM(cr.App1_IVANo_6yr + cr.App2_IVANo_6yr + cr.App3_IVANo_6yr + cr.App4_IVANo_6yr), IVAVal6yr = SUM(cr.App1_IVAVal_6yr + cr.App2_IVAVal_6yr + cr.App3_IVAVal_6yr + cr.App4_IVAVal_6yr)
INTO #creditref 
FROM TML_DW.dbo.tbl_CreditRefLatest cr
INNER JOIN #apps a ON a.ApplicationRef = cr.ApplicationRef
WHERE a.OriginationSource = 'TML'
GROUP BY cr.ApplicationRef

--BML Placeholder

INSERT INTO #creditref
	(
		  ApplicationRef
		, NoBo6m		
		, NoBo1yr		
		, NoBo2yr		
		, NoBo3yr		
		, NoBo4yr		
		, NoBo6yr		
		, NoIVA1yr		
		, NoIVA2yr		
		, NoIVA3yr		
		, NoIVA6yr		
	)

(
SELECT 
  ApplicationRef = a.ApplicationRef
, NoBo6m		 = NULL
, NoBo1yr		 = NULL
, NoBo2yr		 = NULL
, NoBo3yr		 = NULL
, NoBo4yr		 = NULL
, NoBo6yr		 = NULL
, NoIVA1yr		 = NULL
, NoIVA2yr		 = NULL
, NoIVA3yr		 = NULL
, NoIVA6yr		 = NULL
FROM #apps a
WHERE a.OriginationSource = 'BML'
)

CREATE CLUSTERED INDEX IDX_App2 ON #creditref(ApplicationRef);

--SELECT * 
--FROM #creditref

----------------------------------------------------------------------------------------------------------------------
-- Arrears data at the report end and only accounts in #apps

IF OBJECT_ID('tempdb..#Arrears') IS NOT NULL
DROP TABLE #Arrears;

SELECT ad.* INTO #Arrears
FROM TML_DW.dbo.tbl_ArrearsDaily ad
INNER JOIN #apps a ON a.AccountNo = ad.AccountNo
WHERE ad.COBDATE = @endDate AND a.OriginationSource = 'TML';

--BML Placeholder
INSERT INTO #Arrears
	(
		COBID
	  , COBDate
	  , AccountNo
	  , ArrearsEpisodeNo
	  , ArrearsStart
	  , ArrearsEnd
	  , MonthsInArrears
	  , ArrearsBalance
	  , CurrentMonthlyPayments
	  , ArrearsRatio
	  , AgedDebt
	  , DIM_CO_ArrearsEpisode_DWSK
	  , LivePaymentHoliday
	  , PaymentHolidayPayment
	  , PaymentHolidayBalance
	  , PaymentHolidayRatio
	  , TrueArrearsStart
	  , TrueArrearsBalance
	  , TrueArrearsRatio
	  , RegulatedStartDate
	)

(SELECT
	@cobid	  -- COBID - int
  , GETDATE() -- COBDate - date
  , a.AccountNo	  -- AccountNo - varchar(20)
  , NULL	  -- ArrearsEpisodeNo - int
  , NULL	  -- ArrearsStart - date
  , NULL	  -- ArrearsEnd - date
  , NULL	  -- MonthsInArrears - int
  , NULL	  -- ArrearsBalance - decimal(10, 2)
  , NULL	  -- CurrentMonthlyPayments - decimal(10, 2)
  , NULL	  -- ArrearsRatio - decimal(10, 2)
  , ''		  -- AgedDebt - varchar(100)
  , NULL	  -- DIM_CO_ArrearsEpisode_DWSK - bigint
  , NULL	  -- LivePaymentHoliday - int
  , NULL	  -- PaymentHolidayPayment - decimal(10, 2)
  , NULL	  -- PaymentHolidayBalance - decimal(10, 2)
  , NULL	  -- PaymentHolidayRatio - decimal(10, 2)
  , NULL	  -- TrueArrearsStart - date
  , NULL	  -- TrueArrearsBalance - decimal(10, 2)
  , NULL	  -- TrueArrearsRatio - decimal(10, 2)
  , NULL	  -- RegulatedStartDate - date
  FROM #apps a
WHERE a.OriginationSource = 'BML'
AND a.AccountNo IS NOT NULL
)


----------------------------------------------------------------------------------------------------------------------
-- Secured and Unsecured Loan Account Types from PaymentProfiles with Max Arrears >= 3 in last 24 months

IF OBJECT_ID('tempdb..#Arrears24') IS NOT NULL
DROP TABLE #Arrears24;

SELECT ApplicationRef, COUNT(*) AS ArrearsTotal
INTO #Arrears24
FROM TML_DW.dbo.tbl_PaymentProfiles
WHERE AccountCode IN ('01','02','03','05','12','13','14','16','17','21','22','26','28','80')
AND MaxArrear24m >= 3
GROUP BY ApplicationRef

--BML Placeholder

INSERT INTO #Arrears24
	(
		  ApplicationRef
		, ArrearsTotal
	)

(SELECT
a.ApplicationRef -- ApplicationRef - varchar(250)
 , 0
   FROM #apps a
WHERE a.OriginationSource = 'BML'

	)


----------------------------------------------------------------------------------------------------------------------
-- Missed Payments Unsecred/Secured Loans

IF OBJECT_ID('tempdb..#mpsul') IS NOT NULL
DROP TABLE #mpsul;

SELECT mp.ApplicationRef, mp.SecuredUnsecured, mp.Missed3Mths, mp.Missed6Mths
	, mp.Missed12Mths, mp.Missed18Mths, mp.Missed24Mths, mp.MaxArrears24Mths
	, mp.Missed36Mths, mp.Missed48Mths, mp.Missed60Mths, mp.Missed72Mths
	, mp.LoanType
INTO #mpsul
FROM TML_DW.dbo.vw_MissPaymentsSecuredUnsecuredLoans mp
INNER JOIN #apps a ON a.ApplicationRef = mp.ApplicationRef
WHERE  A.OriginationSource = 'TML'

CREATE CLUSTERED INDEX IDX_MSUL1 ON #mpsul(ApplicationRef);

-- BML Placeholder

INSERT INTO #mpsul
	(
		ApplicationRef
	  , SecuredUnsecured
	  , Missed3Mths
	  , Missed6Mths
	  , Missed12Mths
	  , Missed18Mths
	  , Missed24Mths
	  , MaxArrears24Mths
	  , Missed36Mths
	  , Missed48Mths
	  , Missed60Mths
	  , Missed72Mths
	  , LoanType
	)
(SELECT
	a.ApplicationRef-- ApplicationRef - varchar(250)
  , ''	 -- SecuredUnsecured - varchar(9)
  , NULL -- Missed3Mths - int
  , NULL -- Missed6Mths - int
  , NULL -- Missed12Mths - int
  , NULL -- Missed18Mths - int
  , NULL -- Missed24Mths - int
  , NULL -- MaxArrears24Mths - int
  , NULL -- Missed36Mths - int
  , NULL -- Missed48Mths - int
  , NULL -- Missed60Mths - int
  , NULL -- Missed72Mths - int
  , NULL -- LoanType - varchar(255)
     FROM #apps a
WHERE a.OriginationSource = 'BML')



----------------------------------------------------------------------------------------------------------------------
-- Unsecred/Secured Defaults

IF OBJECT_ID('tempdb..#usd') IS NOT NULL
DROP TABLE #usd;

SELECT usd.ApplicationRef, usd.SecuredUnsecured, usd.Default1m, usd.Default3m, usd.Default6m
	, usd.Default12m, usd.Default18m, usd.Default24m, usd.Default36m, usd.Default48m
	, usd.Default60m, usd.Default72m, usd.DefaultedBalance, usd.LoanType 
INTO #usd
FROM TML_DW.dbo.vw_UnsecuredSecuredDefaults usd
INNER JOIN #apps a ON a.ApplicationRef = usd.ApplicationRef
WHERE a.OriginationSource = 'TML'



-- BML Placeholder

INSERT INTO #usd
	(
		ApplicationRef
	  , SecuredUnsecured
	  , Default1m
	  , Default3m
	  , Default6m
	  , Default12m
	  , Default18m
	  , Default24m
	  , Default36m
	  , Default48m
	  , Default60m
	  , Default72m
	  , DefaultedBalance
	  , LoanType
	)
VALUES
(	NULL -- ApplicationRef - varchar(250)
  , ''	 -- SecuredUnsecured - varchar(9)
  , NULL -- Default1m - int
  , NULL -- Default3m - int
  , NULL -- Default6m - int
  , NULL -- Default12m - int
  , NULL -- Default18m - int
  , NULL -- Default24m - int
  , NULL -- Default36m - int
  , NULL -- Default48m - int
  , NULL -- Default60m - int
  , NULL -- Default72m - int
  , NULL -- DefaultedBalance - decimal(38, 2)
  , NULL -- LoanType - varchar(255)
	)


CREATE CLUSTERED INDEX IDX_USD1 ON #usd(ApplicationRef);

----------------------------------------------------------------------------------------------------------------------

DECLARE @RateDate date = CONVERT(date, '20241117', 112);

DECLARE @BBR     decimal(10,4),
        @TBRBTL  decimal(10,4),
        @TBRRESI decimal(10,4);

SELECT  @BBR     = dr.BBR,
        @TBRBTL  = dr.TBRBTL,
        @TBRRESI = dr.TBRRESI
FROM TML_DW.dbo.fn_DailyRates(@RateDate) dr;


-----------------------------------------------------------
/*
	output the strat data
*/

IF OBJECT_ID('tempdb..#calcs') IS NOT NULL
DROP TABLE #calcs;

SELECT app.ApplicationRef
, IncomeMultiple = IIF(ISNULL(aff.GrossIncomeIncludingCreditsTotal, 0) = 0
				, 0
				, IIF(app.LoanType = 'BTL'
						, 0
						, CONVERT(DECIMAL(8,2), ROUND(app.LoanAmount / aff.GrossIncomeIncludingCreditsTotal,2)))
					)
, MonthlyRentalIncome = CONVERT(DECIMAL(20,2), COALESCE(so.MonthlyRentalIncome, pd.MonthlyRentalIncome, aff.MonthlyRentalIncome))
, StressTestRate = IIF(
					app.LoanType IN ('Residential', 'Residential2')
					, CASE 
						WHEN LEFT(app.Product, 1) = '5' THEN app.AppInterestRate  -- five year product origination
						ELSE app.ReversionRate + 1 -- two year product origination  --ticket raised to look at
					END
					, CASE 
						WHEN LEFT(app.Product, 1) = '5' THEN app.AppInterestRate  -- five year product origination
						WHEN LEFT(app.Product, 1) = '2' AND app.AppInterestRate + 2 < 5.5 THEN 5.5
						ELSE app.AppInterestRate + 2 -- two year product origination
					END
				)
, StressedMonthlyInterestPayment = CONVERT(DECIMAL(20, 6),(app.LoanAmount * (IIF(
																		app.LoanType IN ('Residential', 'Residential2')
																		, CASE 
																			WHEN LEFT(app.Product, 1) = '5' THEN app.AppInterestRate  -- five year product origination
																			ELSE app.ReversionRate + 1 -- two year product origination
																		END
																		, CASE 
																			WHEN LEFT(app.Product, 1) = '5' THEN app.AppInterestRate  -- five year product origination
																			WHEN LEFT(app.Product, 1) = '2' AND app.AppInterestRate + 2 < 5.5 THEN 5.5
																			ELSE app.AppInterestRate + 2 -- two year product origination
																		END
																	) /100)
									/12))
, ICR = IIF(
	app.LoanType = 'Residential'
	, 1.40
	, IIF ( 
	app.LoanType = 'Residential2'
	, CONVERT(DECIMAL(6,2), aff.NetIncome/pay.PaymentAmount)
	, CONVERT(DECIMAL(6,2), COALESCE(so.MonthlyRentalIncome, pd.MonthlyRentalIncome, aff.MonthlyRentalIncome)
		/ (app.LoanAmount * (CASE 
										WHEN LEFT(app.Product, 1) = '5' THEN app.AppInterestRate  -- five year product origination
										WHEN LEFT(app.Product, 1) = '2' AND app.AppInterestRate + 2 < 5.5 THEN 5.5
										ELSE app.AppInterestRate + 2 -- two year product origination
									END /100)
					/12)
		)
	)
)
, ICRAdjusted = IIF(
	app.LoanType = 'Residential'
	, 1.40
	, CONVERT(DECIMAL(6,2), (COALESCE(so.MonthlyRentalIncome, pd.MonthlyRentalIncome, aff.MonthlyRentalIncome) + ISNULL(rentAdjust.RentAdjustment, 0))
		/ (app.LoanAmount * (CASE 
										WHEN LEFT(app.Product, 1) = '5' THEN app.AppInterestRate  -- five year product origination
										WHEN LEFT(app.Product, 1) = '2' AND app.AppInterestRate + 2 < 5.5 THEN 5.5
										ELSE app.AppInterestRate + 2 -- two year product origination
									END /100)
					/12)
		)
	)
, RentAdjustedForAffPass = ISNULL(rentAdjust.RentAdjustment, 0)
, app.ReversionRate
, app.Product
, app.PTDate

INTO #calcs
FROM (
SELECT app.ApplicationRef, app.LoanType, app.LoanAmount, app.AppInterestRate--, app.ReversionRate
, Product = ISNULL(prop.Product, app.Product), app.PTDate
, ReversionRate = IIF(
					app.AppDate > '2020-10-21' OR reverttable.productcode >= '1925' 
					, IIF(app.LoanType = 'BTL'	
									, dr.TBRBTL + CONVERT(DECIMAL(4,2), revertTable.revertMargin)
									, dr.TBRRESI + CONVERT(DECIMAL(4,2), revertTable.revertMargin)
							)
					, CONVERT(NUMERIC(4,2), dr.BBR + revertTable.RevertMargin)
					)							
FROM TML_DW.dbo.tbl_Applications app
CROSS APPLY TML_DW.dbo.fn_DailyRates(CONVERT(DATE, CONVERT(VARCHAR(10), @cobid))) dr 
LEFT OUTER JOIN TML_DW.dbo.tbl_ProductHistory ph ON app.AccountNo = ph.AccountNo
											AND ph.VersionNo = 1 -- original product details
LEFT OUTER JOIN TML_DW.dbo.tbl_Products prop ON ph.ProductCode = prop.ProductCode
LEFT OUTER JOIN (
	SELECT  ProductCode, tier, ltv, (RevertAdd*100) AS RevertMargin
	FROM TML_DW.dbo.tbl_Products
) revertTable ON app.ProductCode = revertTable.ProductCode
WHERE app.DipAcceptDate IS NOT NULL
) app
LEFT OUTER JOIN (
	SELECT ApplicationRef = pvt.IdentityValue
	, MonthlyRentalIncome = CONVERT(DECIMAL(20, 2), pvt.MonthlyRentalIncome)
	FROM (   
		SELECT TableName, IdentityColumn, IdentityValue, UpdateColumn, UpdateValue
		, OverrideReason
		FROM TML_DW.dbo.tbl_Overrides 
	) AS P
	PIVOT
		(  
				MAX(UpdateValue) FOR UpdateColumn IN (MonthlyRentalIncome)
		) AS pvt
	WHERE pvt.TableName = 'sp_PopulateStratsTable'
	AND pvt.IdentityColumn = 'ApplicationRef'
) so ON app.ApplicationRef = so.ApplicationRef COLLATE DATABASE_DEFAULT
LEFT OUTER JOIN TML_DW.dbo.tbl_AffordabilityLatest aff ON aff.ApplicationRef = app.ApplicationRef
LEFT OUTER JOIN TML_DW.dbo.tbl_PropertyDetails pd ON app.ApplicationRef = pd.ApplicationRef
LEFT OUTER JOIN 	(	
	SELECT SUM(pay.PaymentAmount) AS PaymentAmount,
	pay.AccountNo
	FROM TML_DW.dbo.vw_PaymentSchedule pay
	INNER JOIN TML_DW.dbo.tbl_Applications tapps ON tapps.ApplicationRef = pay.AccountNo COLLATE	 DATABASE_DEFAULT
	WHERE tapps.LoanType <> 'Residential' AND pay.DIM_CO_PaymentSchedule_SSK2 = '2'
	AND tapps.ApplicationRef <> 'M001383127'
	GROUP BY pay.AccountNo
	)pay ON pay.AccountNo = app.ApplicationRef COLLATE DATABASE_DEFAULT 
-- change to get rental adjustment put in to make pass affordability after base rate would cause failure
LEFT OUTER JOIN (
	SELECT a.ApplicationRef
	, RentAdjustment = CONVERT(DECIMAL(10,2), fmaVal.HostID)
	FROM DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAValuation fmaVal 
	INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAProperty prp ON fmaVal.PropertyID = prp.Id
	INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAPropertySurveyDetails prpsurdet ON prp.PropertySurveyDetailsId = prpsurdet.Id 
	INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAPropertySummary prpsum ON prpsurdet.PropertySummaryId = prpsum.Id 
	INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMASecurityValuation secVal ON prpsum.SecurityValuationId = secVal.Id 	
																					AND secVal.IsActiveValuation = 1
	INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMASecurity sec ON secVal.SecurityId = sec.Id
	INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMALoanDetails loandet ON sec.LoanDetailsId = loandet.Id
	INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAApplication a ON loandet.ApplicationId = a.Id
	WHERE 1=1 
	AND fmaVal.HostID <> ''
	AND ISNUMERIC(fmaVal.HostID) = 1
	) rentAdjust ON app.ApplicationRef = rentAdjust.ApplicationRef COLLATE DATABASE_DEFAULT;


--BML Placeholder

INSERT INTO #calcs
	(
		ApplicationRef
	  , IncomeMultiple
	  , MonthlyRentalIncome
	  , StressTestRate
	  , StressedMonthlyInterestPayment
	  , ICR
	  , ICRAdjusted
	  , RentAdjustedForAffPass
	  , ReversionRate
	  , Product
	  , PTDate
	)
VALUES
(	''	 -- ApplicationRef - varchar(255)
  , 0
  , 0
  , 0
  , 0
  , 0
  , 0
  , 0
  , 0
  , NULL
  , NULL -- PTDate - date
	)

	CREATE CLUSTERED INDEX IDX_Calc1 ON #calcs(ApplicationRef);

----------------------------------------------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#Vals') IS NOT NULL
DROP TABLE #Vals;

	 SELECT ApplicationRef
	 , CustomerProvidedValuation = MAX(IIF(ValuationType = 'CustomerProvided', IIF(PropertyValue > PresentValue, PropertyValue, PresentValue) , 0))
	 , ActualValuation = MAX(IIF(ValuationType <> 'CustomerProvided', PropertyValue, 0))
	 INTO #Vals
	 FROM TML_DW.dbo.vw_Valuations
	 GROUP BY ApplicationRef

	 CREATE CLUSTERED INDEX IDX_Vals1 ON #Vals(ApplicationRef);



IF OBJECT_ID('tempdb..#vw_IntermediaryTree') IS NOT NULL
DROP TABLE #vw_IntermediaryTree;

SELECT
  it.Broker
, it.Network
, it.Club
, it.Packager
, it.IntermediaryRoute
, it.DIM_CO_Application_DWSK
INTO #vw_IntermediaryTree
FROM TML_DW.dbo.vw_IntermediaryTree it

----------------------------------------------------------------------------------------------------------------------	
-- debtcon details

IF OBJECT_ID('tempdb..#debtcon') IS NOT NULL
DROP TABLE #debtcon;

SELECT debtCon.ApplicationRef
     , debtCon.DebtConsolidation
     , debtCon.SecuredLoanRepaid
     , debtCon.SecuredLoanCount
     , debtCon.TrueDebtCon
     , debtCon.UnsecuredDebtsToConsolidate
     , debtCon.HomeImprovements
     , debtCon.Other
     , debtCon.MoneyWithdrawn
     , debtCon.BoEIsXFKVAD
     , debtCon.BoEIsXFKVAC
INTO #debtcon
FROM TML_DW.dbo.vw_DebtConsolidation debtCon

----------------------------------------------------------------------------------------------------------------------
-- Application Fees Details
IF OBJECT_ID('tempdb..#afees') IS NOT NULL
DROP TABLE #afees;

SELECT afees.ApplicationRef, afees.CompletionFee, afees.CompletionFeeAdded, afees.TransferFee, afees.TransferFeeAdded 
INTO #afees
FROM TML_DW.dbo.vw_ApplicationFees afees 

----------------------------------------------------------------------------------------------------------------------
-- Portfolio Count details
IF OBJECT_ID('tempdb..#PortCount') IS NOT NULL
DROP TABLE #PortCount;

SELECT ApplicationRef, PortfolioCount, PortfolioFlag
INTO #PortCount
FROM TML_DW.dbo.vw_PortfolioCount

---------------------------------------------------------------------------------------------	 	
--TML Visa data

IF OBJECT_ID('tempdb..#visa') IS NOT NULL
DROP TABLE #visa;

SELECT appl.ApplicationRef, WorkingVisa = 1
INTO #visa
FROM DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMARequirement fmareq
INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAApplicant SynA
    ON fmareq.ApplicantID = SynA.ID
INNER JOIN TML_DW.dbo.tbl_Applicants appl
    ON SynA.ID = appl.ApplicantId
WHERE fmareq.Code IN (453, 454, 455, 456)
GROUP BY
    appl.ApplicationRef;

----------------------------------------------------------------------------------------------------------------------
-- now create temp table
IF OBJECT_ID('tempdb..#strats') IS NOT NULL
DROP TABLE #strats;

SELECT 
  COBID = @cobid
, COBDate = @cobDate
, ApplicationRef = app.ApplicationRef
, app.LoanType
, app.DipCreatedDate
, app.DipAcceptDate
, app.DIPSubmitDate
, DateDIPAccept = app.DIPAcceptDate
, AppDate = app.AppDate
, FirstOfferDate = app.FirstOfferDate
, ReofferDate = app.LatestOfferDate
, CompDate = app.CompDate
, LatestStatus = app.LatestStatus
, app.Environment
, ReportStatus = IIF( app.AccountClosedDate IS NOT NULL, 'Redeemed', repStat.ReportStatus)
, NoApplicants = app.Applicants
, Cust1MaritalStatus = cust1.MaritalStatus 
, Cust2MaritalStatus = cust2.MaritalStatus 
, Cust1EmploymentType = cust1.EmploymentType 
, Cust2EmploymentType = cust2.EmploymentType 
, Cust1DateOfBirth = cust1.DateOfBirth
, Cust2DateOfBirth = cust2.DateOfBirth
, Cust1Income = IIF(cust1.CustomerNo = 1, aff.GrossIncomeExcludingCreditsApp1, aff.GrossIncomeExcludingCreditsApp2) 
, Cust2Income = IIF(cust1.CustomerNo = 1, aff.GrossIncomeExcludingCreditsApp2, aff.GrossIncomeExcludingCreditsApp1) 
, CombinedIncome = aff.GrossIncomeIncludingCreditsTotal
, IncomeMultipleOLD = IIF((aff.GrossIncomeApp1 + ISNULL(aff.GrossIncomeApp2, 0)) = 0 , 0 , IIF(app.LoanType = 'BTL', 0, CONVERT(DECIMAL(8,2), ROUND(app.LoanAmount / (aff.GrossIncomeApp1 + ISNULL(aff.GrossIncomeApp2, 0)),2))))
, i.IncomeMultiple -- NS 29/10/19
, Cust1AgeAtApp = CASE
						WHEN cust1.DateOfBirth IS NULL
						OR COALESCE(app.AppDate, app.DipAcceptDate) IS NULL
						THEN NULL
						ELSE
						DATEDIFF(YEAR, cust1.DateOfBirth, COALESCE(app.AppDate, app.DipAcceptDate))
						- CASE
								WHEN DATEADD(
												YEAR,
												DATEDIFF(YEAR, cust1.DateOfBirth, COALESCE(app.AppDate, app.DipAcceptDate)),
												cust1.DateOfBirth
											) > COALESCE(app.AppDate, app.DipAcceptDate)
								THEN 1 ELSE 0
						END
				END
, Cust2AgeAtApp = CASE WHEN cust2.DateOfBirth IS NULL
								OR COALESCE(app.AppDate, app.DipAcceptDate) IS NULL
							THEN NULL
						ELSE DATEDIFF(YEAR, cust2.DateOfBirth, COALESCE(app.AppDate, app.DipAcceptDate))
								- CASE WHEN DATEADD(YEAR,DATEDIFF(YEAR, cust2.DateOfBirth, COALESCE(app.AppDate, app.DipAcceptDate)),
										cust2.DateOfBirth ) > COALESCE(app.AppDate, app.DipAcceptDate)
										THEN 1 
										ELSE 0
								END
				END
, YoungestAgeAtApp = CASE WHEN applicants.YoungestDOB IS NULL
									OR app.AppDate IS NULL
								THEN NULL
							ELSE DATEDIFF(YEAR, applicants.YoungestDOB, app.AppDate)
									- CASE WHEN DATEADD(YEAR,DATEDIFF(YEAR, applicants.YoungestDOB, app.AppDate),
													applicants.YoungestDOB) > app.AppDate
											THEN 1
										ELSE 0
									END
							END
, Cust1FirstTimeBuyer = IIF(cust1.FTBFlag = 1, 'True', 'False')
, Cust2FirstTimeBuyer = IIF(cust2.FTBFlag = 1, 'True', 'False')
, Cust1AgeatMaturity = (DATEDIFF(m,cust1.DateofBirth, COALESCE(app.CompDate, app.ExpectedCompDate, app.AppDate))+app.TermInMonths)/12
, Cust2AgeatMaturity = (DATEDIFF(m,cust2.DateofBirth, COALESCE(app.CompDate, app.ExpectedCompDate, app.AppDate))+app.TermInMonths)/12
, Cust1RetirementAge = cust1.RetirementAge 
, Cust2RetirementAge = cust2.RetirementAge
, Cust1RetirementDate = cust1.RetirementDate
, Cust2RetirementDate = cust2.RetirementDate
-----------
, Cust1LIRFlag = CASE 
				 WHEN app.LoanType = 'Residential'
				 THEN IIF(cust1.LIRFlag24AM = 1, 'Y', 'N')
				 ELSE IIF(cust1.LIRFlag = 1, 'Y', 'N')
				 END
, Cust2LIRFlag = CASE 
				 WHEN app.LoanType = 'Residential'
				 THEN IIF(cust2.LIRFlag24AM = 1, 'Y', 'N')
				 ELSE IIF(cust2.LIRFlag = 1, 'Y', 'N')
				 END
, LoanPurpose = app.MortgageType
, MortgageGroup = CASE WHEN app.MortgageType LIKE '%Remortgage%'
					   THEN 'Remortgage'
				   WHEN app.MortgageType = 'Purchase' AND app.FirstTimeBuyer = 1
					   THEN 'First Time Buyer'
				   ELSE 'Purchase'
			   END
, AppType = app.ProductTier 
, ProductTierJoin = IIF(
					ISNUMERIC(RIGHT(app.ProductTier, 1)) = '0' OR LEFT(app.ProductTier, 2) = 'RL'
					, 0
					, RIGHT(app.ProductTier, 1) + IIF(app.ProductTier LIKE 'TML%', 9, 0)
				)
, RepaymentType = tapps.RepaymentType
, CustomerLTV = CAST(ROUND((app.LoanAmount / vals.CustomerProvidedValuation) * 100,2) AS DECIMAL(20,2))
, OriginalLTV = app.OriginalLTV
, vals.ActualValuation
, CustomerProvidedValuation = CONVERT(DECIMAL(20,2), vals.CustomerProvidedValuation)
, ValAge = DATEDIFF(m, prop.ValuationDate, COALESCE(app.CompDate, app.ExpectedCompDate, GETDATE()))
, app.CILTV
, LoanAmount = app.LoanAmount
, InitialLoanRequested = app.LoanAmount
, GrossLoanAmount = app.OpeningCapitalBalance
, MortgagePreCompAmount = app.LoanAmount - ( (afees.CompletionFee * IIF(afees.CompletionFeeAdded = 0, 1, 0))  + (afees.TransferFee * IIF(afees.TransferFeeAdded = 0, 1, 0)) )
, MultipleFlag = IIF(app.LoanType = 'BTL' 
								, 0
								, IIF(
									 i.IncomeMultiple > 4.50 
									 , 1
									 , 0
								)	 
							)
, ExtraRemortgageBorrowing = (ISNULL(debtCon.DebtConsolidation, 0) + ISNULL(debtCon.HomeImprovements, 0) + ISNULL(debtCon.Other,0))
, dapp.IsHomeImprovement
, dapp.IsCapitalRaising
, IsDebtConsolidation = CONVERT(INT, dapp.IsDebtConsolidation)
, DebtConsolidationAmount = ISNULL(debtCon.DebtConsolidation, 0)
, InitialTermYears = ISNULL(app.TermInMonths, 0)/12   --(065)
, InitialTermMonths = ISNULL(app.TermInMonths, 0)     --(065)
, cust1.LoanMaturityDate
, app.ProductCode
, ProductTier = app.ProductTier
, ProductLTVBand = app.ProductMaxLTV
, ProductType = app.Product
, ProductGroup = CASE WHEN app.Product LIKE '%2 Year Tracker%'
					   THEN '2 Year Tracker'
				   WHEN app.Product LIKE '%2 Year Fixed%' 
					   THEN '2 Year Fixed'
				   WHEN app.Product LIKE '%5 Year Fixed%' 
					   THEN '5 Year Fixed'
				   ELSE 'Unknown'
			   END
, ProductFeature = CASE 
				    WHEN app.Product LIKE '%Semi-Exclusive%' THEN 'Semi-Exclusive'
				    WHEN app.Product LIKE '%Premier Exclusive%' THEN 'Premier Exclusive'
				    WHEN NULLIF(app.ProductFeature, '') IS NULL THEN 'Standard' --'N/A'
				    ELSE app.ProductFeature
				END
, NoCCJ_3m = cref.App1_CCJNo_3m + cref.App2_CCJNo_3m
, NoCCJ_6m = cref.App1_CCJNo_6m + cref.App2_CCJNo_6m
, NoCCJ_1yr = cref.App1_CCJNo_1yr + cref.App2_CCJNo_1yr
, ValueCCJ_1yr = cref.App1_CCJVal_1yr + cref.App2_CCJVal_1yr
, NoCCJ_2yr = cref.App1_CCJNo_2yr + cref.App2_CCJNo_2yr
, ValueCCJ_2yr = cref.App1_CCJVal_2yr + cref.App2_CCJVal_2yr
, NoCCJ_3yr = cref.App1_CCJNo_3yr + cref.App2_CCJNo_3yr
, ValueCCJ_3yr = cref.App1_CCJVal_3yr + cref.App2_CCJVal_3yr
, NoCCJ_4yr = cref.App1_CCJNo_4yr + cref.App2_CCJNo_4yr
, ValueCCJ_4yr = cref.App1_CCJVal_4yr + cref.App2_CCJVal_4yr
, NoCCJ_6yr = cref.App1_CCJNo_6yr + cref.App2_CCJNo_6yr
, ValueCCJ_6yr = cref.App1_CCJVal_6yr + cref.App2_CCJVal_6yr
, NoBOIVA_6yr = cref.App1_BONo_6yr + cref.App2_BONo_6yr + cref.App1_IVANo_6yr + cref.App2_IVANo_6yr
, ValueBOIVA_6yr = cref.App1_BOVal_6yr + cref.App2_BOVal_6yr + cref.App1_IVAVal_6yr + cref.App2_IVAVal_6yr
, NoBOIVA_3yr = cref.App1_BONo_3yr + cref.App2_BONo_3yr + cref.App1_IVANo_3yr + cref.App2_IVANo_3yr
, ValueBOIVA_3yr = cref.App1_BOVal_3yr + cref.App2_BOVal_3yr + cref.App1_IVAVal_3yr + cref.App2_IVAVal_3yr
, SecurityType = prop.PropertyType
, SecuritySubType = prop.PropertySubType
, prop.TenureType
, prop.LeaseRemaining
, LeaseAtEndOfTermYears = FLOOR(CONVERT(DECIMAL (5,1), IIF(prop.TenureType = 'Leasehold', IIF(prop.LeaseRemaining> 10000, 10000, prop.LeaseRemaining) - (app.TermInMonths / 12.0), 0) ))
, PropertyType = CASE
				WHEN prop.PropertySubType = 'Detached' THEN 'Detached'
				WHEN prop.PropertySubType = 'SemiDetached' THEN 'Semi-Detached'
				WHEN prop.PropertySubType LIKE '%Terrace%' THEN 'Terraced'
				WHEN prop.PropertyType IN ('House','Bungalow') THEN 'Detached'
				WHEN prop.PropertyType LIKE '%Flat%' THEN 'Flat'
				WHEN prop.PropertyType ='Maisonette' THEN 'Maisonette'
				WHEN prop.PropertyType = 'Other' THEN 'Other'
				WHEN prop.PropertyType = 'Unknown' THEN 'Unknown'
				ELSE 'Other'
			END
, prop.Region
, prop.NumberOfBedrooms
, it.Broker
, it.Network
, MortgageClub = it.Club
, it.Packager
, IntroducerType = CASE it.IntermediaryRoute 
				WHEN 'Packager' THEN 'Specialist Distributor'
				WHEN 'Broker' THEN 'Broker Direct'
				WHEN 'Club' THEN 'Mortgage Club'
				ELSE 'Network'
			   END
, CreditReferenceId = cref.CreditReferenceId
, RNScore = app.RNScore
, TMLScore = ISNULL(app.TMLScore, 464)
------------------------------------------------------------------------------
-- TEMP UNTIL HAVE TIME TO FIX SLOW JOIN
, ScoreTier = CASE
			 WHEN app.TMLScore >= 622 THEN 'Tier 1'
			 WHEN app.TMLScore BETWEEN 609 AND 621 THEN 'Tier 2'
			 WHEN app.TMLScore BETWEEN 589 AND 608 THEN 'Tier 3'
			 WHEN app.TMLScore BETWEEN 569 AND 588 THEN 'Tier 4'
			 WHEN app.TMLScore BETWEEN 557 AND 568 THEN 'Tier 5'
			 WHEN app.TMLScore BETWEEN 535 AND 556 THEN 'Tier 6'
			 WHEN app.TMLScore BETWEEN 523 AND 534 THEN 'Tier 7'
			 WHEN app.TMLScore BETWEEN 512 AND 522 THEN 'Tier 8'
			 WHEN app.TMLScore BETWEEN 465 AND 511 THEN 'Tier 9'
			 WHEN app.TMLScore <= 464 THEN 'Decline'
			 ELSE NULL
			END
, ScoreDistribution = CASE
				    WHEN app.TMLScore <= 440 THEN 'Band 01: <= 440'
				    WHEN app.TMLScore <= 460 THEN 'Band 02: 441-460'
				    WHEN app.TMLScore <= 480 THEN 'Band 03: 461-480'
				    WHEN app.TMLScore <= 500 THEN 'Band 04: 481-500'
				    WHEN app.TMLScore <= 520 THEN 'Band 05: 501-520'
				    WHEN app.TMLScore <= 540 THEN 'Band 06: 521-540'
				    WHEN app.TMLScore <= 560 THEN 'Band 07: 541-560'
				    WHEN app.TMLScore <= 580 THEN 'Band 08: 561-580'
				    WHEN app.TMLScore <= 600 THEN 'Band 09: 581-600'
				    WHEN app.TMLScore <= 620 THEN 'Band 10: 601-620'
				    WHEN app.TMLScore <= 640 THEN 'Band 11: 621-640'
				    WHEN app.TMLScore <= 660 THEN 'Band 12: 641-660'
				    WHEN app.TMLScore <= 680 THEN 'Band 13: 661-680'
				    WHEN app.TMLScore <= 700 THEN 'Band 14: 681-700' 
				    WHEN app.TMLScore >  700 THEN 'Band 15: > 700'
				    ELSE NULL
				  END

------------------------------------------------------------------------------
, SelfEmployedFlag = CONVERT(INT, app.SelfEmployedFlag)
, RetirementFlagOLD = CASE
				WHEN FLOOR(DATEDIFF(dd, cust1.DateOfBirth, app.AppDate) / 365.25) >= cust1.MinRetirementAge 
				    THEN 0 -- already past retirement age or age 70, whichever lower
				WHEN cust1.MinRetirementAge - DATEDIFF(dd, cust1.DateOfBirth, app.AppDate) / 365.25 > 0
				    AND cust1.MinRetirementAge - DATEDIFF(dd, cust1.DateOfBirth, app.AppDate) / 365.25 < 10
				    THEN 1 -- < 10 years to retirement from app
				WHEN 100.0 * (DATEDIFF(dd, cust1.DateOfBirth, app.AppDate) / 365.25 + (app.TermInMonths)/12.0 - cust1.MinRetirementAge)
					 / ((app.TermInMonths)/12.0) 
					  > 25 
				    THEN 1 -- > 25% of term extends beyond retirement age or age 70, whichever lower
				WHEN cust2.DateOfBirth IS NULL 
				    THEN 0 --no customer 2
				WHEN FLOOR(DATEDIFF(dd, cust2.DateOfBirth, app.AppDate) / 365.25) >= cust2.MinRetirementAge 
				    THEN 0 -- already past retirement age or age 70, whichever lower
				WHEN cust2.MinRetirementAge - DATEDIFF(dd, cust2.DateOfBirth, app.AppDate) / 365.25 > 0
				    AND cust2.MinRetirementAge - DATEDIFF(dd, cust2.DateOfBirth, app.AppDate) / 365.25 < 10
				    THEN 1 -- < 10 years to retirement from app
				WHEN 100.0 * (DATEDIFF(dd, cust2.DateOfBirth, app.AppDate) / 365.25 + (app.TermInMonths)/12.0 - cust2.MinRetirementAge)
					 / ((app.TermInMonths)/12.0) 
					  > 25 
				    THEN 1 -- > 25% of term extends beyond retirement age or age 70, whichever lower
				ELSE 0
				END
, LendingIntoRetirement = CASE
						  WHEN app.LoanType = 'Residential'
						  THEN IIF(cust1.LendingIntoRetirement24AM = 1 OR cust2.LendingIntoRetirement24AM = 1, 1, 0)
						  ELSE IIF(cust1.LendingIntoRetirement = 1 OR cust2.LendingIntoRetirement = 1, 1, 0)
						  END
, PercentagePastRetirement = IIF(cust1.PercentPastRetirement >= ISNULL(cust2.PercentPastRetirement, 0), cust1.PercentPastRetirement, cust2.PercentPastRetirement)
, RetirementFlag = CASE
				   WHEN app.LoanType = 'Residential'
				   THEN IIF(cust1.LIRFlag24AM = 1 OR cust2.LIRFlag24AM = 1, 1, 0)
				   ELSE IIF(cust1.LIRFlag = 1 OR cust2.LIRFlag = 1, 1, 0)
				   END
, RetirementFlagReason = NULLIF(IIF(cust1.LIRFlagSetBy IS NOT NULL, 'App1: ' + cust1.LIRFlagSetBy + ' ', '')
									 + IIF(cust2.LIRFlagSetBy IS NOT NULL, 'App2: ' + cust2.LIRFlagSetBy + ' ', ''), '')
, ImpairedFlag = IIF(
				arrears.ArrearsTotal IS NOT NULL OR
				cref.App1_IVANo_3yr + cref.App2_IVANo_3yr + cref.App1_BONo_3yr + cref.App2_BONo_3yr > 0 OR
				(cref.App1_CCJVal_3yr > 500 OR cref.App2_CCJVal_3yr > 500)
				, 1
				, 0
			)
, CCJsFlag = IIF(cref.App1_CCJNo_3yr + cref.App2_CCJNo_3yr > 0, 1, 0)
, app.FirstTimeBuyer
, NewBuildFlag = CONVERT(INT, prop.IsNewBuild)
, NewBuildIncentive = IIF(prop.IsNewBuild + ISNULL(incentive.WithIncentive, 0) = 2, 1, 0)
, ISNULL(referrals.ReferralFlag, 0) AS ReferralFlag
, arrears.ArrearsTotal
, GiftedEquityFlag = CONVERT(INT, IIF(ds.DepositAmount IS NULL, 0, 1))

-- BTL data
, InterestRate = ISNULL (
								IIF(app.Environment = 'Origination', app.AppInterestRate, app.InterestRate)
								, 0
					 )
, InterestRateJoin = ISNULL(IIF(app.Environment = 'Origination', app.AppInterestRate, app.InterestRate), 0) 
, AppInterestRate = ISNULL(app.AppInterestRate,0)
, AnnualRentalIncome = CONVERT(DECIMAL(20,2),i.MonthlyRentalIncome * 12)
, MonthlyRentalIncome = i.MonthlyRentalIncome
, i.StressedMonthlyInterestPayment
, i.StressTestRate
, i.ICR
, i.ICRAdjusted
, i.RentAdjustedForAffPass
, BTLScore = app.TMLScore
, Over65Flag = CASE WHEN OldestDOB IS NULL
						OR app.AppDate IS NULL
					THEN 0
				ELSE
				CASE WHEN ( DATEDIFF(YEAR, OldestDOB, app.AppDate)
						- CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, OldestDOB, app.AppDate),
								OldestDOB) > app.AppDate
						THEN 1 
				ELSE 0
					END
							) > 65
				THEN 1 ELSE 0
				END
				END
, Over70Flag = CASE WHEN applicants.YoungestDOB IS NULL
								OR app.AppDate IS NULL
						THEN 0
					ELSE
					CASE WHEN ( DATEDIFF(YEAR, applicants.YoungestDOB, app.AppDate)
								- CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, applicants.YoungestDOB, app.AppDate),
												applicants.YoungestDOB) > app.AppDate
										THEN 1 
								ELSE 0
								END
							) > 70
						THEN 1 
						ELSE 0
					END
				END
, app.CustomerType
, FTBTL = CONVERT(INT,IIF(
						app.LoanType = 'BTL' AND app.MortgageType = 'Purchase'
						AND custTotals.BTLOwners + ISNULL(btlProps.PortfolioCount, 0) = 0
						AND app.ProductTier IN ('Ltd Company BTL', 'Standard (Individual) BTL')
						, 1
						, 0)
				)
, Expat = IIF(custTotals.Expats > 0, 1, 0)
, PortfolioFlag = btlProps.PortfolioFlag
, btlProps.PortfolioCount
, TMLPortfolio = custTotals.BTLOwners
-- Latest Affordability Data
, RequestedLoanAmount = affSC.Loan
, BestResultTwoYear = affSc.TwoYearResult
, BestResultFiveYear = affSc.FiveYearResult
, AffordabilityRating = affSc.Rating
, AfordabilityBestTier = affSc.BestTier
, MaxLoanTwoYear = affSc.TwoYearMaxLoan	 
, MaxLoanFiveYear = affSc.FiveYearMaxLoan
, app.Securitised 	 
, app.SecuritisationStatus
, app.ReversionDate
, ISNULL(prod.ProductRange, 'Unkown') AS ProductRange

---- COVID reporting
, PaymentHoliday = IIF(ct.AccountNo IS NOT NULL, 1, 0)
, HolidayPeriod = CASE 
						  WHEN ph.HolidayPeriod <4 THEN CONVERT(VARCHAR(3), ph.HolidayPeriod)
						  WHEN ph.HolidayPeriod >=4 THEN '4+'
						  ELSE 'N/A'
						END 
, CurrentIncomeStatus = IIF(ph.PaymentHolidayID IS NOT NULL, ISNULL(ct.CurrentIncomeStatus, 'Unknown'), 'N/A')
, Industry = IIF(ph.PaymentHolidayID IS NOT NULL, ISNULL(ct.IndustryApp1, 'Unknown'), 'N/A')
, RateType = IIF(app.Environment = 'Servicing', IIF(app.RevertedFlag = 0, 'Initial', 'Reverted'), NULL)
, app.RevertedFlag
, HolidayActive = IIF(ph.ReportStartDate <= @cobDate AND @cobDate BETWEEN ph.ReportStartDate AND DATEADD(d, -1, DATEADD(m, ph.HolidayPeriod, ph.ReportStartDate)), 1, 0)
, AgreedHolidaysCount = IIF(
									 ct.AccountNo IS NULL
									 , NULL
									 , CASE 
										  WHEN LEFT(LetterCode6, 3) IN ('RES', 'BTL') AND ISNUMERIC(RIGHT(LetterCode6, 1)) = '1' THEN 6
										  WHEN LEFT(LetterCode5, 3) IN ('RES', 'BTL') AND ISNUMERIC(RIGHT(LetterCode5, 1)) = '1' THEN 5
										  WHEN LEFT(LetterCode4, 3) IN ('RES', 'BTL') AND ISNUMERIC(RIGHT(LetterCode4, 1)) = '1' THEN 4
										  WHEN LEFT(LetterCode3, 3) IN ('RES', 'BTL') AND ISNUMERIC(RIGHT(LetterCode3, 1)) = '1' THEN 3
										  WHEN LEFT(LetterCode2, 3) IN ('RES', 'BTL') AND ISNUMERIC(RIGHT(LetterCode2, 1)) = '1' THEN 2
										  ELSE 1
									  END
								)
, ExtensionMonth = CASE 
						  WHEN ph.PaymentHolidayID IS NULL THEN 'N/A'
						  WHEN ph.HolidayPeriod > ph.InitialHolidayRequested THEN DATENAME(MONTH, DATEADD(m, ph.InitialHolidayRequested, ph.ReportStartDate))
						  ELSE 'N/A'
						 END
, ExtensionMonthNo = CASE 
						  WHEN ph.PaymentHolidayID IS NULL THEN NULL
						  WHEN ph.HolidayPeriod > ph.InitialHolidayRequested THEN MONTH(DATEADD(m, ph.InitialHolidayRequested, ph.ReportStartDate))
						  ELSE NULL
						 END
, CurrentBalance = IIF(app.LoanType = 'Residential', app.CurrentBalance, app.ActualCurrentBalance)	
, DeferralStatus = 'Deferral'
							+ IIF(ph.ReportStartDate <= @cobDate AND @cobDate BETWEEN ph.ReportStartDate AND DATEADD(d, -1, DATEADD(m, ph.HolidayPeriod, ph.ReportStartDate)), 'Active', '')
						   + IIF(ph.HolidayPeriod > ph.InitialHolidayRequested, 'Extension', '')
							+ IIF(
									 ph.ReportStartDate <= @cobDate 
										AND @cobDate BETWEEN ph.ReportStartDate AND DATEADD(d, -1, DATEADD(m, ph.HolidayPeriod, ph.ReportStartDate))
										AND ph.HolidayPeriod <= ph.InitialHolidayRequested
									 , 'ActiveNoExtension'
									 , ''
									)
						   + IIF(
									 ph.ReportStartDate <= @cobDate 
										AND @cobDate > DATEADD(d, -1, DATEADD(m, ph.HolidayPeriod, ph.ReportStartDate))
										AND ph.HolidayPeriod <= ph.InitialHolidayRequested
									 , 'EndedNoExtension'
									 , ''
									)
, YoungestAgeBorrower = IIF(cust1.AgeAtApp <= ISNULL(cust2.AgeAtApp, 999), cust1.AgeAtApp, cust2.AgeAtApp)
, RevertNotRedeemed =  CASE WHEN app.AccountClosedDate IS NULL AND app.RevertedFlag = 1  THEN 'Reverted Not Redeemed'
						WHEN app.AccountClosedDate >= app.ReversionDate AND app.RevertedFlag = 1  THEN 'Redeemed after Reverted'
						WHEN app.AccountClosedDate < app.ReversionDate AND app.RevertedFlag = 1  THEN 'Redeemed before Reverted'
						ELSE 'Not Reverted'
					END
, app.SecuritisationTag, app.SecuritisationFlag

------ Columns moved from sp_Strats to the build scrip
, app.UADate
, ISNULL(prod.DateActive, '9999-12-31') AS ProductDateActive
, cref.NoDebtManagementPlans

------------------------------------------------------------

---- default values for groups . Will be overwritten in queries after
, CustomerLTVSegment = CONVERT(VARCHAR(50), 'Error')
, CustomerLTVSegmentOrder = 99
, CustomerBTLLTVSegment = CONVERT(VARCHAR(50), 'Error')
, CustomerBTLLTVSegmentOrder = 99
, LTVSegment = CONVERT(VARCHAR(50), 'Error') 
, LTVSegmentOrder = 99 
, LTVSegmentResidential =  CONVERT(VARCHAR(50), 'Error')
, LTVSegmentOrderResidential = 99 
, LTVSegmentBTL = CONVERT(VARCHAR(50), 'Error') 
, LTVSegmentOrderBTL = 0 
, LoanAmountCategory = CONVERT(VARCHAR(50), 'Error') 
, LoanCategoryOrder =  99
, IncomeGroup = CONVERT(VARCHAR(50), 'Error') 
, IncomeGroupOrder =  99
, IncomeMultipleGroup = IIF(app.LoanType = 'BTL', 'N/A', CONVERT(VARCHAR(50), 'Error'))
, IncomeMultipleOrder = IIF(app.LoanType = 'BTL', 99,  99)
, TierAssetClass = CONVERT(VARCHAR(50), 'Unknown Band')
, BedroomCatgeory = CONVERT(VARCHAR(50), NULL) 
, BedroomOrderNo = CONVERT(INT, NULL)
, RNGroup = CONVERT(VARCHAR(50), NULL) 
, RNGroupNo = CONVERT(INT, NULL)
, InterestRateGroup = CONVERT(VARCHAR(50), NULL) 
, InterestRateOrder = CONVERT(INT, NULL)
, ICRSegment = CONVERT(VARCHAR(50), 'Unknown')
, ICRSegmentOrder = 99
, ICR2Segment = CONVERT(VARCHAR(50), 'Unknown')
, ICR2SegmentOrder = 99
, UnderwritingMandateLevel = CONVERT(VARCHAR(50), NULL) 
, UWMandateLevelOrder = CONVERT(INT, NULL)
, tapps.PTDate
, app.OriginationSource
-----------------------------------------------------------

INTO #strats
FROM #apps app
LEFT OUTER JOIN #dimcapps dapp ON app.ApplicationRef = dapp.ApplicationRef
INNER JOIN #tapps tapps ON app.ApplicationRef = tapps.ApplicationRef

--- DIFFERENT VALUATIONS
INNER JOIN #vals vals ON dapp.ApplicationRef = vals.ApplicationRef COLLATE DATABASE_DEFAULT

----LEFT OUTER JOIN #calcs i ON i.ApplicationRef = app.ApplicationRef
INNER JOIN #calcs i ON i.ApplicationRef = app.ApplicationRef 

LEFT OUTER JOIN TML_DW.dbo.tbl_PropertyDetails prop ON app.ApplicationRef = prop.ApplicationRef COLLATE DATABASE_DEFAULT
INNER JOIN TML_DW.dbo.vw_ApplicationReportStatus repStat ON app.LatestStatus = repStat.LatestStatus COLLATE DATABASE_DEFAULT
LEFT OUTER JOIN TML_DW.dbo.tbl_Applicants cust1 ON app.ApplicationRef = cust1.ApplicationRef 
													AND cust1.BoEAppNo = 1
LEFT OUTER JOIN TML_DW.dbo.tbl_Applicants cust2 ON app.ApplicationRef = cust2.ApplicationRef 
													AND cust2.BoEAppNo = 2
LEFT OUTER JOIN TML_DW.dbo.tbl_CreditRefLatest cref ON app.APplicationRef = cref.ApplicationRef COLLATE DATABASE_DEFAULT
LEFT OUTER JOIN  #debtcon debtCon ON app.ApplicationRef = debtCon.ApplicationRef
INNER JOIN #vw_IntermediaryTree it ON app.DIM_CO_Application_DWSK = it.DIM_CO_Application_DWSK
LEFT OUTER JOIN TML_DW.dbo.tbl_AffordabilityLatest aff ON app.ApplicationRef = aff.ApplicationRef COLLATE DATABASE_DEFAULT
LEFT OUTER JOIN TML_DW.dbo.tbl_AffordabilityScores affSc ON aff.DocumentRef = affSc.DocumentRef
LEFT OUTER JOIN #afees afees ON app.ApplicationRef = afees.ApplicationRef
---- REFERRALS

LEFT OUTER JOIN (
	SELECT ApplicationRef
	, SUM(IIF(ReferralType = 'Internal', 1, 0)) AS InternalReferrals
	, SUM(IIF(ReferralType = 'Funder', 1, 0)) AS FunderReferrals
	, 1 AS ReferralFlag 
	FROM TML_DW.dbo.tbl_Referrals
	GROUP BY ApplicationRef
) referrals ON app.ApplicationRef = referrals.ApplicationRef COLLATE DATABASE_DEFAULT

LEFT OUTER JOIN #Arrears24 arrears ON app.ApplicationRef = arrears.ApplicationRef COLLATE DATABASE_DEFAULT

LEFT OUTER JOIN ( SELECT d.ApplicationRef, DepositAmount = SUM(d.DepositAmount) 
					FROM dbo.vw_DepositSources d
					WHERE d.DepositSource = 'EquityGiftedDeposit'
					GROUP BY d.ApplicationRef
					) ds ON app.ApplicationRef = ds.ApplicationRef	

LEFT OUTER JOIN (
    SELECT DISTINCT a.ApplicationRef, a.StatusNameId, d.Source, d.Amount AS GiftedAmount, 1 AS WithIncentive
    FROM DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAApplication a 
    INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMADeposit d ON a.ID = d.ApplicationId
												   AND d.Source = 'BuilderVendorDeposit'	
) incentive ON app.ApplicationRef = incentive.ApplicationRef COLLATE DATABASE_DEFAULT


-------------------------------------------------------

---- BTL specific data
LEFT OUTER JOIN (
    SELECT ApplicationRef
    , YoungestDOB = MAX(DateOfBirth) 
    , OldestDOB = MIN(DateOfBirth)
    , NoApplicants = COUNT(*)
    FROM TML_DW.dbo.tbl_Applicants
    GROUP BY ApplicationRef
) applicants ON app.ApplicationRef = applicants.ApplicationRef

LEFT OUTER JOIN (
    SELECT ApplicationRef, Applicants = COUNT(*), BTLOwners = SUM(AnyBTLProperties) 
    , Expats = SUM(IsExPat) 
    FROM TML_DW.dbo.tbl_Applicants
    GROUP BY ApplicationRef
) custTotals ON app.ApplicationRef = custTotals.ApplicationRef

LEFT OUTER JOIN #PortCount btlProps ON app.ApplicationRef = btlProps.ApplicationRef
LEFT JOIN TML_DW.dbo.tbl_Products prod ON app.ProductCode = prod.ProductCode

LEFT OUTER JOIN TML_DW.dbo.tbl_PaymentHolidays ph ON app.AccountNo = ph.AccountNo
																	 AND ISNULL(ph.TrackerStatus, 'PH Active') NOT IN ('Redeemed', 'Cancelled')
																	 AND ISNULL(ph.HolidayPeriod, 0) > 0

LEFT OUTER JOIN TML_DW.dbo.tbl_CovidTracker ct ON ph.AccountNo = ct.AccountNo
																	 AND LEFT(LetterCode1, 3) IN ('RES', 'BTL') AND ISNUMERIC(RIGHT(LetterCode1, 1)) = '1' 

WHERE app.DipAcceptDate IS NOT NULL
AND app.OriginationSource = 'TML'
OPTION(RECOMPILE);



------------------------------------------------------------------------------------------------------------------

---- category group joins

-- income group
UPDATE s 
SET IncomeGroup = grp_inc.CategoryName
, IncomeGroupOrder = grp_inc.Orderno
FROM #strats s
INNER JOIN #groups grp_inc ON s.CombinedIncome BETWEEN grp_inc.MinValue AND grp_inc.MaxValue
								AND grp_inc.CategoryGroup = 'Income'

-- income group multiple
UPDATE s 
SET IncomeMultipleGroup = grp_incMul.CategoryName
, IncomeMultipleOrder = grp_incMul.Orderno
FROM #strats s
INNER JOIN #groups grp_incMul ON s.IncomeMultiple BETWEEN grp_incMul.MinValue AND grp_incMul.MaxValue
								AND grp_incMul.CategoryGroup = 'Income Multiple'
WHERE s.LoanType <> 'BTL'

-- residential LTV segment
UPDATE s 
SET LTVSegment =  grp_ltvSeg.CategoryName
, LTVSegmentOrder = grp_ltvSeg.Orderno
, LTVSegmentResidential =  grp_ltvSeg.CategoryName
, LTVSegmentOrderResidential = grp_ltvSeg.Orderno
FROM #strats s
INNER JOIN #groups grp_ltvSeg ON s.OriginalLTV BETWEEN grp_ltvSeg.MinValue AND grp_ltvSeg.MaxValue
								AND grp_ltvSeg.CategoryGroup = 'LTV Segment'

-- BTL LTV segment
UPDATE s 
SET LTVSegmentBTL = grp_ltvBTLSeg.CategoryName
, LTVSegmentOrderBTL = grp_ltvBTLSeg.OrderNo
FROM #strats s
LEFT OUTER JOIN #groups grp_ltvBTLSeg ON OriginalLTV BETWEEN grp_ltvBTLSeg.MinValue AND grp_ltvBTLSeg.MaxValue
										AND grp_ltvBTLSeg.CategoryGroup = 'BTL LTV Segment'

-- Residential Customer LTV segment
UPDATE s 
SET s.CustomerLTVSegment = grp_ltvSegCust.CategoryName
, s.CustomerLTVSegmentOrder = grp_ltvSegCust.OrderNo
FROM #strats s
LEFT OUTER JOIN #groups grp_ltvSegCust ON s.CustomerLTV BETWEEN grp_ltvSegCust.MinValue AND grp_ltvSegCust.MaxValue
													 AND grp_ltvSegCust.CategoryGroup = 'LTV Segment'

-- BTL Customer LTV segment
UPDATE s 
SET s.CustomerBTLLTVSegment = grp_ltvSegCustBTL.CategoryName
, CustomerBTLLTVSegmentOrder = grp_ltvSegCustBTL.OrderNo
FROM #strats s
LEFT OUTER JOIN #groups grp_ltvSegCustBTL ON s.CustomerLTV BETWEEN grp_ltvSegCustBTL.MinValue AND grp_ltvSegCustBTL.MaxValue
												AND grp_ltvSegCustBTL.CategoryGroup = 'BTL LTV Segment'

-- loan amount
UPDATE s 
SET s.LoanAmountCategory = grp_loanVal.CategoryName
, LoanCategoryOrder = grp_loanVal.OrderNo
FROM #strats s 
LEFT OUTER JOIN #groups grp_loanVal ON s.GrossLoanAmount BETWEEN grp_loanVal.MinValue AND grp_loanVal.MaxValue
										AND grp_loanVal.CategoryGroup = 'Loan Amount'

-- asset class
UPDATE s 
SET TierAssetClass = grp_tier.CategoryName
FROM #strats s 
LEFT OUTER JOIN #groups grp_tier ON s.ProductTierJoin BETWEEN grp_tier.MinValue AND grp_tier.MaxValue 
										   AND grp_tier.CategoryGroup = 'Tier Asset Class'

-- Bedrooms
UPDATE s 
SET BedroomCatgeory = grp_bed.CategoryName 
, s.BedroomOrderNo = grp_bed.Orderno
FROM #strats s 
INNER JOIN #groups grp_bed ON s.NumberOfBedrooms BETWEEN CONVERT(INT, grp_bed.MinValue) AND CONVERT(INT, grp_bed.MaxValue)
								AND grp_bed.CategoryGroup = 'Bedrooms'

-- reating score
UPDATE s 
SET s.RNGroup = grp_rnsc.CategoryName
, RNGroupNo = grp_rnsc.Orderno
FROM #strats s 
INNER JOIN #groups grp_rnsc ON s.RNScore BETWEEN grp_rnsc.MinValue AND grp_rnsc.MaxValue
												AND grp_rnsc.CategoryGroup = 'RN Score'

-- interest rate
UPDATE s 
SET InterestRateGroup = grpCoupon.CategoryName
, InterestRateOrder = grpCoupon.Orderno
FROM #strats s 
INNER JOIN #groups grpCoupon ON s.InterestRateJoin BETWEEN grpCoupon.MinValue AND grpCoupon.MaxValue
													AND grpCoupon.CategoryGroup = 'Interest Rate'

--	ICR
UPDATE s 
SET ICRSegment = grp_icr.CategoryName
, ICRSegmentOrder = grp_icr.Orderno
FROM #strats s 
INNER JOIN #groups grp_icr ON s.ICRAdjusted BETWEEN grp_icr.MinValue AND grp_icr.MaxValue
													AND grp_icr.CategoryGroup = 'ICR Result'

UPDATE s 
SET ICR2Segment = grp_icr2.CategoryName
, ICR2SegmentOrder = grp_icr2.Orderno
FROM #strats s  
INNER JOIN #groups grp_icr2 ON s.ICRAdjusted BETWEEN grp_icr2.MinValue AND grp_icr2.MaxValue
													AND grp_icr2.CategoryGroup = 'ICR Result2'

-- Underwriter Mandate
UPDATE s 
SET UnderwritingMandateLevel = grp_uwLoanAmount.CategoryName
, UWMandateLevelOrder = grp_uwLoanAmount.Orderno
FROM #strats s 
INNER JOIN #groups grp_uwLoanAmount ON s.LoanAmount BETWEEN grp_uwLoanAmount.MinValue AND grp_uwLoanAmount.MaxValue
										AND grp_uwLoanAmount.CategoryGroup = 'Underwriting Mandate Level';


------------------------------------------------------------------------------------------------------------------

--used to add on new columns which use the base data in strarts, saves on redoing logic twice
IF OBJECT_ID('tempdb..#strats2') IS NOT NULL
DROP TABLE #strats2;

SELECT s.COBID, s.COBDate, s.ApplicationRef, s.LoanType, s.DIPCreatedDate, s.DipAcceptDate, s.DIPSubmitDate
	, s.DateDIPAccept, s.AppDate, s.FirstOfferDate, s.ReofferDate, s.CompDate, s.LatestStatus, s.Environment
	, s.ReportStatus, s.NoApplicants, s.Cust1MaritalStatus, s.Cust2MaritalStatus, s.Cust1EmploymentType
	, s.Cust2EmploymentType, s.Cust1DateOfBirth, s.Cust2DateOfBirth, s.Cust1Income, s.Cust2Income, s.CombinedIncome
	, s.IncomeGroup, s.IncomeGroupOrder, s.Cust1AgeAtApp, s.Cust2AgeAtApp, s.YoungestAgeAtApp, s.Cust1FirstTimeBuyer
	, s.Cust2FirstTimeBuyer, s.Cust1AgeatMaturity, s.Cust2AgeatMaturity, s.Cust1RetirementAge, s.Cust2RetirementAge
	, s.Cust1RetirementDate, s.Cust2RetirementDate, s.Cust1LIRFlag, s.Cust2LIRFlag, s.LoanPurpose, s.MortgageGroup
	, s.AppType, s.RepaymentType, s.CustomerLTV, s.CustomerLTVSegment, s.CustomerLTVSegmentOrder, s.CustomerBTLLTVSegment
	, s.CustomerBTLLTVSegmentOrder, s.OriginalLTV, s.LTVSegment, s.LTVSegmentOrder, s.LTVSegmentResidential
	, s.LTVSegmentOrderResidential, s.LTVSegmentBTL, s.LTVSegmentOrderBTL, s.ActualValuation, s.CustomerProvidedValuation
	, s.ValAge, s.CILTV, s.LoanAmount, s.InitialLoanRequested, s.GrossLoanAmount, s.MortgagePreCompAmount
	, s.LoanAmountCategory, s.LoanCategoryOrder, s.IncomeMultipleOLD, s.IncomeMultiple, s.IncomeMultipleGroup
	, s.IncomeMultipleOrder, s.MultipleFlag, s.ExtraRemortgageBorrowing, s.IsHomeImprovement, s.IsCapitalRaising
	, s.IsDebtConsolidation, s.DebtConsolidationAmount, s.InitialTermYears, s.InitialTermMonths, s.LoanMaturityDate
	, s.ProductCode, s.ProductTier, s.ProductLTVBand, s.ProductType, s.ProductGroup, s.ProductFeature, s.TierAssetClass
	, s.NoCCJ_3m, s.NoCCJ_6m, s.NoCCJ_1yr, s.ValueCCJ_1yr, s.NoCCJ_2yr, s.ValueCCJ_2yr, s.NoCCJ_3yr, s.ValueCCJ_3yr
	, s.NoCCJ_4yr, s.ValueCCJ_4yr, s.NoCCJ_6yr, s.ValueCCJ_6yr, s.NoBOIVA_6yr, s.ValueBOIVA_6yr, s.NoBOIVA_3yr
	, s.ValueBOIVA_3yr, s.SecurityType, s.SecuritySubType, s.TenureType, s.LeaseRemaining, s.LeaseAtEndOfTermYears
	, s.PropertyType, s.Region, s.NumberOfBedrooms, s.BedroomCatgeory, s.BedroomOrderNo, s.Broker, s.Network, s.MortgageClub
	, s.Packager, s.IntroducerType, s.CreditReferenceId, s.RNScore, s.RNGroup, s.RNGroupNo, s.TMLScore, s.ScoreTier
	, s.ScoreDistribution, s.SelfEmployedFlag, s.RetirementFlagOLD, s.LendingIntoRetirement, s.PercentagePastRetirement
	, s.RetirementFlag, s.RetirementFlagReason, s.ImpairedFlag, s.CCJsFlag, s.FirstTimeBuyer, s.NewBuildFlag
	, s.NewBuildIncentive, s.ReferralFlag, s.ArrearsTotal, s.GiftedEquityFlag, s.InterestRate, s.AppInterestRate
	, s.InterestRateGroup, s.InterestRateOrder, s.AnnualRentalIncome, s.MonthlyRentalIncome, s.StressedMonthlyInterestPayment
	, s.StressTestRate, s.ICR, s.ICRSegment, s.ICRSegmentOrder, s.ICR2Segment, s.ICR2SegmentOrder, s.ICRAdjusted
	, s.RentAdjustedForAffPass, s.BTLScore, s.Over65Flag, s.Over70Flag, s.CustomerType, s.FTBTL, s.Expat, s.PortfolioFlag
	, s.PortfolioCount, s.TMLPortfolio, s.RequestedLoanAmount, s.BestResultTwoYear, s.BestResultFiveYear, s.AffordabilityRating
	, s.AfordabilityBestTier, s.MaxLoanTwoYear, s.MaxLoanFiveYear, s.Securitised, s.SecuritisationStatus, s.ReversionDate
	, s.ProductRange, s.PaymentHoliday, s.HolidayPeriod, s.CurrentIncomeStatus, s.Industry, s.RateType, s.RevertedFlag
	, s.HolidayActive, s.AgreedHolidaysCount, s.ExtensionMonth, s.ExtensionMonthNo, s.CurrentBalance, s.DeferralStatus
	, s.UnderwritingMandateLevel, s.UWMandateLevelOrder, s.YoungestAgeBorrower, s.RevertNotRedeemed, s.SecuritisationTag
	, s.SecuritisationFlag, s.UADate, s.ProductDateActive, s.NoDebtManagementPlans, s.PTDate

----Columns from sp_Strats moved to the populate script for use in Power BI
	, CapitalRaised = isnull((s.ExtraRemortgageBorrowing/s.LoanAmount)*100, 0)
	, iif (s.ICR > 10 AND s.MonthlyRentalIncome > 10000 ,'Y', 'N') AS ICROutlier
	, CapitalRaisedSeg = rc.CategoryName, CapRaisedDebtExclSeg = rc1.CategoryName, DebtConSeg = rc22.CategoryName

---- Columns added for new conversion SSRS report
	, DipSubmitMonthD = eomonth(s.DIPSubmitDate), DipAcceptMonthD = eomonth(s.DipAcceptDate), AppMonthD = eomonth(s.AppDate)
	, OfferMonthD = eomonth(s.FirstOfferDate), CompMonthD = eomonth(s.CompDate)
	, DipSubmitMonth = CASE WHEN s.DIPSubmitDate IS NULL THEN NULL
							ELSE LEFT(DATENAME(month, s.DIPSubmitDate), 3) + '-' + RIGHT(CONVERT(char(4), YEAR(s.DIPSubmitDate)), 2)
						END
	, DipAcceptMonth = CASE WHEN s.DipAcceptDate IS NULL THEN NULL
							ELSE LEFT(DATENAME(month, s.DipAcceptDate), 3) + '-' + RIGHT(CONVERT(char(4), YEAR(s.DipAcceptDate)), 2)
						END
	, AppMonth = CASE WHEN s.AppDate IS NULL THEN NULL
					ELSE LEFT(DATENAME(month, s.AppDate), 3) + '-' + RIGHT(CONVERT(char(4), YEAR(s.AppDate)), 2)
				END
	, OfferMonth = CASE WHEN s.FirstOfferDate IS NULL THEN NULL
						ELSE LEFT(DATENAME(month, s.FirstOfferDate), 3) + '-' + RIGHT(CONVERT(char(4), YEAR(s.FirstOfferDate)), 2)
					END 
	, CompMonth = CASE WHEN s.CompDate IS NULL THEN NULL
						ELSE LEFT(DATENAME(month, s.CompDate), 3) + '-' + RIGHT(CONVERT(char(4), YEAR(s.CompDate)), 2)
					END
	, DipSubmit = iif(s.DIPSubmitDate is null, 1, 0), AppSubmitted = iif(s.AppDate is null, 1, 0)
	, Offered = iif(s.FirstOfferDate is null, 1, 0), Completed = iif(s.CompDate is null, 1, 0), DipSubmitMonthBack = datediff(m, s.DIPSubmitDate, @endDate)
	, DipAcceptMonthBack = datediff(m, s.DipAcceptDate, @endDate), AppMonthBack = datediff(m, s.AppDate, @endDate)
	, OfferMonthBack = datediff(m, s.FirstOfferDate, @endDate), CompMonthBack = datediff(m, s.CompDate, @endDate)

	, CASE WHEN s.LoanType ='Residential2' AND s.ProductCode >= '2575' THEN 'New'
		WHEN s.LoanType = 'Residential2' AND s.ProductCode < '2575' THEN 'Old'
		WHEN s.LoanType = 'Residential2' AND s.ProductCode IS NULL AND s.DipAcceptDate < '2022-02-15' THEN 'Old'
		WHEN s.LoanType = 'Residential2' AND s.ProductCode IS NULL AND s.DipAcceptDate >= '2022-02-15' THEN 'New'
		ELSE null
		END AS SBResiProductFilter
		
	, TrueArrearsRatio = ISNULL(ad.TrueArrearsRatio, 0), ISNULL(PDLoans.NoPayDayLoans, 0) AS NoPayDayLoans
	, NULL AS NoBo6m,NULL AS BoVal6m, NULL AS NoBo1yr, NULL AS BoVal1yr, NULL AS NoBo2yr, NULL AS BoVal2yr, NULL AS NoBo3yr, NULL AS BoVal3yr, NULL AS NoBo4yr
	, NULL AS BoVal4yr, NULL AS NoBo6yr, NULL AS BoVal6yr, NULL AS NoIVA1yr, NULL AS IVAVal1yr, NULL AS NoIVA2yr, NULL AS IVAVal2yr, NULL AS NoIVA3yr
	, NULL AS IVAVal3yr, NULL AS NoIVA6yr, NULL AS IVAVal6yr, isnull(usd.Default1m, 0) AS Default1m, ISNULL(usd.Default3m, 0) AS Default3m
	, ISNULL(usd.Default6m, 0) AS Default6m, ISNULL(usd.Default12m, 0) AS Default12m, ISNULL(usd.Default18m, 0) AS Default18m
	, ISNULL(usd.Default24m, 0) AS Default24m, ISNULL(usd.Default36m, 0) AS Default36m, ISNULL(usd.Default48m, 0) AS Default48m
	, ISNULL(usd.Default60m, 0) AS Default60m, ISNULL(usd.Default72m, 0) AS Default72m, ISNULL(msl.Missed3Mths, 0) AS Missed3Mths
	, ISNULL(msl.Missed6Mths, 0) AS Missed6Mths, ISNULL(msl.Missed12Mths, 0) AS Missed12Mths, ISNULL(msl.Missed18Mths, 0) AS Missed18Mths
	, ISNULL(msl.Missed24Mths, 0) AS Missed24Mths, ISNULL(msl.Missed36Mths, 0) AS Missed36Mths, ISNULL(msl.Missed48Mths, 0) AS Missed48Mths
	, ISNULL(msl.Missed60Mths, 0) AS Missed60Mths, ISNULL(msl.Missed72Mths, 0) AS Missed72Mths

	, prr.OrderNo AS SBResiProductOrder, Repossion = IIF(Repo.CurrentStatus = 'Possession', 1, 0) ,prr.RLUMI
	, ISNULL(umsl.Missed3Mths, 0) AS UnsMissed3Mths , ISNULL(umsl.Missed6Mths, 0) AS UnsMissed6Mths, ISNULL(umsl.Missed12Mths, 0) AS UnsMissed12Mths
	, ISNULL(umsl.Missed18Mths, 0) AS UnsMissed18Mths, ISNULL(umsl.Missed24Mths, 0) AS UnsMissed24Mths, ISNULL(umsl.Missed36Mths, 0) AS UnsMissed36Mths
	, ISNULL(umsl.Missed48Mths, 0) AS UnsMissed48Mths, ISNULL(umsl.Missed60Mths, 0) AS UnsMissed60Mths, ISNULL(umsl.Missed72Mths,0) AS UnsMissed72Mths
	, ISNULL(usdd.Default1m, 0) AS UnsDefaults1m, ISNULL(usdd.Default3m, 0) AS UnsDefaults3m, ISNULL(usdd.Default6m, 0) AS UnsDefaults6m
	, ISNULL(usdd.Default12m, 0) AS UnsDefaults12m, ISNULL(usdd.Default18m, 0) AS UnsDefaults18m, ISNULL(usdd.Default24m, 0) AS UnsDefaults24m
	, ISNULL(usdd.Default36m,0 ) AS UnsDefaults36m, ISNULL(usdd.Default48m, 0) AS UnsDefaults48m, ISNULL(usdd.Default60m, 0) AS UnsDefaults60m
	, ISNULL(usdd.Default72m, 0) AS UnsDefaults72m
	, s.OriginationSource
	, HasWorkingVisa = ISNULL(vi.WorkingVisa, 0)
INTO #strats2
FROM #strats s
LEFT OUTER JOIN #groups rc ON ISNULL(ROUND((s.ExtraRemortgageBorrowing/s.LoanAmount)*100,2), 0) BETWEEN rc.MinValue AND rc.MaxValue
																AND rc.CategoryGroup = 'Capital Raised'
LEFT OUTER JOIN #groups rc1 ON ISNULL(ROUND(((s.ExtraRemortgageBorrowing - s.DebtConsolidationAmount)/s.LoanAmount)*100,2), 0) BETWEEN rc1.MinValue AND rc1.MaxValue
																AND rc1.CategoryGroup = 'Capital Raised'
LEFT OUTER JOIN #groups rc22 ON ISNULL(ROUND(( s.DebtConsolidationAmount/s.LoanAmount)*100,2), 0) BETWEEN rc22.MinValue AND rc22.MaxValue
																AND rc22.CategoryGroup = 'Capital Raised'

LEFT OUTER JOIN (SELECT ApplicationRef, COUNT(ApplicationRef) AS NoPayDayLoans
					FROM dbo.tbl_PaymentProfiles
					WHERE 1 = 1
					AND AccountType = 'PayDayLoans'
					GROUP BY ApplicationRef) PDLoans ON PDLoans.ApplicationRef = s.ApplicationRef

LEFT OUTER JOIN #mpsul msl ON msl.ApplicationRef = s.ApplicationRef AND msl.SecuredUnsecured = 'Secured'
LEFT OUTER JOIN #usd usd ON usd.ApplicationRef = s.ApplicationRef AND usd.SecuredUnsecured = 'Secured'
LEFT OUTER JOIN #mpsul umsl ON umsl.ApplicationRef = s.ApplicationRef AND umsl.SecuredUnsecured = 'Unsecured'
LEFT OUTER JOIN #usd usdd ON usdd.ApplicationRef = s.ApplicationRef AND usdd.SecuredUnsecured = 'Unsecured'
LEFT OUTER JOIN (
			SELECT AccountNo, CurrentStatus 
			FROM TML_DW.dbo.fn_Litigations(@endcob) 
			WHERE CurrentStatusGroup = 'Possession') repo ON repo.AccountNo = s.ApplicationRef
LEFT OUTER JOIN TML_DW.dbo.tbl_ProductsReportRanking prr ON prr.Tier = s.ProductTier
LEFT OUTER JOIN #Arrears ad ON ad.accountno = s.applicationRef  
LEFT OUTER JOIN #visa vi ON s.ApplicationRef = vi.ApplicationRef


----------------------------------------------------------------
--BML Temp Tables
----------------------------------------------------------------

IF OBJECT_ID('tempdb..#bml_calcs') IS NOT NULL
DROP TABLE #bml_calcs;

SELECT 
	  app.ApplicationRef
	, IncomeMultiple = IIF(ISNULL(aff.GrossIncomeIncludingCreditsTotal, 0) = 0
					, 0
					, IIF(app.LoanType = 'BTL'
							, 0
							, CONVERT(DECIMAL(8,2), ROUND(app.LoanAmount / aff.GrossIncomeIncludingCreditsTotal,2)))
						)
	, MonthlyRentalIncome = CONVERT(DECIMAL(20,2), COALESCE(so.MonthlyRentalIncome, pd.MonthlyRentalIncome, aff.MonthlyRentalIncome))
	, StressTestRate = sr.StressRate
	, StressedMonthlyInterestPayment = CONVERT(decimal(20,6), (app.LoanAmount * (sr.StressRate / 100.0)) / 12.0	)
	, ICR = IIF(
		app.LoanType = 'Residential'
		, 1.40
		, IIF ( 
		app.LoanType = 'Residential2'
		, CONVERT(DECIMAL(6,2), aff.NetIncome/pay.PaymentAmount)
		, CONVERT(DECIMAL(6,2), COALESCE(so.MonthlyRentalIncome, pd.MonthlyRentalIncome, aff.MonthlyRentalIncome)
			/ (app.LoanAmount * (sr.StressRate / 100.0) / 12.0)
						)
					)
				)
	, ICRAdjusted = NULL
	, RentAdjustedForAffPass = NULL
	, app.ReversionRate
	, app.Product
	, app.PTDate
INTO #bml_calcs
FROM
	(
	SELECT 
		  app.ApplicationRef
		, app.LoanType
		, app.LoanAmount
		, app.AppInterestRate
--		, app.ReversionRate
		, Product = ISNULL(prop.Product, app.Product), app.PTDate
		
		, ReversionRate = IIF(
								app.AppDate > '2020-10-21' OR revertTable.ProductCode >= '1925',
								IIF(app.LoanType = 'BTL',
										@TBRBTL + CONVERT(decimal(4,2), revertTable.RevertMargin),
										@TBRRESI + CONVERT(decimal(4,2), revertTable.RevertMargin)
										),
								CONVERT(numeric(4,2), @BBR + revertTable.RevertMargin)
								)							
	FROM #tapps app
	LEFT OUTER JOIN TML_DW.dbo.tbl_ProductHistory ph ON app.AccountNo = ph.AccountNo AND ph.VersionNo = 1 -- original product details
	LEFT OUTER JOIN TML_DW.dbo.tbl_Products prop ON ph.ProductCode = prop.ProductCode
	LEFT OUTER JOIN 
		(
		SELECT  
			  ProductCode
			, tier
			, ltv
			, (RevertAdd*100) AS RevertMargin
		FROM TML_DW.dbo.tbl_Products
		) revertTable ON app.ProductCode = revertTable.ProductCode
	WHERE app.DipAcceptDate IS NOT NULL
	) app
CROSS APPLY (SELECT StressRate = IIF(app.LoanType IN ('Residential','Residential2')
										, CASE WHEN LEFT(app.Product, 1) = '5' THEN app.AppInterestRate
												ELSE app.ReversionRate + 1
											END
										, CASE WHEN LEFT(app.Product, 1) = '5' THEN app.AppInterestRate
												WHEN LEFT(app.Product, 1) = '2'
													AND app.AppInterestRate + 2 < 5.5 THEN 5.5
												ELSE app.AppInterestRate + 2
											END
									)
				) sr
LEFT OUTER JOIN 
	(
	SELECT 
		  ApplicationRef = pvt.IdentityValue
		, MonthlyRentalIncome = CONVERT(DECIMAL(20, 2), pvt.MonthlyRentalIncome)
	FROM 
		(   
		SELECT 
			  TableName
			, IdentityColumn
			, IdentityValue, UpdateColumn, UpdateValue
			, OverrideReason
			FROM TML_DW.dbo.tbl_Overrides 
		) AS P
		PIVOT
			(MAX(UpdateValue) FOR UpdateColumn IN (MonthlyRentalIncome)) AS pvt
		WHERE pvt.TableName = 'sp_PopulateStratsTable'
		AND pvt.IdentityColumn = 'ApplicationRef'
	) so ON app.ApplicationRef = so.ApplicationRef COLLATE DATABASE_DEFAULT
LEFT OUTER JOIN TML_DW.dbo.tbl_AffordabilityLatest aff ON aff.ApplicationRef = app.ApplicationRef
LEFT OUTER JOIN TML_DW.dbo.tbl_PropertyDetails pd ON app.ApplicationRef = pd.ApplicationRef
LEFT OUTER JOIN	(
	SELECT 
		  SUM(pay.PaymentAmount) AS PaymentAmount
		, pay.AccountNo
	FROM TML_DW.dbo.vw_PaymentSchedule pay
	INNER JOIN TML_DW.dbo.tbl_Applications tapps ON tapps.ApplicationRef = pay.AccountNo COLLATE	 DATABASE_DEFAULT
	WHERE tapps.LoanType <> 'Residential'
	AND pay.DIM_CO_PaymentSchedule_SSK2 = '2'
	AND tapps.ApplicationRef <> 'M001383127'
	GROUP BY pay.AccountNo
	)pay ON pay.AccountNo = app.ApplicationRef COLLATE DATABASE_DEFAULT 
-- change to get rental adjustment put in to make pass affordability after base rate would cause failure

WHERE pd.OriginationSource = 'BML'

	CREATE CLUSTERED INDEX IDX_BMLCalc1 ON #bml_calcs(ApplicationRef);





-- now create temp table
IF OBJECT_ID('tempdb..#bml_strats') IS NOT NULL
DROP TABLE #bml_strats;



SELECT 
  COBID = @cobid
, COBDate = @cobDate
, ApplicationRef = app.ApplicationRef
, app.LoanType
, app.DipCreatedDate
, app.DipAcceptDate
, app.DIPSubmitDate
, DateDIPAccept = app.DIPAcceptDate
, AppDate = app.AppDate
, FirstOfferDate = app.FirstOfferDate
, ReofferDate = app.LatestOfferDate
, CompDate = app.CompDate
, LatestStatus = app.LatestStatus
, app.Environment
, ReportStatus = IIF( app.AccountClosedDate IS NOT NULL, 'Redeemed', repStat.ReportStatus)
, NoApplicants = app.Applicants
, Cust1MaritalStatus = cust1.MaritalStatus 
, Cust2MaritalStatus = cust2.MaritalStatus 
, Cust1EmploymentType = cust1.EmploymentType 
, Cust2EmploymentType = cust2.EmploymentType 
, Cust1DateOfBirth = cust1.DateOfBirth
, Cust2DateOfBirth = cust2.DateOfBirth
, Cust1Income = NULL
, Cust2Income = NULL
, CombinedIncome = NULL
, IncomeMultipleOLD = NULL
, i.IncomeMultiple -- NS 29/10/19
, Cust1AgeAtApp = CASE  WHEN cust1.DateOfBirth IS NULL OR COALESCE(app.AppDate, app.DipAcceptDate) IS NULL THEN NULL
						ELSE DATEDIFF(YEAR, cust1.DateOfBirth, COALESCE(app.AppDate, app.DipAcceptDate))
								- CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, cust1.DateOfBirth, COALESCE(app.AppDate, app.DipAcceptDate)), cust1.DateOfBirth)
												> COALESCE(app.AppDate, app.DipAcceptDate) THEN 1 
										ELSE 0 
								END
				END
, Cust2AgeAtApp = CASE	WHEN cust2.DateOfBirth IS NULL OR COALESCE(app.AppDate, app.DipAcceptDate) IS NULL THEN NULL
						ELSE DATEDIFF(YEAR, cust2.DateOfBirth, COALESCE(app.AppDate, app.DipAcceptDate))
								- CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, cust2.DateOfBirth, COALESCE(app.AppDate, app.DipAcceptDate)), cust2.DateOfBirth)
												> COALESCE(app.AppDate, app.DipAcceptDate) THEN 1 
										ELSE 0 
								END
				END
, YoungestAgeAtApp = CASE WHEN applicants.YoungestDOB IS NULL OR app.AppDate IS NULL THEN NULL
							ELSE DATEDIFF(YEAR, applicants.YoungestDOB, app.AppDate)
									- CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, applicants.YoungestDOB, app.AppDate), applicants.YoungestDOB)
											> app.AppDate THEN 1 
											ELSE 0 
									END
					END
, Cust1FirstTimeBuyer = IIF(cust1.FTBFlag = 1, 'True', 'False')
, Cust2FirstTimeBuyer = IIF(cust2.FTBFlag = 1, 'True', 'False')
, Cust1AgeatMaturity = (DATEDIFF(m,cust1.DateofBirth, COALESCE(app.CompDate, app.ExpectedCompDate, app.AppDate))+app.TermInMonths)/12
, Cust2AgeatMaturity = (DATEDIFF(m,cust2.DateofBirth, COALESCE(app.CompDate, app.ExpectedCompDate, app.AppDate))+app.TermInMonths)/12
, Cust1RetirementAge = cust1.RetirementAge 
, Cust2RetirementAge = cust2.RetirementAge
, Cust1RetirementDate = cust1.RetirementDate
, Cust2RetirementDate = cust2.RetirementDate
-----------
, Cust1LIRFlag = CASE 
				 WHEN app.LoanType = 'Residential'
				 THEN IIF(cust1.LIRFlag24AM = 1, 'Y', 'N')
				 ELSE IIF(cust1.LIRFlag = 1, 'Y', 'N')
				 END
, Cust2LIRFlag = CASE 
				 WHEN app.LoanType = 'Residential'
				 THEN IIF(cust2.LIRFlag24AM = 1, 'Y', 'N')
				 ELSE IIF(cust2.LIRFlag = 1, 'Y', 'N')
				 END
, LoanPurpose = app.MortgageType
, MortgageGroup = CASE WHEN app.MortgageType LIKE '%Remortgage%'
					   THEN 'Remortgage'
				   WHEN app.MortgageType = 'Purchase' AND app.FirstTimeBuyer = 1
					   THEN 'First Time Buyer'
				   ELSE 'Purchase'
			   END
, AppType = app.ProductTier --ISNULL(aff.ProductTypeBTL, 'Unknown')
, ProductTierJoin = IIF(
					ISNUMERIC(RIGHT(app.ProductTier, 1)) = '0' OR LEFT(app.ProductTier, 2) = 'RL'
					, 0
					, RIGHT(app.ProductTier, 1) + IIF(app.ProductTier LIKE 'TML%', 9, 0)
				)
, RepaymentType = tapps.RepaymentType
, CustomerLTV = NULL
, OriginalLTV = app.OriginalLTV
, ActualValuation = NULL
, CustomerProvidedValuation = NULL
, ValAge = DATEDIFF(m, prop.ValuationDate, COALESCE(app.CompDate, app.ExpectedCompDate, GETDATE()))
, app.CILTV
, LoanAmount = app.LoanAmount
, InitialLoanRequested = app.LoanAmount
, GrossLoanAmount = app.OpeningCapitalBalance
, MortgagePreCompAmount = NULL
, MultipleFlag = 0
, ExtraRemortgageBorrowing = NULL
, IsHomeImprovement = 0
, IsCapitalRaising = 0
, IsDebtConsolidation = CONVERT(INT, dapp.IsDebtConsolidation)
, DebtConsolidationAmount = 0
, InitialTermYears = ISNULL(app.TermInMonths, 0)/12   --(065)
, InitialTermMonths = ISNULL(app.TermInMonths, 0)     --(065)
, cust1.LoanMaturityDate
, app.ProductCode
, ProductTier = app.ProductTier
, ProductLTVBand = app.ProductMaxLTV
, ProductType = app.Product
, ProductGroup = CASE WHEN app.Product LIKE '%2 Year Tracker%'
					   THEN '2 Year Tracker'
				   WHEN app.Product LIKE '%2 Year Fixed%' 
					   THEN '2 Year Fixed'
				   WHEN app.Product LIKE '%5 Year Fixed%' 
					   THEN '5 Year Fixed'
				   ELSE 'Unknown'
			   END
, ProductFeature = CASE 
				    WHEN app.Product LIKE '%Semi-Exclusive%' THEN 'Semi-Exclusive'
				    WHEN app.Product LIKE '%Premier Exclusive%' THEN 'Premier Exclusive'
				    WHEN NULLIF(app.ProductFeature, '') IS NULL THEN 'Standard' --'N/A'
				    ELSE app.ProductFeature
				END
, NoCCJ_3m = cref.App1_CCJNo_3m + cref.App2_CCJNo_3m
, NoCCJ_6m = cref.App1_CCJNo_6m + cref.App2_CCJNo_6m
, NoCCJ_1yr = cref.App1_CCJNo_1yr + cref.App2_CCJNo_1yr
, ValueCCJ_1yr = cref.App1_CCJVal_1yr + cref.App2_CCJVal_1yr
, NoCCJ_2yr = cref.App1_CCJNo_2yr + cref.App2_CCJNo_2yr
, ValueCCJ_2yr = cref.App1_CCJVal_2yr + cref.App2_CCJVal_2yr
, NoCCJ_3yr = cref.App1_CCJNo_3yr + cref.App2_CCJNo_3yr
, ValueCCJ_3yr = cref.App1_CCJVal_3yr + cref.App2_CCJVal_3yr
, NoCCJ_4yr = cref.App1_CCJNo_4yr + cref.App2_CCJNo_4yr
, ValueCCJ_4yr = cref.App1_CCJVal_4yr + cref.App2_CCJVal_4yr
, NoCCJ_6yr = cref.App1_CCJNo_6yr + cref.App2_CCJNo_6yr
, ValueCCJ_6yr = cref.App1_CCJVal_6yr + cref.App2_CCJVal_6yr
, NoBOIVA_6yr = cref.App1_BONo_6yr + cref.App2_BONo_6yr + cref.App1_IVANo_6yr + cref.App2_IVANo_6yr
, ValueBOIVA_6yr = cref.App1_BOVal_6yr + cref.App2_BOVal_6yr + cref.App1_IVAVal_6yr + cref.App2_IVAVal_6yr
, NoBOIVA_3yr = cref.App1_BONo_3yr + cref.App2_BONo_3yr + cref.App1_IVANo_3yr + cref.App2_IVANo_3yr
, ValueBOIVA_3yr = cref.App1_BOVal_3yr + cref.App2_BOVal_3yr + cref.App1_IVAVal_3yr + cref.App2_IVAVal_3yr
, SecurityType = prop.PropertyType
, SecuritySubType = prop.PropertySubType
, prop.TenureType
, prop.LeaseRemaining
, LeaseAtEndOfTermYears = FLOOR(CONVERT(DECIMAL (5,1), IIF(prop.TenureType = 'Leasehold', prop.LeaseRemaining - (app.TermInMonths / 12.0), 0) ))
, PropertyType = CASE
				WHEN prop.PropertySubType = 'Detached' THEN 'Detached'
				WHEN prop.PropertySubType = 'SemiDetached' THEN 'Semi-Detached'
				WHEN prop.PropertySubType LIKE '%Terrace%' THEN 'Terraced'
				WHEN prop.PropertyType IN ('House','Bungalow') THEN 'Detached'
				WHEN prop.PropertyType LIKE '%Flat%' THEN 'Flat'
				WHEN prop.PropertyType ='Maisonette' THEN 'Maisonette'
				WHEN prop.PropertyType = 'Other' THEN 'Other'
				WHEN prop.PropertyType = 'Unknown' THEN 'Unknown'
				ELSE 'Other'
			END
, prop.Region
, prop.NumberOfBedrooms
, Broker = ''
, Network = NULL
, MortgageClub = NULL
, Packager = NULL
, IntroducerType = ''
, CreditReferenceId = cref.CreditReferenceId
, RNScore = app.RNScore
, TMLScore = ISNULL(app.TMLScore, 464)
------------------------------------------------------------------------------
-- TEMP UNTIL HAVE TIME TO FIX SLOW JOIN
, ScoreTier = CASE
			 WHEN app.TMLScore >= 622 THEN 'Tier 1'
			 WHEN app.TMLScore BETWEEN 609 AND 621 THEN 'Tier 2'
			 WHEN app.TMLScore BETWEEN 589 AND 608 THEN 'Tier 3'
			 WHEN app.TMLScore BETWEEN 569 AND 588 THEN 'Tier 4'
			 WHEN app.TMLScore BETWEEN 557 AND 568 THEN 'Tier 5'
			 WHEN app.TMLScore BETWEEN 535 AND 556 THEN 'Tier 6'
			 WHEN app.TMLScore BETWEEN 523 AND 534 THEN 'Tier 7'
			 WHEN app.TMLScore BETWEEN 512 AND 522 THEN 'Tier 8'
			 WHEN app.TMLScore BETWEEN 465 AND 511 THEN 'Tier 9'
			 WHEN app.TMLScore <= 464 THEN 'Decline'
			 ELSE NULL
			END
, ScoreDistribution = CASE
				    WHEN app.TMLScore <= 440 THEN 'Band 01: <= 440'
				    WHEN app.TMLScore <= 460 THEN 'Band 02: 441-460'
				    WHEN app.TMLScore <= 480 THEN 'Band 03: 461-480'
				    WHEN app.TMLScore <= 500 THEN 'Band 04: 481-500'
				    WHEN app.TMLScore <= 520 THEN 'Band 05: 501-520'
				    WHEN app.TMLScore <= 540 THEN 'Band 06: 521-540'
				    WHEN app.TMLScore <= 560 THEN 'Band 07: 541-560'
				    WHEN app.TMLScore <= 580 THEN 'Band 08: 561-580'
				    WHEN app.TMLScore <= 600 THEN 'Band 09: 581-600'
				    WHEN app.TMLScore <= 620 THEN 'Band 10: 601-620'
				    WHEN app.TMLScore <= 640 THEN 'Band 11: 621-640'
				    WHEN app.TMLScore <= 660 THEN 'Band 12: 641-660'
				    WHEN app.TMLScore <= 680 THEN 'Band 13: 661-680'
				    WHEN app.TMLScore <= 700 THEN 'Band 14: 681-700' 
				    WHEN app.TMLScore >  700 THEN 'Band 15: > 700'
				    ELSE NULL
				  END

------------------------------------------------------------------------------
, SelfEmployedFlag = CONVERT(INT, app.SelfEmployedFlag)
, RetirementFlagOLD = CASE
				WHEN FLOOR(DATEDIFF(dd, cust1.DateOfBirth, app.AppDate) / 365.25) >= cust1.MinRetirementAge 
				    THEN 0 -- already past retirement age or age 70, whichever lower
				WHEN cust1.MinRetirementAge - DATEDIFF(dd, cust1.DateOfBirth, app.AppDate) / 365.25 > 0
				    AND cust1.MinRetirementAge - DATEDIFF(dd, cust1.DateOfBirth, app.AppDate) / 365.25 < 10
				    THEN 1 -- < 10 years to retirement from app
				WHEN 100.0 * (DATEDIFF(dd, cust1.DateOfBirth, app.AppDate) / 365.25 + (app.TermInMonths)/12.0 - cust1.MinRetirementAge)
					 / ((app.TermInMonths)/12.0) 
					  > 25 
				    THEN 1 -- > 25% of term extends beyond retirement age or age 70, whichever lower
				WHEN cust2.DateOfBirth IS NULL 
				    THEN 0 --no customer 2
				WHEN FLOOR(DATEDIFF(dd, cust2.DateOfBirth, app.AppDate) / 365.25) >= cust2.MinRetirementAge 
				    THEN 0 -- already past retirement age or age 70, whichever lower
				WHEN cust2.MinRetirementAge - DATEDIFF(dd, cust2.DateOfBirth, app.AppDate) / 365.25 > 0
				    AND cust2.MinRetirementAge - DATEDIFF(dd, cust2.DateOfBirth, app.AppDate) / 365.25 < 10
				    THEN 1 -- < 10 years to retirement from app
				WHEN 100.0 * (DATEDIFF(dd, cust2.DateOfBirth, app.AppDate) / 365.25 + (app.TermInMonths)/12.0 - cust2.MinRetirementAge)
					 / ((app.TermInMonths)/12.0) 
					  > 25 
				    THEN 1 -- > 25% of term extends beyond retirement age or age 70, whichever lower
				ELSE 0
				END
, LendingIntoRetirement = CASE
						  WHEN app.LoanType = 'Residential'
						  THEN IIF(cust1.LendingIntoRetirement24AM = 1 OR cust2.LendingIntoRetirement24AM = 1, 1, 0)
						  ELSE IIF(cust1.LendingIntoRetirement = 1 OR cust2.LendingIntoRetirement = 1, 1, 0)
						  END
, PercentagePastRetirement = IIF(cust1.PercentPastRetirement >= ISNULL(cust2.PercentPastRetirement, 0), cust1.PercentPastRetirement, cust2.PercentPastRetirement)
, RetirementFlag = CASE
				   WHEN app.LoanType = 'Residential'
				   THEN IIF(cust1.LIRFlag24AM = 1 OR cust2.LIRFlag24AM = 1, 1, 0)
				   ELSE IIF(cust1.LIRFlag = 1 OR cust2.LIRFlag = 1, 1, 0)
				   END
, RetirementFlagReason = NULLIF(IIF(cust1.LIRFlagSetBy IS NOT NULL, 'App1: ' + cust1.LIRFlagSetBy + ' ', '')
									 + IIF(cust2.LIRFlagSetBy IS NOT NULL, 'App2: ' + cust2.LIRFlagSetBy + ' ', ''), '')
, ImpairedFlag = 0
, CCJsFlag = IIF(cref.App1_CCJNo_3yr + cref.App2_CCJNo_3yr > 0, 1, 0)
, app.FirstTimeBuyer
, NewBuildFlag = CONVERT(INT, prop.IsNewBuild)
, NewBuildIncentive = 0
, ISNULL(referrals.ReferralFlag, 0) AS ReferralFlag
, ArrearsTotal = 0
, GiftedEquityFlag = 0

-- BTL data
, InterestRate = ISNULL (
								IIF(app.Environment = 'Origination', app.AppInterestRate, app.InterestRate)
								, 0
					 )
, InterestRateJoin = ISNULL(IIF(app.Environment = 'Origination', app.AppInterestRate, app.InterestRate), 0) 
, AppInterestRate = ISNULL(app.AppInterestRate,0)
, AnnualRentalIncome = CONVERT(DECIMAL(20,2),i.MonthlyRentalIncome * 12)
, MonthlyRentalIncome = i.MonthlyRentalIncome
, i.StressedMonthlyInterestPayment
, i.StressTestRate
, i.ICR
, i.ICRAdjusted
, RentAdjustedForAffPass = 0
, BTLScore = app.TMLScore
, Over65Flag = CASE WHEN OldestDOB IS NULL OR app.AppDate IS NULL THEN 0
					ELSE CASE WHEN ( DATEDIFF(YEAR, OldestDOB, app.AppDate) - 
										CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, OldestDOB, app.AppDate), OldestDOB) > app.AppDate THEN 1 
											ELSE 0
										END
									) > 65 THEN 1 
							ELSE 0 
						END
				END


, Over70Flag = CASE WHEN applicants.YoungestDOB IS NULL OR app.AppDate IS NULL THEN 0
					ELSE CASE WHEN ( DATEDIFF(YEAR, applicants.YoungestDOB, app.AppDate) -
										CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, applicants.YoungestDOB, app.AppDate), applicants.YoungestDOB) > app.AppDate THEN 1 
											ELSE 0
										END
									) > 70 THEN 1 
							ELSE 0 
						END
				END
, app.CustomerType
, FTBTL = NULL
			
, Expat = IIF(custTotals.Expats > 0, 1, 0)
, PortfolioFlag = NULL
, PortfolioCount = NULL
, TMLPortfolio = custTotals.BTLOwners
-- Latest Affordability Data
, RequestedLoanAmount = NULL
, BestResultTwoYear = NULL
, BestResultFiveYear = NULL
, AffordabilityRating = NULL
, AfordabilityBestTier = NULL
, MaxLoanTwoYear = NULL 
, MaxLoanFiveYear = NULL
, app.Securitised 	 
, app.SecuritisationStatus
, app.ReversionDate
, ISNULL(prod.ProductRange, 'Unkown') AS ProductRange

---- COVID reporting
, PaymentHoliday = 0
, HolidayPeriod = NULL
, CurrentIncomeStatus = 0
, Industry = ''
, RateType = NULL
, app.RevertedFlag
, AgreedHolidaysCount = NULL
, ExtensionMonth = NULL
, ExtensionMonthNo = NULL
, CurrentBalance = IIF(app.LoanType = 'Residential', app.CurrentBalance, app.ActualCurrentBalance)	
, DeferralStatus = 0
, YoungestAgeBorrower = IIF(cust1.AgeAtApp <= ISNULL(cust2.AgeAtApp, 999), cust1.AgeAtApp, cust2.AgeAtApp)
, RevertNotRedeemed =  CASE WHEN app.AccountClosedDate IS NULL AND app.RevertedFlag = 1  THEN 'Reverted Not Redeemed'
						WHEN app.AccountClosedDate >= app.ReversionDate AND app.RevertedFlag = 1  THEN 'Redeemed after Reverted'
						WHEN app.AccountClosedDate < app.ReversionDate AND app.RevertedFlag = 1  THEN 'Redeemed before Reverted'
						ELSE 'Not Reverted'
					END
, app.SecuritisationTag, app.SecuritisationFlag

------ Columns moved from sp_Strats to the build scrip
, app.UADate
, isnull(prod.DateActive, '9999-12-31') as ProductDateActive
, cref.NoDebtManagementPlans

------------------------------------------------------------

---- default values for groups . Will be overwritten in queries after
, CustomerLTVSegment = CONVERT(VARCHAR(50), 'Error')
, CustomerLTVSegmentOrder = 99
, CustomerBTLLTVSegment = CONVERT(VARCHAR(50), 'Error')
, CustomerBTLLTVSegmentOrder = 99
, LTVSegment = CONVERT(VARCHAR(50), 'Error') 
, LTVSegmentOrder = 99 
, LTVSegmentResidential =  CONVERT(VARCHAR(50), 'Error')
, LTVSegmentOrderResidential = 99 
, LTVSegmentBTL = CONVERT(VARCHAR(50), 'Error') 
, LTVSegmentOrderBTL = 0 
, LoanAmountCategory = CONVERT(VARCHAR(50), 'Error') 
, LoanCategoryOrder =  99
, IncomeGroup = CONVERT(VARCHAR(50), 'Error') 
, IncomeGroupOrder =  99
, IncomeMultipleGroup = IIF(app.LoanType = 'BTL', 'N/A', CONVERT(VARCHAR(50), 'Error'))
, IncomeMultipleOrder = IIF(app.LoanType = 'BTL', 99,  99)
, TierAssetClass = CONVERT(VARCHAR(50), 'Unknown Band')
, BedroomCatgeory = CONVERT(VARCHAR(50), NULL) 
, BedroomOrderNo = CONVERT(INT, NULL)
, RNGroup = CONVERT(VARCHAR(50), NULL) 
, RNGroupNo = CONVERT(INT, NULL)
, InterestRateGroup = CONVERT(VARCHAR(50), NULL) 
, InterestRateOrder = CONVERT(INT, NULL)
, ICRSegment = CONVERT(VARCHAR(50), 'Unknown')
, ICRSegmentOrder = 99
, ICR2Segment = CONVERT(VARCHAR(50), 'Unknown')
, ICR2SegmentOrder = 99
, UnderwritingMandateLevel = CONVERT(VARCHAR(50), NULL) 
, UWMandateLevelOrder = CONVERT(INT, NULL)
, tapps.PTDate
, app.OriginationSource
-----------------------------------------------------------

INTO #bml_strats
FROM #apps app
LEFT JOIN DPR_DW.dbo.DIM_CO_Application dapp ON app.ApplicationRef = dapp.ApplicationRef COLLATE DATABASE_DEFAULT AND dapp.SCDStatus = 'C'
LEFT JOIN #tapps tapps ON app.ApplicationRef = tapps.ApplicationRef
LEFT JOIN #bml_calcs i ON i.ApplicationRef = app.ApplicationRef 
LEFT OUTER JOIN TML_DW.dbo.tbl_PropertyDetails prop ON app.ApplicationRef = prop.ApplicationRef COLLATE DATABASE_DEFAULT
LEFT JOIN TML_DW.dbo.vw_ApplicationReportStatus repStat ON app.LatestStatus = repStat.LatestStatus COLLATE DATABASE_DEFAULT
LEFT OUTER JOIN TML_DW.dbo.tbl_Applicants cust1 ON app.ApplicationRef = cust1.ApplicationRef AND cust1.BoEAppNo = 1
LEFT OUTER JOIN TML_DW.dbo.tbl_Applicants cust2 ON app.ApplicationRef = cust2.ApplicationRef AND cust2.BoEAppNo = 2
LEFT OUTER JOIN TML_DW.dbo.tbl_CreditRefLatest cref ON app.APplicationRef = cref.ApplicationRef COLLATE DATABASE_DEFAULT

---- REFERRALS

LEFT OUTER JOIN 
	(
	SELECT
		  ApplicationRef
		, SUM(IIF(ReferralType = 'Internal', 1, 0)) AS InternalReferrals
		, SUM(IIF(ReferralType = 'Funder', 1, 0)) AS FunderReferrals
		, 1 AS ReferralFlag 
	FROM TML_DW.dbo.tbl_Referrals
	GROUP BY ApplicationRef
	) referrals ON app.ApplicationRef = referrals.ApplicationRef COLLATE DATABASE_DEFAULT

--------------------------------------------------------------------------------------------------------------

---- BTL specific data
LEFT OUTER JOIN 
	(
    SELECT
		  ApplicationRef
		, YoungestDOB = MAX(DateOfBirth) 
		, OldestDOB = MIN(DateOfBirth)
		, NoApplicants = COUNT(*)
    FROM TML_DW.dbo.tbl_Applicants
    GROUP BY ApplicationRef
	) applicants ON app.ApplicationRef = applicants.ApplicationRef

LEFT OUTER JOIN 
	(
    SELECT
		  ApplicationRef
		, Applicants = COUNT(*)
		, BTLOwners = SUM(AnyBTLProperties) 
		, Expats = SUM(IsExPat) 
    FROM TML_DW.dbo.tbl_Applicants
    GROUP BY ApplicationRef
	) custTotals ON app.ApplicationRef = custTotals.ApplicationRef

LEFT JOIN TML_DW.dbo.tbl_Products prod ON app.ProductCode = prod.ProductCode
WHERE app.DipAcceptDate IS NOT NULL
AND app.OriginationSource = 'BML'

OPTION(RECOMPILE);


--------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('tempdb..#bml_strats2') IS NOT NULL
DROP TABLE #bml_strats2;

SELECT s.COBID, s.COBDate, s.ApplicationRef, s.LoanType, s.DIPCreatedDate, s.DipAcceptDate, s.DIPSubmitDate
	, s.DateDIPAccept, s.AppDate, s.FirstOfferDate, s.ReofferDate, s.CompDate, s.LatestStatus, s.Environment
	, s.ReportStatus, s.NoApplicants, s.Cust1MaritalStatus, s.Cust2MaritalStatus, s.Cust1EmploymentType
	, s.Cust2EmploymentType, s.Cust1DateOfBirth, s.Cust2DateOfBirth, s.Cust1Income, s.Cust2Income, s.CombinedIncome
	, s.IncomeGroup, s.IncomeGroupOrder, s.Cust1AgeAtApp, s.Cust2AgeAtApp, s.YoungestAgeAtApp, s.Cust1FirstTimeBuyer
	, s.Cust2FirstTimeBuyer, s.Cust1AgeatMaturity, s.Cust2AgeatMaturity, s.Cust1RetirementAge, s.Cust2RetirementAge
	, s.Cust1RetirementDate, s.Cust2RetirementDate, s.Cust1LIRFlag, s.Cust2LIRFlag, s.LoanPurpose, s.MortgageGroup
	, s.AppType, s.RepaymentType, s.CustomerLTV, s.CustomerLTVSegment, s.CustomerLTVSegmentOrder, s.CustomerBTLLTVSegment
	, s.CustomerBTLLTVSegmentOrder, s.OriginalLTV, s.LTVSegment, s.LTVSegmentOrder, s.LTVSegmentResidential
	, s.LTVSegmentOrderResidential, s.LTVSegmentBTL, s.LTVSegmentOrderBTL, s.ActualValuation, s.CustomerProvidedValuation
	, s.ValAge, s.CILTV, s.LoanAmount, s.InitialLoanRequested, s.GrossLoanAmount, s.MortgagePreCompAmount
	, s.LoanAmountCategory, s.LoanCategoryOrder, s.IncomeMultipleOLD, s.IncomeMultiple, s.IncomeMultipleGroup
	, s.IncomeMultipleOrder, s.MultipleFlag, s.ExtraRemortgageBorrowing, s.IsHomeImprovement, s.IsCapitalRaising
	, s.IsDebtConsolidation, s.DebtConsolidationAmount, s.InitialTermYears, s.InitialTermMonths, s.LoanMaturityDate
	, s.ProductCode, s.ProductTier, s.ProductLTVBand, s.ProductType, s.ProductGroup, s.ProductFeature, s.TierAssetClass
	, s.NoCCJ_3m, s.NoCCJ_6m, s.NoCCJ_1yr, s.ValueCCJ_1yr, s.NoCCJ_2yr, s.ValueCCJ_2yr, s.NoCCJ_3yr, s.ValueCCJ_3yr
	, s.NoCCJ_4yr, s.ValueCCJ_4yr, s.NoCCJ_6yr, s.ValueCCJ_6yr, s.NoBOIVA_6yr, s.ValueBOIVA_6yr, s.NoBOIVA_3yr
	, s.ValueBOIVA_3yr, s.SecurityType, s.SecuritySubType, s.TenureType, s.LeaseRemaining, s.LeaseAtEndOfTermYears
	, s.PropertyType, s.Region, s.NumberOfBedrooms, s.BedroomCatgeory, s.BedroomOrderNo, s.Broker, s.Network, s.MortgageClub
	, s.Packager, s.IntroducerType, s.CreditReferenceId, s.RNScore, s.RNGroup, s.RNGroupNo, s.TMLScore, s.ScoreTier
	, s.ScoreDistribution, s.SelfEmployedFlag, s.RetirementFlagOLD, s.LendingIntoRetirement, s.PercentagePastRetirement
	, s.RetirementFlag, s.RetirementFlagReason, s.ImpairedFlag, s.CCJsFlag, s.FirstTimeBuyer, s.NewBuildFlag
	, s.NewBuildIncentive, s.ReferralFlag, s.ArrearsTotal, s.GiftedEquityFlag, s.InterestRate, s.AppInterestRate
	, s.InterestRateGroup, s.InterestRateOrder, s.AnnualRentalIncome, s.MonthlyRentalIncome, s.StressedMonthlyInterestPayment
	, s.StressTestRate, s.ICR, s.ICRSegment, s.ICRSegmentOrder, s.ICR2Segment, s.ICR2SegmentOrder, s.ICRAdjusted
	, s.RentAdjustedForAffPass, s.BTLScore, s.Over65Flag, s.Over70Flag, s.CustomerType, s.FTBTL, s.Expat, s.PortfolioFlag
	, s.PortfolioCount, s.TMLPortfolio, s.RequestedLoanAmount, s.BestResultTwoYear, s.BestResultFiveYear, s.AffordabilityRating
	, s.AfordabilityBestTier, s.MaxLoanTwoYear, s.MaxLoanFiveYear, s.Securitised, s.SecuritisationStatus, s.ReversionDate
	, s.ProductRange, s.PaymentHoliday, s.HolidayPeriod, s.CurrentIncomeStatus, s.Industry, s.RateType, s.RevertedFlag
	, HolidayActive = 0 , s.AgreedHolidaysCount, s.ExtensionMonth, s.ExtensionMonthNo, s.CurrentBalance, s.DeferralStatus
	, s.UnderwritingMandateLevel, s.UWMandateLevelOrder, s.YoungestAgeBorrower, s.RevertNotRedeemed, s.SecuritisationTag
	, s.SecuritisationFlag, s.UADate, s.ProductDateActive, s.NoDebtManagementPlans, s.PTDate

----Columns from sp_Strats moved to the populate script for use in Power BI
	, CapitalRaised = ISNULL(IIF(s.LoanAmount = 0,0,(s.ExtraRemortgageBorrowing/s.LoanAmount))*100, 0)
	, IIF (s.ICR > 10 AND s.MonthlyRentalIncome > 10000 ,'Y', 'N') AS ICROutlier
	, CapitalRaisedSeg = rc.CategoryName, CapRaisedDebtExclSeg = rc1.CategoryName, DebtConSeg = rc22.CategoryName

---- Columns added for new conversion SSRS report
	, DipSubmitMonthD = EOMONTH(s.DIPSubmitDate), DipAcceptMonthD = EOMONTH(s.DipAcceptDate), AppMonthD = EOMONTH(s.AppDate)
	, OfferMonthD = EOMONTH(s.FirstOfferDate), CompMonthD = EOMONTH(s.CompDate)
	, DipSubmitMonth = CASE WHEN s.DIPSubmitDate IS NULL THEN NULL
							ELSE LEFT(DATENAME(MONTH, s.DIPSubmitDate), 3) + '-' + RIGHT(CONVERT(CHAR(4), YEAR(s.DIPSubmitDate)), 2)
						END
	, DipAcceptMonth = CASE WHEN s.DipAcceptDate IS NULL THEN NULL
							ELSE LEFT(DATENAME(MONTH, s.DipAcceptDate), 3) + '-' + RIGHT(CONVERT(CHAR(4), YEAR(s.DipAcceptDate)), 2)
						END
	, AppMonth = CASE WHEN s.AppDate IS NULL THEN NULL
					ELSE LEFT(DATENAME(MONTH, s.AppDate), 3) + '-' + RIGHT(CONVERT(CHAR(4), YEAR(s.AppDate)), 2)
				END
	, OfferMonth = CASE WHEN s.FirstOfferDate IS NULL THEN NULL
						ELSE LEFT(DATENAME(MONTH, s.FirstOfferDate), 3) + '-' + RIGHT(CONVERT(CHAR(4), YEAR(s.FirstOfferDate)), 2)
					END 
	, CompMonth = CASE WHEN s.CompDate IS NULL THEN NULL
						ELSE LEFT(DATENAME(MONTH, s.CompDate), 3) + '-' + RIGHT(CONVERT(CHAR(4), YEAR(s.CompDate)), 2)
					END
	, DipSubmit = IIF(s.DIPSubmitDate IS NULL, 1, 0), AppSubmitted = IIF(s.AppDate IS NULL, 1, 0)
	, Offered = IIF(s.FirstOfferDate IS NULL, 1, 0), Completed = IIF(s.CompDate IS NULL, 1, 0), DipSubmitMonthBack = DATEDIFF(m, s.DIPSubmitDate, @endDate)
	, DipAcceptMonthBack = DATEDIFF(m, s.DipAcceptDate, @endDate), AppMonthBack = DATEDIFF(m, s.AppDate, @endDate)
	, OfferMonthBack = DATEDIFF(m, s.FirstOfferDate, @endDate), CompMonthBack = DATEDIFF(m, s.CompDate, @endDate)

	, CASE WHEN s.LoanType ='Residential2' AND s.ProductCode >= '2575' THEN 'New'
		WHEN s.LoanType = 'Residential2' AND s.ProductCode < '2575' THEN 'Old'
		WHEN s.LoanType = 'Residential2' AND s.ProductCode IS NULL AND s.DipAcceptDate < '2022-02-15' THEN 'Old'
		WHEN s.LoanType = 'Residential2' AND s.ProductCode IS NULL AND s.DipAcceptDate >= '2022-02-15' THEN 'New'
		ELSE NULL
		END AS SBResiProductFilter
		
	, TrueArrearsRatio = ISNULL(ad.TrueArrearsRatio, 0), ISNULL(PDLoans.NoPayDayLoans, 0) AS NoPayDayLoans
	, NULL AS NoBo6m ,NULL AS BoVal6m, NULL AS NoBo1yr, NULL AS BoVal1yr, NULL AS NoBo2yr, NULL AS BoVal2yr, NULL AS NoBo3yr, NULL AS BoVal3yr, NULL AS NoBo4yr
	, NULL AS BoVal4yr, NULL AS NoBo6yr, NULL AS BoVal6yr, NULL AS NoIVA1yr, NULL AS IVAVal1yr, NULL AS NoIVA2yr, NULL AS IVAVal2yr, NULL AS NoIVA3yr
	, NULL AS IVAVal3yr, NULL AS NoIVA6yr, NULL AS IVAVal6yr, 0 AS Default1m, 0 AS Default3m
	, 0 AS Default6m, 0 AS Default12m, 0 AS Default18m
	, 0 AS Default24m, 0 AS Default36m, 0 AS Default48m
	, 0 AS Default60m, 0 AS Default72m, 0 AS Missed3Mths
	, 0 AS Missed6Mths, 0 AS Missed12Mths, 0 AS Missed18Mths
	, 0 AS Missed24Mths, 0 AS Missed36Mths, 0 AS Missed48Mths
	, 0 AS Missed60Mths, 0 AS Missed72Mths

	, prr.OrderNo AS SBResiProductOrder, Repossion = IIF(Repo.CurrentStatus = 'Possession', 1, 0) ,prr.RLUMI
	, 0 AS UnsMissed3Mths ,	0 AS UnsMissed6Mths,		0 AS UnsMissed12Mths
	, 0 AS UnsMissed18Mths,	0 AS UnsMissed24Mths,	0 AS UnsMissed36Mths
	, 0 AS UnsMissed48Mths,	0 AS UnsMissed60Mths,	0 AS UnsMissed72Mths
	, 0 AS UnsDefaults1m,	0 AS UnsDefaults3m,		0 AS UnsDefaults6m
	, 0 AS UnsDefaults12m,	0 AS UnsDefaults18m,		0 AS UnsDefaults24m
	, 0 AS UnsDefaults36m,	0 AS UnsDefaults48m,		0 AS UnsDefaults60m
	, 0 AS UnsDefaults72m
	, s.OriginationSource
	, HasWrokingVisa = 0
INTO #bml_strats2
FROM #bml_strats s
CROSS APPLY (
    SELECT
        CapitalRaisedPct =
            ISNULL(CASE WHEN s.LoanAmount = 0 THEN 0
                              ELSE (s.ExtraRemortgageBorrowing / s.LoanAmount) * 100.0
                         END,  0),

        CapRaisedDebtExclPct =
            ISNULL(CASE WHEN s.LoanAmount = 0 THEN 0
                              ELSE ((s.ExtraRemortgageBorrowing - s.DebtConsolidationAmount) / s.LoanAmount) * 100.0
                         END, 0),

        DebtConPct =
            ISNULL(CASE WHEN s.LoanAmount = 0 THEN 0
                              ELSE (s.DebtConsolidationAmount / s.LoanAmount) * 100.0
                         END,  0)
) cr
LEFT JOIN #groups rc ON cr.CapitalRaisedPct BETWEEN rc.MinValue AND rc.MaxValue
							AND rc.CategoryGroup = 'Capital Raised'
LEFT JOIN #groups rc1 ON cr.CapRaisedDebtExclPct BETWEEN rc1.MinValue AND rc1.MaxValue
							AND rc1.CategoryGroup = 'Capital Raised'
LEFT JOIN #groups rc22 ON cr.DebtConPct BETWEEN rc22.MinValue AND rc22.MaxValue
							AND rc22.CategoryGroup = 'Capital Raised'

LEFT OUTER JOIN (SELECT ApplicationRef, COUNT(ApplicationRef) AS NoPayDayLoans
					FROM dbo.tbl_PaymentProfiles
					WHERE 1 = 1
					AND AccountType = 'PayDayLoans'
					GROUP BY ApplicationRef) PDLoans ON PDLoans.ApplicationRef = s.ApplicationRef

LEFT OUTER JOIN ( SELECT AccountNo, CurrentStatus 
				FROM TML_DW.dbo.fn_Litigations(@endcob) 
				WHERE CurrentStatusGroup = 'Possession'
				) repo ON repo.AccountNo = s.ApplicationRef
LEFT OUTER JOIN TML_DW.dbo.tbl_ProductsReportRanking prr ON prr.Tier = s.ProductTier
LEFT OUTER JOIN #Arrears ad ON ad.accountno = s.applicationRef  

--------------------------------------------------------------------------------------------------------------
-- BML residential LTV segment
UPDATE s 
SET LTVSegment =  grp_ltvSeg.CategoryName
, LTVSegmentOrder = grp_ltvSeg.Orderno
, LTVSegmentResidential =  grp_ltvSeg.CategoryName
, LTVSegmentOrderResidential = grp_ltvSeg.Orderno
FROM #bml_strats2 s
INNER JOIN #groups grp_ltvSeg ON s.OriginalLTV BETWEEN grp_ltvSeg.MinValue AND grp_ltvSeg.MaxValue
								AND grp_ltvSeg.CategoryGroup = 'LTV Segment'
WHERE OriginationSource = 'BML'

--------------------------------------------------------------------------------------------------------------

-- loan amount
UPDATE s 
SET s.LoanAmountCategory = grp_loanVal.CategoryName
, LoanCategoryOrder = grp_loanVal.OrderNo
FROM #bml_strats2 s 
LEFT OUTER JOIN #groups grp_loanVal ON s.GrossLoanAmount BETWEEN grp_loanVal.MinValue AND grp_loanVal.MaxValue
										AND grp_loanVal.CategoryGroup = 'Loan Amount'

--------------------------------------------------------------------------------------------------------------

-- BTL LTV segment
UPDATE s 
SET LTVSegmentBTL = grp_ltvBTLSeg.CategoryName
, LTVSegmentOrderBTL = grp_ltvBTLSeg.OrderNo
FROM #bml_strats2 s
LEFT OUTER JOIN #groups grp_ltvBTLSeg ON ISNULL(OriginalLTV, 0) BETWEEN grp_ltvBTLSeg.MinValue AND grp_ltvBTLSeg.MaxValue
										AND grp_ltvBTLSeg.CategoryGroup = 'BTL LTV Segment'

--------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#comb_strats') IS NOT NULL
DROP TABLE #comb_strats;

SELECT COBID, COBDate, ApplicationRef, LoanType, DIPCreatedDate, DipAcceptDate, DIPSubmitDate, DateDIPAccept, AppDate, FirstOfferDate, ReofferDate
	, CompDate, LatestStatus, Environment, ReportStatus, NoApplicants, Cust1MaritalStatus, Cust2MaritalStatus, Cust1EmploymentType, Cust2EmploymentType
	, Cust1DateOfBirth, Cust2DateOfBirth, Cust1Income, Cust2Income, CombinedIncome, IncomeGroup, IncomeGroupOrder, Cust1AgeAtApp, Cust2AgeAtApp
	, YoungestAgeAtApp, Cust1FirstTimeBuyer, Cust2FirstTimeBuyer, Cust1AgeatMaturity, Cust2AgeatMaturity, Cust1RetirementAge, Cust2RetirementAge
	, Cust1RetirementDate, Cust2RetirementDate, Cust1LIRFlag, Cust2LIRFlag, LoanPurpose, MortgageGroup, AppType, RepaymentType, CustomerLTV
	, CustomerLTVSegment, CustomerLTVSegmentOrder, CustomerBTLLTVSegment, CustomerBTLLTVSegmentOrder, OriginalLTV, LTVSegment, LTVSegmentOrder
	, LTVSegmentResidential, LTVSegmentOrderResidential, LTVSegmentBTL, LTVSegmentOrderBTL, ActualValuation, CustomerProvidedValuation, ValAge
	, CILTV, LoanAmount, InitialLoanRequested, GrossLoanAmount, MortgagePreCompAmount, LoanAmountCategory, LoanCategoryOrder, IncomeMultipleOLD
	, IncomeMultiple, IncomeMultipleGroup, IncomeMultipleOrder, MultipleFlag, ExtraRemortgageBorrowing, IsHomeImprovement, IsCapitalRaising
	, IsDebtConsolidation, DebtConsolidationAmount, InitialTermYears, InitialTermMonths, LoanMaturityDate, ProductCode, ProductTier, ProductLTVBand
	, ProductType, ProductGroup, ProductFeature, TierAssetClass, NoCCJ_3m, NoCCJ_6m, NoCCJ_1yr, ValueCCJ_1yr, NoCCJ_2yr, ValueCCJ_2yr, NoCCJ_3yr
	, ValueCCJ_3yr, NoCCJ_4yr, ValueCCJ_4yr, NoCCJ_6yr, ValueCCJ_6yr, NoBOIVA_6yr, ValueBOIVA_6yr, NoBOIVA_3yr, ValueBOIVA_3yr, SecurityType
	, SecuritySubType, TenureType, LeaseRemaining, LeaseAtEndOfTermYears, PropertyType, Region, NumberOfBedrooms, BedroomCatgeory, BedroomOrderNo
	, Broker, Network, MortgageClub, Packager, IntroducerType, CreditReferenceId, RNScore, RNGroup, RNGroupNo, TMLScore, ScoreTier, ScoreDistribution
	, SelfEmployedFlag, RetirementFlagOLD, LendingIntoRetirement, PercentagePastRetirement, RetirementFlag, RetirementFlagReason, ImpairedFlag
	, CCJsFlag, FirstTimeBuyer, NewBuildFlag, NewBuildIncentive, ReferralFlag, ArrearsTotal, GiftedEquityFlag, InterestRate, AppInterestRate
	, InterestRateGroup, InterestRateOrder, AnnualRentalIncome, MonthlyRentalIncome, StressedMonthlyInterestPayment, StressTestRate, ICR
	, ICRSegment, ICRSegmentOrder, ICR2Segment, ICR2SegmentOrder, ICRAdjusted, RentAdjustedForAffPass, BTLScore, Over65Flag, Over70Flag
	, CustomerType, FTBTL, Expat, PortfolioFlag, PortfolioCount, TMLPortfolio, RequestedLoanAmount, BestResultTwoYear, BestResultFiveYear
	, AffordabilityRating, AfordabilityBestTier, MaxLoanTwoYear, MaxLoanFiveYear, Securitised, SecuritisationStatus, ReversionDate, ProductRange
	, PaymentHoliday, HolidayPeriod, CurrentIncomeStatus, Industry, RateType, RevertedFlag, HolidayActive, AgreedHolidaysCount, ExtensionMonth
	, ExtensionMonthNo, CurrentBalance, DeferralStatus, UnderwritingMandateLevel, UWMandateLevelOrder, YoungestAgeBorrower, RevertNotRedeemed
	, SecuritisationTag, SecuritisationFlag, UADate, ProductDateActive, NoDebtManagementPlans, PTDate, CapitalRaised, ICROutlier, CapitalRaisedSeg
	, CapRaisedDebtExclSeg, DebtConSeg, DipSubmitMonthD, DipAcceptMonthD, AppMonthD, OfferMonthD, CompMonthD, DipSubmitMonth, DipAcceptMonth
	, AppMonth, OfferMonth, CompMonth, DipSubmit, AppSubmitted, Offered, Completed, DipSubmitMonthBack, DipAcceptMonthBack, AppMonthBack
	, OfferMonthBack, CompMonthBack, SBResiProductFilter, TrueArrearsRatio, NoPayDayLoans, NoBo6m, BoVal6m, NoBo1yr, BoVal1yr, NoBo2yr, BoVal2yr
	, NoBo3yr, BoVal3yr, NoBo4yr, BoVal4yr, NoBo6yr, BoVal6yr, NoIVA1yr, IVAVal1yr, NoIVA2yr, IVAVal2yr, NoIVA3yr, IVAVal3yr, NoIVA6yr, IVAVal6yr
	, Default1m, Default3m, Default6m, Default12m, Default18m, Default24m, Default36m, Default48m, Default60m, Default72m, Missed3Mths, Missed6Mths
	, Missed12Mths, Missed18Mths, Missed24Mths, Missed36Mths, Missed48Mths, Missed60Mths, Missed72Mths, SBResiProductOrder, Repossion, RLUMI
	, UnsMissed3Mths, UnsMissed6Mths, UnsMissed12Mths, UnsMissed18Mths, UnsMissed24Mths, UnsMissed36Mths, UnsMissed48Mths, UnsMissed60Mths
	, UnsMissed72Mths, UnsDefaults1m, UnsDefaults3m, UnsDefaults6m, UnsDefaults12m, UnsDefaults18m, UnsDefaults24m, UnsDefaults36m
	, UnsDefaults48m, UnsDefaults60m, UnsDefaults72m, OriginationSource, HasWorkingVisa 
INTO #comb_strats 
FROM #strats2
	
INSERT INTO  #comb_strats

SELECT COBID, COBDate, ApplicationRef, LoanType, DIPCreatedDate, DipAcceptDate, DIPSubmitDate, DateDIPAccept, AppDate, FirstOfferDate, ReofferDate
	, CompDate, LatestStatus, Environment, ReportStatus, NoApplicants, Cust1MaritalStatus, Cust2MaritalStatus, Cust1EmploymentType, Cust2EmploymentType
	, Cust1DateOfBirth, Cust2DateOfBirth, Cust1Income, Cust2Income, CombinedIncome, IncomeGroup, IncomeGroupOrder, Cust1AgeAtApp, Cust2AgeAtApp
	, YoungestAgeAtApp, Cust1FirstTimeBuyer, Cust2FirstTimeBuyer, Cust1AgeatMaturity, Cust2AgeatMaturity, Cust1RetirementAge, Cust2RetirementAge
	, Cust1RetirementDate, Cust2RetirementDate, Cust1LIRFlag, Cust2LIRFlag, LoanPurpose, MortgageGroup, AppType, RepaymentType, CustomerLTV
	, CustomerLTVSegment, CustomerLTVSegmentOrder, CustomerBTLLTVSegment, CustomerBTLLTVSegmentOrder, OriginalLTV, LTVSegment, LTVSegmentOrder
	, LTVSegmentResidential, LTVSegmentOrderResidential, LTVSegmentBTL, LTVSegmentOrderBTL, ActualValuation, CustomerProvidedValuation, ValAge
	, CILTV, LoanAmount, InitialLoanRequested, GrossLoanAmount, MortgagePreCompAmount, LoanAmountCategory, LoanCategoryOrder, IncomeMultipleOLD
	, IncomeMultiple, IncomeMultipleGroup, IncomeMultipleOrder, MultipleFlag, ExtraRemortgageBorrowing, IsHomeImprovement, IsCapitalRaising
	, IsDebtConsolidation, DebtConsolidationAmount, InitialTermYears, InitialTermMonths, LoanMaturityDate, ProductCode, ProductTier, ProductLTVBand
	, ProductType, ProductGroup, ProductFeature, TierAssetClass, NoCCJ_3m, NoCCJ_6m, NoCCJ_1yr, ValueCCJ_1yr, NoCCJ_2yr, ValueCCJ_2yr, NoCCJ_3yr
	, ValueCCJ_3yr, NoCCJ_4yr, ValueCCJ_4yr, NoCCJ_6yr, ValueCCJ_6yr, NoBOIVA_6yr, ValueBOIVA_6yr, NoBOIVA_3yr, ValueBOIVA_3yr, SecurityType
	, SecuritySubType, TenureType, LeaseRemaining, LeaseAtEndOfTermYears, PropertyType, Region, NumberOfBedrooms, BedroomCatgeory, BedroomOrderNo
	, Broker, Network, MortgageClub, Packager, IntroducerType, CreditReferenceId, RNScore, RNGroup, RNGroupNo, TMLScore, ScoreTier, ScoreDistribution
	, SelfEmployedFlag, RetirementFlagOLD, LendingIntoRetirement, PercentagePastRetirement, RetirementFlag, RetirementFlagReason, ImpairedFlag
	, CCJsFlag, FirstTimeBuyer, NewBuildFlag, NewBuildIncentive, ReferralFlag, ArrearsTotal, GiftedEquityFlag, InterestRate, AppInterestRate
	, InterestRateGroup, InterestRateOrder, AnnualRentalIncome, MonthlyRentalIncome, StressedMonthlyInterestPayment, StressTestRate, ICR
	, ICRSegment, ICRSegmentOrder, ICR2Segment, ICR2SegmentOrder, ICRAdjusted, RentAdjustedForAffPass, BTLScore, Over65Flag, Over70Flag
	, CustomerType, FTBTL, Expat, PortfolioFlag, PortfolioCount, TMLPortfolio, RequestedLoanAmount, BestResultTwoYear, BestResultFiveYear
	, AffordabilityRating, AfordabilityBestTier, MaxLoanTwoYear, MaxLoanFiveYear, Securitised, SecuritisationStatus, ReversionDate, ProductRange
	, PaymentHoliday, HolidayPeriod, CurrentIncomeStatus, Industry, RateType, RevertedFlag, HolidayActive, AgreedHolidaysCount, ExtensionMonth
	, ExtensionMonthNo, CurrentBalance, DeferralStatus, UnderwritingMandateLevel, UWMandateLevelOrder, YoungestAgeBorrower, RevertNotRedeemed
	, SecuritisationTag, SecuritisationFlag, UADate, ProductDateActive, NoDebtManagementPlans, PTDate, CapitalRaised, ICROutlier, CapitalRaisedSeg
	, CapRaisedDebtExclSeg, DebtConSeg, DipSubmitMonthD, DipAcceptMonthD, AppMonthD, OfferMonthD, CompMonthD, DipSubmitMonth, DipAcceptMonth
	, AppMonth, OfferMonth, CompMonth, DipSubmit, AppSubmitted, Offered, Completed, DipSubmitMonthBack, DipAcceptMonthBack, AppMonthBack
	, OfferMonthBack, CompMonthBack, SBResiProductFilter, TrueArrearsRatio, NoPayDayLoans, NoBo6m, BoVal6m, NoBo1yr, BoVal1yr, NoBo2yr, BoVal2yr
	, NoBo3yr, BoVal3yr, NoBo4yr, BoVal4yr, NoBo6yr, BoVal6yr, NoIVA1yr, IVAVal1yr, NoIVA2yr, IVAVal2yr, NoIVA3yr, IVAVal3yr, NoIVA6yr, IVAVal6yr
	, Default1m, Default3m, Default6m, Default12m, Default18m, Default24m, Default36m, Default48m, Default60m, Default72m, Missed3Mths, Missed6Mths
	, Missed12Mths, Missed18Mths, Missed24Mths, Missed36Mths, Missed48Mths, Missed60Mths, Missed72Mths, SBResiProductOrder, Repossion, RLUMI
	, UnsMissed3Mths, UnsMissed6Mths, UnsMissed12Mths, UnsMissed18Mths, UnsMissed24Mths, UnsMissed36Mths, UnsMissed48Mths, UnsMissed60Mths
	, UnsMissed72Mths, UnsDefaults1m, UnsDefaults3m, UnsDefaults6m, UnsDefaults12m, UnsDefaults18m, UnsDefaults24m, UnsDefaults36m
	, UnsDefaults48m, UnsDefaults60m, UnsDefaults72m, OriginationSource, HasWrokingVisa 
FROM #bml_strats2


----------------------------------------------------------------
----------------------------------------------------------------
/* 
	 ERROR CHECKING AND REBUILD OF TABLE
*/
-- check that there are no duplicate application ref before dropping existing. primary key violation
DECLARE @dupCheck VARCHAR(500);
DECLARE @errorMessage VARCHAR(500);
DECLARE @rows INT;
DECLARE @updateTable VARCHAR(50);

SET @updateTable = 'tbl_Strats';

-- check if empty table. Would suggest issue with applications feed
SELECT @rows = ISNULL(COUNT(*), 0) 
FROM #comb_strats;

IF @rows = 0
BEGIN
	 SET @errorMessage = 'Empty Table Error - ' + ISNULL(@updateTable, '') + ' population was empty. Not updated for latest day';
END

;WITH dups 
AS (
	 SELECT TOP 1 ApplicationRef
	 FROM #comb_strats
	 GROUP BY ApplicationRef
	 HAVING COUNT(*) > 1
)
SELECT @dupCheck = dups.ApplicationRef
FROM dups;

IF @dupCheck IS NOT NULL
BEGIN
	 SET @errorMessage = 'Duplicate Primary Key Error - ' + ISNULL(@updateTable, '') + ' population had duplicate Application Reference (' + @dupCheck + '). Not updated for latest day';
END;


-- if no issues 
IF @errorMessage IS NULL
BEGIN 
	 -- drop the existing table. This allows quick & easy addition of new columns
	 IF OBJECT_ID(N'dbo.tbl_Strats', N'U') IS NOT NULL
		 DROP TABLE dbo.tbl_Strats;

	 -- now we have the temp table create new empty prod table which can then have index applied
	 -- add the primary key index
	 SELECT * INTO dbo.tbl_Strats
	 FROM #comb_strats
	 WHERE ApplicationRef = 'M9999999';

	 -- now add the primary key
	 ALTER TABLE dbo.tbl_Strats
	 ADD CONSTRAINT PK_Strats  PRIMARY KEY CLUSTERED (ApplicationRef);

	 -- populate from the temp table. Any duplications will cause it to fail
	 INSERT INTO dbo.tbl_Strats
	 SELECT COBID, COBDate, ApplicationRef, LoanType, DIPCreatedDate, DipAcceptDate, DIPSubmitDate, DateDIPAccept, AppDate
		, FirstOfferDate, ReofferDate, CompDate, LatestStatus, Environment, ReportStatus, NoApplicants, Cust1MaritalStatus
		, Cust2MaritalStatus, Cust1EmploymentType, Cust2EmploymentType, Cust1DateOfBirth, Cust2DateOfBirth, Cust1Income
		, Cust2Income, CombinedIncome, IncomeGroup, IncomeGroupOrder, Cust1AgeAtApp, Cust2AgeAtApp, YoungestAgeAtApp
		, Cust1FirstTimeBuyer, Cust2FirstTimeBuyer, Cust1AgeatMaturity, Cust2AgeatMaturity, Cust1RetirementAge
		, Cust2RetirementAge, Cust1RetirementDate, Cust2RetirementDate, Cust1LIRFlag, Cust2LIRFlag, LoanPurpose
		, MortgageGroup, AppType, RepaymentType, CustomerLTV, CustomerLTVSegment, CustomerLTVSegmentOrder
		, CustomerBTLLTVSegment, CustomerBTLLTVSegmentOrder, OriginalLTV, LTVSegment, LTVSegmentOrder
		, LTVSegmentResidential, LTVSegmentOrderResidential, LTVSegmentBTL, LTVSegmentOrderBTL, ActualValuation
		, CustomerProvidedValuation, ValAge, CILTV, LoanAmount, InitialLoanRequested, GrossLoanAmount
		, MortgagePreCompAmount, LoanAmountCategory, LoanCategoryOrder, IncomeMultipleOLD, IncomeMultiple
		, IncomeMultipleGroup, IncomeMultipleOrder, MultipleFlag, ExtraRemortgageBorrowing, IsHomeImprovement
		, IsCapitalRaising, IsDebtConsolidation, DebtConsolidationAmount, InitialTermYears, InitialTermMonths
		, LoanMaturityDate, ProductCode, ProductTier, ProductLTVBand, ProductType, ProductGroup, ProductFeature
		, TierAssetClass, NoCCJ_3m, NoCCJ_6m, NoCCJ_1yr, ValueCCJ_1yr, NoCCJ_2yr, ValueCCJ_2yr, NoCCJ_3yr, ValueCCJ_3yr
		, NoCCJ_4yr, ValueCCJ_4yr, NoCCJ_6yr, ValueCCJ_6yr, NoBOIVA_6yr, ValueBOIVA_6yr, NoBOIVA_3yr, ValueBOIVA_3yr
		, SecurityType, SecuritySubType, TenureType, LeaseRemaining, LeaseAtEndOfTermYears, PropertyType, Region
		, NumberOfBedrooms, BedroomCatgeory, BedroomOrderNo, Broker, Network, MortgageClub, Packager, IntroducerType
		, CreditReferenceId, RNScore, RNGroup, RNGroupNo, TMLScore, ScoreTier, ScoreDistribution, SelfEmployedFlag
		, RetirementFlagOLD, LendingIntoRetirement, PercentagePastRetirement, RetirementFlag, RetirementFlagReason
		, ImpairedFlag, CCJsFlag, FirstTimeBuyer, NewBuildFlag, NewBuildIncentive, ReferralFlag, ArrearsTotal
		, GiftedEquityFlag, InterestRate, AppInterestRate, InterestRateGroup, InterestRateOrder, AnnualRentalIncome
		, MonthlyRentalIncome, StressedMonthlyInterestPayment, StressTestRate, ICR, ICRSegment, ICRSegmentOrder
		, ICR2Segment, ICR2SegmentOrder, ICRAdjusted, RentAdjustedForAffPass, BTLScore, Over65Flag, Over70Flag
		, CustomerType, FTBTL, Expat, PortfolioFlag, PortfolioCount, TMLPortfolio, RequestedLoanAmount
		, BestResultTwoYear, BestResultFiveYear, AffordabilityRating, AfordabilityBestTier, MaxLoanTwoYear
		, MaxLoanFiveYear, Securitised, SecuritisationStatus, ReversionDate, ProductRange, PaymentHoliday
		, HolidayPeriod, CurrentIncomeStatus, Industry, RateType, RevertedFlag, HolidayActive, AgreedHolidaysCount
		, ExtensionMonth, ExtensionMonthNo, CurrentBalance, DeferralStatus, UnderwritingMandateLevel, UWMandateLevelOrder
		, YoungestAgeBorrower, RevertNotRedeemed, SecuritisationTag, SecuritisationFlag, UADate, ProductDateActive
		, NoDebtManagementPlans, PTDate, CapitalRaised, ICROutlier, CapitalRaisedSeg, CapRaisedDebtExclSeg
		, DebtConSeg, DipSubmitMonthD, DipAcceptMonthD, AppMonthD, OfferMonthD, CompMonthD, DipSubmitMonth
		, DipAcceptMonth, AppMonth, OfferMonth, CompMonth, DipSubmit, AppSubmitted, Offered, Completed, DipSubmitMonthBack
		, DipAcceptMonthBack, AppMonthBack, OfferMonthBack, CompMonthBack, SBResiProductFilter, TrueArrearsRatio
		, NoPayDayLoans, NoBo6m, BoVal6m, NoBo1yr, BoVal1yr, NoBo2yr, BoVal2yr, NoBo3yr, BoVal3yr, NoBo4yr
		, BoVal4yr, NoBo6yr, BoVal6yr, NoIVA1yr, IVAVal1yr, NoIVA2yr, IVAVal2yr, NoIVA3yr, IVAVal3yr, NoIVA6yr
		, IVAVal6yr, Default1m, Default3m, Default6m, Default12m, Default18m, Default24m, Default36m, Default48m
		, Default60m, Default72m, Missed3Mths, Missed6Mths, Missed12Mths, Missed18Mths, Missed24Mths, Missed36Mths
		, Missed48Mths, Missed60Mths, Missed72Mths, SBResiProductOrder, Repossion, RLUMI, UnsMissed3Mths, UnsMissed6Mths
		, UnsMissed12Mths, UnsMissed18Mths, UnsMissed24Mths, UnsMissed36Mths, UnsMissed48Mths, UnsMissed60Mths, UnsMissed72Mths
		, UnsDefaults1m, UnsDefaults3m, UnsDefaults6m, UnsDefaults12m, UnsDefaults18m, UnsDefaults24m, UnsDefaults36m
		, UnsDefaults48m, UnsDefaults60m, UnsDefaults72m, OriginationSource, HasWorkingVisa
	 FROM #comb_strats;

	 -- update the daily checks table with the latest date
	 UPDATE TML_DW.dbo.tbl_DailyCheck 
	 SET LatestDate = @cobDate
	 WHERE TableName = 'TML_DW.dbo.tbl_Strats'

	 ----------------------------------------------------
	 -----------------------------------------------------

	 --APPLY OVERRIDES
	 EXEC sp_OverrideTableValues @updateTable
END;
ELSE -- error has occured
BEGIN
	 -- it there is an issue insert into the stored procedures issue log to be addressed in the morning
	 INSERT INTO TML_DW.dbo.log_StoredProcedureErrors(ErrorNumber, ErrorDescription, ErrorProcedure, ErrorState, ErrorSeverity, ErrorLine, ErrorTime)
	 VALUES( '0000'       -- ErrorNumber - varchar(50)
				 , @errorMessage      -- ErrorDescription - varchar(4000)
				 , PARSENAME(@procedureName, 1)    -- ErrorProcedure - varchar(100)
				 ,1,0,0, GETDATE() 	 );

END;


---------------------------------------------------------------------------------------------------
-- END & ERROR CATCHING
---------------------------------------------------------------------------------------------------

-- log end of procedure run
UPDATE TML_DW.dbo.log_StoredProcedureRuns
SET RunEnd = GETDATE()
WHERE ProcedureName = @procedureName
AND RunTime = @runTime;
BEGIN TRANSACTION;

--log end of procedure run
UPDATE TML_DW.dbo.log_StoredProcedureRuns
SET RunEnd = GETDATE()
WHERE ProcedureName = @procedureName
AND RunTime = @runTime;

COMMIT TRANSACTION;

END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
        ROLLBACK TRANSACTION;
    END

    BEGIN TRANSACTION;

    UPDATE TML_DW.dbo.log_StoredProcedureRuns
    SET RunEnd = GETDATE()
    WHERE ProcedureName = @procedureName
    AND RunTime = @runTime;

    COMMIT TRANSACTION;

    EXEC dbo.sp_Insert_ErrorLog; --To log Stored procedure errors
    THROW;
END CATCH

SET NOCOUNT OFF;
END;


GO
