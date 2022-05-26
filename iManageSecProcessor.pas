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
    procedure Button1Click(Sender: TObject);

  private
    { Private declarations }
    CurrCustomerID : string;
    procedure ProcessSecurity();
    Function ProcessExistingGroups(fDB : string) : boolean;
    Function ProcessNewGroups(fDB : string) : boolean;
    Function GetWSGroup(fDBID : string; fGroupID : string) : boolean;
    Function RemoveWSGroup(fDBID : string; fGroupID : string; fIWSID : string) : boolean;
    Function CreateWSGroup(fDBID : string; fGroupID : string; fIWSID : string) : boolean;
    Function AddWSGroup(fDBID : string; fGroupID : string; fIWSID : string) : boolean;
    Function UpdateWSGroup(fDBID : string; fWSID : string; fIWSID : string) : boolean;
    Function GetWorkspaceID(fDBID : string; fWSID : string) : string;

  public
    { Public declarations }
  end;

var
  fSecurityProcessor: TfSecurityProcessor;

const
  v2APIBase = 'work/api/v2/customers/';

implementation
uses
  system.json, REST.Types;

{$R *.dfm}

procedure TfSecurityProcessor.Button1Click(Sender: TObject);
begin
  ProcessSecurity;
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
    ShowMessage(CurrCustomerID);

    qSecurityJobDBs.Close;
    qSecurityJobDBs.Open;
    while not qSecurityJobDBs.eof do
    begin
      ProcessExistingGroups(qSecurityJobDBs.FieldByName('DBID').AsString);

      qSecurityJobDBs.Next;
    end;

  end;
End;

Function TfSecurityProcessor.ProcessExistingGroups(fDB : string) : boolean;
Begin
  Result := False;
  With qSecurityJobs Do
  begin
    Close;
    SQL.Clear;
    SQL.Text := 'select * ' +
                'from ' + fDB + '.mhgroup.groups g ' +
                'inner join wsc.dbo.EL_WS_Security_Queue wsq on g.GROUPID = ''ePMS-'' + wsq.wsid collate database_default ' +
                'inner join ' + fDB + '.mhgroup.projects p on p.CUSTOM1 = wsq.wsid collate database_default ';
    Open;
    while not EOF do
    begin
      if FieldByName('ProcessCode').AsString = 'REMOVE_WS' then
      begin
        //Remove Restricted group and add default entity security group
      end
      else if (FieldByName('ProcessCode').AsString = 'ADD_U') or
              (FieldByName('ProcessCode').AsString = 'REMOVE_U') then
      begin
        //Add user(s) to / remove user(s) from existing group
        //Ensure group is Enabled
            //      end
            //      else if FieldByName('ProcessCode').AsString = 'REMOVE_U'  then
            //      begin
                    //existing group
                    //Ensure group is Enabled
      end;

      Next;
    end;


  end;
End;

Function TfSecurityProcessor.ProcessNewGroups(fDB : string) : boolean;
var
  CurrWorkspaceID : string;
Begin
  Result := False;
  With qSecurityJobs Do
  begin
    Close;
    SQL.Clear;
    SQL.Text := 'select wsq.*, p.PRJ_ID ' +
                'from el_ws_security_queue wsq ' +
                'left join ' + fDB + '.mhgroup.groups g on g.GROUPID = ''ePMS-'' + wsq.wsid collate database_default ' +
                'inner join ' + fDB + '.mhgroup.projects p on p.CUSTOM1 = wsq.wsid collate database_default ' +
                'where g.GROUPID is null ' +
                'and ProcessCode = ''ADD_WS'' ';

    Open;
    while not EOF do
    begin
      CurrWorkspaceID := '';
      CurrWorkspaceID := fDB + '!' + FieldByName('PRJ_ID').AsString;
      //Remove default entity security group and add Restricted group
      RemoveWSGroup(fDB, FieldByName('DEFAULT_SECURITY_GROUP').AsString, CurrWorkspaceID);
      AddWSGroup(fDB, 'ePMS-' + FieldByName('WSID').AsString, CurrWorkspaceID);
      //Add user(s) to new group
      Next;
    end;

