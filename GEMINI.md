# Gemini Project: Innominatam

This file provides a comprehensive overview of the Innominatam project, a turn-based RPG developed with the Godot Engine. It is intended to be a living document, updated as the project evolves.

## Project Overview

Innominatam is a 2D turn-based role-playing game. The project is built with Godot 4 and uses GDScript for its logic. Based on the file structure and scripts, the game features a party system, inventory management, a skill system, and a turn-based combat system. The project name, "Innominatam," is specified in the `project.godot` file.

### Core Technologies

*   **Engine:** Godot 4
*   **Language:** GDScript

### Key Features

*   **Turn-Based Combat:** The game uses a turn-based combat system, likely managed by the `TurnityManager` autoloaded script.
*   **Party System:** Players can manage a party of characters, each with unique stats and skills, as defined in `PartyManager.gd`.
*   **Inventory Management:** The game features an inventory system for managing items, handled by `InventoryManager.gd`.
*   **Skill System:** Characters can learn and use skills, which are defined in `Skills.gd`.
*   **Save/Load System:** The game has a save and load system, as indicated by the `SaveManager.gd` autoload.

## Building and Running

To run the project, you will need to have the Godot Engine (version 4.4 or later) installed.

1.  **Open the Godot Editor:** Launch the Godot Engine editor.
2.  **Import the Project:** Use the "Import" button to open the project. Select the `project.godot` file in the root directory.
3.  **Run the Project:** Once the project is open, you can run it by pressing the "Play" button (or F5).

## Development Conventions

The project follows standard Godot conventions. GDScript is used for all game logic. The code is organized into scenes and scripts, with a clear separation of concerns.

### Autoloaded Scripts

The project makes extensive use of Godot's autoload feature to manage global state and systems. The following scripts and scenes are loaded automatically:

*   `Debug`: For debugging purposes.
*   `Enemies`: Manages enemy data.
*   `Skills`: Defines the game's skills.
*   `TurnityManager`: Manages the turn-based combat system.
*   `BattleTransition`: Handles the transition to battle scenes.
*   `DialogManager`: Manages in-game dialog.
*   `SoundManager`: Manages sound and music.
*   `InventoryManager`: Manages the player's inventory.
*   `Items`: Defines the game's items.
*   `PartyManager`: Manages the player's party.
*   `InventoryUI`: The user interface for the inventory.
*   `EquipmentMenu`: The user interface for equipping items.
*   `InputManager`: Manages player input.
*   `SaveManager`: Manages saving and loading game data.
*   `WorldState`: Manages the overall state of the game world.
