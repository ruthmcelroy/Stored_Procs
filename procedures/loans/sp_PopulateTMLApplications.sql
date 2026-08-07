USE TML_DW
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.sp_PopulateTMLApplications
AS
BEGIN

-- =============================================================================
-- Procedure:   sp_PopulateTMLApplications
-- Schema:      dbo
-- Database:    TML_DW
-- Purpose:     Populate the daily applications table.
-- Owner:       Data Engineering Team
-- Dependencies:
--   Tables:    DPR_DW.dbo.DIM_CO_Account, DPR_DW.dbo.DIM_CO_Advance, DPR_DW.dbo.DIM_CO_Application, DPR_DW.dbo.DIM_CO_GLEntryType, DPR_DW.dbo.DIM_CO_ProdSegm, DPR_DW.dbo.DIM_CO_Status, DPR_DW.dbo.FACT_CO_Application, DPR_DW.dbo.FACT_CO_DecisionHistoryTrx, DPR_DW.dbo.FACT_CO_GLEntryTrx, DPR_DW.dbo.FACT_CO_StatusTrx, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAApplication, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMADecisionHistory, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAFeaturesPackage, DPR_DW.Latest_Orig_BoM.dbo_morAppFMA_FMALoanDetails, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAProduct, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAProperty, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAPropertyDetail, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAPropertySummary, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAPropertySurveyDetails, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMASecurity, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMASecurityValuation, DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAStatus, DPR_DW.Latest_Serv_Lss.dbo_lss_Advance, DPR_DW.Latest_Serv_Lss.dbo_lss_LoanAccount, DPR_DW.Latest_Serv_Lss.dbo_lss_LoanSegment, TML_DW.dbo.app, TML_DW.dbo.dups, TML_DW.dbo.fn_AccountDailySnapshot, TML_DW.dbo.fn_DailyRates, TML_DW.dbo.log_StoredProcedureErrors, TML_DW.dbo.log_StoredProcedureRuns, TML_DW.dbo.tbl_AffordabilityLatest, TML_DW.dbo.tbl_Applicants, TML_DW.dbo.tbl_Applications, TML_DW.dbo.tbl_CostOfFunds, TML_DW.dbo.tbl_CreditRefLatest, TML_DW.dbo.tbl_DailyRates, TML_DW.dbo.tbl_DeadDates, TML_DW.dbo.tbl_ExcludeFromSecuritisation, TML_DW.dbo.tbl_ProductHistory, TML_DW.dbo.tbl_Products, TML_DW.dbo.tbl_PropertyDetails, TML_DW.dbo.tbl_ServicingPools
--   Procs:     TML_DW.dbo.sp_Insert_ErrorLog, TML_DW.dbo.sp_OverrideTableValues, TML_DW.dbo.sp_PopulateGYNIM
--   Views:     TML_DW.dbo.vw_AppFeeAnalysis, TML_DW.dbo.vw_BrokerExclusions, TML_DW.dbo.vw_MortgageType, TML_DW.dbo.vw_Valuations
--   Functions: TML_DW.dbo.fn_AccountDailySnapshot, TML_DW.dbo.fn_DailyRates, TML_DW.dbo.tbl_Applications
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
-- Name:		Populate Applications
-- Info:		Populate the daily applications table
-- *******************************************************************************************************************
-- ChangeNo		Developer		Date			JiraNo		Detail
-- 
-- 001			 N Sharkie		2017-11-03					Created
-- 002			 N Sharkie		2017-12-01					Changed to new table with only one recor1`1d per application.
-- 003			 N Sharkie		2018-04-11					Updated reversion rate calc. Put back in with same logic as app function
-- 004			 N Sharkie		2018-04-23					Added in exclusion for test applications
-- 005			 N Sharkie		2018-04-26					Changed logic on origination prod to resolve missing app int rates for fees returned cases after 100 days
-- 006			 N Sharkie		2018-05-08					Added in logging of end time
-- 007			 N Sharkie		2018-05-09					updated RN score filter for BTL
-- 008			 N Sharkie		2018-05-14					Added in Customer Type
-- 009			 N Sharkie		2018-05-16					Changed to use tbl_Applicants instead of vw_Applicants
-- 010			 N Sharkie		2018-05-30					Appliced fix for missing Offer Date on Manually typed offer.
-- 011			 N Sharkie		2018-05-31					Added in disable and renable of fereign key to Applicant portfolio table
-- 012			 N Sharkie		2018-06-01					nulled some servicing columns to deal with DPR redemption issue & Added RepaymentType
-- 013			 N Sharkie		2018-06-05					updated ValReceiveDate to deal with BTL valuation dates not using wizard
-- 014			 N Sharkie		2018-06-15					Added in product features and actual current Balance
-- 015			 K Cowie		2018-06-26					Updated OriginalGrossLTV to deal with 0 valuation
-- 016			 N Sharkie		2018-06-27					removed carriage returns and line feeds from oprod product description
-- 017			 N Sharkie		2018-07-13					updated LTV values for if Value <=1 then 0
-- 018			 N Sharkie		2018-07-18					Fix for DPR Issues applying Revert Rate to oprod BaseRate value
-- 019			 N Sharkie		2018-07-26					Updated Products to change All to Unknown
-- 020			 N Sharkie		2018-08-15					Removed link to vw_ArrrearsAppl
-- 021			 N Sharkie		2018-08-22					Updated revert rate logic to deal with new product max ltv value & Added RevertMargin column
-- 022			 N Sharkie		2018-08-28					moved to use synonyms instead of DIMCOProduct & tidied up oprod
-- 023			 N Sharkie		2018-09-10					added in ReversionDate column
-- 024			 K Cowie		2018-09-13					Added in an update for applications M001337557 and M001335430 as they are redeemed but not completed properly
-- 025			 N Sharkie		2018-09-13					Permanent fix to #24 temp hard code fix. Updated logic on Environment and Completion Date columns
-- 026			 N Sharkie		2019-02-07					Added in Is Regulated and APR columns
-- 027			 N Sharkie		2019-02-14					Added in grouping and sum of balances in sprod due to issue where Part & Part mortgage caused duplication
-- 028			 N Sharkie		2019-03-21					Added OpeningBaseRateMargin & fixed AccountOpenDate to match CompDate
-- 029			 N Sharkie		2019-04-11					Including Servicing Pool 3 (DWSK 20) for securitised loans and logic to identify
-- 030			 N Sharkie		2019-05-02					changed join to account table to be >=
-- 031			 N Sharkie		2019-05-24					changed ORigLTV to check number not greater than 100
-- 032			 K Cowie		2019-05-29					Changed CILTV to have NULLIF for 0 property value
-- 033			 N Sharkie		2019-06-05					Changed all LTV columns to null if FACT_CO value > 100
-- 034			 R Callan		2019-06-06					Changed synprod.ProductCode to synprod.ProductCategoryto bring back the full ProductTeir Name in stead of the truncated version of applications still to complete
-- 035			 N Sharkie		2019-09-12					Temp fix applied to hard code missing App Date until overrule table implemented.
-- 036			 N Sharkie		2019-09-12					Removed Temp fix replaced with call to override procedure & updated to use temp table to limit damage during build failures
-- 037			 N Sharkie		2019-11-01					Update to columns using property values to deal better with zero valuations
-- 038			 N Sharkie		2019-11-15					Using fn_ApplicationDaily snapshot to resolve balances issue on FACT_CO_ProdSegm
-- 039			 N Sharkie		2019-12-23					Updated joins to home price index table to cope with carriage returns in its region column
-- 040			 N Sharkie		2020-01-03					securitisation sub query and additional columns added
-- 041			 K Cowie		2020-02-26					Update to Valuation, OriginalLTV, OriginalGrossLTV, CILTV columns to use ImprovedValue if PropertyValue and PurchasePrice are both 0
-- 042			 N Sharkie		2020-02-28					Added filter to product features to exclude new version types
-- 043			 N Sharkie		2020-03-30					Changed source of valuations date as status history was missing some dates and fix to CILTV divide by 0
-- 044			 N Sharkie		2020-07-08					changed revert table for instances that have been overwritten from original
-- 045			 N Sharkie		2020-09-23					Updated secutitisation query for BTL and changes to securitisation flag logic and added in new servicing pools for it
-- 046			 N Sharkie		2020-09-24					Rewrite sections to improve performance - temp table with indexes added, duplications removed, Opening Interest Rate fixed
-- 047			 N Sharkie		2020-09-28					Update to securitisation query & columns. Retained are now not classed as securitised
-- 048			 R Callan		2020-10-19					Update to have new SecuritisationFlag column, to used in reports.
-- 049			 N Sharkie		2020-10-21					Update to prod fetaures. Now using new view to to exclude duplication caused by new versions
-- 050			 K Cowie		2020-12-08					Update to Revert Rate section and update to Reversion Rate, OpeningBaseRateMargin & AppBaseRate to use TBR as well as LIBOR
-- 051			 N Sharkie		2021-01-18					replace dacc with acc section to use synonyms instead of dim co table which had errors with loan term
-- 052			 N Sharkie		2021-01-21					update to acc to bring in repayment type. Previoualy only using origination type which mised 2Solves issue where accounts which change type after completion.
-- 053			 N Sharkie		2021-01-22					logic added to loan type to differentiate bewtween the different funders
-- 054			 R Callan		2021-02-08					Updated AppBaseRate, OpeningBaseRateMargin, ReversionRate to include new TML Base Rate for Shawbrook Residential (TBRRESI) update TBR to be TBRBTL
-- 055			 K Cowie		2021-06-16					added in pool 41 for Residential2 completions, logic added to NULL recompletion dates in the future
-- 056			 N Sharkie		2021-09-10					Update to securitisation data for new process and tables - query and columns updated
-- 057			 N Sharkie		2021-09-22					Added Servicing Pool for Lanebrook 21 & slight tweak to the securitisations columns and query following updates to underlying securitisation tables
-- 															changed source og of loan type tp the servicing pools tbale to allow switching
-- 058			 N Sharkie		2021-11-25					Changed logic on making Resi2 to look at Dip created date instead of submitted
-- 059			 N Sharkie		2022-01-12					Removed use of scalar value function on reverted rate and now using table function. Reduced run time by over 4 min
-- 060			 N Sharkie		2022-02-10					Updated account open date to use recompletion date.
-- 061			 R Callan		2021-02-16					Updated producttier to bring back the new Product codes for SB Residential RL1-1 ect...
-- 062			 N Sharkie		2022-02-24					Added check on transfer out date to secs sub query
-- 063			 N Sharkie		2022-03-25					Added Exclude From SecuritisationColumn
-- 064			 K Cowie		2022-05-23					Changed LIBOR to BBR column in fn_DailyRates for oprod data
-- 065			 N Sharkie		2022-10-20					Big re-write to reduce run time from 14 mint to 1 min, removing function calls on columns, using temp tables with indexes etc...
-- 066			 N Sharkie		2022-12-19					using daily account function for interest rate due to issues with FACT_CO table
-- 067			 N Sharkie		2022-01-11					Added distinct to scores temp to fix when credit report created at exact same time
-- 068			 N Sharkie		2023-03-15					Combined accs sub query and sprod tenp into new accs temp table -removing links to prodsegm & dropped score temp and changed source of scores to cred ref latest
-- 069			 R Callan		2023-03-02					Updated latesstatus to have an iif statement, ApplicationSubmitted  = Underwriter Assessement, New joins for AppDate and
-- 															PreFMASubmittedDate.  Appdate changed from app.AppDate to AppDate.AppDate AS AppDate
-- 															AppBaseRate, ValInstructDate, ReversionRate amended from app.AppDate to AppDate.AppDate
-- 070			 N Sharkie		2023-03-27					Moved all dates into inital apps subquery
-- 071			 K Cowie		2023-04-20					Update to FirstOfferDate, new join for offers using synonyms and old join renamed to LatestOffers
-- 072			 K Cowie		2023-05-10					Update to Environment and LatestStatus for auto completing process
-- 073			 N Sharkie		2023-05-11					rearrange the apps dates and update to make sure app date is always populated
-- 074			 R Callan		2023-05-22					Update to the Dead Date logic as all cancelled/Declined applications before the Finvoa Upgrade as set to 2023-05-06
-- 															Changes made where clause to remove test case from the upgrade added to temp table #dimcoApps
-- 															New temp tables for the Expired and Cancelled applications added along with insert statements
-- 															#DeadTBL temp table added to put back deaddates pre-upgrade
-- 															#Final temp table added to pull data together and replace any dates with dates in #DeadTBL should these not match
-- 															#DeadDates added and #Final and to #DeadTBL to bring back two missing records due to two applicaitons as no
-- 															Decision History wizard has been run on the them.
-- 															Old join or dead removed and replaced with join to #DeadDates
-- 075			R Ronald		2023-07-14					Added in disable of foreign key to Product History table
-- 076			R Ronald		2023-07-25					Added in re-enable of foreign key to product history table
-- 077			R Ronald		2023-08-29					Updates for PT Cases - ProductCode to most recent product code, added in PTDate, update reversion date calculation
-- 															for PT cases and fixed term taken from most recent product
-- 078			R Ronald		2023-08-31					Update to Product Transfers temp table logic to take most recent version if before reportdate
-- 079			R Ronald		2023-11-02					Updates so PT date will populate on the PTDate rather than day after and excluding any loan mods from product history table which aren't PTs
-- 080			R Ronald		2023-11-08					Added in offer expiry date
-- 081			R Callan		2023-11-17					Added new temp table for the Valuations (#vals) view to fix the issue of missing valuation instruction dates. The view has bee
-- 															used to join to the temp table #dimcoApps.  ValInstructDate has been updated have the same logic as AppDate to bring
-- 															back the missing dates and an ISNULL to #vals view to bring back any that are missing.
-- 082			R Ronald		2023-12-19					Added changetype = Product Transfer to product transfer join as repayment type changes on PT accounts causing PT details to drop off
-- 083			G Thirupathi	2023-12-29					To handle cases when environment = origination and latest stuats = completed
-- 084			N Sharkie		2023-05-11					additional update to previous change to set latest status to not completed for cases in this situation
-- 085			M Lee			2024-01-19					Added an InitialValDate to the select for latest Dim Co application. Joined by app ref through synonyms to the security valuations tbl.
-- 															Added same into the create apps table section and the final insert into.
-- 086			M Lee			2024-01-22					Changed InitialValDate join to obtain the inspection date of the valuation. Added same into the create apps table section and the final insert into.
-- 087			N Sharkie		2024-02-13					Fix issue caused by pipeline product transfers, now excluded. build elig app pool and use this to filter others, Fix applied to deal with blank RiskScheme
-- 088			R Ronald		2024-02-13					Updated #oprod temp table to remove WHERE prod.variantcode <> '' AND a.ApplicationRef IS NULL to fix issue with products not populating
-- 089			G Thirupathi	2024-03-26					Added the IsSaleAdvised column on 05/01/2024 (Line Nos. 901–904, 1190–1207) per request from Malcom Carse. (For auditing purposes, it was added on the fifth,
-- 															but Neil brought in the earlier version of the applications table on the 13th to make some fixes because of some problems with the PopulateApplications Script.
-- 															The column was added to the tbl_Applications, but the script did not include the changes I made.)
-- 															As requested by Tom and as part of the Forecasting report preparation, two new columns have been added: GrossYield and NIM (Net Interest Margin)
-- 															As requested by Neil, the PTDate column has bean moved after the ReversionDate
-- 090			R Callan		2024-04-09					Updated to improve performance for Azure.   Temp table added for vw_BrokerExclusions #brexcl, join on the #appPool changed from the
-- 															view to the new temp table.
-- 															#appPool and #vals updated from select * to pull back all the column names instead.
-- 															#vals innerjoin to #appPool has been removed. replaced with a delete statement to only return the valuations
-- 															which are present in the temp table #appPool, does the same job as the inner join that was removed.
-- 091			G Thirupathi	2024-04-08					Moved the GY & NIM calcs after the tbl_applications is recreated to avoid the GY column being zero and and NIM being negative
-- 															as the vw_AppFeeAnalysis is based on the tbl_applications
-- 092			M Lee			2024-04-17					Added additional logic into final build into applications table around loantype logic. Covers split pool PT's defaulting back to loantype = Residential
-- 															which would incorrectly remove them from SB data feed.
-- 093			K Seshasayee	2024-06-05					Product Tier code updated to accomodate 'Standard v3' Product Category
-- 094			M Lee			2024-06-19					Amendments to OriginalLTV and OriginalGrossLTV for shared ownership
-- 095			R Callan		2024-07-01					Product Transfer updated to reslove issue wher PT Account has PT'd more than once.  New temp tables fpr pt3 and pt4 have been added to reslove
-- 															the issued of the wrong details being brought in.
-- 096			K Seshasayee	2024-07-02					Where clause for Application Date updated to prevent app dates / assessment dates being recorded as today's date / causing differences with balances in tables like strats
-- 097			M Lee			2024-07-17					Added columns for Share LTV's, CIShareValue and CI Share LTV
-- 098			G Thirupathi	2024-07-26					Product Feature fix for 'Residential £O up front fees' products
-- 099			R Callan		2024-12-02		14782		Updated the final select to have a new column for Funder.  TML funder set as Residentail = 24AM and rest is Shawbrook.  Done in
-- 															preperation for BML.   Will be amended when BML data comes in.
-- 099			H Rielly		2024-09-25		12296		Updated to include Originator Source Column
-- 100			R Callan		2025-02-05		9838		Updated join to tbl_ServicingPools to have new condition of loantype added
-- 101			N Sharkie		2025-03-13		15888		Added logic to fill in the new reports to SB Column and moved funder pop to build and not final populate.
-- 102			M Lee			2025-06-26		17970		Added FullyPackagedDate logic
-- 103			N Sharkie		2025-08-26		19414		Added logic to pick up completed cases with 0 LTV, ppopulated RportToSB flag
-- 104			R Callan		2025-10-30		20559		Update the product history temp table to make date check exclude any time element.
-- 105			N Sharkie		2026-03-23		23143		ReportToSB flag added to final insert. Had been missed previously
-- 106			H Rielly		2026-04-27		23466		Updated to execute GYNIM SP
-- 107			G Thirupathi	2026-04-28		22751		Added BalanceClosedDate, CashBalance and Shortfall columns and its logics
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

SET ANSI_PADDING ON;

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

DECLARE @reportDate DATE;
DECLARE @cobID INT;

SET @reportDate = DATEADD(d, -1, GETDATE());
SELECT @cobID = CAST(FORMAT(@reportDate,'yyyyMMdd') AS INT);

DECLARE @migDate DATE = '2023-05-06' -- used fpr app date poulation as logic updated during finova upgrade migration

---------------------------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#appPool') IS NOT NULL
DROP TABLE #appPool;

IF OBJECT_ID('tempdb..#apps') IS NOT NULL
DROP TABLE #apps;

IF OBJECT_ID('tempdb..#dimcoApps') IS NOT NULL
DROP TABLE #dimcoApps;

IF OBJECT_ID('tempdb..#oprod') IS NOT NULL
DROP TABLE #oprod;

IF OBJECT_ID('tempdb..#accs') IS NOT NULL
DROP TABLE #accs;

---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#brexcl') IS NOT NULL
DROP TABLE #brexcl;

SELECT ApplicationRef
into #brexcl
FROM TML_DW.dbo.vw_BrokerExclusions

---------------------------------------------------------------------------------------------------
/*
	get Aplpication pool to use. This will allow us to filter out PT applications as not wanted for reporting
	Can then use to filter out other tables
*/

SELECT dapp.DIM_CO_Application_DWSK, dapp.DIM_CO_Application_SSK, dapp.DIM_CO_Process_DWSK, dapp.AccountCategory, dapp.AccountType, dapp.ApplicationRef
	, dapp.ApplicationType, dapp.ApplicationPurpose, dapp.ApplicationSubPurpose, dapp.ApplicationDate, dapp.TotalApplicants, dapp.UsePanelSolicitors
	, dapp.Service, dapp.LatestStatus, dapp.Channel, dapp.IsRegulated, dapp.LoanType, dapp.LoanSubType, dapp.LoanPurpose, dapp.LoanTermStartDate, dapp.ERCEndDate
	, dapp.BenefitPeriodEndDate, dapp.BpfBasedOn, dapp.IncomeStatus, dapp.RepaymentType, dapp.InterestRateOption, dapp.ProductRange, dapp.IsSaleAdvised
	, dapp.LenderCode, dapp.LenderName, dapp.OfferDate, dapp.OfferDateEstimated, dapp.OfferExpiry, dapp.AccountNumber, dapp.CompletionDate, dapp.CompletionDateEstimated
	, dapp.ProductScheme, dapp.ApplicationClass, dapp.CampaignCode, dapp.Source, dapp.SourceOther, dapp.SourceSubType, dapp.SourceSubTypeOther, dapp.Branch
	, dapp.CurrencyType, dapp.IsDebtConsolidation, dapp.IsHomeImprovement, dapp.StaffMember, dapp.IsHighNetWorthLoan, dapp.IsMCOBTransition, dapp.IsSharedOwnership
	, dapp.IsCapitalRaising, dapp.IsAnonymised, dapp.FunderPoolCode, dapp.SourceSystemID, dapp.TermBasedOn, dapp.CalculationMortalityTerm, dapp.AuditKey, dapp.IsInferred
	, dapp.Checksum, dapp.SCDStartDate, dapp.SCDEndDate, dapp.SCDStatus 
INTO #appPool
FROM DPR_DW.dbo.DIM_CO_Application dapp	 
--LEFT OUTER JOIN TML_DW.dbo.vw_BrokerExclusions excl ON dapp.ApplicationRef = excl.ApplicationRef -- Exclusions - exclude test applications
LEFT OUTER JOIN #brexcl excl ON dapp.ApplicationRef = excl.ApplicationRef -- Exclusions - exclude test applications
WHERE @cobID >= dapp.SCDStartDate AND @cobID < dapp.SCDEndDate
AND dapp.ApplicationRef <>'Unknown'
AND excl.ApplicationRef IS NULL -- exclude test applications
AND dapp.ApplicationDate NOT IN (20230506, 20230507, 20230508) -- created as test for finova upgrade
AND dapp.ApplicationPurpose <> 'ProductSwitch'
OPTION (RECOMPILE);

CREATE CLUSTERED INDEX IDX_AP1 ON #appPool(ApplicationRef);

---------------------------------------------------------------------------------------------------
--vw_AppFeeAnalysis

IF OBJECT_ID('tempdb..#AppFee') IS NOT NULL
DROP TABLE #AppFee;

SELECT afa.ApplicationRef, afa.AppDate, afa.AppFeePerc, afa.NetValFeePerc, afa.CompFeePerc, afa.TTFeePerc
	, afa.ERCPerc, afa.ProcFeePerc, afa.CashbackPerc
INTO #AppFee
FROM TML_DW.dbo.vw_AppFeeAnalysis afa

CREATE CLUSTERED INDEX IDX_APF1 ON #AppFee(ApplicationRef);


---------------------------------------------------------------------------------------------------

-- Val Instructe missing
IF OBJECT_ID('tempdb..#vals') IS NOT NULL
DROP TABLE #vals;

SELECT v.ApplicationRef, v.LoanType, v.DIM_CO_Application_DWSK, v.DipCreatedDate, v.SecurityValuationId, v.PropertyValue, v.PresentValue, v.ImprovedValue
	, v.ValuationType, v.BPFBasedOn, v.ValInstructDate, v.ValuationDate, v.ValuationStatus, v.IsLatestValuation, v.ValuerFirm, v.ValuerContactName
	, v.IsActiveValuation, v.PurchasePrice, v.ValuationToUsePurchasePrice, v.PartialRententionRequired, v.Retainer, v.TenureType, v.RemainingLease
	, v.IsNewBuild, v.Region, v.PostCode, v.PropertyFullAddress, v.HouseName, v.FlatNumber, v.HouseNumber, v.PropertyType, v.PropertySubType, v.TitleNo
	, v.PropertyBuilt, v.NumberOfBedrooms, v.NumberOfKitchens, v.NumberOfReceptions, v.IsAboveRetailPremises, v.PropertyStorey, v.StoreysInBlock
	, v.RentalIncome, v.RentUnfurnished, v.MinRentalIncome, v.DIM_CO_AssetSecurity_DWSK, v.LocalAuthModHousingAss, v.rentaloccupancytype, v.EPCRating
	, v.EPCRatingNote, v.CertificationType, v.HasNHBCCertificate, v.HasARCCertificate, v.HasZurichCertificate, v.OtherCertificate 
INTO #vals
FROM dbo.vw_Valuations v
--INNER JOIN #appPool ap ON v.ApplicationRef = ap.ApplicationRef COLLATE DATABASE_DEFAULT
WHERE v.ValInstructDate IS NOT NULL	
AND v.IsLatestValuation = 1;

DELETE FROM #vals 
WHERE NOT EXISTS (
		SELECT 1
		FROM #appPool apps
		WHERE apps.ApplicationRef = #vals.ApplicationRef COLLATE DATABASE_DEFAULT
		);

CREATE CLUSTERED INDEX IDX_Vals1 ON #vals(ApplicationRef);

---------------------------------------------------------------------------------------------------
--Dead Dates
-- Dead dates before Finova upgrade.
IF OBJECT_ID('tempdb..#DeadTBL') IS NOT NULL
DROP TABLE #DeadTBL;

SELECT d.ApplicationRef,
       d.DeadDate,
	   app.LatestStatus
INTO #DeadTBL
FROM dbo.tbl_DeadDates d
INNER JOIN dbo.tbl_Applications app ON app.ApplicationRef = d.ApplicationRef
INNER JOIN #appPool ap ON d.ApplicationRef = ap.ApplicationRef COLLATE DATABASE_DEFAULT
WHERE app.LatestStatus IN ('Expired' , 'CancelledDeclined')


IF OBJECT_ID('tempdb..#Expired') IS NOT NULL
DROP TABLE #Expired;

--Insert into the @#Expired table
SELECT dapp.ApplicationRef
	, CONVERT(DATE, CONVERT(VARCHAR(10), MAX(dapp.SCDStartDate))) AS DeadDate
into #Expired
FROM DPR_DW..DIM_CO_Application dapp
INNER JOIN #appPool ap ON dapp.ApplicationRef = ap.ApplicationRef COLLATE DATABASE_DEFAULT
LEFT OUTER JOIN TML_DW.dbo.vw_BrokerExclusions excl ON dapp.ApplicationRef = excl.ApplicationRef -- Exclusions - exclude test applications
WHERE 1= 1
AND dapp.LatestStatus IN ('Expired') 
AND dapp.SCDStartDate <> 20230506
AND excl.ApplicationRef IS NULL -- exclude test applications
GROUP BY dapp.ApplicationRef 


IF OBJECT_ID('tempdb..#Cancelled') IS NOT NULL
DROP TABLE #Cancelled;

--Insert into the @#Cancelled table
SELECT ap.ApplicationRef
	, FORMAT(MAX(dh.DecisionDate), 'yyyy-MM-dd') AS DeadDate
INTO #Cancelled
FROM DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMADecisionHistory dh
INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAApplication ap ON dh.ApplicationId = ap.Id
INNER JOIN #appPool p ON ap.ApplicationRef = p.ApplicationRef COLLATE DATABASE_DEFAULT
LEFT OUTER JOIN TML_DW.dbo.vw_BrokerExclusions excl 
							ON ap.ApplicationRef = excl.ApplicationRef COLLATE DATABASE_DEFAULT-- Exclusions - exclude test applications
WHERE 1 = 1
AND excl.ApplicationRef IS NULL -- exclude test applications
AND dh.ProductSelected  = 'Decline Cancel'
AND dh.FmaStatusBefore <> dh.FmaStatusAfter
GROUP BY ap.ApplicationRef


-- Final Select
-- join the expired and cancelled / Declined together, join to the DeadDate table to bring back
-- the correct dates before upgrade as new ways is brining back different dates.
IF OBJECT_ID('tempdb..#Final') IS NOT NULL
DROP TABLE #Final;

SELECT b.ApplicationRef,
IIF(b.DeadDate = b.tableDeadDate OR b.DeadDate >= '2023-05-09', b.DeadDate, b.tableDeadDate) AS DeadDate
INTO #Final
From
(
	SELECT a.ApplicationRef, MAX(a.DeadDate) AS DeadDate 
		, d.DeadDate AS tableDeadDate
	FROM (
		SELECT ApplicationRef,
			   DeadDate 
		FROM #Expired

		UNION

		SELECT ApplicationRef COLLATE DATABASE_DEFAULT,
			   DeadDate 
		FROM #Cancelled
		) a
		LEFT OUTER JOIN dbo.tbl_DeadDates d ON d.ApplicationRef = a.ApplicationRef
		LEFT OUTER JOIN  DPR_DW..DIM_CO_Application dapp ON  dapp.ApplicationRef = a.ApplicationRef COLLATE DATABASE_DEFAULT
															AND dapp.SCDStatus = 'C'	
	WHERE 1 = 1
	AND dapp.LatestStatus IN ('Expired', 'CancelledDeclined' )
	GROUP BY a.ApplicationRef, d.DeadDate 
) b

-- Join the #Final table to the #DeadTBL to bring back missing records for two applicaitons as 
-- no Decision History wizard has been run on the them.
IF OBJECT_ID('tempdb..#DeadDates') IS NOT NULL
DROP TABLE #DeadDates;

SELECT deadD.ApplicationRef, deadD.DeadDate 
INTO #DeadDates
FROM (
	SELECT ApplicationRef, DeadDate
	FROM #Final

	UNION

	SELECT ApplicationRef, DeadDate
	FROM #DeadTBL
	WHERE NOT EXISTS (
		SELECT *
		FROM #Final
		WHERE #Final.ApplicationRef = #DeadTBL.ApplicationRef
	)
) deadD;

---------------------------------------------------------------------------------------------------
/*
	-- TAKE LATEST DIM CO APPLICATION
*/
SELECT ExternalSystemReference
, dapp.*
, Environment = IIF(dapp.LatestStatus = 'Completed' AND dapp.CompletionDate < CAST(FORMAT(GETDATE(), 'yyyyMMdd')AS INT) OR dapp.Applicationref = 'M001373482', 'Servicing', 'Origination')
, DIPCreatedDate = CONVERT(DATE,CONVERT(VARCHAR,dapp.ApplicationDate,102))
, dipsub.DIPSubmitDate, dipacc.DipAcceptDate
, AppDate = ISNULL(appDate.AppDate, assDate.AssessmentDate)
, UADate = IIF(
				appDate.AppDate < @migDate
				, appDate.AppDate -- didnt exist before migration so need to set to the app date for historic workflow calculations
				, assDate.AssessmentDate 
			)
, ValInstructDate = ISNULL(IIF( ISNULL(appDate.AppDate, assDate.AssessmentDate) IS NOT NULL, valdates.ValInstructDate, NULL), vals.ValInstructDate)
, ValReceiveDate = pt.ValuationDate
, FirstOfferDate = offers.FirstOfferDate
, LatestOfferDate = IIF(
				    Latestoffers.LatestOfferDate > ISNULL(RecompletionDate, comp.CompletionDate) AND dead.DeadDate IS NOT NULL
				    , offers.FirstOfferDate
				    , Latestoffers.LatestOfferDate
				 ) -- deals with 5832 reval after closure and manually typed offer date #10
, ExpectedCompDate = CONVERT(DATE, CONVERT(VARCHAR, dapp.CompletionDate))
, CompDate = comp.CompletionDate
, comp.FeesReturnedDate
, comp.RecompletionDate	
, dead.DeadDate 
, ExcludeFromSecuritisation = IIF(efs.AccountNo IS NOT NULL, 1, 0)
, OfferExpiryDate = IIF(dapp.OfferExpiry = 99991231, NULL, CONVERT(VARCHAR, CONVERT(DATE, CONVERT(VARCHAR(10), dapp.OfferExpiry))))
, InitialValDate = IIF(pt.ValuationDate < initialvaldates.InitialValDate, pt.ValuationDate, initialvaldates.InitialValDate)
INTO #dimcoApps
FROM #appPool dapp
INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFMA_FMAApplication synApp ON dapp.ApplicationRef = synApp.ApplicationRef COLLATE DATABASE_DEFAULT 
INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFMA_FMALoanDetails ld ON synApp.Id = ld.ApplicationId
LEFT OUTER JOIN TML_DW.dbo.tbl_PropertyDetails pt ON dapp.DIM_CO_Application_DWSK = pt.DIM_CO_Application_DWSK --COLLATE DATABASE_DEFAULT
															AND pt.OriginationSource = 'TML'

--DIP SUBMIT
LEFT OUTER JOIN (
	   SELECT 
	   dapp.ApplicationRef,
	   CONVERT(DATE, CONVERT(VARCHAR, MIN(fdechist.DecisionDateTime))) AS DIPSubmitDate
	   FROM DPR_DW.dbo.FACT_CO_DecisionHistoryTrx fdechist
	   INNER JOIN DPR_DW.dbo.DIM_CO_Application dapp ON fdechist.DIM_CO_Application_DWSK = dapp.DIM_CO_Application_DWSK
	   WHERE fdechist.ProductSelected = 'DIP Submit'
	   AND CONVERT(DATE, fdechist.DecisionDateTime) <= @reportDate
	   GROUP BY dapp.ApplicationRef
) dipsub ON dapp.ApplicationRef = dipsub.ApplicationRef

--DIP ACCEPT
LEFT OUTER JOIN ( 
	SELECT dapp.ApplicationRef,
	CONVERT(DATE,CONVERT(VARCHAR, MIN(fdechist.DecisionDateTime),102)) AS DipAcceptDate
	FROM DPR_DW.dbo.FACT_CO_DecisionHistoryTrx fdechist
	INNER JOIN DPR_DW.dbo.DIM_CO_Application dapp ON fdechist.DIM_CO_Application_DWSK = dapp.DIM_CO_Application_DWSK
	WHERE fdechist.ProductSelected = 'DIP Submit'
	AND fdechist.Username LIKE 'PortalUsers%' 
	AND fdechist.DecisionStatus = 'Accept'
	AND CONVERT(DATE, fdechist.DecisionDateTime) <= @reportDate
	GROUP BY dapp.ApplicationRef
	UNION
	-- get the 3 early applications with no portal dip accept but went onto application 
	SELECT dapp.ApplicationRef AS [Application Ref]
	, CONVERT(DATE,CONVERT(VARCHAR,MIN(stat.TransactionDate),102)) AS DipAcceptDate
	FROM DPR_DW.dbo.FACT_CO_StatusTrx stat
	INNER JOIN DPR_DW.dbo.DIM_CO_Application dapp ON stat.DIM_CO_Process_DWSK = dapp.DIM_CO_Process_DWSK
	WHERE stat.DIM_CO_Status_DWSK = 4
	AND dapp.ApplicationRef NOT IN (
									SELECT 
									dapp.ApplicationRef
									FROM DPR_DW..FACT_CO_DecisionHistoryTrx fdechist
									INNER JOIN DPR_DW..DIM_CO_Application dapp ON fdechist.DIM_CO_Application_DWSK = dapp.DIM_CO_Application_DWSK
									WHERE fdechist.ProductSelected = 'DIP Submit'
									AND fdechist.Username LIKE 'PortalUsers%' 
									AND fdechist.DecisionStatus = 'Accept'
									GROUP BY dapp.ApplicationRef
								) 
	-- AND stat.TransactionDate < @cobID
	GROUP BY dapp.ApplicationRef
) dipacc
	ON dapp.ApplicationRef = dipacc.ApplicationRef


-- Application Date
LEFT OUTER JOIN ( 
	SELECT fma.ApplicationRef
	, CONVERT(DATE,CONVERT(VARCHAR(10), MIN(fmas.DateCreated),102)) AS AppDate
	FROM DPR_DW.[Latest_Orig_BoM].[dbo_morAppFma_FMAStatus] fmas
	LEFT OUTER JOIN DPR_DW.[Latest_Orig_BoM].[dbo_morAppFma_FMAApplication] fma ON fma.Id = fmas.ApplicationId
	WHERE fmas.statusNameId = 'PreFMASubmitted'
	AND FORMAT(fmas.DateCreated, 'yyyy-MM-dd') < FORMAT(GETDATE(), 'yyyy-MM-dd')
	GROUP BY fma.ApplicationRef
) appDate 
	ON appDate.ApplicationRef COLLATE DATABASE_DEFAULT = dapp.ApplicationRef
                    
-- Underwriter Assessmnt date - all documents have been uploaded by broker
LEFT OUTER JOIN ( 
	SELECT fma.ApplicationRef
	, CONVERT(DATE,CONVERT(VARCHAR(10), MIN(fmas.DateCreated),102)) AS AssessmentDate
	FROM DPR_DW.[Latest_Orig_BoM].[dbo_morAppFma_FMAStatus] fmas
	LEFT OUTER JOIN DPR_DW.[Latest_Orig_BoM].[dbo_morAppFma_FMAApplication] fma ON fma.Id = fmas.ApplicationId
	WHERE fmas.StatusNameId = 'ApplicationSubmitted'
	AND FORMAT(fmas.DateCreated, 'yyyy-MM-dd') < FORMAT(GETDATE(), 'yyyy-MM-dd')
	GROUP BY fma.ApplicationRef
) assDate 
	ON assDate.ApplicationRef COLLATE DATABASE_DEFAULT = dapp.ApplicationRef

-- VALUATION DATES
LEFT OUTER JOIN (
    SELECT 
    ApplicationRef = ISNULL(valInst.ApplicationRef, valRec.APplicationRef)
    , ValInstructDate = valInst.ValDate
    , ValReceiveDate = valRec.ValDate
    FROM ( 
	   SELECT dapp.ApplicationRef
	   , CONVERT(DATE,CONVERT(VARCHAR,MIN(stat.TransactionDate)),102) AS ValDate
	   FROM DPR_DW..FACT_CO_StatusTrx stat
	   INNER JOIN DPR_DW..DIM_CO_Application dapp ON stat.DIM_CO_Process_DWSK = dapp.DIM_CO_Process_DWSK
	   INNER JOIN DPR_DW..DIM_CO_Status dstat ON stat.DIM_CO_Status_DWSK = dstat.DIM_CO_Status_DWSK
	   WHERE stat.DIM_CO_Status_DWSK IN (24) -- Val Instructed
	   AND stat.TransactionDate <= @cobID
	   GROUP BY dapp.ApplicationRef
    ) valInst
    FULL OUTER JOIN (
	   SELECT dapp.ApplicationRef
	   , CONVERT(DATE,CONVERT(VARCHAR,MIN(stat.TransactionDate)),102) AS ValDate
	   FROM DPR_DW..FACT_CO_StatusTrx stat
	   INNER JOIN DPR_DW..DIM_CO_Application dapp ON stat.DIM_CO_Process_DWSK = dapp.DIM_CO_Process_DWSK
	   INNER JOIN DPR_DW..DIM_CO_Status dstat ON stat.DIM_CO_Status_DWSK = dstat.DIM_CO_Status_DWSK
	   WHERE stat.DIM_CO_Status_DWSK IN (25) -- Val Received
	   AND stat.TransactionDate <= @cobID
	   GROUP BY dapp.ApplicationRef
    ) valRec
	   ON valInst.ApplicationRef = valRec.ApplicationRef  

) valdates ON dapp.ApplicationRef = valdates.ApplicationRef

--Initial Valuation Dates
LEFT OUTER JOIN (
SELECT
APP.ApplicationRef
,CONVERT(DATE,InitialVals.InspectionDate) AS InitialValDate
FROM DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAApplication APP
INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMALoanDetails LD ON APP.Id = LD.ApplicationId
INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMASecurity SEC ON LD.Id = SEC.LoanDetailsId
INNER JOIN (
			SELECT * FROM
			(
				SELECT 
				ROW_NUMBER() OVER (PARTITION BY SECVAL.SecurityId ORDER BY SECVAL.ValuationDate ASC) AS Ranking
				,SECVAL.Id AS SecurityValuationId
				,SECVAL.SecurityId AS SecurityId
				,SECVAL.ValuationDate AS ValuationInstructed
				,PROPDET.InspectionDate
				FROM DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMASecurityValuation SECVAL
				INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAPropertySummary PROPSUM ON SECVAL.Id = PROPSUM.SecurityValuationId
				INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAPropertySurveyDetails SURVDET ON PROPSUM.Id = SURVDET.PropertySummaryId
				INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAProperty PROPERTY ON SURVDET.Id = PROPERTY.PropertySurveyDetailsId
				INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAPropertyDetail PROPDET ON PROPERTY.Id = PROPDET.PropertyId
				WHERE SECVAL.ValuationType <> 'CustomerProvided' AND SECVAL.ValuationDate IS NOT NULL
				) tmp
			WHERE tmp.Ranking = 1
			) InitialVals ON InitialVals.SecurityId = SEC.Id
) initialvaldates ON dapp.ApplicationRef = initialvaldates.ApplicationRef COLLATE DATABASE_DEFAULT

LEFT OUTER JOIN (
	SELECT dapp.ApplicationRef, COUNT(*) AS NoOffers
	, CONVERT(DATE, MIN(fdechist.DecisionDate)) AS FirstOfferDate
	, CONVERT(DATE, MAX(fdechist.DecisionDate))  AS LatestOfferDate
	FROM DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMADecisionHistory fdechist
	INNER JOIN DPR_DW.[Latest_Orig_BoM].[dbo_morAppFma_FMAApplication] dapp ON dapp.id = fdechist.applicationid
	WHERE fdechist.ProductSelected = 'Issue Offer'
	AND fdechist.Scheme= 'Wizard.IssueOffer'
	AND fdechist.decisionstatus =2 
	GROUP BY dapp.ApplicationRef
) offers
	ON dapp.ApplicationRef = offers.ApplicationRef COLLATE DATABASE_DEFAULT

LEFT OUTER JOIN (
	SELECT dapp.ApplicationRef, COUNT(*) AS NoOffers
	, CONVERT(DATE, MIN(fdechist.DecisionDateTime)) AS FirstOfferDate
	, CONVERT(DATE, MAX(fdechist.DecisionDateTime))  AS LatestOfferDate
	FROM DPR_DW..FACT_CO_DecisionHistoryTrx fdechist
	INNER JOIN DPR_DW..DIM_CO_Application dapp ON fdechist.DIM_CO_Application_DWSK = dapp.DIM_CO_Application_DWSK
	WHERE fdechist.ProductSelected = 'Issue Offer'
	AND fdechist.Scheme= 'Wizard.IssueOffer'
	GROUP BY dapp.ApplicationRef
) Latestoffers
	ON dapp.ApplicationRef = Latestoffers.ApplicationRef 

-- COMPLETIONS
LEFT OUTER JOIN (
    SELECT AccountNo, DIM_CO_Account_DWSK, Securitised, ISNULL(OrigCompletion, CompDate) AS CompletionDate, FeesReturnedDate, RecompletionDate
	 , c.DIM_CO_ServicingPool_DWSK
    FROM (
	   SELECT dacc.AccountNo, dacc.DIM_CO_Account_DWSK
		, Securitised = IIF(dacc.DIM_CO_ServicingPool_DWSK = 20, 1, 0)
	   , IIF( returned.FeesReturnedDate IS NULL
		  , CONVERT(DATE, CONVERT(VARCHAR, dadv.AdvanceStartDate))
		  , CASE	
				WHEN returned.ReCompletion <= @reportDate
					THEN CONVERT(DATE, CONVERT(VARCHAR, dadv.AdvanceStartDate))
				WHEN returned.FeesReturnedDate <= @reportDate 
					THEN NULL
			 ELSE CONVERT(DATE, CONVERT(VARCHAR, dadv.AdvanceStartDate))
		  END
	   ) AS CompletionDate
	   , CONVERT(DATE, CONVERT(VARCHAR, dadv.AdvanceStartDate)) AS CompDate
	   , returned.FeesReturnedDate, OrigCompletion, returned.ReCompletion AS RecompletionDate
	   , dadv.Status, dadv.SCDStartDate, dadv.SCDEndDate
	   , RowNumber = ROW_NUMBER() OVER (PARTITION BY dacc.AccountNo ORDER BY dadv.AdvanceStartDate DESC) 
		, dacc.DIM_CO_ServicingPool_DWSK
	   FROM DPR_DW..DIM_CO_Account dacc
	   INNER JOIN DPR_DW..DIM_CO_Advance dadv ON dacc.DIM_CO_Account_DWSK = dadv.DIM_CO_Account_DWSK
	   INNER JOIN (
		  SELECT dacc.AccountNo, MAX(dadv.SCDStartDate) AS MaxStart
		  FROM DPR_DW..DIM_CO_Account dacc
		  INNER JOIN DPR_DW..DIM_CO_Advance dadv ON dacc.DIM_CO_Account_DWSK = dadv.DIM_CO_Account_DWSK
		  WHERE CONVERT(DATE, CONVERT(VARCHAR, dadv.SCDEndDate)) >= @reportDate
		  GROUP BY dacc.AccountNo
	   ) latest ON dacc.AccountNo = latest.AccountNo 
				AND dadv.SCDStartDate = latest.MaxStart
	   /*
		  Earliest adjustment needed to deal with instances that weren't cancelled properly 
		  so needed to be reissued again before being cancelled eg. *5832
		  */
		  LEFT OUTER JOIN (
			 SELECT acc.AccountNo, et.TransactionType, tx.Amount, app.LatestStatus, tx.DIM_CO_ProdSegm_DWSK 
			 , CONVERT(DATE, CONVERT(VARCHAR, acc.AccountOpenDate )) AS OrigCompletion
			 , CONVERT(DATE, tx.TransactionDatetime) AS FeesReturnedDate
			 , IIF(app.CompletionDate = 99991231, NULL 
					, IIF(CONVERT(DATE, CONVERT(VARCHAR, app.CompletionDate)) > CONVERT(DATE, GETDATE()), NULL
					, CONVERT(DATE, CONVERT(VARCHAR, app.CompletionDate)))) AS ReCompletion
			 FROM DPR_DW.dbo.DIM_CO_Account acc
			 INNER JOIN DPR_DW.dbo.DIM_CO_Application app ON acc.AccountNo = app.ApplicationRef AND app.SCDStatus = 'C'
			 INNER JOIN DPR_DW.dbo.DIM_CO_Advance adv ON acc.DIM_CO_Account_DWSK = adv.DIM_CO_Account_DWSK
			 INNER JOIN DPR_DW.dbo.DIM_CO_ProdSegm ps ON adv.DIM_CO_Advance_DWSK = ps.DIM_CO_Advance_DWSK 
			 INNER JOIN DPR_DW.dbo.FACT_CO_GLEntryTrx tx ON ps.DIM_CO_ProdSegm_DWSK = tx.DIM_CO_ProdSegm_DWSK 
			 INNER JOIN DPR_DW.dbo.DIM_CO_GLEntryType et ON tx.DIM_CO_GLEntryType_DWSK = et.DIM_CO_GLEntryType_DWSK 
										  AND et.TransactionType =  'Credit Principal Adjustment'
			 INNER JOIN (
				SELECT dacc.AccountNo, MIN(dadv.SCDStartDate) AS MaxStart
				FROM DPR_DW..DIM_CO_Account dacc
				INNER JOIN DPR_DW..DIM_CO_Advance dadv ON dacc.DIM_CO_Account_DWSK = dadv.DIM_CO_Account_DWSK
				WHERE dadv.Status = 'Closed'
				GROUP BY dacc.AccountNo
			 ) earliest ON acc.AccountNo = earliest.AccountNo 
						  AND adv.SCDStartDate = earliest.MaxStart
		  ) returned ON dacc.AccountNo = returned.AccountNo 
		  WHERE CONVERT(DATE, CONVERT(VARCHAR, dadv.AdvanceStartDate)) <= @reportDate
    ) c
    WHERE c.RowNumber = 1
) comp
	ON dapp.ApplicationRef = comp.AccountNo


LEFT OUTER JOIN #DeadDates dead ON dapp.ApplicationRef = dead.ApplicationRef COLLATE DATABASE_DEFAULT

LEFT OUTER JOIN TML_DW.dbo.vw_BrokerExclusions excl ON dapp.ApplicationRef = excl.ApplicationRef -- Exclusions - exclude test applications
LEFT OUTER JOIN TML_DW.dbo.tbl_ExcludeFromSecuritisation efs ON dapp.ApplicationRef = efs.AccountNo COLLATE DATABASE_DEFAULT
LEFT OUTER JOIN #vals vals ON vals.ApplicationRef = dapp.ApplicationRef COLLATE DATABASE_DEFAULT

OPTION (RECOMPILE);

CREATE CLUSTERED INDEX IDX_DApp1 ON #dimcoApps(ApplicationRef);
CREATE NONCLUSTERED INDEX IDX_DApp2 ON #dimcoApps(DIM_CO_Application_DWSK);

---------------------------------------------------------------------------------------------------

/* oprod join put as temp table for performance issues*/

IF OBJECT_ID('tempdb..#oprod') IS NOT NULL
DROP TABLE #oprod;

SELECT DISTINCT app.ApplicationRef--, ld.LoanType, ld.LoanPurpose, prod.LoanAmount												
, ProductCode = prod.VariantCode COLLATE DATABASE_DEFAULT		
, tp.Product
, prod.RateSchedule														
, LTVTier = IIF(prod.RiskScheme = '', 60, CONVERT(DECIMAL(6,2), LEFT(prod.RiskScheme, 2))) -- Chnage #87
, TierBand = prod.ProductCategory												
, prod.RiskScheme												
, ProductDescription = REPLACE(REPLACE(prod.RateScheduleId, CHAR(10), ''), CHAR(13), '')  COLLATE DATABASE_DEFAULT -- remove line breaks and carriage returns 												
, TermInMonths = (ld.InitialLoanTermRequested * 12) + ld.InitialLoanTermMonthsRequested																
, AppInterestRate = CONVERT(DECIMAL(6,2), prod.InitialInterestRate)																	
, tp.RevertAdd	

-- reporting wrong thing but consistant with what was there before. Change once done
, AppBaseRate = IIF(												
				ISNULL(prod.BaseRate, 5) > 1								
				, ISNULL(BaseRates.LIBOR, prod.BaseRate - tp.BaseRateMargin) 								
				, prod.BaseRate								
			)																		
, tp.ProductRange	
, ProductFeatureResi0UpFrontFees = IIF(tp.ProductFeature LIKE '%Residential £O up front fees%', tp.ProductFeature, NULL)
INTO #oprod
FROM DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAApplication app	
--INNER JOIN #appPool ap ON app.Applicationref = ap.ApplicationRef
INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMALoanDetails ld ON app.ID = ld.ApplicationId												
INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAProduct prod ON ld.ID = prod.LoanDetailsId												
LEFT OUTER JOIN (												
	SELECT l.ApplicationRef, l.DateCreated											
	--, TrackerRate = IIF(l.DateCreated > '2020-10-21',r2.TrackerRate, r.TrackerRate)  /*Not used in the stored proceudre  */											
	, LIBOR = CASE WHEN apps.LoanType = 'BTL'  AND l.DateCreated > '2020-10-21' THEN (SELECT TBRBTL FROM dbo.fn_DailyRates(l.DateCreated))
				WHEN apps.LoanType = 'Residential2'  AND l.DateCreated > '2021-01-01' THEN (SELECT TBRRESI FROM dbo.fn_DailyRates(l.DateCreated))
				ELSE (SELECT BBR FROM dbo.fn_DailyRates(l.DateCreated))
				END									
	FROM TML_DW..tbl_AffordabilityLatest l											
	LEFT OUTER JOIN	#dimcoApps apps ON apps.ApplicationRef = l.ApplicationRef COLLATE DATABASE_DEFAULT									
) baseRates												
	ON app.ApplicationRef = baseRates.ApplicationRef COLLATE DATABASE_DEFAULT											
LEFT OUTER JOIN TML_DW.dbo.tbl_Products tp ON prod.VariantCode = CONVERT(VARCHAR(10), tp.ProductCode)												
LEFT OUTER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAFeaturesPackage fpack ON prod.Id = fpack.ProductId		
LEFT OUTER JOIN #dimcoApps a ON a.ApplicationRef = app.ApplicationRef COLLATE DATABASE_DEFAULT
OPTION(RECOMPILE);

CREATE CLUSTERED INDEX IDX_Oprod1 ON #oprod(ApplicationRef);

---------------------------------------------------------------------------------------------------

--Product Transfers 

IF OBJECT_ID('tempdb..#ProductTransfers') IS NOT NULL
DROP TABLE #ProductTransfers;


SELECT ph.AccountNo,
       ph.ProductCode,
       ph.OpenDate AS PTDate,
       ph.TermInMonths,
       ph.RepaymentType,
       ph.VersionNo,
	   p.Product AS ProductDescription,
	   p.ProductFeature,
	   p.ProductRange
INTO #ProductTransfers
FROM dbo.tbl_ProductHistory ph
LEFT OUTER JOIN dbo.tbl_Products p ON p.ProductCode = ph.ProductCode
INNER JOIN (
    SELECT AccountNo, MAX(VersionNo) AS MaxVersionNo
    FROM dbo.tbl_ProductHistory
	WHERE OpenDate < CAST(GETDATE() AS date)
	AND ChangeType = 'Product Transfer'
    GROUP BY AccountNo
) maxver ON ph.AccountNo = maxver.AccountNo AND ph.VersionNo = maxver.MaxVersionNo
WHERE ph.VersionNo <> 1
AND ph.ChangeType = 'Product Transfer'


-- PT that have PT'd already.   Where an account has pt'd more than once within 
-- as shrot period of time.  This breaks on the first of the month and then
-- resloves the following day.   Fix to reslove the issue and should
-- account for future PT's for an account should do more than 2 PT'S.
-- Temp table resloves the issue for the first of the month by getting 
--  the correct details
IF OBJECT_ID('tempdb..#pt3') IS NOT NULL
DROP TABLE #pt3;

SELECT  AccountNo, MAX(VersionNo) -1 AS VersionNo
INTO #pt3
FROM dbo.tbl_ProductHistory
WHERE 1 = 1
AND VersionNo > 2
AND ChangeType = 'Product Transfer'
AND OpenDate = FORMAT(GETDATE(), 'yyyy-MM-dd')
GROUP BY AccountNo


-- Join to get the data that is required in one row from the pt3
IF OBJECT_ID('tempdb..#pt4') IS NOT NULL
DROP TABLE #pt4;

SELECT pt.ProductCode,  p.Product AS ProductDescription,
	   p.ProductFeature, p.ProductRange, pt.AccountNo
INTO #pt4
FROM dbo.tbl_ProductHistory pt
INNER JOIN #pt3 pt3 ON pt3.AccountNo = pt.AccountNo 
								AND pt3.VersionNo = pt.VersionNo
LEFT OUTER JOIN dbo.tbl_Products p ON p.ProductCode = pt.ProductCode


----------------------------------------------------------------------------------------------------
-- servicing * product data

/* put as temp table for performance issues*/

SELECT  accInfo.AccountNo, accInfo.LoanType, accInfo.AccountOpenDate, accInfo.LoanTermStartDate
, accInfo.InitialLoanTermMonths, accInfo.RepaymentType, InitialBaseRateCode, accInfo.InitialBaseRate
, accInfo.DIM_CO_ServicingPool_DWSK
, prod.TierBand,COALESCE(COALESCE(pt4.ProductCode, pt.ProductCode),prod.ProductCode) AS ProductCode, prod.ProductCode AS ProductCodeV1, prod.LTVTier, COALESCE(COALESCE(pt4.ProductDescription, pt.ProductDescription),prod.ProductDescription) AS ProductDescription
, prod.OpeningInterestRate, COALESCE(COALESCE(pt4.ProductRange, pt.ProductRange), prod.ProductRange) AS ProductRange
, accInfo.DIM_CO_Account_DWSK, DIM_CO_ProdSegm_DWSK,  pt2.PTDate, COALESCE(pt4.ProductFeature, pt.ProductFeature) AS ProductFeature
, COALESCE(pt.PTDate, accInfo.LoanTermStartDate) AS FixedTermStart
INTO #accs
FROM (
	SELECT AccountNo = la.LoanAccountNo COLLATE DATABASE_DEFAULT
	, sp.LoanType
	--, la.LoanType -- use servicing pool to get buy backs in correct pool
	, AccountOpenDate = CONVERT(DATE, ls.SegmentStartDate)
	, LoanTermStartDate = CONVERT(DATE, la.LoanTermStartDate)
	, la.InitialLoanTermMonths
	, dacc.DIM_CO_Account_DWSK
	, RepaymentType = CASE 
						WHEN COUNT(ls.RepaymentType) = 2 THEN 'PartByPart'
						WHEN MAX(ls.RepaymentType) = 'CapitalAndInterest' THEN 'Repayment'
						ELSE 'InterestOnly'
					  END
	, InitialBaseRateCode = prod.BaseRateCode
	, InitialBaseRate = CASE
							WHEN prod.BaseRateCode = 'LIBOR' THEN dr.LIBOR
							WHEN la.LoanType = 'BTL' THEN dr.TBRBTL
							ELSE dr.TBRRESI
						END
	, dacc.DIM_CO_ServicingPool_DWSK
	, DIM_CO_ProdSegm_DWSK = MAX(pseg.DIM_CO_ProdSegm_DWSK)
	FROM DPR_DW.Latest_Serv_Lss.dbo_lss_LoanSegment ls
	INNER JOIN DPR_DW.Latest_Serv_Lss.dbo_lss_LoanAccount la ON ls.LoanAccountID = la.ID
	INNER JOIN (
		SELECT LoanAccountId, LatestStart = MAX(SegmentStartDate) 
		FROM DPR_DW.Latest_Serv_Lss.dbo_lss_LoanSegment 
		WHERE CONVERT(INT, FORMAT(SegmentStartDate, 'yyyyMMdd')) <= @cobid
		GROUP BY LoanAccountId	
	) latestSeg
		ON ls.LoanAccountId = latestSeg.LoanAccountId
	 			AND ls.SegmentStartDate = latestSeg.LatestStart
	INNER JOIN DPR_DW.Latest_Serv_Lss.dbo_lss_Advance ad ON ls.AdvanceId = ad.Id
	INNER JOIN (
		SELECT ad.LoanAccountId
		, LatestAdvance = MAX(AdvanceNumber) 
		FROM DPR_DW.Latest_Serv_Lss.dbo_lss_Advance ad 
		WHERE CONVERT(INT, FORMAT(ad.StartDate, 'yyyyMMdd')) <= @cobid
		GROUP BY ad.LoanAccountId
	) latestAdv
		ON ls.LoanAccountId = latestAdv.LoanAccountId
				AND ad.AdvanceNumber = latestAdv.LatestAdvance
	INNER JOIN DPR_DW.dbo.DIM_CO_Account dacc ON CONVERT(VARCHAR(50), la.ID) = dacc.DIM_CO_Account_SSK
												AND dacc.SCDStatus = 'C'
	INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAApplication synApp ON dacc.AccountNo = synApp.ApplicationRef COLLATE DATABASE_DEFAULT
	INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMALoanDetails ld ON synApp.ID = ld.ApplicationId
	INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAProduct prod ON ld.ID = prod.LoanDetailsId

	INNER JOIN dbo.tbl_DailyRates dr ON dr.RateDay = CONVERT(DATE, ls.SegmentStartDate)
	LEFT OUTER JOIN DPR_DW.dbo.DIM_CO_ProdSegm pseg ON CONVERT(VARCHAR(50), ls.ID) = pseg.DIM_CO_ProdSegm_SSK
														AND pseg.SCDStatus = 'C'
	LEFT JOIN dbo.tbl_ServicingPools sp ON dacc.DIM_CO_ServicingPool_DWSK = sp.DIM_CO_ServicingPool_DWSK
											 AND dacc.LoanType = sp.DPRLoanType COLLATE DATABASE_DEFAULT
	GROUP BY la.LoanAccountNo, la.LoanType, ls.SegmentStartDate, la.LoanTermStartDate, la.InitialLoanTermMonths
				, dacc.DIM_CO_Account_DWSK, prod.BaseRateCode, dr.LIBOR, dr.TBRBTL, dr.TBRRESI
				, dacc.DIM_CO_ServicingPool_DWSK, sp.LoanType
) accInfo
LEFT OUTER JOIN (
	SELECT AccountNo = app.ApplicationRef
	, Tierband = prod.ProductCategory
	, ProductCode = prod.VariantCode
	, LTVTier = CONVERT(decimal(6,2), CONVERT(INT, LEFT(prod.RiskScheme, 2)))
	, OpeningInterestRate = CONVERT(DECIMAL(6,2), prod.InitialInterestRate)
	, ProductDescription = prod.RateScheduleId
	, tprod.ProductRange
	FROM DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAApplication app
	INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMALoanDetails ld ON app.ID = ld.ApplicationId
	INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAProduct prod ON ld.ID = prod.LoanDetailsId
	LEFT OUTER JOIN TML_DW.dbo.tbl_Products tprod ON prod.VariantCode = CONVERT(VARCHAR(10), tprod.ProductCode)
) prod
	ON accInfo.AccountNo = prod.AccountNo
LEFT OUTER JOIN #ProductTransfers pt ON pt.AccountNo = accInfo.AccountNo
AND pt.PTDate <= @reportDate
LEFT OUTER JOIN #ProductTransfers pt2 ON pt2.AccountNo = accInfo.AccountNo
AND pt2.PTDate <= GETDATE()
LEFT OUTER JOIN #pt4 pt4 ON pt4.AccountNo = accInfo.AccountNo
;

CREATE CLUSTERED INDEX IDX_Accs1 ON #accs(AccountNo);

---------------------------------------------------------------------------------------------------
/*
	-- CREATE APPS TABLE
*/
SELECT ReportDate = @reportDate
, COBID = @cobID
, dapp.ApplicationRef
, dapp.DIM_CO_Application_DWSK
, dapp.DIM_CO_Application_SSK
, Environment = dapp.Environment
, LoanType = ISNULL(
					acc.LoanType
					, IIF(dapp.LoanType = 'Residential' AND ISNULL(acc.PTDate, dapp.DIPCreatedDate) > '2021-01-25', 'Residential2', dapp.LoanType)
				)
, RepaymentType = ISNULL(acc.RepaymentType, dapp.RepaymentType)
, IsRegulated = CASE dapp.IsRegulated
						 WHEN 'True' THEN 1
						 WHEN 'False' THEN 0
						 ELSE NULL
					 END
, LatestStatus = CASE 
					WHEN dapp.LatestStatus = 'ApplicationSubmitted' THEN 'Underwriter Assessment'
					WHEN dapp.LatestStatus = 'PreFMASubmitted' THEN 'Upload Documents'
					--WHEN dapp.LatestStatus = 'Completion' AND  dapp.CompletionDate = CAST(FORMAT(GETDATE(), 'yyyyMMdd')AS int) THEN 'AwaitingFundsRel'
					WHEN dapp.LatestStatus = 'Completed' AND  dapp.CompletionDate = CAST(FORMAT(GETDATE(), 'yyyyMMdd')AS INT) THEN 'AwaitingFundsRel'
					WHEN dapp.Environment = 'Origination' AND dapp.LatestStatus = 'Completed' AND dapp.CompletionDate = 99991231 THEN 'Delayed' -- Change #84 - returned funds not worked correctly in back office
					ELSE dapp.LatestStatus
				END
, Applicants = ISNULL(synApp.TotalApplicants, dapp.TotalApplicants)
, CustomerType = IIF(cust.CompanyName IS NULL, 'Individual', 'Company') -- ISNULL(cust.CustomerType, 'Individual') 
, MortgageType = ISNULL(mtype.LoanPurpose, dapp.LoanPurpose)
, ProductCode = COALESCE(acc.ProductCode, oprod.ProductCode)
, Product = COALESCE(acc.ProductDescription COLLATE DATABASE_DEFAULT, oprod.ProductDescription, IIF(dapp.InterestRateOption = 'All', 'Unknown', dapp.InterestRateOption))
, ProductTier = COALESCE(
						IIF(
							dapp.LoanType = 'Residential' AND dapp.DIPCreatedDate > '2021-01-25'
							, reverttable.tier
							, CASE 
					
								WHEN  cust.CompanyName IS NULL AND dapp.LoanType = 'BTL' AND ISNULL(acc.TierBand, tiertable.ProductCode) = 'Standard (Individual and Ltd Company)' THEN 'Standard (Individual) BTL'
								WHEN  cust.CompanyName IS NOT NULL AND dapp.LoanType = 'BTL' AND ISNULL(acc.TierBand, tiertable.ProductCode) = 'Standard (Individual and Ltd Company)' THEN 'Ltd Company BTL'
								ELSE COALESCE(acc.TierBand, tiertable.ProductCode, 'Unknown')
							  END
						)
						, 'Unknown'
					)
, ProductMaxLTV = COALESCE(acc.LTVTier, oprod.LTVTier)
, COALESCE(acc.ProductFeature, prodFeatures.ProductFeature, oprod.ProductFeatureResi0UpFrontFees) AS ProductFeature
, ProductRange = COALESCE(acc.ProductRange, oprod.ProductRange)
, TermInMonths = COALESCE(acc.InitialLoanTermMonths, oprod.TermInMonths)
, AppInterestRate = CONVERT(DECIMAL(4,2), oprod.AppInterestRate)
--, GrossYield = ISNULL(ROUND((((CONVERT(DECIMAL(10,2), oprod.AppInterestRate))/100)-afa.AppFeePerc+afa.NetValFeePerc+afa.CompFeePerc+afa.TTFeePerc+afa.ERCPerc-afa.ProcFeePerc-afa.CashbackPerc)*100,2), 0.00)
, GrossYield = CONVERT(DECIMAL(10,4),0.00)
, NetInterestMargin = CONVERT(DECIMAL(10,4),0.00)
, AppBaseRate = IIF(
					dapp.AppDate > '2020-10-21' OR reverttable.productcode >= 1925	
					,  IIF(dapp.LoanType = 'BTL'	
						, dr.TBRBTL
						, dr.TBRRESI
					)
					, oprod.AppBaseRate
				)			
, LoanAmount = fapp.LoanAmount_ABS
, OpeningCapitalBalance = fapp.LoanGrossAmount_ABS
, Valuation = ISNULL(NULLIF(pt.PropertyValue, 0), IIF(pt.PurchasePrice = 0, pt.ImprovedValue, pt.PurchasePrice)) --pt.PropertyValue
, OriginalLTV = CASE 
				WHEN dapp.IsSharedOwnership = 1
				THEN CONVERT(DECIMAL(20,2),fapp.LoanAmount_ABS/ISNULL(NULLIF(pt.PropertyValue, 0), IIF(pt.PurchasePrice = 0, pt.ImprovedValue, pt.PurchasePrice))*100)
				ELSE IIF(ISNULL(NULLIF(pt.PropertyValue, 0), IIF(pt.PurchasePrice = 0, pt.ImprovedValue, pt.PurchasePrice))/*ISNULL(pt.propertyvalue, 0)*/ <= 1.00
						  , 0
						  , IIF(fapp.LoanToValue_ABS > 100.00 , 0, fapp.LoanToValue_ABS)
						  )
				END
, OriginalGrossLTV = CASE 
					 WHEN dapp.IsSharedOwnership = 1
					 THEN CONVERT(DECIMAL(20,2),fapp.LoanGrossAmount_ABS/ISNULL(NULLIF(pt.PropertyValue, 0), IIF(pt.PurchasePrice = 0, pt.ImprovedValue, pt.PurchasePrice))*100) 
					 ELSE CONVERT(DECIMAL(20,2), IIF(ISNULL(NULLIF(pt.PropertyValue, 0), pt.PurchasePrice) /*pt.propertyvalue*/ <= 1.00
									 , 0
									 , IIF(fapp.LoanToValue_ABS > 100.00 , 0, fapp.LoanGrossAmount_ABS / ISNULL(NULLIF(pt.PropertyValue, 0), IIF(pt.PurchasePrice = 0, pt.ImprovedValue, pt.PurchasePrice)) * 100)
									 )
								  )
					 END
, OriginalShareLTV = CONVERT(NUMERIC(6,2)
						, IIF(fapp.LoanAmount_ABS > pt.PurchasePrice
							, 0
							, ROUND((fapp.LoanAmount_ABS / NULLIF(pt.PurchasePrice,0) * 100), 2))
						)
, OriginalShareGrossLTV = CONVERT(NUMERIC(6,2)
						, IIF(fapp.LoanGrossAmount_ABS > pt.PurchasePrice
							, 0
							, ROUND((fapp.LoanGrossAmount_ABS / NULLIF(pt.PurchasePrice,0) * 100), 2))
						)
, LoanToPurchasePrice = CONVERT(NUMERIC(6,2), IIF(fapp.LoanGrossAmount_ABS > pt.PurchasePrice
																	 , 0
																	 , ROUND((fapp.LoanGrossAmount_ABS / NULLIF(pt.PurchasePrice,0) * 100), 2))
																)
, RetentionValue = CONVERT(DECIMAL(20,2), IIF(acc.AccountNo IS NULL
											, COALESCE(fapp.LoanRetention_ABS,0)
											, bal.RetentionAmount--COALESCE(acc.RetentionAmount_ABS,0)
											)
						)
, dapp.DIM_CO_Process_DWSK
, pt.Region
, sc.RNScore, sc.TMLScore
, SelfEmployedFlag = IIF(cust.EmploymentType = 'SelfEmployed', 1, 0)
, FirstTimeBuyer = ISNULL(ftb.FirstTimeBuyer, 0)
, dapp.DIPCreatedDate, dapp.DIPSubmitDate, dapp.DipAcceptDate, dapp.AppDate, dapp.UADate
, FullyPackagedDate = dapp.UADate
, dapp.ValInstructDate, dapp.ValReceiveDate
, dapp.FirstOfferDate, dapp.LatestOfferDate, dapp.ExpectedCompDate
, CompDate = ISNULL(dapp.CompDate, IIF(dapp.LatestStatus = 'Completed', CONVERT(DATE, CONVERT(VARCHAR, acc.AccountOpenDate)),NULL)) --change #25
, dapp.FeesReturnedDate
, dapp.RecompletionDate
, dapp.DeadDate

-- SERVICING
, acc.DIM_CO_Account_DWSK
, DIM_CO_ProdSegm_DWSK = IIF(dapp.Environment = 'Servicing', acc.DIM_CO_ProdSegm_DWSK, NULL)
, AccountNo = IIF(dapp.Environment = 'Servicing', acc.AccountNo, NULL) 
, AccountOpenDate = IIF(dapp.Environment = 'Servicing', acc.AccountOpenDate, NULL)
, AccountClosedDate = redempt.RedemptionDate
, ReversionDate = DATEADD(YEAR, CONVERT(INT, LEFT(acc.ProductDescription, 1)), CONVERT(DATE,CONVERT(VARCHAR, acc.FixedTermStart,102))) -- year first incase leap year
, acc.PTDate
, CurrentBalance = IIF(
					(dapp.LatestStatus = 'Completed' AND dapp.Environment = 'Origination')
					, NULL
					, IIF(redempt.RedemptionDate IS NULL, bal.PrincipalBalance, 0)
					) -- #Change 083
, ActualCurrentBalance = IIF(
							(dapp.LatestStatus = 'Completed' AND dapp.Environment = 'Origination')
							, NULL
							, ISNULL(IIF(redempt.RedemptionDate IS NULL, bal.CurrentBalance, 0), 0)
							) -- #Change 083
, InitialInterestRate = IIF(
							dapp.Environment = 'Servicing'
							, CONVERT(DECIMAL(4,2), acc.OpeningInterestRate)
							, NULL
						)
, InitialBaseRateCode =  IIF(
							dapp.Environment = 'Servicing'
							, acc.InitialBaseRateCode
							, NULL
						)
, InitialBaseRate = IIF(
						dapp.Environment = 'Servicing'
						, CONVERT(DECIMAL(4,2), acc.initialBaseRate)
						, NULL
					)
, InitialBaseRateMargin = IIF(
							dapp.Environment = 'Servicing'
							,CONVERT(DECIMAL(4,2), acc.OpeningInterestRate - acc.InitialBaseRate)
							, NULL
						)
, InterestRate = IIF(
					dapp.Environment = 'Servicing' AND redempt.RedemptionDate IS NULL 
					, CONVERT(DECIMAL(4,2), NULLIF(bal.InterestRate, 0))
					, NULL
				)
, BaseRateMargin = IIF(
						dapp.Environment = 'Servicing' AND redempt.RedemptionDate IS NULL
						, bal.InterestRate - bal.BaseRate
						, NULL
						)
, RevertMargin = CONVERT(DECIMAL(4,2), revertTablePT.revertMargin)
, ReversionRate = IIF(
						--AppDate.AppDate > '2020-10-21' OR reverttable.productcode >= 1925	
						dapp.AppDate > '2020-10-21' OR reverttablePT.productcode >= 1925				
						, IIF(dapp.LoanType = 'BTL'	
								, dr.TBRBTL + CONVERT(DECIMAL(4,2), revertTablePT.revertMargin)
								, dr.TBRRESI + CONVERT(DECIMAL(4,2), revertTablePT.revertMargin)
							)
						, CONVERT(NUMERIC(4,2), dr.BBR + revertTablePT.RevertMargin)	
					)
, APR = fapp.Apr_ABS
, ValuationHPI = hpiVal.HPI
, CILTV = IIF(redempt.RedemptionDate IS NULL AND ISNULL(bal.CurrentBalance, 0) > 0, -- change #43,
			 IIF(
				hpiVal.HPI IS NULL
				, IIF(dapp.LoanType = 'Residential' AND dapp.DIPCreatedDate <= '2021-01-25' , bal.PrincipalBalance, bal.CurrentBalance) / ISNULL(NULLIF(pt.PropertyValue, 0), IIF(pt.PurchasePrice = 0, pt.ImprovedValue, pt.PurchasePrice))
				, IIF(dapp.LoanType = 'Residential' AND dapp.DIPCreatedDate <= '2021-01-25' , bal.PrincipalBalance, bal.CurrentBalance) / (ISNULL(NULLIF(pt.PropertyValue, 0), IIF(pt.PurchasePrice = 0, pt.ImprovedValue, pt.PurchasePrice)) / hpiVal.HPI * COALESCE(hpiRecent.HPI, hpiVal.HPI))
			 )
		 , 0
		)
, CIValuation = IIF(
			 hpiVal.HPI IS NULL
			 , pt.PropertyValue
			 , CONVERT(MONEY, (ISNULL(NULLIF(pt.PropertyValue, 0), pt.PurchasePrice) / hpiVal.HPI * COALESCE(hpiRecent.HPI, hpiVal.HPI)))
			 )
, CIShareLTV = IIF(redempt.RedemptionDate IS NULL AND ISNULL(bal.CurrentBalance, 0) > 0
					, IIF(hpiVal.HPI IS NULL
						, IIF(dapp.LoanType = 'Residential' AND dapp.DIPCreatedDate <= '2021-01-25' , bal.PrincipalBalance, bal.CurrentBalance) / pt.PurchasePrice
						, IIF(dapp.LoanType = 'Residential' AND dapp.DIPCreatedDate <= '2021-01-25' , bal.PrincipalBalance, bal.CurrentBalance) / (NULLIF(pt.PurchasePrice, 0) / hpiVal.HPI * COALESCE(hpiRecent.HPI, hpiVal.HPI))
						)
					, 0
				)
, CIShareValue = IIF(
					hpiVal.HPI IS NULL
					, pt.PurchasePrice
					, CONVERT(MONEY, NULLIF(pt.PurchasePrice, 0) / hpiVal.HPI * COALESCE(hpiRecent.HPI, hpiVal.HPI))
					)
, SCDStatus = IIF(@reportDate = CONVERT(DATE, DATEADD(d, -1, GETDATE())), 'C', 'H')

-- SECURITISATION INFO			
, Securitised = IIF(dapp.LatestStatus <> 'Completed', NULL, ISNULL(secs.Securitised, 0))
, SecuritisedDate = IIF(secs.Securitised = 1, secs.SecuritisedDate, NULL)
, SecuritisationTag = IIF(
						dapp.LatestStatus <> 'Completed' OR  (dapp.LatestStatus = 'Completed' AND dapp.Environment = 'Origination')
						, NULL
						, ISNULL(secs.SecuritisationTag, 'Balance Sheet')
					)-- #Change 083 
, secs.SecuritisationName -- OK 
, SecuritisationStatus = IIF(dapp.LatestStatus <> 'Completed' OR (dapp.LatestStatus = 'Completed' AND dapp.Environment = 'Origination')
							, NULL
							, ISNULL(secs.SecuritisationStatus, 'Balance Sheet')
						  ) -- OK -- #Change 083
, SecuritisationFlag = IIF(
						dapp.LatestStatus <> 'Completed' OR (dapp.LatestStatus = 'Completed' AND dapp.Environment = 'Origination')
						, NULL
						, ISNULL(secs.SecuritisationFlag, 'BS')
						) -- #Change 083
, dapp.ExcludeFromSecuritisation
--, presub.PreFMASubmittedDate
--, PreFMASubFlag =  IIF(presub.PreFMASubmittedDate IS NULL, 0, 1)
, dapp.OfferExpiryDate
, dapp.InitialValDate
, CASE WHEN ld.IsSaleAdvised = 1 THEN 'Yes'
	   WHEN ld.IsSaleAdvised = 0 THEN 'No'
	   WHEN ld.IsSaleAdvised IS NULL THEN 'Unknown'
  END AS IsSaleAdvised

, OriginatorSource = 'TML'
, ReportToSB = CONVERT(INT, NULL)
, BalanceClosedDate = CAST(NULL AS DATE)	--= CASE WHEN app.ActualCurrentBalance = 0 AND BalanceClosed IS NULL
, Shortfall = NULL	
, CashBalance = bal.CurrentBalance
INTO #apps
----------------------------------------------------------------------------------------
--	 
-- ORIGINATION DATA
--
FROM #dimcoApps dapp
INNER JOIN DPR_DW..FACT_CO_Application fapp ON dapp.DIM_CO_Application_SSK = fapp.FACT_CO_Application_SSK		

-- get addiitional data from synonymns that might be misin on warehouse tables
INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFMA_FMAApplication synApp ON dapp.ApplicationRef = synApp.ApplicationRef COLLATE DATABASE_DEFAULT 

INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFMA_FMALoanDetails ld ON synApp.Id = ld.ApplicationId

-- MORTGAGE TYPE - CHECK FOR NEW PRODUCTS
LEFT JOIN TML_DW.dbo.vw_MortgageType mtype ON dapp.ApplicationRef = mtype.ApplicationRef COLLATE DATABASE_DEFAULT

-- FIRST TIME BUYER CHECK
LEFT OUTER JOIN (
    SELECT ApplicationRef, IIF(SUM(FTBFlag) > 0, 1, 0) AS FirstTimeBuyer
    FROM TML_DW..tbl_Applicants
    GROUP BY ApplicationRef
) ftb
    ON dapp.ApplicationRef = ftb.ApplicationRef COLLATE DATABASE_DEFAULT

-- SELF EMPLOYED FLAG
LEFT OUTER JOIN TML_DW.dbo.tbl_Applicants cust ON dapp.ApplicationRef = cust.ApplicationRef COLLATE DATABASE_DEFAULT
									   AND cust.BoEAppNo = 1

LEFT OUTER JOIN #oprod oprod ON dapp.ApplicationRef = oprod.ApplicationRef COLLATE DATABASE_DEFAULT

-- Product Tier BEWARE THE FIELD IN DIM_CO_APPLICATION DUE TO UPDATE MISMATCHES
LEFT OUTER JOIN (
	   SELECT dapp.ApplicationRef, synprod.ProductCategory COLLATE DATABASE_DEFAULT AS ProductCode
	   FROM #dimcoApps dapp
	   INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMALoanDetails syndets ON dapp.DIM_CO_Application_SSK = CAST(syndets.ApplicationId AS VARCHAR(50)) COLLATE DATABASE_DEFAULT
	   INNER JOIN DPR_DW.Latest_Orig_BoM.dbo_morAppFma_FMAProduct synprod ON syndets.Id = synprod.LoanDetailsId
) tiertable
	   ON dapp.ApplicationRef = tiertable.ApplicationRef

LEFT OUTER JOIN TML_DW.dbo.tbl_PropertyDetails pt ON dapp.DIM_CO_Application_DWSK = pt.DIM_CO_Application_DWSK --COLLATE DATABASE_DEFAULT
														AND pt.OriginationSource = 'TML'

-- GET THE SCORES FROM EQUIFAX AND TML INTERNALLY CALULATED
LEFT OUTER JOIN dbo.tbl_CreditRefLatest sc ON dapp.ApplicationRef = sc.ApplicationRef COLLATE DATABASE_DEFAULT


CROSS APPLY TML_DW.dbo.fn_DailyRates(CONVERT(DATE, CONVERT(VARCHAR(10), @cobid))) dr 

-----------------------------------------------------------------------------------------
----	 
----	SERVICING DATA
----

LEFT OUTER JOIN #accs acc ON dapp.ApplicationRef = acc.AccountNo COLLATE DATABASE_DEFAULT
							--AND acc.LoanTermStartDate >= ISNULL(comp.FeesReturnedDate, '1999-12-31')
							AND acc.LoanTermStartDate >= ISNULL(dapp.FeesReturnedDate, '1999-12-31')

LEFT OUTER JOIN dbo.fn_AccountDailySnapshot(@cobID, NULL) bal ON acc.AccountNo = bal.AccountNo COLLATE DATABASE_DEFAULT

-------------------------------------------------------------------------
----
----    get any product features. - get now using the product code on synonym product tables as DIM_CO can be out pf sync
----
--/*
LEFT OUTER JOIN TML_DW.dbo.vw_ProductFeatures prodFeatures ON COALESCE(acc.ProductCode, oprod.ProductCode) = prodFeatures.variantCode COLLATE DATABASE_DEFAULT
 
------------------------------------------------------------------------
----
----    Reversion rates. same as daily function calucultor.
----    Will be calculated on output using the revert rate and base rate
----

LEFT OUTER JOIN (
	SELECT  ProductCode, tier, ltv, (RevertAdd*100) AS RevertMargin
	FROM TML_DW.dbo.tbl_Products
) reverttable 
	ON COALESCE(acc.ProductCodeV1, oprod.ProductCode) = reverttable.ProductCode

LEFT OUTER JOIN (
	SELECT  ProductCode, tier, ltv, (RevertAdd*100) AS RevertMargin
	FROM TML_DW.dbo.tbl_Products
) reverttablePT 
	ON COALESCE(acc.ProductCode, oprod.ProductCode) = reverttablePT.ProductCode

---------------------------------------------------------------------------
----
----	   HPI data - current index valuations
----

-- original Index at valuation												-- original Index at valuation
LEFT OUTER JOIN TML_DW.dbo.tbl_HomePriceIndex hpiVal  ON DATEPART(q, pt.ValuationDate) = hpiVal.Quarter
																AND DATEPART(yyyy, pt.ValuationDate) = hpiVal.Year
																--AND pt.Region = hpiVal.Region COLLATE DATABASE_DEFAULT
																AND pt.Region = RTRIM(REPLACE(REPLACE(hpiVal.Region, CHAR(13), ''), CHAR(10), '')) COLLATE DATABASE_DEFAULT

-- most recent index valuation 
LEFT OUTER JOIN TML_DW.dbo.tbl_HomePriceIndex hpiRecent ON DATEPART(q, DATEADD(m, -3, @reportDate)) = hpiRecent.Quarter
																AND DATEPART(yyyy, DATEADD(m, -3, @reportDate)) = hpiRecent.Year
																--AND pt.Region = hpiRecent.Region COLLATE DATABASE_DEFAULT
																AND pt.Region = RTRIM(REPLACE(REPLACE(hpiRecent.Region, CHAR(13), ''), CHAR(10), '')) COLLATE DATABASE_DEFAULT

-------------------------------------------------------------------------------------------
----
----    Redemptions - closed accounts
----
LEFT OUTER JOIN TML_DW.dbo.vw_Redemptions redempt ON acc.AccountNo = redempt.AccountNo COLLATE DATABASE_DEFAULT

-------------------------------------------------------------------------------------------
----
----  Securitisation 
----

-- securitisaton details - use row number to get latest as this is for cob yesterday. Faster than using dates bewtween
LEFT OUTER JOIN (
	SELECT sp.AccountNo, s.Securitised, sp.SecuritisationStatus, s.SecuritisationFlag, s.SecuritisationName, s.SecuritisationTag
	, s.SecuritisationID
	, SecuritisedDate = CONVERT(DATE, CONVERT(VARCHAR(10), sp.SecuritisedDate))
	, LatestOrder = ROW_NUMBER() OVER (PARTITION BY sp.AccountNo ORDER BY sp.SecuritisedDate DESC)
	FROM TML_DW.dbo.tbl_SecuritisedPool sp
	INNER JOIN TML_DW.dbo.tbl_Securitisations s ON sp.SecuritisationId = s.SecuritisationID
	WHERE sp.TransferOutDate > @reportDate 
) secs	
	ON acc.AccountNo = secs.AccountNo
		AND secs.LatestOrder = 1
---------------------------------------------------------------------------

OPTION (RECOMPILE);

-----------------

-- fill in funder and Report to Shawbrook flag
UPDATE #apps
SET ReportToSB = IIF(LoanType <> 'Residential' AND CompDate IS NOT NULL , 1, 0) -- need to see anything that has touched their books even
;

-- tidy up in case completed case has 0 for Original LTV
UPDATE #apps
SET OriginalLTV = LoanAmount / Valuation
WHERE AccountNo IS NOT NULL
AND OriginalLTV = 0;

-----------------------------------------------------------------------
-----------------------------------------------------------------------
/* 
	 ERROR CHECKING AND REBUILD OF TABLE
*/
-- check that there are no duplicate application ref before dropping existing. primary key violation
DECLARE @dupCheck VARCHAR(500);
DECLARE @errorMessage VARCHAR(500);
DECLARE @rows INT;
DECLARE @updateTable VARCHAR(50);

SET @updateTable = 'tbl_Applications';

-- check if empty table. Would suggest issue with applications feed
SELECT @rows = ISNULL(COUNT(*), 0) 
FROM #apps;

IF @rows = 0
BEGIN
	 SET @errorMessage = 'Empty Table Error - ' + ISNULL(@updateTable, '') + ' population was empty. Not updated for latest day';
END

;WITH dups 
AS (
	 SELECT TOP 1 ApplicationRef
	 FROM #apps
	 GROUP BY ApplicationRef
	 HAVING COUNT(*) > 1
)
SELECT @dupCheck = dups.ApplicationRef
FROM dups;

IF @dupCheck IS NOT NULL
BEGIN
	 SET @errorMessage = 'Duplicate Primary Key Error - ' + ISNULL(@updateTable, '') + ' population had duplicate Application Reference (' + @dupCheck + '). Not updated for latest day';
END;


-- if no issues then we can delete and rebuild existing table
IF @errorMessage IS NULL
BEGIN 

	 --------------------------------------------------
	 --CHANGE #11
	 --DISABLE the foreign key constraint to the portfolio table - Could have just rebuilt table so recreate if not exists. 
	 IF OBJECT_ID('dbo.[fk_AppPortAppRef]') IS NULL 
	 BEGIN
		  ALTER TABLE dbo.tbl_ApplicantPortfolios WITH CHECK ADD CONSTRAINT fk_AppPortAppRef FOREIGN KEY(ApplicationRef)
		  REFERENCES dbo.tbl_Applications (ApplicationRef)
	 END

	 ALTER TABLE tbl_ApplicantPortfolios
	 NOCHECK CONSTRAINT fk_AppPortAppRef;

	 --------------------------------------------------

	 -- empty the table
	 DELETE TML_DW.dbo.tbl_Applications
	 WHERE OriginationSource = 'TML';


	--------------------------------------------------
	 -- Track applications that are closed, but with Residual Balance
	INSERT INTO TML_DW.dbo.tbl_AccountResidualBalance
	SELECT	ReportDate = a.AccountClosedDate, a.ApplicationRef, a.AccountNo, a.AccountClosedDate, a.BalanceClosedDate, a.ActualCurrentBalance, a.CashBalance
	FROM #apps a 
	LEFT JOIN TML_DW.dbo.tbl_AccountResidualBalance arb ON a.ApplicationRef COLLATE DATABASE_DEFAULT = arb.ApplicationRef COLLATE DATABASE_DEFAULT AND a.AccountNo = arb.AccountNo 
	WHERE arb.ApplicationRef IS NULL
	  AND a.AccountClosedDate IS NOT NULL
	  AND a.AccountOpenDate IS NOT NULL
	  AND (
	        ISNULL(a.ActualCurrentBalance, 0) <> 0
	        OR ISNULL(a.CashBalance, 0) <> 0
	      );

	-- Update balance closed date for applications with no more residual balance in #FinalData (tbl_Applications)
		
	UPDATE a
	SET a.BalanceClosedDate = @reportDate
	FROM #apps a
	INNER JOIN TML_DW.dbo.tbl_AccountResidualBalance arb ON a.ApplicationRef COLLATE DATABASE_DEFAULT = arb.ApplicationRef COLLATE DATABASE_DEFAULT AND a.AccountNo = arb.AccountNo
	WHERE a.AccountClosedDate IS NOT NULL
	  AND a.AccountOpenDate IS NOT NULL
	  AND ISNULL(a.ActualCurrentBalance, 0) = 0
	  AND ISNULL(a.CashBalance, 0) = 0
	  AND (
	        ISNULL(arb.ActualCurrentBalance, 0) <> 0
	        OR ISNULL(arb.CashBalance, 0) <> 0
	      )
	  AND a.BalanceClosedDate IS NULL;

	  UPDATE a
		SET a.BalanceClosedDate = a.AccountClosedDate
		FROM #apps a 
		LEFT JOIN TML_DW.dbo.tbl_AccountResidualBalance arb ON a.ApplicationRef COLLATE DATABASE_DEFAULT = arb.ApplicationRef COLLATE DATABASE_DEFAULT
																		AND a.AccountNo = arb.AccountNo
		WHERE a.AccountClosedDate IS NOT NULL
		  AND arb.ApplicationRef IS NULL;

	-- Update balance closed date for applications with no more residual balance in tbl_AccountResidualBalance/Update both balances together, and only close when both are zero:
	UPDATE arb
	SET
	    arb.BalanceClosedDate = a.BalanceClosedDate,
	    arb.ActualCurrentBalance = a.ActualCurrentBalance,
	    arb.CashBalance = a.CashBalance
	FROM TML_DW.dbo.tbl_AccountResidualBalance arb
	INNER JOIN #apps a ON a.ApplicationRef COLLATE DATABASE_DEFAULT = arb.ApplicationRef COLLATE DATABASE_DEFAULT AND a.AccountNo = arb.AccountNo
	WHERE a.AccountClosedDate IS NOT NULL
	  AND a.AccountOpenDate IS NOT NULL
	  AND ISNULL(a.ActualCurrentBalance, 0) = 0
	  AND ISNULL(a.CashBalance, 0) = 0
	  AND a.BalanceClosedDate = @reportDate;


	INSERT INTO TML_DW.dbo.tbl_Applications
	(
	ReportDate, COBID, ApplicationRef, DIM_CO_Application_DWSK, DIM_CO_Application_SSK, Environment, LoanType, RepaymentType, IsRegulated, LatestStatus, Applicants, CustomerType,
	MortgageType, ProductCode, Product, ProductTier, ProductMaxLTV, ProductFeature, ProductRange, TermInMonths, AppInterestRate, GrossYield, NetInterestMargin, AppBaseRate, 
	LoanAmount, OpeningCapitalBalance, Valuation, OriginalLTV, OriginalGrossLTV, LoanToPurchasePrice, RetentionValue, DIM_CO_Process_DWSK, Region, RNScore, TMLScore, SelfEmployedFlag, 
	FirstTimeBuyer, DIPCreatedDate, DIPSubmitDate, DipAcceptDate, AppDate, UADate, ValInstructDate, ValReceiveDate, FirstOfferDate, LatestOfferDate, ExpectedCompDate, CompDate, 
	FeesReturnedDate, RecompletionDate, DeadDate, DIM_CO_Account_DWSK, DIM_CO_ProdSegm_DWSK, AccountNo, AccountOpenDate, AccountClosedDate, ReversionDate, PTDate, CurrentBalance,
	ActualCurrentBalance, InitialInterestRate, InitialBaseRateCode, InitialBaseRate, InitialBaseRateMargin, InterestRate, BaseRateMargin, RevertMargin, ReversionRate, APR, ValuationHPI,
	CILTV, CIValuation, SCDStatus, Securitised, SecuritisedDate, SecuritisationName, SecuritisationStatus, SecuritisationFlag, SecuritisationTag,  ExcludeFromSecuritisation, OfferExpiryDate,
	InitialValDate, IsSaleAdvised, OriginalShareLTV, OriginalShareGrossLTV, CIShareValue, CIShareLTV, OriginationSource, Funder, FullyPackagedDate, ReportToSB, BalanceClosedDate, Shortfall, CashBalance
	)
	SELECT DISTINCT ReportDate, COBID, ApplicationRef, DIM_CO_Application_DWSK, DIM_CO_Application_SSK, Environment, LoanType, RepaymentType, IsRegulated, LatestStatus, Applicants,
	CustomerType, MortgageType, ProductCode, Product, ProductTier, ProductMaxLTV, ProductFeature, ProductRange, TermInMonths, AppInterestRate, GrossYield, NetInterestMargin, 
	AppBaseRate, LoanAmount, OpeningCapitalBalance, Valuation, OriginalLTV, OriginalGrossLTV, LoanToPurchasePrice, RetentionValue, DIM_CO_Process_DWSK, Region, RNScore, TMLScore, 
	SelfEmployedFlag, FirstTimeBuyer, DIPCreatedDate, DIPSubmitDate, DipAcceptDate, AppDate, UADate, ValInstructDate, ValReceiveDate, FirstOfferDate, LatestOfferDate, ExpectedCompDate,
	CompDate, FeesReturnedDate, RecompletionDate, DeadDate, DIM_CO_Account_DWSK, DIM_CO_ProdSegm_DWSK, AccountNo, AccountOpenDate, AccountClosedDate, ReversionDate, PTDate, CurrentBalance, 
	ActualCurrentBalance, InitialInterestRate, InitialBaseRateCode, InitialBaseRate, InitialBaseRateMargin, InterestRate, BaseRateMargin, RevertMargin, ReversionRate, APR, ValuationHPI, 
	CILTV, CIValuation , SCDStatus , Securitised, SecuritisedDate, SecuritisationName, SecuritisationStatus, SecuritisationFlag, SecuritisationTag, ExcludeFromSecuritisation, 
	OfferExpiryDate, InitialValDate , IsSaleAdvised, a.OriginalShareLTV, a.OriginalShareGrossLTV, a.CIShareValue, a.CIShareLTV, OriginatorSource = 'TML',
	Funder = CASE WHEN a.LoanType = 'Residential' THEN '24AM'
					WHEN a.LoanType = 'BTL' THEN 'Shawbrook'
					ELSE 'Shawbrook'
				END,
	a.FullyPackagedDate, a.ReportToSB, a.BalanceClosedDate,	a.Shortfall, a.CashBalance
	FROM #apps a;

	---------------------------------------------------
		
	 -- Update Gross Yield

	 	UPDATE app
		SET app.GrossYield = ISNULL(ROUND((((CONVERT(DECIMAL(10,2), appf.AppInterestRate))/100)-appf.AppFeePerc+appf.NetValFeePerc+appf.CompFeePerc+appf.TTFeePerc+appf.ERCPerc-appf.ProcFeePerc-appf.CashbackPerc)*100,2), 0.00)
		FROM  TML_DW.dbo.[tbl_Applications] app
		INNER JOIN 
			(SELECT apps.applicationRef, 
					apps.AppInterestRate,
					afa.AppFeePerc, 
					afa.NetValFeePerc,
					afa.CompFeePerc,
					afa.TTFeePerc,
					afa.ERCPerc,
					afa.ProcFeePerc,
					afa.CashbackPerc
				  FROM TML_DW.dbo.[tbl_Applications] apps
				  INNER JOIN TML_DW.dbo.[vw_AppFeeAnalysis] afa ON apps.ApplicationRef = afa.ApplicationRef COLLATE DATABASE_DEFAULT
				  WHERE apps.AppDate IS NOT NULL
			 ) as appf ON app.ApplicationRef = appf.ApplicationRef ;

	 -- Update the Net Interest Margin 

		UPDATE app
		SET app.NetInterestMargin = CONVERT(DECIMAL(10,2), ISNULL(appcof.NIM, 0.00))
		FROM  TML_DW.dbo.[tbl_Applications] app
		INNER JOIN 
			(SELECT apps.applicationRef, 
					NIM =COALESCE(GrossYield, 0) -  IIF(apps.Product LIKE ('2%'), CoF2YearRates, IIF(apps.Product LIKE ('5%'), CoF5YearRates, 0.00))
				  FROM TML_DW.dbo.[tbl_Applications] apps
				  LEFT OUTER JOIN TML_DW.dbo.tbl_CostOfFunds cof ON EOMONTH(apps.appdate) = CoF.MonthEnd
				 ) appcof
		ON app.ApplicationRef = appcof.ApplicationRef ;

	---------------------------------------------------
	 --CHANGE #11
	 --ENABLE the foreign key constraint to the portfolio table
	 ALTER TABLE dbo.tbl_ApplicantPortfolios
	 CHECK CONSTRAINT fk_AppPortAppRef;

	---------------------------------------------------
	---------------------------------------------------

	EXEC dbo.sp_PopulateGYNIM @OriginationSource = 'TML'-- varchar(3)

	 --APPLY OVERRIDES
	 EXEC sp_OverrideTableValues @updateTable

END;
ELSE -- error has occured
BEGIN
	 -- it there is an issue insert into the stored procedures issue log to be addressed in the morning
	 INSERT INTO dbo.log_StoredProcedureErrors(ErrorNumber, ErrorDescription, ErrorProcedure, ErrorState, ErrorSeverity, ErrorLine, ErrorTime)
	 VALUES( '0000'       -- ErrorNumber - varchar(50)
				 , @errorMessage      -- ErrorDescription - varchar(4000)
				 , @procedureName    -- ErrorProcedure - varchar(100)
				 ,1,0,0, GETDATE() 	 );
		SELECT @errorMessage;

END;

-----------------------------------------------------------------------------------------------------
---- END & ERROR CATCHING
-----------------------------------------------------------------------------------------------------

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


