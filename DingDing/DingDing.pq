// This file contains your Data Connector logic
section DingDing;

[DataSource.Kind="DingDing", Publish="DingDing.Publish"]
shared DingDing.Contents = (Mode as text,corpid as text,corpsecret as text) =>  //Mode as text,corpid as text,corpsecret as text
    let
        Token=getToken(corpid,corpsecret),
        department=getDepartment(Token),
        employee=getEmployee(Token,department[id]),
        source=if(Mode="部门") then department 
        else if(Mode="员工") then employee 
        else if(Mode="考勤审批") then getApproval(Token)
        else if(Mode="打卡记录") then getAttendance(Token,employee[userid])
        else "无效的参数"
        in 
            source;
getToken=(Corpid as text,Corpsecret as text)=>
  let
    query=[corpid=Corpid,corpsecret=Corpsecret],//corpid="ding3d5947bb45b3e83f",corpsecret="sqvHbb0XjYlp9e9gdri8FyFhfzON25ticWwVPxIoWnDwn-nwveUthEOMIUTWzk0s"
    tokenbody = Json.Document(Web.Contents("https://oapi.dingtalk.com/gettoken",[Query=query])),
    result = if (Record.HasFields(tokenbody, {"error", "error_description"})) then 
                    error Error.Record(tokenbody[error], tokenbody[error_description], tokenbody)
                 else
                    tokenbody,
   access_token=tokenbody[access_token]
   in
   access_token;