{    Close;
    SQL.Clear;
    SQL.Text := 'select * ' +
                'from el_ws_security_queue wsq ' +
                'left join ' + fDB + '.mhgroup.groups g on g.GROUPID = ''ePMS-'' + wsq.wsid ' +
                'inner join ' + fDB + '.mhgroup.projects p on p.CUSTOM1 = wsq.wsid ' +
                'where g.GROUPID is null ' +
                'and ProcessCode = ''ADD_U'' ';

    Open;
    while not EOF do
    begin
      //Add user(s) to new group

    end;
 }
  end;

End;

Function TfSecurityProcessor.RemoveWSGroup(fDBID : string; fGroupID : string; fIWSID : string) : boolean;
var
  rBody : string;
Begin
  try
    Result := False;
    rRequestPost.Resource := v2APIBase + CurrCustomerID + '/libraries/' + fDBID + '/workspaces/' + fIWSID + '/security';
    rBody := '{"remove" :[{"id"  : "' + fGroupID + '", "type" : "group"}]}';

    rBody := StringReplace(rBody,#$A,'',[rfReplaceAll]);
    rBody := StringReplace(rBody,#$D,'',[rfReplaceAll]);

    rRequestPost.Params.AddItem('body', rBody, TRESTRequestPArameterKind.pkREQUESTBODY);
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
Begin
  try
    Result := False;
    rRequestGet.Resource := v2APIBase + CurrCustomerID + '/libraries/' + fDBID + '/groups?alias=' + fGroupID;
    rRequestGet.Execute;
    if rResponseGet.StatusCode = 200 then
      
    begin
      Result := True;
    end
    else
      Result := False;
      
  except on E: Exception do
    Result := False;
  end;

End;

Function TfSecurityProcessor.CreateWSGroup(fDBID : string; fGroupID : string; fIWSID : string) : boolean;
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

    rRequestPost.Params.AddItem('body', rBody, TRESTRequestPArameterKind.pkREQUESTBODY);
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
  rBody : string;
Begin
  try
    Result := False;

    //Check first, create if new, and add to workspace
    if not GetWSGroup(fDBID, fGroupID) then
      if not CreateWSGroup(fDBID, fGroupID) then
        exit;
        
    rRequestPost.Resource := v2APIBase + CurrCustomerID + '/libraries/' + fDBID + '/workspaces/' + fIWSID + '/security';
    rBody := '{"include" :[{"id"  : "' + fGroupID + '", "access_level" : "full_access", "type" : "group"}]}';

    rBody := StringReplace(rBody,#$A,'',[rfReplaceAll]);
    rBody := StringReplace(rBody,#$D,'',[rfReplaceAll]);

    rRequestPost.Params.AddItem('body', rBody, TRESTRequestPArameterKind.pkREQUESTBODY);
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

Function TfSecurityProcessor.UpdateWSGroup(fDBID : string; fWSID : string; fIWSID : string) : boolean;
var
  rGroupID, rBodyHead, rBody : string;
Begin
  Result := False;
  rGroupID := 'ePMS-' + fWSID;
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
              '"data": [' +

    rBody := '"' + FieldByName('UserID').AsString + '"';
    Next;
    while not EOF do
    begin
      rBody := rBody + ', "' + FieldByName('UserID').AsString + '"';
      Next;
    end;

    rBody := rBody + '], "action": "add"}';
    Close;
  end;
  rRequestPut.Resource := v2APIBase + CurrCustomerID + '/libraries/' + fDBID + '/groups/' + rGroupID + '/members';
  rRequestPost.Params.AddItem('body', rBodyHead + rBody, TRESTRequestPArameterKind.pkREQUESTBODY);
  rRequestPut.Params.ParameterByName('body').ContentType := ctAPPLICATION_JSON;
  rRequestPut.Execute;

  if rResponsePost.StatusCode = 200 then
    Result := True
  else
    Result := False;
  //  PUT /customers/{customerId}/libraries/{libraryId}/groups/{groupId}/members
{
  "database": "ACTIVE_UK",
  "data_type": "users",
  "data": [
    "ACASE"
  ],
  "action": "add"
}
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
    rRequestPost.Params.AddItem('body', rBody, TRESTRequestPArameterKind.pkREQUESTBODY);
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


end.
