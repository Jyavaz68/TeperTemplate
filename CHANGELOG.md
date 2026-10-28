## v1.3.6
- Fix: iPhone / iPad were wrongly detected as weak devices (Safari reports few CPU cores) and lost glass, shine and spinning rings. Apple devices are now treated as strong; the self-tuning guard still switches effects off if the page stutters
- Strong devices get a richer glass look again (stronger blur and saturation on cards and the bottom bar)
- Fix: a long username no longer pushes the logo and brand name out of the top block (the name is truncated instead)
- Debug switch: add ?teper=fx, ?teper=normal or ?teper=lite to the page link to force a tier (?teper=auto resets)

## v1.3.5
- Three automatic tiers: strong phones ("fx") get the subtle glass shine, avatar color cycle, animated brand gradient and glowing spinning rings; mid-range phones keep the spinning rings; weak phones ("lite") get no animation or blur
- The "lite" check no longer flags every phone with 6 GB RAM (browsers report them as 4 GB): only <= 2 GB, <= 4 cores or Data Saver
- Self-tuning: if the page stutters during the first seconds, effects are switched off automatically

## v1.3.4
- Top block: removed the status label under the username; the avatar dot already shows it (green / yellow / red). The status text is kept for screen readers and as the dot's tooltip

## v1.3.3
- Top block: the tagline under the brand name is hidden (more room for the username); it still shows in the page title
- Account card: shorter English labels and "—" for empty values, so numbers are no longer cut off

## v1.3.2
- Top block: profile (avatar, name, status) next to the logo on one row, with the language and theme buttons below it in the same block
- Account details and expiry date are compact again (single-line rows, no title), like the classic layout
- Help: the support block now only has one button, "ارتباط با پشتیبانی" (no title, no extra text)

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
