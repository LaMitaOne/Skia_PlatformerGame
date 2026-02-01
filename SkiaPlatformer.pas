{*******************************************************************************
  SkiaPlatformer
********************************************************************************
  A high-performance, thread-safe 2D platformer engine built on Skia4Delphi.
  Designed for smooth animations, particle effects, and responsive physics.

  Key Features:
  - Custom Physics Engine: Tile-based collision, gravity, friction, and inertia.
  - Multi-threaded Rendering: Physics runs on a background thread for consistent FPS.
  - "Alive" Avatar System: Organic sine-wave animations (breathing, swaying).
  - Particle System: Dynamic visual effects (Dust puffs, Velocity sparks).
  - Modern Visuals: Linear gradients, soft shadows, neon/glass aesthetics.
  - Thread-Safe Controls: Critical section locking for robust input handling.
*******************************************************************************}


{ Skia-Platformer v0.1 alpha                                                   }
{ by Lara Miriam Tamy Reschke                                                   }
{                                                                              }
{------------------------------------------------------------------------------}

{
 ----Latest Changes
   v 0.1: Initial Release
           - Implemented core AABB collision detection.
           - Added "Alive" procedural animation for avatar.
           - Integrated particle emitter system.
           - Applied advanced Skia effects (Glow, Blur, Gradients).
}


unit SkiaPlatformer;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.Math,
  System.Generics.Collections, System.UITypes, System.SyncObjs, FMX.Types,
  FMX.Controls, FMX.Forms, FMX.Skia, System.Skia;

const
  {
    GAME CONSTANTS
    These values control the "feel" of the gameplay physics.
  }
  TILE_SIZE = 32;  // The size of one grid block in pixels (32x32).
  GRAVITY = 45.0; // How fast the player falls downwards.
  ACCEL = 140.0; // How fast the player speeds up when keys are pressed.
  MAX_SPEED = 12.0; // The maximum horizontal speed (terminal velocity).
  JUMP_FORCE = -16.0; // The upward velocity applied when jumping (Negative is UP).
  FRICTION = 80.0; // How fast the player slows down when keys are released.

type
  {
    TBodyState
    Simple state machine to track if the player is touching the ground or in the air.
    This is crucial for determining if we are allowed to jump.
  }
  TBodyState = (bsGround, bsAir);

  {
    TTile
    Represents a single block in the game world.
  }
  TTile = record
    Solid: Boolean;      // If True, the player cannot walk through this block.
    IsFloating: Boolean; // Used for rendering: True = Glass/Holographic, False = Solid Ground.
  end;

  {
    TActor
    Represents the Player character.
  }
  TActor = record
    Pos: TPointF;       // Current X,Y coordinates in pixels.
    Vel: TPointF;       // Current Velocity vector (Speed X, Speed Y).
    Width: Single;      // Hitbox width.
    Height: Single;     // Hitbox height.
    State: TBodyState; // Is the player on the ground or in the air?
  end;

  {
    TParticle
    Represents a single visual effect (dust, spark).
  }
  TParticle = record
    Pos: TPointF;       // Position of the particle.
    Vel: TPointF;       // Movement direction and speed.
    Life: Single;       // 1.0 = New, 0.0 = Dead (Used for fading out).
    Color: TAlphaColor; // Color of the particle.
    Size: Single;       // Radius of the particle.
  end;

  {
    TPlatformerGame
    The main game control class. Inherits from TSkCustomControl to use Skia drawing.
  }
  TPlatformerGame = class(TSkCustomControl)
  private
    { Threading & Timing }
    FThread: TThread;       // The background physics thread.
    FActive: Boolean;         // Flag to stop the game loop.
    FLock: TCriticalSection; // Thread safety lock for shared variables.

    { Input }
    FKeys: set of Byte;      // Stores which keys are currently pressed.

    { Game World }
    FPlayer: TActor;         // The player object.
    FTiles: TArray<TTile>;   // The grid map (1D array representing 2D grid).
    FMapCols: Integer;        // Width of the map in tiles.
    FMapRows: Integer;        // Height of the map in tiles.

    { Visuals }
    FAnimPhase: Single;       // A ticker (0.0 to infinity) used for sine-wave animations (swaying/breathing).
    FParticles: TList<TParticle>; // List of active visual effects.

    { Core Game Procedures }
    procedure DoPhysicsUpdate(DeltaSec: Double); // Calculates movement and collisions.
    procedure SafeInvalidate;                 // Requests a redraw safely from the background thread.
    procedure StartThread;                    // Initializes the physics loop.
    procedure StopThread;                     // Stops the physics loop.

    { Particle System }
    procedure UpdateParticles(DeltaTime: Single); // Moves particles and creates new ones.
    procedure DrawParticles(const ACanvas: ISkCanvas);  // Renders the particle list.

    { Avatar Rendering }
    procedure DrawAliveAvatar(const ACanvas: ISkCanvas; const Center: TPointF; const Scale: Single; const VelX: Single);
  protected
    { Skia Rendering Event }
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
  =============================================================================
  This function checks if a specific pixel coordinate (AX, AY) overlaps a solid block.
  It converts world coordinates (pixels) to grid coordinates (Cols, Rows).
 ============================================================================= }

