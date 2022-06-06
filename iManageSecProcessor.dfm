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
  OnCreate = FormCreate
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
  object Button2: TButton
    Left = 544
    Top = 48
    Width = 75
    Height = 25
    Caption = 'Fix 1st WS'
    TabOrder = 1
    Visible = False
    OnClick = Button2Click
  end
  object Button3: TButton
    Left = 528
    Top = 120
    Width = 99
    Height = 25
    Caption = 'Enable WS Group'
    TabOrder = 2
    OnClick = Button3Click
  end
  object iManageConn: TUniConnection
    ProviderName = 'SQL Server'
    Port = 1433
    Database = 'WSC'
    Username = 'sa'
    Server = 'EUIMANSQL01.INCEGD.COM'
    LoginPrompt = False
    Left = 136
    Top = 8
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
    Top = 72
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
          '{'#10'"user_id" : "epmsdev",'#10'"password" : "newyork",'#10'"persona" : "ad' +
          'min",'#10'"application_name" : "ePMS"'#10'}'
        ContentType = ctAPPLICATION_JSON
      end>
    Resource = 'api/v1/session/login'
    Response = rResponseLogin
    SynchronizedEvents = False
    Left = 112
    Top = 72
  end
  object rResponseLogin: TRESTResponse
    ContentType = 'application/json'
    Left = 192
    Top = 72
  end
  object iManageSQLServer: TSQLServerUniProvider
    Left = 40
    Top = 8
  end
  object qSecurityJobs: TUniQuery
    Connection = iManageConn
    SQL.Strings = (
      'select distinct dbid '
      'from wsc.dbo.el_ws_security_queue'
      'where IsProcessed = '#39'N'#39' and Ignore = '#39'N'#39
      ''
      '/*'
      'select * '
      'from wsc.dbo.el_ws_security_queue'
      'where IsProcessed = '#39'N'#39' and Ignore = '#39'N'#39
      '*/')
    Left = 56
    Top = 216
  end
  object qSecurityJobDBs: TUniQuery
    Connection = iManageConn
    SQL.Strings = (
      'select distinct dbid '
      'from wsc.dbo.el_ws_security_queue'
      'where IsProcessed = '#39'N'#39' and Ignore = '#39'N'#39)
    Left = 136
    Top = 216
  end
  object rRequestPost: TRESTRequest
    Accept = '*/*'
    Client = RESTClient1
    Method = rmPOST
    Params = <>
    Response = rResponsePost
    SynchronizedEvents = False
    Left = 40
    Top = 276
  end
  object rResponsePost: TRESTResponse
    Left = 128
    Top = 272
  end
  object rResponseGet: TRESTResponse
    RootElement = 'data'
    Left = 304
    Top = 272
  end
  object rRequestGet: TRESTRequest
    Accept = '*/*'
    Client = RESTClient1
    Params = <>
    Response = rResponseGet
    SynchronizedEvents = False
    Left = 216
    Top = 276
  end
  object rRequestTest: TRESTRequest
    Accept = '*/*'
    Client = RESTClient1
    Method = rmPOST
    Params = <
      item
        Kind = pkREQUESTBODY
        name = 'body'
        Value = 
          '{"enabled": true, "full_name": "ePMS Ethical Wall Group", "group' +
          '_nos": 2, "id": "ePMS-G.NKG.1-14", "is_external": false }'
        ContentType = ctAPPLICATION_JSON
      end>
    Resource = 'work/api/v2/customers/1/libraries/EU_GDG_OPEN/groups'
    Response = rResponseTest
    SynchronizedEvents = False
    Left = 392
    Top = 196
  end
  object rResponseTest: TRESTResponse
    ContentType = 'application/json'
    Left = 480
    Top = 192
  end
  object qGroupMembers: TUniQuery
    Connection = iManageConn
    SQL.Strings = (
      'select * '
      'from wsc.dbo.el_ws_security_queue'
      'where IsProcessed = '#39'N'#39' and Ignore = '#39'N'#39)
    Left = 240
    Top = 192
  end
  object rRequestPut: TRESTRequest
    Accept = '*/*'
    Client = RESTClient1
    Method = rmPUT
    Params = <>
    Response = rResponsePut
    SynchronizedEvents = False
    Left = 392
    Top = 284
  end
  object rResponsePut: TRESTResponse
    Left = 472
    Top = 280
  end
  object qUpdateQueue: TUniQuery
    Connection = iManageConn
    SQL.Strings = (
      'Update wsc.dbo.el_ws_security_queue'
      'Set IsProcessed = :YorN, '
      '    DateProcessed = GetDate()'
      'where DBID = :DBID'
      'and   WSID = :WSID'
      'and   isnull(UserID, '#39'XNULL'#39') in (:UserID)'
      'and   ProcessCode := :ProcessCode'
      'and IsProcessed = '#39'N'#39
      'and Ignore = '#39'N'#39
      ''
      '')
    Left = 496
    Top = 128
    ParamData = <
      item
        DataType = ftUnknown
        Name = 'YorN'
        Value = nil
      end
      item
        DataType = ftUnknown
        Name = 'DBID'
        Value = nil
      end
      item
        DataType = ftUnknown
        Name = 'WSID'
        Value = nil
      end
      item
        DataType = ftUnknown
        Name = 'UserID'
        Value = nil
      end
      item
        DataType = ftUnknown
        Name = 'ProcessCode'
        Value = nil
      end>
  end
end
