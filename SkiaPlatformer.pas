{*******************************************************************************
  SkiaPlatformer (Endless Scroller Edition)
********************************************************************************
  A high-performance, thread-safe 2D platformer engine built on Skia4Delphi.
  Designed for smooth animations, particle effects, and responsive physics.
  Now featuring 100% code-generated, procedural textures! No external images.

  Author:  Lara Miriam Tamy Reschke
  License: MIT
  Key Features:
  - Procedural World Generation: Infinite scrolling map with strategic gaps,
    floating platforms, and sky islands.
  - Procedural Textures: Grass, dirt, and stone textures are generated entirely
    in code at runtime using an 8-variant texture atlas to break repetition.
  - Advanced Visuals: Dynamic Day/Night/Alien cycle, parallax backgrounds,
    and neon glow effects.
  - Game Loop: Score system, "Stargate" level transitions, and deadly traps.
  - Enemies & Interactions: AI enemies that patrol and react to pits, plus
    exploding crates for points.
  - Custom Physics Engine: Tile-based collision, gravity, friction, and inertia.
  - "Alive" Avatar System: Organic sine-wave animations, with specific jump/fall
    poses that freeze leg movement while in the air.
  - Particle System: Dynamic visual effects (Explosions, Dust, Fireflies).
*******************************************************************************}

