{*******************************************************************************
  SkiaPlatformer (Endless Scroller Edition)
********************************************************************************
  A high-performance, thread-safe 2D platformer engine built on Skia4Delphi.
  Designed for smooth animations, particle effects, and responsive physics.

  Author:  Lara Miriam Tamy Reschke
  Version: 0.2 Alpha
  License: MIT

  Key Features:
  - Procedural World Generation: Infinite scrolling map with strategic gaps,
    floating platforms, and sky islands.
  - Advanced Visuals: Dynamic Day/Night/Alien cycle, parallax backgrounds,
    and neon glow effects.
  - Game Loop: Score system, "Stargate" level transitions, and deadly traps.
  - Enemies & Interactions: AI enemies that patrol and react to pits, plus
    exploding crates for points.
  - Custom Physics Engine: Tile-based collision, gravity, friction, and inertia.
  - "Alive" Avatar System: Organic sine-wave animations (breathing, swaying).
  - Particle System: Dynamic visual effects (Explosions, Dust, Fireflies).
*******************************************************************************}

{
 ----Latest Changes
   v 0.2:
     - Added Procedural Map Generation (Gaps, Floating Platforms).
     - Added Enemies (Ghosts) with basic AI.
     - Added Gate at end of level with world themes.
     - Added Pause Menu (M/ESC) and Reset functionality.
     - Expanded Controls: WASD + Arrows + Space.
     - Added Parallax Backgrounds (Trees, Clouds) matching time of day.

   v 0.1: Initial Alpha
     - Implemented core AABB collision detection.
     - Added "Alive" procedural animation for avatar.
     - Integrated particle emitter system.
}

unit SkiaPlatformer;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.Math,
  System.Generics.Collections, System.UITypes, System.SyncObjs, FMX.Types,
  FMX.Controls, FMX.Forms, FMX.Skia, System.Skia;

const
  TILE_SIZE = 32;
  GRAVITY = 45.0;
  ACCEL = 80.0;
  MAX_SPEED = 8.0;
  JUMP_FORCE = -17.0;
  FRICTION = 60.0;

