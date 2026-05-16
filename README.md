# Pac-Man in ARM Assembly 🕹️

A functional multiplayer implementation of Pac-Man, developed in **ARM Assembly** for the **NXP LPC2105** (ARM7TDMI-S) using **Keil uVision 5**.

## 🎮 Game Overview & Controls
The game runs via serial communication (**UART #2**). The game board is rendered and updated directly in the terminal (viewable in Keil's 'Memory 2' window). Eaten tokens are replaced by blank spaces (ASCII 32).

Characters feature a "wrap-around" mechanic: reaching a screen boundary teleports the player to the opposite side.

| Player | Icon | Up | Down | Left | Right |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Player 1** | `@` | `W` | `S` | `A` | `D` |
| **Player 2** | `&` | `I` | `K` | `J` | `L` |

*Controls are case-insensitive (supports both uppercase and lowercase ASCII).*

## 📁 Project Structure
* **prac5.s**: Main engine. Handles movement logic, collision detection, and screen wrapping.
* **rand.s**: Subroutine for pseudo-random ghost AI behavior.
* **Startup.s**: System boot, stack initialization, and interrupt vectors.
* **practica5.pdf**: Full technical documentation and terminology.

## 🛠️ Hardware & Environment
* **MCU:** NXP LPC2105 (ARM7)
* **IDE:** Keil uVision 5 (Requires Legacy Support for ARM7)
* **Interface:** UART #2 (Serial Terminal)

## 🚀 How to Run
1. Open `prac5.uvprojx` in Keil uVision 5.
2. Build the project.
3. Start the debugger and open the **UART #2** window (and 'Memory 2' for the board view).
4. Use the keys defined above to play.
5. (Optional) Download the pre-compiled `prac5.axf` from [Releases](../../releases).

## 🧠 Technical Highlights
* **Continuous Movement:** Once a direction key is pressed, the character moves automatically until hitting a wall.
* **Screen Wrapping:** Logic implemented to handle coordinate overflow/underflow at screen boundaries.
* **Direct Memory Mapping:** Video and I/O handled via direct access to LPC2105 GPIO and memory registers.
* **Bare-Metal:** 100% Assembly. No high-level libraries or OS.

---
*Developed as a technical practice in low-level Assembly programming.*