{ Skia-Platformer v0.5                                                         }
{ by Lara Miriam Tamy Reschke                                                  }
{                                                                              }
{------------------------------------------------------------------------------}
{
 ----Latest Changes
   v 0.5: Visuals Overhaul, Game Feel & Dynamic Themes Update
     - Added Procedural Texture Generation: Grass, Dirt, and Stone are now
       rendered using a code-generated 8-variant texture atlas. No external
       image files required!
     - Dynamic Visual Styles: Press 'V' to cycle through rendering modes:
       1. Standard (Organic nature textures)
       2. Sci-Fi/Cyberpunk (Dark neon-cracked terrain)
       3. Cuphead Mode (Vintage film grain, sepia tint, and vignette overlay)
     - Avatar Animations: Reworked jump physics for both Stickman and Cat.
       Legs no longer play the running animation while in the air (bsAir);
       instead, they lock into a dynamic jumping pose.
     - Backgrounds: Replaced mountain snow with deterministic rock structures
       and cracks. Trees now feature procedural leaf clusters.
   v 0.4:
     - Added Audio effect system with royalty free audios from
       https://www.pavsmusic.com/free-sound-pack-kits/
   v 0.3:
     - Added cat avatar -> Toggle between "Stickman" and "Cat" avatars by pressing 'C'.
     - Cat Avatar features tail wagging, ear rendering, and directional head movement.
     - Added a new "Far Mountains" background layer with parallax scrolling;
     - Fixed - all scenery (trees, mountains) now anchors to the bottom of the screen,
       eliminating floating elements over pits.
     - Physics & Controls: Reworked friction logic to use exponential deceleration.
       movement now stops instantly and cleanly without the "wiggle" or coasting delay.
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
  FMX.Controls, FMX.Forms, FMX.Skia, Winapi.MMSystem, System.Skia;

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

  TAudioEffect = (afNone, afJump, afExplosion, afCrate, afPortal, afWin, afDie);

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
    FThread: TThread;
    FActive: Boolean;
    FLock: TCriticalSection;
    FKeys: set of Byte;
    FMenuActive: Boolean;
    FScore: Integer;
    FLevel: Integer;
    FGameState: TGameState;
    FDeadTime: Single;
    FWinTime: Single;
    FUseCatAvatar: Boolean;
    FAnimPhase: Single;
    FLookDir: Integer;
    FBraking: Boolean;
    FCrouching: Boolean;
    FPlayer: TActor;
    FTiles: TArray<TTile>;
    FDecor: TList<TDecorItem>;
    FEnemies: TList<TEnemy>;
    FGate: TGate;
    FMapCols: Integer;
    FMapRows: Integer;
    FCameraX: Single;
    FParticles: TList<TParticle>;
    FBgClouds: TArray<TPointF>;
    FBgBushes: TArray<TPointF>;
    FBgMountains: TArray<TPointF>;
    FVisualMode: Integer; // 0: Standard, 1: SciFi, 2: Cuphead
    FGrainShader: ISkShader;
    // Procedural Textures
    FGrassShader: ISkShader;
    FDirtShader: ISkShader;
    FStoneShader: ISkShader;

    procedure PlayEffect(Effect: TAudioEffect);
    procedure DoPhysicsUpdate(DeltaSec: Double);
    procedure UpdateCamera;
    procedure SafeInvalidate;
    procedure StartThread;
    procedure StopThread;
    procedure GenerateProceduralMap;
    procedure GenerateBackgroundElements;
    procedure InitProceduralTextures;
    procedure CheckCrateCollisions;
    procedure CheckEnemyCollisions;
    procedure CheckGateCollision;
    procedure UpdateEnemies(DeltaSec: Double);
    procedure SpawnExplosion(const X, Y: Single; Color: TAlphaColor);
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
    procedure DrawCatAvatar(const ACanvas: ISkCanvas; const Center: TPointF; const Scale: Single; const VelX: Single);
  protected
    procedure Draw(const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
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
  PROCEDURAL TEXTURE GENERATION
============================================================================= }
procedure TPlatformerGame.InitProceduralTextures;
var
  LSurface: ISkSurface;
  LCanvas: ISkCanvas;
  LPaint: ISkPaint;
  I, VariantX, J: Integer;
  BaseX: Single;
  BladeColors: array[0..3] of TAlphaColor;
begin
  Randomize;
  LPaint := TSkPaint.Create(TSkPaintStyle.Fill);
  LPaint.AntiAlias := True;

  if FVisualMode = 1 then
  begin
    // --- SCI-FI / CYBERPUNK MODE ---
    // Dark Stone with Neon Cracks
    LSurface := TSkSurface.MakeRaster(256, 32);
    LCanvas := LSurface.Canvas;
    LCanvas.Clear($FF000000);
    for VariantX := 0 to 7 do
    begin
      LPaint.Style := TSkPaintStyle.Fill;
      LPaint.Color := $FF111118;
      LCanvas.DrawRect(RectF(VariantX * 32, 0, (VariantX + 1) * 32, 32), LPaint);
      LPaint.StrokeWidth := 1.5;
      LPaint.Style := TSkPaintStyle.Stroke;
      // Neon Pink/Blue Cracks
      if VariantX mod 2 = 0 then
        LPaint.Color := $FFFF00FF
      else
        LPaint.Color := $FF00FFFF;
      for I := 0 to 3 do
        LCanvas.DrawLine(PointF(VariantX * 32 + Random(32), Random(32)), PointF(VariantX * 32 + Random(32), Random(32)), LPaint);
    end;
    FGrassShader := LSurface.MakeImageSnapshot.MakeShader(TSkTileMode.repeat, TSkTileMode.repeat);
    FDirtShader := FGrassShader;
    FStoneShader := FGrassShader;
  end
  else
  begin
    // --- STANDARD NATURE MODE ---
    BladeColors[0] := $FF3A6A2A;
    BladeColors[1] := $FF4F7A35;
    BladeColors[2] := $FF7A9A45;
    BladeColors[3] := $FF558B2F;

    LSurface := TSkSurface.MakeRaster(256, 32);
    LCanvas := LSurface.Canvas;
    LCanvas.Clear($FF000000);
    for VariantX := 0 to 7 do
    begin
      LPaint.Color := $FF5A3A1A;
      LPaint.Style := TSkPaintStyle.Fill;
      LCanvas.DrawRect(RectF(VariantX * 32, 0, (VariantX + 1) * 32, 32), LPaint);
      for I := 0 to 15 do
      begin
        LPaint.Color := $FF3A220A;
        LCanvas.DrawCircle(PointF(VariantX * 32 + Random(32), Random(32)), 1 + Random(2), LPaint);
        LPaint.Color := $FF8A6A4A;
        LCanvas.DrawCircle(PointF(VariantX * 32 + Random(32), Random(32)), 1, LPaint);
      end;
      LPaint.Color := $FF2E5D2E;
      LCanvas.DrawRect(RectF(VariantX * 32, 0, (VariantX + 1) * 32, 10), LPaint);
      LPaint.StrokeWidth := 1.5;
      LPaint.Style := TSkPaintStyle.Stroke;
      LPaint.StrokeCap := TSkStrokeCap.Round;
      for I := 0 to 4 do
      begin
        BaseX := VariantX * 32 + Random(32);
        LPaint.Color := BladeColors[Random(4)];
        for J := 0 to 1 + Random(2) do
        begin
          var RootX := BaseX + J * 2 - 1;
          var TipX := RootX + (Random - 0.5) * 4;
          var Height := 4 + Random(6);
          LCanvas.DrawLine(PointF(RootX, 10), PointF(TipX, 10 - Height), LPaint);
        end;
      end;
    end;
    FGrassShader := LSurface.MakeImageSnapshot.MakeShader(TSkTileMode.repeat, TSkTileMode.repeat);

    // Dirt
    LSurface := TSkSurface.MakeRaster(256, 32);
    LCanvas := LSurface.Canvas;
    LCanvas.Clear($FF000000);
    for VariantX := 0 to 7 do
    begin
      LPaint.Color := $FF4A2F15;
      LPaint.Style := TSkPaintStyle.Fill;
      LCanvas.DrawRect(RectF(VariantX * 32, 0, (VariantX + 1) * 32, 32), LPaint);
      for I := 0 to 15 do
      begin
        LPaint.Color := $FF2A1A0A;
        LCanvas.DrawCircle(PointF(VariantX * 32 + Random(32), Random(32)), 1 + Random(2), LPaint);
        LPaint.Color := $FF6A4A2A;
        LCanvas.DrawCircle(PointF(VariantX * 32 + Random(32), Random(32)), 1, LPaint);
      end;
    end;
    FDirtShader := LSurface.MakeImageSnapshot.MakeShader(TSkTileMode.repeat, TSkTileMode.repeat);

    // Stone
    LSurface := TSkSurface.MakeRaster(256, 32);
    LCanvas := LSurface.Canvas;
    LCanvas.Clear($FF000000);
    for VariantX := 0 to 7 do
    begin
      LPaint.Style := TSkPaintStyle.Fill;
      LPaint.Color := $FF3D3D5C;
      LCanvas.DrawRect(RectF(VariantX * 32, 0, (VariantX + 1) * 32, 32), LPaint);
      for I := 0 to 10 do
      begin
        LPaint.Color := $FF505080;
        LCanvas.DrawCircle(PointF(VariantX * 32 + Random(32), Random(32)), 1 + Random(3), LPaint);
      end;
      LPaint.StrokeWidth := 1;
      LPaint.Style := TSkPaintStyle.Stroke;
      LPaint.Color := $FF000000;
      for I := 0 to 2 do
        LCanvas.DrawLine(PointF(VariantX * 32 + Random(32), Random(32)), PointF(VariantX * 32 + Random(32), Random(32)), LPaint);
    end;
    FStoneShader := LSurface.MakeImageSnapshot.MakeShader(TSkTileMode.repeat, TSkTileMode.repeat);
  end;

  // --- CUPHEAD GRAIN FILTER  ---
  LSurface := TSkSurface.MakeRaster(128, 128);
  LCanvas := LSurface.Canvas;
  LCanvas.Clear($FF000000);
  LPaint.Style := TSkPaintStyle.Fill;
  for I := 0 to 4000 do
  begin
    var LGray := Random(255);
    LPaint.Color := TAlphaColorF.Create(LGray, LGray, LGray, 80).ToAlphaColor;
    LCanvas.DrawPoint(PointF(Random(128), Random(128)), LPaint);
  end;
  FGrainShader := LSurface.MakeImageSnapshot.MakeShader(TSkTileMode.repeat, TSkTileMode.repeat);
end;
{ =============================================================================
  WORLD GENERATION
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
  Depth: Integer; // Used for deep ground generation
begin
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
  FGameState := gsPlaying;
  FDeadTime := 0;
  FWinTime := 0;

  C := 0;
  while C < FMapCols do
  begin
    if C < 5 then
    begin
      // SAFE START AREA (4 tiles deep)
      FTiles[FloorLevel * FMapCols + C].TileType := ttGrass;
      FTiles[FloorLevel * FMapCols + C].Solid := True;
      for Depth := 1 to 3 do
      begin
        if FloorLevel + Depth < FMapRows then
        begin
          FTiles[(FloorLevel + Depth) * FMapCols + C].TileType := ttGround;
          FTiles[(FloorLevel + Depth) * FMapCols + C].Solid := True;
        end;
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
      // NORMAL GROUND (4 tiles deep)
      FTiles[FloorLevel * FMapCols + C].TileType := ttGrass;
      FTiles[FloorLevel * FMapCols + C].Solid := True;
      for Depth := 1 to 3 do
      begin
        if FloorLevel + Depth < FMapRows then
        begin
          FTiles[(FloorLevel + Depth) * FMapCols + C].TileType := ttGround;
          FTiles[(FloorLevel + Depth) * FMapCols + C].Solid := True;
        end;
      end;

      if Random(30) = 0 then
      begin
        Item.Pos := PointF(C * TILE_SIZE, (FloorLevel - 1) * TILE_SIZE);
        Item.Kind := dtPlant;
        FDecor.Add(Item);
      end;
      Inc(C);
    end;
  end;

  PlatformX := 10;
  while PlatformX < FMapCols - 10 do
  begin
    PlatformX := PlatformX + 3 + Random(4);
    PlatformY := FloorLevel - (3 + Random(3));
    if PlatformY < 2 then
      PlatformY := 2;
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

  PlatformX := 20;
  while PlatformX < FMapCols - 10 do
  begin
    PlatformX := PlatformX + 8 + Random(10);
    PlatformY := FloorLevel - (8 + Random(5));
    if PlatformY < 1 then
      PlatformY := 1;
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

  FGate.Pos := PointF((FMapCols - 15) * TILE_SIZE, (FloorLevel - 2) * TILE_SIZE);
  FGate.Width := 64;
  FGate.Height := 96;
  FGate.Phase := 0;
  FPlayer.Pos := PointF(100, FloorLevel * TILE_SIZE - FPlayer.Height - 10);
end;

procedure TPlatformerGame.GenerateBackgroundElements;
var
  I: Integer;
begin
  SetLength(FBgClouds, 30);
  for I := 0 to High(FBgClouds) do
    FBgClouds[I] := PointF(Random(FMapCols * TILE_SIZE * 2), Random(300) + 20);

  SetLength(FBgMountains, 15);
  for I := 0 to High(FBgMountains) do
    FBgMountains[I] := PointF(Random(FMapCols * TILE_SIZE * 2), 30 + Random(40));

  SetLength(FBgBushes, 50);
  for I := 0 to High(FBgBushes) do
    FBgBushes[I] := PointF(Random(FMapCols * TILE_SIZE * 2), 25 + Random(35));
end;

{ =============================================================================
  LOGIC & AI
============================================================================= }
procedure TPlatformerGame.UpdateCamera;
var
  ScreenWidth, TargetX: Single;
begin
  if FDeadTime > 0 then
    Exit;
  ScreenWidth := Width;
  TargetX := FPlayer.Pos.X - (ScreenWidth * 0.4);
  FCameraX := FCameraX + (TargetX - FCameraX) * 0.25;
  if FCameraX < 0 then
    FCameraX := 0;
  if FCameraX > (FMapCols * TILE_SIZE) - ScreenWidth + 200 then
    FCameraX := (FMapCols * TILE_SIZE) - ScreenWidth + 200;
end;

procedure TPlatformerGame.SpawnExplosion(const X, Y: Single; Color: TAlphaColor);
var
  I: Integer;
  P: TParticle;
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
var
  I: Integer;
  Item: TDecorItem;
  R: TRectF;
begin
  if FGameState <> gsPlaying then
    Exit;
  R := TRectF.Create(FPlayer.Pos.X, FPlayer.Pos.Y, FPlayer.Pos.X + FPlayer.Width, FPlayer.Pos.Y + FPlayer.Height);
  for I := FDecor.Count - 1 downto 0 do
  begin
    Item := FDecor[I];
    if Item.Kind = dtCrate then
    begin
      if R.IntersectsWith(TRectF.Create(Item.Pos.X + 2, Item.Pos.Y + 2, Item.Pos.X + 30, Item.Pos.Y + 30)) then
      begin
        SpawnExplosion(Item.Pos.X + 16, Item.Pos.Y + 16, TAlphaColors.Orange);
        FDecor.Delete(I);
        Inc(FScore);
        PlayEffect(afCrate);
      end;
    end;
  end;
end;

procedure TPlatformerGame.CheckGateCollision;
var
  R, R2: TRectF;
begin
  if FGameState <> gsPlaying then
    Exit;
  R := TRectF.Create(FPlayer.Pos.X, FPlayer.Pos.Y, FPlayer.Pos.X + FPlayer.Width, FPlayer.Pos.Y + FPlayer.Height);
  R2 := TRectF.Create(FGate.Pos.X, FGate.Pos.Y, FGate.Pos.X + FGate.Width, FGate.Pos.Y + FGate.Height);
  if R.IntersectsWith(R2) then
  begin
    FGameState := gsWin;
    FWinTime := 2.0;
    SpawnExplosion(FGate.Pos.X + FGate.Width / 2, FGate.Pos.Y + FGate.Height / 2, TAlphaColors.Cyan);
    PlayEffect(afPortal);
  end;
end;

procedure TPlatformerGame.CheckEnemyCollisions;
var
  I: Integer;
  E: TEnemy;
  R, R2: TRectF;
begin
  if FGameState <> gsPlaying then
    Exit;
  R := TRectF.Create(FPlayer.Pos.X, FPlayer.Pos.Y, FPlayer.Pos.X + FPlayer.Width, FPlayer.Pos.Y + FPlayer.Height);
  for I := FEnemies.Count - 1 downto 0 do
  begin
    E := FEnemies[I];
    R2 := TRectF.Create(E.Pos.X, E.Pos.Y, E.Pos.X + E.Width, E.Pos.Y + E.Height);
    if R.IntersectsWith(R2) then
    begin
      SpawnExplosion((R.Left + R.Right) / 2, (R.Top + R.Bottom) / 2, TAlphaColors.Red);
      FEnemies.Delete(I);
      FGameState := gsDead;
      FDeadTime := 1.5;
      FPlayer.Pos.X := -1000;
      FPlayer.Vel.X := 0;
      FPlayer.Vel.Y := 0;
      FScore := 0;
      PlayEffect(afDie);
      Exit;
    end;
  end;
end;

procedure TPlatformerGame.UpdateEnemies(DeltaSec: Double);
var
  I: Integer;
  E: TEnemy;
  FloorLevel: Integer;
begin
  FloorLevel := FMapRows - 4;
  for I := FEnemies.Count - 1 downto 0 do
  begin
    E := FEnemies[I];
    E.Pos.X := E.Pos.X + E.Vel.X * DeltaSec;
    E.Phase := E.Phase + DeltaSec * 5;
    E.Pos.Y := E.Pos.Y + 15 * DeltaSec;
    if IsSolidTile(FTiles, FMapCols, FMapRows, E.Pos.X + E.Width / 2, E.Pos.Y + E.Height) then
    begin
      E.Pos.Y := Trunc((E.Pos.Y + E.Height) / TILE_SIZE) * TILE_SIZE - E.Height;
      if IsSolidTile(FTiles, FMapCols, FMapRows, E.Pos.X + E.Width / 2 + Sign(E.Vel.X) * 10, E.Pos.Y + E.Height / 2) then
        E.Vel.X := -E.Vel.X;
    end;
    if E.Pos.Y > (FloorLevel * TILE_SIZE + 100) then
    begin
      SpawnExplosion(E.Pos.X + E.Width / 2, E.Pos.Y, TAlphaColors.Purple);
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
  Center, SpawnPos: TPointF;
begin
  Center := PointF(FPlayer.Pos.X + FPlayer.Width / 2, FPlayer.Pos.Y + FPlayer.Height);
  if (FPlayer.State = bsGround) and (Abs(FPlayer.Vel.X) > 0.5) then
  begin
    if Random(5) = 0 then
    begin
      P.Pos := Center + PointF(0, FPlayer.Height / 2 - 29);
      P.Vel := PointF(-FPlayer.Vel.X * 0.5, -5 - Random * 5);
      P.Life := 0.6;
      P.Color := TAlphaColors.White;
      P.Size := 3 + Random * 2;
      FParticles.Add(P);
    end;
  end;
  if Random(10) = 0 then
  begin
    SpawnPos := PointF(FPlayer.Pos.X + Random(Trunc(Width)) - Width / 2, Random(FMapRows * TILE_SIZE));
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
  AccelThisFrame, NextY, FloorLevel, OldVelX: Single;
begin
  if not FActive or FMenuActive then
    Exit;

  if FGameState = gsWin then
  begin
    FWinTime := FWinTime - DeltaSec;
    UpdateParticles(DeltaSec);
    FGate.Phase := FGate.Phase + DeltaSec * 20;
    if FWinTime <= 0 then
    begin
      Inc(FLevel);
      GenerateProceduralMap;
      GenerateBackgroundElements;
    end;
    Exit;
  end;

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

  FloorLevel := FMapRows - 4;
  FLock.Acquire;
  try
    Left := Byte(vkLeft) in FKeys;
    Right := Byte(vkRight) in FKeys;
    Jump := Byte(vkUp) in FKeys;
  finally
    FLock.Release;
  end;

  OldVelX := FPlayer.Vel.X;
  AccelThisFrame := ACCEL * DeltaSec;
  if Left then
    FPlayer.Vel.X := Max(FPlayer.Vel.X - AccelThisFrame, -MAX_SPEED)
  else if Right then
    FPlayer.Vel.X := Min(FPlayer.Vel.X + AccelThisFrame, MAX_SPEED)
  else
  begin
    FPlayer.Vel.X := FPlayer.Vel.X * 0.85;
    if Abs(FPlayer.Vel.X) < 0.1 then
      FPlayer.Vel.X := 0;
  end;

  FBraking := (Abs(FPlayer.Vel.X) > 0.5) and (((FPlayer.Vel.X > 0) and Left) or ((FPlayer.Vel.X < 0) and Right));

  if Jump and (FPlayer.State = bsGround) then
  begin
    FPlayer.Vel.Y := JUMP_FORCE;
    FPlayer.State := bsAir;
    PlayEffect(afJump);
  end;

  if FPlayer.State = bsAir then
    FPlayer.Vel.Y := FPlayer.Vel.Y + GRAVITY * DeltaSec;

  FPlayer.Pos.X := FPlayer.Pos.X + FPlayer.Vel.X * TILE_SIZE * DeltaSec;
  if FPlayer.Pos.X < 0 then
    FPlayer.Pos.X := 0;
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

  if FPlayer.Pos.Y > (FloorLevel * TILE_SIZE + 50) then
  begin
    SpawnExplosion(FPlayer.Pos.X + FPlayer.Width / 2, FPlayer.Pos.Y, TAlphaColors.Red);
    FGameState := gsDead;
    FDeadTime := 1.5;
    FPlayer.Pos.X := -1000;
    FPlayer.Vel.X := 0;
    FPlayer.Vel.Y := 0;
    FScore := 0;
    PlayEffect(afDie);
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
var
  Font: TSkFont;
  Paint: ISkPaint;
  Txt: string;
begin
  Txt := 'Crates: ' + IntToStr(FScore) + ' | Level: ' + IntToStr(FLevel);
  if FUseCatAvatar then
    Txt := Txt + ' [CAT]';

  // Style Name anzeigen
  case FVisualMode of
    0:
      Txt := Txt + ' [STD]';
    1:
      Txt := Txt + ' [SCIFI]';
    2:
      Txt := Txt + ' [CUPHEAD]';
  end;
  Txt := Txt + ' [V:' + IntToStr(FVisualMode) + ']';

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
  ParallaxX1, ParallaxX2, ParallaxX3: Single;
  CloudX, CloudY, BushX, TreeBaseY, MtnX, MtnBaseY, MtnPeakY, MtnWidth, TreeSize, MtnSeed, TreeSeed: Single;
  BushColor, MtnColor: TAlphaColor;
  PB: ISkPathBuilder;
begin
  case (FLevel mod 4) of
    0:
      Colors := [$FF0f0c29, $FF302b63, $FF24243e];
    1:
      Colors := [$FF87CEEB, $FFADD8E6, $FFF0F8FF];
    2:
      Colors := [$FFFF7F50, $FFFD5E53, $FF4B0082];
    3:
      Colors := [$FF2F4F4F, $FF008080, $FF20B2AA];
  else
    Colors := [$FF0f0c29, $FF302b63, $FF24243e];
  end;
  Paint := TSkPaint.Create;
  Paint.Shader := TSkShader.MakeGradientLinear(PointF(0, 0), PointF(0, ADest.Height), Colors, nil, TSkTileMode.Clamp);
  ACanvas.DrawPaint(Paint);
  Paint.Shader := nil;

  ParallaxX1 := -FCameraX * 0.05;
  ParallaxX2 := -FCameraX * 0.1;
  ParallaxX3 := -FCameraX * 0.4;
  Paint.AntiAlias := True;

  // --- 2. MOUNTAINS (Procedural Rock Structure) ---
  // Draws mountains with deterministic rock lines and cracks instead of snow.
  PB := TSkPathBuilder.Create;
  Paint.Style := TSkPaintStyle.Fill;
  if (FLevel mod 4) = 0 then
    MtnColor := $FF050510
  else
    MtnColor := $FF1a1a2e;

  for I := 0 to High(FBgMountains) do
  begin
    MtnX := FBgMountains[I].X + ParallaxX1;
    MtnSeed := FBgMountains[I].Y;
    MtnBaseY := ADest.Height;
    MtnPeakY := MtnBaseY - (MtnSeed * 4.0);
    MtnWidth := MtnSeed * 5.0;
    if MtnX < -MtnWidth then
      MtnX := MtnX + (FMapCols * TILE_SIZE * 2);
    if MtnX > Width + MtnWidth then
      Continue;

    // Draw base mountain triangle
    PB.Reset;
    PB.MoveTo(MtnX - MtnWidth / 2, MtnBaseY);
    PB.LineTo(MtnX + MtnWidth / 2, MtnBaseY);
    PB.LineTo(MtnX, MtnPeakY);
    Paint.Color := MtnColor;
    ACanvas.DrawPath(PB.Snapshot, Paint);

    // Deterministic random based on seed (prevents flickering)
    var RockLines := Trunc(Frac(MtnSeed * 3.1) * 3) + 2;

    // Draw bright diagonal rock lines
    Paint.Color := $FFFFFFFF;
    Paint.Alpha := 25;
    Paint.Style := TSkPaintStyle.Stroke;
    Paint.StrokeWidth := 1.5;
    var LPeakOff := MtnPeakY + (MtnSeed * 0.8);
    ACanvas.DrawLine(PointF(MtnX, LPeakOff), PointF(MtnX + (MtnWidth / RockLines), MtnBaseY), Paint);
    ACanvas.DrawLine(PointF(MtnX, LPeakOff), PointF(MtnX - (MtnWidth / RockLines), MtnBaseY), Paint);

    // Draw dark horizontal cracks
    Paint.Color := $FF000000;
    Paint.Alpha := 50;
    var LRandY1 := MtnBaseY - (MtnSeed * 1.5);
    var LRandY2 := MtnBaseY - (MtnSeed * 2.5);
    ACanvas.DrawLine(PointF(MtnX - MtnWidth / 4, LRandY1), PointF(MtnX + MtnWidth / 4, LRandY1), Paint);
    ACanvas.DrawLine(PointF(MtnX - MtnWidth / 6, LRandY2), PointF(MtnX + MtnWidth / 6, LRandY2), Paint);

    Paint.Style := TSkPaintStyle.Fill;
    Paint.Alpha := 255;
  end;

  Paint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Normal, 20.0);
  for I := 0 to High(FBgClouds) do
  begin
    CloudX := FBgClouds[I].X + ParallaxX2;
    CloudY := FBgClouds[I].Y;
    if CloudX < -200 then
      CloudX := CloudX + (FMapCols * TILE_SIZE * 2);
    if CloudX > Width + 200 then
      Continue;
    if (FLevel mod 4) = 0 then
      Paint.Color := $FF3d3d5c
    else
      Paint.Color := $FFFFFFFF;
    Paint.Alpha := 100;
    ACanvas.DrawCircle(PointF(CloudX, CloudY), 60, Paint);
  end;

  // --- 4. TREES (Procedural Leaf Structure) ---
  // Draws trees with deterministic leaf clusters instead of flat circles.
  Paint.MaskFilter := nil;
  case (FLevel mod 4) of
    0:
      BushColor := $FF0a0a15;
    1:
      BushColor := $FF006400;
    2:
      BushColor := $FF8B0000;
    3:
      BushColor := $FF004040;
  else
    BushColor := $FF0a0a15;
  end;

  for I := 0 to High(FBgBushes) do
  begin
    BushX := FBgBushes[I].X + ParallaxX3;
    TreeSeed := FBgBushes[I].Y;
    TreeSize := TreeSeed * 1.2;
    TreeBaseY := ADest.Height;
    if BushX < -TreeSize * 2 then
      BushX := BushX + (FMapCols * TILE_SIZE * 2);
    if BushX > Width + TreeSize * 2 then
      Continue;

    // Stable color variation
    if Frac(TreeSeed * 1.3) > 0.5 then
      Paint.Color := $FF228B22
    else
      Paint.Color := BushColor;

    Paint.Style := TSkPaintStyle.Fill;

    // Draw main canopy
    ACanvas.DrawCircle(PointF(BushX, TreeBaseY - TreeSize), TreeSize, Paint);
    var LeftSize := TreeSize * (0.5 + Frac(TreeSeed * 2.1) * 0.3);
    ACanvas.DrawCircle(PointF(BushX - TreeSize * 0.6, TreeBaseY - TreeSize * 0.8), LeftSize, Paint);
    var RightSize := TreeSize * (0.5 + Frac(TreeSeed * 3.7) * 0.3);
    ACanvas.DrawCircle(PointF(BushX + TreeSize * 0.6, TreeBaseY - TreeSize * 0.85), RightSize, Paint);

    if Frac(TreeSeed * 4.9) > 0.6 then
    begin
      var TopSize := TreeSize * 0.4;
      ACanvas.DrawCircle(PointF(BushX, TreeBaseY - TreeSize * 1.5), TopSize, Paint);
    end;

    // Draw leaf structure (highlights and shadows)
    Paint.Color := $FFFFFFFF;
    Paint.Alpha := 30;
    ACanvas.DrawCircle(PointF(BushX - TreeSize * 0.2, TreeBaseY - TreeSize * 1.2), TreeSize * 0.3, Paint);
    ACanvas.DrawCircle(PointF(BushX + TreeSize * 0.3, TreeBaseY - TreeSize * 0.9), TreeSize * 0.2, Paint);

    Paint.Color := $FF000000;
    Paint.Alpha := 30;
    ACanvas.DrawCircle(PointF(BushX + TreeSize * 0.1, TreeBaseY - TreeSize * 0.6), TreeSize * 0.4, Paint);
    Paint.Alpha := 255;
  end;
end;

procedure TPlatformerGame.DrawTileMap(const ACanvas: ISkCanvas);
var
  Paint, OutlinePaint: ISkPaint;
  TileRect: TRectF;
  C, R: Integer;
  VariantX: Single;
begin
  Paint := TSkPaint.Create(TSkPaintStyle.Fill);
  Paint.AntiAlias := True;

  OutlinePaint := TSkPaint.Create(TSkPaintStyle.Stroke);
  OutlinePaint.StrokeWidth := 1.0;
  OutlinePaint.AntiAlias := True;
  OutlinePaint.Color := $AA000000; // Semi-transparent black outline

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
              if Assigned(FGrassShader) then
              begin
                ACanvas.Save;
                try
                  ACanvas.ClipRect(TileRect);
                  VariantX := ((C * 13 + R * 7) mod 8) * 32;
                  ACanvas.Translate(C * TILE_SIZE - VariantX, R * TILE_SIZE);
                  Paint.Shader := FGrassShader;
                  ACanvas.DrawRect(RectF(0, 0, 256, 32), Paint);
                  Paint.Shader := nil;
                finally
                  ACanvas.Restore;
                end;
              end
              else
              begin
                Paint.Color := TAlphaColors.Darkgreen;
                ACanvas.DrawRect(TileRect, Paint);
              end;
              ACanvas.DrawRect(TileRect, OutlinePaint);
            end;

          ttGround:
            begin
              if Assigned(FDirtShader) then
              begin
                ACanvas.Save;
                try
                  ACanvas.ClipRect(TileRect);
                  VariantX := ((C * 13 + R * 7) mod 8) * 32;
                  ACanvas.Translate(C * TILE_SIZE - VariantX, R * TILE_SIZE);
                  Paint.Shader := FDirtShader;
                  ACanvas.DrawRect(RectF(0, 0, 256, 32), Paint);
                  Paint.Shader := nil;
                finally
                  ACanvas.Restore;
                end;
              end
              else
              begin
                Paint.Color := TAlphaColors.Brown;
                ACanvas.DrawRect(TileRect, Paint);
              end;
              ACanvas.DrawRect(TileRect, OutlinePaint);
            end;
          ttStone:
            begin
              if Assigned(FStoneShader) then
              begin
                ACanvas.Save;
                try
                  ACanvas.ClipRect(TileRect);
                  VariantX := ((C * 17 + R * 11) mod 8) * 32;
                  ACanvas.Translate(C * TILE_SIZE - VariantX, R * TILE_SIZE);
                  Paint.Shader := FStoneShader;
                  ACanvas.DrawRect(RectF(0, 0, 256, 32), Paint);
                  Paint.Shader := nil;
                finally
                  ACanvas.Restore;
                end;
              end
              else
              begin
                Paint.Color := $FF3d3d5c;
                ACanvas.DrawRect(TileRect, Paint);
              end;
              ACanvas.DrawRect(TileRect, OutlinePaint);
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
var
  Paint: ISkPaint;
  Center: TPointF;
  PhaseOffset: Single;
  PathBuilder: ISkPathBuilder;
  I: Integer;
  Angle, Radius: Single;
begin
  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;
  Center := PointF(FGate.Pos.X + FGate.Width / 2, FGate.Pos.Y + FGate.Height / 2);
  ACanvas.Save;
  ACanvas.SaveLayer(TSkPaint.Create);
  try
    Paint.Style := TSkPaintStyle.Fill;
    Paint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 25.0);
    if Sin(FGate.Phase * 2) > 0 then
      Paint.Color := $FF00FFFF
    else
      Paint.Color := $FFFF00FF;
    Paint.Alpha := 180;
    PhaseOffset := Sin(FGate.Phase) * 0.2;
    ACanvas.Save;
    ACanvas.Translate(Center.X, Center.Y);
    ACanvas.Scale(1.0 + PhaseOffset, 1.0 - PhaseOffset);
    ACanvas.DrawOval(TRectF.Create(-45, -70, 45, 70), Paint);
    ACanvas.Restore;
    Paint.Style := TSkPaintStyle.Fill;
    Paint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Normal, 10.0);
    Paint.Color := $FF050510;
    ACanvas.DrawOval(TRectF.Create(Center.X - 25, Center.Y - 45, Center.X + 25, Center.Y + 45), Paint);
    Paint.Style := TSkPaintStyle.Stroke;
    Paint.StrokeWidth := 2;
    Paint.Color := $FFFFFFFF;
    Paint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 3.0);
    PathBuilder := TSkPathBuilder.Create;
    PathBuilder.MoveTo(Center.X, Center.Y);
    for I := 0 to 20 do
    begin
      Angle := FGate.Phase * 5 + (I * 0.5);
      Radius := I * 3.0;
      PathBuilder.LineTo(Center.X + Cos(Angle) * Radius, Center.Y + Sin(Angle) * Radius * 1.5);
    end;
    ACanvas.DrawPath(PathBuilder.Snapshot, Paint);
  finally
    ACanvas.Restore;
    ACanvas.Restore;
  end;
