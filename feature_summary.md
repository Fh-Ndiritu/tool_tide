# ToolTide: Projects Feature Summary

The **Projects** feature in ToolTide allows users to manage and iterate on their design concepts. It serves as a central workspace for transforming initial images into polished landscape designs using AI-powered tools.

## Key Features

### 1. Project Creation
- **New Project Workflow**: Users can start a new project from scratch by uploading an initial photo of their space (e.g., a backyard or patio).s
- **Integration**: Projects can also be created from existing `MaskRequests`, aiming to seamlessly transition from a quick request to a persistent workspace.

### 2. The Workspace (Canvas)
The project view offers a comprehensive interactive interface:
- **Central Canvas**: Displays the current state of the design.
- **Layer Management**: A sidebar (left) to view and navigate different iterations (layers) of the design. Each generation creates a new layer, preserving the history.

### 3. Masking Tools (Brushes)
Users can precisely define areas they want to change using the "Brush" tab:
- **Paint Brush**: Select / mask areas of the image to modify (e.g., paint over the grass to replace it).
- **Eraser**: Correct or refine the mask selection.
- **Brush Size**: Adjustable slider to control the precision of the tools.
- **Undo/Redo/Clear**: Standard history controls to manage masking actions.

### 4. Generation Tools
- **Smart Fix**: The primary tool for editing. Users write a text instruction (e.g., "Add a stone fire pit", "Replace grass with pavers") and generate new variations based on their mask.
- **Auto Fix**: A feature to automatically analyze the image and suggest improvements (currently in place as a recommended workflow).

## User Workflow Example
1.  **Upload**: User creates a project with a photo of their garden.
2.  **Mask**: User selects the "Brush" tool and paints over an empty lawn area.
3.  **Prompt**: User switches to "Smart Fix" and types "Install a modern wooden pergola".
4.  **Generate**: System processes the request and adds a new "Layer" with the generated pergola.
5.  **Iterate**: User can select this new layer and continue editing, or go back to the original if they want to try a different idea.
