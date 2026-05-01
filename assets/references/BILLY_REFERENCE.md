# Billy Reference

Use the user's provided Billy photo as the identity reference for all generated pet sprites.

## Visual Identity

- Orange tabby domestic cat.
- Large round dark eyes with a gentle alert expression.
- White chest bib extending down the front.
- White front paws.
- Orange striped forehead, cheeks, body, legs, and tail.
- Rounded cute desktop-pet proportions, but keep Billy recognizable.
- No collars, clothes, accessories, hats, props, or extra markings unless explicitly requested.

## Sprite Prompt Rules

- Preserve the same face design, fur color, stripe pattern, white chest, and white paws across every frame.
- Keep body size, head size, baseline, and center placement consistent across frames.
- For walk actions, all frames must face the requested direction only. Do not mix left-facing and right-facing frames.
- Use a perfectly flat solid `#00ff00` chroma-key background with no shadows, floor plane, gradients, labels, borders, or text.
- Generate `4x4` sheets as candidate grids. Select the best cells in playback order with `import_action_4x4.sh`.

## Local Reference Image

If the original reference image is available in the workspace, store it as:

```text
assets/references/billy-reference.png
```

Do not treat generated sprites as identity references unless the user approves them.
