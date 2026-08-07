USE TML_DW
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_PopulateMonthlySummary
	@updateType INT = 1
AS
BEGIN

-- =============================================================================
-- Procedure:   sp_PopulateMonthlySummary
-- Schema:      dbo
-- Database:    TML_DW
-- Purpose:     populates the account summary table with common monthly reporting data.
-- Owner:       Data Engineering Team
-- Dependencies:
--   Tables:    DPR_DW.dbo.DIM_CO_Account, DPR_DW.Latest_Serv_Lss.dbo_lss_Fee, DPR_DW.Latest_Serv_Lss.dbo_lss_FeeOperation, DPR_DW.Latest_Serv_Lss.dbo_lss_LoanAccount, DPR_DW.Latest_Serv_Lss.dbo_lss_LoanSegment, DPR_DW.Latest_Serv_Lss.dbo_lss_LssTransaction, TML_DW.bml.tbl_BMLSummitTransactions, TML_DW.bml.tbl_LegacyScheduledPayment, TML_DW.dbo.cte_FeeAmount, TML_DW.dbo.cte_FeeOperations, TML_DW.dbo.cte_Fees, TML_DW.dbo.fn_AccountDailySnapshot, TML_DW.dbo.fn_AccountMonthlySchedule, TML_DW.dbo.fn_Transactions, TML_DW.dbo.log_StoredProcedureRuns, TML_DW.dbo.tbl_AccountMonthlySummary, TML_DW.dbo.tbl_Applications, TML_DW.dbo.tbl_ArrearsDaily, TML_DW.dbo.tbl_DailyCheck, TML_DW.dbo.tbl_HomePriceIndex, TML_DW.dbo.tbl_PropertyDetails, TML_DW.dbo.tbl_Securitisations, TML_DW.dbo.tbl_SecuritisedPool, TML_DW.dbo.tbl_ServicingPools, TML_DW.dbo.tbl_SystemCalendar
--   Procs:     TML_DW.dbo.sp_Insert_ErrorLog
--   Views:     (none)
--   Functions: TML_DW.dbo.fn_AccountDailySnapshot, TML_DW.dbo.fn_AccountMonthlySchedule, TML_DW.dbo.fn_Transactions
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
-- Name:	sp_PopulateMonthlySummary
-- Info:	populates the account summary table with common monthly reporting data
-- *******************************************************************************************************************
-- ChangeNo	Developer		Date			JIRA	Detail
-- 
-- 001			N Sharkie		2022-02-24				Created
-- 002			N Sharkie		2022-03-10				Added Reverted Flag
-- 003			N Sharkie		2022-03-25				Added Filter for excluding origination accounts that were returned funds
-- 004			N Sharkie		2022-03-29				Removed chnage #3 and applied environment logic and change to filter on sec sub query
-- 005			N Sharkie		2022-04-19				Added code to remove returned funds with invalid dates
-- 006			N Sharkie		2022-07-07				Added default collation to account number in monthSumm table definition
-- 007			N Sharkie		2022-08-01				removed loan segment id from erc temp as not needed and caused ssue with part by part account
-- 008			R Callan		2022-08-03				Added new Fees column to be used in the Servicing report.  Added to the #Payment table and to
-- 													final temp table.
-- 009			N Sharkie		2022-08-16				Added in SUM on fees in payments query in case more than one in month
-- 010			N Sharkie		2023-08-09				Added ServicingPool column to the output
-- 011			N Sharkie		2023-08-25				Change to Securitisation sub query and columns
-- 012			N SHarkie		2023-08-31				Added Product Code to the output
-- 013			R Callan		2023-10-12				Update the temp table #monthSummm updated the column ServicingPool to have
-- 													varchar(100) instead of varch(20).
-- 014			M Lee			2023-12-21				Added Repayment Type
-- 015			M Lee			2024-07-17				Added CIShareValue and CIShareLTV
-- 016         K Seshasayee    2024-11-13		11040	Arrears Ratio and Arrears Balance added
-- 017			H Rielly		2024-11-29		12296	Add OriginationSource column
-- 018			R Callan		2024-12-11		9838	Change the following joins to allow BML Data to come in to have if statement added
-- 													so instead of just ApplicationRef, depending on the OriginationSource it will use
-- 													ApplicationRef or AccountNo
-- 													TML_DW.dbo.tbl_Applications app ON  bal.AccountNo = IIF(app.OriginationSource = 'TML',app.ApplicationRef, app.AccountNo)
-- 													DPR_DW.dbo.DIM_CO_Account dacc ON IIF(app.OriginationSource = 'TML',app.ApplicationRef, app.AccountNo)
-- 019			R Callan		2025-01-16				Updated for BML to amend CIShareLTV to have NULLIF around PurchasePrice and CILTV to have NULLIF around valuation
-- 020			R Callan		2025-02-05		9838	Updated join to tbl_ServicingPools to have new condition of loantype added
-- 021			R Callan		2025-02-18		9838	Updated the securitisations join to eiter user applicationRef or AccountNo depending on OriginationSource
-- 022			M Lee			2025-04-10		9838	Amended initial schedule table creation and added conditional insert for missing BML schedules for the month of migration.
-- 023			N Sharkie		2025-04-16		16396	changed to use transactions function, added transactions from static BML historic table, BML daliy arrers changed to use daily figures
-- 024			M Lee			2025-06-06		17291	Removed joins to ReportedDailyArrearsBalance synonym for BML arrears figures, changed back to use tbl_ArrearsDaily for both brands
-- 025			N Sharkie		2025-09-30		19996	Updte to BML overpayments logic. Obly iverpayt if paying more than scheduled and last monthls arrears balance
-- 026			N Sharkie		2026-02-16		22674	Align TML overpyments with BML and remove double count of last months arrears on overpayment total for closed accounts
-- 
-- *******************************************************************************************************************
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
		  , CONCAT('@updateType = ', + @updateType)
		  , @runTime);