type
  TBodyState = (bsGround, bsAir);
  TGameState = (gsPlaying, gsDead, gsWin);

  TTileType = (ttEmpty, ttGround, ttGrass, ttStone);

  TTile = record
    TileType: TTileType;
    Solid: Boolean;
  end;

  TActor = record
    Pos: TPointF;
    Vel: TPointF;
    Width: Single;
    Height: Single;
    State: TBodyState;
  end;

  TParticle = record
    Pos: TPointF;
    Vel: TPointF;
    Life: Single;
    Color: TAlphaColor;
    Size: Single;
  end;

  TDecorType = (dtPlant, dtCrate);

  TDecorItem = record
    Pos: TPointF;
    Kind: TDecorType;
  end;

  TEnemy = record
    Pos: TPointF;
    Vel: TPointF;
    Width: Single;
    Height: Single;
    Phase: Single;
  end;

  TGate = record
    Pos: TPointF;
    Width: Single;
    Height: Single;
    Phase: Single;
  end;

  TPlatformerGame = class(TSkCustomControl)
  private
    { Threading & Timing }
    FThread: TThread;
    FActive: Boolean;
    FLock: TCriticalSection;

    { Input }
    FKeys: set of Byte;

    { Game State }
    FMenuActive: Boolean;
    FScore: Integer;
    FLevel: Integer;
    FGameState: TGameState;
    FDeadTime: Single;
    FWinTime: Single; // Timer for victory animation

    { Game World }
    FPlayer: TActor;
    FTiles: TArray<TTile>;
    FDecor: TList<TDecorItem>;
    FEnemies: TList<TEnemy>;
    FGate: TGate;
    FMapCols: Integer;
    FMapRows: Integer;

    { Camera }
    FCameraX: Single;

    { Visuals }
    FAnimPhase: Single;
    FParticles: TList<TParticle>;

    { Backgrounds }
    FBgClouds: TArray<TPointF>;
    FBgBushes: TArray<TPointF>;

    { Core Game Procedures }
    procedure DoPhysicsUpdate(DeltaSec: Double);
    procedure UpdateCamera;
    procedure SafeInvalidate;
    procedure StartThread;
    procedure StopThread;

    { World Generation }
    procedure GenerateProceduralMap;
    procedure GenerateBackgroundElements;

    { Logic Helpers }
    procedure CheckCrateCollisions;
    procedure CheckEnemyCollisions;
    procedure CheckGateCollision;
    procedure UpdateEnemies(DeltaSec: Double);
    procedure SpawnExplosion(const X, Y: Single; Color: TAlphaColor);

    { Rendering Routines }
    procedure DrawBackgrounds(const ACanvas: ISkCanvas; const ADest: TRectF);
    procedure DrawTileMap(const ACanvas: ISkCanvas);
    procedure DrawDecorations(const ACanvas: ISkCanvas);
    procedure DrawEnemies(const ACanvas: ISkCanvas);
    procedure DrawGate(const ACanvas: ISkCanvas);
    procedure DrawParticles(const ACanvas: ISkCanvas);
    procedure DrawUI(const ACanvas: ISkCanvas);
    procedure UpdateParticles(DeltaTime: Single);
    procedure DrawMenu(const ACanvas: ISkCanvas; const ADest: TRectF);
    procedure DrawAliveAvatar(const ACanvas: ISkCanvas; const Center: TPointF; const Scale: Single; const VelX: Single);
  protected
    procedure Draw(const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Input Handling }
    procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
    procedure KeyUp(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
  end;

implementation

{ =============================================================================
  HELPER: IS SOLID TILE?
============================================================================= }
function IsSolidTile(const Tiles: TArray<TTile>; Cols, Rows: Integer; const AX, AY: Single): Boolean;
var
  Col, Row: Integer;
begin
  Col := Trunc(AX / TILE_SIZE);
  Row := Trunc(AY / TILE_SIZE);

  if (Col < 0) or (Col >= Cols) or (Row < 0) or (Row >= Rows) then
    Exit(True);

  Result := Tiles[Row * Cols + Col].Solid;
end;

{ =============================================================================
  PROCEDURE: GENERATE PROCEDURAL MAP
============================================================================= }
procedure TPlatformerGame.GenerateProceduralMap;
var
  C, R, GapLen, PLen: Integer;
  FloorLevel: Integer;
  LastGapEnd: Integer;
  PlatformY: Integer;
  PlatformX: Integer;
  Item: TDecorItem;
  Enemy: TEnemy;
  IsAboveGap: Boolean;
begin
  // 1. Clear
  for R := 0 to FMapRows - 1 do
    for C := 0 to FMapCols - 1 do
    begin
      FTiles[R * FMapCols + C].TileType := ttEmpty;
      FTiles[R * FMapCols + C].Solid := False;
    end;

  FDecor.Clear;
  FEnemies.Clear;
  FloorLevel := FMapRows - 4;
  LastGapEnd := -10;

  FScore := 0;
  FGameState := gsPlaying;
  FDeadTime := 0;
  FWinTime := 0;

  // 2. Generate Floor
  C := 0;
  while C < FMapCols do
  begin
    if C < 5 then
    begin
      FTiles[FloorLevel * FMapCols + C].TileType := ttGrass;
      FTiles[FloorLevel * FMapCols + C].Solid := True;
      if FloorLevel + 1 < FMapRows then
      begin
        FTiles[(FloorLevel + 1) * FMapCols + C].TileType := ttGround;
        FTiles[(FloorLevel + 1) * FMapCols + C].Solid := True;
      end;
      Inc(C);
      Continue;
    end;

    if (C > LastGapEnd + 6) and (Random(25) = 0) then
    begin
      GapLen := 2 + Random(3);
      for var GL := 0 to GapLen do
      begin
        if (C + GL) < FMapCols then
        begin
          FTiles[FloorLevel * FMapCols + C + GL].TileType := ttEmpty;
          FTiles[FloorLevel * FMapCols + C + GL].Solid := False;
        end;
      end;
      LastGapEnd := C + GapLen;
      C := C + GapLen;
    end
    else
    begin
      FTiles[FloorLevel * FMapCols + C].TileType := ttGrass;
      FTiles[FloorLevel * FMapCols + C].Solid := True;

      if FloorLevel + 1 < FMapRows then
      begin
        FTiles[(FloorLevel + 1) * FMapCols + C].TileType := ttGround;
        FTiles[(FloorLevel + 1) * FMapCols + C].Solid := True;
      end;

      if Random(30) = 0 then
      begin
        Item.Pos := PointF(C * TILE_SIZE, (FloorLevel-1) * TILE_SIZE);
        Item.Kind := dtPlant;
        FDecor.Add(Item);
      end;
      Inc(C);
    end;
  end;

  // 3. Generate Floating Platforms (Lower Layer)
  PlatformX := 10;
  while PlatformX < FMapCols - 10 do
  begin
    PlatformX := PlatformX + 3 + Random(4);
    PlatformY := FloorLevel - (3 + Random(3));

    if PlatformY < 2 then PlatformY := 2;

    PLen := 2 + Random(2);

    IsAboveGap := False;
    for var P := 0 to PLen do
    begin
      if (PlatformX + P < FMapCols) then
      begin
        if not FTiles[FloorLevel * FMapCols + PlatformX + P].Solid then
        begin
          IsAboveGap := True;
          Break;
        end;
      end;
    end;

    if not IsAboveGap then
    begin
      for var P := 0 to PLen do
      begin
        if (PlatformX + P < FMapCols) then
        begin
          FTiles[PlatformY * FMapCols + PlatformX + P].TileType := ttStone;
          FTiles[PlatformY * FMapCols + PlatformX + P].Solid := True;
        end;
      end;

      if Random(3) = 0 then
      begin
        Item.Pos := PointF((PlatformX + 1) * TILE_SIZE, (PlatformY - 1) * TILE_SIZE);
        Item.Kind := dtCrate;
        FDecor.Add(Item);
      end;

      if Random(5) = 0 then
      begin
        Enemy.Pos := PointF((PlatformX + 1) * TILE_SIZE, (PlatformY - 1) * TILE_SIZE - 10);
        Enemy.Vel := PointF(15 + Random(20), 0);
        Enemy.Width := 24;
        Enemy.Height := 24;
        Enemy.Phase := Random(100);
        FEnemies.Add(Enemy);
      end;
    end;
  end;

  // 4. Generate High Platforms (Sky Islands)
  PlatformX := 20;
  while PlatformX < FMapCols - 10 do
  begin
    PlatformX := PlatformX + 8 + Random(10);
    PlatformY := FloorLevel - (8 + Random(5));

    if PlatformY < 1 then PlatformY := 1;

    PLen := 2 + Random(3);

    for var P := 0 to PLen do
    begin
      if (PlatformX + P < FMapCols) then
      begin
        FTiles[PlatformY * FMapCols + PlatformX + P].TileType := ttStone;
        FTiles[PlatformY * FMapCols + PlatformX + P].Solid := True;
      end;
    end;

    if Random(2) = 0 then
    begin
      Item.Pos := PointF((PlatformX + 1) * TILE_SIZE, (PlatformY - 1) * TILE_SIZE);
      Item.Kind := dtCrate;
      FDecor.Add(Item);
    end;
  end;

  // 5. Generate Stargate (End of Level)
  FGate.Pos := PointF((FMapCols - 15) * TILE_SIZE, (FloorLevel - 2) * TILE_SIZE);
  FGate.Width := 64;
  FGate.Height := 96;
  FGate.Phase := 0;

  // 6. Spawn Player
  FPlayer.Pos := PointF(100, FloorLevel * TILE_SIZE - FPlayer.Height - 10);
end;

procedure TPlatformerGame.GenerateBackgroundElements;
var I: Integer;
begin
  SetLength(FBgClouds, 30);
  for I := 0 to High(FBgClouds) do
    FBgClouds[I] := PointF(Random(FMapCols * TILE_SIZE * 2), Random(400) + 50);

  SetLength(FBgBushes, 60);
  for I := 0 to High(FBgBushes) do
    FBgBushes[I] := PointF(Random(FMapCols * TILE_SIZE * 2), (FMapRows - 5) * TILE_SIZE + Random(40));
end;

{ =============================================================================
  LOGIC
============================================================================= }
procedure TPlatformerGame.UpdateCamera;
var
  ScreenWidth, TargetX: Single;
begin
  if FDeadTime > 0 then Exit;

  ScreenWidth := Width;
  TargetX := FPlayer.Pos.X - (ScreenWidth * 0.4);
  FCameraX := FCameraX + (TargetX - FCameraX) * 0.08;

  if FCameraX < 0 then FCameraX := 0;
  if FCameraX > (FMapCols * TILE_SIZE) - ScreenWidth + 200 then
    FCameraX := (FMapCols * TILE_SIZE) - ScreenWidth + 200;
end;

procedure TPlatformerGame.SpawnExplosion(const X, Y: Single; Color: TAlphaColor);
var I: Integer; P: TParticle;
begin
  for I := 0 to 15 do
  begin
    P.Pos := PointF(X, Y);
    P.Vel := PointF((Random - 0.5) * 400, (Random - 0.5) * 400 - 100);
    P.Life := 0.8;
    P.Color := Color;
    P.Size := 4 + Random * 4;
    FParticles.Add(P);
  end;
end;

procedure TPlatformerGame.CheckCrateCollisions;
var I: Integer; Item: TDecorItem; R: TRectF;
begin
  if FGameState <> gsPlaying then Exit;

  R := TRectF.Create(FPlayer.Pos.X, FPlayer.Pos.Y,
                     FPlayer.Pos.X + FPlayer.Width, FPlayer.Pos.Y + FPlayer.Height);

  for I := FDecor.Count - 1 downto 0 do
  begin
    Item := FDecor[I];
    if Item.Kind = dtCrate then
    begin
      if R.IntersectsWith(TRectF.Create(Item.Pos.X+2, Item.Pos.Y+2, Item.Pos.X+30, Item.Pos.Y+30)) then
      begin
        SpawnExplosion(Item.Pos.X + 16, Item.Pos.Y + 16, TAlphaColors.Orange);
        FDecor.Delete(I);
        Inc(FScore);
      end;
    end;
  end;
end;

procedure TPlatformerGame.CheckGateCollision;
var R, R2: TRectF;
begin
  if FGameState <> gsPlaying then Exit;

  R := TRectF.Create(FPlayer.Pos.X, FPlayer.Pos.Y,
                     FPlayer.Pos.X + FPlayer.Width, FPlayer.Pos.Y + FPlayer.Height);

  R2 := TRectF.Create(FGate.Pos.X, FGate.Pos.Y,
                      FGate.Pos.X + FGate.Width, FGate.Pos.Y + FGate.Height);

  if R.IntersectsWith(R2) then
  begin
    FGameState := gsWin;
    FWinTime := 2.0; // 2 seconds of victory vortex
    SpawnExplosion(FGate.Pos.X + FGate.Width/2, FGate.Pos.Y + FGate.Height/2, TAlphaColors.Cyan);
  end;
end;

procedure TPlatformerGame.CheckEnemyCollisions;
var I: Integer; E: TEnemy; R, R2: TRectF;
begin
  if FGameState <> gsPlaying then Exit;

  R := TRectF.Create(FPlayer.Pos.X, FPlayer.Pos.Y,
                     FPlayer.Pos.X + FPlayer.Width, FPlayer.Pos.Y + FPlayer.Height);

  for I := FEnemies.Count - 1 downto 0 do
  begin
    E := FEnemies[I];
    R2 := TRectF.Create(E.Pos.X, E.Pos.Y, E.Pos.X + E.Width, E.Pos.Y + E.Height);

    if R.IntersectsWith(R2) then
    begin
      SpawnExplosion((R.Left + R.Right)/2, (R.Top + R.Bottom)/2, TAlphaColors.Red);
      FEnemies.Delete(I);
      FGameState := gsDead;
      FDeadTime := 1.5;
      FPlayer.Pos.X := -1000;
      FPlayer.Vel.X := 0;
      FPlayer.Vel.Y := 0;
      FScore := 0;
      Exit;
    end;
  end;
end;

procedure TPlatformerGame.UpdateEnemies(DeltaSec: Double);
var I: Integer; E: TEnemy; FloorLevel: Integer;
begin
  FloorLevel := FMapRows - 4;

  for I := FEnemies.Count - 1 downto 0 do
  begin
    E := FEnemies[I];
    E.Pos.X := E.Pos.X + E.Vel.X * DeltaSec;
    E.Phase := E.Phase + DeltaSec * 5;
    E.Pos.Y := E.Pos.Y + 15 * DeltaSec;

    if IsSolidTile(FTiles, FMapCols, FMapRows, E.Pos.X + E.Width/2, E.Pos.Y + E.Height) then
    begin
      E.Pos.Y := Trunc((E.Pos.Y + E.Height) / TILE_SIZE) * TILE_SIZE - E.Height;
      if IsSolidTile(FTiles, FMapCols, FMapRows, E.Pos.X + E.Width/2 + Sign(E.Vel.X)*10, E.Pos.Y + E.Height/2) then
         E.Vel.X := -E.Vel.X;
    end;

    if E.Pos.Y > (FloorLevel * TILE_SIZE + 100) then
    begin
      SpawnExplosion(E.Pos.X + E.Width/2, E.Pos.Y, TAlphaColors.Purple);
      FEnemies.Delete(I);
      Continue;
    end;
    FEnemies[I] := E;
  end;
end;

procedure TPlatformerGame.UpdateParticles(DeltaTime: Single);
var
  I: Integer;
  P: TParticle;
  Center: TPointF;
  SpawnPos: TPointF;
begin
  Center := PointF(FPlayer.Pos.X + FPlayer.Width / 2, FPlayer.Pos.Y + FPlayer.Height);

  if (FPlayer.State = bsGround) and (Abs(FPlayer.Vel.X) > 0.5) then
  begin
    if Random(5) = 0 then
    begin
      P.Pos := Center + PointF(0, FPlayer.Height/2 - 29);
      P.Vel := PointF(-FPlayer.Vel.X * 0.5, -5 - Random * 5);
      P.Life := 0.6;
      P.Color := TAlphaColors.White;
      P.Size := 3 + Random * 2;
      FParticles.Add(P);
    end;
  end;

  if Random(10) = 0 then
  begin
     SpawnPos := PointF(FPlayer.Pos.X + Random(Trunc(Width)) - Width/2, Random(FMapRows * TILE_SIZE));
     if not IsSolidTile(FTiles, FMapCols, FMapRows, SpawnPos.X, SpawnPos.Y) then
     begin
       P.Pos := SpawnPos;
       P.Vel := PointF((Random - 0.5) * 10, (Random - 0.5) * 10);
       P.Life := 2.0;
       P.Color := TAlphaColors.Yellow;
       P.Size := 2;
       FParticles.Add(P);
     end;
  end;

  for I := FParticles.Count - 1 downto 0 do
  begin
    P := FParticles[I];
    P.Pos.X := P.Pos.X + P.Vel.X * DeltaTime;
    P.Pos.Y := P.Pos.Y + P.Vel.Y * DeltaTime;
    P.Life := P.Life - (0.8 * DeltaTime);

    if P.Life <= 0 then
      FParticles.Delete(I)
    else
      FParticles[I] := P;
  end;
end;

{ =============================================================================
  PHYSICS
============================================================================= }
procedure TPlatformerGame.DoPhysicsUpdate(DeltaSec: Double);
var
  Left, Right, Jump: Boolean;
  AccelThisFrame: Single;
  NextY: Single;
  FloorLevel: Integer;
begin
  if not FActive then Exit;

  // PAUSE LOGIC: If menu is open, freeze everything
  if FMenuActive then Exit;

  // --- WIN STATE ---
  if FGameState = gsWin then
  begin
    FWinTime := FWinTime - DeltaSec;
    UpdateParticles(DeltaSec);
    FGate.Phase := FGate.Phase + DeltaSec * 20; // Speed up animation

    if FWinTime <= 0 then
    begin
      Inc(FLevel);
      GenerateProceduralMap;
      GenerateBackgroundElements; // New clouds for new level
    end;
    Exit;
  end;

  // --- DEAD STATE ---
  if FGameState = gsDead then
  begin
    FDeadTime := FDeadTime - DeltaSec;
    UpdateParticles(DeltaSec);

    if FDeadTime <= 0 then
    begin
      FGameState := gsPlaying;
      FloorLevel := FMapRows - 4;
      FPlayer.Pos.X := 100;
      FPlayer.Pos.Y := FloorLevel * TILE_SIZE - FPlayer.Height - 10;
      FPlayer.Vel.X := 0;
      FPlayer.Vel.Y := 0;
    end;
    Exit;
  end;

  // --- PLAYING STATE ---
  FloorLevel := FMapRows - 4;

  FLock.Acquire;
  try
    Left := Byte(vkLeft) in FKeys;
    Right := Byte(vkRight) in FKeys;
    Jump := Byte(vkUp) in FKeys;
  finally
    FLock.Release;
  end;

  AccelThisFrame := ACCEL * DeltaSec;
  if Left then FPlayer.Vel.X := Max(FPlayer.Vel.X - AccelThisFrame, -MAX_SPEED)
  else if Right then FPlayer.Vel.X := Min(FPlayer.Vel.X + AccelThisFrame, MAX_SPEED)
  else
  begin
    if Abs(FPlayer.Vel.X) > 0.1 then
      FPlayer.Vel.X := FPlayer.Vel.X - Sign(FPlayer.Vel.X) * FRICTION * DeltaSec
    else
      FPlayer.Vel.X := 0;
  end;

  if Jump and (FPlayer.State = bsGround) then
  begin
    FPlayer.Vel.Y := JUMP_FORCE;
    FPlayer.State := bsAir;
  end;

  if FPlayer.State = bsAir then
    FPlayer.Vel.Y := FPlayer.Vel.Y + GRAVITY * DeltaSec;

  FPlayer.Pos.X := FPlayer.Pos.X + FPlayer.Vel.X * TILE_SIZE * DeltaSec;
  if FPlayer.Pos.X < 0 then FPlayer.Pos.X := 0;
  if FPlayer.Pos.X > FMapCols * TILE_SIZE - FPlayer.Width then
    FPlayer.Pos.X := FMapCols * TILE_SIZE - FPlayer.Width;

  NextY := FPlayer.Pos.Y + FPlayer.Vel.Y * TILE_SIZE * DeltaSec;

  if IsSolidTile(FTiles, FMapCols, FMapRows, FPlayer.Pos.X + FPlayer.Width / 2, NextY + FPlayer.Height) then
  begin
    FPlayer.Pos.Y := Trunc((NextY + FPlayer.Height) / TILE_SIZE) * TILE_SIZE - FPlayer.Height;
    FPlayer.Vel.Y := 0;
    FPlayer.State := bsGround;
  end
  else if IsSolidTile(FTiles, FMapCols, FMapRows, FPlayer.Pos.X + FPlayer.Width / 2, NextY) then
  begin
    FPlayer.Pos.Y := (Trunc(NextY / TILE_SIZE) + 1) * TILE_SIZE;
    FPlayer.Vel.Y := 0;
  end
  else
  begin
    FPlayer.Pos.Y := NextY;
    FPlayer.State := bsAir;
  end;

  // Pit Fall Death
  if FPlayer.Pos.Y > (FloorLevel * TILE_SIZE + 50) then
  begin
    SpawnExplosion(FPlayer.Pos.X + FPlayer.Width/2, FPlayer.Pos.Y, TAlphaColors.Red);
    FGameState := gsDead;
    FDeadTime := 1.5;
    FPlayer.Pos.X := -1000;
    FPlayer.Vel.X := 0;
    FPlayer.Vel.Y := 0;
    FScore := 0;
    Exit;
  end;

  CheckCrateCollisions;
  CheckEnemyCollisions;
  CheckGateCollision;
  UpdateEnemies(DeltaSec);
  UpdateParticles(DeltaSec);
  UpdateCamera;
end;

{ =============================================================================
  RENDERING
============================================================================= }
procedure TPlatformerGame.DrawUI(const ACanvas: ISkCanvas);
var Font: TSkFont; Paint: ISkPaint; Txt: String;
begin
  Txt := 'Crates: ' + IntToStr(FScore) + ' | Level: ' + IntToStr(FLevel);

  Font := TSkFont.Create;
  try
    Paint := TSkPaint.Create;
    Paint.Style := TSkPaintStyle.Fill;
    Paint.AntiAlias := True;

    Paint.Color := TAlphaColors.Black;
    Paint.Alpha := 150;
    ACanvas.DrawSimpleText(Txt, 12, 42, Font, Paint);

    Paint.Color := TAlphaColors.Yellow;
    Paint.Alpha := 255;
    ACanvas.DrawSimpleText(Txt, 10, 40, Font, Paint);
  finally
    Font.Free;
  end;
end;

procedure TPlatformerGame.DrawBackgrounds(const ACanvas: ISkCanvas; const ADest: TRectF);
var
  Paint: ISkPaint;
  Colors: TArray<TAlphaColor>;
  I: Integer;
  ParallaxX1, ParallaxX2: Single;
  CloudX, CloudY, BushX, BushY: Single;
  BushColor: TAlphaColor;
begin
  // Dynamic Sky based on Level
  Case (FLevel mod 4) of
    0: Colors := [$FF0f0c29, $FF302b63, $FF24243e]; // Night (Dark Blue)
    1: Colors := [$FF87CEEB, $FFADD8E6, $FFF0F8FF]; // Day (Light Blue)
    2: Colors := [$FFFF7F50, $FFFD5E53, $FF4B0082]; // Sunset (Orange/Purple)
    3: Colors := [$FF2F4F4F, $FF008080, $FF20B2AA]; // Alien (Teal)
  else
    Colors := [$FF0f0c29, $FF302b63, $FF24243e];
  end;

  Paint := TSkPaint.Create;
  Paint.Shader := TSkShader.MakeGradientLinear(PointF(0,0), PointF(0, ADest.Height), Colors, nil, TSkTileMode.Clamp);
  ACanvas.DrawPaint(Paint);
  Paint.Shader := nil;

  ParallaxX1 := -FCameraX * 0.1;
  ParallaxX2 := -FCameraX * 0.4;

  Paint.AntiAlias := True;
  Paint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Normal, 20.0);

  for I := 0 to High(FBgClouds) do
  begin
    CloudX := FBgClouds[I].X + ParallaxX1;
    CloudY := FBgClouds[I].Y;
    if CloudX < -200 then CloudX := CloudX + (FMapCols * TILE_SIZE * 2);
    if CloudX > Width + 200 then Continue;

    if (FLevel mod 4) = 0 then Paint.Color := $FF3d3d5c else Paint.Color := $FFFFFFFF;
    Paint.Alpha := 100;
    ACanvas.DrawCircle(PointF(CloudX, CloudY), 60, Paint);
  end;

  // Dynamic Bush/Tree Colors based on Sky
  Paint.MaskFilter := nil;

  Case (FLevel mod 4) of
    0: BushColor := $FF1a1a2e; // Dark Silhouette for Night
    1: BushColor := $FF228B22; // Forest Green for Day
    2: BushColor := $FF8B0000; // Dark Red for Sunset
    3: BushColor := $FF008080; // Teal for Alien
  else
    BushColor := $FF1a1a2e;
  end;

  Paint.Color := BushColor;

  for I := 0 to High(FBgBushes) do
  begin
    BushX := FBgBushes[I].X + ParallaxX2;
    BushY := FBgBushes[I].Y;
    if BushX < -50 then BushX := BushX + (FMapCols * TILE_SIZE * 2);
    if BushX > Width + 50 then Continue;

    ACanvas.DrawCircle(PointF(BushX, BushY), 25, Paint);
    ACanvas.DrawCircle(PointF(BushX + 20, BushY + 5), 20, Paint);
  end;
