-- Bảng lưu trữ trạng thái xác nhận tăng ca
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[OvertimeConfirmation]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[OvertimeConfirmation](
        [LogDate] [date] NOT NULL,
        [IsDone] [bit] NULL DEFAULT ((0)),
        [IsLocked] [bit] NULL DEFAULT ((0)),
        [ModifyTime] [datetime] NULL,
     CONSTRAINT [PK_OvertimeConfirmation] PRIMARY KEY CLUSTERED 
    (
        [LogDate] ASC
    ))
END
GO

-- =============================================
-- Author:      Antigravity
-- Create date: 2026-04-28
-- Description: Lấy dữ liệu hiển thị, tự động thêm các ngày trong tháng nếu chưa có
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[sp_LoadOvertimeConfirmation]
    @Month INT,
    @Year INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Lấy ngày đầu tiên và ngày cuối cùng của tháng được chọn
    DECLARE @StartDate DATE = DATEFROMPARTS(@Year, @Month, 1);
    DECLARE @EndDate DATE = EOMONTH(@StartDate);
    
    DECLARE @CurrentDate DATE = @StartDate;

    -- Tự động sinh dữ liệu cho các ngày trong tháng nếu chưa tồn tại
    WHILE @CurrentDate <= @EndDate
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM [dbo].[OvertimeConfirmation] WHERE LogDate = @CurrentDate)
        BEGIN
            INSERT INTO [dbo].[OvertimeConfirmation] (LogDate, IsDone, IsLocked, ModifyTime)
            VALUES (@CurrentDate, 0, 0, GETDATE());
        END
        SET @CurrentDate = DATEADD(DAY, 1, @CurrentDate);
    END

    -- Trả về dữ liệu mảng
    SELECT 
        LogDate,
        ISNULL(IsDone, 0) AS IsDone,
        ISNULL(IsLocked, 0) AS IsLocked,
        ModifyTime
    FROM [dbo].[OvertimeConfirmation]
    WHERE MONTH(LogDate) = @Month AND YEAR(LogDate) = @Year
    ORDER BY LogDate ASC;
END
GO

-- =============================================
-- Author:      Antigravity
-- Create date: 2026-04-28
-- Description: Cập nhật trạng thái xác nhận và khóa từ giao diện
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[sp_SaveOvertimeConfirmation]
    @JsonData NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    -- Cập nhật dữ liệu từ chuỗi JSON truyền vào thông qua hàm OPENJSON
    -- Định dạng mảng JSON: [{"LogDate":"2026-04-01", "IsDone":1, "IsLocked":0}, ...]
    UPDATE t
    SET t.IsDone = j.IsDone,
        t.IsLocked = j.IsLocked,
        t.ModifyTime = GETDATE()
    FROM [dbo].[OvertimeConfirmation] t
    INNER JOIN OPENJSON(@JsonData) WITH (
        LogDate DATE '$.LogDate',
        IsDone BIT '$.IsDone',
        IsLocked BIT '$.IsLocked'
    ) j ON t.LogDate = j.LogDate;

    -- Trả về object kết quả JSON cho API format
    SELECT 'success' AS result, '' AS reason;
END
GO
