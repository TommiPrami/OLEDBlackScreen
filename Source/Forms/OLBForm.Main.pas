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
    ActionSettings: TAction;
    ActionStopSavingScreen: TAction;
    ImageListTrayIcon: TImageList;
    MenuItemExit: TMenuItem;
    MenuItemPause: TMenuItem;
    MenuItemPause10min: TMenuItem;
    MenuItemPause30min: TMenuItem;
    MenuItemPause45min: TMenuItem;
    MenuItemPause60min: TMenuItem;
    MenuItemSeparator: TMenuItem;
    MenuItemSettings: TMenuItem;
    PopupMenuTrayIcon: TPopupMenu;
    Timer: TTimer;
    TimerAfterShow: TTimer;
    TrayIcon: TTrayIcon;
    procedure ActionCloseExecute(Sender: TObject);
    procedure ActionSettingsExecute(Sender: TObject);
    procedure ActionStopSavingScreenExecute(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure MenuItemPauseClick(Sender: TObject);
    procedure TimerAfterShowTimer(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure TrayIconDblClick(Sender: TObject);
  strict private
    { Private declarations }
    FMouseDistance: TMouseDistance;
    FSettings: TSettings;
    FSettingsFullFilename: string;
    FPauseUntil: TDateTime;
    procedure StartSavingScreen;
    procedure StopSavingScreen;
    procedure PauseFor(const AMinutesToPause: Integer);
    procedure GetRidOfCheckedPauseMenu;
  protected
    procedure CreateParams(var AParams: TCreateParams); override;
  public
    { Public declarations }
  end;

var
  OLBMainForm: TOLBMainForm;

implementation

uses
  System.DateUtils, System.Math, OBSUnit.Utils, OLBForm.Settings;

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
  Visible := False;
  FPauseUntil := 0.00;

  LoadSettings(FSettingsFullFilename, FSettings);

  FMouseDistance := TMouseDistance.Create(FSettings.MouseMoveResetTime);
  SystemCritical.Start;
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

procedure TOLBMainForm.GetRidOfCheckedPauseMenu;
begin
  for var LIndex := 0 to MenuItemPause.Count - 1 do
    if MenuItemPause.Items[LIndex].Checked then
      MenuItemPause.Items[LIndex].Checked := False;
end;

procedure TOLBMainForm.MenuItemPauseClick(Sender: TObject);
begin
  if Sender is TMenuItem then
  begin
    var LMenuItem := Sender as TMenuItem;

    if LMenuItem.Tag > 0 then
    begin
      PauseFor(LMenuItem.Tag);
      LMenuItem.Checked := True;
    end;
  end;
end;

procedure TOLBMainForm.PauseFor(const AMinutesToPause: Integer);
begin
  FPauseUntil := IncMinute(Now, AMinutesToPause);
end;

procedure TOLBMainForm.StartSavingScreen;
begin
  if not IsZero(FPauseUntil) then
    GetRidOfCheckedPauseMenu;

  FPauseUntil := 0.00;
  BorderStyle := bsNone;

{$IFDEF RELEASE}
  // For now only in release version because iy ids too easy to paint your self into the corner with this
  WindowState := TWindowState.wsMaximized;
{$ELSE}
  WindowState := TWindowState.wsNormal;
{$ENDIF}

  FormStyle := fsStayOnTop;
  Visible := True;
  AlphaBlendValue := 255;
  AlphaBlend := False;
  Application.BringToFront;

  FMouseDistance.Clear;
end;

procedure TOLBMainForm.StopSavingScreen;
begin
  AlphaBlendValue := 0;
  AlphaBlend := True;
  WindowState := TWindowState.wsMinimized;
  Visible := False;
  ShowWindow(Handle, SW_HIDE);
  FPauseUntil := 0.00;

  FMouseDistance.Clear;
end;

procedure TOLBMainForm.TimerAfterShowTimer(Sender: TObject);
begin
  TimerAfterShow.Enabled := False;

  StopSavingScreen;
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

    if IsZero(FPauseUntil) or (Now > FPauseUntil) then
    begin
      GetLastInputInfo(LLastInput);

      if Abs(GetTickCount - LLastInput.dwTime) > (FSettings.UserIdleTime * 1000) then
        StartSavingScreen;
    end;
  end;
end;

procedure TOLBMainForm.TrayIconDblClick(Sender: TObject);
begin
  ActionSettings.Execute;
end;

end.
