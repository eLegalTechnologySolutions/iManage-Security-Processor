unit iManageSecProcessor;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Data.DB, DBAccess, Uni, IPPeerClient,
  Data.Bind.Components, Data.Bind.ObjectScope, REST.Client, Vcl.StdCtrls,
  UniProvider, SQLServerUniProvider, MemDS;

type
  TfSecurityProcessor = class(TForm)
    iManageConn: TUniConnection;
    RESTClient1: TRESTClient;
    rRequestLogin: TRESTRequest;
    rResponseLogin: TRESTResponse;
    Button1: TButton;
    iManageSQLServer: TSQLServerUniProvider;
    qSecurityJobs: TUniQuery;
    qSecurityJobDBs: TUniQuery;
    rRequestPost: TRESTRequest;
    rResponsePost: TRESTResponse;
    rResponseGet: TRESTResponse;
    rRequestGet: TRESTRequest;
    rRequestTest: TRESTRequest;
    rResponseTest: TRESTResponse;
    qGroupMembers: TUniQuery;
    rRequestPut: TRESTRequest;
    rResponsePut: TRESTResponse;
    qUpdateQueue: TUniQuery;
    Button2: TButton;
    Button3: TButton;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Button3Click(Sender: TObject);

  private
    { Private declarations }
    CurrCustomerID : string;
    procedure ProcessSecurity();
    Function ProcessExistingGroups(fDB : string) : boolean;
    Function ProcessNewGroups(fDB : string) : boolean;
    Function GetWSGroup(fDBID : string; fGroupID : string) : boolean;
    Function RemoveWSGroup(fDBID : string; fGroupID : string; fIWSID : string) : boolean;
    Function CreateWSGroup(fDBID : string; fGroupID : string) : boolean;
    Function AddWSGroup(fDBID : string; fGroupID : string; fIWSID : string) : boolean;
    Function UpdateWSGroup(fDBID : string; fWSID : string; fIWSID : string) : boolean;
    Function GetWorkspaceID(fDBID : string; fWSID : string) : string;
    Function EnableWSGroup(fDBID : string; fGroupID : string) : boolean;
    procedure UpdateSecurityQueue(pDBID : string; pWSID : string; pUserID : string; pProcessCode : string; pYorN : string);
    procedure FixWS();

  public
    { Public declarations }
  end;

var
  fSecurityProcessor: TfSecurityProcessor;

const
  v2APIBase = 'work/api/v2/customers/';

implementation
uses
  system.json, REST.Types, system.strutils, REST.Utils, REST.HTTPClient;

{$R *.dfm}

procedure TfSecurityProcessor.Button1Click(Sender: TObject);
begin
  ProcessSecurity;
end;

procedure TfSecurityProcessor.Button2Click(Sender: TObject);
begin
  FixWS;
end;

procedure TfSecurityProcessor.Button3Click(Sender: TObject);
begin
  EnableWSGroup('EU_GDG_OPEN', 'ePMS-001.04074-1');
end;

procedure TfSecurityProcessor.ProcessSecurity();
var
  LogonJSONObject : TJSONObject;
Begin
  rRequestLogin.Execute;
  if rResponseLogin.StatusCode = 200 then
  begin
    CurrCustomerID := '';
    LogonJSONObject := rResponseLogin.JSONValue as TJSONObject;
    CurrCustomerID := LogonJSONObject.GetValue('customer_id').Value;
    qSecurityJobDBs.Close;
    qSecurityJobDBs.Open;
    while not qSecurityJobDBs.Eof do
    begin
      ProcessNewGroups(qSecurityJobDBs.FieldByName('DBID').AsString);
      ProcessExistingGroups(qSecurityJobDBs.FieldByName('DBID').AsString);
      qSecurityJobDBs.Next;
    end;

  end;
End;

Function TfSecurityProcessor.ProcessExistingGroups(fDB : string) : boolean;
var
  CurrWorkspaceID : string;