---------------------------------------------------------------------------------------------------
-- QUERY SECTION
---------------------------------------------------------------------------------------------------
----------------------------------------------------------------------
/*
	INTERNAL
*/
DECLARE @date DATE;
DECLARE @yest DATE;
DECLARE @endDate DATE;
DECLARE @startDate DATE;

DECLARE @startDateId INT;
DECLARE @endDateId INT;
DECLARE @lastMonthEnd DATE

SET @updateType = ISNULL(@updateType, 1);

SET @yest = DATEADD(d, -1, GETDATE());
SET @endDate = EOMONTH(@yest);
SET @startDate = IIF(@updateType = 1, DATEADD(m, -1, DATEADD(d, 1, @endDate)), '2016-09-01'); -- 1 current month, 2 = all time
SET @lastMonthEnd = DATEADD(d, -1, @startDate)

--PRINT @startDate;
--PRINT @endDate;

SET @startDateId = CONVERT(INT, FORMAT(@startDate, 'yyyyMMdd'));
SET @endDateId = CONVERT(INT, FORMAT(@endDate, 'yyyyMMdd'));


------------------------------------------------------
------------------------------------------------------
-- DROP TABLES

IF OBJECT_ID('tempdb..#monthSumm') IS NOT NULL
DROP TABLE #monthSumm;

IF OBJECT_ID('tempdb..#months') IS NOT NULL
DROP TABLE #months;

IF OBJECT_ID('tempdb..#sched') IS NOT NULL
DROP TABLE #sched;

IF OBJECT_ID('tempdb..#erc') IS NOT NULL
DROP TABLE #erc;

IF OBJECT_ID('tempdb..#trans') IS NOT NULL
DROP TABLE #trans;

------------------------------------------------------
------------------------------------------------------
-- cretae summary table 

