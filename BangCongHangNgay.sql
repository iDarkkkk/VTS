USE Paradise_NIVS_Cloud
GO
if object_id('[dbo].[EmployeeTimeSheet]') is null
	EXEC ('CREATE PROCEDURE [dbo].[EmployeeTimeSheet] as select 1')
GO
--exec EmployeeTimeSheet @FromDate='2018-03-01',@ToDate='2018-03-31',@LoginID=3
ALTER PROCEDURE [dbo].[EmployeeTimeSheet]
(
 @LoginID int,
 @Month int,
 @Year int,
 @LanguageID varchar(2) = 'VN',
 @isWeb int =0
)
AS
BEGIN
 set nocount on;

 declare @FromDateDef date, @ToDateDef date ,@FromDate date, @ToDate date
 SELECT @FromDateDef = FromDate, @ToDateDef = ToDate FROM dbo.fn_Get_SalaryPeriod(@Month, @Year)


 --DANH SÁCH CÁC NGÀY TRONG THÁNG MẶC ĐỊNH
 SELECT * INTO #fn_datelistDef FROM DBO.fn_datelist(@FromDateDef,@ToDateDef)

 --KIỂM TRA NGÀY ĐẦU TIÊN CỦA KỲ LƯƠNG THÁNG LÀ NGÀY  BAO NHIÊU
 SET @FromDate=@FromDateDef
 IF(DATEPART(DW,@FromDateDef) <> 2) set  @FromDate=dateadd(day,- (DATEPART(DW,@FromDateDef) - 2),@FromDateDef)
 IF(DATEPART(DW,@FromDateDef) = 1)  set  @FromDate=dateadd(day,-6,@FromDateDef)

 --KIỂM TRA NGÀY CUỐI CÙNG CỦA KỲ KỲ LƯƠNG LÀ NGÀY BAO NHIÊU
 SET @ToDate=@ToDateDef
 IF(DATEPART(DW,@ToDateDef) <> 1)  set  @ToDate=dateadd(day,8 - DATEPART(DW,@ToDateDef),@ToDateDef)

 declare @Br varchar(5) = '<br>'
 if @isWeb = 0 set @Br = ''

    if NOT EXISTS(SELECT TOP 1 1 FROM dbo.tblSC_Login s WHERE LoginID = @LoginID  AND EXISTS(SELECT TOP 1 1 FROM dbo.tblEmployee WHERE EmployeeID = s.EmployeeID))
   set @LoginID = (SELECT TOP 1 LoginID FROM dbo.tblSC_Login WHERE LoginID > 3 AND EmployeeID IN (SELECT top 1 EmployeeID FROM dbo.tblEmployee))

 declare @EmployeeID varchar(20)
 select @EmployeeID = EmployeeID  from tblSC_Login where LoginID = @LoginID

 if @LoginID =23 set @EmployeeID='72' --Dùng để test
 set @EmployeeID=isnull(@EmployeeID,'72')

 insert into tmpCheckLoginData(LogTime,LoginID,EmployeeID,Func)
 select GETDATE(),@LoginID,@EmployeeID,'EmployeeTimeSheet'

 -- gio vao, gio ra, nhieu mốc, Ký hiệu nghỉ
 -- Tổng công, tăng ca
 -- Đi trễ, về sớm
 -- Ghi chú
 select w.EmployeeID, w.ScheduleDate as AttDate,case when @LanguageID = 'VN' or len(ISNULL(lt.DescriptionEN,'')) < 1 then lt.Description else lt.DescriptionEN end --+ case when @isWeb = 0 then '' else '<br>' end + isnull(lv.Reason,'')
   as WorkingTime
 ,ls.LeaveStatus Description
 , ss.ShiftName, isnull(w.HolidayStatus,0) HolidayStatus
 ,'#'+REPLACE(lt.HilightColorCode,'#','') HilightColorCode
 ,lv.LeaveCode
 into #SelectData
 from tblWSchedule w
 left join tblShiftSetting ss on w.ShiftID = ss.ShiftID
 left join tblLvHistory lv on w.ScheduleDate = lv.LeaveDate and w.EmployeeID = lv.EmployeeID
 left join tblLeaveType lt on lv.LeaveCode = lt.LeaveCode
 left join tblLeaveStatus ls on lv.LeaveStatus = ls.LeaveStatusID
 where w.EmployeeID = @EmployeeID and w.ScheduleDate between @FromDate and @ToDate

 -- gio vao, ra nhieu moc
 select ta.EmployeeID, ta.AttDate, ta.Period, ta.AttStart, ta.AttEnd, case when isnull(s.HolidayStatus,0) > 0 then null else ta.WorkingTime end WorkingTime into #tblHasTA from  tblHasTA ta inner join #SelectData s on ta.EmployeeID = s.EmployeeID and ta.AttDate = s.AttDate where ta.EmployeeID = @EmployeeID and ta.AttDate between @FromDate and @ToDate and ta.AttDate <= GETDATE()
 update #tblHasTA set AttEnd = null,WorkingTime = null where AttEnd > GETDATE()
 update s set WorkingTime = isnull(s.WorkingTime,'') +  case when s.WorkingTime is null then '' else @Br end + isnull(CONVERT(varchar(5), t.AttStart,108),'')+ ' - '+ isnull(CONVERT(varchar(5), t.AttEnd,108),'')
 ,Description = isnull(s.Description,'') + case when s.HolidayStatus > 0 then '' else case when s.Description is null then '' else @Br end +  case when @LanguageID = 'VN' then 'Công: ' else 'Hours: ' end + isnull(CAST(t.WorkingTime as varchar(10)) ,'') end
 from  #SelectData s inner join #tblHasTA t on s.EmployeeID = t.EmployeeID and s.AttDate = t.AttDate and t.Period = 0 and (t.AttStart is not null or t.AttEnd is not null)
 update s set WorkingTime = isnull(s.WorkingTime,'') + case when s.WorkingTime is null then '' else @Br end + isnull(CONVERT(varchar(5), t.AttStart,108),'')+ ' - '+ isnull(CONVERT(varchar(5), t.AttEnd,108),'')
 ,Description = isnull(s.Description,'') + case when s.HolidayStatus > 0 then '' else case when s.Description is null then '' else @Br end +  case when @LanguageID = 'VN' then 'Công: ' else 'Hours: ' end + isnull(CAST(t.WorkingTime as varchar(10)) ,'') end
 from  #SelectData s inner join #tblHasTA t on s.EmployeeID = t.EmployeeID and s.AttDate = t.AttDate and t.Period = 1 and (t.AttStart is not null or t.AttEnd is not null)
 update s set WorkingTime = isnull(s.WorkingTime,'') + case when s.WorkingTime is null then '' else @Br end + isnull(CONVERT(varchar(5), t.AttStart,108),'')+ ' - '+ isnull(CONVERT(varchar(5), t.AttEnd,108),'')
 ,Description = isnull(s.Description,'') + case when s.HolidayStatus > 0 then '' else case when s.Description is null then '' else @Br end +  case when @LanguageID = 'VN' then 'Công: ' else 'Hours: ' end + isnull(CAST(t.WorkingTime as varchar(10)) ,'') end
 from  #SelectData s inner join #tblHasTA t on s.EmployeeID = t.EmployeeID and s.AttDate = t.AttDate and t.Period = 2 and (t.AttStart is not null or t.AttEnd is not null)
 update #SelectData set ShiftName = 'Off' where HolidayStatus > 0 and WorkingTime is null

 select EmployeeID,OTDate,OTKind,SUM(ApprovedHours) ApprovedHours
 into #tblOTList from tblOTList a where OTDate between @FromDate and @ToDate and Approved = 1 and exists(select 1 from #SelectData e where a.EmployeeID = e.EmployeeID)
 group by EmployeeID,OTDate,OTKind
 -- giờ công, tăng ca
 update s set Description = isnull(s.Description,'') + case when len(isnull(s.Description,'')) < 1 then '' else @Br end + t.ColumnDisplayName + ': ' + isnull(CAST(t.ApprovedHours as varchar(10)) ,'') from  #SelectData s inner join (select EmployeeID, OTDate, sum(o.ApprovedHours) ApprovedHours, os.ColumnDisplayName from #tblOTList o left join tblOvertimeSetting os on o.OTKind = os.OTKind where o.OTDate between @FromDate and @ToDate and o.OTKind = 11 group by EmployeeID, OTDate, os.ColumnDisplayName) t on s.EmployeeID = t.EmployeeID and s.AttDate = t.OTDate
 update s set Description = isnull(s.Description,'') + case when len(isnull(s.Description,'')) < 1 then '' else @Br end + t.ColumnDisplayName + ': ' + isnull(CAST(t.ApprovedHours as varchar(10)) ,'') from  #SelectData s inner join (select EmployeeID, OTDate, sum(o.ApprovedHours) ApprovedHours, os.ColumnDisplayName from #tblOTList o left join tblOvertimeSetting os on o.OTKind = os.OTKind where o.OTDate between @FromDate and @ToDate and o.OTKind = 22 group by EmployeeID, OTDate, os.ColumnDisplayName) t on s.EmployeeID = t.EmployeeID and s.AttDate = t.OTDate
 update s set Description = isnull(s.Description,'') + case when len(isnull(s.Description,'')) < 1 then '' else @Br end + t.ColumnDisplayName + ': ' + isnull(CAST(t.ApprovedHours as varchar(10)) ,'') from  #SelectData s inner join (select EmployeeID, OTDate, sum(o.ApprovedHours) ApprovedHours, os.ColumnDisplayName from #tblOTList o left join tblOvertimeSetting os on o.OTKind = os.OTKind where o.OTDate between @FromDate and @ToDate and o.OTKind = 23 group by EmployeeID, OTDate, os.ColumnDisplayName) t on s.EmployeeID = t.EmployeeID and s.AttDate = t.OTDate
 update s set Description = isnull(s.Description,'') + case when len(isnull(s.Description,'')) < 1 then '' else @Br end + t.ColumnDisplayName + ': ' + isnull(CAST(t.ApprovedHours as varchar(10)) ,'') from  #SelectData s inner join (select EmployeeID, OTDate, sum(o.ApprovedHours) ApprovedHours, os.ColumnDisplayName from #tblOTList o left join tblOvertimeSetting os on o.OTKind = os.OTKind where o.OTDate between @FromDate and @ToDate and o.OTKind = 26 group by EmployeeID, OTDate, os.ColumnDisplayName) t on s.EmployeeID = t.EmployeeID and s.AttDate = t.OTDate
 update s set Description = isnull(s.Description,'') + case when len(isnull(s.Description,'')) < 1 then '' else @Br end + t.ColumnDisplayName + ': ' + isnull(CAST(t.ApprovedHours as varchar(10)) ,'') from  #SelectData s inner join (select EmployeeID, OTDate, sum(o.ApprovedHours) ApprovedHours, os.ColumnDisplayName from #tblOTList o left join tblOvertimeSetting os on o.OTKind = os.OTKind where o.OTDate between @FromDate and @ToDate and o.OTKind = 21 group by EmployeeID, OTDate, os.ColumnDisplayName) t on s.EmployeeID = t.EmployeeID and s.AttDate = t.OTDate
 update s set Description = isnull(s.Description,'') + case when len(isnull(s.Description,'')) < 1 then '' else @Br end + t.ColumnDisplayName + ': ' + isnull(CAST(t.ApprovedHours as varchar(10)) ,'') from  #SelectData s inner join (select EmployeeID, OTDate, sum(o.ApprovedHours) ApprovedHours, os.ColumnDisplayName from #tblOTList o left join tblOvertimeSetting os on o.OTKind = os.OTKind where o.OTDate between @FromDate and @ToDate and o.OTKind = 27 group by EmployeeID, OTDate, os.ColumnDisplayName) t on s.EmployeeID = t.EmployeeID and s.AttDate = t.OTDate

 -----DANH SÁCH CÁC NGÀY TRONG TUẦN
 DECLARE @WEEK_NAME NVARCHAR(MAX)=''
 SELECT @WEEK_NAME+=N'
  <li>'+case when @isWeb = 2 then WeekNameShort else WeekName end+'</li>
 ' from DBO.fn_WeekName(@LanguageID)
 order by case when Code='Sunday' then 2 else 1 end

 -----DANH SÁCH CÁC NGÀY TRONG THÁNG
 DECLARE @DAY_MONTH NVARCHAR(MAX)=''
 SELECT @DAY_MONTH+=N'
  <li class="'+case when d.Date not in (select Date from #fn_datelistDef) then N'bg-secondary' else N'bg-body' end +N'">
   <span>'+
   case when MONTH(d.Date) <> @Month
       then (select MonthNameShort from dbo.fn_MonthName('EN') w where MONTH(d.Date) = w.Code) else N'' end
   +N' '+cast(DAY(Date) as varchar(10))
   +N'</span>
   <p style="border-radius: 5px;padding-left: 5px;text-align:left;background:#025656;margin:2px;"> '+ISNULL(s.ShiftName,'')+N' </p>
   <p style="border-radius: 5px;padding-left: 5px;text-align:left;background:'+isnull(s.HilightColorCode,'#027702')+N';margin:2px;">
    '+case when @isWeb=2 then isnull(ISNULL(s.LeaveCode,
     case when @isWeb=2 then REPLACE(s.WorkingTime,'-','') else s.WorkingTime end
    ),'') else ISNULL(s.WorkingTime,'') end+N'
   </p>
   <p style="border-radius: 5px;padding-left: 5px;text-align:left;background:#6501a3;margin:2px;"> '+ISNULL(s.Description,'')+N'</p>
  </li>

 ' FROM DBO.fn_datelist(@FromDate,@ToDate) d
 left join #SelectData s on s.AttDate=d.Date

 --select AttDate,WorkingTime,Description,ShiftName,HilightColorCode,LeaveCode from  #SelectData return

 declare @APPLICATION_ADDRESS nvarchar(max) = case when @isWeb = 0 then dbo.fn_GetAPPLICATION_ADDRESS() else '/' end
 declare @bootstrap nvarchar(max) = N'<link rel="stylesheet" href="'+@APPLICATION_ADDRESS+N'Content/bootstrap.min.css">
  <script src="'+@APPLICATION_ADDRESS+N'Scripts/bootstrap.min.js"></script>'
 if @isWeb != 0 set @bootstrap = ''

   declare @Query nvarchar(max)=''
   select @Query=N'
  '+@bootstrap+N'
  <style>
  .DashboarAttByEmployee {
   -ms-text-size-adjust: 100%;
   -webkit-text-size-adjust: 100%;
   box-sizing: border-box;
   font-family: "Poppins", sans-serif;
   font-size: 100%;
   font-weight: 300;
   color: white;
   line-height: 1.5;
   margin: 0;

  }

  .DashboarAttByEmployee ul ,
  .DashboarAttByEmployee ul:before,
  .DashboarAttByEmployee ul:after {
   box-sizing: inherit
  }

  .DashboarAttByEmployee li ,
  .DashboarAttByEmployee li:before,
  .DashboarAttByEmployee li:after {
   box-sizing: inherit
  }

  .DashboarAttByEmployee  h1 {
   font-size: 3rem;
   font-weight: 300
  }

  .DashboarAttByEmployee  h2 {
   font-size: 2.5rem;
   font-weight: 300
  }

  .DashboarAttByEmployee  ul {
   margin: 0;
   padding: 0;
   display: flex;
   flex-flow: row wrap
  }

  .DashboarAttByEmployee ul li {
   list-style-type: none;
   display: block;
   width: 14.285714%
  }

  .DashboarAttByEmployee ul li::before {
   content: "​"
  }

  .DashboarAttByEmployee .days-of-week li {
   text-align: center;
   /* color: black;*color: black; */;
   padding: 10px 0;
   border-top: 1px solid #e0e0e0;
   border-right: 1px solid #e0e0e0;
   border-bottom: 1px solid #e0e0e0;
  }

  .DashboarAttByEmployee .days-of-week li:first-child {
   border-left: 1px solid #e0e0e0;
  }

  .DashboarAttByEmployee .days-of-week li:last-child {
   border-right: 1px solid #e0e0e0;
  }

  .DashboarAttByEmployee .days-of-month li {
   position: relative;
   padding: 5px 5px 5px 0px;
   height: 125px;
   text-align: center;
   border-top: none;
   border-right: 1px solid #e0e0e0;
   border-bottom: 1px solid #e0e0e0;
   font-size: .8rem;
  }


  .DashboarAttByEmployee  .days-of-month li:nth-of-type(1) {
   border-left: 1px solid #e0e0e0;
  }

  .DashboarAttByEmployee  .days-of-month li:nth-of-type(7n+8) {
   border-left: 1px solid #e0e0e0;
  }

  .DashboarAttByEmployee  .days-of-month li span {
   position: absolute;
   top: 5px;
   /* color: black;*color: black; */;
   text-align: center;
  }
  @media screen and (max-width: 1500px) and (min-width: 768px) {
   .DashboarAttByEmployee {
    padding: 10px 5% !important;
   }
  }

  @media screen and (max-width: 768px) and (min-width: 270px) {
   .DashboarAttByEmployee {
    padding: 5px 0 !important;
   }
   .DashboarAttByEmployee .days-of-month li {
    font-size: .65rem !important;
    padding: 5px 0px 0px 0px !important;
   }
  }
  </style>

  <div class="DashboarAttByEmployee">

   <ul aria-label="Days of the Week" class="days-of-week">
    '+ISNULL(@WEEK_NAME,'')+N'

   </ul>

   <ul aria-label="Days of the Month" class="days-of-month">
    '+ISNULL(@DAY_MONTH,'')+N'
   </ul>
   </div>
   <script>HideLoadingByClassOrID("#EmployeeTimeSheet")</script>
  '
 select @Query as Col1

END
GO
exec EmployeeTimeSheet 1500, 3,2026,'VN',2