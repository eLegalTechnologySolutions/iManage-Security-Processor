object fSecurityProcessor: TfSecurityProcessor
  Left = 0
  Top = 0
  Caption = 'Security Processor'
  ClientHeight = 359
  ClientWidth = 649
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object Button1: TButton
    Left = 376
    Top = 104
    Width = 75
    Height = 25
    Caption = 'Run Security'
    TabOrder = 0
    OnClick = Button1Click
  end
  object iManageConn: TUniConnection
    ProviderName = 'SQL Server'
    Port = 1433
    Database = 'WSC'
    Username = 'sa'
    Server = 'EUIMANSQL01.INCEGD.COM'
    Connected = True
    LoginPrompt = False
    Left = 128
    Top = 64
    EncryptedPassword = 
      '8CFF8BFF90FF8FFF83FFB2FFBEFFA6FFB0FFADFF83FF96FF91FF9BFF96FF9EFF' +
      '83FFBBFFB6FFADFFBAFFBCFFABFF'
  end
  object RESTClient1: TRESTClient
    Accept = '*/*'
    AcceptCharset = 'UTF-8, *;q=0.8'
    BaseURL = 'https://imancontrol.incegd.com/'
    ContentType = 'application/json'
    Params = <>
    HandleRedirects = True
    RaiseExceptionOn500 = False
    Left = 40
    Top = 48
  end
  object rRequestLogin: TRESTRequest
    Accept = '*/*'
    Client = RESTClient1
    Method = rmPUT
    Params = <
      item
        Kind = pkREQUESTBODY
        name = 'body'
        Value = 
          '{'#10'"user_id" : "epmsdev",'#10'"password" : "newyork",'#10'"persona" : "us' +
          'er",'#10'"application_name" : "ePMS"'#10'}'
        ContentType = ctAPPLICATION_JSON
      end>
    Resource = 'api/v1/session/login'
    Response = rResponseLogin
    SynchronizedEvents = False
    Left = 40
    Top = 144
  end
  object rResponseLogin: TRESTResponse
    ContentType = 'application/json'
    Left = 128
    Top = 144
  end
  object iManageSQLServer: TSQLServerUniProvider
    Left = 256
    Top = 8
  end
  object qGetJobs: TUniQuery
    Connection = iManageConn
    SQL.Strings = (
      'select * '
      'from wsc.dbo.el_ws_security_queue'
      'where IsProcessed = '#39'N'#39' and Ignore = '#39'N'#39)
    Left = 56
    Top = 216
  end
end
