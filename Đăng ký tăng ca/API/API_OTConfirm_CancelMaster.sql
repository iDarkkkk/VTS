USE Paradise_NIVS_Cloud
GO
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
        DECLARE @App1 VARCHAR(50), @App2 VARCHAR(50);

        SELECT @CurrentStatus = Approve_Status,
               @App1 = ISNULL(Approver_1, ''),
               @App2 = ISNULL(Approver_2, '')
        FROM tblOTActualMasterNIVS
        WHERE Identity_ID = @Identity_ID;

        IF @CurrentStatus = 1
        BEGIN
            UPDATE tblOTActualMasterNIVS
            SET Approve_Status = 4
            WHERE Identity_ID = @Identity_ID;

            -- Message trả về UI
            DECLARE @MsgSuccess1 NVARCHAR(200) = CASE
                WHEN @LanguageID = 'EN' THEN N'Form cancelled successfully!'
                WHEN @LanguageID = 'JP' THEN N'申請が正常にキャンセルされました！'
                ELSE N'Đã hủy đơn thành công!'
            END;
            SELECT 'success' AS result, @MsgSuccess1 AS reason;
        END
        ELSE IF @CurrentStatus = 2
        BEGIN
            DECLARE @StartLevel INT = 1;
            DECLARE @Date1 DATETIME = NULL, @Rem1 NVARCHAR(200) = NULL;

            IF @App1 = 'SKIP'
            BEGIN
                SET @StartLevel = 2;
                SET @Date1 = GETDATE();
                SET @Rem1 = CASE
                    WHEN @LanguageID = 'EN' THEN N'System automatically skipped cancellation approval due to no Level 1'
                    WHEN @LanguageID = 'JP' THEN N'1次承認者がいないため、キャンセル承認を自動スキップしました'
                    ELSE N'Hệ thống tự động bỏ qua do không có Cấp 1'
                END;
            END

            UPDATE tblOTActualMasterNIVS
            SET Approve_Status = 5,
                Current_Approved_Level = @StartLevel,

                ApproveDate_1_Old = ApproveDate_1,
                ApproverRemark_1_Old = ApproverRemark_1,
                ApproveDate_2_Old = ApproveDate_2,
                ApproverRemark_2_Old = ApproverRemark_2,
                ApproveDate_3_Old = ApproveDate_3,
                ApproverRemark_3_Old = ApproverRemark_3,
                ApproveDate_4_Old = ApproveDate_4,
                ApproverRemark_4_Old = ApproverRemark_4,

                ApproveDate_1 = @Date1,
                ApproverRemark_1 = @Rem1,
                ApproveDate_2 = NULL, ApproverRemark_2 = NULL,
                ApproveDate_3 = NULL, ApproverRemark_3 = NULL,
                ApproveDate_4 = NULL, ApproverRemark_4 = NULL
            WHERE Identity_ID = @Identity_ID;

            DECLARE @MsgSuccess2 NVARCHAR(200) = CASE
                WHEN @LanguageID = 'EN' THEN N'Cancellation request sent. Waiting for Level ' + CAST(@StartLevel AS VARCHAR(10)) + N' approval!'
                WHEN @LanguageID = 'JP' THEN N'キャンセル申請を送信しました。' + CAST(@StartLevel AS VARCHAR(10)) + N'次承認待ちです！'
                ELSE N'Đã gửi yêu cầu Xin Hủy thành công!'
            END;
            SELECT 'success' AS result, @MsgSuccess2 AS reason;

            DECLARE @IsDivision INT, @TargetID INT, @OTDate DATE;
            DECLARE @GroupName NVARCHAR(250), @TotalEmp INT, @TotalHours FLOAT;

            SELECT @IsDivision = ISNULL(IsDivision, 0),
                   @TargetID = CASE WHEN ISNULL(IsDivision, 0) = 1 THEN DivisionID ELSE GroupID END,
                   @OTDate = OTDate
            FROM tblOTActualMasterNIVS
            WHERE Identity_ID = @Identity_ID;

            IF @IsDivision = 1
                SELECT @GroupName = DivisionName FROM tblDivision WHERE DivisionID = @TargetID;
            ELSE
                SELECT @GroupName = GroupTeamName FROM tblGroupTeam WHERE GroupTeamID = @TargetID;

            SELECT @TotalEmp = COUNT(DISTINCT EmployeeID), @TotalHours = SUM(ISNULL(Actual_OTHours, 0))
            FROM tblOTActualDetailNIVS
            WHERE Identity_ID = @Identity_ID;

            DECLARE @NextApprover VARCHAR(50) = CASE WHEN @App1 = 'SKIP' THEN @App2 ELSE @App1 END;

            DECLARE @CurLang VARCHAR(2) = 'VN';
            IF ISNULL(@NextApprover, '') <> '' AND @NextApprover <> 'SKIP'
            BEGIN
                SELECT TOP 1 @CurLang = ISNULL(NULLIF(CurLang, ''), 'VN')
                FROM tblSC_Login
                WHERE LoginID = @NextApprover OR EmployeeID = @NextApprover;
            END

            DECLARE @NotifyText NVARCHAR(MAX);
            SET @NotifyText = CASE
                WHEN @CurLang = 'EN' THEN
                    N'CANCELLATION REQUEST for Actual OT:' + CHAR(10) +
                    N'Dept: ' + ISNULL(@GroupName, '') + CHAR(10) +
                    N'Date: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) +
                    N'Emps: ' + CAST(ISNULL(@TotalEmp, 0) AS VARCHAR) + N' people' + CHAR(10) +
                    N'Total OT: ' + CAST(CAST(ISNULL(@TotalHours, 0) AS DECIMAL(10,1)) AS VARCHAR) + N'h'
                WHEN @CurLang = 'JP' THEN
                    N'実残業確認のキャンセル申請:' + CHAR(10) +
                    N'部署: ' + ISNULL(@GroupName, '') + CHAR(10) +
                    N'日付: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) +
                    N'対象者: ' + CAST(ISNULL(@TotalEmp, 0) AS VARCHAR) + N' 名' + CHAR(10) +
                    N'合計残業: ' + CAST(CAST(ISNULL(@TotalHours, 0) AS DECIMAL(10,1)) AS VARCHAR) + N'h'
                ELSE
                    N'YÊU CẦU HỦY Xác Nhận Thực Tế:' + CHAR(10) +
                    N'Bộ phận: ' + ISNULL(@GroupName, '') + CHAR(10) +
                    N'Ngày: ' + CONVERT(VARCHAR, @OTDate, 103) + CHAR(10) +
                    N'Nhân viên: ' + CAST(ISNULL(@TotalEmp, 0) AS VARCHAR) + N' người' + CHAR(10) +
                    N'Tổng giờ: ' + CAST(CAST(ISNULL(@TotalHours, 0) AS DECIMAL(10,1)) AS VARCHAR) + N'h'
            END;

            IF ISNULL(@NextApprover, '') <> '' AND @NextApprover <> 'SKIP'
            BEGIN
                INSERT INTO tblEmailList(TemplateName, SendStatus, Approved_Send, Identity_Id, ApprovedByID, ParadiseBadge, NotificationText)
                VALUES ('Nivs_App_Notify', 0, 1, @Identity_ID, @NextApprover, 1, @NotifyText);
            END

            -- Kích hoạt job gửi mail
            UPDATE Taskschedule set LastTryDay = '20190101', NextRunDate = '20190101' where FunctionName = 'SendPendingEmail'

        END
    END TRY
    BEGIN CATCH
        SELECT 'error' AS result, ERROR_MESSAGE() AS reason;
    END CATCH
END
GO