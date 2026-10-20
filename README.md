# War Game: Multi-Agent BDI Strategy Simulation

A multi-agent grand strategy simulation that couples a **Godot 4** simulation environment (acting as the physical embodiment / environment) with a **JaCaMo / Jason** BDI (Belief-Desire-Intention) multi-agent cognitive architecture (acting as the mind).

---

## Supported Nations & Port Allocation

| Nation                | Godot Node          | WebSocket Port | Agent Specification     |
| :-------------------- | :------------------ | :------------- | :---------------------- |
| **Austria-Hungary**   | `austria_hungary`   | `9080`         | `austria_hungary.asl`   |
| **Italy**             | `italy`             | `9081`         | `italy.asl`             |
| **The German Empire** | `the_german_empire` | `9082`         | `the_german_empire.asl` |
| **France**            | `france`            | `9083`         | `france.asl`            |
| **Spain**             | `spain`             | `9084`         | `spain.asl`             |
| **United Kingdom**    | `united_kingdom`    | `9085`         | `united_kingdom.asl`    |

---

## Prerequisites & Requirements

Ensure the following tools are installed on your machine before running the project:

### 1. Godot Engine 4 (v4.3 or newer, recommended: Godot 4.6.x)

- Download the standard (or .NET if preferred) 64-bit build from [godotengine.org](https://godotengine.org/download).
- Ensure the executable is accessible (optionally add it to your system `PATH` as `godot`).

### 2. Java Development Kit (JDK 21 or JDK 25)

- JaCaMo and Gradle toolchain require JDK 21+ (configured for JDK 25 in `mind/build.gradle`).
- Check your installation in terminal:
  ```bash
  java --version
  ```

### 3. Gradle (v8.5+ or v9.x)

- Required to build and launch JaCaMo.
- Check your installation in terminal:
  ```bash
  gradle --version
  ```

---

## Step-by-Step Installation & Execution Guide

> [!IMPORTANT]
> **Execution Order Matters!**
> You **MUST** always start the **Godot simulation first** so that the WebSocket servers are initialized and listening. Once Godot is running, start the **JaCaMo Mind**.

### Step 1: Clone or Open the Repository

Open a terminal in the project root directory:

```bash
cd war-game
```

### Step 2: Start the Godot Simulation (The Body)

You can launch Godot either via the **Godot Editor UI** or directly from the **Command Line**:

#### Option A: Using the Godot Editor

1. Open the Godot 4 Editor.
2. Click **Import**, navigate to the `godot/` folder within this repository, and select `project.godot`.
3. Click **Import & Edit**.
4. Press **F5** (or click the **Play** button in the top-right corner) to run the main scene (`res://scenes/game.tscn`).

#### Option B: Using the Command Line

From the repository root:

```bash
# Using the Godot CLI (replace with your Godot executable path if not in PATH):
godot --path godot scenes/game.tscn

# Or on Windows using an absolute path, for example:
& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64.exe" --path godot scenes/game.tscn
```

Once running, Godot will initialize the world map, provinces, and start the WebSocket servers on ports `9080` through `9085`.

---

### Step 3: Start the JaCaMo Mind Agents (The Mind)

Open a **second terminal** window, navigate to the `mind/` directory, and run Gradle:

```bash
cd mind
gradle run
```

Gradle will automatically:

1. Download required dependencies (JaCaMo 1.2, Java-WebSocket, org.json).
2. Compile Java bridge classes (`CountryAgent.java`, `VesnaAgent.java`, internal actions).
3. Launch `jacamo.infra.JaCaMoLauncher` with `vesna.jcm`.
4. Connect all 6 cognitive agents to their respective Godot WebSocket servers.

You will see terminal output indicating that agents have connected:

```text
[austria_hungary] Agent austria_hungary initialized and ready.
[italy] Agent italy initialized and ready.
[the_german_empire] Agent the_german_empire initialized and ready.
...
```

---

## Game Controls & Keyboard Shortcuts

When the Godot window is active:

| Input                                 | Action                                                                                                                                              |
| :------------------------------------ | :-------------------------------------------------------------------------------------------------------------------------------------------------- |
| **H**                                 | **Toggle HUD**: Show/hide the entire graphical user interface and overlays.                                                                         |
| **Left Mouse Button**                 | **Select Province**: Click on any province to view its details, buildings, morale, and garrison in the HUD. Click on background to clear selection. |
| **Middle Mouse Button (Hold & Drag)** | **Camera Pan**: Move the view across the European map.                                                                                              |
| **Mouse Wheel Up / Down**             | **Zoom In / Out**: Zoom the camera smoothly.                                                                                                        |
