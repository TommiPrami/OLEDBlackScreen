unit OLBForm.Main;

interface

uses
  Winapi.Messages, Winapi.Windows, System.Actions, System.Classes, System.Diagnostics, System.ImageList,
  System.SysUtils, System.Variants, System.Win.TaskbarCore, Vcl.ActnList, Vcl.BaseImageCollection, Vcl.Controls,
  Vcl.Dialogs, Vcl.ExtCtrls, Vcl.Forms, Vcl.Graphics, Vcl.ImgList, Vcl.StdActns, Vcl.Taskbar, Vcl.VirtualImageList,
  OBSUnit.SystemCritical, OBSUnit.Types, SVGIconImageCollection, SVGIconVirtualImageList, Vcl.ImageCollection, Vcl.Menus;

{ TODO:
        Check these:
         - https://github.com/aehimself/AEFramework/blob/master/AE.Comp.KeepMeAwake.pas
         - https://stackoverflow.com/questions/2212823/how-to-detect-inactive-user
         - https://stackoverflow.com/questions/2177513/receive-screensaver-notification
}

type
  TOLBMainForm = class(TForm)
    ActionClose: TAction;
    ActionList: TActionList;
    ActionStopSavingScreen: TAction;
    Timer: TTimer;
    TrayIcon: TTrayIcon;
    ImageListTrayIcon: TImageList;
    PopupMenuTrayIcon: TPopupMenu;
    Settings1: TMenuItem;
    ActionSettings: TAction;
    N1: TMenuItem;
    Exit1: TMenuItem;
    procedure ActionCloseExecute(Sender: TObject);
    procedure ActionStopSavingScreenExecute(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure TimerTimer(Sender: TObject);
    procedure TrayIconDblClick(Sender: TObject);
    procedure ActionSettingsExecute(Sender: TObject);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
  strict private
    { Private declarations }
    FMouseDistance: TMouseDistance;
    FSettings: TSettings;
    FSettingsFullFilename: string;
    procedure StartSavingScreen;
    procedure StopSavingScreen;
  protected
    procedure CreateParams(var AParams: TCreateParams); override;
  public
    { Public declarations }
  end;

var
  OLBMainForm: TOLBMainForm;

implementation

uses
  OBSUnit.Utils, OLBForm.Settings;

{$R *.dfm}

procedure TOLBMainForm.ActionCloseExecute(Sender: TObject);
begin
  Close;
end;

procedure TOLBMainForm.ActionSettingsExecute(Sender: TObject);
begin
  if not Assigned(OLBSettingsForm) then
    if TOLBSettingsForm.ClassShowModal(Self, FSettings) = mrOk then
      WriteSettings(FSettingsFullFilename, FSettings);
end;

procedure TOLBMainForm.ActionStopSavingScreenExecute(Sender: TObject);
begin
  StopSavingScreen;
end;

procedure TOLBMainForm.CreateParams(var AParams: TCreateParams);
begin
  inherited;

  AParams.ExStyle := AParams.ExStyle and not WS_EX_APPWINDOW;
  AParams.WndParent := Application.Handle;
end;

procedure TOLBMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  SystemCritical.Stop;
end;

procedure TOLBMainForm.FormCreate(Sender: TObject);
begin
  LoadSettings(FSettingsFullFilename, FSettings);

  FMouseDistance := TMouseDistance.Create(FSettings.MouseMoveResetTime);
  SystemCritical.Start;
  StopSavingScreen;
end;

procedure TOLBMainForm.FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if FMouseDistance.AddCoordinate(X, Y) > FSettings.MouseMoveDistance then
    StopSavingScreen;
end;

procedure TOLBMainForm.FormMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbRight then
    PopupMenuTrayIcon.Popup(X, Y)
  else
    StopSavingScreen;
end;

procedure TOLBMainForm.StartSavingScreen;
begin
  BorderStyle := bsNone;

{$IFDEF RELEASE}
  // For now only in release version because iy ids too easy to paint your self into the corner with this
  WindowState := TWindowState.wsMaximized;
{$ELSE}
  WindowState := TWindowState.wsNormal;
{$ENDIF}

  FormStyle := fsStayOnTop;
  Application.BringToFront;

  FMouseDistance.Clear;
end;

procedure TOLBMainForm.StopSavingScreen;
begin
  WindowState := TWindowState.wsMinimized;

  FMouseDistance.Clear;
end;

procedure TOLBMainForm.TimerTimer(Sender: TObject);
begin
  if WindowState = TWindowState.wsMaximized then
  begin
    // Do something for the teams and shit...
  end
  else
  begin
    var LLastInput: TLastInputInfo;
    LLastInput.cbSize := SizeOf(TLastInputInfo);

    GetLastInputInfo(LLastInput);

    if Abs(GetTickCount - LLastInput.dwTime) > (FSettings.UserIdleTime * 1000) then
      StartSavingScreen;
  end;
end;

procedure TOLBMainForm.TrayIconDblClick(Sender: TObject);
begin
  ActionSettings.Execute;
end;

end.
