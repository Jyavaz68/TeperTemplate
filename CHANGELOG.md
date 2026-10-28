## v1.3.1
- Fix: page stuck on grey skeletons (a leftover reference to a removed button stopped the script)
- The profile (avatar, name, status) now lives in the top block next to the logo; the duplicate profile card is gone
- "Account details" is now a half-width card next to a new "Expiry date" card, like the usage rings below
- "Support" always has a button; when no support ID is configured it opens a centered popup with the message, otherwise it opens that ID

## v1.3.0
- Lighter: removed the animated shine, hue-cycling, drop-shadow filters and moving orbs; blur reduced to 14-18px. Weak devices (<=4 GB RAM, <=4 cores or Data Saver) automatically get "lite mode": no blur, no animations
- Removed the "Quick connect" button (it was unreliable). The profile card is now the first block and the account details sit right below it
- "Support": if no support ID/link is configured the button opens a popup ("message the person you got this service from"); if one is set it opens that ID. In the Help tab the support block is now the last one
- Removed the user-side color picker. Colors are chosen by the admin in the installer: button color (14 presets or #hex) plus a separate background for the dark theme and for the light theme (presets or #hex). New flags `--bg-dark` and `--bg-light`

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