end;

procedure TPlatformerGame.DrawMenu(const ACanvas: ISkCanvas; const ADest: TRectF);
var
  Paint: ISkPaint;
  Font: TSkFont;
  Rect: TRectF;
  CenterX, CenterY: Single;
begin
  Paint := TSkPaint.Create;
  Paint.Color := $AA000000;
  ACanvas.DrawPaint(Paint);
  CenterX := ADest.Width / 2;
  CenterY := ADest.Height / 2;
  Rect := TRectF.Create(CenterX - 150, CenterY - 100, CenterX + 150, CenterY + 200);
  Paint.Color := $FF333344;
  Paint.AntiAlias := True;
  ACanvas.DrawRoundRect(Rect, 20, 20, Paint);
  Paint.Style := TSkPaintStyle.Stroke;
  Paint.StrokeWidth := 3;
  Paint.Color := $FFFFFFFF;
  ACanvas.DrawRoundRect(Rect, 20, 20, Paint);
  Font := TSkFont.Create;
  try
    Paint := TSkPaint.Create(TSkPaintStyle.Fill);
    Paint.AntiAlias := True;
    Paint.Color := TAlphaColors.White;
    ACanvas.DrawSimpleText('PAUSED', CenterX - 70, CenterY - 50, Font, Paint);
    Paint.Color := TAlphaColors.Yellow;
    ACanvas.DrawSimpleText('ESC - Resume', CenterX - 65, CenterY + 10, Font, Paint);
    ACanvas.DrawSimpleText('R - Reset Level', CenterX - 65, CenterY + 40, Font, Paint);
    ACanvas.DrawSimpleText('C - Toggle Cat', CenterX - 65, CenterY + 70, Font, Paint);
    ACanvas.DrawSimpleText('V - Visual Style', CenterX - 65, CenterY + 100, Font, Paint);
  finally
    Font.Free;
  end;
