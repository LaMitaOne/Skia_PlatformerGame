# Skia_PlatformerGame
RADStudio FMX / Skia4Delphi platformer game prototype with physics, jumping, collision, enemys, random levels, audio effects, particles &amp; animated stickman or cat... Enjoy! :D     

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/LaMitaOne/Skia_PlatformerGame)    
     
DeepWiki:    
"The entirety of the game logic, physics, and rendering is contained within SkiaPlatformer.pas.      
 This "everything-in-one-place" approach provides a high-density learning resource for technical      
 users interested in engine architecture."    
    
<img width="1606" height="591" alt="Unbenannt" src="https://github.com/user-attachments/assets/c7dd4161-659f-4ef0-ad7c-6017c9ae93e4" />


Sample Video: [https://www.youtube.com/watch?v=mePkXrbPfJg](https://youtu.be/Rjs-OW2iUtM)    
    
# Skia Platformer Game v0.6  

A feature-rich 2D platformer prototype built entirely with Skia (FMX + Skia4Delphi). What started as a 2-hour "can I do this?" challenge has evolved into a fully playable endless scroller with procedural generation, physics, audio and visual effects.    

SkiaPlatformer Preview
🎮 Gameplay Features

This isn't just a static tech demo anymore. It's a vertical slice of a platformer engine:

    Procedural Generation: Every level is randomly generated. It ensures gaps are jumpable, platforms are "mostly" reachable, and high "Sky Islands" reward exploration.
    Stargate Levels: Find the portal at the end of the map to teleport to the next level.
    Dynamic Worlds: The background changes based on the level (Day, Night, Sunset, Alien World). Trees and clouds adjust their colors to match the sky.
    Enemies: Encounter "Ghosts" that patrol platforms. Touch them, and it's game over! But watch out—they can fall into pits just like you.
    Physics & Juice: Smooth gravity, friction, and particle explosions. Crates explode with a satisfying burst when collected.
    Responsive Controls: Tight movement with friction and acceleration.
    Dynamic Visual Styles/Overlays. (natural/cyberpunk, none/paper/cuphead) 
    Procedural created textures    
    
🕹️ Controls

    Move Left: A or Left Arrow
    Move Right: D or Right Arrow
    Jump: W, Space, or Up Arrow
    Pause Menu: M or Escape
    Reset Level: R (While paused)
    Switch Avatar: C (Cat or stickman)
    Switch visual style: V  
    Switch overlay mode: F    

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
    v 0.6:     
     - Separated Textures and Post-Processing into independent systems.    
     - Added new paper style overlay     
     - 'V' now switches textures (Standard Nature vs. Cyberpunk).    
     - 'F' now switches Post-Processing Filters (None -> Paper -> Cuphead).    
   v 0.5:   
     - Visuals Overhaul, Game Feel & Dynamic Themes Update    
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
    
License

MIT License - Do whatever you want with it. Credits appreciated but not required.

Happy jumping! 🦘   

more game prototypes:
    
https://github.com/LaMitaOne/SkiaLemmings    
https://github.com/LaMitaOne/SkiaStarPatrols    
https://github.com/LaMitaOne/Skiatris    
https://github.com/LaMitaOne/Skia-A-Cats-Life    
https://github.com/LaMitaOne/Skia-RTS-Game    