CREATE TABLE #monthSumm 
(	
	MonthEnd DATE NOT NULL
	, COBID INT NOT NULL
	, Environment VARCHAR(20) NOT NULL
	, AccountNo VARCHAR(20) COLLATE DATABASE_DEFAULT NOT NULL
	, LoanType VARCHAR(20) NOT NULL
	, MonthNo INT NULL
	, CurrentBalance DECIMAL(20,2) NULL DEFAULT 0
	, PrincipalBalance DECIMAL(20,2) NULL DEFAULT 0
	, RetentionAmount DECIMAL(20,2) NULL DEFAULT 0
	, RevertedFlag INT NULL DEFAULT 0
	, BaseRateCode VARCHAR(20) NULL
	, InterestRate DECIMAL(6,2) NULL
	, CIValSetBy VARCHAR(20) NULL
	, CIValuation DECIMAL(20,2) NULL
	, CILTV DECIMAL(10,4) NULL
	, Securitised INT NULL
	, SecuritisationTag VARCHAR(50) NULL
	, SecuritisedDate DATE NULL
	, SecuritisationName VARCHAR(100) NULL
	, SecuritisationStatus VARCHAR(50) NULL
	, SecuritisationFlag VARCHAR(5) NULL
	, ScheduledPayment DECIMAL(20,2) NULL 
	, PaymentsMade DECIMAL(20,2) NULL 
	, Overpayment DECIMAL(20,2) NULL
	, ERCPayment  DECIMAL(20,2) NULL DEFAULT 0
	, Fees decimal(20,2) null default 0
	, ServicingPool varchar(100) NULL
	, ProductCode VARCHAR(250) NULL -- UA3 ONLY
	, RepaymentType VARCHAR(20)
	, CIShareValue DECIMAL(20,2) NULL
	, CIShareLTV DECIMAL(10,4) NULL
	, ArrearsRatio DECIMAL(10,2) NULL
	, ArrearsBalance DECIMAL(10,2) NULL
	, CONSTRAINT PK_AMS PRIMARY KEY(MonthEnd, AccountNo)
	, OriginationSource VARCHAR(3)
);


------------------------------------------------------
------------------------------------------------------
-- Months Table

SELECT MonthEnd = Date
, MonthNo = ROW_NUMBER() OVER(ORDER BY DATE)
INTO #months
FROM dbo.tbl_SystemCalendar sc
WHERE Date BETWEEN @startDate AND EOMONTH(@endDate)
AND Date = sc.MonthEnd;

------------------------------------------------------
------------------------------------------------------
/*
	Create payment Schedule Table
*/

--Need to create temp table so can declare servicing pool as nullable. Servicing Pool is used later but from a different function.
--Creating by selecting into it from the monthly schedule function makes it a not null column which won't work for our temporary BML April fix
CREATE TABLE #sched 
(	
AccountNo VARCHAR(10) NOT NULL,
PaymentMonth DATE NULL,
ScheduledPayment DECIMAL(38,2) NULL,
ServicingPool VARCHAR(255) NULL,
PaymentNo BIGINT NULL
);

INSERT INTO #sched
(
AccountNo, PaymentMonth, ScheduledPayment, ServicingPool, PaymentNo
)
SELECT 
AccountNo, PaymentMonth, ScheduledPayment, ServicingPool, PaymentNo
FROM dbo.fn_AccountMonthlySchedule(NULL, NULL) 
WHERE 1=1
AND PaymentMonth BETWEEN @startDate AND @endDate;


--If running April 2025 or an all time, we need to grab the missing scheduled payments from legacy table
IF (@startDate = '2025-04-01' AND @endDate = '2025-04-30') OR @updateType =2
BEGIN
	INSERT INTO #sched
	(
	AccountNo, PaymentMonth, ScheduledPayment, ServicingPool, PaymentNo
	)
	SELECT 
	LSP.AccountNumber, '2025-04-30',LSP.FinalCurrentDueAmount, NULL, NULL
	FROM bml.tbl_LegacyScheduledPayment LSP
	LEFT JOIN #sched sched ON LSP.AccountNumber = sched.AccountNo COLLATE DATABASE_DEFAULT
	WHERE sched.AccountNo IS NULL
END

CREATE CLUSTERED INDEX IDX_PaySched ON #sched(PaymentMonth, AccountNo);