end;

procedure TPlatformerGame.DrawTileMap(const ACanvas: ISkCanvas);
var
  Paint, GlowPaint: ISkPaint;
  TileRect: TRectF;
  C, R: Integer;
begin
  Paint := TSkPaint.Create(TSkPaintStyle.Fill);
  Paint.AntiAlias := True;

  GlowPaint := TSkPaint.Create(TSkPaintStyle.Stroke);
  GlowPaint.StrokeWidth := 2.0;
  GlowPaint.AntiAlias := True;
  GlowPaint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 4.0);

  for R := 0 to FMapRows - 1 do
    for C := 0 to FMapCols - 1 do
    begin
      if FTiles[R * FMapCols + C].Solid then
      begin
        TileRect := TRectF.Create(C * TILE_SIZE, R * TILE_SIZE, (C + 1) * TILE_SIZE, (R + 1) * TILE_SIZE);

        if (TileRect.Right < FCameraX - 50) or (TileRect.Left > FCameraX + Width + 50) then
          Continue;

        case FTiles[R * FMapCols + C].TileType of
          ttGrass:
            begin
              Paint.Color := TAlphaColors.Darkgreen;
              ACanvas.DrawRoundRect(TileRect, 4, 4, Paint);
              GlowPaint.Color := $FF00ff00;
              ACanvas.DrawRoundRect(TileRect, 4, 4, GlowPaint);
            end;
          ttGround:
            begin
              Paint.Color := TAlphaColors.Brown;
              ACanvas.DrawRoundRect(TileRect, 4, 4, Paint);
            end;
          ttStone:
            begin
              Paint.Color := $FF3d3d5c;
              ACanvas.DrawRoundRect(TileRect, 6, 6, Paint);
              GlowPaint.Color := $FF7070db;
              ACanvas.DrawRoundRect(TileRect, 6, 6, GlowPaint);
            end;
        end;
      end;
    end;
