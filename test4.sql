USE Paradise_NIVS_Cloud
GO
if object_id('[dbo].[API_OTPlan_Accumulated_Export]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_OTPlan_Accumulated_Export] as select 1')
GO

ALTER PROCEDURE [dbo].[API_OTPlan_Accumulated_Export]
(
    @FromDate date,
    @ToDate date,
    @LoginID int,
    @LanguageID varchar(2) = 'VN',
    @FormCode int = 1
)
as
begin
    set nocount on;

    select sc.LoginID, sc.EmployeeID, s.Items
    into #tblSC_Login
    from tblSC_Login sc
    cross apply dbo.SplitString(sc.ParentLoginID,'&') as s
    where sc.LoginID = @LoginID;

    declare @EmployeeID varchar(20) = (select top 1 EmployeeID from #tblSC_Login);
    declare @DateTitle nvarchar(20) = '';
    declare @DivisionID int = -1, @DivisionID2 int = -1;

    if exists(select 1 from #tblSC_Login where Items = '4664')
    begin
        select @DivisionID = DivisionID
        from dbo.fn_vtblEmployeeList_Simple_ByDate(@ToDate, @EmployeeID, null);

        select @DivisionID2 = DivisionID
        from tblDivisionGroup
        where DivisionID2 = @DivisionID;
    end

    if exists(select 1 from #tblSC_Login where Items = '8') or @LoginID = 3
    begin
        set @DivisionID = -1;
    end

    select e.EmployeeID, iif(@LanguageID = 'VN', e.FullName, dbo.fn_RemoveToneMark(e.FullName)) as FullName, e.DivisionID,
           isnull(d.DivisionName, '') as DivisionName, isnull(g.GroupName, '') as GroupName ,e.EmployeeTypeID
    into #tmpEmployeeList
    from dbo.fn_vtblEmployeeList_Simple_ByDate(@ToDate, '-1', null) e
    left join tblDivision d on e.DivisionID = d.DivisionID
    left join tblGroup g on g.GroupID = e.GroupID
    where (@DivisionID = -1 or e.DivisionID = @DivisionID or e.DivisionID = isnull(@DivisionID2, -99))
      and e.EmployeeStatusID <> 20;

    create table #tmpLatest (
        EmployeeID varchar(50),
        OTDate date,
        OTHours numeric(18, 4)
    );

    if @FormCode = 1
    begin
        insert into #tmpLatest (EmployeeID, OTDate, OTHours)
        select EmployeeID, OTDate, OTHours
        from (
            select d.EmployeeID, d.OTDate, d.OTHours, row_number() over(partition by d.EmployeeID, cast(d.OTDate as date) order by m.CreateTime desc) as RowNum
            from tblOTListRegisteredNIVS_Detail d
            inner join tblOTListRegisteredNIVS m on d.Identity_ID = m.Identity_ID
            where m.Approve_Status = 2
              and cast(d.OTDate as date) >= @FromDate
              and cast(d.OTDate as date) <= @ToDate
        ) T where RowNum = 1;
    end
    else if @FormCode = 2
    begin
        insert into #tmpLatest (EmployeeID, OTDate, OTHours)
        select EmployeeID, OTDate, OTHours
        from (
            select d.EmployeeID, d.OTDate, d.Actual_OTHours as OTHours, row_number() over(partition by d.EmployeeID, cast(d.OTDate as date) order by m.CreateTime desc) as RowNum
            from tblOTActualDetailNIVS d
            inner join tblOTActualMasterNIVS m on d.Identity_ID = m.Identity_ID
            where m.Approve_Status = 2
              and cast(d.OTDate as date) >= @FromDate
              and cast(d.OTDate as date) <= @ToDate
        ) T where RowNum = 1;
    end

    select  p.EmployeeID, sum(isnull(p.OTHours, 0)) as TotalOT,
        sum(case when isnull(c.HolidayStatus, 0) = 0 then isnull(p.OTHours, 0) else 0 end) as OT_150,
        sum(case when isnull(c.HolidayStatus, 0) = 1 then isnull(p.OTHours, 0) else 0 end) as OT_200,
        sum(case when isnull(c.HolidayStatus, 0) = 2 then isnull(p.OTHours, 0) else 0 end) as OT_300
    into #tmpOT
    from #tmpLatest p
    inner join #tmpEmployeeList emp on p.EmployeeID = emp.EmployeeID
    left join tblCalendarWorking c on cast(p.OTDate as date) = cast(c.Date as date) and emp.EmployeeTypeID = c.EmployeeTypeID
    group by p.EmployeeID;

    select  row_number() over(order by e.DivisionID, e.EmployeeID) as STT, e.EmployeeID, e.FullName, e.DivisionName, e.GroupName,
        case when isnull(o.OT_150, 0) = 0 then '' else cast(o.OT_150 as varchar(20)) end as OT_150,
        case when isnull(o.OT_200, 0) = 0 then '' else cast(o.OT_200 as varchar(20)) end as OT_200,
        case when isnull(o.OT_300, 0) = 0 then '' else cast(o.OT_300 as varchar(20)) end as OT_300,
         case when isnull(o.TotalOT, 0) = 0 then '' else cast(o.TotalOT as varchar(20)) end as TotalOT
    into #tmpExport
    from #tmpEmployeeList e
    inner join #tmpOT o on e.EmployeeID = o.EmployeeID
    where isnull(o.TotalOT, 0) > 0
    order by e.DivisionID, e.EmployeeID;

    create table #ExportConfig (
        TableIndex varchar(50),
        RowIndex int,
        ColumnName nvarchar(100),
        ParseType nvarchar(max),
        Position nvarchar(10),
        SheetIndex int,
        TestDescription nvarchar(100),
        WithHeader int,
        WithBestFit bit
    );

    if @FormCode = 1
    begin
        insert into #ExportConfig(TableIndex, RowIndex, ColumnName, ParseType, Position, SheetIndex)
        values ('0', null, null, 'TableNonInsert', 'A3', 0),
               ('1', null, null, 'Table|KeepExcelOriginalValue=EmployeeID', 'A5', 0);
    end
    else if @FormCode = 2
    begin
        insert into #ExportConfig(TableIndex, RowIndex, ColumnName, ParseType, Position, SheetIndex)
        values ('0', null, null, 'TableNonInsert', 'A3', 0),
               ('1', null, null, 'Table|KeepExcelOriginalValue=EmployeeID', 'A5', 0);
    end

    select concat(N'Ngày đã chọn ',CONVERT(varchar, @FromDate, 103),' - ',CONVERT(varchar, @ToDate, 103)) as PrintDate
    select * from #tmpExport order by STT;

    select * from #ExportConfig;

    drop table #tblSC_Login;
    drop table #tmpEmployeeList;
    drop table #tmpLatest;
    drop table #tmpOT;
    drop table #tmpExport;
    drop table #ExportConfig;
end
GO