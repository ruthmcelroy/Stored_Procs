USE TML_DW
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_PopulateLoanLevelTable
	@monthEnd DATE = NULL 
	--, @runType INT = 1 
	, @loanType VARCHAR(50) = NULL
	, @division VARCHAR(5) = 'TML'
	, @sec VARCHAR(50) = NULL

AS
BEGIN

-- =============================================================================
-- Procedure:   sp_PopulateLoanLevelTable
-- Schema:      dbo
-- Database:    TML_DW
-- Purpose:     Populates monthly loan level table for BoE and securitisation tapes.
-- Owner:       Data Engineering Team
-- Dependencies:
--   Tables:    DPR_DW.dbo.DIM_CO_Account, DPR_DW.dbo.IF_COAccount_COAssetSecurity, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAApplication, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMALoanDetails, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAProduct, TML_DW.dbo.acc, TML_DW.dbo.appPool, TML_DW.dbo.fn_AccountMonthlySchedule, TML_DW.dbo.fn_Forbearance, TML_DW.dbo.fn_Overpayments, TML_DW.dbo.fn_Repossessions, TML_DW.dbo.h, TML_DW.dbo.h2, TML_DW.dbo.log_StoredProcedureRuns, TML_DW.dbo.tags, TML_DW.dbo.tbl_AccountMonthlySummary, TML_DW.dbo.tbl_AffordabilityLatest, TML_DW.dbo.tbl_ApplicantPortfolios, TML_DW.dbo.tbl_Applicants, TML_DW.dbo.tbl_Applications, TML_DW.dbo.tbl_ArrearsDaily, TML_DW.dbo.tbl_BTLAggregateLoanLevel, TML_DW.dbo.tbl_BTLApplicants, TML_DW.dbo.tbl_Countries, TML_DW.dbo.tbl_CreditRefLatest, TML_DW.dbo.tbl_DailyCheck, TML_DW.dbo.tbl_DailyRates, TML_DW.dbo.tbl_EligPool, TML_DW.dbo.tbl_HomePriceIndex, TML_DW.dbo.tbl_Litigations, TML_DW.dbo.tbl_LoanLevelReport, TML_DW.dbo.tbl_PaymentHolidays, TML_DW.dbo.tbl_PaymentProfiles, TML_DW.dbo.tbl_ProductHistory, TML_DW.dbo.tbl_Products, TML_DW.dbo.tbl_PropertyDetails, TML_DW.dbo.tbl_Retentions, TML_DW.dbo.tbl_SalesActuals, TML_DW.dbo.tbl_Securitisations, TML_DW.dbo.tbl_SecuritisedPool, TML_DW.dbo.tbl_ServicingCorrespondence, TML_DW.dbo.tbl_Strats, TML_DW.dbo.tbl_SystemCalendar
--   Procs:     TML_DW.dbo.sp_Insert_ErrorLog
--   Views:     TML_DW.dbo.vw_DebtConsolidation, TML_DW.dbo.vw_PortfolioCount, TML_DW.dbo.vw_RetentionReleases
--   Functions: TML_DW.dbo.fn_AccountMonthlySchedule, TML_DW.dbo.fn_Forbearance, TML_DW.dbo.fn_Overpayments
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
-- Name:	sp_PopulateLoanLevelTable
-- Info:	Populates monthly loan level table for BoE and securitisation tapes
-- *******************************************************************************************************************
-- ChangeNo	Developer		Date		JiraNo	Detail
-- 
-- 001			N Sharkie		2025-11-18	16060	Created - build script from original procedure into newly updated table
-- 002			N Sharkie		2026-02-02	22251	fixed hard coded dates in previous months arrears joins
-- 003			N Sharkie		2026-02-26	22566	fix to monthhist to exclude in month sec Buy back, removed unused columns, added AppRef & Original Funder columns
-- 004			N Sharkie		2026-03-13	23000	remove closed secs, updates to AR73, AR131 and update to lia subquery
-- 005			M Lee			2026-04-30	23495	Removed join condition on vers join in creation of #hist temp table
-- 												as was filtering out latest versions when they are term/repayment type changes
-- 												Brought initial version term in months all the way through from hist to use for AR61
-- 006			N Sharkie		2026-05-22	23752	Upodate to balance sheet grouping, add folder path to output
-- 
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
		  , 'ETL' -- SSRS Report OR ETL
		  , NULL
		  , @runTime);

---------------------------------------------------------------------------------------------------
-- QUERY SECTION
---------------------------------------------------------------------------------------------------
/*
THIS PROCEDURE 
	-- BUILD MONTHLY REPORT
		-- BUILD MULTIPLE ACCOUNT HOLDERS TABLE
		-- GET LIST OF SECURITISATIONSA
		-- GET FORBEARANCE INFO FOR MONTH
		-- GET ACCOUNTS LIST
		-- BUILD HISTORY TABLE
		-- BUILD ACCOUNTS TABLE
		-- BUILD CUSTOMERS TABLE
		-- BUILD BASE REPORT
		-- ARCHIVE / SAVE MONTH
*/
-----------------------------------------
-- INTERNAL
DECLARE @cobid INT;
DECLARE @lastMonthEnd DATE;
DECLARE @b1m DATE;
DECLARE @b2m DATE;
DECLARE @q1m DATE;
DECLARE @formattedName VARCHAR(50);
DECLARE @runScript INT;

-- DEAL WITH NULL
-- default month end to yesterday - normal daily run will kick it out unless run type = override (2)
SET @monthEnd = ISNULL(@monthEnd, EOMONTH(DATEADD(m, -1, GETDATE())));


--SELECT @monthEnd

SET @cobid = CAST(FORMAT(@monthEnd,'yyyyMMdd') AS INT);

SET @b1m = EOMONTH(DATEADD(MONTH, -1, @monthEnd));
SET @b2m = EOMONTH(DATEADD(MONTH, -2, @monthEnd));

SET @q1m =  DATEADD(qq, DATEDIFF(qq, 0, GETDATE()), -1) 

--SELECT @q1m



SELECT @lastMonthEnd = IIF(@monthEnd = EOMONTH(@monthEnd), @monthEnd, @b1m);

--SELECT @runScript


-------------------------------------------------------------------------------------------------------------------
-- BUILD MONTHLY REPORT
-- if selected to build report

