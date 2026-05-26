USE Paradise_NIVS_Cloud
GO
if object_id('[dbo].[API_OTExceed_CancelMaster]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_OTExceed_CancelMaster] as select 1')
GO
ALTER PROCEDURE [dbo].[API_OTExceed_CancelMaster]
    @Identity_ID VARCHAR(100),
    @LoginID VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @CurrentStatus INT, @App1 VARCHAR(50), @App2 VARCHAR(50);
        SELECT @CurrentStatus = Approve_Status, @App1 = Approver_1 FROM tblOTExceedMasterNIVS WHERE Identity_ID = @Identity_ID;

        IF @CurrentStatus = 1
        BEGIN
            UPDATE tblOTExceedMasterNIVS SET Approve_Status = 4 WHERE Identity_ID = @Identity_ID;
        END
        ELSE IF @CurrentStatus = 2
        BEGIN
            DECLARE @StartLevel INT = 1;
            IF @App1 = 'SKIP' SET @StartLevel = 2;

            UPDATE tblOTExceedMasterNIVS
            SET Approve_Status = 5, Current_Approved_Level = @StartLevel,
                ApproveDate_1_Old = ApproveDate_1, ApproverRemark_1_Old = ApproverRemark_1, ApproveDate_2_Old = ApproveDate_2, ApproverRemark_2_Old = ApproverRemark_2, ApproveDate_3_Old = ApproveDate_3, ApproverRemark_3_Old = ApproverRemark_3, ApproveDate_4_Old = ApproveDate_4, ApproverRemark_4_Old = ApproverRemark_4,
                ApproveDate_1 = CASE WHEN @App1 = 'SKIP' THEN GETDATE() ELSE NULL END, ApproverRemark_1 = CASE WHEN @App1 = 'SKIP' THEN N'Hệ thống tự động bỏ qua' ELSE NULL END,
                ApproveDate_2 = NULL, ApproverRemark_2 = NULL, ApproveDate_3 = NULL, ApproverRemark_3 = NULL, ApproveDate_4 = NULL, ApproverRemark_4 = NULL
            WHERE Identity_ID = @Identity_ID;
        END
        DECLARE @IsDivision INT, @TargetID INT, @OTDate DATE;
            DECLARE @GroupName NVARCHAR(250), @TotalEmp INT;

            SELECT @IsDivision = ISNULL(IsDivision, 0),
                   @TargetID = CASE WHEN ISNULL(IsDivision, 0) = 1 THEN DivisionID ELSE GroupID END,
                   @OTDate = OTDate
            FROM tblOTExceedMasterNIVS
            WHERE Identity_ID = @Identity_ID;

            IF @IsDivision = 1
                SELECT @GroupName = DivisionName FROM tblDivision WHERE DivisionID = @TargetID;
            ELSE
                SELECT @GroupName = GroupTeamName FROM tblGroupTeam WHERE GroupTeamID = @TargetID;

            SELECT @TotalEmp = COUNT(DISTINCT EmployeeID)
            FROM tblOTExceedDetailNIVS
            WHERE Identity_ID = @Identity_ID;

            DECLARE @NextApprover VARCHAR(50) = CASE WHEN @App1 = 'SKIP' THEN @App2 ELSE @App1 END;

            DECLARE @CurLang VARCHAR(2) = 'VN';
            IF ISNULL(@NextApprover, '') <> '' AND @NextApprover <> 'SKIP'
            BEGIN
                SELECT TOP 1 @CurLang = ISNULL(NULLIF(CurLang, ''), 'VN')
                FROM tblSC_Login
                WHERE EmployeeID = @NextApprover OR LoginName = @NextApprover OR CAST(LoginID AS VARCHAR(50)) = @NextApprover;
            END

            DECLARE @NotifyText NVARCHAR(MAX);
            SET @NotifyText = CASE
                WHEN @CurLang = 'EN' THEN
                    N'CANCELLATION REQUEST for OT Limit Exceed:' + CHAR(10) +
                    N'Dept: ' + ISNULL(@GroupName, '') + CHAR(10) +
                    N'Date: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) +
                    N'Emps exceeding limit: ' + CAST(ISNULL(@TotalEmp, 0) AS VARCHAR) + N' people'
                WHEN @CurLang = 'JP' THEN
                    N'超過残業のキャンセル申請:' + CHAR(10) +
                    N'部署: ' + ISNULL(@GroupName, '') + CHAR(10) +
                    N'日付: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) +
                    N'超過対象者: ' + CAST(ISNULL(@TotalEmp, 0) AS VARCHAR) + N' 名'
                ELSE
                    N'YÊU CẦU HỦY Đơn ĐK Vượt Định Mức OT:' + CHAR(10) +
                    N'Bộ phận: ' + ISNULL(@GroupName, '') + CHAR(10) +
                    N'Ngày: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) +
                    N'Nhân viên vượt: ' + CAST(ISNULL(@TotalEmp, 0) AS VARCHAR) + N' người'
            END;

            IF ISNULL(@NextApprover, '') <> '' AND @NextApprover <> 'SKIP'
            BEGIN
                INSERT INTO tblEmailList(TemplateName, SendStatus, Approved_Send, Identity_Id, ApprovedByID, ParadiseBadge, NotificationText)
                VALUES ('Nivs_App_Notify', 0, 1, @Identity_ID, @NextApprover, 1, @NotifyText);
            END

            UPDATE Taskschedule set LastTryDay = '20190101', NextRunDate = '20190101' where FunctionName = 'SendPendingEmail';
        SELECT 'success' AS result, N'Đã gửi yêu cầu Hủy thành công!' AS reason;
    END TRY
    BEGIN CATCH
        SELECT 'error' AS result, ERROR_MESSAGE() AS reason;
    END CATCH
END
GO