end;

procedure TPlatformerGame.DrawEnemies(const ACanvas: ISkCanvas);
var
  E: TEnemy;
  Paint, GlowPaint: ISkPaint;
  Center: TPointF;
  Offset: Single;
begin
  Paint := TSkPaint.Create(TSkPaintStyle.Fill);
  Paint.AntiAlias := True;
  GlowPaint := TSkPaint.Create(Paint);
  GlowPaint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 6.0);
  GlowPaint.Color := TAlphaColors.Purple;
  for E in FEnemies do
  begin
    Center := PointF(E.Pos.X + E.Width / 2, E.Pos.Y + E.Height / 2);
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
var
  P: TParticle;
  Paint: ISkPaint;
  AlphaVal: Integer;
begin
  if FParticles.Count = 0 then
    Exit;
  Paint := TSkPaint.Create(TSkPaintStyle.Fill);
  Paint.AntiAlias := True;
  Paint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 3.0);
  for P in FParticles do
  begin
    Paint.Color := P.Color;
    AlphaVal := Round(P.Life * 180);
    if AlphaVal > 255 then
      AlphaVal := 255;
    if AlphaVal < 0 then
      AlphaVal := 0;
    Paint.Alpha := AlphaVal;
    ACanvas.DrawCircle(P.Pos, P.Size * P.Life, Paint);
  end;
