// This file contains your Data Connector logic
section DingDing;

[DataSource.Kind="DingDing", Publish="DingDing.Publish"]
shared DingDing.Contents = () =>  //Mode as text,corpid as text,corpsecret as text
    let
        Token=getToken("ding3d5947bb45b3e83f","sqvHbb0XjYlp9e9gdri8FyFhfzON25ticWwVPxIoWnDwn-nwveUthEOMIUTWzk0s"),
        department=getDepartment(Token),
        employee=getEmployee(Token,department[id]),
        Mode="考勤审批",
        source=if(Mode="部门") then department 
        else if(Mode="员工") then employee 
        else if(Mode="考勤审批") then getApproval(Token)
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
        Approvaltype={"PROC-EF6YJDXRN2-X4XBZQ78RZW7FHBH5TCR1-Z1WJS4QI-84","PROC-EF6YJDXRN2-X4XBZQ78RZW7FHBH5TCR1-Z1WJS4QI-84","PROC-EF6YJDXRN2-X4XBZQ78RZW7FHBH5TCR1-E1WJS4QI-74","PROC-FF6Y696SO2-7I2FX6JQUD6G902HJR7X1-XJS8FKUI-TH","PROC-52IKRYIV-IB0U612TTCUSV2CK48EY1-KDNI9JFJ-1","PROC-EF6YJDXRN2-X4XBZQ78RZW7FHBH5TCR1-A0WJS4QI-54"},
        firstday=Date.StartOfYear(DateTime.LocalNow()),
        starttime=Number.Round(86400*(Number.From(firstday)-Number.From(#datetime(1970,1,1,8,0,0))),3)*1000,
        url="https://eco.taobao.com/router/rest",
        data = List.Generate(
              () => [cursor=0,result2=Table.FromRecords({})],
              each [cursor]<>null,
              each[list=Xml.Tables(Web.Contents(url, [Content=Text.ToBinary("method=dingtalk.smartwork.bpms.processinstance.list&session="&Token&"&v=2.0&process_code=PROC-EF6YJDXRN2-X4XBZQ78RZW7FHBH5TCR1-Z1WJS4QI-84&start_time="&Number.ToText(starttime)&"&cursor="&Number.ToText([cursor])),
                                                Headers=[#"Content-Type"="application/x-www-form-urlencoded;charset=utf-8"]])),
        result1 = Table.ExpandTableColumn(list, "result", {"ding_open_errcode", "result", "success"}, {"ding_open_errcode", "result.1", "success"}),
        result2 = Table.ExpandTableColumn(result1, "result.1", {"list", "next_cursor"}, {"list", "next_cursor"}),
        changetype = Table.TransformColumnTypes(result2,{{"next_cursor", Int64.Type}}),
        cursor= changetype[next_cursor]{0},type="PROC-EF6YJDXRN2-X4XBZQ78RZW7FHBH5TCR1-Z1WJS4QI-84"]),
        Table = Table.FromRecords(data)
//         #"Expanded {0}" = Table.ExpandListColumn(Table, "data2"),
//         #"Expanded {0}1" = Table.ExpandRecordColumn(#"Expanded {0}", "data2", {"i", "cursor", "result2", "list", "result1", "changetype", "type"}, {"i", "cursor", "result2", "list", "result1", "changetype", "type"}),
//         #"Expanded {0}2" = Table.ExpandTableColumn(#"Expanded {0}1", "result2", {"ding_open_errcode", "list", "next_cursor", "success", "request_id"}, {"ding_open_errcode", "list.1", "next_cursor", "success", "request_id"}),
//         #"Expanded {0}3" = Table.ExpandTableColumn(#"Expanded {0}2", "list.1", {"process_instance_top_vo"}, {"process_instance_top_vo"}),
//         #"Expanded {0}4" = Table.ExpandTableColumn(#"Expanded {0}3", "process_instance_top_vo", {"approver_userid_list", "business_id", "cc_userid_list", "create_time", "finish_time", "form_component_values", "originator_dept_id", "originator_userid", "process_instance_id", "process_instance_result", "status", "title"}, {"approver_userid_list", "business_id", "cc_userid_list", "create_time", "finish_time", "form_component_values", "originator_dept_id", "originator_userid", "process_instance_id", "process_instance_result", "status", "title"}),
//         #"Expanded {0}5" = Table.ExpandTableColumn(#"Expanded {0}4", "form_component_values", {"form_component_value_vo"}, {"form_component_value_vo"}),
//         SourceTabel = Table.RemoveColumns(#"Expanded {0}5",{"i", "cursor", "ding_open_errcode", "approver_userid_list", "cc_userid_list", "next_cursor", "success", "request_id", "list", "result1", "changetype"}),
//        //迟到审批
//        Latelist = Table.SelectRows(SourceTabel, each ([type] = "PROC-52IKRYIV-IB0U612TTCUSV2CK48EY1-KDNI9JFJ-1")),
//         data1 = List.Generate(
//         () => [i=0],  
//         each [i] <Table.RowCount(Latelist),
//         each [i=[i]+1], 
//         each[list=Latelist{[i]},type=Latelist[form_component_value_vo]{[i]}[value]{0},reason=Latelist[form_component_value_vo]{[i]}[value]{1},
//         datetime=Latelist[form_component_value_vo]{[i]}[value]{2},pic=Latelist[form_component_value_vo]{[i]}[value]{3}]
//        ),
//        output = Table.FromRecords(data1),
//        Replace = Table.ReplaceValue(output,"[","",Replacer.ReplaceText,{"datetime"}),
//        Replace1 = Table.ReplaceValue(Replace,"]","",Replacer.ReplaceText,{"datetime"}),
//        SplitColumn = Table.SplitColumn(Replace1, "datetime", Splitter.SplitTextByDelimiter(",", QuoteStyle.Csv), {"datetime.1", "datetime.2", "datetime.3"}),
//        TransformColumn = Table.TransformColumnTypes(SplitColumn,{{"datetime.1", type datetime}, {"datetime.2", type datetime}, {"datetime.3", type number}}),
//        LateTbale = Table.RenameColumns(TransformColumn,{{"datetime.1", "startdate"}, {"datetime.2", "enddate"}, {"datetime.3", "hours"}}),
//        //请假审批
//        Leavelist = Table.SelectRows(SourceTabel, each ([type] = "PROC-EF6YJDXRN2-X4XBZQ78RZW7FHBH5TCR1-A0WJS4QI-54")),
//        Leavedata = List.Generate(
//         () => [i=0],  
//         each [i] <Table.RowCount(Leavelist),
//         each [i=[i]+1], 
//         each[list=Leavelist{[i]},type=Leavelist[form_component_value_vo]{[i]}[value]{0},datetime=Leavelist[form_component_value_vo]{[i]}[value]{1},
//              days=Leavelist[form_component_value_vo]{[i]}[value]{2},
//              reason=Leavelist[form_component_value_vo]{[i]}[value]{3},
//              pic=Leavelist[form_component_value_vo]{[i]}[value]{4}]
//        ),
//        Leaveoutput = Table.FromRecords(Leavedata) ,  
//        LeaveReplace = Table.ReplaceValue(Leaveoutput ,"[","",Replacer.ReplaceText,{"datetime"}),
//        LeaveReplace1 = Table.ReplaceValue(LeaveReplace,"]","",Replacer.ReplaceText,{"datetime"}),
//        LeaveSplitColumn = Table.SplitColumn(LeaveReplace1, "datetime", Splitter.SplitTextByDelimiter(",", QuoteStyle.Csv), {"datetime.1", "datetime.2", "datetime.3"}),
//        LeaveTransformColumn = Table.TransformColumnTypes(LeaveSplitColumn,{{"datetime.1", type datetime}, {"datetime.2", type datetime}, {"datetime.3", type number}}),
//        LeaveTable = Table.RenameColumns(LeaveTransformColumn,{{"datetime.1", "startdate"}, {"datetime.2", "enddate"}, {"datetime.3", "hours"}})
// 
        in
        Table;
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
