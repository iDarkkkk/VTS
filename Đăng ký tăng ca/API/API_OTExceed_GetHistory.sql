USE Paradise_NIVS_Cloud
GO
if object_id('[dbo].[API_OTExceed_GetHistory]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_OTExceed_GetHistory] as select 1')
GO
ALTER PROCEDURE [dbo].[API_OTExceed_GetHistory]
    @LoginID VARCHAR(50),
    @FromDate DATE,
    @ToDate DATE,
    @Status INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        m.Identity_ID,
        CASE WHEN m.IsDivision = 1 THEN ISNULL(d.DivisionName, 'N/A') ELSE ISNULL(g.GroupTeamName, 'N/A') END AS GroupName,
        ISNULL(m.TypeRegister, 1) AS TypeRegister,
        ISNULL(m.IsDivision, 0) AS IsDivision,
        m.OTDate, m.Approve_Status, m.Current_Approved_Level, m.CreateTime,
        m.Approver_1, a1.FullName AS Approver1_Name, m.ApproveDate_1,
        m.Approver_2, a2.FullName AS Approver2_Name, m.ApproveDate_2,
        m.Approver_3, a3.FullName AS Approver3_Name, m.ApproveDate_3,
        (SELECT COUNT(1) FROM tblOTExceedDetailNIVS exD WHERE exD.Identity_ID = m.Identity_ID) AS TotalEmployees
    FROM tblOTExceedMasterNIVS m
    LEFT JOIN tblGroupTeam g ON m.GroupID = g.GroupTeamID
    LEFT JOIN tblDivision d ON m.DivisionID = d.DivisionID
    LEFT JOIN tblEmployee a1 ON m.Approver_1 = a1.EmployeeID
    LEFT JOIN tblEmployee a2 ON m.Approver_2 = a2.EmployeeID
    LEFT JOIN tblEmployee a3 ON m.Approver_3 = a3.EmployeeID
    WHERE m.RegisterBy = @LoginID AND m.OTDate >= @FromDate AND m.OTDate <= @ToDate AND (@Status = -1 OR m.Approve_Status = @Status)
    ORDER BY m.CreateTime DESC;
END
GO