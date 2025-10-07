# Gemini Code Understanding Report

## Project Overview

This project, named "Innominatam," is a turn-based role-playing game (RPG) developed using the Godot Engine. It features a classic Active Time Battle (ATB) system, where characters and enemies act based on an individual timer. The core of the turn-based mechanics is managed by a custom Godot addon called "Turnity."

### Key Technologies & Architecture:

*   **Game Engine:** Godot Engine (version 4.4 indicated in `project.godot`)
*   **Programming Language:** GDScript
*   **Core Gameplay Loop:** The game's combat takes place in the `Scenes/battle.tscn` scene. The logic is primarily driven by `Scenes/battle.gd`, which manages the ATB gauges, character actions (attacking, defending, using skills), and the overall flow of combat.
*   **Turn Management:** The project utilizes the "Turnity" addon (`addons/turnity`) for its turn-based logic. The `TurnityManager` is an autoloaded singleton that provides a framework for managing turns, which the battle system uses to determine which character's turn it is.
*   **Character and Enemy System:**
    *   Characters and enemies are represented by `BattleActor` objects, which store their stats like HP.
    *   Player party data is initialized in `Scenes/battle.gd`.
    *   Enemy types are defined as templates in the autoloaded `Enemies` script (`Scenes/enemies.gd`).
*   **Player Controller:** Outside of combat, a state machine (`Scenes/player_state_machine.gd`, `Scenes/state.gd`, etc.) handles player movement and animations.

## Building and Running

As a Godot project, "Innominatam" is designed to be run and developed within the Godot editor.

1.  **Open the Project:** Open the Godot Engine editor.
2.  **Import Project:** If not already in your project list, use the "Import" button and navigate to the project's root folder (containing `project.godot`).
3.  **Run the Game:**
    *   The main scene is configured in `project.godot` (`run/main_scene`).
    *   Press the **"Play" button (F5)** in the top-right of the Godot editor to run the game.
    *   To run a specific scene, such as the battle scene for testing, open `Scenes/battle.tscn` and press the **"Run Current Scene" button (F6)**.

There are no command-line build or run scripts evident in the project structure.

## Development Conventions

Based on the codebase, the following conventions can be observed:

*   **Autoloaded Singletons:** Core, globally accessible systems are implemented as autoloaded singletons. These are defined in the `[autoload]` section of `project.godot` and include:
    *   `Debug`: For handling debug inputs (e.g., quit, reload).
    *   `Enemies`: A database for enemy templates.
    *   `Skills`: A database for skill definitions.
    *   `TurnityManager`: The core turn management system.
*   **Scene-Specific Logic:** Each major scene (like `battle.tscn`) has a corresponding GDScript file (`battle.gd`) attached to its root node, containing the primary logic for that scene.
*   **State Machines:** Character control outside of combat is handled by a finite state machine (FSM), with individual states defined in separate scripts (`state_idle.gd`, `state_walk.gd`).
*   **Custom Addons:** The project uses a custom addon, "Turnity," for its turn-based system. This addon is self-contained in the `addons/turnity` directory and is enabled in `project.godot`.
*   **Code Style:**
    *   GDScript code uses type hints (e.g., `variable: Type`).
    *   Nodes are frequently accessed using the `@onready` annotation to ensure they are available before use.
    *   Signals are used for communication between different parts of the application, such as UI components and the main battle logic.
