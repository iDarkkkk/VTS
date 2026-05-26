if object_id('[dbo].[API_OTExceed_Count]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_OTExceed_Count] as select 1')
GO

ALTER PROCEDURE [dbo].[API_OTExceed_Count]
    @LoginID VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ActualEmployeeID VARCHAR(50);
    SELECT TOP 1 @ActualEmployeeID = LTRIM(RTRIM(EmployeeID)) 
    FROM tblSc_Login 
    WHERE LoginName = @LoginID OR CAST(LoginID AS VARCHAR(50)) = @LoginID;

    DECLARE @PendingCount INT = 0;

    SELECT @PendingCount = COUNT(1)
    FROM tblOTExceedMasterNIVS m
    WHERE (m.Approve_Status = 1 OR m.Approve_Status = 5)
      AND (
          (m.Current_Approved_Level = 1 AND (m.Approver_1 = @LoginID OR m.Approver_1 = @ActualEmployeeID)) OR
          (m.Current_Approved_Level = 2 AND (m.Approver_2 = @LoginID OR m.Approver_2 = @ActualEmployeeID)) OR
          (m.Current_Approved_Level = 3 AND (m.Approver_3 = @LoginID OR m.Approver_3 = @ActualEmployeeID)) OR
          (m.Current_Approved_Level = 4 AND (m.Approver_4 = @LoginID OR m.Approver_4 = @ActualEmployeeID))
      );

    SELECT @PendingCount AS PendingCount;
END
GO