------------------------------------------------------
------------------------------------------------------
/*
	Create CTE Fees Table
*/
WITH cte_Fees 
AS (
	SELECT
	FeeId = Id
	, LoanSegmentId
	, ProcessId
	, FeeOpaque
	, ChargedAmount = InitialAmount
	, ChargedDate
	FROM DPR_DW.Latest_Serv_Lss.dbo_lss_Fee
	WHERE FeeOpaque LIKE '%ERC%'
	AND CONVERT(DATE, ChargedDate) BETWEEN @startDate AND @endDate
),
cte_FeeOperations 
AS (
	SELECT *
	FROM 
	(
		SELECT feeOp.FeeId, Amount
		, FeeOperationType = CASE FeeOperationType
								WHEN 0 THEN 'ReversedAmount'
								WHEN 1 THEN 'WaivedAmount'
								WHEN 2 THEN 'WaivedReversedAmount'
							END 
		FROM DPR_DW.Latest_Serv_Lss.dbo_lss_FeeOperation feeOp
		INNER JOIN DPR_DW.Latest_Serv_Lss.dbo_lss_Fee fee ON feeOp.FeeId = fee.Id
		LEFT JOIN DPR_DW.Latest_Serv_Lss.dbo_lss_LssTransaction trxOp ON feeOp.TransactionId = trxOp.Id
	) AS Operations
	PIVOT
	(
		SUM(Amount)
		FOR FeeOperationType IN ([ReversedAmount], [WaivedAmount], [WaivedReversedAmount])
	) AS one
)
,
cte_FeeAmount 
AS (
	SELECT a.LoanSegmentId, a.ProcessId, a.FeeOpaque, a.ChargedDate
	, Amount = CONVERT(DECIMAL(20,2), a.ChargedAmount-(ISNULL(b.ReversedAmount,0)+ISNULL(b.WaivedAmount,0)+ISNULL(b.WaivedReversedAmount,0)))
	FROM cte_Fees a
	LEFT OUTER JOIN cte_FeeOperations b ON a.FeeId = b.FeeId
)
SELECT AccountNo =  a.LoanAccountNo
, PaymentMonth = EOMONTH(f.ChargedDate)
, ERCAmount = SUM(ISNULL(f.Amount, 0))
INTO #erc
FROM cte_FeeAmount f
INNER JOIN DPR_DW.Latest_Serv_Lss.dbo_lss_LoanSegment s ON f.LoanSegmentID = s.ID
INNER JOIN DPR_DW.Latest_Serv_Lss.dbo_lss_LoanAccount a ON s.LoanAccountID = a.ID
GROUP BY a.LoanAccountNo, EOMONTH(f.ChargedDate);

------------------------------------------------------
------------------------------------------------------
 -- TRANSACTIONS
/*
5000:	Direct Debit Payment
-5000:  Direct Debit Reveresed
5015:	2nd Direct Debit Payment Attempt
-5015:  2nd Direct Debit Payment Attempt Reversed
5010:   Bank Transfer Payment
-5010:  Bank Transfer Payment
5045:   Standing Order
11001:  Unallocated Funds stored for furure alllocation
5040:   Redemption Payment
-5040:  Redemption Payment reversed
-1000   Servicing Fee (exit) -- not counting
2005    not counting -- not counting
- 1020 ERC
*/

-- combine from transactions - TML and BML post migration and BOSS historic - BML pre migration
CREATE TABLE #trans (
	AccountNo VARCHAR(20) COLLATE DATABASE_DEFAULT
	, TransactionDate DATE
	, MonthEnd DATE 
	, Amount DECIMAL(20,2)
	, Payment DECIMAL(20,2)
	, TransactionType VARCHAR(20)
);

-- insert TML and BML after migration
INSERT INTO #trans (
			AccountNo, TransactionDate, MonthEnd, Amount, Payment, TransactionType
)
SELECT AccountNo, TransactionDate
, MonthEnd = EOMONTH(TransactionDate)
, Amount = -tr.Amount
, Payment = IIF(
				tr.TransactionType IN (5000, -5000, 5015, -5015, 5010, -5010, 5045, -1000, -1020, 1020, 5040, -5040, 5005, -5005)
				, CONVERT(DECIMAL(30,2), -tr.Amount)
				, 0
			)
, TransactionType = CONVERT(VARCHAR(20), TransactionType)
FROM dbo.fn_Transactions(@startDateId, @endDateId) tr
WHERE TransactionType NOT IN (2005, -2005)

