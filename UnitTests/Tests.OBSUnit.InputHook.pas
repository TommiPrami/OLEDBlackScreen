unit Tests.OBSUnit.InputHook;

interface

uses
  DUnitX.TestFramework;

type
  // GetKeyKind decides which keys end the black screen (kkKey), only show the cursor (kkModifier),
  // or are left alone entirely (kkPassThrough).
  [TestFixture]
  TKeyKindTests = class
  public
    [Test]
    procedure Modifiers_AreModifiers;
    [Test]
    procedure MediaAndBrowserKeys_PassThrough;
    [Test]
    procedure OrdinaryKeys_AreKeys;
  end;

  // TKeyCaptureState: what the keyboard hook swallows and reports, without installing a real hook.
  [TestFixture]
  TKeyCaptureStateTests = class
  public
    [Test]
    procedure NotCapturing_PassesKeys;
    [Test]
    procedure Capturing_FirstPressIsSwallowedAndReported;
    [Test]
    procedure Capturing_AutoRepeatIsSwallowedButNotReportedAgain;
    [Test]
    procedure Capturing_PassThroughKeysPass;
    [Test]
    procedure AfterEndCapture_HeldKeyStaysSwallowedUntilReleased;
    [Test]
    procedure AfterEndCapture_OtherKeysPass;
    [Test]
    procedure BeginCapture_ForgetsKeysWhoseReleaseWasMissed;
  end;

implementation

uses
  Winapi.Windows, System.SysUtils, OBSUnit.InputHook;

{ TKeyKindTests }

procedure TKeyKindTests.Modifiers_AreModifiers;
begin
  for var LKey in [VK_SHIFT, VK_CONTROL, VK_MENU, VK_LWIN, VK_RWIN, VK_LSHIFT, VK_RSHIFT, VK_LCONTROL, VK_RCONTROL,
    VK_LMENU, VK_RMENU] do
    Assert.IsTrue(GetKeyKind(LKey) = kkModifier, 'Virtual key ' + IntToStr(LKey));
end;

procedure TKeyKindTests.MediaAndBrowserKeys_PassThrough;
begin
  for var LKey in [VK_BROWSER_BACK, VK_VOLUME_MUTE, VK_VOLUME_DOWN, VK_VOLUME_UP, VK_MEDIA_NEXT_TRACK,
    VK_MEDIA_PLAY_PAUSE, VK_LAUNCH_APP2] do
    Assert.IsTrue(GetKeyKind(LKey) = kkPassThrough, 'Virtual key ' + IntToStr(LKey));
end;

procedure TKeyKindTests.OrdinaryKeys_AreKeys;
begin
  for var LKey in [Ord('A'), Ord('Z'), Ord('0'), VK_SPACE, VK_ESCAPE, VK_RETURN, VK_F1, VK_F11, VK_NUMPAD1, VK_LEFT,
    VK_CAPITAL] do
    Assert.IsTrue(GetKeyKind(LKey) = kkKey, 'Virtual key ' + IntToStr(LKey));
end;

{ TKeyCaptureStateTests }

procedure TKeyCaptureStateTests.NotCapturing_PassesKeys;
var
  LState: TKeyCaptureState;
begin
  LState := Default(TKeyCaptureState);

  Assert.IsTrue(LState.KeyEvent(Ord('A'), True) = keaPass, 'down');
  Assert.IsTrue(LState.KeyEvent(Ord('A'), False) = keaPass, 'up');
end;

procedure TKeyCaptureStateTests.Capturing_FirstPressIsSwallowedAndReported;
var
  LState: TKeyCaptureState;
begin
  LState := Default(TKeyCaptureState);
  LState.BeginCapture;

  Assert.IsTrue(LState.KeyEvent(Ord('A'), True) = keaSwallowAndReport, 'letter');
  Assert.IsTrue(LState.KeyEvent(VK_LSHIFT, True) = keaSwallowAndReport, 'modifier');
  Assert.IsTrue(LState.KeyEvent(Ord('A'), False) = keaSwallow, 'release of a swallowed key');
  Assert.IsTrue(LState.HasSwallowedKeys, 'shift still down');
end;

procedure TKeyCaptureStateTests.Capturing_AutoRepeatIsSwallowedButNotReportedAgain;
var
  LState: TKeyCaptureState;
begin
  LState := Default(TKeyCaptureState);
  LState.BeginCapture;

  LState.KeyEvent(Ord('A'), True);

  Assert.IsTrue(LState.KeyEvent(Ord('A'), True) = keaSwallow);
end;

procedure TKeyCaptureStateTests.Capturing_PassThroughKeysPass;
var
  LState: TKeyCaptureState;
begin
  LState := Default(TKeyCaptureState);
  LState.BeginCapture;

  Assert.IsTrue(LState.KeyEvent(VK_VOLUME_UP, True) = keaPass, 'down');
  Assert.IsTrue(LState.KeyEvent(VK_VOLUME_UP, False) = keaPass, 'up');
end;

procedure TKeyCaptureStateTests.AfterEndCapture_HeldKeyStaysSwallowedUntilReleased;
var
  LState: TKeyCaptureState;
begin
  LState := Default(TKeyCaptureState);
  LState.BeginCapture;
  LState.KeyEvent(Ord('A'), True); // This press ended the black screen
  LState.EndCapture;

  Assert.IsTrue(LState.KeyEvent(Ord('A'), True) = keaSwallow, 'auto-repeat');
  Assert.IsTrue(LState.KeyEvent(Ord('A'), False) = keaSwallow, 'release');
  Assert.IsFalse(LState.HasSwallowedKeys, 'nothing left, the hook can go');
  Assert.IsTrue(LState.KeyEvent(Ord('A'), True) = keaPass, 'the next press is the user''s again');
end;

procedure TKeyCaptureStateTests.AfterEndCapture_OtherKeysPass;
var
  LState: TKeyCaptureState;
begin
  LState := Default(TKeyCaptureState);
  LState.BeginCapture;
  LState.KeyEvent(Ord('A'), True);
  LState.EndCapture;

  Assert.IsTrue(LState.KeyEvent(Ord('B'), True) = keaPass, 'down');
  Assert.IsTrue(LState.KeyEvent(Ord('B'), False) = keaPass, 'up');
end;

procedure TKeyCaptureStateTests.BeginCapture_ForgetsKeysWhoseReleaseWasMissed;
var
  LState: TKeyCaptureState;
begin
  LState := Default(TKeyCaptureState);
  LState.BeginCapture;
  LState.KeyEvent(Ord('A'), True); // Release never seen, e.g. the hook was dropped while at a breakpoint
  LState.EndCapture;

  LState.BeginCapture;

  Assert.IsTrue(LState.KeyEvent(Ord('A'), True) = keaSwallowAndReport, 'A must end the black screen again');
end;

end.
