GO
if object_id('[dbo].[sp_CompanySalarySummary]') is null
	EXEC ('CREATE PROCEDURE [dbo].[sp_CompanySalarySummary] as select 1')
GO

ALTER PROCEDURE [dbo].[sp_CompanySalarySummary]
(
	@LoginID INT = null,
	@month INT= null,
	@year int= null,
	@LanguageID varchar(5) = 'EN',
	@IsExport bit =0
)
as
begin
	set nocount on;
	declare @FromDate datetime, @ToDate datetime
	SELECT @FromDate = FromDate, @ToDate = ToDate FROM dbo.fn_Get_SalaryPeriod(@Month, @Year)

	select EmployeeID,FullName,HireDate,ProbationEndDate,DivisionID,DepartmentID,SectionID,GroupID,PositionID
		,EmployeeStatusID,EmployeeTypeID,LastWorkingDate,AccountNo
	into #tblEmployeeTmpList
	from dbo.fn_vtblEmployeeList_Simple_ByDate(@ToDate,'-1',@LoginID) te where DivisionID <> 1

	delete #tblEmployeeTmpList where HireDate > @ToDate or LastWorkingDate < @FromDate
	delete e from #tblEmployeeTmpList e where exists(select 1 from tblDivision as di where di.DivisionID=e.DivisionID and (di.IsNotSalCal=1 or di.Istemp=1))
	--Lương
	select * into #tblSal_Sal from tblSal_Sal where Month=@Month and year=@Year and exists(select 1 from #tblEmployeeTmpList e where e.EmployeeID=tblSal_Sal.EmployeeID)
	-- OT 
	SELECT EmployeeID,
		SUM(CASE WHEN OTRate = 150 THEN OTHour ELSE 0 END) AS OT15_Hour,
		SUM(CASE WHEN OTRate = 150 THEN OTAmount ELSE 0 END) AS OT15_Amount,
		SUM(CASE WHEN OTRate = 200 THEN OTHour ELSE 0 END) AS OT20_Hour,
		SUM(CASE WHEN OTRate = 200 THEN OTAmount ELSE 0 END) AS OT20_Amount,
		SUM(CASE WHEN OTRate = 300 THEN OTHour ELSE 0 END) AS OT30_Hour,
		SUM(CASE WHEN OTRate = 300 THEN OTAmount ELSE 0 END) AS OT30_Amount
	INTO #OT
	FROM tblSal_OT_Detail
	WHERE Month = @month AND Year = @year
	  AND EXISTS(SELECT 1 FROM #tblEmployeeTmpList te WHERE tblSal_OT_Detail.EmployeeID = te.EmployeeID)
	GROUP BY EmployeeID
	-- Allowances
	SELECT al.EmployeeID,
		SUM(CASE WHEN als.AllowanceCode = 'Qualification_AL' THEN al.Amount ELSE 0 END) AS Qualifi,
		SUM(CASE WHEN als.AllowanceCode = 'Pos_AL' THEN al.Amount ELSE 0 END) AS Position,
		SUM(CASE WHEN als.AllowanceCode = 'Responsibility_AL' THEN al.Amount ELSE 0 END) AS Responsibilit,
		SUM(CASE WHEN als.AllowanceCode = 'Livingsupport1_AL' THEN al.Amount ELSE 0 END) AS Living_support_1,
		SUM(CASE WHEN als.AllowanceCode = 'Language_AL' THEN al.Amount ELSE 0 END) AS Language,
		SUM(CASE WHEN als.AllowanceCode = 'Transport_AL' THEN al.Amount ELSE 0 END) AS Transport,
		SUM(CASE WHEN als.AllowanceCode = 'PerfectAtt' THEN al.Amount ELSE 0 END) AS Perfect_Att,
		SUM(CASE WHEN als.AllowanceCode NOT IN ('Qualification_AL', 'Pos_AL', 'Responsibility_AL', 'Livingsupport1_AL', 'Language_AL', 'Transport_AL', 'PerfectAtt') THEN al.Amount ELSE 0 END) AS Others
	INTO #Allowances
	FROM tblSal_Allowance al
	INNER JOIN tblAllowanceSetting als ON al.AllowanceID = als.AllowanceID
	WHERE al.Month = @month AND al.Year = @year AND ISNULL(al.Amount,0) <> 0 AND ISNULL(al.TakeHome, 1) = 1
	  AND EXISTS(SELECT 1 FROM #tblEmployeeTmpList te WHERE al.EmployeeID = te.EmployeeID)
	GROUP BY al.EmployeeID
	
	-- Adjustments
	SELECT al.EmployeeID,
		SUM(CASE WHEN ir.IncomeKind = 1 AND ISNULL(ir.Taxable,0) = 1 THEN al.Amount ELSE 0 END) AS TaxableAdd,
		SUM(CASE WHEN ir.IncomeKind = 1 AND ISNULL(ir.Taxable,0) = 0 THEN al.Amount ELSE 0 END) AS NontaxAdd,
		SUM(CASE WHEN ir.IncomeKind = 0 AND al.IncomeID = 33 THEN al.Amount ELSE 0 END) AS EL_Deduct, 
		SUM(CASE WHEN ir.IncomeKind = 0 AND ISNULL(ir.Taxable,0) = 1 AND al.IncomeID <> 33 THEN al.Amount ELSE 0 END) AS OtherDeduct,
		SUM(CASE WHEN ir.IncomeKind = 0 AND ISNULL(ir.Taxable,0) = 0 THEN al.Amount ELSE 0 END) AS NontaxDeduct
	INTO #Adjustments
	FROM tblSal_Adjustment al
	INNER JOIN tblIrregularIncome ir ON ir.IncomeID = al.IncomeID
	WHERE al.Month = @month AND al.Year = @year
	  AND EXISTS(SELECT 1 FROM #tblEmployeeTmpList te WHERE al.EmployeeID = te.EmployeeID)
	GROUP BY al.EmployeeID

	-- In Late / Out Early (Hours)
	SELECT EmployeeID,
		SUM(CASE WHEN IOKind = 1 THEN IOMinutesDeduct ELSE 0 END) / 60.0 AS LA_Hour,
		SUM(CASE WHEN IOKind = 2 THEN IOMinutesDeduct ELSE 0 END) / 60.0 AS EL_Hour
	INTO #IO
	FROM tblInLateOutEarly
	WHERE StatusID = 1 AND MONTH(IODate) = @month AND YEAR(IODate) = @year and ApprovedDeduct = 1
	  AND EXISTS(SELECT 1 FROM #tblEmployeeTmpList te WHERE tblInLateOutEarly.EmployeeID = te.EmployeeID)
	GROUP BY EmployeeID

	--View dữ liệu
	SELECT ROW_NUMBER() OVER(ORDER BY CASE WHEN TRY_CAST(e.EmployeeID AS INT) IS NOT NULL THEN TRY_CAST(e.EmployeeID AS INT) ELSE 999999999 END, e.EmployeeID) AS [No],
		e.EmployeeID AS Emp_ID,
		e.FullName AS Employee_Name,
		emp.Sex AS Sex,
		ISNULL(sdet.ActualMonthlyBasic, 0) AS BasicIncome,
		ISNULL(sdet.DaysOfSalEntry, 0) AS Workdays,
		ISNULL(ot.OT15_Hour, 0) AS [1_5],
		ISNULL(ot.OT15_Amount, 0) AS Amount1,
		ISNULL(ot.OT20_Hour, 0) AS [2],
		ISNULL(ot.OT20_Amount, 0) AS Amount2,
		ISNULL(ot.OT30_Hour, 0) AS [3],
		ISNULL(ot.OT30_Amount, 0) AS Amount3,
		ISNULL(ns.NSHours, 0) AS NS_Hour,
		ISNULL(ns.NSAmount, 0) AS NS_Amount,
		ISNULL(al.Qualifi, 0) AS Qualifi_,
		ISNULL(al.Position, 0) AS Position,
		ISNULL(al.Responsibilit, 0) AS Responsibilit,
		ISNULL(al.Living_support_1, 0) AS Living_support_1,
		ISNULL(al.Language, 0) AS Language,
		ISNULL(al.Transport, 0) AS Transport,
		ISNULL(al.Perfect_Att, 0) AS Perfect_Att,
		ISNULL(al.Others, 0) + ISNULL(adj.TaxableAdd, 0) AS Others,
		(ISNULL(sdet.ActualMonthlyBasic, 0) + ISNULL(ot.OT15_Amount, 0) + ISNULL(ot.OT20_Amount, 0) + ISNULL(ot.OT30_Amount, 0) + ISNULL(ns.NSAmount, 0) + ISNULL(al.Qualifi, 0) + ISNULL(al.Position, 0) + ISNULL(al.Responsibilit, 0) + ISNULL(al.Living_support_1, 0) + ISNULL(al.Language, 0) + ISNULL(al.Transport, 0) + ISNULL(al.Perfect_Att, 0) + ISNULL(al.Others, 0) + ISNULL(adj.TaxableAdd, 0)) AS TotalIncome,
		ISNULL(ins.EmployeeSI, 0) AS Social_Ins8Percent,
		ISNULL(ins.EmployeeHI, 0) AS Health_Ins1_5Percent,
		ISNULL(ins.EmployeeUI, 0) AS Jobless_Ins1Percent1,
		CASE WHEN ISNULL(sdet.StandardWDays, 0) > ISNULL(sdet.DaysOfSalEntry, 0) THEN ISNULL(sdet.StandardWDays, 0) - ISNULL(sdet.DaysOfSalEntry, 0) ELSE 0 END AS Leave1,
		ISNULL(io.LA_Hour, 0) AS LA1,
		ISNULL(io.EL_Hour, 0) AS EL1,
		ISNULL(sdet.UnpaidLeaveAmount, 0) AS Leave2,
		0 AS LA2,
		ISNULL(adj.EL_Deduct, 0) AS EL2,
		ISNULL(sal.EmpUnion, 0) AS Union_Fee,
		0 AS Work_Off_70,
		ISNULL(adj.OtherDeduct, 0) AS OtherDeduction,
		(ISNULL(ins.EmployeeSI, 0) + ISNULL(ins.EmployeeHI, 0) + ISNULL(ins.EmployeeUI, 0) + ISNULL(sdet.UnpaidLeaveAmount, 0) + ISNULL(adj.EL_Deduct, 0) + ISNULL(sal.EmpUnion, 0) + ISNULL(adj.OtherDeduct, 0) + ISNULL(tax.TaxAmt, 0)) AS TotalDeduction,
		ISNULL(tax.IncomeTaxable, 0) AS TaxableIncome,
		ISNULL(tax.TaxAmt, 0) AS Tax,
		ISNULL(adj.NontaxAdd, 0) AS NontaxAllowance,
		ISNULL(adj.NontaxDeduct, 0) AS NontaxDeduction,
		ISNULL(sal.GrossTakeHome, 0) AS NetPayment,
		ISNULL(ins.CompanySI, 0) AS Social_Ins17_5Percent,
		ISNULL(ins.CompanyHI, 0) AS Health_Ins3Percent,
		ISNULL(ins.CompanyUI, 0) AS Jobless_Ins1Percent2,
		ROW_NUMBER() OVER(ORDER BY CASE WHEN TRY_CAST(e.EmployeeID AS INT) IS NOT NULL THEN TRY_CAST(e.EmployeeID AS INT) ELSE 999999999 END, e.EmployeeID) AS RowIndex
	INTO #ExportData
	FROM #tblEmployeeTmpList e
	LEFT JOIN tblEmployee emp ON e.EmployeeID = emp.EmployeeID
	LEFT JOIN #tblSal_Sal sal ON e.EmployeeID = sal.EmployeeID
	LEFT JOIN tblSal_Sal_Detail sdet ON e.EmployeeID = sdet.EmployeeID AND sdet.Month = @month AND sdet.Year = @year AND sdet.LatestSalEntry = 1
	LEFT JOIN #OT ot ON e.EmployeeID = ot.EmployeeID
	LEFT JOIN tblSal_NS ns ON e.EmployeeID = ns.EmployeeID AND ns.Month = @month AND ns.Year = @year
	LEFT JOIN #Allowances al ON e.EmployeeID = al.EmployeeID
	LEFT JOIN #Adjustments adj ON e.EmployeeID = adj.EmployeeID
	LEFT JOIN tblSal_Insurance ins ON e.EmployeeID = ins.EmployeeID AND ins.Month = @month AND ins.Year = @year AND ISNULL(ins.InsPaymentStatus,0) <> 7
	LEFT JOIN tblSal_Tax tax ON e.EmployeeID = tax.EmployeeID AND tax.Month = @month AND tax.Year = @year
	LEFT JOIN #IO io ON e.EmployeeID = io.EmployeeID
	--WHERE EXISTS(SELECT 1 FROM tblMonthlyPayrollCheckList m WHERE e.EmployeeID = m.EmployeeID 
	--AND m.Month = @month AND m.Year = @year AND m.isSalCal = 1) 
	--  AND ISNULL(sal.GrossTakeHome,0) > 0

	--SHEET 0: LIST TOTAL
	SELECT * FROM #ExportData ORDER BY [No]
	-- Lưu dữ liệu vào bảng thật để so sánh (Compare)
	IF OBJECT_ID('tblCompanySalaryExport_Compare') IS NOT NULL DROP TABLE tblCompanySalaryExport_Compare
	SELECT * INTO tblCompanySalaryExport_Compare FROM #ExportData

	-- EXPORT
	CREATE TABLE #ExportConfig(TableIndex varchar(max),RowIndex int,ColumnName nvarchar(200),
	ParseType nvarchar(Max),Position nvarchar(200),SheetIndex int,TestDescription nvarchar(max),WithHeader int,WithBestFit bit)

	INSERT INTO #ExportConfig(TableIndex,SheetIndex,ParseType,Position,WithHeader,TestDescription)
	VALUES(0,0,'Table','A7',0,N'Dữ liệu')

	SELECT * FROM #ExportConfig
end
GO
exec sp_CompanySalarySummary 3,3,2026,'VN'