end;

procedure TPlatformerGame.DrawDecorations(const ACanvas: ISkCanvas);
var
  Item: TDecorItem;
  Paint: ISkPaint;
  PotRect, CrateRect: TRectF;
begin
  Paint := TSkPaint.Create(TSkPaintStyle.Fill);
  Paint.AntiAlias := True;
  Paint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 2.0);

  for Item in FDecor do
  begin
    if (Item.Pos.X < FCameraX - 100) or (Item.Pos.X > FCameraX + Width + 100) then
      Continue;

    case Item.Kind of
      dtPlant:
        begin
          PotRect := TRectF.Create(Item.Pos.X + 4, Item.Pos.Y + 20, Item.Pos.X + 28, Item.Pos.Y + 32);
          Paint.Color := $FF8b4513;
          Paint.Style := TSkPaintStyle.Fill;
          ACanvas.DrawRoundRect(PotRect, 2, 2, Paint);

          Paint.Color := $FF5c4033;
          ACanvas.DrawLine(PointF(Item.Pos.X + 16, Item.Pos.Y + 20), PointF(Item.Pos.X + 16, Item.Pos.Y + 5), Paint);

          Paint.Color := $FF39ff14;
          Paint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 4.0);
          ACanvas.DrawCircle(PointF(Item.Pos.X + 16, Item.Pos.Y + 5), 6, Paint);
          ACanvas.DrawCircle(PointF(Item.Pos.X + 10, Item.Pos.Y + 10), 4, Paint);
          ACanvas.DrawCircle(PointF(Item.Pos.X + 22, Item.Pos.Y + 10), 4, Paint);
          Paint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 2.0);
        end;
      dtCrate:
        begin
          CrateRect := TRectF.Create(Item.Pos.X + 2, Item.Pos.Y + 2, Item.Pos.X + 30, Item.Pos.Y + 30);
          Paint.Style := TSkPaintStyle.Fill;
          Paint.Color := $FF4b3621;
          ACanvas.DrawRect(CrateRect, Paint);

          Paint.Style := TSkPaintStyle.Stroke;
          Paint.StrokeWidth := 2;
          Paint.Color := $FFffa500;
          ACanvas.DrawLine(CrateRect.TopLeft, CrateRect.BottomRight, Paint);
          ACanvas.DrawLine(PointF(CrateRect.Left, CrateRect.Bottom), PointF(CrateRect.Right, CrateRect.Top), Paint);
          Paint.Style := TSkPaintStyle.Fill;
        end;
    end;
  end;