function IsSolidTile(const Tiles: TArray<TTile>; Cols, Rows: Integer; const AX, AY: Single): Boolean;
var
  Col, Row: Integer;
begin
  // Convert Pixel coordinate to Grid coordinate
  Col := Trunc(AX / TILE_SIZE);
  Row := Trunc(AY / TILE_SIZE);

  // Boundary Check: If outside the map, treat it as solid (walls/floor).
  // This prevents the player from falling out of the universe.
  if (Col < 0) or (Col >= Cols) or (Row < 0) or (Row >= Rows) then
    Exit(True);

  // Check the specific tile in the array.
  // Array Index = Row * Width + Column
  Result := Tiles[Row * Cols + Col].Solid;
end;

{ =============================================================================
  PROCEDURE: UPDATE PARTICLES
  =============================================================================
  Handles the lifecycle of visual effects (Sparks, Dust).
  1. Spawns new particles based on player state.
  2. Updates existing particle positions.
  3. Removes dead particles.
 ============================================================================= }
procedure TPlatformerGame.UpdateParticles(DeltaTime: Single);
var
  I: Integer;
  P: TParticle;
  Center: TPointF;
begin
  // Determine spawn point: Bottom-Center of the player's feet.
  Center := PointF(FPlayer.Pos.X + FPlayer.Width / 2, FPlayer.Pos.Y + FPlayer.Height);

  // --- 1. EMIT NEW PARTICLES ---

  if FPlayer.State = bsGround then
  begin
    // STATE: IDLE
    // Randomly spawn small white dust puffs.
    if Random(15) = 0 then
    begin
      P.Pos := Center + PointF((Random - 0.5) * 20, 10); // Randomize X slightly, push Y down slightly.
      P.Vel := PointF((Random - 0.5) * 10, -10 - Random * 10); // Float up slowly with random X drift.
      P.Life := 1.0;     // Full life.
      P.Color := TAlphaColors.White;
      P.Size := 1.5 + Random * 2; // Random size.
      FParticles.Add(P);
    end;
  end
  else
  begin
    // STATE: MOVING or JUMPING
    // Spawn orange sparks more frequently.
    if Random(3) = 0 then
    begin
      P.Pos := Center;
      P.Vel := PointF((Random - 0.5) * 30, (Random - 0.5) * 30); // Explode outward.
      P.Life := 1.0;
      P.Color := TAlphaColors.Orange;
      P.Size := 2 + Random * 2;
      FParticles.Add(P);
    end;
  end;

  // --- 2. UPDATE PHYSICS ---

  // Loop backwards through the list so we can delete items safely.
  for I := FParticles.Count - 1 downto 0 do
  begin
    P := FParticles[I];

    // Apply Velocity
    P.Pos.X := P.Pos.X + P.Vel.X * DeltaTime;
    P.Pos.Y := P.Pos.Y + P.Vel.Y * DeltaTime;

    // Fade out life
    P.Life := P.Life - (1.2 * DeltaTime);

    // Apply Gravity to particles (so dust falls back down)
    P.Vel.Y := P.Vel.Y + 20 * DeltaTime;

    // Remove dead particles
    if P.Life <= 0 then
      FParticles.Delete(I)
    else
      FParticles[I] := P; // Save updated state
  end;