-- insert pre migration BML
INSERT INTO #trans (
			AccountNo, TransactionDate, MonthEnd, Amount, Payment, TransactionType
)
SELECT AccountNo = AccountNumber
, TransactionDate = EffectiveDateID
, MonthEnd = EOMONTH(EffectiveDateID)
, Amount = -Amount
, Payment = -Amount
, TransactionType = SourceTransactionTypeID
FROM bml.tbl_BMLSummitTransactions
WHERE IsCash = 1
AND EffectiveDateID BETWEEN @startDate AND @endDate;

------------------------------------------------------
------------------------------------------------------
-- PAYMENTS MADE

IF OBJECT_ID('tempdb..#payments') IS NOT NULL
DROP TABLE #payments;


SELECT TOP (100) PERCENT 
AccountNo = ISNULL(ms.AccountNo, p.AccountNo)
, LoanType = ISNULL(p.LoanType, a.LoanType)
, AccountOpenDate = ISNULL(p.AccountOpenDate, a.AccountOpenDate)
, MonthEnd = ISNULL(ms.PaymentMonth, p.MonthEnd)
, PaymentsMade = ISNULL(p.PaymentsMade, 0)
, ScheduledPayment = ISNULL(ms.ScheduledPayment, 0)
, ERCPayment = ISNULL(p.ERCPayment, 0) 
, MonthNo = DATEDIFF(m, EOMONTH(ISNULL(p.AccountOpenDate, a.AccountOpenDate)), ISNULL(ms.PaymentMonth, p.MonthEnd)) 
, Fees = ISNULL(fees.Fees, 0)
, LastMonthArrears = ISNULL(lm.ArrearsBalance, 0)
, OverpayDeduction = ISNULL(p.ERCPayment, 0) + ISNULL(fees.Fees, 0) + ISNULL(lm.ArrearsBalance, 0)
INTO #payments
FROM #sched ms 
INNER JOIN dbo.tbl_Applications a ON ms.AccountNo = a.AccountNo COLLATE DATABASE_DEFAULT
FULL OUTER JOIN (
	SELECT t.AccountNo, a.LoanType, a.AccountOpenDate, t.MonthEnd
	, PaymentsMade = SUM(t.Payment)
	, PaymentCount = COUNT(t.Payment)
	, ERCPayment = e.ERCAmount
	, a.AccountClosedDate
	FROM #trans t
	INNER JOIN TML_DW.dbo.tbl_Applications a ON t.AccountNo = ISNULL(a.AccountNo, a.ApplicationRef) COLLATE DATABASE_DEFAULT
												--AND trans.MonthEnd <= CONVERT(DATE, ISNULL(a.AccountClosedDate, '9999-12-31')) -- exclude dates after redemption / account closed
	LEFT OUTER JOIN #erc e ON t.AccountNo = e.AccountNo
								AND t.MonthEnd = e.PaymentMonth
	GROUP BY t.AccountNo, a.LoanType, a.AccountOpenDate, t.MonthEnd, a.AccountClosedDate
		, e.ERCAmount
) p
	ON ms.AccountNo = p.AccountNo COLLATE DATABASE_DEFAULT
		AND ms.PaymentMonth = p.MonthEnd

LEFT OUTER JOIN (
	SELECT MonthEnd, AccountNo, Fees = ABS(SUM(Amount))	
	FROM  #trans 
	WHERE TransactionType = '-1000'
	GROUP BY MonthEnd, AccountNo
) fees
	ON ms.AccountNo = fees.AccountNo COLLATE DATABASE_DEFAULT
		AND ms.PaymentMonth = fees.MonthEnd
LEFT OUTER JOIN dbo.tbl_AccountMonthlySummary lm ON ISNULL(ms.AccountNo, p.AccountNo) = lm.AccountNo COLLATE DATABASE_DEFAULT
													AND lm.MonthEnd = @lastMonthEnd
ORDER BY ISNULL(ms.PaymentMonth, p.MonthEnd) DESC, ms.AccountNo;

------------------------------------------------------
------------------------------------------------------
-- GET MONTHLY BALANCES

