
if object_id('[dbo].[API_CreateOrGetOTRegistration]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_CreateOrGetOTRegistration] as select 1')
GO

ALTER PROCEDURE [dbo].[API_CreateOrGetOTRegistration]
    @TargetID int,
    @FromDate date,
    @ToDate date,
    @LoginID varchar(50),
    @TypeRegister int,
    @IsDivision int = 0
as
begin
    set nocount on;
    begin try
        declare @Identity_ID varchar(100), @Status int, @IsProduction4Section bit = 0;

        declare @GroupID int = case when @IsDivision = 0 then @TargetID else null end;
        declare @DivisionID int = case when @IsDivision = 1 then @TargetID else null end;

        if @IsDivision = 0 and exists (
            select 1
            from tblSC_Login l
            inner join dbo.fn_vtblEmployeeList_Simple_ByDate(@ToDate, '-1', null) e on l.EmployeeID = e.EmployeeID
            inner join tblPosition p on e.PositionID = p.PositionID
            inner join dbo.fn_DivDepSecPosRange(0) r on e.EmployeeID = r.EmployeeID and r.ChangedDate <= @ToDate and r.EndDate >= @FromDate
            where l.LoginID = @LoginID and p.PositionName like '%Leader%' and r.DivisionID in (11, 17) and r.SectionID = @TargetID

            union

            select 1
            from tblSC_Login l
            inner join tblReponLeader rl on l.EmployeeID = rl.EmployeeID
            inner join dbo.fn_vtblEmployeeList_Simple_ByDate(@ToDate, '-1', null) e on rl.EmployeeID = e.EmployeeID
            inner join dbo.fn_DivDepSecPosRange(0) r on e.EmployeeID = r.EmployeeID and r.ChangedDate <= @ToDate and r.EndDate >= @FromDate
            where l.LoginID = @LoginID and r.DivisionID in (11, 17) and r.SectionID = @TargetID

            union

            select 1
            from tblSC_Login l
            inner join dbo.fn_vtblEmployeeList_Simple_ByDate(@ToDate, '-1', null) e on l.EmployeeID = e.EmployeeID
            inner join tblDivision d on d.DivisionID in (11, 17)
            cross apply string_split(cast(d.ClerkEmployeeID as varchar(500)), '&')
            where l.LoginID = @LoginID and ltrim(rtrim(value)) = l.EmployeeID and e.DivisionID in (11, 17) and e.SectionID = @TargetID
        )
        begin
            set @IsProduction4Section = 1;
        end

        select top 1 @Identity_ID = Identity_ID, @Status = Approve_Status from tblOTListRegisteredNIVS
        where isnull(GroupID, 0) = isnull(@GroupID, 0) and isnull(DivisionID, 0) = isnull(@DivisionID, 0)
          and OTDateFrom = @FromDate and OTDateTo = @ToDate and TypeRegister = @TypeRegister and Approve_Status = 0 and isnull(IsDivision, 0) = @IsDivision
          and RegisterBy = @LoginID;

        if @Identity_ID is null
        begin
            set @Identity_ID = cast(newid() as varchar(100)); set @Status = 0;
            insert into tblOTListRegisteredNIVS (Identity_ID, GroupID, DivisionID, RegisterBy, OTDateFrom, OTDateTo, Approve_Status, TypeRegister, CreateTime, Current_Approved_Level, IsDivision)
            values (@Identity_ID, @GroupID, @DivisionID, @LoginID, @FromDate, @ToDate, @Status, @TypeRegister, getdate(), 1, @IsDivision);
        end

        select m.*,
            case when m.IsDivision = 1 then isnull((select DivisionName from tblDivision where DivisionID = m.DivisionID), 'N/A')
                 when @IsProduction4Section = 1 then isnull((select SectionName from tblSection where SectionID = m.GroupID), 'N/A')
                 else isnull((select GroupTeamName from tblGroupTeam where GroupTeamID = m.GroupID), 'N/A') end as GroupName
        from tblOTListRegisteredNIVS m where m.Identity_ID = @Identity_ID;

        if @IsDivision = 1 and not exists (select 1 from tblOTListRegisteredNIVS_Detail where Identity_ID = @Identity_ID)
        begin
            return;
        end

        create table #tmpEmployeeList (EmployeeID varchar(50), FullName nvarchar(200), HireDate date, LastWorkingDate date, EmployeeTypeID int, PositionID varchar(50), GroupTeamID int, IsExtraEmp int);
        create table #EmpGroupRange (EmployeeID varchar(50), EffectiveDate date, EndDate date);

        if @IsDivision = 0
        begin
            if @IsProduction4Section = 1
            begin
                insert into #EmpGroupRange (EmployeeID, EffectiveDate, EndDate)
                select r.EmployeeID, r.ChangedDate, r.EndDate
                from dbo.fn_DivDepSecPosRange(0) r
                inner join tblSection targetSec on targetSec.SectionID = @TargetID
                inner join tblSection empSec on empSec.SectionID = r.SectionID
                where r.DivisionID in (11, 17)
                  and ltrim(rtrim(isnull(empSec.SectionName, ''))) = ltrim(rtrim(isnull(targetSec.SectionName, '')))
                  and r.ChangedDate <= @ToDate and r.EndDate >= @FromDate;
            end
            else
            begin
                insert into #EmpGroupRange (EmployeeID, EffectiveDate, EndDate)
                select EmployeeID, EffectiveDate, EndDate from dbo.fn_GroupTeamRange() where GroupTeamID = @TargetID and EffectiveDate <= @ToDate and EndDate >= @FromDate;
            end

            insert into #tmpEmployeeList
            select distinct e.EmployeeID, e.FullName, e.HireDate, e.LastWorkingDate, e.EmployeeTypeID, e.PositionID, e.GroupTeamID, 0
            from fn_vtblEmployeeList_Simple_ByDate(@ToDate, '-1', null) e inner join #EmpGroupRange gr on e.EmployeeID = gr.EmployeeID;

            insert into #tmpEmployeeList
            select distinct e.EmployeeID, e.FullName, e.HireDate, e.LastWorkingDate, e.EmployeeTypeID, e.PositionID, e.GroupTeamID, 1
            from fn_vtblEmployeeList_Simple_ByDate(@ToDate, '-1', null) e inner join tblOTListRegisteredNIVS_Detail dt on e.EmployeeID = dt.EmployeeID
            where dt.Identity_ID = @Identity_ID and isnull(dt.IsExtraEmp, 0) = 1 and e.EmployeeID not in (select EmployeeID from #tmpEmployeeList);
        end
        else
        begin
            insert into #tmpEmployeeList
            select distinct e.EmployeeID, e.FullName, e.HireDate, e.LastWorkingDate, e.EmployeeTypeID, e.PositionID, e.GroupTeamID, 0
            from fn_vtblEmployeeList_Simple_ByDate(@ToDate, '-1', null) e inner join tblOTListRegisteredNIVS_Detail dt on e.EmployeeID = dt.EmployeeID
            where dt.Identity_ID = @Identity_ID;
        end

        select Date as OTDate into #DateList from dbo.fn_datelist(@FromDate, @ToDate);

        select te.EmployeeID, te.FullName, dl.OTDate, te.EmployeeTypeID, te.PositionID, te.GroupTeamID, te.IsExtraEmp
      into #ValidEmpDates from #tmpEmployeeList te cross join #DateList dl
        where (@IsDivision = 1 and dl.OTDate between te.HireDate and isnull(te.LastWorkingDate, '2099-12-31'))
           or (@IsDivision = 0 and (
                (te.IsExtraEmp = 1 and dl.OTDate between te.HireDate and isnull(te.LastWorkingDate, '2099-12-31'))
                or
                (te.IsExtraEmp = 0 and dl.OTDate between te.HireDate and isnull(te.LastWorkingDate, '2099-12-31') and exists(select 1 from #EmpGroupRange gr where gr.EmployeeID = te.EmployeeID and dl.OTDate between gr.EffectiveDate and gr.EndDate))
           ));

        select * into #StatusRange from dbo.fn_EmployeeStatusRange(1) where EmployeeStatusID in (1, 20);
        delete fl from #ValidEmpDates fl inner join #StatusRange sr on fl.EmployeeID = sr.EmployeeID and fl.OTDate between sr.ChangedDate and sr.StatusEndDate;

        select * into #MaternityStatus from dbo.fn_EmployeeStatusRange(0) where EmployeeStatusID = 11 and EmployeeID in (select EmployeeID from #tmpEmployeeList);

        select * into #empDivRange from dbo.fn_DivDepSecPosRange(0) where EmployeeID in (select EmployeeID from #tmpEmployeeList);

        declare @LookBackDate date = dateadd(day, -100, @FromDate);
        declare @StartOfMonth date = datefromparts(year(@FromDate), month(@FromDate), 1);
        declare @EndOfMonth date = eomonth(@ToDate);

        -- =========================================================================

        create table #EmpHolidayWorked (EmployeeID varchar(50), WorkDate date, primary key (EmployeeID, WorkDate));

        insert into #EmpHolidayWorked (EmployeeID, WorkDate)
        select distinct EmployeeID, cast(AttDate as date)
        from tblAttendanceSummary
        where AttDate >= @StartOfMonth and AttDate <= @EndOfMonth
          and isnull(HolidayStatus, 0) > 0
          and AttStart is not null and AttEnd is not null
          and EmployeeID in (select EmployeeID from #tmpEmployeeList);

        insert into #EmpHolidayWorked (EmployeeID, WorkDate)
        select distinct d.EmployeeID, cast(d.OTDate as date)
        from tblOTListRegisteredNIVS_Detail d
        join tblOTListRegisteredNIVS m on d.Identity_ID = m.Identity_ID
        where m.Approve_Status = 2 and m.TypeRegister = 2
          and d.OTDate >= @StartOfMonth and d.OTDate <= @EndOfMonth
          and d.EmployeeID in (select EmployeeID from #tmpEmployeeList)
          and not exists (select 1 from #EmpHolidayWorked w where w.EmployeeID = d.EmployeeID and w.WorkDate = cast(d.OTDate as date));

        select v.EmployeeID, v.OTDate,
               isnull((select count(*) from #EmpHolidayWorked hw where hw.EmployeeID = v.EmployeeID and hw.WorkDate >= datefromparts(year(v.OTDate), month(v.OTDate), 1) and hw.WorkDate < v.OTDate), 0) as WorkedHolidays
        into #HolidayCounts from #ValidEmpDates v;

        -- =========================================================================

        create table #EmpWorkTimeline (EmployeeID varchar(50), WorkDate date, primary key (EmployeeID, WorkDate));

        insert into #EmpWorkTimeline (EmployeeID, WorkDate)
        select distinct EmployeeID, cast(AttDate as date)
        from tblAttendanceSummary
        where AttStart is not null and AttEnd is not null
          and AttDate >= @LookBackDate and AttDate <= @ToDate
          and EmployeeID in (select EmployeeID from #tmpEmployeeList);

        insert into #EmpWorkTimeline (EmployeeID, WorkDate)
        select distinct d.EmployeeID, cast(d.OTDate as date)
        from tblOTListRegisteredNIVS_Detail d
        join tblOTListRegisteredNIVS m on d.Identity_ID = m.Identity_ID
        where m.Approve_Status = 2
          and d.OTDate >= @LookBackDate and d.OTDate <= @ToDate
          and d.EmployeeID in (select EmployeeID from #tmpEmployeeList)
          and not exists (select 1 from #EmpWorkTimeline w where w.EmployeeID = d.EmployeeID and w.WorkDate = cast(d.OTDate as date));

        select EmployeeID, WorkDate, dateadd(day, -dense_rank() over(partition by EmployeeID order by WorkDate), WorkDate) as IslandGrp into #Islands from #EmpWorkTimeline;
        select EmployeeID, WorkDate, row_number() over(partition by EmployeeID, IslandGrp order by WorkDate) as ConsecUpToThisDay into #IslandCounts from #Islands;



        create table #DailyOTBase (EmployeeID varchar(50), OTDate date, Hrs float);

        select distinct EmployeeID, cast(AttDate as date) as OTDate into #AllDates
        from tblAttendanceSummary where AttDate >= @StartOfMonth and AttDate <= @EndOfMonth and EmployeeID in (select EmployeeID from #tmpEmployeeList);

        insert into #AllDates select distinct EmployeeID, cast(OTDate as date) from tblOTActualDetailNIVS where OTDate >= @StartOfMonth and OTDate <= @EndOfMonth and EmployeeID in (select EmployeeID from #tmpEmployeeList) and not exists (select 1 from #AllDates a where a.EmployeeID = tblOTActualDetailNIVS.EmployeeID and a.OTDate = cast(tblOTActualDetailNIVS.OTDate as date));

        insert into #AllDates select distinct EmployeeID, cast(OTDate as date) from tblOTListRegisteredNIVS_Detail where OTDate >= @StartOfMonth and OTDate <= @EndOfMonth and EmployeeID in (select EmployeeID from #tmpEmployeeList) and not exists (select 1 from #AllDates a where a.EmployeeID = tblOTListRegisteredNIVS_Detail.EmployeeID and a.OTDate = cast(tblOTListRegisteredNIVS_Detail.OTDate as date));

        insert into #DailyOTBase (EmployeeID, OTDate, Hrs)
        select
            ad.EmployeeID,
            ad.OTDate,
            coalesce(
                (select top 1 ApprovedHours from tblAttendanceSummary s where s.EmployeeID = ad.EmployeeID and cast(s.AttDate as date) = ad.OTDate and s.ApprovedHours is not null),

                (select top 1 act.Actual_OTHours from tblOTActualDetailNIVS act join tblOTActualMasterNIVS actM on act.Identity_ID = actM.Identity_ID where act.EmployeeID = ad.EmployeeID and cast(act.OTDate as date) = ad.OTDate and actM.Approve_Status = 2 order by actM.CreateTime desc),

                (select top 1 planD.OTHours from tblOTListRegisteredNIVS_Detail planD join tblOTListRegisteredNIVS planM on planD.Identity_ID = planM.Identity_ID where planD.EmployeeID = ad.EmployeeID and cast(planD.OTDate as date) = ad.OTDate and planM.Approve_Status = 2 order by planM.CreateTime desc),

                0
            ) as Hrs
        from #AllDates ad;

        select e.EmployeeID, e.OTDate,
               isnull((select sum(Hrs) from #DailyOTBase b where b.EmployeeID = e.EmployeeID and b.OTDate >= datefromparts(year(e.OTDate), month(e.OTDate), 1) and b.OTDate < e.OTDate), 0) as Calculated_BaseOT
        into #OTRunningTotals from #ValidEmpDates e;

        -- =========================================================================

        select EmployeeID, AttDate as OTDate, isnull(sum(ApprovedHours), 0) as DailyApprovedOT into #RangeOT from tblAttendanceSummary where AttDate between @FromDate and @ToDate group by EmployeeID, AttDate;

        select e.EmployeeID, e.FullName, isnull(rt.Calculated_BaseOT, 0) as BaseOT_Before,
            isnull(r.DailyApprovedOT, 0) as DB_ApprovedHours, e.OTDate as ScheduleDate,
            isnull(dt.ShiftID, s.ShiftID) as ShiftID,
            ss.ShiftName, ss.WorkStart, ss.WorkEnd, ss.OTBeforeStart, ss.OTBeforeEnd, ss.OTAfterStart, ss.OTAfterEnd,
            dt.OTFrom as Saved_OTFrom, dt.OTTo as Saved_OTTo, isnull(m.HolidayStatusID, 0) as HolidayStatus, e.EmployeeTypeID, e.PositionID, e.IsExtraEmp,
            isnull(dt.OTHours, 0) as OTHours, isnull(dt.IsExceed, 0) as IsExceed, isnull(dt.LimitType, '') as LimitType, isnull(dt.CurrentTotalOT, 0) as CurrentTotalOT,
            isnull(hc.WorkedHolidays, 0) as WorkedHolidays,
            isnull(cc.ConsecUpToThisDay, 0) as ConsecutiveDays,
            isnull(dt.IsIndirectEmp, @IsDivision) as IsIndirectEmp, dt.Original_OTTo, dt.Original_OTFrom,
            cast(isnull(td.Direct, 1) as varchar) as IsDirect,

         isnull(cast((
                select top 1 case when isnull(ms.isAllowLate, 0) = 1 then '1' else '0' end
                from #MaternityStatus ms
                where ltrim(rtrim(ms.EmployeeID)) = ltrim(rtrim(e.EmployeeID))
                  and cast(e.OTDate as date) between cast(ms.ChangedDate as date) and cast(ms.StatusEndDate as date)
                order by ms.ChangedDate desc
            ) as varchar(10)), 'NONE') as IsAllowLate
             ,td.DivisionName as DivisionName,
            gr.GroupTeamName as GroupTeamName
        from #ValidEmpDates e
        left join #OTRunningTotals rt on e.EmployeeID = rt.EmployeeID and e.OTDate = rt.OTDate
        left join #RangeOT r on e.EmployeeID = r.EmployeeID and r.OTDate = e.OTDate
        left join tblOTListRegisteredNIVS_Detail dt on e.EmployeeID = dt.EmployeeID and dt.OTDate = e.OTDate and dt.Identity_ID = @Identity_ID
        left join tblAttendanceSummary s on s.EmployeeID = e.EmployeeID and cast(s.AttDate as date) = e.OTDate
        left join tblShiftSetting ss on ss.ShiftID = isnull(dt.ShiftID, s.ShiftID)
        left join tblMappingShiftHolidayStatus m on m.ShiftCode = ss.ShiftCode
        left join #HolidayCounts hc on e.EmployeeID = hc.EmployeeID and e.OTDate = hc.OTDate
        left join #IslandCounts cc on e.EmployeeID = cc.EmployeeID and cc.WorkDate = dateadd(day, -1, e.OTDate)
        left join #empDivRange dr on e.EmployeeID = dr.EmployeeID and e.OTDate between dr.ChangedDate and dr.EndDate
        left join tblDivision td on dr.DivisionID = td.DivisionID
         left join tblGroupTeam gr on gr.GroupTeamID = e.GroupTeamID
        order by e.EmployeeID, e.OTDate;

        drop table #tmpEmployeeList;
        drop table #EmpGroupRange;
        drop table #MaternityStatus;
        drop table #EmpHolidayWorked;
        drop table #HolidayCounts;
        drop table #EmpWorkTimeline;
        drop table #Islands;
        drop table #IslandCounts;
        drop table #AllDates;
        drop table #DailyOTBase;
        drop table #OTRunningTotals;
        drop table #RangeOT;
        drop table #empDivRange;

    end try
    begin catch
        select 'error' as result, error_message() as reason;
    end catch
end
GO

exec API_CreateOrGetOTRegistration 313,'20260525','20260525',1263,1,0