end;

{ =============================================================================
  PROCEDURE: DRAW PARTICLES
  =============================================================================
  Renders the particle list to the canvas using Skia Circles.
 ============================================================================= }
procedure TPlatformerGame.DrawParticles(const ACanvas: ISkCanvas);
var
  I: Integer;
  P: TParticle;
  Paint: ISkPaint;
begin
  if FParticles.Count = 0 then
    Exit;

  Paint := TSkPaint.Create;
  Paint.Style := TSkPaintStyle.Fill;
  Paint.AntiAlias := True; // Smooth edges

  for I := 0 to FParticles.Count - 1 do
  begin
    P := FParticles[I];
    Paint.Color := P.Color;

    // Map Life (0.0 - 1.0) to Alpha (0 - 255)
    Paint.Alpha := Round(P.Life * 255);

    // Draw Circle
    ACanvas.DrawCircle(P.Pos, P.Size * P.Life, Paint);
  end;
end;

{ =============================================================================
  PROCEDURE: PHYSICS UPDATE
  =============================================================================
  The core game loop. Calculates inputs, velocity, collisions, and position.
  This runs roughly 100 times per second on a background thread.
 ============================================================================= }
procedure TPlatformerGame.DoPhysicsUpdate(DeltaSec: Double);
var
  Left, Right, Jump: Boolean;
  AccelThisFrame: Single;
  NextY: Single;
begin
  if not FActive then
    Exit;

  // 1. READ INPUT (Thread Safe)
  FLock.Acquire;
  try
    Left := Byte(vkLeft) in FKeys;
    Right := Byte(vkRight) in FKeys;
    Jump := Byte(vkUp) in FKeys;
  finally
    FLock.Release;
  end;

  // 2. HORIZONTAL MOVEMENT
  AccelThisFrame := ACCEL * DeltaSec;

  if Left then
    FPlayer.Vel.X := Max(FPlayer.Vel.X - AccelThisFrame, -MAX_SPEED)
  else if Right then
    FPlayer.Vel.X := Min(FPlayer.Vel.X + AccelThisFrame, MAX_SPEED)
  else
  begin
    // FRICTION: If no keys pressed, slow down to 0.
    if Abs(FPlayer.Vel.X) > 0.1 then
      FPlayer.Vel.X := FPlayer.Vel.X - Sign(FPlayer.Vel.X) * FRICTION * DeltaSec
    else
      FPlayer.Vel.X := 0;
  end;

  // 3. JUMPING
  if Jump and (FPlayer.State = bsGround) then
  begin
    FPlayer.Vel.Y := JUMP_FORCE; // Apply upward force
    FPlayer.State := bsAir;       // Change state to Air
  end;

  // 4. GRAVITY
  if FPlayer.State = bsAir then
    FPlayer.Vel.Y := FPlayer.Vel.Y + GRAVITY * DeltaSec;

  // 5. APPLY HORIZONTAL MOVEMENT
  FPlayer.Pos.X := FPlayer.Pos.X + FPlayer.Vel.X * TILE_SIZE * DeltaSec;

  // Screen Bounds (Clamp to map width)
  if FPlayer.Pos.X < 0 then
    FPlayer.Pos.X := 0;
  if FPlayer.Pos.X > FMapCols * TILE_SIZE - FPlayer.Width then
    FPlayer.Pos.X := FMapCols * TILE_SIZE - FPlayer.Width;

  // 6. VERTICAL COLLISION DETECTION
  // We look ahead: Where WILL we be next frame?
  NextY := FPlayer.Pos.Y + FPlayer.Vel.Y * TILE_SIZE * DeltaSec;

  // Check FEET (Ground Collision)
  // We check the center-bottom point of the player.
  if IsSolidTile(FTiles, FMapCols, FMapRows, FPlayer.Pos.X + FPlayer.Width / 2, NextY + FPlayer.Height) then
  begin
    // Landed!
    // Snap Y position exactly to the top of the tile.
    FPlayer.Pos.Y := Trunc((NextY + FPlayer.Height) / TILE_SIZE) * TILE_SIZE - FPlayer.Height;
    FPlayer.Vel.Y := 0;
    FPlayer.State := bsGround;
  end
  // Check HEAD (Ceiling Collision)
  else if IsSolidTile(FTiles, FMapCols, FMapRows, FPlayer.Pos.X + FPlayer.Width / 2, NextY) then
  begin
    // Bonked head!
    // Snap Y position exactly to the bottom of the tile.
    FPlayer.Pos.Y := (Trunc(NextY / TILE_SIZE) + 1) * TILE_SIZE;
    FPlayer.Vel.Y := 0;
  end
  else
  begin
    // Falling through air.
    FPlayer.Pos.Y := NextY;
    FPlayer.State := bsAir;

    // Respawn check: If fell off the world
    if FPlayer.Pos.Y > FMapRows * TILE_SIZE then
    begin
      FPlayer.Pos.Y := 0;
      FPlayer.Vel.Y := 0;
    end;
  end;

  // 7. UPDATE PARTICLES
  UpdateParticles(DeltaSec);
