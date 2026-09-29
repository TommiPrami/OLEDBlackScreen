unit OLBForm.Cover;

interface

uses
  Winapi.Messages, Winapi.Windows, System.Classes, System.Types, Vcl.Controls, Vcl.Forms, Vcl.Graphics;

type
  // One borderless black window per monitor. It is shown and hidden with the Win32 API (VCL's Visible would
  // activate it) and never activates, so the application the user was working in keeps the keyboard focus;
  // key presses meant for the black screen are picked up by OBSUnit.InputHook instead.
  TOLBCoverForm = class(TForm)
  strict private
    FCoverRect: TRect;
    procedure WMDpiChanged(var AMessage: TMessage); message WM_DPICHANGED;
    procedure WMMouseActivate(var AMessage: TWMMouseActivate); message WM_MOUSEACTIVATE;
  protected
    procedure CreateParams(var AParams: TCreateParams); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure HideCover;
    procedure ShowCover(const ACoverRect: TRect);
  end;

implementation

{ TOLBCoverForm }

constructor TOLBCoverForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner); // No .dfm

  BorderIcons := [];
  BorderStyle := bsNone;
  Color := clBlack;
  Position := poDesigned;
end;

procedure TOLBCoverForm.CreateParams(var AParams: TCreateParams);
begin
  inherited;

  // Tool window: no taskbar button, not in Alt+Tab. No-activate: clicking it does not take the focus.
  AParams.ExStyle := (AParams.ExStyle or WS_EX_TOOLWINDOW or WS_EX_NOACTIVATE or WS_EX_TOPMOST) and not WS_EX_APPWINDOW;
  AParams.WndParent := Application.Handle;
end;

procedure TOLBCoverForm.HideCover;
begin
  if HandleAllocated then
    ShowWindow(Handle, SW_HIDE);
end;

procedure TOLBCoverForm.ShowCover(const ACoverRect: TRect);
begin
  FCoverRect := ACoverRect;

  SetWindowPos(Handle, HWND_TOPMOST, FCoverRect.Left, FCoverRect.Top, FCoverRect.Width, FCoverRect.Height,
    SWP_NOACTIVATE or SWP_SHOWWINDOW);
end;

procedure TOLBCoverForm.WMDpiChanged(var AMessage: TMessage);
begin
  // Moving onto a monitor with another DPI would make VCL rescale the window to a "suggested" size;
  // a cover must stay exactly the size of its monitor, and it has nothing inside to scale.
  SetWindowPos(Handle, 0, FCoverRect.Left, FCoverRect.Top, FCoverRect.Width, FCoverRect.Height,
    SWP_NOZORDER or SWP_NOACTIVATE);

  AMessage.Result := 0;
end;

procedure TOLBCoverForm.WMMouseActivate(var AMessage: TWMMouseActivate);
begin
  AMessage.Result := MA_NOACTIVATE;
end;

end.