end;

procedure TPlatformerGame.DrawAliveAvatar(const ACanvas: ISkCanvas; const Center: TPointF; const Scale: Single; const VelX: Single);
var
  Paint, GlowPaint: ISkPaint;
  HeadPos, NeckPos, HipPos, FootL, FootR, HandL, HandR: TPointF;
  HeadRadius, BodyHeight, Sway, Breathe: Single;
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
  Paint.Color := $FF202020;
  GlowPaint := TSkPaint.Create(Paint);
  GlowPaint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 8.0);
  GlowPaint.Color := $FF00ffff;

  if VelX < -0.1 then
    LookDir := -1
  else
    LookDir := 1;
  YOffset := 3.0 * Scale + 3.0;

  if FPlayer.State = bsGround then
  begin
    if Abs(VelX) > 0.1 then
    begin
      CurrentPhase := FAnimPhase * 8;
      Breathe := Sin(CurrentPhase) * 2.0 * Scale;
      Sway := 0;
    end
    else
    begin
      CurrentPhase := 0;
      Breathe := 0;
      Sway := 0;
    end;
  end
  else
  begin
    // IN AIR: No running animation, only slight gravity swing movement
    CurrentPhase := 0;
    Breathe := Sin(FAnimPhase * 3) * 1.5 * Scale;
    Sway := Sin(FAnimPhase) * 3.0 * Scale;
  end;

  HeadRadius := 7.0 * Scale;
  BodyHeight := 24.0 * Scale;
  HeadPos := PointF(Center.X + Sway, Center.Y + Breathe + YOffset);
  NeckPos := PointF(Center.X + Sway, Center.Y + Breathe + HeadRadius + YOffset);
  HipPos := PointF(Center.X + (Sway * 0.5), Center.Y + Breathe + HeadRadius + BodyHeight + YOffset);

  if FPlayer.State = bsAir then
  begin
    // JUMP POSE: Legs bent, arms up/back
    FootL := PointF(HipPos.X - 8 * Scale, HipPos.Y + 8 * Scale);
    FootR := PointF(HipPos.X + 8 * Scale, HipPos.Y + 12 * Scale);
    HandL := PointF(NeckPos.X - 12 * Scale, NeckPos.Y - 5 * Scale);
    HandR := PointF(NeckPos.X + 12 * Scale, NeckPos.Y - 5 * Scale);
  end
  else if Abs(VelX) > 0.1 then
  begin
    // Walk on ground
    FootL := PointF(HipPos.X - 5 * Scale + Sin(CurrentPhase) * 4 * Scale, HipPos.Y + 14 * Scale);
    FootR := PointF(HipPos.X + 5 * Scale - Sin(CurrentPhase) * 4 * Scale, HipPos.Y + 14 * Scale);
    HandL := PointF(NeckPos.X - 9 * Scale, NeckPos.Y + 12 * Scale + Sin(CurrentPhase) * 2 * Scale);
    HandR := PointF(NeckPos.X + 9 * Scale, NeckPos.Y + 12 * Scale - Sin(CurrentPhase) * 2 * Scale);
  end
  else
  begin
    // Stand on ground
    FootL := PointF(HipPos.X - 5 * Scale, HipPos.Y + 14 * Scale);
    FootR := PointF(HipPos.X + 5 * Scale, HipPos.Y + 14 * Scale);
    HandL := PointF(NeckPos.X - 9 * Scale, NeckPos.Y + 12 * Scale);
    HandR := PointF(NeckPos.X + 9 * Scale, NeckPos.Y + 12 * Scale);
  end;

  PB := TSkPathBuilder.Create;
  PB.MoveTo(HipPos.X, HipPos.Y);
  PB.LineTo(FootL.X, FootL.Y);
  PB.MoveTo(HipPos.X, HipPos.Y);
  PB.LineTo(FootR.X, FootR.Y);
  PB.MoveTo(NeckPos.X, NeckPos.Y);
  PB.LineTo(HandL.X, HandL.Y);
  PB.MoveTo(NeckPos.X, NeckPos.Y);
  PB.LineTo(HandR.X, HandR.Y);
  PB.MoveTo(NeckPos.X, NeckPos.Y);
  PB.LineTo(HipPos.X, HipPos.Y);
  ACanvas.DrawPath(PB.Snapshot, GlowPaint);
  ACanvas.DrawPath(PB.Snapshot, Paint);

  Paint.Style := TSkPaintStyle.Fill;
  ACanvas.DrawCircle(HeadPos, HeadRadius, GlowPaint);
  ACanvas.DrawCircle(HeadPos, HeadRadius, Paint);

  Paint.Color := TAlphaColors.White;
  Paint.MaskFilter := nil;
  var EyeL := PointF(HeadPos.X + (3 * Scale * LookDir), HeadPos.Y - 2 * Scale);
  var EyeR := PointF(HeadPos.X + (7 * Scale * LookDir), HeadPos.Y - 2 * Scale);
  ACanvas.DrawCircle(EyeL, 2.2 * Scale, Paint);
  ACanvas.DrawCircle(EyeR, 2.2 * Scale, Paint);