end;

procedure TPlatformerGame.DrawGate(const ACanvas: ISkCanvas);
var Paint: ISkPaint; Center: TPointF; PhaseOffset: Single; PathBuilder: ISkPathBuilder; I: Integer; Angle, Radius: Single;
begin
  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;

  Center := PointF(FGate.Pos.X + FGate.Width/2, FGate.Pos.Y + FGate.Height/2);

  // SAVE Canvas state to apply blur to EVERYTHING
  ACanvas.Save;

  // Apply a strong blur filter to the entire layer
  ACanvas.Scale(1, 1); // Identity scale
  // We use a layer for the blur to affect the shape fills properly
  ACanvas.SaveLayer(TSkPaint.Create);
  try
    // 1. Morphing Outer Aura (Cyan/Purple Glow)
    Paint.Style := TSkPaintStyle.Fill;
    Paint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 25.0);

    // Breathing color
    if Sin(FGate.Phase * 2) > 0 then
      Paint.Color := $FF00FFFF // Cyan
    else
      Paint.Color := $FFFF00FF; // Purple

    Paint.Alpha := 180;

    PhaseOffset := Sin(FGate.Phase) * 0.2;
    ACanvas.Save;
    ACanvas.Translate(Center.X, Center.Y);
    ACanvas.Scale(1.0 + PhaseOffset, 1.0 - PhaseOffset); // Morph
    ACanvas.DrawOval(TRectF.Create(-45, -70, 45, 70), Paint);
    ACanvas.Restore;

    // 2. Dark Center "Hole" (Also blurred)
    Paint.Style := TSkPaintStyle.Fill;
    Paint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Normal, 10.0); // Softer blur for center
    Paint.Color := $FF050510; // Very dark blue/black
    ACanvas.DrawOval(TRectF.Create(Center.X - 25, Center.Y - 45, Center.X + 25, Center.Y + 45), Paint);

    // 3. Inner Vortex Lines (White)
    Paint.Style := TSkPaintStyle.Stroke;
    Paint.StrokeWidth := 2;
    Paint.Color := $FFFFFFFF;
    Paint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 3.0); // Glow lines

    PathBuilder := TSkPathBuilder.Create;
    PathBuilder.MoveTo(Center.X, Center.Y);

    for I := 0 to 20 do
    begin
      Angle := FGate.Phase * 5 + (I * 0.5);
      Radius := I * 3.0;
      PathBuilder.LineTo(
        Center.X + Cos(Angle) * Radius,
        Center.Y + Sin(Angle) * Radius * 1.5
      );
    end;

    ACanvas.DrawPath(PathBuilder.Snapshot, Paint);

  finally
    ACanvas.Restore; // Removes the layer/blur
    ACanvas.Restore; // Restores canvas matrix
  end;
