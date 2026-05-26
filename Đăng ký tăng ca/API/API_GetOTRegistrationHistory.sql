USE Paradise_NIVS_Cloud
GO
if object_id('[dbo].[API_GetOTRegistrationHistory]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_GetOTRegistrationHistory] as select 1')
GO

ALTER PROCEDURE [dbo].[API_GetOTRegistrationHistory]
    @LoginID VARCHAR(50),
    @FromDate DATE,
    @ToDate DATE,
    @Status INT = -1
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            m.Identity_ID, m.Approve_Status, m.Current_Approved_Level, m.TypeRegister,
            m.OTDateFrom, m.OTDateTo, m.CreateTime,
            CASE WHEN ISNULL(m.IsDivision, 0) = 1 THEN ISNULL((SELECT DivisionName FROM tblDivision WHERE DivisionID = m.DivisionID), 'N/A')
                 ELSE ISNULL((SELECT GroupTeamName FROM tblGroupTeam WHERE GroupTeamID = m.GroupID), 'N/A') END AS GroupName,

            m.Approver_1, ISNULL(e1.FullName, m.Approver_1) AS Approver1_Name, m.ApproveDate_1,
            m.Approver_2, ISNULL(e2.FullName, m.Approver_2) AS Approver2_Name, m.ApproveDate_2,
            m.Approver_3, ISNULL(e3.FullName, m.Approver_3) AS Approver3_Name, m.ApproveDate_3,
            m.Approver_3, ISNULL(e4.FullName, m.Approver_4) AS Approver4_Name, m.ApproveDate_4,
            m.RegisterBy,
            ISNULL((SELECT TOP 1 1 FROM tblOTListRegisteredNIVS_Detail d WHERE d.Identity_ID = m.Identity_ID AND d.IsExceed = 1), 0) AS HasRisk_Over100h,
            ISNULL(m.IsDivision, 0) AS IsDivision
        FROM tblOTListRegisteredNIVS m
        LEFT JOIN tblEmployee e1 ON m.Approver_1 = e1.EmployeeID
        LEFT JOIN tblEmployee e2 ON m.Approver_2 = e2.EmployeeID
        LEFT JOIN tblEmployee e3 ON m.Approver_3 = e3.EmployeeID
         LEFT JOIN tblEmployee e4 ON m.Approver_4 = e4.EmployeeID
        WHERE m.RegisterBy = @LoginID AND m.Approve_Status > 0
          AND CAST(m.CreateTime AS DATE) >= @FromDate AND CAST(m.CreateTime AS DATE) <= @ToDate
          AND (@Status = -1 OR m.Approve_Status = @Status)
        ORDER BY m.CreateTime DESC;
    END TRY
    BEGIN CATCH
        SELECT 'error' AS result, ERROR_MESSAGE() AS reason;
    END CATCH
END
GO