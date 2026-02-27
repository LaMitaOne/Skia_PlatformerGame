# Skia_PlatformerGame
RADStudio FMX / Skia4Delphi platformer game prototype with physics, jumping, collision, enemys, random levels, particles &amp; animated stickman or cat... Enjoy! :D     
   
<img width="1606" height="587" alt="Unbenannt" src="https://github.com/user-attachments/assets/bd8b234b-9ba6-4699-8ed9-0cc2e6b8a620" />


Sample Video: https://www.youtube.com/watch?v=mePkXrbPfJg    
    
# Skia Platformer Game v0.3  

A feature-rich 2D platformer prototype built entirely with Skia (FMX + Skia4Delphi). What started as a 2-hour "can I do this?" challenge has evolved into a fully playable endless scroller with procedural generation, physics, and visual effects. A nice base to start with, its all easy to see how it works in only one file.    

SkiaPlatformer Preview
🎮 Gameplay Features

This isn't just a static tech demo anymore. It's a vertical slice of a platformer engine:

    Procedural Generation: Every level is randomly generated. It ensures gaps are jumpable, platforms are "mostly" reachable, and high "Sky Islands" reward exploration.
    Stargate Levels: Find the portal at the end of the map to teleport to the next level.
    Dynamic Worlds: The background changes based on the level (Day, Night, Sunset, Alien World). Trees and clouds adjust their colors to match the sky.
    Enemies: Encounter "Ghosts" that patrol platforms. Touch them, and it's game over! But watch out—they can fall into pits just like you.
    Physics & Juice: Smooth gravity, friction, and particle explosions. Crates explode with a satisfying burst when collected.
    Responsive Controls: Tight movement with friction and acceleration.

🕹️ Controls

    Move Left: A or Left Arrow
    Move Right: D or Right Arrow
    Jump: W, Space, or Up Arrow
    Pause Menu: M or Escape
    Reset Level: R (While paused)
    Switch Avatar: C (Cat or stickman)

🛠️ Technical Details

    Renderer: Pure Skia Canvas (No Game Engine, no FMX shapes).
    Threading: Physics runs on a background thread for consistent FPS, synchronized with the main rendering thread.
    Animations: Procedural "sine-wave" animations for the stickman (swaying, breathing, running legs).
    Effects: Heavy use of TSkMaskFilter for glowing platforms, blurry clouds, and neon UI.

📦 What's Inside

    SkiaPlatformer.pas: The complete game engine in a single file.
    Sample project and executable included.

🚀 Getting Started

    Open the project in RAD Studio (Delphi).
    Ensure you have the Skia4Delphi library installed.
    Run and play!

 ----Latest Changes    
   v 0.3:    
     - Added cat avatar -> Toggle between "Organic" and "Cat" avatars by pressing 'C'.    
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
    
License

MIT License - Do whatever you want with it. Credits appreciated but not required.

Happy jumping! 🦘