end;


procedure TPlatformerGame.DrawMenu(const ACanvas: ISkCanvas; const ADest: TRectF);
var Paint: ISkPaint; Font: TSkFont; Rect: TRectF; CenterX, CenterY: Single;
begin
  // 1. Dark Overlay
  Paint := TSkPaint.Create;
  Paint.Color := $AA000000; // Semi-transparent black
  ACanvas.DrawPaint(Paint);

  // 2. Menu Box
  CenterX := ADest.Width / 2;
  CenterY := ADest.Height / 2;
  Rect := TRectF.Create(CenterX - 150, CenterY - 100, CenterX + 150, CenterY + 100);

  Paint.Color := $FF333344;
  Paint.AntiAlias := True;
  ACanvas.DrawRoundRect(Rect, 20, 20, Paint);

  // Border
  Paint.Style := TSkPaintStyle.Stroke;
  Paint.StrokeWidth := 3;
  Paint.Color := $FFFFFFFF;
  ACanvas.DrawRoundRect(Rect, 20, 20, Paint);

  // 3. Text
  Font := TSkFont.Create;
  try

    Paint := TSkPaint.Create(TSkPaintStyle.Fill);
    Paint.AntiAlias := True;

    // Title
    Paint.Color := TAlphaColors.White;
    ACanvas.DrawSimpleText('PAUSED', CenterX - 70, CenterY - 50, Font, Paint);

    // Instructions
    Paint.Color := TAlphaColors.Yellow;
    ACanvas.DrawSimpleText('ESC - Resume', CenterX - 65, CenterY + 10, Font, Paint);
    ACanvas.DrawSimpleText('R - Reset Level', CenterX - 70, CenterY + 40, Font, Paint);
  finally
    Font.Free;
  end;
end;


procedure TPlatformerGame.DrawEnemies(const ACanvas: ISkCanvas);
var E: TEnemy; Paint, GlowPaint: ISkPaint; Center: TPointF; Offset: Single;
begin
  Paint := TSkPaint.Create(TSkPaintStyle.Fill);
  Paint.AntiAlias := True;

  GlowPaint := TSkPaint.Create(Paint);
  GlowPaint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 6.0);
  GlowPaint.Color := TAlphaColors.Purple;

  for E in FEnemies do
  begin
    Center := PointF(E.Pos.X + E.Width/2, E.Pos.Y + E.Height/2);
    Offset := Sin(E.Phase) * 3.0;

    Paint.Color := TAlphaColors.Fuchsia;
    ACanvas.DrawOval(TRectF.Create(Center.X - 14, Center.Y - 12 + Offset, Center.X + 14, Center.Y + 12 + Offset), GlowPaint);
    ACanvas.DrawOval(TRectF.Create(Center.X - 12, Center.Y - 10 + Offset, Center.X + 12, Center.Y + 10 + Offset), Paint);

    Paint.Color := TAlphaColors.White;
    ACanvas.DrawCircle(PointF(Center.X - 4, Center.Y - 2 + Offset), 3, Paint);
    ACanvas.DrawCircle(PointF(Center.X + 4, Center.Y - 2 + Offset), 3, Paint);

    Paint.Color := TAlphaColors.Black;
    ACanvas.DrawCircle(PointF(Center.X - 4, Center.Y - 2 + Offset), 1.5, Paint);
    ACanvas.DrawCircle(PointF(Center.X + 4, Center.Y - 2 + Offset), 1.5, Paint);
  end;
