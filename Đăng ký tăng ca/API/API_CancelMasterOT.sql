USE Paradise_NIVS_Cloud
GO
if object_id('[dbo].[API_CancelMasterOT]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_CancelMasterOT] as select 1')
GO
ALTER PROCEDURE [dbo].[API_CancelMasterOT]
    @Identity_ID VARCHAR(100),
    @LoginID VARCHAR(50),
    @LanguageID varchar(2) = 'VN'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Status INT;
    DECLARE @Approver_1 VARCHAR(50), @Approver_2 VARCHAR(50);

    SET @Identity_ID = LTRIM(RTRIM(@Identity_ID));

    SELECT @Status = Approve_Status,@Approver_1 = ISNULL(Approver_1, ''), @Approver_2 = ISNULL(Approver_2, '')
    FROM tblOTListRegisteredNIVS
    WHERE CAST(Identity_ID AS VARCHAR(100)) = @Identity_ID;


    IF @Status = 1
    BEGIN
        UPDATE tblOTListRegisteredNIVS SET Approve_Status = 4 WHERE CAST(Identity_ID AS VARCHAR(100)) = @Identity_ID;
        UPDATE tblOTListRegisteredNIVS_Detail SET Approve_Status = 4 WHERE CAST(Identity_ID AS VARCHAR(100)) = @Identity_ID;
        SELECT 'success' AS result, N'Đã hủy đơn thành công!' AS reason;
    END

    ELSE IF @Status = 2
    BEGIN

        DECLARE @CurLevel INT = 1;
        DECLARE @Date1 DATETIME = NULL, @Rem1 NVARCHAR(200) = NULL;
        DECLARE @Date2 DATETIME = NULL, @Rem2 NVARCHAR(200) = NULL;

        IF @Approver_1 = 'SKIP'
        BEGIN
            SET @CurLevel = 2;
            SET @Date1 = GETDATE();
            SET @Rem1 = N'Hệ thống tự động bỏ qua duyệt Hủy do không có Cấp 1';
        END

       update tblOTListRegisteredNIVS
        set Approve_Status = 5, Current_Approved_Level = @CurLevel,
            ApproveDate_1_Old = ApproveDate_1, ApproverRemark_1_Old = ApproverRemark_1,
            ApproveDate_2_Old = ApproveDate_2, ApproverRemark_2_Old = ApproverRemark_2,
            ApproveDate_3_Old = ApproveDate_3, ApproverRemark_3_Old = ApproverRemark_3,
            ApproveDate_4_Old = ApproveDate_4, ApproverRemark_4_Old = ApproverRemark_4,
            ApproveDate_1 = @Date1, ApproverRemark_1 = @Rem1,
            ApproveDate_2 = @Date2, ApproverRemark_2 = @Rem2,
            ApproveDate_3 = null, ApproverRemark_3 = null,
            ApproveDate_4 = null, ApproverRemark_4 = null
        where cast(Identity_ID as varchar(100)) = @Identity_ID;

        DECLARE @Msg NVARCHAR(200) = N'Đã gửi yêu cầu Xin Hủy. Chờ Sếp Cấp ' + CAST(@CurLevel AS VARCHAR(10)) + N' phê duyệt!';
        SELECT 'success' AS result, @Msg AS reason;
DECLARE @IsDivision INT, @TargetID INT, @OTDateFrom DATE, @OTDateTo DATE;
        DECLARE @GroupName NVARCHAR(250), @TotalEmp INT, @TotalHours FLOAT;

        SELECT @IsDivision = ISNULL(IsDivision, 0),
               @TargetID = CASE WHEN ISNULL(IsDivision, 0) = 1 THEN DivisionID ELSE GroupID END,
               @OTDateFrom = OTDateFrom,
               @OTDateTo = OTDateTo
        FROM tblOTListRegisteredNIVS
        WHERE Identity_ID = @Identity_ID;

        IF @IsDivision = 1
            SELECT @GroupName = DivisionName FROM tblDivision WHERE DivisionID = @TargetID;
        ELSE
            SELECT @GroupName = GroupTeamName FROM tblGroupTeam WHERE GroupTeamID = @TargetID;

        SELECT @TotalEmp = COUNT(DISTINCT EmployeeID), @TotalHours = SUM(ISNULL(OTHours, 0))
        FROM tblOTListRegisteredNIVS_Detail
        WHERE Identity_ID = @Identity_ID;

        DECLARE @NextApprover VARCHAR(50) = CASE WHEN @Approver_1 = 'SKIP' THEN @Approver_2 ELSE @Approver_1 END;

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
                N'CANCELLATION REQUEST for Planned OT:' + CHAR(10) +
                N'Dept: ' + ISNULL(@GroupName, '') + CHAR(10) +
                N'Date: ' + CONVERT(VARCHAR, @OTDateFrom, 103) + N' - ' + CONVERT(VARCHAR, @OTDateTo, 103) + CHAR(10) +
                N'Emps: ' + CAST(ISNULL(@TotalEmp, 0) AS VARCHAR) + N' people' + CHAR(10) +
                N'Total OT: ' + CAST(CAST(ISNULL(@TotalHours, 0) AS DECIMAL(10,1)) AS VARCHAR) + N'h'
            WHEN @CurLang = 'JP' THEN
                N'計画残業のキャンセル申請:' + CHAR(10) +
                N'部署: ' + ISNULL(@GroupName, '') + CHAR(10) +
                N'日付: ' + CONVERT(VARCHAR, @OTDateFrom, 103) + N' - ' + CONVERT(VARCHAR, @OTDateTo, 103) + CHAR(10) +
                N'対象者: ' + CAST(ISNULL(@TotalEmp, 0) AS VARCHAR) + N' 名' + CHAR(10) +
                N'合計残業: ' + CAST(CAST(ISNULL(@TotalHours, 0) AS DECIMAL(10,1)) AS VARCHAR) + N'h'
            ELSE
                N'YÊU CẦU HỦY Đơn ĐK Tăng ca Kế hoạch:' + CHAR(10) +
                N'Bộ phận: ' + ISNULL(@GroupName, '') + CHAR(10) +
                N'Ngày: ' + CONVERT(VARCHAR, @OTDateFrom, 103) + N' - ' + CONVERT(VARCHAR, @OTDateTo, 103) + CHAR(10) +
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
    ELSE
    BEGIN
        SELECT 'error' AS result, N'Trạng thái đơn không hợp lệ để thao tác!' AS reason;
    END
END
GO