end;

{ =============================================================================
  PROCEDURE: SAFE INVALIDATE
  =============================================================================
  Triggers a redraw on the main UI thread from the background physics thread.
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
        Redraw;   // Ask Skia to redraw
        Repaint;  // Standard FMX repaint
      end;
    end);
end;

{ =============================================================================
  PROCEDURE: START THREAD
  =============================================================================
  Creates the background loop.
 ============================================================================= }
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
          // Run Physics
          DoPhysicsUpdate(DeltaMS / 1000);
          // Request Draw
          SafeInvalidate;
        end;

        Sleep(10); // Limit CPU usage (~100 FPS)
      end;
    end);
  FThread.FreeOnTerminate := True;
  FThread.Start;
end;

{ =============================================================================
  PROCEDURE: STOP THREAD
  =============================================================================
  Safely shuts down the game loop.
 ============================================================================= }
procedure TPlatformerGame.StopThread;
begin
  FActive := False;
  if Assigned(FThread) then
  begin
    FThread.Terminate;
    Sleep(50); // Give it time to exit gracefully
  end;
end;

{ =============================================================================
  CONSTRUCTOR
  =============================================================================
  Sets up the game world, inputs, and visual controls.
 ============================================================================= }
constructor TPlatformerGame.Create(AOwner: TComponent);
var
  C, R: Integer;
begin
  inherited Create(AOwner);

  // 1. SETUP CONTROL
  FLock := TCriticalSection.Create;
  Align := TAlignLayout.Client; // Fill the form
  HitTest := True;
  CanFocus := True;
  TabStop := True;

  // 2. GAME SETTINGS
  FActive := True;
  FMapCols := 50;
  FMapRows := 20;
  FParticles := TList<TParticle>.Create;
  FAnimPhase := 0;

  SetLength(FTiles, FMapCols * FMapRows);

  // 3. INITIALIZE MAP (CLEAR)
  for R := 0 to FMapRows - 1 do
    for C := 0 to FMapCols - 1 do
    begin
      FTiles[R * FMapCols + C].Solid := False;
      FTiles[R * FMapCols + C].IsFloating := False;
    end;

  // 4. CREATE GEOMETRY

  // A. Ground Floor (Solid, Opaque)
  R := 15;
  for C := 0 to FMapCols - 1 do
  begin
    FTiles[R * FMapCols + C].Solid := True;
    FTiles[R * FMapCols + C].IsFloating := False;
  end;

  // B. Floating Boxes (Glassy, Transparent)

  // Set 1: Low jumps (Left side)
  for C := 8 to 9 do
  begin
    FTiles[14 * FMapCols + C].Solid := True;
    FTiles[14 * FMapCols + C].IsFloating := True;
  end;
  for C := 20 to 22 do
  begin
    FTiles[14 * FMapCols + C].Solid := True;
    FTiles[14 * FMapCols + C].IsFloating := True;
  end;

  // Set 2: Medium height (Center)
  for C := 12 to 13 do
  begin
    FTiles[11 * FMapCols + C].Solid := True;
    FTiles[11 * FMapCols + C].IsFloating := True;
  end;
  for C := 30 to 32 do
  begin
    FTiles[11 * FMapCols + C].Solid := True;
    FTiles[11 * FMapCols + C].IsFloating := True;
  end;

  // Set 3: Right side - Very Low
  for C := 40 to 41 do
  begin
    FTiles[13 * FMapCols + C].Solid := True;
    FTiles[13 * FMapCols + C].IsFloating := True;
  end;
  for C := 45 to 46 do
  begin
    FTiles[12 * FMapCols + C].Solid := True;
    FTiles[12 * FMapCols + C].IsFloating := True;
  end;

  // 5. INITIALIZE PLAYER
  FPlayer.Width := 28;
  FPlayer.Height := 56;
  // Spawn on the ground at Row 15
  FPlayer.Pos := PointF(100, 15 * TILE_SIZE - FPlayer.Height - 1);
  FPlayer.Vel := PointF(0, 0);
  FPlayer.State := bsGround;

  // 6. START
  StartThread;