Begin
  try
    Result := False;
    With qSecurityJobs Do
    begin
      Close;
      SQL.Clear;

      //Change query to group by PRJ_ID, wsq.ProcessCode, and wsq.DEFAULT_SECURITY_GROUP
      SQL.Text := 'select distinct wsq.wsid, wsq.ProcessCode, wsq.DEFAULT_SECURITY_GROUP, p.PRJ_ID ' +
                  'from ' + fDB + '.mhgroup.groups g ' +
                  'inner join wsc.dbo.EL_WS_Security_Queue wsq on g.GROUPID = ''ePMS-'' + wsq.wsid collate database_default ' +
                  'inner join ' + fDB + '.mhgroup.projects p on p.CUSTOM1 = wsq.wsid collate database_default ' +
                  'where wsq.IsProcessed = ''N'' and wsq.Ignore = ''N'' ' +
                  'order by wsq.wsid';
      Open;
      while not EOF do
      begin
        CurrWorkspaceID := '';
        CurrWorkspaceID := fDB + '!' + FieldByName('PRJ_ID').AsString;
        if FieldByName('ProcessCode').AsString = 'REMOVE_WS' then
        begin
          //Remove Restricted group and add default entity security group
          If RemoveWSGroup(fDB, 'ePMS-' + FieldByName('WSID').AsString, CurrWorkspaceID) and
            AddWSGroup(fDB, FieldByName('DEFAULT_SECURITY_GROUP').AsString, CurrWorkspaceID) Then
            UpdateSecurityQueue(fDB, FieldByName('WSID').AsString, quotedstr('XNULL'), 'REMOVE_WS', 'Y')
          Else UpdateSecurityQueue(fDB, FieldByName('WSID').AsString, quotedstr('XNULL'), 'REMOVE_WS', 'N');
        end
        else if FieldByName('ProcessCode').AsString = 'ADD_WS' then
          //Add existing group to workspace
          if RemoveWSGroup(fDB, FieldByName('DEFAULT_SECURITY_GROUP').AsString, CurrWorkspaceID) and
            AddWSGroup(fDB, 'ePMS-' + FieldByName('WSID').AsString, CurrWorkspaceID) Then
            UpdateSecurityQueue(fDB, FieldByName('WSID').AsString, quotedstr('XNULL'), 'ADD_WS', 'Y')
          Else UpdateSecurityQueue(fDB, FieldByName('WSID').AsString, quotedstr('XNULL'), 'ADD_WS', 'N')
        else if (FieldByName('ProcessCode').AsString = 'ADD_U') or
                (FieldByName('ProcessCode').AsString = 'REMOVE_U') then
        begin
          //Add user(s) to / remove user(s) from existing group
          UpdateWSGroup(fDB, FieldByName('WSID').AsString, CurrWorkspaceID);
        end;

        Next;
      end;

    end;

  except on E: Exception do
  end;
End;

Function TfSecurityProcessor.ProcessNewGroups(fDB : string) : boolean;
var
  CurrWorkspaceID : string;
Begin
  try
    Result := False;
    With qSecurityJobs Do
    begin
      Close;
      SQL.Clear;
      SQL.Text := 'select distinct wsq.wsid, wsq.ProcessCode, wsq.DEFAULT_SECURITY_GROUP, p.PRJ_ID ' +
                  'from el_ws_security_queue wsq ' +
                  'left join ' + fDB + '.mhgroup.groups g on g.GROUPID = ''ePMS-'' + wsq.wsid collate database_default ' +
                  'inner join ' + fDB + '.mhgroup.projects p on p.CUSTOM1 = wsq.wsid collate database_default ' +
                  'where g.GROUPID is null ' +
                  'and wsq.ProcessCode = ''ADD_WS'' ' +
                  'and wsq.IsProcessed = ''N'' and wsq.Ignore = ''N'' ' +
                  'order by wsq.wsid';

      Open;
      while not EOF do
      begin
        CurrWorkspaceID := '';
        CurrWorkspaceID := fDB + '!' + FieldByName('PRJ_ID').AsString;
        //Remove default entity security group and add Restricted group
        If RemoveWSGroup(fDB, FieldByName('DEFAULT_SECURITY_GROUP').AsString, CurrWorkspaceID) and
        AddWSGroup(fDB, 'ePMS-' + FieldByName('WSID').AsString, CurrWorkspaceID) Then
          begin
            UpdateWSGroup(fDB, FieldByName('WSID').AsString, CurrWorkspaceID);
            UpdateSecurityQueue(fDB, FieldByName('WSID').AsString, quotedstr('XNULL'), 'ADD_WS', 'Y')
          end

        else UpdateSecurityQueue(fDB, FieldByName('WSID').AsString, quotedstr('XNULL'), 'ADD_WS', 'N');
        Next;
      end;
    end;

  except on E: Exception do
  end;

