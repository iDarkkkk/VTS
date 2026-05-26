USE Paradise_NPSV_TEST
GO

IF OBJECT_ID('sp_CompareSalaryWithImport') IS NOT NULL
	DROP PROCEDURE sp_CompareSalaryWithImport
GO

CREATE PROCEDURE sp_CompareSalaryWithImport
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        s.Emp_ID,
        s.Employee_Name,
        
        -- Basic Income (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.BasicIncome, 0) AS BasicIncome_System,
        ROUND(TRY_CAST(i.BasicIncome AS FLOAT), 0) AS BasicIncome_Import,
        ROUND(ISNULL(s.BasicIncome, 0), 0) - ROUND(ISNULL(TRY_CAST(i.BasicIncome AS FLOAT), 0), 0) AS BasicIncome_Diff,

        -- Workdays (Số công -> Làm tròn 2 số thập phân)
        ROUND(s.Workdays, 2) AS Workdays_System,
        ROUND(TRY_CAST(i.Workdays AS FLOAT), 2) AS Workdays_Import,
        ROUND(ISNULL(s.Workdays, 0), 2) - ROUND(ISNULL(TRY_CAST(i.Workdays AS FLOAT), 0), 2) AS Workdays_Diff,

        -- 1.5 Hours (Giờ -> Làm tròn 2 số thập phân)
        ROUND(s.[1_5], 2) AS OT15_System,
        ROUND(TRY_CAST(i.[1_5] AS FLOAT), 2) AS OT15_Import,
        ROUND(ISNULL(s.[1_5], 0), 2) - ROUND(ISNULL(TRY_CAST(i.[1_5] AS FLOAT), 0), 2) AS OT15_Diff,

        -- 1.5 Amount (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.Amount1, 0) AS OT15_Amount_System,
        ROUND(TRY_CAST(i.Amount1 AS FLOAT), 0) AS OT15_Amount_Import,
        ROUND(ISNULL(s.Amount1, 0), 0) - ROUND(ISNULL(TRY_CAST(i.Amount1 AS FLOAT), 0), 0) AS OT15_Amount_Diff,
        
        -- 2.0 Hours (Giờ -> Làm tròn 2 số thập phân)
        ROUND(s.[2], 2) AS OT20_System,
        ROUND(TRY_CAST(i.[2] AS FLOAT), 2) AS OT20_Import,
        ROUND(ISNULL(s.[2], 0), 2) - ROUND(ISNULL(TRY_CAST(i.[2] AS FLOAT), 0), 2) AS OT20_Diff,

        -- 2.0 Amount (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.Amount2, 0) AS OT20_Amount_System,
        ROUND(TRY_CAST(i.Amount2 AS FLOAT), 0) AS OT20_Amount_Import,
        ROUND(ISNULL(s.Amount2, 0), 0) - ROUND(ISNULL(TRY_CAST(i.Amount2 AS FLOAT), 0), 0) AS OT20_Amount_Diff,

        -- 3.0 Hours (Giờ -> Làm tròn 2 số thập phân)
        ROUND(s.[3], 2) AS OT30_System,
        ROUND(TRY_CAST(i.[3] AS FLOAT), 2) AS OT30_Import,
        ROUND(ISNULL(s.[3], 0), 2) - ROUND(ISNULL(TRY_CAST(i.[3] AS FLOAT), 0), 2) AS OT30_Diff,

        -- 3.0 Amount (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.Amount3, 0) AS OT30_Amount_System,
        ROUND(TRY_CAST(i.Amount3 AS FLOAT), 0) AS OT30_Amount_Import,
        ROUND(ISNULL(s.Amount3, 0), 0) - ROUND(ISNULL(TRY_CAST(i.Amount3 AS FLOAT), 0), 0) AS OT30_Amount_Diff,

        -- NS Hour (Giờ -> Làm tròn 2 số thập phân)
        ROUND(s.NS_Hour, 2) AS NS_Hour_System,
        ROUND(TRY_CAST(i.NS_Hour AS FLOAT), 2) AS NS_Hour_Import,
        ROUND(ISNULL(s.NS_Hour, 0), 2) - ROUND(ISNULL(TRY_CAST(i.NS_Hour AS FLOAT), 0), 2) AS NS_Hour_Diff,

        -- NS Amount (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.NS_Amount, 0) AS NS_Amount_System,
        ROUND(TRY_CAST(i.NS_Amount AS FLOAT), 0) AS NS_Amount_Import,
        ROUND(ISNULL(s.NS_Amount, 0), 0) - ROUND(ISNULL(TRY_CAST(i.NS_Amount AS FLOAT), 0), 0) AS NS_Amount_Diff,

        -- Qualifi (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.Qualifi_, 0) AS Qualifi_System,
        ROUND(TRY_CAST(i.Qualifi_ AS FLOAT), 0) AS Qualifi_Import,
        ROUND(ISNULL(s.Qualifi_, 0), 0) - ROUND(ISNULL(TRY_CAST(i.Qualifi_ AS FLOAT), 0), 0) AS Qualifi_Diff,
        
        -- Position (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.Position, 0) AS Position_System,
        ROUND(TRY_CAST(i.Position AS FLOAT), 0) AS Position_Import,
        ROUND(ISNULL(s.Position, 0), 0) - ROUND(ISNULL(TRY_CAST(i.Position AS FLOAT), 0), 0) AS Position_Diff,

        -- Responsibilit (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.Responsibilit, 0) AS Responsibilit_System,
        ROUND(TRY_CAST(i.Responsibilit AS FLOAT), 0) AS Responsibilit_Import,
        ROUND(ISNULL(s.Responsibilit, 0), 0) - ROUND(ISNULL(TRY_CAST(i.Responsibilit AS FLOAT), 0), 0) AS Responsibilit_Diff,

        -- Living_support_1 (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.Living_support_1, 0) AS Living_support_System,
        ROUND(TRY_CAST(i.Living_support_1 AS FLOAT), 0) AS Living_support_Import,
        ROUND(ISNULL(s.Living_support_1, 0), 0) - ROUND(ISNULL(TRY_CAST(i.Living_support_1 AS FLOAT), 0), 0) AS Living_support_Diff,
        
        -- Language (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.Language, 0) AS Language_System,
        ROUND(TRY_CAST(i.Language AS FLOAT), 0) AS Language_Import,
        ROUND(ISNULL(s.Language, 0), 0) - ROUND(ISNULL(TRY_CAST(i.Language AS FLOAT), 0), 0) AS Language_Diff,

        -- Transport (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.Transport, 0) AS Transport_System,
        ROUND(TRY_CAST(i.Transport AS FLOAT), 0) AS Transport_Import,
        ROUND(ISNULL(s.Transport, 0), 0) - ROUND(ISNULL(TRY_CAST(i.Transport AS FLOAT), 0), 0) AS Transport_Diff,

        -- Perfect_Att (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.Perfect_Att, 0) AS PerfectAtt_System,
        ROUND(TRY_CAST(i.Perfect_Att AS FLOAT), 0) AS PerfectAtt_Import,
        ROUND(ISNULL(s.Perfect_Att, 0), 0) - ROUND(ISNULL(TRY_CAST(i.Perfect_Att AS FLOAT), 0), 0) AS PerfectAtt_Diff,

        -- Others (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.Others, 0) AS Others_System,
        ROUND(TRY_CAST(i.Others AS FLOAT), 0) AS Others_Import,
        ROUND(ISNULL(s.Others, 0), 0) - ROUND(ISNULL(TRY_CAST(i.Others AS FLOAT), 0), 0) AS Others_Diff,

        -- TotalIncome (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.TotalIncome, 0) AS TotalIncome_System,
        ROUND(TRY_CAST(i.TotalIncome AS FLOAT), 0) AS TotalIncome_Import,
        ROUND(ISNULL(s.TotalIncome, 0), 0) - ROUND(ISNULL(TRY_CAST(i.TotalIncome AS FLOAT), 0), 0) AS TotalIncome_Diff,

        -- Social_Ins8Percent (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.Social_Ins8Percent, 0) AS SI_Emp_System,
        ROUND(TRY_CAST(i.Social_Ins8Percent AS FLOAT), 0) AS SI_Emp_Import,
        ROUND(ISNULL(s.Social_Ins8Percent, 0), 0) - ROUND(ISNULL(TRY_CAST(i.Social_Ins8Percent AS FLOAT), 0), 0) AS SI_Emp_Diff,
        
        -- Health_Ins1_5Percent (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.Health_Ins1_5Percent, 0) AS HI_Emp_System,
        ROUND(TRY_CAST(i.Health_Ins1_5Percent AS FLOAT), 0) AS HI_Emp_Import,
        ROUND(ISNULL(s.Health_Ins1_5Percent, 0), 0) - ROUND(ISNULL(TRY_CAST(i.Health_Ins1_5Percent AS FLOAT), 0), 0) AS HI_Emp_Diff,

        -- Jobless_Ins1Percent1 (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.Jobless_Ins1Percent1, 0) AS UI_Emp_System,
        ROUND(TRY_CAST(i.Jobless_Ins1Percent1 AS FLOAT), 0) AS UI_Emp_Import,
        ROUND(ISNULL(s.Jobless_Ins1Percent1, 0), 0) - ROUND(ISNULL(TRY_CAST(i.Jobless_Ins1Percent1 AS FLOAT), 0), 0) AS UI_Emp_Diff,

        -- Leave1 (Số công -> Làm tròn 2 số thập phân)
        ROUND(s.Leave1, 2) AS Leave1_System,
        ROUND(TRY_CAST(i.Leave1 AS FLOAT), 2) AS Leave1_Import,
        ROUND(ISNULL(s.Leave1, 0), 2) - ROUND(ISNULL(TRY_CAST(i.Leave1 AS FLOAT), 0), 2) AS Leave1_Diff,

        -- LA1 (Giờ -> Làm tròn 2 số thập phân)
        ROUND(s.LA1, 2) AS LA1_System,
        ROUND(TRY_CAST(i.LA1 AS FLOAT), 2) AS LA1_Import,
        ROUND(ISNULL(s.LA1, 0), 2) - ROUND(ISNULL(TRY_CAST(i.LA1 AS FLOAT), 0), 2) AS LA1_Diff,

        -- EL1 (Giờ -> Làm tròn 2 số thập phân)
        ROUND(s.EL1, 2) AS EL1_System,
        ROUND(TRY_CAST(i.EL1 AS FLOAT), 2) AS EL1_Import,
        ROUND(ISNULL(s.EL1, 0), 2) - ROUND(ISNULL(TRY_CAST(i.EL1 AS FLOAT), 0), 2) AS EL1_Diff,

        -- Leave2 (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.Leave2, 0) AS Leave2_System,
        ROUND(TRY_CAST(i.Leave2 AS FLOAT), 0) AS Leave2_Import,
        ROUND(ISNULL(s.Leave2, 0), 0) - ROUND(ISNULL(TRY_CAST(i.Leave2 AS FLOAT), 0), 0) AS Leave2_Diff,

        -- LA2 (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.LA2, 0) AS LA2_System,
        ROUND(TRY_CAST(i.LA2 AS FLOAT), 0) AS LA2_Import,
        ROUND(ISNULL(s.LA2, 0), 0) - ROUND(ISNULL(TRY_CAST(i.LA2 AS FLOAT), 0), 0) AS LA2_Diff,

        -- EL2 (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.EL2, 0) AS EL2_System,
        ROUND(TRY_CAST(i.EL2 AS FLOAT), 0) AS EL2_Import,
        ROUND(ISNULL(s.EL2, 0), 0) - ROUND(ISNULL(TRY_CAST(i.EL2 AS FLOAT), 0), 0) AS EL2_Diff,

        -- Union_Fee (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.Union_Fee, 0) AS Union_Fee_System,
        ROUND(TRY_CAST(i.Union_Fee AS FLOAT), 0) AS Union_Fee_Import,
        ROUND(ISNULL(s.Union_Fee, 0), 0) - ROUND(ISNULL(TRY_CAST(i.Union_Fee AS FLOAT), 0), 0) AS Union_Fee_Diff,

        -- Work_Off_70 (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.Work_Off_70, 0) AS WorkOff_System,
        ROUND(TRY_CAST(i.Work_Off_70 AS FLOAT), 0) AS WorkOff_Import,
        ROUND(ISNULL(s.Work_Off_70, 0), 0) - ROUND(ISNULL(TRY_CAST(i.Work_Off_70 AS FLOAT), 0), 0) AS WorkOff_Diff,

        -- OtherDeduction (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.OtherDeduction, 0) AS OtherDeduct_System,
        ROUND(TRY_CAST(i.OtherDeduction AS FLOAT), 0) AS OtherDeduct_Import,
        ROUND(ISNULL(s.OtherDeduction, 0), 0) - ROUND(ISNULL(TRY_CAST(i.OtherDeduction AS FLOAT), 0), 0) AS OtherDeduct_Diff,

        -- TotalDeduction (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.TotalDeduction, 0) AS TotalDeduct_System,
        ROUND(TRY_CAST(i.TotalDeduction AS FLOAT), 0) AS TotalDeduct_Import,
        ROUND(ISNULL(s.TotalDeduction, 0), 0) - ROUND(ISNULL(TRY_CAST(i.TotalDeduction AS FLOAT), 0), 0) AS TotalDeduct_Diff,

        -- TaxableIncome (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.TaxableIncome, 0) AS TaxableIncome_System,
        ROUND(TRY_CAST(i.TaxableIncome AS FLOAT), 0) AS TaxableIncome_Import,
        ROUND(ISNULL(s.TaxableIncome, 0), 0) - ROUND(ISNULL(TRY_CAST(i.TaxableIncome AS FLOAT), 0), 0) AS TaxableIncome_Diff,

        -- Tax (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.Tax, 0) AS Tax_System,
        ROUND(TRY_CAST(i.Tax AS FLOAT), 0) AS Tax_Import,
        ROUND(ISNULL(s.Tax, 0), 0) - ROUND(ISNULL(TRY_CAST(i.Tax AS FLOAT), 0), 0) AS Tax_Diff,

        -- NontaxAllowance (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.NontaxAllowance, 0) AS NontaxAdd_System,
        ROUND(TRY_CAST(i.NontaxAllowance AS FLOAT), 0) AS NontaxAdd_Import,
        ROUND(ISNULL(s.NontaxAllowance, 0), 0) - ROUND(ISNULL(TRY_CAST(i.NontaxAllowance AS FLOAT), 0), 0) AS NontaxAdd_Diff,

        -- NontaxDeduction (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.NontaxDeduction, 0) AS NontaxDeduct_System,
        ROUND(TRY_CAST(i.NontaxDeduction AS FLOAT), 0) AS NontaxDeduct_Import,
        ROUND(ISNULL(s.NontaxDeduction, 0), 0) - ROUND(ISNULL(TRY_CAST(i.NontaxDeduction AS FLOAT), 0), 0) AS NontaxDeduct_Diff,

        -- NetPayment (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.NetPayment, 0) AS NetPayment_System,
        ROUND(TRY_CAST(i.NetPayment AS FLOAT), 0) AS NetPayment_Import,
        ROUND(ISNULL(s.NetPayment, 0), 0) - ROUND(ISNULL(TRY_CAST(i.NetPayment AS FLOAT), 0), 0) AS NetPayment_Diff,

        -- Social_Ins17_5Percent (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.Social_Ins17_5Percent, 0) AS SI_Com_System,
        ROUND(TRY_CAST(i.Social_Ins17_5Percent AS FLOAT), 0) AS SI_Com_Import,
        ROUND(ISNULL(s.Social_Ins17_5Percent, 0), 0) - ROUND(ISNULL(TRY_CAST(i.Social_Ins17_5Percent AS FLOAT), 0), 0) AS SI_Com_Diff,

        -- Health_Ins3Percent (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.Health_Ins3Percent, 0) AS HI_Com_System,
        ROUND(TRY_CAST(i.Health_Ins3Percent AS FLOAT), 0) AS HI_Com_Import,
        ROUND(ISNULL(s.Health_Ins3Percent, 0), 0) - ROUND(ISNULL(TRY_CAST(i.Health_Ins3Percent AS FLOAT), 0), 0) AS HI_Com_Diff,

        -- Jobless_Ins1Percent2 (Tiền -> Làm tròn 0 số thập phân)
        ROUND(s.Jobless_Ins1Percent2, 0) AS UI_Com_System,
        ROUND(TRY_CAST(i.Jobless_Ins1Percent2 AS FLOAT), 0) AS UI_Com_Import,
        ROUND(ISNULL(s.Jobless_Ins1Percent2, 0), 0) - ROUND(ISNULL(TRY_CAST(i.Jobless_Ins1Percent2 AS FLOAT), 0), 0) AS UI_Com_Diff

    FROM tblCompanySalaryExport_Compare s
    INNER JOIN (
        -- Lọc bảng ImportPayrollCheck để lấy dòng dữ liệu hợp lệ mới nhất cho mỗi nhân viên
        SELECT * FROM (
            SELECT *, ROW_NUMBER() OVER(PARTITION BY Emp_ID ORDER BY TRY_CAST(RowIndex AS INT) DESC) as rn
            FROM ImportPayrollCheck
            WHERE Emp_ID IS NOT NULL AND Emp_ID <> ''
        ) tmp WHERE rn = 1
    ) i ON s.Emp_ID = CAST(i.Emp_ID AS VARCHAR(20))
    WHERE 
       -- Chỉ hiển thị những nhân viên có tồn tại sự chênh lệch lương thực lãnh (NetPayment) thực tế từ 1 VND trở lên
       ABS(ROUND(ISNULL(s.NetPayment, 0), 0) - ROUND(ISNULL(TRY_CAST(i.NetPayment AS FLOAT), 0), 0)) >= 1
END
GO