end;

{ =============================================================================
  DESTRUCTOR
  =============================================================================
  Cleanup.
 ============================================================================= }
destructor TPlatformerGame.Destroy;
begin
  StopThread;
  FreeAndNil(FLock);
  FreeAndNil(FParticles);
  inherited;
end;

{ =============================================================================
  EVENT: KEY DOWN
  =============================================================================
  Adds key to the pressed set.
 ============================================================================= }
procedure TPlatformerGame.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if Key <= 255 then
  begin
    FLock.Acquire;
    try
      Include(FKeys, Byte(Key));
    finally
      FLock.Release;
    end;
  end;
  inherited;
end;

{ =============================================================================
  EVENT: KEY UP
  =============================================================================
  Removes key from the pressed set.
 ============================================================================= }
procedure TPlatformerGame.KeyUp(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if Key <= 255 then
  begin
    FLock.Acquire;
    try
      Exclude(FKeys, Byte(Key));
    finally
      FLock.Release;
    end;
  end;
  inherited;
end;

{ =============================================================================
  PROCEDURE: DRAW ALIVE AVATAR
  =============================================================================
  Draws the stick figure using organic sine-wave math for animation.
  - 'Center': Anchor point (Top-Left of player box).
  - 'Scale': Global sizing.
  - 'VelX': Used to determine look direction (-1 Left, 1 Right).
 ============================================================================= }
procedure TPlatformerGame.DrawAliveAvatar(const ACanvas: ISkCanvas; const Center: TPointF; const Scale: Single; const VelX: Single);
var
  Paint, GlowPaint: ISkPaint;
  PathBuilder: ISkPathBuilder;
  HeadPos, NeckPos, HipPos, FootL, FootR, HandL, HandR, EyeL, EyeR: TPointF;
  HeadRadius, BodyHeight: Single;
  Sway, Breathe: Single;
  CurrentPhase: Single;
  LookDir: Single;
  YOffset: Single;
begin
  // 1. SETUP PAINTS
  Paint := TSkPaint.Create;
  Paint.Style := TSkPaintStyle.Stroke;
  Paint.StrokeWidth := 3.0 * Scale;
  Paint.StrokeCap := TSkStrokeCap.Round;
  Paint.StrokeJoin := TSkStrokeJoin.Round;
  Paint.AntiAlias := True;
  Paint.Color := TAlphaColors.Black;

  // Create a secondary paint for the "Glow" effect
  // We pass the existing paint to the constructor to copy color/style
  GlowPaint := TSkPaint.Create(Paint);
  // MaskFilter creates an outer glow
  GlowPaint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 6.0);
  // ImageFilter blurs the stroke itself (making it look soft/energetic)
  GlowPaint.ImageFilter := TSkImageFilter.MakeBlur(1.5, 1.5);

  // Determine Look Direction based on Velocity
  if VelX < -0.1 then
    LookDir := -1
  else
    LookDir := 1;

  PathBuilder := TSkPathBuilder.Create;

  // 2. ANIMATION MATH
  // Offset to lower the drawing slightly so feet align better
  YOffset := 3.0 * Scale;

  // Check State to decide animation
  if FPlayer.State = bsGround then
  begin
    // IDLE: Stop all sine wave movement. Reset phase.
    CurrentPhase := 0;
    Breathe := 0;
    Sway := 0;
  end
  else
  begin
    // AIR: Use the global animation phase for swaying/breathing
    CurrentPhase := FAnimPhase;
    // Sine wave functions create smooth organic movement
    Breathe := Sin(CurrentPhase * 3) * 1.5 * Scale;
    Sway := Sin(CurrentPhase) * 3.0 * Scale;
  end;

  // 3. CALCULATE BODY GEOMETRY
  HeadRadius := 7.0 * Scale;
  BodyHeight := 24.0 * Scale;

  // Apply offsets to base positions
  HeadPos := PointF(Center.X + Sway, Center.Y + Breathe + YOffset);
  NeckPos := PointF(Center.X + Sway, Center.Y + Breathe + HeadRadius + YOffset);
  HipPos := PointF(Center.X + (Sway * 0.5), Center.Y + Breathe + HeadRadius + BodyHeight + YOffset);

  // LIMBS: Calculate positions based on state (Idle vs Air)
  if FPlayer.State = bsAir then
  begin
    // JUMPING POSE
    FootL := PointF(HipPos.X - 5 * Scale, HipPos.Y + 8 * Scale);
    FootR := PointF(HipPos.X + 5 * Scale, HipPos.Y + 8 * Scale);
    HandL := PointF(NeckPos.X - 12 * Scale, NeckPos.Y - 2 * Scale);
    HandR := PointF(NeckPos.X + 12 * Scale, NeckPos.Y - 2 * Scale);
  end
  else
  begin
    // IDLE POSE
    FootL := PointF(HipPos.X - 7 * Scale, HipPos.Y + 16 * Scale);
    FootR := PointF(HipPos.X + 7 * Scale, HipPos.Y + 16 * Scale);
    HandL := PointF(NeckPos.X - 9 * Scale, NeckPos.Y + 12 * Scale);
    HandR := PointF(NeckPos.X + 9 * Scale, NeckPos.Y + 12 * Scale);
  end;

  // 4. BUILD PATH (CONNECT THE DOTS)
  // Legs
  PathBuilder.MoveTo(HipPos.X, HipPos.Y);
  PathBuilder.LineTo(FootL.X, FootL.Y);
  PathBuilder.MoveTo(HipPos.X, HipPos.Y);
  PathBuilder.LineTo(FootR.X, FootR.Y);

  // Arms
  PathBuilder.MoveTo(NeckPos.X, NeckPos.Y);
  PathBuilder.LineTo(HandL.X, HandL.Y);
  PathBuilder.MoveTo(NeckPos.X, NeckPos.Y);
  PathBuilder.LineTo(HandR.X, HandR.Y);

  // Torso (Spine)
  PathBuilder.MoveTo(NeckPos.X, NeckPos.Y);
  PathBuilder.LineTo(HipPos.X, HipPos.Y);

  // 5. DRAW BODY LINES WITH GLOW
  ACanvas.DrawPath(PathBuilder.Snapshot, GlowPaint);

  // 6. DRAW HEAD (Sharp, No Blur)
  Paint.Style := TSkPaintStyle.Fill;
  Paint.ImageFilter := nil; // Reset filters for crisp head
  Paint.MaskFilter := nil;
  ACanvas.DrawCircle(HeadPos, HeadRadius, Paint);

  // 7. EYES (Directional)
  Paint.Color := TAlphaColors.White;
  EyeL := PointF(HeadPos.X + (3 * Scale * LookDir), HeadPos.Y - 2 * Scale);
  EyeR := PointF(HeadPos.X + (7 * Scale * LookDir), HeadPos.Y - 2 * Scale);
  ACanvas.DrawCircle(EyeL, 2.2 * Scale, Paint);
  ACanvas.DrawCircle(EyeR, 2.2 * Scale, Paint);
