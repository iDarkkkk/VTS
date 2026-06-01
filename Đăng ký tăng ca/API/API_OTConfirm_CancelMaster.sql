
if object_id('[dbo].[API_OTConfirm_CancelMaster]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_OTConfirm_CancelMaster] as select 1')
GO
ALTER PROCEDURE [dbo].[API_OTConfirm_CancelMaster]
    @Identity_ID VARCHAR(100),
    @LoginID VARCHAR(50),
    @LanguageID VARCHAR(2) = 'VN'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @CurrentStatus INT;
        DECLARE @App1 VARCHAR(50), @App2 VARCHAR(50), @App3 VARCHAR(50);

        SELECT @CurrentStatus = Approve_Status,
               @App1 = ISNULL(Approver_1, ''),
               @App2 = ISNULL(Approver_2, ''),
               @App3 = ISNULL(Approver_3, '')
        FROM tblOTActualMasterNIVS
        WHERE Identity_ID = @Identity_ID;

        IF @CurrentStatus = 1
        BEGIN
            UPDATE tblOTActualMasterNIVS SET Approve_Status = 4 WHERE Identity_ID = @Identity_ID;
            SELECT 'success' AS result, N'Đã hủy đơn thành công!' AS reason;
        END
        ELSE IF @CurrentStatus = 2
        BEGIN
            DECLARE @StartLevel INT = 1;
            DECLARE @Date1 DATETIME = NULL, @Rem1 NVARCHAR(200) = NULL;
            DECLARE @Date2 DATETIME = NULL, @Rem2 NVARCHAR(200) = NULL;

            IF @App1 = 'SKIP'
            BEGIN
                SET @StartLevel = CASE WHEN @App2 = 'SKIP' THEN 3 ELSE 2 END;
                SET @Date1 = GETDATE();
                IF @App2 = 'SKIP'
                BEGIN
                    SET @Date2 = GETDATE();
                    SET @Rem2 = N'Hệ thống tự động bỏ qua do không có Cấp 2';
                END
                SET @Rem1 = N'Hệ thống tự động bỏ qua do không có Cấp 1';
            END

            UPDATE tblOTActualMasterNIVS
            SET Approve_Status = 5,
                Current_Approved_Level = @StartLevel,
                ApproveDate_1_Old = ApproveDate_1, ApproverRemark_1_Old = ApproverRemark_1,
                ApproveDate_2_Old = ApproveDate_2, ApproverRemark_2_Old = ApproverRemark_2,
                ApproveDate_3_Old = ApproveDate_3, ApproverRemark_3_Old = ApproverRemark_3,
                ApproveDate_4_Old = ApproveDate_4, ApproverRemark_4_Old = ApproverRemark_4,
                ApproveDate_5_Old = ApproveDate_5, ApproverRemark_5_Old = ApproverRemark_5, -- [MỚI] Bưng cấp 5 vào

                ApproveDate_1 = @Date1, ApproverRemark_1 = @Rem1,
                ApproveDate_2 = @Date2, ApproverRemark_2 = @Rem2,
                ApproveDate_3 = NULL, ApproverRemark_3 = NULL,
                ApproveDate_4 = NULL, ApproverRemark_4 = NULL,
                ApproveDate_5 = NULL, ApproverRemark_5 = NULL
            WHERE Identity_ID = @Identity_ID;

            SELECT 'success' AS result, N'Đã gửi yêu cầu Xin Hủy thành công!' AS reason;

            DECLARE @IsDivision INT, @TargetID INT, @OTDate DATE;
            DECLARE @GroupName NVARCHAR(250), @TotalEmp INT, @TotalHours FLOAT;

            SELECT @IsDivision = ISNULL(IsDivision, 0), @TargetID = CASE WHEN ISNULL(IsDivision, 0) = 1 THEN DivisionID ELSE GroupID END, @OTDate = OTDate FROM tblOTActualMasterNIVS WHERE Identity_ID = @Identity_ID;
            IF @IsDivision = 1 SELECT @GroupName = DivisionName FROM tblDivision WHERE DivisionID = @TargetID;
            ELSE SELECT @GroupName = GroupTeamName FROM tblGroupTeam WHERE GroupTeamID = @TargetID;

            SELECT @TotalEmp = COUNT(DISTINCT EmployeeID), @TotalHours = SUM(ISNULL(Actual_OTHours, 0)) FROM tblOTActualDetailNIVS WHERE Identity_ID = @Identity_ID;

            DECLARE @NextApprover VARCHAR(50) = CASE WHEN @App1 = 'SKIP' AND @App2 = 'SKIP' THEN @App3 WHEN @App1 = 'SKIP' THEN @App2 ELSE @App1 END;

            DECLARE @CurLang VARCHAR(2) = 'VN';
            IF ISNULL(@NextApprover, '') <> '' AND @NextApprover <> 'SKIP'
            BEGIN
                SELECT TOP 1 @CurLang = ISNULL(NULLIF(CurLang, ''), 'VN') FROM tblSC_Login WHERE LoginID = @NextApprover OR EmployeeID = @NextApprover;
                DECLARE @NotifyText NVARCHAR(MAX) = N'YÊU CẦU HỦY Xác Nhận Thực Tế cần duyệt:' + CHAR(10) + N'Bộ phận: ' + ISNULL(@GroupName, '') + CHAR(10) + N'Ngày: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) + N'Nhân viên: ' + CAST(ISNULL(@TotalEmp, 0) AS VARCHAR) + N' người' + CHAR(10) + N'Tổng giờ: ' + CAST(CAST(ISNULL(@TotalHours, 0) AS DECIMAL(10,1)) AS VARCHAR) + N'h';
                INSERT INTO tblEmailList(TemplateName, SendStatus, Approved_Send, Identity_Id, ApprovedByID, ParadiseBadge, NotificationText) VALUES ('Nivs_App_Notify', 0, 1, @Identity_ID, @NextApprover, 1, @NotifyText);
                UPDATE Taskschedule set LastTryDay = '20190101', NextRunDate = '20190101' where FunctionName = 'SendPendingEmail';
            END
        END
    END TRY
    BEGIN CATCH
        SELECT 'error' AS result, ERROR_MESSAGE() AS reason;
    END CATCH
END
GO