End;

Function TfSecurityProcessor.RemoveWSGroup(fDBID : string; fGroupID : string; fIWSID : string) : boolean;
var
  rBody : string;
Begin
  try
    Result := False;
    rRequestPost.Resource := v2APIBase + CurrCustomerID + '/libraries/' + fDBID + '/workspaces/' + fIWSID + '/security';
    rBody := '{"default_security": "private", "remove" :[{"id"  : "' + fGroupID + '", "type" : "group"}]}';

    rBody := StringReplace(rBody,#$A,'',[rfReplaceAll]);
    rBody := StringReplace(rBody,#$D,'',[rfReplaceAll]);

    rRequestPost.Params.AddItem('body', rBody, TRESTRequestParameterKind.pkREQUESTBODY);
    rRequestPost.Params.ParameterByName('body').ContentType := ctAPPLICATION_JSON;
    rRequestPost.Execute;

    if rResponsePost.StatusCode = 200 then
    begin
      Result := True;
    end
    else
      Result := False;
    
  except on E: Exception do
    Result := False;
  end;
End;

Function TfSecurityProcessor.GetWSGroup(fDBID : string; fGroupID : string) : boolean;
var
  Group_JSONArray : TJsonArray;
  rGroupID : string;
Begin
  try
    Result := False;
    rGroupID := '';
    rRequestGet.Resource := v2APIBase + CurrCustomerID + '/libraries/' + fDBID + '/groups';
    rRequestGet.AddParameter('alias', fGroupID, TRESTRequestParameterKind.pkGETorPOST);
    rRequestGet.Execute;
    if rResponseGet.StatusCode = 200 then
    begin
      if rResponseGet.ContentLength > 16 then
      begin
        Group_JSONArray := rResponseGet.JSONValue as TJSONArray;
        rGroupID := ((Group_JSONArray as TJSONArray).Items[0] as TJSonObject).Get('group_id').JSONValue.Value;
      end
      else rGroupID := '';
      if rGroupID <> '' then
        Result := True
      else
        Result := False;
    end
    else
      Result := False;

  except on E: Exception do
    Result := False;
  end;

End;

Function TfSecurityProcessor.CreateWSGroup(fDBID : string; fGroupID : string) : boolean;
var
  rBody : string;
Begin
  try
    Result := False;
    
    rRequestPost.Resource := v2APIBase + CurrCustomerID + '/libraries/' + fDBID + '/groups';
    rBody :=  '{"enabled": true, ' +
              '"full_name": "ePMS Ethical Wall Group", ' +
              '"group_nos": 2, ' +
              '"id": "' + fGroupID + '", ' +
              '"is_external": false }';

    
    rBody := StringReplace(rBody,#$A,'',[rfReplaceAll]);
    rBody := StringReplace(rBody,#$D,'',[rfReplaceAll]);

    rRequestPost.Params.AddItem('body', rBody, TRESTRequestParameterKind.pkREQUESTBODY);
    rRequestPost.Params.ParameterByName('body').ContentType := ctAPPLICATION_JSON;
    rRequestPost.Execute;

    if rResponsePost.StatusCode = 201 then
    begin
      Result := True;
    end
    else
      Result := False;
    
  except on E: Exception do
    Result := False;
  end;
  
End;

Function TfSecurityProcessor.AddWSGroup(fDBID : string; fGroupID : string; fIWSID : string) : boolean;
var
  rBody, rGroupType : string;
Begin
  try
    Result := False;

    //Check first, create if new, and add to workspace
    if not GetWSGroup(fDBID, fGroupID) then
      if not CreateWSGroup(fDBID, fGroupID) then
        exit;

    rRequestPost.Resource := v2APIBase + CurrCustomerID + '/libraries/' + fDBID + '/workspaces/' + fIWSID + '/security';
    rBody := '{"default_security": "private", "include" :[{"id"  : "' + fGroupID + '", "access_level" : "full_access", "type" : "group"}]}';

    rBody := StringReplace(rBody,#$A,'',[rfReplaceAll]);
    rBody := StringReplace(rBody,#$D,'',[rfReplaceAll]);

    rRequestPost.Params.AddItem('body', rBody, TRESTRequestParameterKind.pkREQUESTBODY);
    rRequestPost.Params.ParameterByName('body').ContentType := ctAPPLICATION_JSON;
    rRequestPost.Execute;

    if rResponsePost.StatusCode = 200 then
    begin
      Result := True;
      //ENSURE Ethical Wall GROUP IS ENABLED.
      if LeftStr(fGroupID, 5) = 'ePMS-' then
        EnableWSGroup(fDBID, fGroupID);
    end
    else
      Result := False;
      
  except on E: Exception do
    Result := False;
  end;
End;

Function TfSecurityProcessor.UpdateWSGroup(fDBID : string; fWSID : string; fIWSID : string) : boolean;
var
  rGroupID, rBodyHead, rBody, rFullBody, UserList : string;
Begin
  Result := False;
  rGroupID := 'ePMS-' + fWSID;
  try
    rBody := '';
    rFullBody := '';
    UserList := '';
    With qGroupMembers Do
    begin
      Close;
      SQL.Text := 'select distinct UserID ' +
                  'from wsc.dbo.el_ws_security_queue ' +
                  'where wsid = ' + QuotedStr(fWSID) +
                  'and ProcessCode = ''ADD_U'' ' +
                  'and IsProcessed = ''N'' and Ignore = ''N'' ';
      Open;
      First;
      if RecordCount > 0 then

      rBodyHead :=  '{"database": "' + fDBID + '",' +
                '"data_type": "users", ' +
                '"data": [';

      rBody := '"' + FieldByName('UserID').AsString + '"';
      UserList := Quotedstr(FieldByName('UserID').AsString);
      Next;
      while not EOF do
      begin
        rBody := rBody + ', "' + FieldByName('UserID').AsString + '"';
        UserList := UserList + ', ' + QuotedStr(FieldByName('UserID').AsString);
        Next;
      end;

      rBody := rBody + '], "action": "add"}';
      Close;
    end;
    rFullBody := rBodyHead + rBody;
    rFullBody := StringReplace(rFullBody,#$A,'',[rfReplaceAll]);
    rFullBody := StringReplace(rFullBody,#$D,'',[rfReplaceAll]);

    rRequestPut.Resource := v2APIBase + CurrCustomerID + '/libraries/' + fDBID + '/groups/{rGroupID}/members';
    rRequestPut.Params.AddItem('rGroupID', rGroupID, TRESTRequestParameterKind.pkURLSEGMENT);
    rRequestPut.Params.AddItem('body', rFullBody, TRESTRequestParameterKind.pkREQUESTBODY);
    rRequestPut.Params.ParameterByName('body').ContentType := ctAPPLICATION_JSON;
    rRequestPut.Execute;

    if rResponsePut.StatusCode = 200 then
    begin
      //Update el_ws_security_queue to IsProcessed = 'Y'
      UpdateSecurityQueue(fDBID, fWSID, UserList, 'ADD_U', 'Y');
      Result := True;
    end
    else
    begin
      Result := False;
      UpdateSecurityQueue(fDBID, fWSID, UserList, 'ADD_U', 'N');
    end;

  except on E: Exception do
    begin
      Result := False;
      UpdateSecurityQueue(fDBID, fWSID, UserList, 'ADD_U', 'N');
    end;
  end;

  try
    rBody := '';
    rFullBody := '';
    UserList := '';
    With qGroupMembers Do
    begin
      Close;
      SQL.Text := 'select distinct UserID ' +
                  'from wsc.dbo.el_ws_security_queue ' +
                  'where wsid = ' + QuotedStr(fWSID) +
                  'and ProcessCode = ''REMOVE_U'' ' +
                  'and IsProcessed = ''N'' and Ignore = ''N'' ' +
                  'and UserID is not null';
      Open;
      First;
      if not EOF then
      begin
        rBodyHead :=  '{"database": "' + fDBID + '",' +
                  '"data_type": "users", ' +
                  '"data": [';

        rBody := '"' + FieldByName('UserID').AsString + '"';
        UserList := QuotedStr(FieldByName('UserID').AsString);
        Next;

        while not EOF do
        begin
          rBody := rBody + ', "' + FieldByName('UserID').AsString + '"';
          UserList := UserList + ', ' + QuotedStr(FieldByName('UserID').AsString);
          Next;
        end;

        rBody := rBody + '], "action": "delete"}';
        Close;

        rFullBody := rBodyHead + rBody;
        rFullBody := StringReplace(rFullBody,#$A,'',[rfReplaceAll]);
        rFullBody := StringReplace(rFullBody,#$D,'',[rfReplaceAll]);

        rRequestPut.Resource := v2APIBase + CurrCustomerID + '/libraries/' + fDBID + '/groups/{rGroupID}/members';
        rRequestPut.Params.AddItem('rGroupID', rGroupID, TRESTRequestParameterKind.pkURLSEGMENT);
        rRequestPost.Params.AddItem('body', rFullBody, TRESTRequestParameterKind.pkREQUESTBODY);
        rRequestPut.Params.ParameterByName('body').ContentType := ctAPPLICATION_JSON;
        rRequestPut.Execute;

        if rResponsePost.StatusCode = 200 then
        begin
          //Update el_ws_security_queue to IsProcessed = 'Y'
          UpdateSecurityQueue(fDBID, fWSID, UserList, 'REMOVE_U', 'Y');
          Result := True;
        end
        else
        begin
          Result := False;
          UpdateSecurityQueue(fDBID, fWSID, UserList, 'REMOVE_U', 'N');
        end;
      end;
    end;
  except on E: Exception do
    begin
      Result := False;
      UpdateSecurityQueue(fDBID, fWSID, UserList, 'REMOVE_U', 'N');
    end;
  end;

  //ENSURE GROUP IS ENABLED.
  EnableWSGroup(fDBID, rGroupID);
End;

Function TfSecurityProcessor.GetWorkspaceID(fDBID : string; fWSID : string) : string;
var
  rbody, WS_ID : string;
  WS_ID_JSONArray : TJsonArray;
Begin
  try
    Result := '';
    rRequestPost.Resource :=  v2APIBase + CurrCustomerID + '/libraries/' + fDBID + '/workspaces/search';
    rbody := '{"filters": {"custom2": "' + fWSID + '"}}';
    rRequestPost.Params.AddItem('body', rBody, TRESTRequestParameterKind.pkREQUESTBODY);
    rRequestPost.Params.ParameterByName('body').ContentType := ctAPPLICATION_JSON;
    rRequestPost.Execute;

    if rResponsePost.StatusCode = 200 then
    begin
      WS_ID_JSONArray := rResponsePost.JSONValue as TJSONArray;
      WS_ID := ((WS_ID_JSONArray as TJSONArray).Items[0] as TJSonObject).Get('workspace_id').JSONValue.Value;
      Result := WS_ID;
    end
    else
      Result := '';

  except on E: Exception do
    Result := '';
  end;

End;

Function TfSecurityProcessor.EnableWSGroup(fDBID : string; fGroupID : string) : boolean;
var
  rBody : string;
Begin
  //Cannot get this to work - 405 error - Method not allowed
  exit;
  try
    Result := False;
    rRequestPut.Resource := v2APIBase + CurrCustomerID + '/libraries/{fDBID}/groups/{fGroupID}';
    rBody :=  '{"enabled": true, ' +
                '"full_name": "ePMS Ethical Wall Group", ' +
                '"group_nos": 2, ' +
                '"id": "' + fGroupID + '", ' +
                '"groupid": "' + fGroupID + '", ' +
                '"group_id": "' + fGroupID + '", ' +
                '"is_external": false }';

    rBody := StringReplace(rBody,#$A,'',[rfReplaceAll]);
    rBody := StringReplace(rBody,#$D,'',[rfReplaceAll]);

    rRequestPut.Params.AddItem('fDBID', fDBID, TRESTRequestParameterKind.pkURLSEGMENT);
    rRequestPut.Params.AddItem('fGroupID', fGroupID, TRESTRequestParameterKind.pkURLSEGMENT);
    rRequestPut.Params.AddItem('body', rBody, TRESTRequestParameterKind.pkREQUESTBODY);
    rRequestPut.Params.ParameterByName('body').ContentType := ctAPPLICATION_JSON;
    rRequestPut.Execute;

    if rResponsePut.StatusCode = 200 then
    begin
      Result := True;
    end
    else
      Result := False;

  except on E: Exception do
    Result := False;
  end;
End;

procedure TfSecurityProcessor.UpdateSecurityQueue(pDBID : string; pWSID : string; pUserID : string; pProcessCode : string; pYorN : string);
Begin
  try
    With qUpdateQueue Do
    begin
      Close;
      SQL.Clear;
      SQL.Text := 'Update wsc.dbo.el_ws_security_queue ' +
                  'Set IsProcessed = ' + quotedstr(pYorN) +
                  ', DateProcessed = GetDate() ' +
                  'where DBID = ' + quotedstr(pDBID) +
                  ' and WSID = ' + quotedstr(pWSID) +
                  ' and isnull(UserID, ''XNULL'') in (' +
                  pUserID + ') ' +
                  ' and ProcessCode = ' + quotedstr(pProcessCode) +
                  ' and IsProcessed = ''N'' ' +
                  ' and Ignore = ''N'' ';
      Execute;
    end;

  except on E: Exception do
  end;
End;


procedure TfSecurityProcessor.FixWS();
var
  LogonJSONObject : TJSONObject;
  CurrWorkspaceID, fDB : string;
Begin
  rRequestLogin.Execute;
  if rResponseLogin.StatusCode = 200 then
  begin
    CurrCustomerID := '';
    LogonJSONObject := rResponseLogin.JSONValue as TJSONObject;
    CurrCustomerID := LogonJSONObject.GetValue('customer_id').Value;
    try
      fDB := 'EU_GDG_OPEN';
      With qSecurityJobs Do
      begin
        Close;
        SQL.Clear;
        SQL.Text := 'select distinct wsq.wsid, wsq.ProcessCode, wsq.DEFAULT_SECURITY_GROUP, p.PRJ_ID ' +
                    'from ' + fDB + '.mhgroup.groups g ' +
                    'inner join wsc.dbo.EL_WS_Security_Queue wsq on g.GROUPID = ''ePMS-'' + wsq.wsid collate database_default ' +
                    'inner join ' + fDB + '.mhgroup.projects p on p.CUSTOM1 = wsq.wsid collate database_default ' +
                    'where wsq.IsProcessed = ''Y'' and wsq.Ignore = ''N'' and processcode = ''ADD_WS'' ' +
                    'order by wsq.wsid';
        Open;
        while not EOF do
        begin
          CurrWorkspaceID := '';
          CurrWorkspaceID := fDB + '!' + FieldByName('PRJ_ID').AsString;
          //Add user(s) to / remove user(s) from existing group
          UpdateWSGroup(fDB, FieldByName('WSID').AsString, CurrWorkspaceID);
          Next;
        end;

      end;

      except on E: Exception do
      end;

    end;

end;

procedure TfSecurityProcessor.FormCreate(Sender: TObject);
begin
  ProcessSecurity;
end;

end.
