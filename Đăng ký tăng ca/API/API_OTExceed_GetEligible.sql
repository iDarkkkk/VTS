USE Paradise_NIVS_Cloud
GO
if object_id('[dbo].[API_OTExceed_GetEligible]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_OTExceed_GetEligible] as select 1')
GO

ALTER PROCEDURE [dbo].[API_OTExceed_GetEligible]
    @TargetID int,
    @OTDate date,
    @LoginID varchar(50),
    @IsDivision int = 0
as
begin
    set nocount on;

    declare @GroupID int = case when @IsDivision = 0 then @TargetID else null end;
    declare @DivisionID int = case when @IsDivision = 1 then @TargetID else null end;
    select * into #tblEmployee from dbo.fn_vtblEmployeeList_Simple_ByDate(getdate(),'-1',null)

    if object_id('tempdb..#empDivRange') is not null drop table #empDivRange;
    select EmployeeID, DivisionID, ChangedDate, EndDate
    into #empDivRange
    from dbo.fn_DivDepSecPosRange(0);

    ;with CTE_LatestPlan as (
        select
            p.Identity_ID as PlanID, p.EmployeeID, p.ShiftID, p.OTFrom,
            p.OTTo, p.IsExceed, p.IsExtraEmp, isnull(p.IsIndirectEmp, @IsDivision) as IsIndirectEmp, m.TypeRegister,
            p.LimitType, p.CurrentTotalOT, e.EmployeeTypeID,
            isnull(p.OTHours, 0) as PlannedOT_Hours,
            row_number() over(partition by p.EmployeeID order by m.CreateTime desc) as RowNum
        from tblOTListRegisteredNIVS_Detail p
        inner join tblOTListRegisteredNIVS m on p.Identity_ID = m.Identity_ID
        inner join #tblEmployee e on p.EmployeeID = e.EmployeeID
        where ((@IsDivision = 0 and m.GroupID = @TargetID) or (@IsDivision = 1 and m.DivisionID = @TargetID))
          and m.Approve_Status = 2
          and cast(p.OTDate as date) = cast(@OTDate as date)
          and p.IsExceed = 1
          and m.RegisterBy = @LoginID
    )

    select cp.EmployeeID, e.FullName, cp.EmployeeTypeID,
        isnull(cp.CurrentTotalOT, 0) as CurrentTotalOT,
        isnull(cp.PlannedOT_Hours, 0) as PlannedOT_Hours,
        isnull(cp.LimitType, N'Vượt Định Mức') as LimitType,
        isnull(cp.TypeRegister, 1) as TypeRegister,
        cast(isnull(td.Direct, 1) as varchar) as IsDirect

    from CTE_LatestPlan cp
    join tblEmployee e on cp.EmployeeID = e.EmployeeID
    left join #empDivRange dr on cp.EmployeeID = dr.EmployeeID and @OTDate between dr.ChangedDate and dr.EndDate
    left join tblDivision td on dr.DivisionID = td.DivisionID
    where cp.RowNum = 1
      and cp.EmployeeID not in (
          select exD.EmployeeID
          from tblOTExceedMasterNIVS exM
          join tblOTExceedDetailNIVS exD on exM.Identity_ID = exD.Identity_ID
          where cast(exM.OTDate as date) = cast(@OTDate as date)
            and exM.Approve_Status in (1, 2, 5)
      );

    drop table #empDivRange;
end
GO