getDepartment=(Token as text)=>
    let 
        url="https://oapi.dingtalk.com/department/list",
        query=[
        access_token=Token
        ],
        list=Json.Document(Web.Contents(url,[Query = query])),
        department = list[department],
        Table = Table.FromList(department, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        Source = Table.ExpandRecordColumn(Table, "Column1", {"createDeptGroup", "name", "id", "autoAddUser", "parentid"}, {"createDeptGroup", "name", "id", "autoAddUser", "parentid"})

    in
        Source;
getEmployee=(Token as text,departmentId as list)=>
    let
       data = List.Generate(
        () => [i=0,y=0],
        each [i]<List.Count(departmentId),
        each [i=[i]+1],
        each[query=[access_token=Token,department_id=Number.ToText(departmentId{[i]})],result=Json.Document(Web.Contents("https://oapi.dingtalk.com/user/list",[Query=query]))]),
        result = Table.FromRecords(data),
        #"Removed Columns" = Table.RemoveColumns(result,{"query"}),
        #"Expanded {0}" = Table.ExpandRecordColumn(#"Removed Columns", "result", {"errcode", "errmsg", "userlist"}, {"errcode", "errmsg", "userlist"}),
        #"Removed Columns1" = Table.RemoveColumns(#"Expanded {0}",{"errcode", "errmsg"}),
        #"Expanded {0}1" = Table.ExpandListColumn(#"Removed Columns1", "userlist"),
        table = Table.ExpandRecordColumn(#"Expanded {0}1", "userlist", {"unionid", "openId", "remark", "userid", "isBoss", "tel", "department", "workPlace", "email", "order", "dingId", "isLeader", "mobile", "active", "isAdmin", "avatar", "isHide", "jobnumber", "name", "position","hiredDate"}, {"unionid", "openId", "remark", "userid", "isBoss", "tel", "department", "workPlace", "email", "order", "dingId", "isLeader", "mobile", "active", "isAdmin", "avatar", "isHide", "jobnumber", "name", "position","hiredDate"}),
        Source=Table.Distinct(table, {"openId"})
        in
        Source;
getApproval=(Token as text)=>
    let
        Approvaltype={"PROC-EF6YJDXRN2-X4XBZQ78RZW7FHBH5TCR1-Z1WJS4QI-84","PROC-EF6YJDXRN2-X4XBZQ78RZW7FHBH5TCR1-E1WJS4QI-74","PROC-FF6Y696SO2-7I2FX6JQUD6G902HJR7X1-XJS8FKUI-TH","PROC-52IKRYIV-IB0U612TTCUSV2CK48EY1-KDNI9JFJ-1","PROC-EF6YJDXRN2-X4XBZQ78RZW7FHBH5TCR1-A0WJS4QI-54"},
        firstday=Date.StartOfYear(DateTime.LocalNow()),
        starttime=Number.Round(86400*(Number.From(firstday)-Number.From(#datetime(1970,1,1,8,0,0))),3)*1000,
        url="https://eco.taobao.com/router/rest",
		//迟到审批
        data = List.Generate(
              () => [cursor=0,result2=Table.FromRecords({}),type=""],
              each [cursor]<>null,
              each[list=Xml.Tables(Web.Contents(url, [Content=Text.ToBinary("method=dingtalk.smartwork.bpms.processinstance.list&session="&Token&"&v=2.0&process_code=PROC-52IKRYIV-IB0U612TTCUSV2CK48EY1-KDNI9JFJ-1&start_time="&Number.ToText(starttime)&"&cursor="&Number.ToText([cursor])),
                                                Headers=[#"Content-Type"="application/x-www-form-urlencoded;charset=utf-8"]])),
        result1 = Table.ExpandTableColumn(list, "result", {"ding_open_errcode", "result", "success"}, {"ding_open_errcode", "result.1", "success"}),
        result2 = Table.ExpandTableColumn(result1, "result.1", {"list", "next_cursor"}, {"list", "next_cursor"}),
        changetype = Table.TransformColumnTypes(result2,{{"next_cursor", Int64.Type}}),
        cursor= changetype[next_cursor]{0},type="PROC-52IKRYIV-IB0U612TTCUSV2CK48EY1-KDNI9JFJ-1"]),
        Table = Table.FromRecords(data),      
        #"Expanded {0}2" = Table.ExpandTableColumn(Table, "result2", {"ding_open_errcode", "list", "next_cursor", "success", "request_id"}, {"ding_open_errcode", "list.1", "next_cursor", "success", "request_id"}),
        #"Expanded {0}3" = Table.ExpandTableColumn(#"Expanded {0}2", "list.1", {"process_instance_top_vo"}, {"process_instance_top_vo"}),
        #"Expanded {0}4" = Table.ExpandTableColumn(#"Expanded {0}3", "process_instance_top_vo", {"approver_userid_list", "business_id", "cc_userid_list", "create_time", "finish_time", "form_component_values", "originator_dept_id", "originator_userid", "process_instance_id", "process_instance_result", "status", "title"}, {"approver_userid_list", "business_id", "cc_userid_list", "create_time", "finish_time", "form_component_values", "originator_dept_id", "originator_userid", "process_instance_id", "process_instance_result", "status", "title"}),
        #"Expanded {0}5" = Table.ExpandTableColumn(#"Expanded {0}4", "form_component_values", {"form_component_value_vo"}, {"form_component_value_vo"}),
        SourceTable = Table.RemoveColumns(#"Expanded {0}5",{ "cursor", "ding_open_errcode", "approver_userid_list", "cc_userid_list", "next_cursor", "success", "request_id"}),
		 data1 = List.Generate(
        () => [i=0],  
        each [i] <Table.RowCount(SourceTable),
        each [i=[i]+1], 
        each[list=SourceTable{[i]},type=SourceTable[form_component_value_vo]{[i]}[value]{0},reason=SourceTable[form_component_value_vo]{[i]}[value]{1},
        datetime=SourceTable[form_component_value_vo]{[i]}[value]{2},pic=SourceTable[form_component_value_vo]{[i]}[value]{3}]
       ),
       output = Table.FromRecords(data1),
       Replace = Table.ReplaceValue(output,"[","",Replacer.ReplaceText,{"datetime"}),
       Replace1 = Table.ReplaceValue(Replace,"]","",Replacer.ReplaceText,{"datetime"}),
       SplitColumn = Table.SplitColumn(Replace1, "datetime", Splitter.SplitTextByDelimiter(",", QuoteStyle.Csv), {"datetime.1", "datetime.2", "datetime.3"}),
       TransformColumn = Table.TransformColumnTypes(SplitColumn,{{"datetime.1", type datetime}, {"datetime.2", type datetime}, {"datetime.3", type number}}),
// 	   RemoveRowsWithErrors=Table.RemoveRowsWithErrors(TransformColumn, {"type"}),
       LateSource = Table.RenameColumns(TransformColumn,{{"datetime.1", "startdate"}, {"datetime.2", "enddate"}, {"datetime.3", "hours"}}),
      
//        //请假审批
 Leavedata = List.Generate(
              () => [cursor=0,result2=Table.FromRecords({}),type=""],
              each [cursor]<>null,
              each[list=Xml.Tables(Web.Contents(url, [Content=Text.ToBinary("method=dingtalk.smartwork.bpms.processinstance.list&session="&Token&"&v=2.0&process_code=PROC-EF6YJDXRN2-X4XBZQ78RZW7FHBH5TCR1-A0WJS4QI-54&start_time="&Number.ToText(starttime)&"&cursor="&Number.ToText([cursor])),
                                                Headers=[#"Content-Type"="application/x-www-form-urlencoded;charset=utf-8"]])),
        result1 = Table.ExpandTableColumn(list, "result", {"ding_open_errcode", "result", "success"}, {"ding_open_errcode", "result.1", "success"}),
        result2 = Table.ExpandTableColumn(result1, "result.1", {"list", "next_cursor"}, {"list", "next_cursor"}),
        changetype = Table.TransformColumnTypes(result2,{{"next_cursor", Int64.Type}}),
        cursor= changetype[next_cursor]{0},type="PROC-EF6YJDXRN2-X4XBZQ78RZW7FHBH5TCR1-A0WJS4QI-54"]),
        LeaveTable = Table.FromRecords(Leavedata),      
        LeaveExpanded = Table.ExpandTableColumn(LeaveTable, "result2", {"ding_open_errcode", "list", "next_cursor", "success", "request_id"}, {"ding_open_errcode", "list.1", "next_cursor", "success", "request_id"}),
        LeaveExpanded2 = Table.ExpandTableColumn(LeaveExpanded, "list.1", {"process_instance_top_vo"}, {"process_instance_top_vo"}),
        LeaveExpanded3 = Table.ExpandTableColumn(LeaveExpanded2, "process_instance_top_vo", {"approver_userid_list", "business_id", "cc_userid_list", "create_time", "finish_time", "form_component_values", "originator_dept_id", "originator_userid", "process_instance_id", "process_instance_result", "status", "title"}, {"approver_userid_list", "business_id", "cc_userid_list", "create_time", "finish_time", "form_component_values", "originator_dept_id", "originator_userid", "process_instance_id", "process_instance_result", "status", "title"}),
        LeaveExpanded4 = Table.ExpandTableColumn(LeaveExpanded3, "form_component_values", {"form_component_value_vo"}, {"form_component_value_vo"}),
        LeaveSourceTable = Table.RemoveColumns(LeaveExpanded4,{ "cursor", "ding_open_errcode", "approver_userid_list", "cc_userid_list", "next_cursor", "success", "request_id"}),
        Leavedata2 = List.Generate(
        () => [i=0],  
        each [i] <Table.RowCount(LeaveSourceTable),
        each [i=[i]+1], 
        each[list=LeaveSourceTable{[i]},type=LeaveSourceTable[form_component_value_vo]{[i]}[value]{0},datetime=LeaveSourceTable[form_component_value_vo]{[i]}[value]{1},
             days=LeaveSourceTable[form_component_value_vo]{[i]}[value]{2},
             reason=LeaveSourceTable[form_component_value_vo]{[i]}[value]{3},
             pic=LeaveSourceTable[form_component_value_vo]{[i]}[value]{4}]
       ),
       Leaveoutput = Table.FromRecords(Leavedata2) ,  
       LeaveReplace = Table.ReplaceValue(Leaveoutput ,"[","",Replacer.ReplaceText,{"datetime"}),
       LeaveReplace1 = Table.ReplaceValue(LeaveReplace,"]","",Replacer.ReplaceText,{"datetime"}),
       LeaveSplitColumn = Table.SplitColumn(LeaveReplace1, "datetime", Splitter.SplitTextByDelimiter(",", QuoteStyle.Csv), {"datetime.1", "datetime.2", "datetime.3"}),
       LeaveTransformColumn = Table.TransformColumnTypes(LeaveSplitColumn,{{"datetime.1", type datetime}, {"datetime.2", type datetime}, {"datetime.3", type number}}),
       LeaveSource = Table.RenameColumns(LeaveTransformColumn,{{"datetime.1", "startdate"}, {"datetime.2", "enddate"}, {"datetime.3", "hours"}}),
//出差
 BusinessTripData = List.Generate(
              () => [cursor=0,result2=Table.FromRecords({}),type=""],
              each [cursor]<>null,
              each[list=Xml.Tables(Web.Contents(url, [Content=Text.ToBinary("method=dingtalk.smartwork.bpms.processinstance.list&session="&Token&"&v=2.0&process_code=PROC-EF6YJDXRN2-X4XBZQ78RZW7FHBH5TCR1-E1WJS4QI-74&start_time="&Number.ToText(starttime)&"&cursor="&Number.ToText([cursor])),
                                                Headers=[#"Content-Type"="application/x-www-form-urlencoded;charset=utf-8"]])),
        result1 = Table.ExpandTableColumn(list, "result", {"ding_open_errcode", "result", "success"}, {"ding_open_errcode", "result.1", "success"}),
        result2 = Table.ExpandTableColumn(result1, "result.1", {"list", "next_cursor"}, {"list", "next_cursor"}),
        changetype = Table.TransformColumnTypes(result2,{{"next_cursor", Int64.Type}}),
        cursor= changetype[next_cursor]{0},type="PROC-EF6YJDXRN2-X4XBZQ78RZW7FHBH5TCR1-E1WJS4QI-74"]),
        BusinessTripTable = Table.FromRecords(BusinessTripData),      
        BusinessTripExpanded = Table.ExpandTableColumn(BusinessTripTable, "result2", {"ding_open_errcode", "list", "next_cursor", "success", "request_id"}, {"ding_open_errcode", "list.1", "next_cursor", "success", "request_id"}),
        BusinessTripExpanded2 = Table.ExpandTableColumn(BusinessTripExpanded, "list.1", {"process_instance_top_vo"}, {"process_instance_top_vo"}),
        BusinessTripExpanded3 = Table.ExpandTableColumn(BusinessTripExpanded2, "process_instance_top_vo", {"approver_userid_list", "business_id", "cc_userid_list", "create_time", "finish_time", "form_component_values", "originator_dept_id", "originator_userid", "process_instance_id", "process_instance_result", "status", "title"}, {"approver_userid_list", "business_id", "cc_userid_list", "create_time", "finish_time", "form_component_values", "originator_dept_id", "originator_userid", "process_instance_id", "process_instance_result", "status", "title"}),
        BusinessTripExpanded4 = Table.ExpandTableColumn(BusinessTripExpanded3, "form_component_values", {"form_component_value_vo"}, {"form_component_value_vo"}),
        BusinessTripSourceTable = Table.RemoveColumns(BusinessTripExpanded4,{ "cursor", "ding_open_errcode", "approver_userid_list", "cc_userid_list", "next_cursor", "success", "request_id"}),
        BusinessTripData2 = List.Generate(
        () => [i=0],  
        each [i] <Table.RowCount(BusinessTripSourceTable),
        each [i=[i]+1], 
        each[list=BusinessTripSourceTable{[i]},type=BusinessTripSourceTable[form_component_value_vo]{[i]}[value]{0},days=BusinessTripSourceTable[form_component_value_vo]{[i]}[value]{1},
reason=BusinessTripSourceTable[form_component_value_vo]{[i]}[value]{2},pic=BusinessTripSourceTable[form_component_value_vo]{[i]}[value]{4}]
       ),
    BusinessTripoutput = Table.FromRecords(BusinessTripData2),
    BusinessTripSplitColumn = Table.SplitColumn(BusinessTripoutput, "type", Splitter.SplitTextByDelimiter(",", QuoteStyle.Csv), {"type.1", "type.2", "type.3", "type.4", "type.5", "type.6", "type.7", "type.8"}),
    BusinessTripTransformColumn = Table.TransformColumnTypes(BusinessTripSplitColumn,{{"type.1", type text}, {"type.2", type text}, {"type.3", type text}, {"type.4", type text}, {"type.5", type text}, {"type.6", type text}, {"type.7", type text}, {"type.8", type text}}),
    BusinessTripRemoveColumns = Table.RemoveColumns(BusinessTripTransformColumn,{"type.1", "type.2", "type.3", "type.4", "type.5", "type.8"}),
    BusinessTripReplaceValue = Table.ReplaceValue(BusinessTripRemoveColumns,"value:[","",Replacer.ReplaceText,{"type.6"}),
    BusinessTripReplaceValue1 = Table.ReplaceValue(BusinessTripReplaceValue,"]","",Replacer.ReplaceText,{"type.7"}),
    BusinessTripSource = Table.RenameColumns(BusinessTripReplaceValue1,{{"type.6", "startdate"}, {"type.7", "enddate"}}),
//外出
    GoOutData = List.Generate(
              () => [cursor=0,result2=Table.FromRecords({}),type=""],
              each [cursor]<>null,
              each[list=Xml.Tables(Web.Contents(url, [Content=Text.ToBinary("method=dingtalk.smartwork.bpms.processinstance.list&session="&Token&"&v=2.0&process_code=PROC-EF6YJDXRN2-X4XBZQ78RZW7FHBH5TCR1-Z1WJS4QI-84&start_time="&Number.ToText(starttime)&"&cursor="&Number.ToText([cursor])),
                                                Headers=[#"Content-Type"="application/x-www-form-urlencoded;charset=utf-8"]])),
        result1 = Table.ExpandTableColumn(list, "result", {"ding_open_errcode", "result", "success"}, {"ding_open_errcode", "result.1", "success"}),
        result2 = Table.ExpandTableColumn(result1, "result.1", {"list", "next_cursor"}, {"list", "next_cursor"}),
        changetype = Table.TransformColumnTypes(result2,{{"next_cursor", Int64.Type}}),
        cursor= changetype[next_cursor]{0},type="PROC-EF6YJDXRN2-X4XBZQ78RZW7FHBH5TCR1-Z1WJS4QI-84"]),
        GoOutTable = Table.FromRecords(GoOutData),      
        GoOutExpanded = Table.ExpandTableColumn(GoOutTable, "result2", {"ding_open_errcode", "list", "next_cursor", "success", "request_id"}, {"ding_open_errcode", "list.1", "next_cursor", "success", "request_id"}),
        GoOutExpanded2 = Table.ExpandTableColumn(GoOutExpanded, "list.1", {"process_instance_top_vo"}, {"process_instance_top_vo"}),
        GoOutExpanded3 = Table.ExpandTableColumn(GoOutExpanded2, "process_instance_top_vo", {"approver_userid_list", "business_id", "cc_userid_list", "create_time", "finish_time", "form_component_values", "originator_dept_id", "originator_userid", "process_instance_id", "process_instance_result", "status", "title"}, {"approver_userid_list", "business_id", "cc_userid_list", "create_time", "finish_time", "form_component_values", "originator_dept_id", "originator_userid", "process_instance_id", "process_instance_result", "status", "title"}),
        GoOutExpanded4 = Table.ExpandTableColumn(GoOutExpanded3, "form_component_values", {"form_component_value_vo"}, {"form_component_value_vo"}),
        GoOutSourceTable = Table.RemoveColumns(GoOutExpanded4,{ "cursor", "ding_open_errcode", "approver_userid_list", "cc_userid_list", "next_cursor", "success", "request_id"}),
        GoOutData2 = List.Generate(
        () => [i=0],  
        each [i] <Table.RowCount(GoOutSourceTable),
        each [i=[i]+1], 
        each[list=GoOutSourceTable{[i]},datetime=GoOutSourceTable[form_component_value_vo]{[i]}[value]{0},hours=GoOutSourceTable[form_component_value_vo]{[i]}[value]{1},
reason=GoOutSourceTable[form_component_value_vo]{[i]}[value]{2},pic=GoOutSourceTable[form_component_value_vo]{[i]}[value]{3}]
       ),
    GoOutoutput = Table.FromRecords(GoOutData2),
    GoOutReplaceValue = Table.ReplaceValue(GoOutoutput,"[","",Replacer.ReplaceText,{"datetime"}),
    GoOutReplaceValue1 = Table.ReplaceValue(GoOutReplaceValue,"]","",Replacer.ReplaceText,{"datetime"}),
    GoOutSplitColumn = Table.SplitColumn(GoOutReplaceValue1, "datetime", Splitter.SplitTextByDelimiter(",", QuoteStyle.Csv), {"datetime.1", "datetime.2"}),
    GoOutTransformColumn = Table.TransformColumnTypes(GoOutSplitColumn,{{"datetime.1", type datetime}, {"datetime.2", type datetime}}),
    GoOutSource = Table.RenameColumns(GoOutTransformColumn,{{"datetime.1", "startdate"}, {"datetime.2", "enddate"}, {"hours", "hours"}}),
    TotalTable=Table.Combine({LeaveSource,BusinessTripSource,GoOutSource,LateSource}),
    Source=Table.RemoveRowsWithErrors(TotalTable, {"type"})
    in
       Source;
getAttendance=(Token as text,userId as list)=>
    let
        Calendars=CreateCalendars(List.Count(userId)),
        url="https://oapi.dingtalk.com/attendance/list?access_token="&Token,
        data = List.Generate(
        () => [i=0],
        each [i]<Table.RowCount(Calendars),
        each [i=[i]+1],
        each[list=Json.Document(Web.Contents(url,[
               Content = Text.ToBinary(Text.FromBinary(Json.FromValue([userIds=userId,workDateFrom =DateTime.ToText(Calendars[startdate]{[i]}, "yyyy-MM-dd HH:mm:ss"),workDateTo= DateTime.ToText(Calendars[enddate]{[i]}, "yyyy-MM-dd HH:mm:ss"),offset=Calendars[offset]{[i]},limit=Calendars[limit]{[i]} ]))),
               Headers=[#"Content-Type"="application/json"]]))]),
       output = Table.FromRecords(data),
       ExpandRecordColumn = Table.ExpandRecordColumn(output, "list", {"errcode", "hasMore", "errmsg", "recordresult"}, {"errcode", "hasMore", "errmsg", "recordresult"}),
       ExpandListColumn = Table.ExpandListColumn(ExpandRecordColumn, "recordresult"),
       ExpandRecordColumn1 = Table.ExpandRecordColumn(ExpandListColumn, "recordresult", {"checkType", "corpId", "locationResult", "baseCheckTime", "groupId", "timeResult", "userId", "recordId", "workDate", "sourceType", "userCheckTime", "planId", "id"}, {"checkType", "corpId", "locationResult", "baseCheckTime", "groupId", "timeResult", "userId", "recordId", "workDate", "sourceType", "userCheckTime", "planId", "id"}),
       AddColumn= Table.AddColumn(ExpandRecordColumn1, "打卡类型", each if [checkType] = "OnDuty" then "上班打卡" else if [checkType] = "OffDuty" then "下班打卡" else null),
       AddColumn1 = Table.AddColumn(AddColumn, "自定义", each #datetime(1970,1,1,0,0,0)+#duration(0, 8, 0,[userCheckTime]/1000)),
       TransformColumn = Table.TransformColumnTypes(AddColumn1,{{"workDate", type text}, {"userCheckTime", type text}, {"baseCheckTime", type text}}),
       AddColumn2 = Table.AddColumn(TransformColumn, "打卡情况", each if [timeResult] = "Normal" then "正常" else if [timeResult] = "Late" then "迟到" else if [timeResult] = "SeriousLate" then "严重迟到" else if [timeResult] = "Absenteeism" then "旷工迟到" else if [timeResult] = "NotSigned" then "缺卡" else if [timeResult] = "Early" then "早退" else null),
       RenameColumns = Table.RenameColumns(AddColumn2,{{"自定义", "打卡时间"}}),
       DuplicateColumn = Table.DuplicateColumn(RenameColumns, "打卡时间", "打卡时间 - 复制"),
       RenameColumns1 = Table.RenameColumns(DuplicateColumn,{{"打卡时间 - 复制", "日期"}}),
       Source= Table.TransformColumnTypes(RenameColumns1,{{"日期", type date}})
        in
            Source;
CreateCalendars=(usercount as number)=>
    let
    thisfirstday=Date.StartOfMonth(DateTime.LocalNow()),
    thisalldays = Date.DaysInMonth(thisfirstday), 
    lastMonthfirstday=Date.AddMonths(thisfirstday,-1),
    lastalldays = Date.DaysInMonth(lastMonthfirstday), 
    totaldays=thisalldays+lastalldays,
    data = List.Generate(
        () => [i=0,startdate=lastMonthfirstday-#duration(0,0,0,0),enddate=lastMonthfirstday+#duration(0,23,59,59)],
        each [i]<totaldays,
        each [i=[i]+1,startdate=Date.AddDays([startdate],1),enddate=Date.AddDays([enddate],1)]
      ),
      output = Table.FromRecords(data),
      looptime=Number.RoundUp(usercount*2/50),
data3 = List.Generate(
        () => [i=0,startdate= output[startdate]{0},enddate= output[enddate]{0},list={[]}],
        each [i]<=Table.RowCount(output),
        each [i=[i]+1,startdate= output [startdate]{[i]},enddate= output[enddate]{[i]},list=List.Generate(
        ()=>[j=0,offset=0,limit=50],
        each [j]<looptime,
        each [j=[j]+1,offset=j*50,limit=50]
)]
      ),
       output3 = Table.FromRecords(data3),
    ExpandListColumn = Table.ExpandListColumn(output3, "list"),
    ExpandRecordColumn = Table.ExpandRecordColumn(ExpandListColumn, "list", {"j", "offset", "limit"}, {"j", "offset", "limit"}),
    TransformColumnTypes = Table.TransformColumnTypes(ExpandRecordColumn,{{"startdate", type datetime}, {"enddate", type datetime}}),
    Source = Table.SelectRows(TransformColumnTypes, each ([j] <> null))

        in
            Source;

// Data Source Kind description
DingDing = [
    Authentication = [
        // Key = [],
        // UsernamePassword = [],
        // Windows = [],
        Implicit = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
DingDing.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = DingDing.Icons,
    SourceTypeImage = DingDing.Icons
];

DingDing.Icons = [
    Icon16 = { Extension.Contents("DingDing16.png"), Extension.Contents("DingDing20.png"), Extension.Contents("DingDing24.png"), Extension.Contents("DingDing32.png") },
    Icon32 = { Extension.Contents("DingDing32.png"), Extension.Contents("DingDing40.png"), Extension.Contents("DingDing48.png"), Extension.Contents("DingDing64.png") }
];