end;

procedure TPlatformerGame.DrawCatAvatar(const ACanvas: ISkCanvas; const Center: TPointF; const Scale: Single; const VelX: Single);
var
  Paint, GlowPaint: ISkPaint;
  BodyRect, HeadRect: TRectF;
  TailWag, RunPhase: Single;
  TailStart, TailMid, TailEnd: TPointF;
  PB: ISkPathBuilder;
begin
  Paint := TSkPaint.Create;
  Paint.Style := TSkPaintStyle.Fill;
  Paint.AntiAlias := True;
  Paint.Color := $FF333333;
  GlowPaint := TSkPaint.Create(Paint);
  GlowPaint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 6.0);
  GlowPaint.Color := $FF00FFFF;

  if not FBraking then
  begin
    if VelX < -0.5 then
      FLookDir := -1
    else if VelX > 0.5 then
      FLookDir := 1;
  end;
  if FLookDir = 0 then
    FLookDir := 1;

  var BodyDrop := 16.0;
  var HeadLift := -10.0;

  // Calculate run phase ONLY if we are on the ground!
  if (FPlayer.State = bsGround) and (Abs(VelX) > 0.5) then
    RunPhase := FAnimPhase * 10
  else
    RunPhase := 0; // In air or standing: No leg movement

  if FCrouching then
    BodyRect := TRectF.Create(Center.X - 20, Center.Y + BodyDrop + 10, Center.X + 20, Center.Y + BodyDrop + 28)
  else
  begin
    if Abs(VelX) > 0.5 then
      BodyRect := TRectF.Create(Center.X - 18, Center.Y + BodyDrop, Center.X + 18, Center.Y + BodyDrop + 18)
    else
      BodyRect := TRectF.Create(Center.X - 14, Center.Y + BodyDrop, Center.X + 14, Center.Y + BodyDrop + 20);
  end;
  ACanvas.DrawOval(BodyRect, GlowPaint);
  ACanvas.DrawOval(BodyRect, Paint);

  // Legs
  Paint.Style := TSkPaintStyle.Stroke;
  Paint.StrokeWidth := 3.0 * Scale;
  Paint.StrokeCap := TSkStrokeCap.Round;

  if FPlayer.State = bsAir then
  begin
    // JUMP POSE: Legs tucked under the body
    ACanvas.DrawLine(PointF(BodyRect.Left + 6, BodyRect.Bottom), PointF(BodyRect.Left + 4, BodyRect.Bottom + 4), Paint);
    ACanvas.DrawLine(PointF(BodyRect.Left + 12, BodyRect.Bottom), PointF(BodyRect.Left + 10, BodyRect.Bottom + 4), Paint);
    ACanvas.DrawLine(PointF(BodyRect.Right - 6, BodyRect.Bottom), PointF(BodyRect.Right - 4, BodyRect.Bottom + 4), Paint);
    ACanvas.DrawLine(PointF(BodyRect.Right - 12, BodyRect.Bottom), PointF(BodyRect.Right - 10, BodyRect.Bottom + 4), Paint);
  end
  else if (Abs(VelX) > 0.5) and not FCrouching then
  begin
    // Running animation
    var LegOffset := Sin(RunPhase) * 5.0;
    ACanvas.DrawLine(PointF(BodyRect.Left + 4, BodyRect.Bottom), PointF(BodyRect.Left + 4 + LegOffset, BodyRect.Bottom + 8), Paint);
    ACanvas.DrawLine(PointF(BodyRect.Left + 8, BodyRect.Bottom), PointF(BodyRect.Left + 8 - LegOffset, BodyRect.Bottom + 8), Paint);
    ACanvas.DrawLine(PointF(BodyRect.Right - 4, BodyRect.Bottom), PointF(BodyRect.Right - 4 + LegOffset, BodyRect.Bottom + 8), Paint);
    ACanvas.DrawLine(PointF(BodyRect.Right - 8, BodyRect.Bottom), PointF(BodyRect.Right - 8 - LegOffset, BodyRect.Bottom + 8), Paint);
  end
  else if not FCrouching then
  begin
    // Standing pose
    ACanvas.DrawLine(PointF(BodyRect.Left + 4, BodyRect.Bottom), PointF(BodyRect.Left + 4, BodyRect.Bottom + 8), Paint);
    ACanvas.DrawLine(PointF(BodyRect.Left + 8, BodyRect.Bottom), PointF(BodyRect.Left + 8, BodyRect.Bottom + 8), Paint);
    ACanvas.DrawLine(PointF(BodyRect.Right - 4, BodyRect.Bottom), PointF(BodyRect.Right - 4, BodyRect.Bottom + 8), Paint);
    ACanvas.DrawLine(PointF(BodyRect.Right - 8, BodyRect.Bottom), PointF(BodyRect.Right - 8, BodyRect.Bottom + 8), Paint);
  end
  else
  begin
    // Crouching pose
    ACanvas.DrawLine(PointF(BodyRect.Left + 4, BodyRect.Bottom - 2), PointF(BodyRect.Left + 2, BodyRect.Bottom + 2), Paint);
    ACanvas.DrawLine(PointF(BodyRect.Right - 4, BodyRect.Bottom - 2), PointF(BodyRect.Right - 2, BodyRect.Bottom + 2), Paint);
  end;

  // Head & Details
  Paint.Style := TSkPaintStyle.Fill;
  var HeadXOffset := FLookDir * 10;
  if Abs(VelX) > 0.5 then
    HeadXOffset := FLookDir * 15;
  HeadRect := TRectF.Create(Center.X - 10 + HeadXOffset, Center.Y + BodyDrop + HeadLift - 5, Center.X + 10 + HeadXOffset, Center.Y + BodyDrop + HeadLift + 15);
  ACanvas.DrawOval(HeadRect, GlowPaint);
  ACanvas.DrawOval(HeadRect, Paint);

  PB := TSkPathBuilder.Create;
  PB.MoveTo(HeadRect.Left + 2, HeadRect.Top + 5);
  PB.LineTo(HeadRect.Left + 6, HeadRect.Top - 8);
  PB.LineTo(HeadRect.Left + 10, HeadRect.Top + 5);
  PB.MoveTo(HeadRect.Right - 10, HeadRect.Top + 5);
  PB.LineTo(HeadRect.Right - 6, HeadRect.Top - 8);
  PB.LineTo(HeadRect.Right - 2, HeadRect.Top + 5);
  ACanvas.DrawPath(PB.Snapshot, Paint);

  TailWag := Sin(FAnimPhase * 6) * 5.0;
  Paint.Style := TSkPaintStyle.Stroke;
  Paint.StrokeWidth := 3.0 * Scale;
  Paint.Color := $FF333333;
  TailStart := PointF(BodyRect.CenterPoint.X - (FLookDir * 15), BodyRect.CenterPoint.Y);
  TailMid := PointF(TailStart.X - (FLookDir * 15), Center.Y + BodyDrop + TailWag);
  TailEnd := PointF(TailMid.X - (FLookDir * 5), Center.Y + BodyDrop - 15 + TailWag);
  PB := TSkPathBuilder.Create;
  PB.MoveTo(TailStart.X, TailStart.Y);
  PB.QuadTo(TailMid.X, TailMid.Y, TailEnd.X, TailEnd.Y);
  ACanvas.DrawPath(PB.Snapshot, Paint);

  Paint.Style := TSkPaintStyle.Fill;
  Paint.Color := TAlphaColors.Yellow;
  var EyeShift := FLookDir * 2;
  ACanvas.DrawCircle(PointF(HeadRect.CenterPoint.X - 3 + EyeShift, HeadRect.CenterPoint.Y), 3, Paint);
  ACanvas.DrawCircle(PointF(HeadRect.CenterPoint.X + 3 + EyeShift, HeadRect.CenterPoint.Y), 3, Paint);
  Paint.Color := TAlphaColors.Black;
  ACanvas.DrawOval(TRectF.Create(HeadRect.CenterPoint.X - 4 + EyeShift, HeadRect.CenterPoint.Y - 1.5, HeadRect.CenterPoint.X - 2 + EyeShift, HeadRect.CenterPoint.Y + 1.5), Paint);
  ACanvas.DrawOval(TRectF.Create(HeadRect.CenterPoint.X + 2 + EyeShift, HeadRect.CenterPoint.Y - 1.5, HeadRect.CenterPoint.X + 4 + EyeShift, HeadRect.CenterPoint.Y + 1.5), Paint);
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
      if FUseCatAvatar then
        PlayerCenter.Y := PlayerCenter.Y + 10.0;
      if FUseCatAvatar then
        DrawCatAvatar(ACanvas, PlayerCenter, 1.0, FPlayer.Vel.X)
      else
        DrawAliveAvatar(ACanvas, PlayerCenter, 1.0, FPlayer.Vel.X);
    end;
    FGate.Phase := FGate.Phase + 0.05;
  finally
    FLock.Release;
    ACanvas.Restore;
  end;
  DrawUI(ACanvas);
  if FMenuActive then
    DrawMenu(ACanvas, ADest);

  if FMenuActive then
    DrawMenu(ACanvas, ADest);

  if FMenuActive then
    DrawMenu(ACanvas, ADest);

  // CUPHEAD VINTAGE FILTER
  if (FVisualMode = 2) and Assigned(FGrainShader) then
  begin
    var LPaint: ISkPaint := TSkPaint.Create(TSkPaintStyle.Fill);
    LPaint.SetAntiAlias(True);

    // 1. Sepia
    LPaint.SetColor($55FFD700);
    ACanvas.DrawRect(ADest, LPaint);

    // 2. Noise
    LPaint.SetShader(FGrainShader);
    ACanvas.DrawRect(ADest, LPaint);
    LPaint.SetShader(nil);

    // 3. Vignette
    LPaint.SetShader(TSkShader.MakeGradientRadial(ADest.CenterPoint, ADest.Width * 0.7, [$00000000, $00000000, $99000000], [0, 0.7, 1], TSkTileMode.Clamp));
    ACanvas.DrawRect(ADest, LPaint);
  end;