DECLARE @monthEnd DATE;
DECLARE @lastDayInMonth DATE;
DECLARE @monthNo INT = 1;
DECLARE @endloop INT; 
DECLARE @cobID INT;

SELECT @endloop = MAX(MonthNo)
FROM #months m;

WHILE @monthNo <= @endloop 
BEGIN
	SELECT @monthEnd = MonthEnd
	, @lastDayInMonth = IIF(MonthEnd <= @yest, MonthEnd, @yest)
	FROM #months 
	WHERE MonthNo = @monthNo;
	
	SET @cobid = CAST(FORMAT(@lastDayInMonth,'yyyyMMdd') as int);

	INSERT INTO #monthSumm(MonthEnd, COBID, Environment, AccountNo, LoanType, MonthNo, CurrentBalance, PrincipalBalance, RetentionAmount, RevertedFlag, BaseRateCode
							,InterestRate, CIValSetBy, CIValuation, CILTV, Securitised, SecuritisationTag, SecuritisedDate, SecuritisationName, SecuritisationStatus
							, SecuritisationFlag, ScheduledPayment, PaymentsMade, Overpayment, ERCPayment, Fees, ServicingPool, ProductCode, RepaymentType
							, CIShareValue, CIShareLTV, ArrearsRatio, ArrearsBalance, OriginationSource)
	SELECT MonthEnd = @lastDayInMonth 
	, COBID = CAST(FORMAT(@lastDayInMonth,'yyyyMMdd') as int) 
	, Environment = CASE 
					WHEN CAST(FORMAT(app.RecompletionDate,'yyyyMMdd') as int) <= @cobid THEN 'Servicing'
					WHEN CAST(FORMAT(app.CompDate,'yyyyMMdd') as int) <= @cobid AND CAST(FORMAT(app.FeesReturnedDate,'yyyyMMdd') as int) <= @cobID THEN 'Origination'
					WHEN CAST(FORMAT(app.CompDate,'yyyyMMdd') as int) <= @cobid  AND (CAST(FORMAT(app.RecompletionDate,'yyyyMMdd') as int) > @cobID OR app.RecompletionDate IS NULL) THEN 'Servicing'
					ELSE 'Origination'
				END
	, bal.AccountNo
	, LoanType = ISNULL(sp.LoanType, app.LoanType)
	, MonthNo = DATEDIFF(m, EOMONTH(app.AccountOpenDate), @monthEnd) 
	, bal.CurrentBalance, bal.PrincipalBalance, bal.RetentionAmount
	, RevertedFlag = IIF(app.ReversionDate <= @lastDayInMonth, 1, 0)
	, bal.BaseRateCode, bal.InterestRate
	, CIValSetBy = IIF(app.ValuationHPI IS NULL, 'Valuation', 'HPI')
	, CIValuation = IIF(
						app.ValuationHPI IS NULL
						, CONVERT(DECIMAL(20,2), NULLIF(app.Valuation, 0))
						, CONVERT(DECIMAL(20,2), app.Valuation / app.ValuationHPI * COALESCE(hpiRecent.HPI, app.ValuationHPI))
					)
	, CILTV = IIF( CAST(FORMAT(app.AccountClosedDate,'yyyyMMdd') as int) <= @cobid
						, 0
						, CONVERT(DECIMAL(20,4)
									 ,IIF(
										  app.ValuationHPI IS NULL 
										  , IIF(app.LoanType = 'Residential', bal.PrincipalBalance, bal.CurrentBalance) / NULLIF(app.Valuation, 0)
										  , IIF(app.LoanType = 'Residential', bal.PrincipalBalance, bal.CurrentBalance) / (app.Valuation / app.ValuationHPI * COALESCE(hpiRecent.HPI, app.ValuationHPI))
										 )
									 )
					)
	-- SECURITISATION INFO			
	, Securitised = ISNULL(secs.Securitised, 0)
	, SecuritisationTag = ISNULL(secs.SecuritisationTag, 'Balance Sheet')
	, SecuritisedDate = IIF(secs.Securitised = 1, secs.SecuritisedDate, NULL)
	, secs.SecuritisationName 
	, SecuritisationStatus = ISNULL(secs.SecuritisationStatus, 'Balance Sheet')						  
	, SecuritisationFlag = ISNULL(secs.SecuritisationFlag, 'BS')
	
	, ScheduledPayment = ISNULL(p.ScheduledPayment, 0)
	, PaymentsMade = ISNULL(p.PaymentsMade, 0)
	, Overpayment = IIF(
						p.PaymentsMade > (ISNULL(p.ScheduledPayment, 0) + p.OverpayDeduction - IIF(ISNULL(bal.CurrentBalance, 0) = 0, ISNULL(p.LastMonthArrears, 0), 0))  
						, p.PaymentsMade - (ISNULL(p.ScheduledPayment, 0) + p.OverpayDeduction - IIF(ISNULL(bal.CurrentBalance, 0) = 0, ISNULL(p.LastMonthArrears, 0), 0))  
						, 0
					)
	, ERCPayment = ISNULL(p.ERCPayment, 0)
	, Fees = isnull(p.Fees,0)
	, bal.ServicingPool
	, app.ProductCode
	, app.RepaymentType
	, CIShareValue = IIF(
					app.ValuationHPI IS NULL
					, CONVERT(DECIMAL(20,2), NULLIF(pt.PurchasePrice, 0))
					, CONVERT(DECIMAL(20,2), pt.PurchasePrice / app.ValuationHPI * COALESCE(hpiRecent.HPI, app.ValuationHPI))
					)
	, CIShareLTV = IIF( CAST(FORMAT(app.AccountClosedDate,'yyyyMMdd') AS INT) <= @cobid
						, 0
						, CONVERT(DECIMAL(20,4)
								, IIF(app.ValuationHPI IS NULL 
									, IIF(app.LoanType = 'Residential', bal.PrincipalBalance, bal.CurrentBalance) / NULLIF(pt.PurchasePrice, 0)
									, IIF(app.LoanType = 'Residential', bal.PrincipalBalance, bal.CurrentBalance) / ( NULLIF(pt.PurchasePrice, 0)  / app.ValuationHPI * COALESCE(hpiRecent.HPI, app.ValuationHPI))
									 )
								 )
					  )
	, ArrearsRatio = arr.TrueArrearsRatio
	, ArrearsBalance = arr.TrueArrearsBalance
	, app.OriginationSource
	FROM TML_DW.dbo.fn_AccountDailySnapshot(@cobID,NULL) bal
	INNER JOIN TML_DW.dbo.tbl_Applications app ON  bal.AccountNo = IIF(app.OriginationSource = 'TML',app.ApplicationRef, app.AccountNo)
	LEFT OUTER JOIN dbo.tbl_PropertyDetails pt ON pt.ApplicationRef = app.ApplicationRef
	LEFT OUTER JOIN #payments p ON bal.AccountNo = p.AccountNo COLLATE DATABASE_DEFAULT
								AND p.MonthEnd = @monthEnd
	
	LEFT OUTER JOIN DPR_DW.dbo.DIM_CO_Account dacc ON IIF(app.OriginationSource = 'TML',app.ApplicationRef, app.AccountNo) = dacc.AccountNo COLLATE DATABASE_DEFAULT
														AND @cobid > dacc.SCDStartDate
														AND @cobid <= dacc.SCDEndDate

	LEFT OUTER JOIN dbo.tbl_ServicingPools sp ON dacc.DIM_CO_ServicingPool_DWSK = sp.DIM_CO_ServicingPool_DWSK 
													AND dacc.LoanType = sp.DPRLoanType COLLATE DATABASE_DEFAULT

	-- securitisaton details - use row number to get latest as this is for cob yesterday. Faster than using dates bewtween
	LEFT OUTER JOIN (
		SELECT sp.AccountNo, s.Securitised, sp.SecuritisationStatus, s.SecuritisationFlag, s.SecuritisationName, s.SecuritisationTag
		, s.SecuritisationID
		, SecuritisedDate = CONVERT(DATE, CONVERT(VARCHAR(10), sp.SecuritisedDate))
		, LatestOrder = ROW_NUMBER() OVER (PARTITION BY sp.AccountNo ORDER BY sp.SecuritisedDate DESC)
		FROM TML_DW.dbo.tbl_SecuritisedPool sp
		INNER JOIN TML_DW.dbo.tbl_Securitisations s ON sp.SecuritisationId = s.SecuritisationID
		WHERE sp.TransferOutDate > CONVERT(DATE, CONVERT(VARCHAR(10), @cobid)) 
	) secs	
		ON IIF(app.OriginationSource = 'TML',app.ApplicationRef, app.AccountNo) = secs.AccountNo
			AND secs.LatestOrder = 1

	-- most recent index valuation
    LEFT OUTER JOIN TML_DW..tbl_HomePriceIndex hpiRecent ON DATEPART(q, DATEADD(m, -3, CONVERT(DATE, CONVERT(VARCHAR(10),@cobid)))) = hpiRecent.Quarter
														 AND DATEPART(yyyy, DATEADD(m, -3, CONVERT(DATE, CONVERT(VARCHAR(10),@cobid)))) = hpiRecent.Year
														 AND app.Region = RTRIM(REPLACE(REPLACE(hpiRecent.Region, CHAR(13), ''), CHAR(10), '')) COLLATE DATABASE_DEFAULT

	-- get TML arrears from daily table															
	LEFT JOIN dbo.tbl_ArrearsDaily arr ON arr.AccountNo = app.AccountNo AND arr.COBID = @cobid --app.COBID

	WHERE app.Environment = 'Servicing'; -- stops returned funds that haven't recompleted

	-- move to the next month
	SET @monthNo = @monthNo + 1;
