# Kheir app icon

A paper diorama: torn Maghrib-dusk sky (night indigo in dark mode), a crescent
hanging balanced on its thread with a brass knot, cut-paper stars, and torn
hills planted with paper flowers. Built for Icon Composer (iOS 26+) as three
layers — sky, moon, hills — with paper shadows baked into each layer.

Regenerate:
1. `python3 gen.py` writes `sky|moon|hills-{dusk,night}.svg`.
2. Render each SVG to a transparent 1024×1024 PNG (e.g. headless Chrome).
3. Rebuild `Kheir/Kheir.icon` with `icon.json` and those PNGs (Icon Composer,
   or the compose-app-icon tooling), then check with
   `ictool Kheir.icon --export-image --platform iOS --rendition Default|Dark|TintedDark`.

The app target uses it via `ASSETCATALOG_COMPILER_APPICON_NAME = Kheir`.