end;

procedure TPlatformerGame.DrawParticles(const ACanvas: ISkCanvas);
var P: TParticle; Paint: ISkPaint; AlphaVal: Integer;
begin
  if FParticles.Count = 0 then Exit;
  Paint := TSkPaint.Create(TSkPaintStyle.Fill);
  Paint.AntiAlias := True;
  Paint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 3.0);

  for P in FParticles do
  begin
    Paint.Color := P.Color;
    AlphaVal := Round(P.Life * 180);
    if AlphaVal > 255 then AlphaVal := 255;
    if AlphaVal < 0 then AlphaVal := 0;
    Paint.Alpha := AlphaVal;
    ACanvas.DrawCircle(P.Pos, P.Size * P.Life, Paint);
  end;
end;

procedure TPlatformerGame.DrawAliveAvatar(const ACanvas: ISkCanvas; const Center: TPointF; const Scale: Single; const VelX: Single);
var
  Paint, GlowPaint: ISkPaint;
  HeadPos, NeckPos, HipPos, FootL, FootR, HandL, HandR: TPointF;
  HeadRadius, BodyHeight: Single;
  Sway, Breathe: Single;
  CurrentPhase: Single;
  LookDir: Single;
  YOffset: Single;
  PB: ISkPathBuilder;
begin
  Paint := TSkPaint.Create;
  Paint.Style := TSkPaintStyle.Stroke;
  Paint.StrokeWidth := 3.0 * Scale;
  Paint.StrokeCap := TSkStrokeCap.Round;
  Paint.StrokeJoin := TSkStrokeJoin.Round;
  Paint.AntiAlias := True;

  // CHANGE: Avatar is now Dark Grey instead of White
  Paint.Color := $FF202020;

  GlowPaint := TSkPaint.Create(Paint);
  GlowPaint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 8.0);
  GlowPaint.Color := $FF00ffff; // Cyan Glow remains

  if VelX < -0.1 then LookDir := -1 else LookDir := 1;

  YOffset := 3.0 * Scale + 3.0;

  if FPlayer.State = bsGround then
  begin
    if Abs(VelX) > 0.1 then
    begin CurrentPhase := FAnimPhase * 8; Breathe := Sin(CurrentPhase) * 2.0 * Scale; Sway := 0; end
    else
    begin CurrentPhase := 0; Breathe := 0; Sway := 0; end;
  end
  else
  begin
    CurrentPhase := FAnimPhase; Breathe := Sin(CurrentPhase * 3) * 1.5 * Scale; Sway := Sin(CurrentPhase) * 3.0 * Scale;
  end;

  HeadRadius := 7.0 * Scale;
  BodyHeight := 24.0 * Scale;

  HeadPos := PointF(Center.X + Sway, Center.Y + Breathe + YOffset);
  NeckPos := PointF(Center.X + Sway, Center.Y + Breathe + HeadRadius + YOffset);
  HipPos := PointF(Center.X + (Sway * 0.5), Center.Y + Breathe + HeadRadius + BodyHeight + YOffset);

  if FPlayer.State = bsAir then
  begin
    FootL := PointF(HipPos.X - 8 * Scale, HipPos.Y + 10 * Scale);
    FootR := PointF(HipPos.X + 8 * Scale, HipPos.Y + 10 * Scale);
    HandL := PointF(NeckPos.X - 12 * Scale, NeckPos.Y - 2 * Scale);
    HandR := PointF(NeckPos.X + 12 * Scale, NeckPos.Y - 2 * Scale);
  end
  else if Abs(VelX) > 0.1 then
  begin
    FootL := PointF(HipPos.X - 5 * Scale + Sin(CurrentPhase)*4*Scale, HipPos.Y + 14 * Scale);
    FootR := PointF(HipPos.X + 5 * Scale - Sin(CurrentPhase)*4*Scale, HipPos.Y + 14 * Scale);
    HandL := PointF(NeckPos.X - 9 * Scale, NeckPos.Y + 12 * Scale + Sin(CurrentPhase)*2*Scale);
    HandR := PointF(NeckPos.X + 9 * Scale, NeckPos.Y + 12 * Scale - Sin(CurrentPhase)*2*Scale);
  end
  else
  begin
    FootL := PointF(HipPos.X - 5 * Scale, HipPos.Y + 14 * Scale);
    FootR := PointF(HipPos.X + 5 * Scale, HipPos.Y + 14 * Scale);
    HandL := PointF(NeckPos.X - 9 * Scale, NeckPos.Y + 12 * Scale);
    HandR := PointF(NeckPos.X + 9 * Scale, NeckPos.Y + 12 * Scale);
  end;

  PB := TSkPathBuilder.Create;
  PB.MoveTo(HipPos.X, HipPos.Y); PB.LineTo(FootL.X, FootL.Y);
  PB.MoveTo(HipPos.X, HipPos.Y); PB.LineTo(FootR.X, FootR.Y);
  PB.MoveTo(NeckPos.X, NeckPos.Y); PB.LineTo(HandL.X, HandL.Y);
  PB.MoveTo(NeckPos.X, NeckPos.Y); PB.LineTo(HandR.X, HandR.Y);
  PB.MoveTo(NeckPos.X, NeckPos.Y); PB.LineTo(HipPos.X, HipPos.Y);

  ACanvas.DrawPath(PB.Snapshot, GlowPaint);
  ACanvas.DrawPath(PB.Snapshot, Paint);

  Paint.Style := TSkPaintStyle.Fill;
  ACanvas.DrawCircle(HeadPos, HeadRadius, GlowPaint);
  ACanvas.DrawCircle(HeadPos, HeadRadius, Paint);

  // Eyes (White stays white for visibility)
  Paint.Color := TAlphaColors.White;
  Paint.MaskFilter := nil;
  var EyeL := PointF(HeadPos.X + (3 * Scale * LookDir), HeadPos.Y - 2 * Scale);
  var EyeR := PointF(HeadPos.X + (7 * Scale * LookDir), HeadPos.Y - 2 * Scale);
  ACanvas.DrawCircle(EyeL, 2.2 * Scale, Paint);
  ACanvas.DrawCircle(EyeR, 2.2 * Scale, Paint);
