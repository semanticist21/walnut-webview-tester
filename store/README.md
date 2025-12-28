# App Store Screenshots

## Structure

```
store/
├── en/                    # English screenshots (SVG)
│   ├── 1.svg - 3.svg     # iPhone 6.9" (1320x2868)
│   └── 4.svg - 6.svg     # iPad 13" (2064x2752)
├── screenshots/           # Source mockup images
│   ├── template-{1,2,3}.png      # iPhone mockups
│   └── template-ipad-{1,2,3}.png # iPad mockups
└── screenshot-template-*.svg     # SVG templates
```

## Specs

| Device | Size | Template |
|--------|------|----------|
| iPhone 6.9" | 1320x2868 | `screenshot-template-iphone.svg` |
| iPad 13" | 2064x2752 | `screenshot-template-ipad.svg` |

## SVG to PNG

```bash
magick en/1.svg en/1.png
```

Note: `magick` may not render SVG gradients correctly. For production PNGs, use browser/Inkscape export or composite directly:

```bash
# Direct composition with magick
magick -size 1320x2868 gradient:'#E8F4FD-#D4E7F7' bg.png
magick bg.png mockup.png -gravity center -composite output.png
```

## Mockup Images

- Source: Device mockup with transparent background
- Format: PNG with alpha channel
- The mockup should include device frame + screenshot inside

## Adding New Screenshots

1. Create mockup image in `screenshots/template-*.png`
2. Encode to base64: `base64 -i input.png -o output.b64`
3. Insert into SVG template with appropriate title/description
