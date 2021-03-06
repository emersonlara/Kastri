unit CPL.View.Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, System.Sensors,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo, FMX.Layouts,
  FMX.Memo.Types,
  {$IF Defined(ANDROID)}
  Androidapi.JNI.GraphicsContentViewText,
  DW.MultiReceiver.Android,
  {$ENDIF}
  DW.Location;

type
  TMessageReceivedEvent = procedure(Sender: TObject; const Msg: string) of object;

  {$IF Defined(ANDROID)}
  TLocalReceiver = class(TMultiReceiver)
  private
    FOnMessageReceived: TMessageReceivedEvent;
    procedure DoMessageReceived(const AMsg: string);
  protected
    procedure Receive(context: JContext; intent: JIntent); override;
    procedure ConfigureActions; override;
  public
    property OnMessageReceived: TMessageReceivedEvent read FOnMessageReceived write FOnMessageReceived;
  end;
  {$ENDIF}

  TMainView = class(TForm)
    Memo: TMemo;
    ClearButton: TButton;
    ContentLayout: TLayout;
    procedure ClearButtonClick(Sender: TObject);
  private
    FLocation: TLocation;
    {$IF Defined(ANDROID)}
    FReceiver: TLocalReceiver;
    {$ENDIF}
    procedure LocationChangedHandler(Sender: TObject; const ALocation: TLocationCoord2D);
    procedure ReceiverMessageReceivedHandler(Sender: TObject; const AMsg: string);
    procedure RequestLocationPermissions;
    procedure StartLocation;
  protected
    procedure DoShow; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MainView: TMainView;

implementation

{$R *.fmx}

uses
  System.Permissions,
  {$IF Defined(CLOUDLOGGING)}
  Grijjy.CloudLogging,
  {$ENDIF}
  DW.OSLog, DW.OSDevice,
  {$IF Defined(ANDROID)}
  Androidapi.Helpers,
  DW.ServiceCommander.Android,
  {$ENDIF}
  DW.Sensors, DW.Consts.Android, DW.UIHelper,
  CPL.Consts;

type
  TPermissionStatuses = TArray<TPermissionStatus>;

  TPermissionStatusesHelper = record helper for TPermissionStatuses
  public
    function AreAllGranted: Boolean;
  end;

{ TPermissionStatusesHelper }

function TPermissionStatusesHelper.AreAllGranted: Boolean;
var
  LStatus: TPermissionStatus;
begin
  for LStatus in Self do
  begin
    if LStatus <> TPermissionStatus.Granted then
      Exit(False);
  end;
  Result := True;
end;

{$IF Defined(ANDROID)}
{ TLocalReceiver }

procedure TLocalReceiver.ConfigureActions;
begin
  IntentFilter.addAction(StringToJString(cServiceMessageAction));
end;

procedure TLocalReceiver.DoMessageReceived(const AMsg: string);
begin
  if Assigned(FOnMessageReceived) then
    FOnMessageReceived(Self, AMsg);
end;

procedure TLocalReceiver.Receive(context: JContext; intent: JIntent);
begin
  if intent.getAction.equals(StringToJString(cServiceMessageAction)) then
    DoMessageReceived(JStringToString(intent.getStringExtra(StringToJString(cServiceBroadcastParamMessage))));
end;
{$ENDIF}

{ TMainView }

constructor TMainView.Create(AOwner: TComponent);
begin
  inherited;
  {$IF Defined(CLOUDLOGGING)}
  GrijjyLog.SetLogLevel(TgoLogLevel.Info);
  GrijjyLog.Connect(cCloudLoggingHost, cCloudLoggingName);
  {$ENDIF}
  {$IF Defined(ANDROID)}
  FReceiver := TLocalReceiver.Create(True);
  FReceiver.OnMessageReceived := ReceiverMessageReceivedHandler;
  {$ENDIF}
  FLocation := TLocation.Create;
  FLocation.Usage := TLocationUsage.Always;
  FLocation.Activity := TLocationActivity.Navigation;
  // FLocation.UsesService := True;
  FLocation.OnLocationChanged := LocationChangedHandler;
end;

destructor TMainView.Destroy;
begin
  {$IF Defined(ANDROID)}
  FReceiver.Free;
  {$ENDIF}
  FLocation.Free;
  inherited;
end;

procedure TMainView.DoShow;
begin
  inherited;
  {$IF Defined(ANDROID)}
  RequestLocationPermissions;
  {$ELSE}
  StartLocation;
  {$ENDIF}
end;

procedure TMainView.Resize;
begin
  inherited;
  ContentLayout.Padding.Rect := TUIHelper.GetOffsetRect;
end;

procedure TMainView.ReceiverMessageReceivedHandler(Sender: TObject; const AMsg: string);
begin
  Memo.Lines.Add('Message from service: ' + AMsg);
end;

procedure TMainView.RequestLocationPermissions;
var
  LPermissions: TArray<string>;
begin
  LPermissions := [cPermissionAccessCoarseLocation, cPermissionAccessFineLocation];
  if TOSVersion.Check(10) then
    LPermissions := LPermissions + [cPermissionAccessBackgroundLocation];
  PermissionsService.RequestPermissions(LPermissions,
    procedure(const APermissions: TArray<string>; const AGrantResults: TArray<TPermissionStatus>)
    begin
      if AGrantResults.AreAllGranted then
        StartLocation;
    end
  );
end;

procedure TMainView.StartLocation;
begin
  {$IF Defined(ANDROID)}
  TServiceCommander.StartService(cServiceName);
  {$ENDIF}
  FLocation.IsActive := True;
end;

procedure TMainView.LocationChangedHandler(Sender: TObject; const ALocation: TLocationCoord2D);
var
  LTimestamp: string;
begin
  LTimestamp := FormatDateTime('yyyy/mm/dd hh:nn:ss.zzz', Now);
  Memo.Lines.Add(Format('%s - Location: %2.6f, %2.6f', [LTimestamp, ALocation.Latitude, ALocation.Longitude]));
end;

procedure TMainView.ClearButtonClick(Sender: TObject);
begin
  Memo.Lines.Clear;
end;

end.