end;


procedure TPlatformerGame.Draw(const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single);
begin
  DrawBackgrounds(ACanvas, ADest);

  ACanvas.Save;
  ACanvas.Translate(-FCameraX, 0);

  FLock.Acquire;
  try
    DrawTileMap(ACanvas);
    DrawDecorations(ACanvas);
    DrawGate(ACanvas);
    DrawEnemies(ACanvas);
    DrawParticles(ACanvas);

    if FGameState = gsPlaying then
    begin
      FAnimPhase := FAnimPhase + 0.1;
      var PlayerCenter := PointF(FPlayer.Pos.X + FPlayer.Width / 2, FPlayer.Pos.Y);
      DrawAliveAvatar(ACanvas, PlayerCenter, 1.0, FPlayer.Vel.X);
    end;

    FGate.Phase := FGate.Phase + 0.05;

  finally
    FLock.Release;
    ACanvas.Restore;
  end;

  DrawUI(ACanvas);

  // DRAW MENU ON TOP
  if FMenuActive then
    DrawMenu(ACanvas, ADest);
end;
{ =============================================================================
  LIFECYCLE
============================================================================= }
procedure TPlatformerGame.SafeInvalidate;
begin
  if csDestroying in ComponentState then Exit;
  TThread.Queue(nil,
    procedure
    begin
      if not (csDestroying in ComponentState) and Assigned(Self) then
      begin
        Redraw;
        Repaint;
      end;
    end);
end;

procedure TPlatformerGame.StartThread;
begin
  if Assigned(FThread) then Exit;
  FThread := TThread.CreateAnonymousThread(
    procedure
    var LastTime, NowTime, DeltaMS: Cardinal;
    begin
      LastTime := TThread.GetTickCount;
      while not TThread.CheckTerminated do
      begin
        NowTime := TThread.GetTickCount;
        DeltaMS := NowTime - LastTime;
        if DeltaMS = 0 then DeltaMS := 1;
        LastTime := NowTime;
        if FActive then
        begin
          DoPhysicsUpdate(DeltaMS / 1000);
          SafeInvalidate;
        end;
        Sleep(12);
      end;
    end);
  FThread.FreeOnTerminate := True;
  FThread.Start;
end;

procedure TPlatformerGame.StopThread;
begin
  FActive := False;
  if Assigned(FThread) then
  begin
    FThread.Terminate;
    Sleep(50);
  end;
end;

constructor TPlatformerGame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLock := TCriticalSection.Create;
  Align := TAlignLayout.Client;
  HitTest := True;
  CanFocus := True;
  TabStop := True;

  FActive := True;
  FLevel := 1;
  FGameState := gsPlaying;

  FMapCols := 200;
  FMapRows := 20;
  FCameraX := 0;
  FParticles := TList<TParticle>.Create;
  FDecor := TList<TDecorItem>.Create;
  FEnemies := TList<TEnemy>.Create;
  SetLength(FTiles, FMapCols * FMapRows);

  FPlayer.Width := 28;
  FPlayer.Height := 56;

  GenerateBackgroundElements;
  GenerateProceduralMap;

  StartThread;
end;

destructor TPlatformerGame.Destroy;
begin
  StopThread;
  FreeAndNil(FLock);
  FreeAndNil(FParticles);
  FreeAndNil(FDecor);
  FreeAndNil(FEnemies);
  inherited;
end;

procedure TPlatformerGame.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
var
  GameKey: Byte;
begin
  // 1. MENU TOGGLE (ESC or M)
  if (Key = vkEscape) or (KeyChar = 'M') or (KeyChar = 'm') then
  begin
    FMenuActive := not FMenuActive;
    Key := 0;
    KeyChar := #0;
    Redraw;
    Repaint;
    Exit;
  end;

  // 2. MENU INPUTS (Reset)
  if FMenuActive then
  begin
    if (KeyChar = 'R') or (KeyChar = 'r') then
    begin
      FLevel := 1;
      GenerateProceduralMap;
      GenerateBackgroundElements;
      FMenuActive := False;
      Key := 0;
      KeyChar := #0;
      Redraw;
      Repaint;
    end;
    Exit;
  end;

  // 3. MAP CONTROLS
  GameKey := 0;

  // A. Check Key Codes (Arrows, Space)
  // We use the Hex values matching your provided constants ($25=37, $20=32 etc.)
  case Key of
    $25: GameKey := $25; // vkLeft  (37)
    $27: GameKey := $27; // vkRight (39)
    $26: GameKey := $26; // vkUp    (38)
    $28: GameKey := $28; // vkDown  (40)
    $20: GameKey := $26; // vkSpace (32) -> Map to vkUp (Jump)
  end;

  // B. Check KeyChar (WASD and Space fallback)
  // If Key was 0 (common for letters/space), check KeyChar
  if GameKey = 0 then
  begin
    case KeyChar of
      'A', 'a': GameKey := $25; // Map to Left
      'D', 'd': GameKey := $27; // Map to Right
      'W', 'w': GameKey := $26; // Map to Up
      'S', 's': GameKey := $28; // Map to Down
      ' ':      GameKey := $26; // Space -> Map to Up (Jump)
    end;
  end;

  // 4. PROCESS INPUT
  if GameKey > 0 then
  begin
    FLock.Acquire;
    try
      Include(FKeys, GameKey);
    finally
      FLock.Release;
    end;
    Key := 0;
    KeyChar := #0;
  end;

  inherited;
end;

procedure TPlatformerGame.KeyUp(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
var
  GameKey: Byte;
begin
  if FMenuActive then Exit;

  GameKey := 0;

  // A. Check Key Codes
  case Key of
    $25: GameKey := $25;
    $27: GameKey := $27;
    $26: GameKey := $26;
    $28: GameKey := $28;
    $20: GameKey := $26; // Space -> Up
  end;

  // B. Check KeyChar
  if GameKey = 0 then
  begin
    case KeyChar of
      'A', 'a': GameKey := $25;
      'D', 'd': GameKey := $27;
      'W', 'w': GameKey := $26;
      'S', 's': GameKey := $28;
      ' ':      GameKey := $26;
    end;
  end;

  if GameKey > 0 then
  begin
    FLock.Acquire;
    try
      Exclude(FKeys, GameKey);
    finally
      FLock.Release;
    end;
    Key := 0;
    KeyChar := #0;
  end;

  inherited;
end;
end.


