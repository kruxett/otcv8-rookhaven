# Affix Border Graphics

Du behöver skapa följande filer i `data/images/ui/`:

## 1. affix_border.png
En 32x32 pixel PNG med genomskinlig mitt och färgad border (2-3px tjock).

Exempel med ImageMagick:
```bash
convert -size 32x32 xc:none \
  -fill none -stroke gold -strokewidth 2 \
  -draw "rectangle 1,1 30,30" \
  affix_border.png
```

Eller använd befintlig UI-border från ditt tema och döp om den.

## 2. glow.png (optional)
En mjuk glow-effekt, 32x32 pixel med gradient från center.

## Alternativ (enklare)
Om du vill undvika att skapa nya grafiker:
- Använd en befintlig border från ditt UI-tema
- Ändra bara färgen via `image-color` i OTUI
- Exempel: Kopiera `window_border.png` ? `affix_border.png`

## Quick start
Skapa en temporär solid border för testning:
```bash
# I data/images/ui/
convert -size 32x32 xc:"rgba(255,215,0,0)" \
  -fill none -stroke "rgba(255,215,0,255)" -strokewidth 3 \
  -draw "rectangle 0,0 31,31" \
  affix_border.png
```

Detta ger en enkel gyllene ram som fungerar direkt.
