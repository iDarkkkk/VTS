USE Paradise_NIVS_Cloud
GO
if object_id('[dbo].[API_OTConfirm_CreateOrGet]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_OTConfirm_CreateOrGet] as select 1')
GO

ALTER PROCEDURE [dbo].[API_OTConfirm_CreateOrGet]
    @TargetID int,
    @OTDate date,
    @LoginID varchar(50),
    @TypeRegister int = 1,
    @IsDivision int = 0
as
begin
    set nocount on;
    begin try
        declare @GroupID int = case when @IsDivision = 0 then @TargetID else null end;
        declare @DivisionID int = case when @IsDivision = 1 then @TargetID else null end;

        declare @PlanID varchar(100);
        declare @PlanType int;

        select top 1 @PlanID = m.Identity_ID, @PlanType = m.TypeRegister
        from tblOTListRegisteredNIVS_Detail d
        inner join tblOTListRegisteredNIVS m on d.Identity_ID = m.Identity_ID
        where ((@IsDivision = 0 and m.GroupID = @TargetID) or (@IsDivision = 1 and m.DivisionID = @TargetID))
          and m.Approve_Status = 2
          and cast(d.OTDate as date) = cast(@OTDate as date)
          and m.RegisterBy = @LoginID
        order by m.CreateTime desc;

        if @PlanType is null
        begin
            select 'error' as result, N'Bạn chưa có dữ liệu Kế hoạch Tăng ca nào được duyệt trong ngày ' + convert(varchar, @OTDate, 103) + N'!' as reason;
            return;
        end

        declare @ActualMasterID varchar(100);
        declare @ActualStatus int = 0;

        select top 1  @ActualMasterID = Identity_ID, @ActualStatus = isnull(Approve_Status, 0)
        from tblOTActualMasterNIVS
        where isnull(GroupID, 0) = isnull(@GroupID, 0)
          and isnull(DivisionID, 0) = isnull(@DivisionID, 0)
          and cast(OTDate as date) = cast(@OTDate as date)
          and Approve_Status <> 4
          and isnull(IsDivision, 0) = @IsDivision
          and RegisterBy = @LoginID
        order by CreateTime desc;
        if @ActualMasterID is null
        begin
            set @ActualMasterID = cast(newid() as varchar(100));
            set @ActualStatus = 0;

            insert into tblOTActualMasterNIVS (Identity_ID, GroupID, DivisionID, IsDivision, OTDate, RegisterBy, Approve_Status, CreateTime, TypeRegister, Plan_Identity_ID)
            values (@ActualMasterID, @GroupID, @DivisionID, @IsDivision, @OTDate, @LoginID, 0, getdate(), @PlanType, @PlanID);
        end
        else
        begin


            update a
            set a.ShiftID = s.ShiftID
            from tblOTActualDetailNIVS a
            inner join tblAttendanceSummary s on a.EmployeeID = s.EmployeeID and cast(a.OTDate as date) = cast(s.AttDate as date)
            where a.Identity_ID = @ActualMasterID

              and isnull(a.ShiftID, 0) <> s.ShiftID;
        end


        select m.*,
            case when m.IsDivision = 1 then isnull((select DivisionName from tblDivision where DivisionID = m.DivisionID), 'N/A')
                 else isnull(g.GroupTeamName, 'N/A') end as GroupName
        from tblOTActualMasterNIVS m
        left join tblGroupTeam g on m.GroupID = g.GroupTeamID
        where m.Identity_ID = @ActualMasterID;

        if object_id('tempdb..#tmpLatestPlan') is not null drop table #tmpLatestPlan;

        select * into #tmpLatestPlan from (
            select
                p.Identity_ID as PlanID, p.EmployeeID, p.ShiftID, p.OTFrom,
                p.OTTo, p.IsExceed, p.IsExtraEmp, isnull(p.IsIndirectEmp, @IsDivision) as IsIndirectEmp, m.TypeRegister,
                p.LimitType, p.CurrentTotalOT, p.ConsecutiveDays, p.WorkedHolidays,
                p.Original_OTFrom, p.Original_OTTo,
                row_number() over(partition by p.EmployeeID order by m.CreateTime desc) as RowNum
            from tblOTListRegisteredNIVS_Detail p
            inner join tblOTListRegisteredNIVS m on p.Identity_ID = m.Identity_ID
            where ((@IsDivision = 0 and m.GroupID = @TargetID) or (@IsDivision = 1 and m.DivisionID = @TargetID))
              and m.Approve_Status = 2
              and cast(p.OTDate as date) = cast(@OTDate as date)
              and m.RegisterBy = @LoginID
        ) T where RowNum = 1;

        if object_id('tempdb..#tmpEmpsActual') is not null drop table #tmpEmpsActual;
        create table #tmpEmpsActual (EmployeeID varchar(50));

        if @ActualStatus > 0
            insert into #tmpEmpsActual select distinct EmployeeID from tblOTActualDetailNIVS where Identity_ID = @ActualMasterID;
        else
            insert into #tmpEmpsActual select distinct EmployeeID from #tmpLatestPlan;

        if object_id('tempdb..#MaternityStatus') is not null drop table #MaternityStatus;
        select * into #MaternityStatus
        from dbo.fn_EmployeeStatusRange(0)
        where EmployeeStatusID = 11
          and EmployeeID in (select EmployeeID from #tmpEmpsActual);

        if object_id('tempdb..#empDivRange') is not null drop table #empDivRange;
        select * into #empDivRange from dbo.fn_DivDepSecPosRange(0) where EmployeeID in (select EmployeeID from #tmpEmpsActual);

        if @ActualStatus > 0
        begin
            select
                a.EmployeeID, isnull(e.FullName, 'N/A') as FullName,
                s.ShiftCode as shiftCode,
                isnull(a.ShiftID, cp.ShiftID) as ShiftID,
                s.ShiftName, s.WorkStart, s.WorkEnd, s.OTBeforeStart, s.OTBeforeEnd, s.OTAfterStart, s.OTAfterEnd,

                isnull(a.Planned_OTFrom, cp.OTFrom) as Planned_OTFrom,
                isnull(a.Planned_OTTo, cp.OTTo) as Planned_OTTo,

                a.Actual_OTFrom as Saved_OTFrom, a.Actual_OTTo as Saved_OTTo,
                isnull(a.Actual_OTHours, 0) as Actual_OTHours,
                isnull(e.EmployeeTypeID, 1) as EmployeeTypeID, isnull(e.PositionID, '') as PositionID,
                isnull(map.HolidayStatusID, 0) as HolidayStatus,

                isnull(cp.IsExceed, 0) as IsExceed,
                isnull(cp.IsExtraEmp, 0) as IsExtraEmp,
                isnull(a.IsIndirectEmp, @IsDivision) as IsIndirectEmp,

                cast(isnull(td.Direct, 1) as varchar) as IsDirect,

                isnull((
                    select top 1 exMaster.Approve_Status
                    from tblOTExceedDetailNIVS exDet
                    join tblOTExceedMasterNIVS exMaster on exDet.Identity_ID = exMaster.Identity_ID
                    where exDet.EmployeeID = a.EmployeeID
                      and cast(exMaster.OTDate as date) = cast(@OTDate as date)
                    order by exMaster.CreateTime desc
                ), 0) as ExceedApproveStatus,
                @ActualStatus as Approve_Status,

                isnull(cp.LimitType, '') as LimitType,
                isnull(cp.CurrentTotalOT, 0) as BaseOT_Before,
                isnull(cp.ConsecutiveDays, 0) as ConsecutiveDays,
                isnull(cp.WorkedHolidays, 0) as WorkedHolidays,
                isnull(cast((
                    select top 1 case when isnull(ms.isAllowLate, 0) = 1 then '1' else '0' end
                    from #MaternityStatus ms
                    where ltrim(rtrim(ms.EmployeeID)) = ltrim(rtrim(a.EmployeeID))
                      and cast(@OTDate as date) between cast(ms.ChangedDate as date) and cast(ms.StatusEndDate as date)
                    order by ms.ChangedDate desc
                ) as varchar(10)), 'NONE') as IsAllowLate

            from tblOTActualDetailNIVS a
            left join #tmpLatestPlan cp on a.EmployeeID = cp.EmployeeID
            left join dbo.fn_vtblEmployeeList_Simple_ByDate(getdate(), '-1',null) e on a.EmployeeID = e.EmployeeID
            left join tblShiftSetting s on s.ShiftID = isnull(a.ShiftID, cp.ShiftID)
            left join tblMappingShiftHolidayStatus map on s.ShiftCode = map.ShiftCode
            left join #empDivRange dr on a.EmployeeID = dr.EmployeeID and @OTDate between dr.ChangedDate and dr.EndDate
            left join tblDivision td on dr.DivisionID = td.DivisionID
            where a.Identity_ID = @ActualMasterID;
        end
        else
        begin
            select cp.EmployeeID, isnull(e.FullName, 'N/A') as FullName,s.ShiftCode as shiftCode,
                cp.ShiftID, s.ShiftName, s.WorkStart, s.WorkEnd, s.OTBeforeStart, s.OTBeforeEnd, s.OTAfterStart, s.OTAfterEnd,
                cp.OTFrom as Planned_OTFrom, cp.OTTo as Planned_OTTo,
                a.Actual_OTFrom as Saved_OTFrom, a.Actual_OTTo as Saved_OTTo,
                isnull(a.Actual_OTHours, 0) as Actual_OTHours,
                isnull(e.EmployeeTypeID, 1) as EmployeeTypeID, isnull(e.PositionID, '') as PositionID,
                isnull(map.HolidayStatusID, 0) as HolidayStatus,
                isnull(cp.IsExceed, 0) as IsExceed,
                isnull(cp.IsExtraEmp, 0) as IsExtraEmp,
                isnull(cp.IsIndirectEmp, @IsDivision) as IsIndirectEmp,

                cast(isnull(td.Direct, 1) as varchar) as IsDirect,

                isnull((
                    select top 1 exMaster.Approve_Status
                    from tblOTExceedDetailNIVS exDet
                    join tblOTExceedMasterNIVS exMaster on exDet.Identity_ID = exMaster.Identity_ID
                    where exDet.EmployeeID = cp.EmployeeID
                      and cast(exMaster.OTDate as date) = cast(@OTDate as date)
                    order by exMaster.CreateTime desc
                ), 0) as ExceedApproveStatus,
                @ActualStatus as Approve_Status,
                isnull(cp.LimitType, '') as LimitType,
                isnull(cp.CurrentTotalOT, 0) as BaseOT_Before,
                isnull(cp.ConsecutiveDays, 0) as ConsecutiveDays,
                isnull(cp.WorkedHolidays, 0) as WorkedHolidays,
                isnull(cast((
                    select top 1 case when isnull(ms.isAllowLate, 0) = 1 then '1' else '0' end
                    from #MaternityStatus ms
                    where ltrim(rtrim(ms.EmployeeID)) = ltrim(rtrim(cp.EmployeeID))
                      and cast(@OTDate as date) between cast(ms.ChangedDate as date) and cast(ms.StatusEndDate as date)
                    order by ms.ChangedDate desc
                ) as varchar(10)), 'NONE') as IsAllowLate

            from #tmpLatestPlan cp
            left join dbo.fn_vtblEmployeeList_Simple_ByDate(getdate(), '-1',null) e on cp.EmployeeID = e.EmployeeID
            left join tblShiftSetting s on cp.ShiftID = s.ShiftID
            left join tblMappingShiftHolidayStatus map on s.ShiftCode = map.ShiftCode
            left join tblOTActualDetailNIVS a on a.Identity_ID = @ActualMasterID and a.EmployeeID = cp.EmployeeID
            left join #empDivRange dr on cp.EmployeeID = dr.EmployeeID and @OTDate between dr.ChangedDate and dr.EndDate
            left join tblDivision td on dr.DivisionID = td.DivisionID;
        end

        drop table #tmpLatestPlan;
        drop table #tmpEmpsActual;
        drop table #MaternityStatus;
        drop table #empDivRange;

    end try
    begin catch
        select 'error' as result, error_message() as reason;
    end catch
end
GO