--IF @runScript = 1 
--BEGIN

	IF OBJECT_ID('tempdb..#multiple') IS NOT NULL
	DROP TABLE #multiple;

	IF OBJECT_ID('tempdb..#monthList') IS NOT NULL
	DROP TABLE #monthList;

	IF OBJECT_ID('tempdb..#securitisations') IS NOT NULL
	DROP TABLE #securitisations;

	IF OBJECT_ID('tempdb..#hist') IS NOT NULL
	DROP TABLE #hist;

	IF OBJECT_ID('tempdb..#accs') IS NOT NULL
	DROP TABLE #accs;

	IF OBJECT_ID('tempdb..#customers') IS NOT NULL
	DROP TABLE #customers;

	IF OBJECT_ID('tempdb..#forb') IS NOT NULL
	DROP TABLE #forb;

	IF OBJECT_ID('tempdb..#report') IS NOT NULL
	DROP TABLE #report;

	-------------------------------------------------
	-------------------------------------------------
	/*
		 -- BUILD MULTIPLE ACCOUNT HOLDERS TABLE
	*/
	SELECT DISTINCT AccountNo, dup.LoanType, dup.LoanTypes--, CorrespondenceAddress
	INTO #multiple
	FROM (
		SELECT sc.CustomerNo, sc.AccountNo, a.LoanType, sc.Title, sc.FirstName, sc.Surname, sc.CompanyName, sc.DateOfBirth, sc.CustomerName
				, sc.CorrespondenceAddress, sc.FlatNumber, sc.BuildingNumber, sc.BuildingName, sc.AddressLine1, sc.AddressLine2
				, sc.TownCity, sc.County, sc.PostCode, sc.Country, sc.BorrowerClass, sc.CustomerOrderNo, sc.AccountCustomerID
				, sc.CustomerID, sc.AddressId, LoanTypes
		--FROM dbo.vw_ServicingCorrespondence sc
		FROM dbo.tbl_ServicingCorrespondence sc
		INNER JOIN dbo.tbl_Applications a ON sc.AccountNo = a.AccountNo
		INNER JOIN (
			SELECT CustomerName = REPLACE(sc.CustomerName, 'o''r', 'O R'), sc.DateOfBirth, LoanTypes = COUNT(DISTINCT a.LoanType)
			, BTLCount = SUM(IIF(LoanType = 'BTL', 1, 0))
			FROM dbo.tbl_ServicingCorrespondence sc
			INNER JOIN dbo.tbl_Applications a ON sc.AccountNo = a.AccountNo
			WHERE sc.BorrowerClass = 'Individual'
			GROUP BY sc.CustomerName, sc.DateOfBirth
			HAVING COUNT(DISTINCT a.LoanType) > 1
			AND SUM(IIF(LoanType = 'BTL', 1, 0)) > 0 
		) d
			ON sc.CustomerName = d.CustomerName
				AND sc.DateOfBirth = d.DateOfBirth		
	) dup;

	CREATE CLUSTERED INDEX IDX_Mult1 ON #multiple(AccountNo);

	-------------------------------------------------
	-------------------------------------------------
	-- GET LIST OF SECURITISATIONS

	SELECT SecuritisationID, SecuritisationTag
	, EnglishPath, ScottishPath
	, SecNo = ROW_NUMBER() OVER(ORDER BY SecuritisationID)
	INTO #securitisations
	FROM dbo.tbl_Securitisations
	WHERE Funder IN ('Shawbrook', 'BML') -- BML should probably be Shawbrook but no affect on TML
	AND Securitised = 1
	AND OriginationSource = ISNULL(@division, OriginationSource)
	AND SecuritisationTag = ISNULL(@sec, SecuritisationTag) -- if it is poulated no point having others in table
	AND ISNULL(ClosedDate, '9999-12-31') > @monthEnd
	
	-------------------------------------------------
	-------------------------------------------------
	/*+
		GET ACCOUNTS LIST
		-- entires from current month and last time accounts in each requested securitisation
	*/

	SELECT c.AccountNo, c.MonthEnd
	, IsLatest = 1
	INTO #monthList
	FROM dbo.tbl_AccountMonthlySummary c
	INNER JOIN dbo.tbl_Applications app ON c.AccountNo = app.AccountNo
	WHERE c.LoanType <> 'Residential' -- always exclude 24AM loans
	AND c.MonthEnd = @monthEnd
	AND c.OriginationSource = ISNULL(@division, c.OriginationSource)
	AND IIF(@sec IS NULL, c.SecuritisationTag, REPLACE(c.SecuritisationTag, ' Retained', '')) = ISNULL(@sec, c.SecuritisationTag)
	AND app.Funder NOT IN ('Merlot 2nds', 'Hoist') -- too old not in this report

	UNION
	
	SELECT AccountNo
	, MonthEnd = EOMONTH(DATEADD(m, -1, sp.TransferOutDate))
	, IsLatest = 0
	FROM dbo.tbl_SecuritisedPool sp
	INNER JOIN #securitisations s ON sp.SecuritisationId = s.SecuritisationID
	WHERE IIF(sp.TransferOutDate > @monthEnd, '9999-12-31', sp.TransferOutDate) <> '9999-12-31'

	-------------------------------------------------
	-------------------------------------------------
	-- GET FORBEARANCE INFO FOR MONTH

	SELECT f.AccountNo, f.AR122, f.AR123, f.AR173
	INTO #forb
	FROM dbo.fn_Forbearance(@monthEnd) f
	INNER JOIN #monthList m ON f.AccountNo = m.AccountNo

	--------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------
	/*
		BUILD HISTORY TABLE
	*/
	CREATE TABLE #hist (
		AccountNo VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS -- collating here means dont need to add default to all joins
		, Division VARCHAR(50) COLLATE SQL_Latin1_General_CP1_CI_AS -- collating here means dont need to add default to all joins
		, LoanType VARCHAR(50) COLLATE SQL_Latin1_General_CP1_CI_AS
		, MonthEnd DATE
		, InterestRate DECIMAL(6,2)
		--, ProductCode INT
		, ProductCode VARCHAR(20)  COLLATE SQL_Latin1_General_CP1_CI_AS
		, PTFlag INT
		, PTDate DATE
		, CurrentBalance DECIMAL(20,2)
		, PrincipalBalance DECIMAL(20,2)
		, RetentionAmount DECIMAL(20,2)
		, ScheduledPayment DECIMAL(20,2)
		, PaymentsMade DECIMAL(20,2)
		, BaseRateCode VARCHAR(20) 
		, CIValSetBy VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS
		, CIValuation DECIMAL(20,2) 
		, CILTV DECIMAL(10,4)
		, RevertedFlag INT
		, Securitised INT 
		, SecuritisationFlag VARCHAR(10) COLLATE SQL_Latin1_General_CP1_CI_AS
		, SecuritisedDate DATE
		, TransferOutDate DATE
		, SecuritisationTag VARCHAR(100) COLLATE SQL_Latin1_General_CP1_CI_AS
		, SecuritisationName VARCHAR(100) COLLATE SQL_Latin1_General_CP1_CI_AS
		, SecuritisationStatus VARCHAR(100) COLLATE SQL_Latin1_General_CP1_CI_AS
		, FormattedPoolName VARCHAR(50)
		, ProductVersionNo INT
		, VersionStartDate DATE
		, Product VARCHAR(50)
		, ProductFeature VARCHAR(100)
		, RepaymentType VARCHAR(20)
		, ReversionDate DATE
		, BaseRateMargin DECIMAL(20,2)
		, RevertMargin DECIMAL(10,2)
		, ChangeType VARCHAR(50)
		, TermInMonths INT
		, IsLatest INT NOT NULL DEFAULT 0
		, SecTagNo INT NULL
		, InitialProductFeature VARCHAR(100)
		, InitialFunder VARCHAR(50)
		, InitialTerm INT
		, EligPool INT DEFAULT 0
	);

	INSERT INTO #hist (
		AccountNo, MonthEnd, Division, LoanType, InterestRate, ProductCode, PTFlag, PTDate
		, CurrentBalance, PrincipalBalance, RetentionAmount
		, ScheduledPayment, PaymentsMade, BaseRateCode, CIValSetBy, CIValuation, CILTV, RevertedFlag
		, Securitised, SecuritisationFlag, SecuritisedDate, TransferOutDate
		, SecuritisationTag, SecuritisationName, SecuritisationStatus, FormattedPoolName
		, BaseRateMargin, ProductVersionNo, VersionStartDate, Product, ProductFeature, RepaymentType
		, ReversionDate, RevertMargin, ChangeType, TermInMonths, InitialProductFeature, InitialFunder, InitialTerm
		, IsLatest, EligPool
	)
	SELECT c.AccountNo, c.MonthEnd, c.OriginationSource, c.LoanType, c.InterestRate, c.ProductCode
	, PTFlag = vers.IsPT
	, PTDate = IIF(vers.IsPT = 1, vers.OpenDate, NULL)
	, c.CurrentBalance, c.PrincipalBalance, c.RetentionAmount, c.ScheduledPayment
	, c.PaymentsMade, c.BaseRateCode, c.CIValSetBy, c.CIValuation, c.CILTV, c.RevertedFlag
	, c.Securitised, c.SecuritisationFlag, sp.SecuritisedDate
	, TransferOutDate = NULLIF(sp.TransferOutDate, '9999-12-31')
	, SecuritisationTag = IIF(c.SecuritisationTag = 'Balance Sheet', 'Balance Sheet - ' + REPLACE(c.LoanType, '2', ''), c.SecuritisationTag)
	, c.SecuritisationName, c.SecuritisationStatus, s.FormattedPoolName
	, BaseRateMargin = c.InterestRate - CASE 
											WHEN c.BaseRateCode = 'BBR' THEN dr.BBR
											WHEN c.BaseRateCode = 'LIBOR' THEN dr.LIBOR
											WHEN c.BaseRateCode = 'TBR' AND c.LoanType = 'BTL' THEN dr.TBRBTL
											WHEN c.BaseRateCode = 'TBR' AND c.LoanType <> 'BTL' THEN dr.TBRRESI
											ELSE NULL
										END
	, ProductVersionNo = vers.VersionNo
	, VersionStartDate = vers.OpenDate
	, vers.Product, vers.ProductFeature, vers.RepaymentType, vers.ReversionDate, vers.RevertMargin
	, vers.ChangeType, vers.TermInMonths
	, InitialProductFeature = NULLIF(i.ProductFeature, '')
	, i.InitialFunder
	, i.InitialTerm
	, ml.IsLatest
	, EligPool = IIF(ep.AccountNo IS NOT NULL, 1, 0)
	FROM #monthList ml
	INNER JOIN dbo.tbl_AccountMonthlySummary c ON ml.AccountNo = c.AccountNo
													AND ml.MonthEnd = c.MonthEnd
	INNER JOIN dbo.tbl_DailyRates dr ON c.COBID = dr.COBID
	-- initial product details
	INNER JOIN (
		SELECT h.AccountNo
		, ProductFeature = CASE 
								WHEN h.OriginationSource = 'TML' THEN p.ProductFeature
								WHEN CHARINDEX('HTB', p.Product) > 0 THEN 'Help to Buy'
								ELSE p.ProductFeature
						   END
		, InitialFunder = CASE 
							WHEN p.ProductType = 'Residential' THEN '24AM'
							WHEN h.OriginationSource = 'BML' AND YEAR(h.OpenDate) < 2016 THEN 'Merlot'
							ELSE 'Shawbrook'
						  END
		, InitialTerm = h.TermInMonths
		FROM dbo.tbl_ProductHistory h
		INNER JOIN tbl_Products p ON h.ProductCode = p.ProductCode
		WHERE h.VersionNo = 1
	) i 
		ON i.AccountNo = c.AccountNo
	-- join to product history. Need to have left join or returned funds after month end will be excluded
	LEFT OUTER JOIN(
		SELECT ph.AccountNo, ph.VersionNo, ph.Product, ph.ProductFeature, ph.OpenDate
		, ph.ProductCode, ph.ChangeType, ph.ReversionDate
		, ph.RevertMargin, ph.TermInMonths, ph.RepaymentType, ph.IsPT
		FROM (
			SELECT h.AccountNo, h.VersionNo, h.OpenDate, h.ProductCode, h.ReversionDate
			, h.ChangeType, h.TermInMonths, h.RepaymentType, p.IsPT
			, p.Product, p.ProductFeature
			, RevertMargin = p.RevertAdd * 100
			, VO = ROW_NUMBER() OVER (PARTITION BY h.AccountNo ORDER BY h.VersionNo DESC)
			FROM dbo.tbl_ProductHistory h
			INNER JOIN dbo.tbl_Products p ON h.ProductCode = p.ProductCode
			WHERE OpenDate <= @monthEnd
			--AND ISNULL(h.ChangeType, 'Open') IN ('Open', 'Product Transfer') --Change005 dropping term and repayment changes if latest
		) ph
		WHERE VO = 1
	) vers ON c.AccountNo = vers.AccountNo
	LEFT OUTER JOIN dbo.tbl_Securitisations s ON c.SecuritisationFlag = s.SecuritisationFlag
	LEFT OUTER JOIN dbo.tbl_SecuritisedPool sp ON c.AccountNo = sp.AccountNo
												AND s.SecuritisationID = sp.SecuritisationId 
	LEFT OUTER JOIN dbo.tbl_EligPool ep ON c.AccountNo = ep.AccountNo
	
	---------------------------------------
	-- set the securitisation order no - used to mark on securitisation tape which ones have trannsferred out via PT.				
	;WITH tags
	AS (
		SELECT AccountNo, MonthEnd
		, SecTagNo = ROW_NUMBER() OVER(PARTITION BY AccountNo ORDER BY MonthEnd)
		FROM #hist
	)
	UPDATE h 
	SET h.SecTagNo = t.SecTagNo
	FROM #hist h
	INNER JOIN tags t ON h.AccountNo = t.AccountNo
							AND h.MonthEnd = t.MonthEnd;	

	-- now if PT product then set the previous entry if securitisation to show the PT info
	UPDATE h2
	SET h2.PTFlag = h1.PTFlag
	, h2.PTDate = h1.PTDate	
	FROM #hist h1
	INNER JOIN #hist h2 ON h1.AccountNo = h2.AccountNo
							AND h2.SecTagNo = h1.SecTagNo - 1 
							AND h2.Securitised = 1
	WHERE h1.PTFlag = 1;


	-----------------------------------------
	---- set the eligible Pool flag DEV ONLY
	--UPDATE h
	--SET h.EligPool = 1
	--FROM #hist h
	--INNER JOIN dbo.tbl_EligPool p ON p.AccountNo = h.AccountNo
	--AND IsLatest = 1

	-------------------------------------------------
	-------------------------------------------------
	/*
		 -- BUILD ACCOUNTS TABLE
	*/
	SELECT h.MonthEnd, h.AccountNo
	, Division = tapp.OriginationSource
	, h.LoanType, h.IsLatest, h.InitialProductFeature, h.InitialFunder, h.InitialTerm, h.EligPool
	-------------------------
	-- old pools should be 0/NULL for current snapshots metrics. Multiply by is latest flag
	, CurrentBalance = h.CurrentBalance * h.IsLatest
	, PrincipalBalance = h.PrincipalBalance * h.IsLatest
	, RetentionAmount = h.RetentionAmount * h.IsLatest
	, InterestRate = h.InterestRate * h.IsLatest
	, ScheduledPayment = h.ScheduledPayment * h.IsLatest
	, PaymentsMade = h.PaymentsMade * h.IsLatest
	, CILTV = IIF( h.IsLatest = 0
					, 0
					, CONVERT(DECIMAL(20,4)
									 ,IIF(
										  tapp.ValuationHPI IS NULL 
										  , h.PrincipalBalance / NULLIF(tapp.Valuation, 0)
										  , h.PrincipalBalance / (NULLIF(tapp.Valuation, 0) / tapp.ValuationHPI * COALESCE(hpiRecent.HPI, tapp.ValuationHPI))
										 )
									 )
					)

	-- HISTORIC DATA
	, h.CIValSetBy
	, CIValuation = IIF(
						tapp.ValuationHPI IS NULL
						, CONVERT(DECIMAL(20,2), NULLIF(tapp.Valuation, 0))
						, CONVERT(DECIMAL(20,2), tapp.Valuation / tapp.ValuationHPI * COALESCE(hpiRecent.HPI, tapp.ValuationHPI))
					)	
	, h.RevertedFlag, h.BaseRateCode
	, VersionStartDate = ISNULL(h.VersionStartDate, tapp.CompDate) -- returned funds will be NUll 
	, h.ProductCode, h.PTFlag, h.PTDate
	, RepaymentType = ISNULL(h.RepaymentType, tapp.RepaymentType)  -- returned funds will be NUll 
	, Product = ISNULL(h.Product, tapp.Product)
	, ProductFeature = ISNULL(h.ProductFeature, tapp.ProductFeature)
	, h.BaseRateMargin
	, RevertMargin = ISNULL(h.RevertMargin, prod.RevertAdd * 100)
	, ReversionDate = COALESCE(h.ReversionDate, DATEADD(YEAR, CONVERT(INT, SUBSTRING(tapp.Product, CHARINDEX('Year', tapp.Product)-2, 1)), tapp.CompDate ), '9999-12-31')  --COALESCE for the BML products Trackers/Variable Rates
	, h.Securitised, h.SecuritisationTag, h.SecuritisedDate, h.TransferOutDate, h.SecuritisationName, h.SecuritisationStatus, h.SecuritisationFlag
	, h.ChangeType
	, ProductVersionNo = ISNULL(h.ProductVersionNo, 1) -- returned funds will be NUll 
	, TermInMonths = ISNULL(h.TermInMonths, tapp.TermInMonths)
	, FormattedName = ISNULL(h.FormattedPoolName, 'TML')

	-------------------------

	, tapp.ExcludeFromSecuritisation
	, AccountOpenDate = ISNULL(tapp.AccountOpenDate, tapp.CompDate) -- could have returned funds since then
	, tapp.OpeningCapitalBalance, tapp.OriginalGrossLTV
	, tapp.ProductTier
	, tapp.Applicants, tapp.CustomerType
	, CreditScore = IIF(h.SecuritisedDate < '2024-05-14', tapp.TMLScore, tapp.RNScore)
	, tapp.MortgageType
	, AccountClosedDate =	CASE
								WHEN h.TransferOutDate IS NOT NULL THEN h.TransferOutDate -- transfers out should look like redemptions on securitisation tape
								WHEN ISNULL(tapp.AccountClosedDate, '9999-12-31') > h.MonthEnd THEN NULL
								ELSE tapp.AccountClosedDate
							END	
	, prd.InterestOnlyAmount
	, ReversionRateCode = CASE
							WHEN prd.ReversionRateDescription = 'Bank of England Base Rate' THEN 'BBR'
							WHEN prd.ReversionRateDescription = 'LIBOR' THEN 'LIBOR'
							WHEN prd.ReversionRateDescription LIKE 'The Mortgage Lender%' THEN 'TBR'
							ELSE '?'
						  END 
	, ApplicationTaxCreditsAllowance = ISNULL(aff.ApplicationTaxCreditsAllowance, 0)
	, aff.GrossIncomeIncludingCreditsTotal
	, CustomerPoolPortfolio = ISNULL(portf.CustomerPoolPortfolio, 0)
	, AppPool = CONVERT(VARCHAR(50), NULL) --ap.AppPool
	, crossCollFlag = IIF(crossColl.AccountNo IS NULL, 0, 1)
	, InitialMaturityDate = DATEADD(MONTH, ISNULL(h1.TermInMonths, tapp.TermInMonths), ISNULL(h1.OpenDate, tapp.CompDate)) -- use app table if returned funds 
	, tapp.InitialBaseRateCode
	, tapp.Valuation
	, tapp.ApplicationRef
	INTO #accs
	FROM dbo.tbl_Applications tapp
	INNER JOIN dbo.tbl_Products prod ON tapp.ProductCode = prod.ProductCode
	INNER JOIN #hist h ON tapp.ApplicationRef = h.AccountNo COLLATE DATABASE_DEFAULT
							AND (h.Securitised + h.IsLatest) > 0 -- this will pick up the latest if balance sheet as well as any historic securitisations
	INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAApplication synApp ON tapp.ApplicationRef = synApp.ApplicationRef  COLLATE DATABASE_DEFAULT
	INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMALoanDetails ld ON synApp.ID = ld.ApplicationID
	INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAProduct prd ON ld.ID = prd.LoanDetailsID
	INNER JOIN dbo.tbl_AffordabilityLatest aff ON tapp.ApplicationRef = aff.ApplicationRef
	LEFT OUTER JOIN dbo.tbl_ProductHistory h1 ON tapp.ApplicationRef = h1.AccountNo -- needs to be app ref and not account no in case returned funds after running
											AND h1.VersionNo = 1
	LEFT OUTER JOIN dbo.tbl_Securitisations sec ON h.SecuritisationTag = sec.SecuritisationTag COLLATE DATABASE_DEFAULT
	-- left join as they may have noone with us if all redeemed
	LEFT OUTER JOIN (
		 SELECT DISTINCT bal.ApplicationRef, bal.CustomerPool
		 , pf.CustomerPoolPortfolio 
		 FROM TML_DW.dbo.tbl_BTLAggregateLoanLevel bal
		 INNER JOIN (
			  SELECT CustomerPool
			  , CustomerPoolPortfolio = COUNT(DISTINCT ApplicationRef)
			  FROM dbo.tbl_BTLAggregateLoanLevel
			  WHERE Environment = 'Portfolio'
			  GROUP BY CustomerPool
		 ) pf 
			  ON bal.CustomerPool = pf.CustomerPool
	) portf ON h1.AccountNo = portf.ApplicationRef

	LEFT OUTER JOIN #multiple crossColl ON tapp.ApplicationRef = crossColl.AccountNo 

	-- most recent index valuation
    LEFT OUTER JOIN TML_DW..tbl_HomePriceIndex hpiRecent ON DATEPART(q, DATEADD(m, -3, CONVERT(DATE, CONVERT(VARCHAR(10),@cobid)))) = hpiRecent.Quarter
														 AND DATEPART(yyyy, DATEADD(m, -3, CONVERT(DATE, CONVERT(VARCHAR(10),@cobid)))) = hpiRecent.Year
														 AND tapp.Region = RTRIM(REPLACE(REPLACE(hpiRecent.Region, CHAR(13), ''), CHAR(10), '')) COLLATE DATABASE_DEFAULT
	ORDER BY h.MonthEnd DESC, h.AccountNo
	OPTION(RECOMPILE);

	DELETE FROM #accs
	WHERE AccountNo IN (
						SELECT ApplicationRef
						FROM dbo.tbl_Applications
						WHERE FeesReturnedDate <= @monthEnd 
						AND (AccountOpenDate IS NULL OR AccountOpenDate >= @monthEnd)
						);

	----------------------------
	-- remove closed securitisations
	
	DELETE a
	FROM #accs a
	WHERE EXISTS (
		SELECT 1
		FROM #accs b
		WHERE b.SecuritisationTag = a.SecuritisationTag
		GROUP BY b.SecuritisationTag
		HAVING SUM(b.CurrentBalance) = 0
	);

	--Dev Only to display counts/sums per securitisation
	----------------------------
	--SELECT 
	--  a.SecuritisationTag
	--, LoanCount = COUNT(*)
	--, LoanValue = FORMAT(SUM(a.CurrentBalance), 'N2')
	--, PrinValue = FORMAT(SUM(a.PrincipalBalance), 'N2')
	--FROM #accs a
	--GROUP BY a.SecuritisationTag
	--ORDER BY a.SecuritisationTag
	----------------------------

	CREATE CLUSTERED INDEX IDX_App1L ON #accs(AccountNo, SecuritisationTag);
	


	-- add in the portfolio data. Faster than doing as part of original build. DARK ARTS
	;WITH appPool
	AS (
	SELECT acc.AccountNo
		, AppPool = (SELECT REPLACE(
							 STUFF(
								  (
								  SELECT ',' + CONVERT(VARCHAR(20), p.BTLApplicantID)
								  FROM TML_DW.dbo.tbl_ApplicantPortfolios p
								  INNER JOIN TML_DW.dbo.tbl_BTLApplicants ba ON p.BTLApplicantID = ba.BTLApplicantID
																				AND ba.ApplicantType = 'individual'	
								  WHERE p.ApplicationRef = acc.AccountNo	 
								  FOR XML PATH('')
								  ), 1, 1, ''
								  )
							 , ',', ', '
						 ) )
		FROM dbo.tbl_AccountMonthlySummary acc
		WHERE LoanType = ISNULL(@loanType, LoanType)
		AND MonthEnd = @monthEnd
	)


	UPDATE acc
	SET acc.AppPool = ap.AppPool
	FROM #accs acc
	INNER JOIN appPool ap ON acc.AccountNo = ap.AccountNo;

	-------------------------------------------------
	---------------------------------------------------
	--/*
	--	 -- BUILD CUSTOMERS TABLE
	--*/
	SELECT a.*								
	, TotalIncomeIncCredits = a.TotalIncome + IIF(
												acc.LoanType <> 'BTL' AND a.ClaimsCredits = 1
												, ISNULL(acc.ApplicationTaxCreditsAllowance, 0)
												, 0
											)
	, CreditReportDate = cr.DateCreated
	, CCJNo_6yr_Satisfied = CASE 
										 WHEN a.CustomerNo IN (1, 101) THEN App1_CCJNo_6yr_Satisfied
										 WHEN a.CustomerNo IN (2, 102) THEN App2_CCJNo_6yr_Satisfied
										 WHEN a.CustomerNo IN (3, 103) THEN App3_CCJNo_6yr_Satisfied
										 WHEN a.CustomerNo IN (4, 104) THEN App4_CCJNo_6yr_Satisfied
									 END
	, CCJVal_6yr_Satisfied = CASE 
										 WHEN a.CustomerNo IN (1, 101) THEN App1_CCJVal_6yr_Satisfied
										 WHEN a.CustomerNo IN (2, 102) THEN App2_CCJVal_6yr_Satisfied
										 WHEN a.CustomerNo IN (3, 103) THEN App3_CCJVal_6yr_Satisfied
										 WHEN a.CustomerNo IN (4, 104) THEN App4_CCJVal_6yr_Satisfied
									 END
	, CCJNo_6yr_UnSatisfied = CASE 
										 WHEN a.CustomerNo IN (1, 101) THEN App1_CCJNo_6yr_UnSatisfied
										 WHEN a.CustomerNo IN (2, 102) THEN App2_CCJNo_6yr_UnSatisfied
										 WHEN a.CustomerNo IN (3, 103) THEN App3_CCJNo_6yr_UnSatisfied
										 WHEN a.CustomerNo IN (4, 104) THEN App4_CCJNo_6yr_UnSatisfied
									 END
	, CCJVal_6yr_UnSatisfied = CASE 
											  WHEN a.CustomerNo IN (1, 101) THEN App1_CCJVal_6yr_UnSatisfied
											  WHEN a.CustomerNo IN (2, 102) THEN App2_CCJVal_6yr_UnSatisfied
											  WHEN a.CustomerNo IN (3, 103) THEN App3_CCJVal_6yr_UnSatisfied
											  WHEN a.CustomerNo IN (4, 104) THEN App4_CCJVal_6yr_UnSatisfied
										  END
	, Date_last_CCJ = CASE 
							  WHEN a.CustomerNo IN (1, 101) THEN App1_Date_last_CCJ
							  WHEN a.CustomerNo IN (2, 102) THEN App2_Date_last_CCJ
							  WHEN a.CustomerNo IN (3, 103) THEN App3_Date_last_CCJ
							  WHEN a.CustomerNo IN (4, 104) THEN App4_Date_last_CCJ
						   END
	, IVANo_6yr = CASE 
						 WHEN a.CustomerNo IN (1, 101) THEN App1_IVANo_6yr
						 WHEN a.CustomerNo IN (2, 102) THEN App2_IVANo_6yr
						 WHEN a.CustomerNo IN (3, 103) THEN App3_IVANo_6yr
						 WHEN a.CustomerNo IN (4, 104) THEN App4_IVANo_6yr
						END
	, BONo_6yr = CASE 
						 WHEN a.CustomerNo IN (1, 101) THEN App1_BONo_6yr
						 WHEN a.CustomerNo IN (2, 102) THEN App2_BONo_6yr
						 WHEN a.CustomerNo IN (3, 103) THEN App3_BONo_6yr
						 WHEN a.CustomerNo IN (4, 104) THEN App4_BONo_6yr
						END
	, Mortgage_repos = CASE 
							WHEN a.CustomerNo IN (1, 101) THEN App1_Mortgage_repos
							WHEN a.CustomerNo IN (2, 102) THEN App2_Mortgage_repos
							WHEN a.CustomerNo IN (3, 103) THEN App3_Mortgage_repos
							WHEN a.CustomerNo IN (4, 104) THEN App4_Mortgage_repos
						END
	, SixMonthsMissed = ISNULL(m.SixMonthMissed, 0)
	, TotalMissed = m.TotalMissed
	, YearMissed = m.YearMissed
	INTO #customers
	FROM TML_DW.dbo.tbl_Applicants a
	INNER JOIN #accs acc ON a.ApplicationRef = acc.ApplicationRef
	LEFT OUTER JOIN TML_DW.dbo.tbl_CreditRefLatest cr ON a.ApplicationRef = cr.ApplicationRef
	LEFT OUTER JOIN (
		 SELECT ApplicationRef, CreditReferenceId, CustomerNo
		 , SixMonthMissed = SUM(ISNULL(Missed6m, 0)) 
		 , TotalMissed = SUM(ISNULL(Missed72m, 0))
		 , YearMissed = SUM(ISNULL(Missed12m, 0))
		 , COUNT(*) AS MortgageCount
		 FROM tbl_PaymentProfiles
		 WHERE AccountType IN ('Mortgage', 'SecondMortgage')
		 GROUP BY ApplicationRef, CreditReferenceId, CustomerNo
	) m
		 ON a.ApplicationRef = m.ApplicationRef
			  AND a.CustomerNo = m.CustomerNo

	WHERE a.DIM_CO_Account_DWSK IS NOT NULL
	OPTION(RECOMPILE);

	CREATE CLUSTERED INDEX IDX_Cust1 ON #customers(ApplicationRef);
	CREATE NONCLUSTERED INDEX IDX_Cust2 ON #customers(BoEAppNo);

	-------------------------------------------------
	-------------------------------------------------
	/*
		 -- BUILD BASE REPORT
	*/

	SELECT DISTINCT ReportMonth = @monthEnd
	--, acc.MonthEnd
	, acc.Division, acc.LoanType
	, CurrentBalance = acc.CurrentBalance * acc.IsLatest 
	, PrincipalBalance = acc.PrincipalBalance * acc.IsLatest
	, acc.Securitised, acc.SecuritisationStatus, acc.SecuritisationFlag, acc.SecuritisationTag
	--, SecuritisationGroup = REPLACE(acc.SecuritisationTag, ' Retained', '')
	, SecuritisationGroup = IIF(CHARINDEX('Balance Sheet', acc.SecuritisationTag) > 0 , 'Balance Sheet', REPLACE(acc.SecuritisationTag, ' Retained', ''))
	, ReportName = CONCAT(acc.Division, ' ',  IIF(acc.SecuritisationTag = 'BS', 'Non Sec', acc.SecuritisationTag), ' ', FORMAT(@monthEnd, 'MMM-yy'))
	, AR1 = @monthEnd
	, AR1F = FORMAT(@monthEnd, 'dd-MM-yyyy')
	, AR2 = ISNULL(acc.formattedname, acc.Division)
	, AR2F = acc.FormattedName 
	, AR3 = acc.AccountNo 
	, AR4 = IIF(CHARINDEX('BTL', acc.Loantype) > 0 , 'N', 'Y')
	, AR5 = acc.Division
	, AR6 = acc.Division 
	, AR7 = IIF(
				acc.LoanType = 'BTL'
				, acc.AppPool
				, c1.ServicingCustNo + IIF(acc.Applicants > 1, ', ' + c2.ServicingCustNo, '') COLLATE DATABASE_DEFAULT
			)
	, AR8 = f.DIM_CO_AssetSecurity_SSK
	, AR9 = IIF(acc.LoanType = 'Residential', NULL, pro.SBProductCode)
	, AR9F = CAST(NULL AS VARCHAR(20))
	, AR10F = CAST(NULL AS INT)
	, AR10 = IIF(
				acc.LoanType = 'Residential'
				, NULL
				, DATEDIFF(MONTH, EOMONTH(acc.AccountOpenDate), @monthEnd) - CONVERT(INT, ISNULL(arrc.TrueArrearsRatio, 0))
			 )
	, AR11 = CAST(NULL AS VARCHAR(255))
	, AR11NSEC = IIF(acc.Division = 'BML', NULL, acc.crossCollFlag) -- only applicable for TML
	, AR12 = NULL
	, AR13 = NULL
	, AR14 = NULL
	, AR15 = CASE
				WHEN acc.Division = 'BML' THEN 'IND'
				WHEN acc.CustomerType = 'Individual' THEN 'IND'
				WHEN acc.CustomerType = 'Company' THEN 'COM'
				ELSE 'ERROR'
			 END 
	, AR16BTL = CONVERT(VARCHAR(2)
						, CASE 
							   WHEN c1.Nationality IN ('British', 'United Kingdom') AND Expat = 0 THEN 1 -- UK National living in the UK
								  WHEN c1.Nationality IN ('British', 'United Kingdom') AND Expat = 1 THEN 2 -- UK National living abroad
								  WHEN c1.Nationality NOT IN ('British', 'United Kingdom') AND c1.ResidenceCountry IN ('UnitedKingdom', 'UK') AND c1.EUNational = 1 THEN 3 -- EU National living in the UK
								  WHEN c1.Nationality NOT IN ('British', 'United Kingdom') AND c1.ResidenceCountry NOT IN ('UnitedKingdom', 'UK') AND c1.EUNational = 1 AND cnt1.Country = cntRes.Country THEN 4 -- EU National living in home country
								  WHEN c1.Nationality NOT IN ('British', 'United Kingdom') AND c1.ResidenceCountry IN ('UnitedKingdom', 'UK') AND c1.EUNational = 0 THEN 5 -- Other Foreign National living in the UK
								  WHEN c1.Nationality NOT IN ('British', 'United Kingdom') AND c1.ResidenceCountry NOT IN ('UnitedKingdom', 'UK') AND c1.EUNational = 0  THEN 6 -- Other Foreign National living elsewhere
								  WHEN c1.Nationality NOT IN ('British', 'United Kingdom') AND c1.ResidenceCountry NOT IN ('UnitedKingdom', 'UK') AND c1.EUNational = 1 THEN 7 -- EU National living elsewhere
							   ELSE 999 -- ??
						   END 
					)  
	, AR16 = CASE c1.Nationality
			   WHEN 'British' THEN 'N' -- TML
			   WHEN 'United Kingdom' THEN 'N' -- BML
			   ELSE 'Y'
		   END  
	, AR17 = CASE 
				WHEN acc.LoanType = 'BTL' THEN 'Prime'
				WHEN CHARINDEX('-', acc.ProductTier) = 0 THEN acc.ProductTier
				ELSE REPLACE(LEFT(acc.ProductTier, CHARINDEX('-', acc.ProductTier)-1), '-', '')
			END
	, AR18 = YEAR(CONVERT(DATETIME , CONVERT(CHAR , c1.DateOfBirth)))
	, AR19 = acc.Applicants
	, AR20 = YEAR(CONVERT(DATETIME , CONVERT(CHAR , c2.DateOfBirth)))
	, AR21 = IIF(CHARINDEX('BTL', acc.LoanType) = 0 AND c1.BoeTypeCode = 9 AND c1.LIRFlag = 1, 8, c1.BoeTypeCode) -- for resi loans if other but lending into retirement then set to retired- securitisation request
	, AR22 = IIF(c1.FTBFlag = 1, 'Y', 'N')
	, AR23 = IIF(acc.Product LIKE '%right%', 'Y','N')
	, AR24 = IIF(acc.Product LIKE '%right%', CONVERT(VARCHAR(20), prop.PurchasePrice),'N/A')
	, AR24F = IIF(acc.Product LIKE '%right%', CONVERT(VARCHAR(20), prop.PurchasePrice),'')
	, AR25 = CASE
				WHEN CHARINDEX('-', acc.ProductTier) = 0 THEN acc.ProductTier
				ELSE REPLACE(LEFT(acc.ProductTier, CHARINDEX('-', acc.ProductTier)-1), '-', '')
			END
	, AR26 = c1.TotalIncomeIncCredits
	, AR27 = IIF(acc.LoanType = 'BTL', 4, 3) -- BTL non verified but residential is
	, AR28 = IIF(c2.DIM_CO_Customer_DWSK IS NULL 
				, NULL
				, c2.TotalIncomeIncCredits 
				)
	, AR28F = IIF(c2.DIM_CO_Customer_DWSK IS NULL 
				, '0.00'
				, CONVERT(VARCHAR(20), c2.TotalIncomeIncCredits)
				)
	, AR29 = CASE 
				WHEN c2.DIM_CO_Customer_DWSK IS NULL THEN 'ND'  -- not applicable if only 1 applicant
				WHEN acc.LoanType = 'BTL' THEN '4' -- unverfied if BTL
				ELSE '3'  -- is residential so verified 
			 END
	, AR30 = CASE 
				WHEN c1.Nationality NOT IN ('British', 'United Kingdom') AND c1.ResidenceCountry NOT IN ('UnitedKingdom', 'United Kingdom') AND c1.EUNational = 0  THEN '3' -- Other Foreign National living elsewhere
				WHEN c1.Nationality NOT IN ('British', 'United Kingdom') AND c1.ResidenceCountry NOT IN ('UnitedKingdom', 'United Kingdom') AND c1.EUNational = 1 THEN '3' -- EU National living elsewhere
				WHEN c1.IsExpat = 1 THEN '3' 
				WHEN c1.YearsInUK < 3 THEN '1'
				ELSE '2'
			END
	, AR31 = c1.CCJNo_6yr_Satisfied
	, AR32 = c1.CCJVal_6yr_Satisfied
	, AR33 = c1.CCJNo_6yr_UnSatisfied
	, AR34 = c1.CCJVal_6yr_UnSatisfied
	, AR35 = CONVERT(DATE, c1.Date_last_CCJ)
	, AR35F = ISNULL(CONVERT(VARCHAR(10), FORMAT(c1.Date_last_CCJ, 'dd-MM-yyyy')), 'ND')
	, AR36 = IIF(c1.IVANo_6yr + c1.BONo_6yr > 0, 'Y', 'N')
	, AR37 = NULL
	, AR38 = NULL
	, AR39 = NULL
	, AR40 = NULL
	, AR41 = NULL
	, AR42 = NULL
	, AR43 = 'ND' 
	, AR43F = 'ND'
	, AR44 = 'ND'
	, AR44F = 'ND'
	, AR45 = NULL
	, AR45F = NULL
	, AR46 = 'ND'
	, AR47 = IIF(c1.Mortgage_repos > 0, 'Y', 'N') 
	, AR48 = COALESCE(CONVERT(VARCHAR, c1.SixMonthsMissed) , 'ND')
	, AR49 = IIF(
				c1.SixMonthsMissed IS NULL
				, 'ND'
				,  CONVERT(VARCHAR(20), COALESCE(c1.TotalMissed , 0) - COALESCE(c1.SixMonthsMissed , 0) )
				)
	, AR50 = NULL
	, AR51 = NULL
	, AR52 = NULL
	, AR53 = IIF(acc.Division = 'BML', NULL, acc.InitialMaturityDate) -- only for Shawbrook reporting.formatted is still blank
	, AR53F = NULL
	, AR54 = NULL
	, AR54F = CAST(NULL AS DECIMAL(20,2))
	, AR55 = CONVERT(DATE, acc.AccountOpenDate)
	, AR56 = DATEADD(MONTH, acc.TermInMonths, acc.AccountOpenDate) --- NEED TO REVIEW WHEN WE GET A TERM EXTENSION FORBEARANCE MEASURE
	, AR57 = IIF(acc.Securitised = 1, SecuritisedDate, NULL)
	, AR58 = CASE
				WHEN acc.Division = 'TML' THEN IIF(sa.IntermediaryRoute = 'Packager', '5', '3')
				WHEN sa.IntermediaryRoute = 'Club' THEN '1'
				WHEN sa.IntermediaryRoute = 'Network' THEN '1'
				WHEN sa.IntermediaryRoute = 'Direct' THEN '2'
				WHEN sa.IntermediaryRoute = 'Broker' THEN '3'
				WHEN sa.IntermediaryRoute = 'Internet' THEN '4'
				WHEN sa.IntermediaryRoute = 'Packager' THEN '5'
				ELSE '3' 
			 END
	, AR59 = CASE 
				WHEN acc.MortgageType = 'Purchase' THEN '1'
				WHEN acc.MortgageType = 'Re-mortgage with Equity Release' THEN '8'
				WHEN acc.MortgageType <> 'Purchase' AND ISNULL(dc.MoneyWithdrawn, 0) = 0 THEN '2'
				WHEN ISNULL(dc.MoneyWithdrawn, 0) > 0 AND ISNULL(dc.TrueDebtCon, 0) > 0 THEN '6'
				WHEN ISNULL(dc.MoneyWithdrawn, 0) > 0 AND ISNULL(dc.TrueDebtCon, 0) = 0 THEN '8'
				WHEN ISNULL(dc.MoneyWithdrawn, 0) > 0 AND ISNULL(dc.TrueDebtCon, 0) < 0 AND FLOOR(CONVERT(INT, dc.TrueDebtCon)) = 0  THEN '8' --Rounding issue relating to M001433174
				ELSE 'ERROR'
			END
	, AR60 = IIF(acc.ProductTier LIKE '%Shared%', '6', '1')
	, AR61 = acc.InitialTerm
	, AR62 = 0
	, AR63 = '0.00'
	, AR64 = 'N'
	, AR65 = 2
	, AR66 = acc.OpeningCapitalBalance
	, AR67 = acc.PrincipalBalance -- principal instead of actual balance
	, AR68 = 'N'   
	, AR69 = CASE acc.RepaymentType
					WHEN 'InterestOnly' THEN 1
					WHEN 'Repayment' THEN 2
					WHEN 'PartByPart' THEN 7
					ELSE 9
				END
	, AR70 = 1
	, AR71 = IIF(acc.AccountClosedDate IS NOT NULL, NULL,  NULLIF(acc.ScheduledPayment, 0))
	, AR72 = CASE acc.RepaymentType
					WHEN 'InterestOnly' THEN 6 -- Bullet
					WHEN 'Repayment' THEN 1 -- Annuity
					WHEN 'PartByPart' THEN 13 -- Other
					ELSE 13 -- Other
				END
	, AR73 = CASE 
				WHEN acc.Division = 'BML' THEN NULL
				WHEN acc.LoanType = 'BTL' THEN NULL
				ELSE acc.OpeningCapitalBalance /  (c1.TotalIncomeIncCredits + ISNULL(c2.TotalIncomeIncCredits, 0)) --combined salaries for Resi
			 END 	
	, AR73F = CONVERT(DECIMAL(20,4), 
								CASE 
									WHEN acc.Division = 'BML' THEN NULL
									WHEN acc.LoanType = 'BTL' THEN NULL
									ELSE acc.OpeningCapitalBalance /  (c1.TotalIncomeIncCredits + ISNULL(c2.TotalIncomeIncCredits, 0)) --combined salaries for Resi
								 END 
							)
	, AR74 = IIF(
				acc.LoanType <> 'BTL' AND acc.InitialProductFeature = 'Help To Buy'
				, 4 
				, 1 --no guarantor
			) 
	, AR75 = 'NA' 
	, AR75F = ''
	, AR76 = 'NA' 
	, AR76F = ''
	, AR77 = 'NA'
	, AR77F = ''
	, AR78 = IIF(
				acc.LoanType <> 'BTL' AND acc.InitialProductFeature = 'Help To Buy'
				, 'UK Government'
				, 'NA'
			) 
	, AR78F = IIF(
				acc.LoanType <> 'BTL' AND acc.InitialProductFeature = 'Help To Buy'
				, 'UK Government'
				, ''
			)
	, AR79 = 'NA'
	, AR79F = ''
	, AR80 = '0.00'
	, AR81 = '0.00'
	, AR82 = '0.00'
	, AR83 = '0.00'
	, AR84 = 1
	, AR85 = CONVERT(DECIMAL(20,2), IIF(ISNULL(rets.AvailableAmount, 0.00) = 0.00, 0.00, rets.AvailableAmount))
	, AR86 = rets.ExpiryDate
	, AR86F = FORMAT(rets.ExpiryDate, 'dd-MM-yyyy')
	, AR87 = IIF(
				acc.LoanType = 'Residential'
				, CONVERT(VARCHAR(20),acc.PrincipalBalance) -- principal balance 24AM
				, CONVERT(VARCHAR(20),acc.PrincipalBalance) 
			) 
	, AR88 = 'NA'
	, AR88F = ''
	, AR89 = 'NA'
	, AR89F = ''
	, AR90 = 'NA'
	, AR90F = '0.00'
	, AR91 = 'NA'
	, AR91F = 'N'
	, AR92 = ISNULL(ph.HolidayPeriod, 0)
	, AR93 = 'NA'
	, AR93F = ''
	, AR94 = 'NA'
	, AR94F = ''
	, AR95 = 'NA'
	, AR95F = ''
	, AR96 = 'NA'
	, AR96F = ''
	, AR97 = ISNULL(overpayments.lastOverPaymentAmount, 0.00)
	, AR98 = ISNULL(CONVERT(VARCHAR(20), overpayments.LatestPaymentDate), 'NA')
	, AR98F = ISNULL(CONVERT(VARCHAR(20), overpayments.LatestPaymentDate), '')
	, AR99 = CONVERT(DECIMAL(20,2), ISNULL(overpayments.ERCTotal, 0.00))
	, AR100 = ISNULL(overpayments.OverPaymentAmount, 0.00) 
	, AR101 = 0.1
	, AR101F = '0.10'
	, AR102 = NULL
	, AR103 = CONVERT(DECIMAL(20,2),IIF(acc.ProductTier LIKE '%Shared%', prop.PurchasePrice/acc.Valuation, NULL))
	, AR104 = CONVERT(DECIMAL(20,2),IIF(acc.ProductTier LIKE '%Shared%', prop.PurchasePrice/acc.Valuation, NULL))
	, AR105 = CASE 
				WHEN acc.Division = 'BML' THEN IIF(acc.Product LIKE '%htb%', 1, 4)
				ELSE IIF(acc.InitialProductFeature = 'Help To Buy', 1, 4) 
			  END
	, AR106F = CAST(NULL AS DECIMAL(20,2))
	, AR106 = IIF(
				acc.LoanType = 'Residential'
				, NULL
				, CASE acc.RepaymentType
					WHEN 'Repayment' THEN 0
					WHEN 'InterestOnly' THEN acc.OpeningCapitalBalance
					WHEN 'PartByPart' THEN acc.InterestOnlyAmount
					ELSE -1
				  END
				)
	-- Change #39 -column now based on initial product and not the status at month end which it was previously. Reversion status is irrelevant
	, AR107 = CASE 
				WHEN DATEDIFF(m, acc.AccountOpenDate, acc.ReversionDate) = acc.TermInMonths AND acc.Product LIKE '%Fixed%'  THEN '3' -- equivalent to fixed for life
				WHEN DATEDIFF(m, acc.AccountOpenDate, acc.ReversionDate) = acc.TermInMonths AND acc.Product LIKE '%Tracker%' THEN '1' -- equivalent to float for life
				WHEN acc.Product LIKE '%Fixed%' THEN '5'
				WHEN acc.Product LIKE '%Tracker%' THEN '2'
				WHEN acc.Product LIKE '%Inferred Member%' THEN 'Dodgy Test Data'
				ELSE 'Error'
			  END 
	, AR108 = CASE 
				WHEN acc.IsLatest = 0 THEN 'ND' -- not latest so no current interest rate
				WHEN acc.Product LIKE '%Fixed%' AND acc.RevertedFlag = 0 THEN 'ND' -- fixed not reverted yet
				WHEN acc.BaseRateCode = 'LIBOR' THEN '3' -- LIBOR
				WHEN acc.BaseRateCode = 'BBR' THEN '9'
				ELSE '11' -- standard variable rate
			  END
	, AR109 = ISNULL(acc.InterestRate / 100, 0.00)
	, AR109F = ISNULL(CONVERT(DECIMAL(10, 5), acc.InterestRate / 100), 0.00)
	, AR110 = CASE
				WHEN acc.AccountClosedDate IS NOT NULL THEN NULL --- closed account
				WHEN acc.Product LIKE '%Fixed%' AND acc.RevertedFlag = 0 THEN acc.InterestRate -- fixed not reverted show current interest rate
				WHEN acc.Product LIKE '%Tracker%' AND acc.RevertedFlag = 0 THEN acc.BaseRateMargin -- fixed not reverted show current base rate margin
				ELSE acc.RevertMargin -- reverted
			END / 100
	, AR110F = CONVERT(DECIMAL(10, 5), CASE
											WHEN acc.AccountClosedDate IS NOT NULL THEN NULL --- closed account
											WHEN acc.Product LIKE '%Fixed%' AND acc.RevertedFlag = 0 THEN acc.InterestRate -- fixed not reverted show current interest rate
											WHEN acc.Product LIKE '%Tracker%' AND acc.RevertedFlag = 0 THEN acc.BaseRateMargin -- fixed not reverted show current base rate margin
											ELSE acc.RevertMargin -- reverted
										END / 100
				)
	, AR111 = IIF(acc.Product LIKE '%Fixed%' AND acc.RevertedFlag = 0, 'NA', '3')
	, AR111F = IIF(acc.Product LIKE '%Fixed%' AND acc.RevertedFlag = 0, '', '3')
	, AR112 = 'NA'
	, AR112F = ''
	, AR113 = IIF(acc.RevertedFlag = 0 AND acc.IsLatest = 1, acc.ReversionDate, NULL) -- only has a future change if not already reverted and is secured in latest month
	, AR114 = 'NA'
	, AR114F = ''
	, AR115 = 'NA'
	, AR115F = ''
	, AR116 = 'NA'
	, AR116F = ''
	, AR117 = 'NA'
	, AR117F = ''
	, AR118 = CASE 
				WHEN DATEDIFF(m, acc.AccountOpenDate, acc.ReversionDate) = acc.TermInMonths THEN 'ND' -- Accounts for mortgages that are fixed until end of mortgage term
				WHEN acc.IsLatest = 0 THEN 'ND' -- not latest so no future change
				WHEN acc.RevertedFlag = 1 THEN 'ND' -- already reverted so no future change
				WHEN acc.Product LIKE '%Fixed%' AND CONVERT(INT, LEFT(acc.Product, CHARINDEX(' ', acc.Product)-1)) * 12 = acc.TermInMonths THEN 'ND' -- equivalent to fixed for life so no future change
				WHEN acc.ReversionRateCode = 'LIBOR' THEN  '11' --'9' -- LIBOR - 9s should be 11 , treasury request
				WHEN acc.ReversionRateCode = 'BBR' THEN '11' --'9' - 9s should be 11 , treasury request
				ELSE '11' -- standard variable rate
			  END
	, AR119 =	CASE 
				WHEN DATEDIFF(m, acc.AccountOpenDate, acc.ReversionDate) = acc.TermInMonths THEN NULL -- Accounts for mortgages that are fixed until end of mortgage term
				ELSE IIF(acc.RevertedFlag = 1 OR acc.IsLatest = 0, NULL, acc.RevertMargin / 100) -- no future margin if already reverted or not latest
				END
	, AR120 = acc.RevertMargin / 100 
	, AR121 = acc.ReversionDate
	, AR122 = ISNULL(fb.AR122, 'N')
	, AR123 = ISNULL(fb.AR123, 9)
	, AR124 = acc.PTFlag
	, AR124F = NULL
	, AR125 = acc.PTDate	
	, AR125F = NULL
	, AR126 = NULL
	, AR127 = CAST(NULL AS VARCHAR(100))
	, AR127SB = CASE 
					WHEN acc.AccountNo IN ('M001450442', 'M001443117') THEN 'House in multiple occupation - 6 or fewer occupants'
					WHEN acc.ProductTier LIKE 'HMO%' AND prop.NumberOfBedrooms < 7 THEN 'House in multiple occupation - 6 or fewer occupants'
					WHEN acc.ProductTier LIKE 'HMO%' AND prop.NumberOfBedrooms >= 7  THEN 'House in multiple occupation - 7 or more occupants'
					WHEN prop.PropertyType IN ('Flat', 'StudioFlat', 'FlatStudio', 'Maisonette') AND prop.PropertySubType = 'Converted'THEN 'Flat Converted Flat'
					WHEN prop.PropertyType IN ('Flat', 'StudioFlat', 'FlatStudio', 'Maisonette', 'PurposeBuiltFlat') THEN 'Flat Purpose Built'
					WHEN prop.PropertyType IN ('House', 'Bungalow', 'Other') AND prop.PropertySubType IN ('Detached', 'SemiDetached', 'Semi-Detached', 'EndTerraced', 'EndTerrace', 'Other') THEN 'Single Dwelling - House'
					WHEN prop.PropertyType IN ('House', 'Bungalow', 'Other') THEN 'House Mid-Terrace'
					WHEN prop.PropertyType IN ('Detached House', 'Semi-Detached House', 'End Terrace House', 'Detached Bungalow', 'Semi-Detached Bungalow') THEN 'Single Dwelling - House'
					WHEN prop.PropertyType IN ('Mid Terrace House') THEN 'House Mid-Terrace'
					WHEN prop.PropertyType = 'House' AND prop.TenureType IN ('Freehold', 'Feuhold/Absolute Ownership') THEN 'Single Dwelling - House' -- BML freehold
					ELSE 'ERROR'
				 END		
	, AR128 = ISNULL(NULLIF(prop.ITL1Name, ''), 'Unknown ITL 1') -- NUTS Unknown for new builds that haven't been mapped yet
	, AR128F = ISNULL(NULLIF(prop.ITL1Code, ''), 'TLZ') -- NUTS Unknown for new builds that haven't been mapped yet 
	, AR129 = UPPER(RTRIM(LEFT(prop.Postcode, PATINDEX('% %',prop.Postcode))))
	, AR130 = IIF(CHARINDEX('BTL', acc.Loantype) > 0, 3, 1)
	, AR131 = CASE
				  WHEN acc.ProductTier LIKE 'HMO%' THEN 5
				  WHEN prop.ValuationType IN ('HMOIL', 'MUBIL') THEN 5
				  WHEN prop.PropertyType = 'Other' AND CHARINDEX('Detach', prop.PropertySubType) > 0 THEN 1
				  WHEN prop.PropertyType = 'Other' AND CHARINDEX('Terrace', prop.PropertySubType) > 0 THEN 4
				  WHEN prop.PropertyType = 'Other' AND prop.PropertySubType = 'Other' THEN 1
				  WHEN prop.PropertyType = 'Other' THEN 11
				  WHEN CHARINDEX('Bungalow', prop.PropertyType) > 0 THEN 3
				  WHEN CHARINDEX('Detach', prop.PropertyType) > 0 THEN 1
				  WHEN CHARINDEX('Flat', prop.PropertyType) > 0 THEN 2
				  WHEN CHARINDEX('Terrace', prop.PropertyType) > 0 THEN 4
				  WHEN CHARINDEX('House', prop.PropertyType) > 0 AND CHARINDEX('Detach', prop.PropertySubType) > 0 THEN 1
				  WHEN prop.PropertyType IN ('Maisonette') THEN 2
				  WHEN prop.PropertyType = 'House' AND prop.PropertySubType IN ('BackToBack', 'Converted', 'Other') THEN 1
				  WHEN prop.PropertyType = 'House' AND CHARINDEX('Terrace', prop.PropertySubType) > 0 THEN 4
				  WHEN prop.PropertyType = 'Terraced' AND prop.PropertySubType = 'Terraced' and prop.TenureType in ('Freehold','Feuhold') THEN 4 --BML
				  WHEN prop.PropertyType = 'House' AND prop.TenureType IN ('Freehold', 'Feuhold/Absolute Ownership') THEN 1 -- BML freehold
				  WHEN prop.PropertyType = 'Back to Back' AND prop.PropertySubType = 'Terraced' and prop.TenureType in ('Freehold','Feuhold') THEN 4 --BML
				  ELSE 999
			  END
	, AR132 = CASE
					WHEN prop.IsNewBuild = 1 AND YEAR(CONVERT(DATE, acc.AccountOpenDate)) - (IIF(prop.PropertyBuilt != 0, prop.PropertyBuilt, IIF(prop.IsNewBuild = 1, YEAR(prop.ValuationDate), 0))) < 2 THEN '1'
					WHEN prop.IsNewBuild = 0 AND YEAR(CONVERT(DATE, acc.AccountOpenDate)) - (IIF(prop.PropertyBuilt != 0, prop.PropertyBuilt, IIF(prop.IsNewBuild = 1, YEAR(prop.ValuationDate), 0))) = 0 THEN '1'
					ELSE '2'
				END 
	, AR133 =  IIF(prop.PropertyBuilt != 0, prop.PropertyBuilt, IIF(prop.IsNewBuild = 1, YEAR(prop.ValuationDate), 0))
	, AR134 = 'ND' -- Not captured
	, AR135 = acc.OriginalGrossLTV / 100 -- convert to fraction for decimal
	, AR135F = CONVERT(DECIMAL(20, 4), acc.OriginalGrossLTV / 100)  -- convert to fraction for decimal
	, AR136 = prop.PropertyValue
	, AR137 = prop.OriginalValuationMethod
	, AR138 = CONVERT(DATE , prop.ValuationDate)
	, AR139 = IIF(prop.OriginalValuationMethod = 4, CONVERT(VARCHAR(10), prop.AVMCapitalConfidence), 'NA')
	, AR139F = IIF(prop.OriginalValuationMethod = 4, CONVERT(VARCHAR(10), prop.AVMCapitalConfidence), 'ND')
	, AR140 = IIF(prop.OriginalValuationMethod = 4, 'Hometrack', 'NA')
	, AR140F = IIF(prop.OriginalValuationMethod = 4, 'Hometrack', '')
	, AR141 = acc.CILTV
	, AR142 = IIF(acc.MortgageType = 'Purchase', prop.PurchasePrice, prop.PropertyValue)
	, AR143 = acc.CIValuation
	-- If different value then its indexed so use the last quarter end
	, AR144 = IIF(prop.PropertyValue = acc.CIValuation, prop.OriginalValuationMethod, '5') 
	-- If different value then its indexed so use the last quarter end
	, AR145 = IIF(prop.PropertyValue = acc.CIValuation, prop.ValuationDate, @q1m) 
	, AR146 = 'NA'
	, AR146F = ''
	, AR147 = IIF(prop.PropertyValue = acc.CIValuation AND prop.OriginalValuationMethod = 4, 'Hometrack', 'NA') 
	, AR147F = IIF(prop.PropertyValue = acc.CIValuation AND prop.OriginalValuationMethod = 4, 'Hometrack', '') 
	, AR148 = prop.PropertyValue 
	, AR149 = NULL
	, AR150 = NULL						
	, AR151 = 'NA'							 
	, AR151F = '' 							 
	, AR152 = 'NA'							 
	, AR152F = '' 						 
	, AR153 = 'NA'				  
	, AR153F = ''
	, AR154 = CASE
				WHEN CHARINDEX('Residential', acc.LoanType) > 0 THEN NULL
				WHEN acc.AccountNo = 'M001443305' THEN 24000
				WHEN acc.AccountNo = 'M001407532' THEN 33000
				ELSE st.AnnualRentalIncome
			  END
	, AR155 = CASE
				WHEN acc.Division = 'BML' THEN 1
				WHEN acc.LoanType = 'BTL' THEN  pc.PortfolioCount + acc.CustomerPoolPortfolio
				ELSE NULL
			  END
	, AR156 = CONVERT(VARCHAR(20), CASE 
										WHEN acc.AccountNo = 'M001443305' THEN '1.43'
										WHEN acc.AccountNo = 'M001407532' THEN '1.46'
										WHEN CHARINDEX('BTL', acc.LoanType) > 0 THEN CONVERT(VARCHAR(20), st.ICRAdjusted)
										ELSE 'ND' -- resi now ND
								   END
							)
	, AR157 = '0.00'
	, AR158 = 'N' --update for repossessed properties
	, AR159 = NULL
	, AR160 = NULL
	, AR161 = NULL
	, AR162 = IIF(
				prop.EPCPopulatedBy IN ('Underwriting', 'EPC Register Mapping', 'Bluesky')
				, IIF(prop.EPCRating NOT IN ('A', 'B', 'C', 'D', 'E', 'F', 'G'), 'ND', ISNULL(prop.EPCRating, 'ND'))
				, 'ND'
				)
	, AR163 = IIF(
				prop.EPCPopulatedBy IN ('EPC Register Mapping')
				, IIF(prop.PotentialEPC NOT IN ('A', 'B', 'C', 'D', 'E', 'F', 'G'), 'ND', ISNULL(prop.PotentialEPC, 'ND'))
				, 'ND'
				)
	, AR164 = 'ND'  -- dont know IF property exempt so MARK AS ND
	, AR165 = NULL

	------------------------------------------------------------
	/* 
	ARREARS
	*/
	, AR166 = CASE
				WHEN acc.AccountClosedDate IS NOT NULL THEN '4' -- Redeemed
				WHEN repo.AccountNo IS NOT NULL THEN '3' -- repossessed
				WHEN lit.CurrentStatusGroup = 'Possession' THEN '3' -- Default or Foreclosure
				WHEN arrc.TrueArrearsRatio >= 4.00 THEN '3' -- Shawbrook defined default
				WHEN arrc.TrueArrearsBalance > 0 AND arrc.TrueArrearsRatio >= 1 THEN '2' -- arrears
				ELSE '1' -- performing
			  END
	, AR167 = CASE
				WHEN arrc.TrueArrearsBalance > 0 AND arrc.TrueArrearsRatio >= 1 THEN lia.LastCurrent
				ELSE NULL 
			 END -- add case when arr bal >0
	, AR167F = CASE
				WHEN arrc.TrueArrearsBalance > 0 AND arrc.TrueArrearsRatio >= 1 THEN FORMAT(lia.LastCurrent, 'dd-MM-yyyy') -- month end before arrears started
				ELSE NULL 
			 END -- add case when arr bal >0
	, AR168 = ISNULL(CONVERT(VARCHAR,lia.LastInArrears), 'ND') -- for real non ph arrears only
	, AR168F = ISNULL(CONVERT(VARCHAR,FORMAT(lia.LastInArrears, 'dd-MM-yyyy')), 'ND') -- for real non ph arrears only
	, AR169 = IIF(acc.IsLatest = 0, 0, ISNULL(arrc.TrueArrearsBalance, 0)) -- shouldnt be null but isnull for safety
	, AR170 = IIF(acc.IsLatest = 0, 0, ISNULL(arrc.TrueArrearsRatio, 0))
	, AR171 = ISNULL(arr1m.TrueArrearsBalance, 0) -- shouldnt be null but isnull for safety
	, AR172 = ISNULL(arr2m.TrueArrearsBalance, 0) -- shouldnt be null but isnull for safety

	-- keep ph date in if historic. Will always be earlier than forbearance date though so put forbearance first as reporting latest
	, AR173 = CONVERT(VARCHAR(20), fb.AR173)
	, AR173F = CONVERT(VARCHAR(20), FORMAT(fb.AR173, 'dd-MM-yyyy'))

	----------------------------------------------------------------------------------------------------------

	, AR174 = IIF(lit.AccountNo IS NOT NULL, 'Y', 'N')
	, AR175 = ISNULL(CONVERT(VARCHAR(20), acc.AccountClosedDate), '')
	, AR176 = 0
	, AR177 = IIF(repo.CompletedSale = 1, repo.LastArrearsBalance, NULL)
	, AR178 = IIF(repo.RepossessionDate IS NULL, 'NA', CONVERT(VARCHAR(10), repo.RepossessionDate)) 
	, AR178F = IIF(repo.RepossessionDate IS NULL, NULL, repo.RepossessionDate)
	, AR179 = IIF(repo.CompletedSale = 1, ISNULL(repo.SellingPrice, 0), NULL)
	, AR180 = repo.LossOnSale
	, AR181 = 0
	, AR182 = 0
	, AR183 = NULL
	, AR184 = NULL
	, AR185 = NULL
	, AR186 = NULL
	, AR187 = NULL
	, AR188 = NULL
	, AR189 = CASE 
					WHEN c2.EmploymentType IS NULL THEN 'ND'
					WHEN c2.BoeTypeCode = 9 AND c2.LIRFlag = 1 THEN '8' -- other but lending in to retirement
					ELSE ISNULL(CONVERT(VARCHAR(2), c2.BoETypeCode), 'ND')
				END
	, AR190 = CASE
				WHEN c2.DIM_CO_Customer_DWSK IS NULL THEN 'ND'
				WHEN CHARINDEX('-', acc.ProductTier) = 0 THEN acc.ProductTier
				ELSE REPLACE(LEFT(acc.ProductTier, CHARINDEX('-', acc.ProductTier)-1), '-', '')
			END
	, AR191 = CASE
				WHEN c2.YearsInUK < 3 THEN '1'
				WHEN c2.YearsInUK >= 3 THEN '2'
				ELSE 'ND'
			 END
	, AR192 = IIF(c2.DIM_CO_Customer_DWSK IS NULL, 'ND', TRY_CONVERT(VARCHAR, ISNULL(c2.CCJNo_6yr_Satisfied, 0) + ISNULL(c3.CCJNo_6yr_Satisfied, 0) + ISNULL(c4.CCJNo_6yr_Satisfied, 0)))
	, AR193 = IIF(c2.DIM_CO_Customer_DWSK IS NULL, 'ND', TRY_CONVERT(VARCHAR, ISNULL(c2.CCJVal_6yr_Satisfied, 0) + ISNULL(c3.CCJVal_6yr_Satisfied, 0) + ISNULL(c4.CCJVal_6yr_Satisfied, 0)))
	, AR194 = IIF(c2.DIM_CO_Customer_DWSK IS NULL, 'ND', TRY_CONVERT(VARCHAR, ISNULL(c2.CCJNo_6yr_UnSatisfied, 0) + ISNULL(c3.CCJNo_6yr_UnSatisfied, 0) + ISNULL(c4.CCJNo_6yr_UnSatisfied, 0)))
	, AR195 = IIF(c2.DIM_CO_Customer_DWSK IS NULL, 'ND', TRY_CONVERT(VARCHAR, ISNULL(c2.CCJVal_6yr_UnSatisfied, 0) + ISNULL(c3.CCJVal_6yr_UnSatisfied, 0) + ISNULL(c4.CCJVal_6yr_UnSatisfied, 0)))
	, AR196 = IIF(c2.DIM_CO_Customer_DWSK IS NULL, 'ND', TRY_CONVERT(VARCHAR, COALESCE(c2.Date_last_CCJ, c3.Date_last_CCJ, c4.Date_last_CCJ), 103)) 
	, AR197 = IIF(
					c2.DIM_CO_Customer_DWSK IS NULL
					, 'ND'
					, IIF(
						TRY_CONVERT(VARCHAR, ISNULL(c2.IVANo_6yr, 0) + ISNULL(c2.BONo_6yr, 0) + ISNULL(c3.IVANo_6yr, 0) + ISNULL(c3.BONo_6yr, 0) + ISNULL(c4.IVANo_6yr, 0) + ISNULL(c4.BONo_6yr, 0)) = '0'
						, 'N'
						, 'Y' 
					)
				)
	, AR198 = NULL
	, AR199 = NULL
	, AR200 = NULL
	, AR201 = NULL
	, AR202 = NULL
	, AR203 = NULL
	, AR204 = 'ND'
	, AR205 = 'ND'
	, AR206 = 'ND'
	, AR207 = 'ND'
	, AR208 = IIF(
				 c2.DIM_CO_Customer_DWSK IS NULL
				 , 'ND'
				 ,  IIF(ISNULL(c2.Mortgage_repos, 0) + ISNULL(c3.Mortgage_repos, 0)  + ISNULL(c4.Mortgage_repos, 0) > 0, 'Y', 'N')
			  )
	, AR209 = CASE 
					WHEN c2.DIM_CO_Customer_DWSK IS NULL 
						 THEN 'ND' -- only one applicant
					WHEN c2.SixMonthsMissed IS NULL AND c3.SixMonthsMissed IS NULL AND c4.SixMonthsMissed IS NULL 
						 THEN 'ND' -- no info for any of other applicants
					ELSE CONVERT(VARCHAR , COALESCE(c2.SixMonthsMissed , 0) + COALESCE(c3.SixMonthsMissed , 0) + COALESCE(c4.SixMonthsMissed , 0))
				 END
	, AR210 = CASE 
					WHEN c2.DIM_CO_Customer_DWSK IS NULL 
						 THEN 'ND' -- only one applicant
					WHEN c2.SixMonthsMissed IS NULL AND c3.SixMonthsMissed IS NULL AND c4.SixMonthsMissed IS NULL 
						 THEN 'ND' -- no info for any of other applicants
					ELSE CONVERT(VARCHAR , (COALESCE(c2.TotalMissed , 0) - COALESCE(c2.SixMonthsMissed , 0)) 
													+ (COALESCE(c3.TotalMissed , 0) - COALESCE(c3.SixMonthsMissed , 0))
													+ (COALESCE(c4.TotalMissed , 0) - COALESCE(c4.SixMonthsMissed , 0)) 
									)
				 END
	, AR211 = NULL
	, AR212 = NULL
	, AR213 = NULL
	, AR214 = NULL
	, AR215 = NULL
	, AR216 = NULL
	, AR217 = 'ND'
	, AR218 = 'ND'
	, AR219F = CAST(NULL AS VARCHAR(20))
	, AR219 = CAST(NULL AS VARCHAR(20))
	, AR220 = 'ND'
	, AR221 = NULL
	, AR222 = NULL
	, AR223 = NULL
	, AR224 = NULL
	, AR225 = NULL
	, AR226 = NULL
	, AR227 = 'ND'
	, AR228 = 'ND'
	, AR229 = NULL 
	, AR229F = NULL
	, AR230 = 'ND'
	, AR231 = CASE
				WHEN acc.Division = 'BML' AND c2.CustomerType IS NOT NULL THEN 'IND'
				WHEN COALESCE(c2.CustomerType , 'ND') = 'Individual' THEN 'IND'
				WHEN COALESCE(c2.CustomerType , 'ND') = 'Company' THEN 'COM'
				WHEN COALESCE(c2.CustomerType , 'ND') = 'ND' THEN 'ND'
				ELSE 'ERROR'
			  END
	, AR232 = CASE
			   WHEN c2.Nationality IS NULL THEN 'ND'
			   WHEN c2.Nationality = 'British' THEN 'N'
			   WHEN c2.Nationality = 'United Kingdom' THEN 'N'
			   ELSE 'Y'
		   END
	, AR233 = CASE
				WHEN c2.DIM_CO_Customer_DWSK IS NULL THEN 'ND'
				WHEN CHARINDEX('-', acc.ProductTier) = 0 THEN acc.ProductTier
				ELSE REPLACE(LEFT(acc.ProductTier, CHARINDEX('-', acc.ProductTier)-1), '-', '')
			END
	, AR234 = CASE
				WHEN c2.DIM_CO_Customer_DWSK IS NULL THEN 'ND'
				WHEN c2.FTBFlag = 1 THEN 'Y'
				WHEN c2.FTBFlag = 0 OR
					acc.MortgageType = 'Remortgage' THEN 'N'
				ELSE 'Unknown'
			 END
	, AR235 = IIF(c1.IVANo_6yr + c1.BONo_6yr > 0, 'Y', 'N') 
	, AR236 = IIF(
					c2.DIM_CO_Customer_DWSK IS NULL
					, 'ND'
					, IIF(
						 ISNULL(c2.IVANo_6yr, 0) + ISNULL(c2.BONo_6yr, 0) + ISNULL(c3.IVANo_6yr, 0) + ISNULL(c3.BONo_6yr, 0) + ISNULL(c4.IVANo_6yr, 0) + ISNULL(c4.BONo_6yr, 0) > 0
						 , 'Y'
						 , 'N'
						) 
					)
	, MainMissedOneYear = CONVERT(VARCHAR , COALESCE(c1.YearMissed , 0))
	, AdditionalMissedOneYear = CONVERT(VARCHAR(20) , COALESCE(c2.YearMissed , 0) + COALESCE(c3.YearMissed , 0) + COALESCE(c4.YearMissed , 0))
	, PaymentHolidayEndDate = ph.EndDate
	, AuthorisedPaymentHolidayArrears = ISNULL(arrc.PaymentHolidayBalance, 0)
	, EligiblePool = acc.EligPool
	, acc.ExcludeFromSecuritisation 
	, acc.InitialFunder
	, acc.ApplicationRef
	, acc.IsLatest
	, FolderPath = REPLACE(IIF(prop.ITL1Name = 'Scotland', sec.ScottishPath, EnglishPath), 'yyyyMM', CONVERT(VARCHAR(6), FORMAT(@monthEnd, 'yyyyMM')))
	INTO #report
	FROM #accs acc
	INNER JOIN (
		SELECT *
		, OriginalValuationMethod = CASE ValuationType
										WHEN 'InternalValuation' THEN '1'
										WHEN 'Revaluation' THEN '1'
										WHEN 'FullValuation' THEN '1'
										WHEN 'Standard Valuation' THEN '1'
										WHEN 'Home buyers+Standard Valuation' THEN '1'
										WHEN 'Re-inspection' THEN '1'
										WHEN 'Re-type' THEN '1' -- desktop
										WHEN 'Driveby' THEN '3' 
										WHEN 'CustomerProvided' THEN '9999'
										WHEN 'Unknown' THEN 'ND'
										WHEN 'BTLStandardIL' THEN '1' 
										WHEN 'HMOIL' THEN '1'
										WHEN 'MUBIL' THEN '1'
										WHEN 'AVM' THEN '4'
										-- BML
										WHEN 'Full' THEN '1'
										WHEN 'Origination' THEN '1'
										WHEN 'ScottishRetype' THEN '4'
										WHEN 'Manual' THEN ''
										WHEN 'Desktop' THEN '6'
										WHEN 'Reinspection' THEN '1'
										WHEN 'Drive by' THEN '3' 
										ELSE '9999' -- ERROR
									 END 
		FROM TML_DW.dbo.tbl_PropertyDetails 
	) prop 
		ON acc.AccountNo = prop.ApplicationRef

	INNER JOIN TML_DW.dbo.tbl_Strats st ON acc.AccountNo = st.ApplicationRef --COLLATE DATABASE_DEFAULT

	INNER JOIN DPR_DW.dbo.DIM_CO_Account dacc ON acc.AccountNo = dacc.AccountNo COLLATE DATABASE_DEFAULT
													AND @cobid >= dacc.SCDStartDate 
													AND @cobid < dacc.SCDEndDate 

	INNER JOIN DPR_DW.dbo.IF_COAccount_COAssetSecurity F ON dacc.DIM_CO_Account_DWSK = F.DIM_CO_Account_DWSK
													AND F.IsPrimarySecurity = 'True'
													AND @cobid BETWEEN F.SCDStartDate AND F.SCDEndDate

	INNER JOIN #customers c1 ON acc.AccountNo = c1.ApplicationRef 
								AND c1.BoEAppNo = 1
	INNER JOIN TML_DW.dbo.tbl_Products pro ON acc.ProductCode = pro.ProductCode

	LEFT OUTER JOIN dbo.tbl_SalesActuals sa	ON acc.ApplicationRef = sa.ApplicationRef
	LEFT OUTER JOIN #customers c2 ON acc.AccountNo = c2.ApplicationRef 
															AND c2.BoEAppNo = 2	
	LEFT OUTER JOIN #customers c3 ON acc.AccountNo = c3.ApplicationRef 
															AND c3.BoEAppNo = 3	
	LEFT OUTER JOIN #customers c4 ON acc.AccountNo= c4.ApplicationRef 
															AND c4.BoEAppNo = 4	
														
	LEFT OUTER JOIN TML_DW.dbo.fn_AccountMonthlySchedule(@cobid, NULL) payment ON  acc.AccountNo = payment.AccountNo --COLLATE DATABASE_DEFAULT
			    
	LEFT OUTER JOIN (
		SELECT A.AccountNo
		, A.TrueArrearsBalance, A.TrueArrearsRatio
		, A.PaymentHolidayBalance
		, ShawbrookDefault = IIF(A.TrueArrearsRatio >= 4.00, 1, 0) 
		, DefaultStartDate = IIF(A.TrueArrearsRatio >= 4.00, def.DefaultStartDate, NULL) 
		FROM dbo.tbl_ArrearsDaily A
		LEFT OUTER JOIN (
			-- get default start date
			SELECT A.AccountNo
			, DefaultStartDate = EOMONTH(DATEADD(m, 1, MAX(A.CobDate))) -- to get first moth they were at 4 or highr find last tim ethey were less than and add one month to date
			FROM dbo.tbl_ArrearsDaily A
			INNER JOIN dbo.tbl_SystemCalendar c ON a.COBDate = c.Date
													AND c.LastDayOfMonth = 'Y'
			WHERE a.COBDate < @monthEnd
			AND a.TrueArrearsRatio < 4.00
			GROUP BY a.AccountNo
		) def
			ON a.AccountNo = def.AccountNo
		WHERE a.COBDate = @monthEnd
	) arrc
		ON acc.AccountNo = arrc.AccountNo COLLATE DATABASE_DEFAULT


	LEFT OUTER JOIN TML_DW.dbo.tbl_ArrearsDaily arr1m ON acc.AccountNo = arr1m.AccountNo COLLATE DATABASE_DEFAULT
															AND arr1m.COBDate = @b1m
														
	LEFT OUTER JOIN TML_DW.dbo.tbl_ArrearsDaily arr2m ON acc.AccountNo = arr2m.AccountNo COLLATE DATABASE_DEFAULT
															AND arr2m.COBDate = @b2m

	LEFT OUTER JOIN (
		SELECT ms.AccountNo
		, LastInArrears = MAX(ms.MonthEnd)
		, MaxArrears = MAX(ms.ArrearsRatio)
		, lc.LastCurrent
		FROM dbo.tbl_AccountMonthlySummary ms
		INNER JOIN #accs a ON ms.AccountNo = a.AccountNo 
		LEFT OUTER JOIN (
			SELECT DISTINCT m.AccountNo
			, LastCurrent = MAX(m.MonthEnd)
			FROM dbo.tbl_AccountMonthlySummary m
			INNER JOIN #accs a ON m.AccountNo = a.AccountNo 
			WHERE ISNULL(m.ArrearsRatio, 0) < 1.00
			AND m.MonthEnd <= @monthEnd
			GROUP BY m.AccountNo
		) lc
			ON ms.AccountNo = lc.AccountNo
		WHERE ms.MonthEnd <= @monthEnd
		AND ms.ArrearsRatio >= 1.00
		GROUP BY ms.AccountNo, lc.LastCurrent
	) lia
		ON acc.AccountNo = lia.AccountNo COLLATE DATABASE_DEFAULT 

	LEFT OUTER JOIN dbo.tbl_Litigations lit ON acc.AccountNo = lit.AccountNo COLLATE DATABASE_DEFAULT
												AND lit.MonthEnd = acc.MonthEnd

	LEFT OUTER JOIN fn_Repossessions(@monthEnd) repo ON acc.AccountNo = repo.AccountNo

	LEFT OUTER JOIN #forb fb ON acc.AccountNo = fb.AccountNo

	----------------------------------------------------------------------------------

	LEFT OUTER JOIN (
		 SELECT ret.AccountNo, ret.OriginalAmount
				, AvailableAmount = ret.AvailableAmount + ISNULL(rr.WithdrawnSinceMonthEnd, 0)
				, ret.DateActive
				, ret.ExpiryDate, ret.LastTransaction, ret.Closed, ret.ClosedReason, ret.LastUpdated 
		 FROM  TML_DW.dbo.tbl_Retentions ret
		 LEFT OUTER JOIN (
			  SELECT rr.AccountNo
			  , WithdrawnSinceMonthEnd = SUM(rr.DrawdownAmount)
			  FROM dbo.vw_RetentionReleases rr
			  WHERE rr.WithdrawalDate BETWEEN DATEADD(d, 1, @monthEnd) AND GETDATE()
			  GROUP BY rr.AccountNo
		 ) rr
			  ON ret.AccountNo = rr.AccountNo
		 WHERE @monthEnd BETWEEN ret.DateActive AND ISNULL(ret.LastTransaction, ret.ExpiryDate)
		 AND ret.Closed = 0
	) rets 				 
		ON rets.AccountNo = acc.AccountNo

	-- overpayments / prepayments

	LEFT OUTER JOIN ( 
		 SELECT AccountNo, LatestPaymentDate, LastOverPaymentAmount, OverPaymentAmount
		, ERCTotal = ERCTotal -- confirm if should include otherwise 0
		, OverpaymentsMade 
		FROM TML_DW.dbo.fn_Overpayments(@monthEnd) o
	) overpayments
		 ON acc.AccountNo = overpayments.AccountNo COLLATE DATABASE_DEFAULT

	LEFT OUTER JOIN TML_DW.dbo.tbl_Countries cnt1 ON c1.Nationality = cnt1.Nationality COLLATE DATABASE_DEFAULT
	LEFT OUTER JOIN TML_DW.dbo.tbl_Countries cntRes ON c1.ResidenceCountry = cntRes.SystemName COLLATE DATABASE_DEFAULT
	LEFT OUTER JOIN TML_DW.dbo.vw_PortfolioCount pc ON acc.AccountNo = pc.ApplicationRef
	LEFT OUTER JOIN TML_DW.dbo.vw_DebtConsolidation dc ON acc.AccountNo = dc.ApplicationRef

	LEFT OUTER JOIN TML_DW.dbo.tbl_PaymentHolidays ph ON acc.AccountNo = ph.AccountNo
													  AND ISNULL(ph.TrackerStatus, 'PH Active') NOT IN ('Redeemed', 'Cancelled')
													  AND ISNULL(ph.DateAgreed, GETDATE()) <= @monthEnd
													  AND ISNULL(ph.InitialStartDate, ph.ReportStartDate) <= @monthEnd

	LEFT OUTER JOIN #securitisations sec ON acc.SecuritisationTag = sec.SecuritisationTag

	ORDER BY acc.AccountNo
	OPTION (RECOMPILE);

	---------------------------------------
	-- populate the tables


	----------------------------

	-- delete if already exists
	DELETE dbo.tbl_LoanLevelReport 
	WHERE ReportMonth = @monthEnd
	AND ReportQuery = 'ZINC 2025';

	 
	INSERT INTO dbo.tbl_LoanLevelReport (
		ReportMonth, SecuritisationTag, Securitised, SecuritisationFlag, SecuritisationGroup
		, ReportName, Division, LoanType, CurrentBalance, PrincipalBalance
		, AR1, AR2, AR2F, AR3, AR4
		, AR5, AR6, AR7, AR8, AR9, AR9F, AR10, AR10F, AR11, AR12, AR13, AR14, AR15, AR16--, AR16F
		, AR17, AR18, AR19, AR20, AR21, AR22, AR23, AR24, AR24F, AR25, AR26, AR27, AR28
		, AR28F, AR29, AR30, AR31, AR32, AR33, AR34, AR35, AR35F, AR36, AR37, AR38, AR39, AR40
		, AR41, AR42, AR43, AR43F, AR44, AR44F, AR45, AR45F, AR46, AR47, AR48, AR49, AR50, AR51
		, AR52, AR53, AR53F, AR54, AR54F, AR55, AR56, AR57, AR58, AR59, AR60, AR61, AR62, AR63
		, AR64, AR65, AR66, AR67, AR68, AR69, AR70, AR71, AR72, AR73, AR73F, AR74, AR75, AR75F
		, AR76, AR76F, AR77, AR77F, AR78, AR78F, AR79, AR79F, AR80, AR81, AR82, AR83, AR84, AR85
		, AR86, AR86F, AR87, AR88, AR88F, AR89, AR89F, AR90, AR90F, AR91, AR91F, AR92, AR93, AR93F
		, AR94, AR94F, AR95, AR95F, AR96, AR96F, AR97, AR98, AR98F, AR99, AR100, AR101, AR101F, AR102
		, AR103, AR104, AR105, AR106, AR106F, AR107, AR108, AR109, AR109F, AR110, AR110F, AR111
		, AR111F, AR112, AR112F, AR113, AR114, AR114F, AR115, AR115F, AR116, AR116F, AR117, AR117F
		, AR118, AR119, AR120, AR121, AR122, AR123, AR124, AR124F, AR125, AR125F, AR126, AR127
		, AR128, AR128F, AR129, AR130, AR131, AR132, AR133, AR134, AR135, AR135F, AR136, AR137
		, AR138, AR139, AR139F, AR140, AR140F, AR141, AR142, AR143, AR144, AR145, AR146, AR146F
		, AR147, AR147F, AR148, AR149, AR150, AR151, AR151F, AR152, AR152F, AR153, AR153F, AR154
		, AR155, AR156, AR157, AR158, AR159, AR160, AR161, AR162, AR163, AR164, AR165, AR166, AR167
		, AR167F, AR168, AR168F, AR169, AR170, AR171, AR172, AR173, AR173F, AR174, AR175, AR176
		, AR177, AR178, AR178F, AR179, AR180, AR181, AR182, AR183, AR184, AR185, AR186, AR187
		, AR188, AR189, AR190, AR191, AR192, AR193, AR194, AR195, AR196, AR197, AR198, AR199, AR200
		, AR201, AR202, AR203, AR204, AR205, AR206, AR207, AR208, AR209, AR210, AR211, AR212, AR213
		, AR214, AR215, AR216, AR217, AR218, AR219, AR219F, AR220, AR221, AR222, AR223, AR224, AR225
		, AR226, AR227, AR228, AR229, AR230, AR231, AR232, AR233, AR234, AR235, AR236
		, ExcludeFromSec, EligiblePool, InitialFunder, ApplicationRef, FolderPath
	)
	SELECT ReportMonth, SecuritisationTag, Securitised, SecuritisationFlag, SecuritisationGroup
		, ReportName, Division, LoanType, CurrentBalance, PrincipalBalance
		, AR1, AR2, AR2F, AR3, AR4, AR5, AR6, AR7, AR8, AR9, AR9F, AR10, AR10F
		, AR11 = IIF(Securitised = 1, AR11, AR11NSEC)
		, AR12, AR13, AR14, AR15
		, AR16 = AR16--IIF(LoanType = 'BTL', AR16BTL, AR16)
		/* AR16F*/, AR17, AR18, AR19, AR20, AR21, AR22, AR23, AR24, AR24F, AR25, AR26, AR27, AR28
		, AR28F, AR29, AR30, AR31, AR32, AR33, AR34, AR35, AR35F, AR36, AR37, AR38, AR39, AR40
		, AR41, AR42, AR43, AR43F, AR44, AR44F, AR45, AR45F, AR46, AR47, AR48, AR49, AR50, AR51
		, AR52, AR53, AR53F, AR54, AR54F, AR55, AR56, AR57, AR58, AR59, AR60, AR61, AR62, AR63
		, AR64, AR65, AR66, AR67, AR68, AR69, AR70, AR71, AR72, AR73, AR73F, AR74, AR75, AR75F
		, AR76, AR76F, AR77, AR77F, AR78, AR78F, AR79, AR79F, AR80, AR81, AR82, AR83, AR84, AR85
		, AR86, AR86F, AR87, AR88, AR88F, AR89, AR89F, AR90, AR90F, AR91, AR91F, AR92, AR93, AR93F
		, AR94, AR94F, AR95, AR95F, AR96, AR96F, AR97, AR98, AR98F, AR99, AR100, AR101, AR101F, AR102
		, AR103, AR104, AR105, AR106, AR106F, AR107, AR108, AR109, AR109F, AR110, AR110F, AR111
		, AR111F, AR112, AR112F, AR113, AR114, AR114F, AR115, AR115F, AR116, AR116F, AR117, AR117F
		, AR118, AR119, AR120, AR121, AR122, AR123, AR124, AR124F, AR125, AR125F, AR126
		, AR127 = IIF(LoanType <> 'Residential', AR127SB, AR127)
		, AR128, AR128F, AR129, AR130, AR131, AR132, AR133, AR134, AR135, AR135F, AR136, AR137
		, AR138, AR139, AR139F, AR140, AR140F, AR141, AR142, AR143, AR144, AR145, AR146, AR146F
		, AR147, AR147F, AR148, AR149, AR150, AR151, AR151F, AR152, AR152F, AR153, AR153F, AR154
		, AR155, AR156, AR157, AR158, AR159, AR160, AR161, AR162, AR163, AR164, AR165, AR166, AR167
		, AR167F, AR168, AR168F, AR169, AR170, AR171, AR172, AR173, AR173F, AR174, AR175, AR176
		, AR177, AR178, AR178F, AR179, AR180, AR181, AR182, AR183, AR184, AR185, AR186, AR187
		, AR188, AR189, AR190, AR191, AR192, AR193, AR194, AR195, AR196, AR197, AR198, AR199, AR200
		, AR201, AR202, AR203, AR204, AR205, AR206, AR207, AR208, AR209, AR210, AR211, AR212, AR213
		, AR214, AR215, AR216, AR217, AR218, AR219, AR219F, AR220, AR221, AR222, AR223, AR224, AR225
		, AR226, AR227, AR228, AR229, AR230, AR231, AR232, AR233, AR234, AR235, AR236
		, ExcludeFromSecuritisation, EligiblePool, InitialFunder, ApplicationRef, FolderPath
	FROM #report
	;

------------------------------
	

-- update the daily checks table with the latest date
UPDATE TML_DW.dbo.tbl_DailyCheck 
SET LatestDate = @monthEnd
WHERE TableName = 'TML_DW.dbo.tbl_LoanLevelReport'

---------------------------------------------------------------------------------------------------
-- END & ERROR CATCHING
---------------------------------------------------------------------------------------------------

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
END
GO
