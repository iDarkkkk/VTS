
if object_id('[dbo].[API_GetOTRegistrationByID]') is null
	EXEC ('CREATE PROCEDURE [dbo].[API_GetOTRegistrationByID] as select 1')
GO

ALTER PROCEDURE [dbo].[API_GetOTRegistrationByID]
    @Identity_ID varchar(100)
as
begin
    set nocount on;
    begin try
        declare @GroupID int, @DivisionID int, @FromDate date, @ToDate date, @IsDivision int, @RegisterBy varchar(50), @IsProduction4Section bit = 0;
        select top 1 @GroupID = GroupID, @DivisionID = DivisionID, @FromDate = OTDateFrom, @ToDate = OTDateTo, @IsDivision = isnull(IsDivision, 0), @RegisterBy = RegisterBy
        from tblOTListRegisteredNIVS where Identity_ID = @Identity_ID;

        declare @TargetID int = case when @IsDivision = 1 then @DivisionID else @GroupID end;

        if @IsDivision = 0 and exists (
            select 1
            from tblSC_Login l
            inner join dbo.fn_vtblEmployeeList_Simple_ByDate(@ToDate, '-1', null) e on l.EmployeeID = e.EmployeeID
            inner join tblPosition p on e.PositionID = p.PositionID
            where l.LoginID = @RegisterBy and p.PositionName like '%Leader%' and e.DivisionID in (11, 17) and e.SectionID = @TargetID

            union

            select 1
            from tblSC_Login l
            inner join tblReponLeader rl on l.EmployeeID = rl.EmployeeID
            inner join dbo.fn_vtblEmployeeList_Simple_ByDate(@ToDate, '-1', null) e on rl.EmployeeID = e.EmployeeID
            where l.LoginID = @RegisterBy and e.DivisionID in (11, 17) and e.SectionID = @TargetID

            union

            select 1
            from tblOTListRegisteredNIVS_Detail dt
            inner join dbo.fn_DivDepSecPosRange(0) r on dt.EmployeeID = r.EmployeeID and dt.OTDate between r.ChangedDate and r.EndDate
            where dt.Identity_ID = @Identity_ID and r.DivisionID in (11, 17) and r.SectionID = @TargetID
        )
        begin
            set @IsProduction4Section = 1;
        end
        --Hieu: check lại xem ca có dc cập nhật mới hay không

        update d
        set d.ShiftID = s.ShiftID
        from tblOTListRegisteredNIVS_Detail d
        inner join tblAttendanceSummary s on d.EmployeeID = s.EmployeeID and cast(d.OTDate as date) = cast(s.AttDate as date)
        where d.Identity_ID = @Identity_ID
          and s.ShiftID is not null
          and isnull(d.ShiftID, 0) <> s.ShiftID;


        select m.Identity_ID, m.Approve_Status, m.Current_Approved_Level, m.TypeRegister, m.GroupID, m.DivisionID, m.IsDivision, m.OTDateFrom, m.OTDateTo, m.Remark,
            upper(m.Approver_1) as Approver_1, concat(e1.EmployeeID, ' - ', e1.FullName ) as Approver1_Name, m.ApproveDate_1, m.ApproverRemark_1,
            upper(m.Approver_2) as Approver_2, concat(e2.EmployeeID, ' - ', e2.FullName ) as Approver2_Name, m.ApproveDate_2, m.ApproverRemark_2,
            upper(m.Approver_3) as Approver_3, concat(e3.EmployeeID, ' - ', e3.FullName ) as Approver3_Name, m.ApproveDate_3, m.ApproverRemark_3,
            upper(m.Approver_4) as Approver_4, concat(e4.EmployeeID, ' - ', e4.FullName ) as Approver4_Name, m.ApproveDate_4, m.ApproverRemark_4,
            m.CreateTime, concat(sc.EmployeeID, ' - ', e.FullName)  as RegisterBy,
            case when m.IsDivision = 1 then isnull((select DivisionName from tblDivision where DivisionID = m.DivisionID), 'N/A')
                 when @IsProduction4Section = 1 then isnull((select SectionName from tblSection where SectionID = m.GroupID), 'N/A')
                 else isnull((select GroupTeamName from tblGroupTeam where GroupTeamID = m.GroupID), 'N/A') end as GroupName
        from tblOTListRegisteredNIVS m
        left join tblEmployee e1 on m.Approver_1 = e1.EmployeeID
        left join tblEmployee e2 on m.Approver_2 = e2.EmployeeID
        left join tblEmployee e3 on m.Approver_3 = e3.EmployeeID
        left join tblEmployee e4 on m.Approver_4 = e4.EmployeeID
        left join tblSC_Login sc on sc.LoginID = m.RegisterBy
        left join tblEmployee e on e.EmployeeID = sc.EmployeeID
        where m.Identity_ID = @Identity_ID;

        create table #tmpEmployeeList (EmployeeID varchar(50), FullName nvarchar(200), HireDate date, LastWorkingDate date, EmployeeTypeID int, PositionID varchar(50), GroupTeamID int, IsExtraEmp int);
        create table #EmpGroupRange (EmployeeID varchar(50), EffectiveDate date, EndDate date);

        if exists (select 1 from tblOTListRegisteredNIVS_Detail where Identity_ID = @Identity_ID)
        begin
            insert into #tmpEmployeeList
            select distinct e.EmployeeID, e.FullName, e.HireDate, e.LastWorkingDate, e.EmployeeTypeID, e.PositionID, e.GroupTeamID, isnull(dt.IsExtraEmp, 0)
            from tblOTListRegisteredNIVS_Detail dt
            inner join fn_vtblEmployeeList_Simple_ByDate(@ToDate, '-1', null) e on dt.EmployeeID = e.EmployeeID
            where dt.Identity_ID = @Identity_ID;

            insert into #EmpGroupRange (EmployeeID, EffectiveDate, EndDate)
            select distinct EmployeeID, OTDate, OTDate
            from tblOTListRegisteredNIVS_Detail
            where Identity_ID = @Identity_ID;
        end
        else if @IsDivision = 0
        begin
            if @IsProduction4Section = 1
            begin
                insert into #EmpGroupRange (EmployeeID, EffectiveDate, EndDate)
                select EmployeeID, ChangedDate, EndDate from dbo.fn_DivDepSecPosRange(0)
                where DivisionID in (11, 17) and SectionID = @TargetID and ChangedDate <= @ToDate and EndDate >= @FromDate;
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

        insert into #DailyOTBase (EmployeeID, OTDate, Hrs)
        select EmployeeID, cast(AttDate as date), sum(isnull(ApprovedHours, 0))
        from tblAttendanceSummary
        where AttDate >= @StartOfMonth and AttDate <= @EndOfMonth
          and EmployeeID in (select EmployeeID from #tmpEmployeeList)
          and ApprovedHours is not null
        group by EmployeeID, cast(AttDate as date);

        insert into #DailyOTBase (EmployeeID, OTDate, Hrs)
        select EmployeeID, OTDate, Hrs from (
            select d.EmployeeID, cast(d.OTDate as date) as OTDate, isnull(d.OTHours, 0) as Hrs,
                   row_number() over(partition by d.EmployeeID, cast(d.OTDate as date) order by m.CreateTime desc) as rn
            from tblOTListRegisteredNIVS_Detail d
            join tblOTListRegisteredNIVS m on d.Identity_ID = m.Identity_ID
            where m.Approve_Status = 2
              and d.OTDate >= @StartOfMonth and d.OTDate <= @EndOfMonth
              and d.EmployeeID in (select EmployeeID from #tmpEmployeeList)
        ) T
        where rn = 1
        and not exists (select 1 from #DailyOTBase b where b.EmployeeID = T.EmployeeID and b.OTDate = T.OTDate);

        select e.EmployeeID, e.OTDate,
               isnull((select sum(Hrs) from #DailyOTBase b where b.EmployeeID = e.EmployeeID and b.OTDate >= datefromparts(year(e.OTDate), month(e.OTDate), 1) and b.OTDate < e.OTDate), 0) as Calculated_BaseOT
        into #OTRunningTotals from #ValidEmpDates e;

        select EmployeeID, AttDate as OTDate, isnull(sum(ApprovedHours), 0) as DailyApprovedOT into #RangeOT from tblAttendanceSummary where AttDate between @FromDate and @ToDate group by EmployeeID, AttDate;

        -- =========================================================================
        select e.EmployeeID, e.FullName, isnull(rt.Calculated_BaseOT, 0) as BaseOT_Before,
            isnull(r.DailyApprovedOT, 0) as DB_ApprovedHours, e.OTDate as ScheduleDate,
            isnull(dt.ShiftID, s.ShiftID) as ShiftID,
            ss.ShiftName, ss.WorkStart, ss.WorkEnd, ss.OTBeforeStart, ss.OTBeforeEnd, ss.OTAfterStart, ss.OTAfterEnd,
            dt.OTFrom as Saved_OTFrom, dt.OTTo as Saved_OTTo, isnull(m.HolidayStatusID, 0) as HolidayStatus, e.EmployeeTypeID, e.PositionID, e.IsExtraEmp,
            isnull(dt.OTHours, 0) as OTHours, isnull(dt.IsExceed, 0) as IsExceed, isnull(dt.LimitType, '') as LimitType, isnull(dt.CurrentTotalOT, 0) as CurrentTotalOT,

            isnull(hc.WorkedHolidays, 0) as WorkedHolidays,
            isnull(cc.ConsecUpToThisDay, 0) as ConsecutiveDays,

            isnull(dt.IsIndirectEmp, @IsDivision) as IsIndirectEmp, dt.Original_OTTo, dt.Original_OTFrom,
            isnull((
                select
                    l.LogID,
                    l.ApproveLevel,
                    l.EditedBy,
                    concat(l.EditedBy, ' - ', isnull(el.FullName, isnull(el2.FullName, ''))) as EditedByName,
                    l.OldFrom,
                    l.OldTo,
                    l.OldHours,
                    l.NewFrom,
                    l.NewTo,
       l.NewHours,
                    l.EditRemark,
                    l.EditTime
                from tblOTListRegisteredNIVS_Detail_EditLog l
                left join tblEmployee el on el.EmployeeID = l.EditedBy
                left join tblSC_Login sl on cast(sl.LoginID as varchar(50)) = l.EditedBy
                left join tblEmployee el2 on el2.EmployeeID = sl.EmployeeID
                where cast(l.Identity_ID as varchar(100)) = cast(dt.Identity_ID as varchar(100))
                  and l.EmployeeID = dt.EmployeeID
                  and cast(l.OTDate as date) = cast(dt.OTDate as date)
                order by l.LogID
                for json path
            ), '[]') as EditHistoryJson,

            cast(isnull(td.Direct, 1) as varchar) as IsDirect,

            isnull(cast((
                select top 1 case when isnull(ms.isAllowLate, 0) = 1 then '1' else '0' end
                from #MaternityStatus ms
                where ltrim(rtrim(ms.EmployeeID)) = ltrim(rtrim(e.EmployeeID))
                  and cast(e.OTDate as date) between cast(ms.ChangedDate as date) and cast(ms.StatusEndDate as date)
                order by ms.ChangedDate desc
            ) as varchar(10)), 'NONE') as IsAllowLate

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

        order by e.EmployeeID, e.OTDate;

        drop table #tmpEmployeeList;
        drop table #EmpGroupRange;
        drop table #MaternityStatus;
        drop table #EmpHolidayWorked;
        drop table #HolidayCounts;
        drop table #EmpWorkTimeline;
        drop table #Islands;
        drop table #IslandCounts;
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
