unit Unit9;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, SkiaPlatformer;

type
  TForm9 = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
    procedure FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
  private
    { Private-Deklarationen }
    Game: TPlatformerGame;
  public
    { Public-Deklarationen }
  end;

var
  Form9: TForm9;

implementation

{$R *.fmx}

procedure TForm9.FormCreate(Sender: TObject);
begin
  Game := TPlatformerGame.Create(Self);
  Game.Parent := Self;
  Game.Align := TAlignLayout.Client;
end;

procedure TForm9.FormActivate(Sender: TObject);
begin
  if Assigned(Game) then
    Game.SetFocus;
end;

procedure TForm9.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if Assigned(Game) then
  begin
    Game.Free;
    Game := nil;
  end;

  CanClose := True;
end;

procedure TForm9.FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
begin
  if Assigned(Game) then
    Game.KeyDown(Key, KeyChar, Shift);
end;

procedure TForm9.FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
begin
  if Assigned(Game) then
    Game.KeyUp(Key, KeyChar, Shift);
end;

end.

