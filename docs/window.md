# Window

The game window is 2560×1440. `project.godot` sets that viewport, a resizable window, stretch mode `canvas_items`, aspect `expand`, fractional scale, and hidpi. A Mac Retina display keeps a sharp image, and a window smaller than 2560×1440 scales the canvas down instead of clipping the panels.

Static layout stays in the scenes. The top bar is anchored across the full width. It shows the human's mana (`Mana: N (+M/turn)`) and the turn (`Turn` plus `N / 50`). The unit panel sits on the bottom left and the city panel on the bottom right. The city panel does not cover the top bar. Main menu, victory, and defeat fill the viewport and center their columns. `camera.default_zoom` is 0.72 so the hex map fills this window the way 0.36 filled the old 1280×720 window. Clicks use the canvas transform, so a resize does not change which hex is hit.