END;

-- now delete fron the live table if it is in the build 
DELETE l
FROM TML_DW.dbo.tbl_AccountMonthlySummary l
INNER JOIN #monthSumm b ON l.AccountNo = b.AccountNo
							AND EOMONTH(l.MonthEnd) = EOMONTH(b.MonthEnd)	
WHERE l.MonthEnd IS NOT NULL;


-- delete any ivalid entries - change #005
DELETE TML_DW..tbl_AccountMonthlySummary 
WHERE MonthEnd NOT IN (
						SELECT Date
						FROM dbo.tbl_SystemCalendar sc
						WHERE (sc.LastDayOfMonth = 'Y' AND Date < GETDATE())
						OR Date = CONVERT(DATE, DATEADD(d, -1, GETDATE()))	
					)

-- now add the build table to the live table
INSERT INTO TML_DW.dbo.tbl_AccountMonthlySummary (MonthEnd, COBID, AccountNo, LoanType, MonthNo
												, CurrentBalance, PrincipalBalance, RetentionAmount, RevertedFlag, BaseRateCode
												, InterestRate, CIValSetBy, CIValuation, CILTV, Securitised, SecuritisationTag, SecuritisedDate, SecuritisationName
												, SecuritisationStatus, SecuritisationFlag, ScheduledPayment, PaymentsMade, Overpayment, ERCPayment, Fees, ServicingPool, ProductCode, RepaymentType
												, CIShareValue, CIShareLTV, ArrearsRatio, ArrearsBalance, OriginationSource
												)
SELECT MonthEnd, COBID, AccountNo, LoanType, MonthNo, CurrentBalance, PrincipalBalance, RetentionAmount, RevertedFlag, BaseRateCode
     , InterestRate, CIValSetBy, CIValuation, CILTV, Securitised, SecuritisationTag, SecuritisedDate, SecuritisationName
     , SecuritisationStatus, SecuritisationFlag, ScheduledPayment, PaymentsMade, Overpayment, ERCPayment, Fees, ServicingPool, ProductCode, RepaymentType
	 , CIShareValue, CIShareLTV, ArrearsRatio, ArrearsBalance, OriginationSource
FROM #monthSumm
WHERE Environment = 'Servicing' 
ORDER BY MonthEnd, AccountNo;

---------------------------------------------
-- update the daily checks table with the latest date

UPDATE TML_DW.dbo.tbl_DailyCheck 
SET LatestDate = @lastDayInMonth
WHERE TableName = 'TML_DW.dbo.tbl_AccountMonthlySummary';


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
