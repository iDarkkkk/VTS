USE Paradise_NIVS_Cloud
GO
if object_id('[dbo].[API_OTExceed_GetByID]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_OTExceed_GetByID] as select 1')
GO

ALTER PROCEDURE [dbo].[API_OTExceed_GetByID]
    @Identity_ID varchar(100)
as
begin
    set nocount on;

    select * into #tblEmployee from dbo.fn_vtblEmployeeList_Simple_ByDate(getdate(),'-1',null)

    declare @OTDate date;
    select top 1 @OTDate = cast(OTDate as date)
    from tblOTExceedMasterNIVS
    where Identity_ID = @Identity_ID;

    select m.*,
           case when m.IsDivision = 1 then isnull(div.DivisionName, 'N/A') else isnull(g.GroupTeamName, 'N/A') end as GroupName
    from tblOTExceedMasterNIVS m
    left join tblGroupTeam g on m.GroupID = g.GroupTeamID
    left join tblDivision div on m.DivisionID = div.DivisionID
    where m.Identity_ID = @Identity_ID;

    select d.*, e.FullName, e.EmployeeTypeID,

        cast(isnull(td.Direct, 1) as varchar) as IsDirect

    from tblOTExceedDetailNIVS d
    join #tblEmployee e on d.EmployeeID = e.EmployeeID
    left join dbo.fn_DivDepSecPosRange(0) dr on d.EmployeeID = dr.EmployeeID and @OTDate between dr.ChangedDate and dr.EndDate
    left join tblDivision td on dr.DivisionID = td.DivisionID
    where d.Identity_ID = @Identity_ID;
end
GO