end;

{ =============================================================================
  LIFECYCLE
============================================================================= }
procedure TPlatformerGame.SafeInvalidate;
begin
  if csDestroying in ComponentState then
    Exit;
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
  if Assigned(FThread) then
    Exit;
  FThread := TThread.CreateAnonymousThread(
    procedure
    var
      LastTime, NowTime, DeltaMS: Cardinal;
    begin
      LastTime := TThread.GetTickCount;
      while not TThread.CheckTerminated do
      begin
        NowTime := TThread.GetTickCount;
        DeltaMS := NowTime - LastTime;
        if DeltaMS = 0 then
          DeltaMS := 1;
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
  FUseCatAvatar := False;
  FLookDir := 1;
  FBraking := False;
  FCrouching := False;
  FVisualMode := 0; // Standard Textures
  InitProceduralTextures;

  // Generate procedural textures BEFORE map generation!
  InitProceduralTextures;

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

procedure TPlatformerGame.PlayEffect(Effect: TAudioEffect);
var
  FileName, BasePath: string;
  Flags: Cardinal;
begin
  if Effect = afNone then
    Exit;
  BasePath := ExtractFilePath(ParamStr(0));
  case Effect of
    afJump:
      FileName := 'Game Design Sound Effects - Pavs Music\39 - Jump.wav';
    afExplosion:
      FileName := 'Game Design Sound Effects - Pavs Music\47 - Crunch.wav';
    afCrate:
      FileName := 'Game Design Sound Effects - Pavs Music\05 - Equip.wav';
    afPortal:
      FileName := 'Game Design Sound Effects - Pavs Music\12 - TingaLing.wav';
    afWin:
      FileName := 'Game Design Sound Effects - Pavs Music\34 - Useful Sound 18.wav';
    afDie:
      FileName := 'Game Design Sound Effects - Pavs Music\03 - Crush.wav';
  else
    FileName := '';
  end;
  if FileName = '' then
    Exit;
  FileName := BasePath + FileName;
  if not FileExists(FileName) then
    Exit;
  Flags := SND_ASYNC or SND_FILENAME or SND_NODEFAULT;
  PlaySound(PChar(FileName), 0, Flags);
end;

procedure TPlatformerGame.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
var
  GameKey: Byte;
begin
  if (KeyChar = 'V') or (KeyChar = 'v') then
  begin
    FVisualMode := FVisualMode + 1;
    if FVisualMode > 2 then
      FVisualMode := 0;
    InitProceduralTextures;
    Key := 0;
    KeyChar := #0;
  end;
  if (Key = vkEscape) or (KeyChar = 'M') or (KeyChar = 'm') then
  begin
    FMenuActive := not FMenuActive;
    Key := 0;
    KeyChar := #0;
    Redraw;
    Repaint;
    Exit;
  end;
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
    if (KeyChar = 'C') or (KeyChar = 'c') then
    begin
      FUseCatAvatar := not FUseCatAvatar;
      Key := 0;
      KeyChar := #0;
      Redraw;
      Repaint;
    end;
    Exit;
  end;
  if (KeyChar = 'C') or (KeyChar = 'c') then
  begin
    FUseCatAvatar := not FUseCatAvatar;
    Key := 0;
    KeyChar := #0;
    Exit;
  end;
  GameKey := 0;
  case Key of
    $25:
      GameKey := $25;
    $27:
      GameKey := $27;
    $26:
      GameKey := $26;
    $28:
      GameKey := $28;
    $20:
      GameKey := $26;
  end;
  if GameKey = 0 then
  begin
    case KeyChar of
      'A', 'a':
        GameKey := $25;
      'D', 'd':
        GameKey := $27;
      'W', 'w':
        GameKey := $26;
      'S', 's':
        GameKey := $28;
      ' ':
        GameKey := $26;
    end;
  end;
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
  if FMenuActive then
    Exit;
  GameKey := 0;
  case Key of
    $25:
      GameKey := $25;
    $27:
      GameKey := $27;
    $26:
      GameKey := $26;
    $28:
      GameKey := $28;
    $20:
      GameKey := $26;
  end;
  if GameKey = 0 then
  begin
    case KeyChar of
      'A', 'a':
        GameKey := $25;
      'D', 'd':
        GameKey := $27;
      'W', 'w':
        GameKey := $26;
      'S', 's':
        GameKey := $28;
      ' ':
        GameKey := $26;
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

