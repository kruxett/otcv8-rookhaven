"""Package the PixelLab south base study without painting or scaling sprite art."""
from pathlib import Path
import hashlib
import importlib.util
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[2]
spec = importlib.util.spec_from_file_location('editable_export', REPO / 'assets/outfits/rookwarden/tools/export_editable.py')
export = importlib.util.module_from_spec(spec)
spec.loader.exec_module(export)


def main():
    source = ROOT / 'male/source/v14-approved-concept'
    target = ROOT / 'male/editable-v14-base-concept'
    target.mkdir(exist_ok=False)
    art = Image.open(source / 'base-neutral.png').convert('RGBA')
    native = Image.open(source / 'native-citizen-south.png').convert('RGBA')
    mask = Image.open(source / 'native-citizen-mask.png').convert('RGBA')
    # Mask metadata only: assign the single runestone to the detail channel.
    for xy in [(46,45),(45,46),(46,46),(47,46),(46,47)]:
        assert mask.getpixel(xy) == (255,0,0,255)
        mask.putpixel(xy, (0,0,255,255))
    channels = export.COLORS
    names = ['Helmet', 'Breastplate, bracers and hip armor', 'Legs and greaves', 'Boots and runestone']
    fixed = Image.new('RGBA', art.size)
    parts = [Image.new('RGBA', art.size) for _ in channels]
    for y in range(art.height):
        for x in range(art.width):
            color = mask.getpixel((x,y))
            if color in channels:
                parts[channels.index(color)].putpixel((x,y), art.getpixel((x,y)))
            else:
                fixed.putpixel((x,y), art.getpixel((x,y)))
    merged = fixed.copy()
    for part in parts:
        merged.alpha_composite(part)
    assert merged.tobytes() == art.tobytes()
    assert art.getchannel('A').tobytes() == native.getchannel('A').tobytes()
    layers = [('Citizen anatomy reference - hidden', native, False, False),
              ('Native face and hands - locked', fixed, True, False)]
    layers += [(name + ' - neutral paint', part, True, True) for name,part in zip(names,parts)]
    layers += [('Four-color mask - hidden', mask, False, True)]
    export.write_ase(target / 'rune-sentinel-base-south.aseprite', layers)
    export.write_ora(target / 'rune-sentinel-base-south.ora', layers, merged, 'Rune Sentinel - south base design study')
    (target / 'base-neutral.png').write_bytes((source / 'base-neutral.png').read_bytes())
    (target / 'base-review.png').write_bytes((source / 'base-review.png').read_bytes())
    mask.save(target / 'base-color-mask.png')
    fixed.save(target / 'native-fixed-skin.png')
    for name,part in zip(['helmet','torso-arms-hips','legs-greaves','boots-runestone'],parts):
        part.save(target / (name + '.png'))
    qa = json.loads((source / 'final-qa.json').read_text())
    qa['layer_merge_byte_exact'] = True
    qa['aseprite_and_openraster_layers_read_back_exact'] = True
    qa['color_channels'] = {}
    white = (0,0,0,0)
    for i,name in enumerate(names):
        selection = list(white)
        selection[i] = 95
        recolored = export.recolor(art, mask, tuple(selection))
        expected = [(x,y) for y in range(64) for x in range(64) if mask.getpixel((x,y)) == channels[i] and art.getpixel((x,y))[3]]
        changes = [(x,y) for y in range(64) for x in range(64) if art.getpixel((x,y)) != recolored.getpixel((x,y))]
        assert changes and set(changes).issubset(expected)
        qa['color_channels'][name] = {'mask_pixels':len(expected),'tint_changed_pixels':len(changes),'other_channels_and_fixed_skin_unchanged':True}
    qa['source_sha256'] = hashlib.sha256(art.tobytes()).hexdigest()
    qa['scope'] = 'One native south idle base study. No addons, other directions, walk frames or in-game tests yet. Alpha and fixed skin checks do not establish aesthetic approval.'
    (target / 'verification.json').write_text(json.dumps(qa,indent=2), encoding='utf-8')
    (target / 'README.md').write_text('''# Rune Sentinel — basutkast i sydvy\n\nKonceptet är godkänt; denna grafik inväntar godkännande. Native 64×64-canvas med den ursprungliga 32×32-figurens placering, utan skalning. Inga addons ingår.\n\nÖppna `rune-sentinel-base-south.aseprite` eller `.ora` för manuell redigering. Hjälm, torso/armar/höfter, ben och stövlar/runsten ligger på separata synliga målningslager. Ansikte och händer ligger på ett låst lager. Citizen-referensen och fyrkanalsmasken är dolda. Måla i neutralt vitt/grått; ändra färgområden separat i masklagret.\n\nMask: gult = hjälm, rött = bröstrustning/armar/höfter, grönt = ben, blått = stövlar och runsten. Masken är metadata och ska inte läggas synligt ovanpå målningen. Inga speldata har importerats för denna outfit.\n\nPixelLab-jobb: ce50fdcb-4a42-4908-bb31-10142204ff2f. Exakt PixelLab-finish: 057bad5a-2c49-4f9c-92f1-e49d16ffc498. Original, mask, referenser och målbeslut ligger i `../source/v14-approved-concept/`. Tidigare försök bevaras och är inte godkända. Nästa steg efter grafisk återkoppling: samma fastställda dräkt i övriga riktningar, därefter gångbilder och separata addons.\n''', encoding='utf-8')
    print(json.dumps({'output':str(target),'verification':qa},ensure_ascii=False))


if __name__ == '__main__':
    main()
