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
    qGetJobs: TUniQuery;
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
    CurrCustomerID : string;

    procedure ProcessSecurity();
  public
    { Public declarations }
  end;

var
  fSecurityProcessor: TfSecurityProcessor;

implementation
uses
  system.json;

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
  end;
End;

end.
