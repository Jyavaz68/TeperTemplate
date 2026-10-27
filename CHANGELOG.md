## v1.2.0
- Fix: "Quick connect" now opens the app with the raw subscription link (e.g. `streisand://import/https://…`) instead of a percent-encoded one, which caused "invalid config" in Streisand and similar apps. The link is only URL-encoded when the app expects it as a query value (`?url={url}`)
- New "Customize colors" sheet (palette button): 14 accent presets + two custom pickers for the button gradient, and 16 background presets (dark and light) + a custom background picker. Saved on the user's device only; text and surfaces adapt automatically to light or dark backgrounds
- Support: if no support ID/link is configured, the Help tab tells the user to message the person they bought the config from; if one is set, the button opens that ID and the ID is shown
- Stronger liquid-glass look: animated color orbs behind the page, thicker blur, gradient glass borders, glossy buttons, glass sheets and dock
- Installer: numbered color menus in the terminal for the button/accent color (14 presets + custom hex) and the page background (15 presets + custom hex); new `--bg` flag. The admin's choice is the default; users can still change it from the palette button

## v1.1.0
- Default logo is now the shield icon with an animated gradient brand name (used when no logo URL is set)
- Profile photo: users can tap their avatar to set a photo (stored only on their device); avatar has a status dot and a slow hue cycle
- Thin dotted rings that spin clockwise / counter-clockwise around the data and time rings
- Very subtle glass shine pass over cards

## v1.0.0
- First release: Liquid-glass dashboard with 4-tab navigation (bottom dock on phones, side rail on desktop)
- Fully offline: inline icons and QR generator, no CDN required (Vazirmatn font loads when online)
- Persian / English with RTL/LTR switching, dark / light themes, 5 accent colors
- Branding (name, tagline, logo, support link) configured by the installer
- Installer menu: install, update (keeps branding), change branding, status, uninstall
