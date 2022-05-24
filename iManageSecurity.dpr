program iManageSecurity;

uses
  Vcl.Forms,
  iManageSecProcessor in 'iManageSecProcessor.pas' {fSecurityProcessor};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfSecurityProcessor, fSecurityProcessor);
  Application.Run;
end.