end;

{ =============================================================================
  PROCEDURE: MAIN DRAW
  =============================================================================
  The main rendering pipeline called by Skia.
  1. Clear Screen.
  2. Draw Background.
  3. Draw World (Tiles).
  4. Draw Particles.
  5. Draw Player.
 ============================================================================= }
procedure TPlatformerGame.Draw(const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single);
var
  Paint, StrokePaint, ShadowPaint: ISkPaint;
  TileRect, ShadowRect: TRectF;
  C, R: Integer;
  PlayerCenter: TPointF;
  Gradient: ISkShader;
  GradientColors: TArray<TAlphaColor>;
begin
  // --- 1. BACKGROUND ---
  // Create a smooth vertical gradient (Sky Blue -> Deep Midnight Blue)
  GradientColors := [TAlphaColors.Skyblue, TAlphaColors.Midnightblue];
  Gradient := TSkShader.MakeGradientLinear(PointF(0, 0),           // Start (Top)
    PointF(0, ADest.Height), // End (Bottom)
    GradientColors,            // Colors
    nil,                      // Positions (evenly distributed)
    TSkTileMode.Clamp         // Repeat mode
  );

  Paint := TSkPaint.Create;
  Paint.Shader := Gradient;
  ACanvas.DrawPaint(Paint); // Fill whole canvas
  Paint.Shader := nil; // Reset shader for other objects

  FLock.Acquire;
  try
    // --- 2. BEAUTIFUL TILES ---
    ShadowPaint := TSkPaint.Create;
    ShadowPaint.Color := TAlphaColors.Black;
    ShadowPaint.Alpha := 80; // Semi-transparent shadow
    ShadowPaint.ImageFilter := TSkImageFilter.MakeBlur(4.0, 4.0); // Soft shadow

    Paint.Style := TSkPaintStyle.Fill;

    StrokePaint := TSkPaint.Create;
    StrokePaint.Style := TSkPaintStyle.Stroke;
    StrokePaint.Color := TAlphaColors.Lightgray;
    StrokePaint.StrokeWidth := 1.5;

    // Loop through all tiles
    for R := 0 to FMapRows - 1 do
      for C := 0 to FMapCols - 1 do
        if FTiles[R * FMapCols + C].Solid then
        begin
          // Define tile rectangle
          TileRect := TRectF.Create(C * TILE_SIZE, R * TILE_SIZE, (C + 1) * TILE_SIZE, (R + 1) * TILE_SIZE);
          // Define shadow rectangle (offset slightly down-right)
          ShadowRect := TRectF.Create(TileRect.Left + 4, TileRect.Top + 4, TileRect.Right + 4, TileRect.Bottom + 4);

          // A. Draw Shadow
          ACanvas.DrawRoundRect(ShadowRect, 6, 6, ShadowPaint);

          if FTiles[R * FMapCols + C].IsFloating then
          begin
            // FLOATING BLOCK STYLE (Glassy/Neon)
            Paint.Color := TAlphaColors.Dimgrey;
            Paint.Alpha := 200; // Slight transparency
            Paint.ImageFilter := TSkImageFilter.MakeBlur(1.0, 1.0); // Slight blur for softness

            ACanvas.DrawRoundRect(TileRect, 8, 8, Paint);

            // White Glow Border
            StrokePaint.Color := TAlphaColors.White;
            StrokePaint.Alpha := 200;
            ACanvas.DrawRoundRect(TileRect, 8, 8, StrokePaint);
          end
          else
          begin
            // GROUND BLOCK STYLE (Solid & Clean)
            Paint.Color := TAlphaColors.Dimgrey;
            Paint.Alpha := 255; // Opaque
            Paint.ImageFilter := nil; // Sharp edges

            ACanvas.DrawRoundRect(TileRect, 6, 6, Paint);

            // Subtle Gray Border
            StrokePaint.Color := TAlphaColors.Gray;
            StrokePaint.Alpha := 255;
            ACanvas.DrawRoundRect(TileRect, 6, 6, StrokePaint);
          end;
        end;

    // --- 3. PARTICLES ---
    DrawParticles(ACanvas);

    // --- 4. ALIVE AVATAR ---
    // Increment animation phase
    FAnimPhase := FAnimPhase + 0.15;

    // Calculate center of player for drawing
    PlayerCenter := PointF(FPlayer.Pos.X + FPlayer.Width / 2, FPlayer.Pos.Y);

    // Draw the character
    DrawAliveAvatar(ACanvas, PlayerCenter, 1.0, FPlayer.Vel.X);

  finally
    FLock.Release;
  end;
end;

end.

