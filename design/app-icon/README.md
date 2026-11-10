# Kheir app icon

The flower of the day, cut from paper, with the crescent at its heart: eight
terracotta outer petals, eight blush inner petals, a navy centre holding a cream
crescent, and four paper leaves on green construction paper. Dark mode sets the
same flower on night-indigo paper with deeper petals. Built for Icon Composer
(iOS 26+) as four layers — background, outer petals, inner petals, heart — with
paper shadows baked into each layer so iOS can add depth between them.

Regenerate:
1. `python3 gen.py` writes `{background,outer,inner,heart}-{light,dark}.svg`
   (shared helpers — crescent, shadows, grain — come from `diorama_base.py`).
2. Render each SVG to a transparent 1024×1024 PNG (e.g. headless Chrome).
3. Rebuild `Kheir/Kheir.icon` from `icon.json` and those PNGs, then check with
   `ictool Kheir.icon --export-image --platform iOS --rendition Default|Dark|TintedDark|ClearLight`.

The app target uses it via `ASSETCATALOG_COMPILER_APPICON_NAME = Kheir`.
