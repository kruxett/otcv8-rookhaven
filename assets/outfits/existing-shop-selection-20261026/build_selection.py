"""Build a selection board from verified existing native outfit previews."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import xml.etree.ElementTree as ET
import json,hashlib,sys
REPO=Path(__file__).resolve().parents[3]
CACHE=REPO/'assets/outfits/reference-review-20261026'
OUT=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    cached=json.loads((CACHE/'rookhaven-index.json').read_text())
    source=REPO.parent/'Rookhaven/data/XML/outfits.xml'
    rows=[o.attrib for o in ET.parse(source).getroot() if o.get('enabled')=='yes']
    assert sha(REPO/'data/things/860/Tibia.dat')==cached['dat_sha256']
    assert sha(REPO/'data/things/860/Tibia.spr')==cached['spr_sha256']
    for row in rows:assert any(all(r.get(k)==v for k,v in row.items()) for r in cached['items'])
    males=[r for r in rows if r['type']=='1'];females=[r for r in rows if r['type']=='0']
    normalize=lambda n:n.replace('Noblewoman','Nobleman').replace('Norsewoman','Norseman')
    pairs=[]
    for m in males:
        f=next(f for f in females if normalize(f['name'])==m['name'])
        pairs.append((m,f))
    assert len(pairs)==24 and len(rows)==48
    font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',14)
    bold=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',15)
    small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',12)
    def board(phase):
        canvas=Image.new('RGB',(1056,1040),'#24272b');draw=ImageDraw.Draw(canvas)
        draw.text((12,8),'Rookhaven · 24 befintliga outfits',font=bold,fill='white')
        draw.text((12,31),'Male till vänster, female till höger · båda addons där de finns · exempelfärger',font=font,fill='#bfc5cd')
        for i,(m,f) in enumerate(pairs):
            x=i%4*264;y=i//4*164+55
            name=m['name'] if m['name']==f['name'] else m['name']+' / '+f['name']
            draw.text((x+8,y+4),name,font=bold,fill=('#e4bd73' if m['name'] in ['Warmaster','Nightmare','Yalaharian'] else 'white'))
            for sex,row in enumerate([m,f]):
                folder=CACHE/'rookhaven'/f"{row['looktype']}-{row['type']}"
                im=Image.open(folder/f'south-{phase}-full.png').convert('RGBA')
                assert im.width<=64 and im.height<=64
                slot=Image.new('RGBA',(64,64))
                slot.paste(im,(64-im.width,64-im.height))
                im=slot.resize((128,128),Image.Resampling.NEAREST)
                canvas.paste(im,(x+sex*132,y+28),im)
        return canvas
    board(0).save(OUT/'all24-male-female.png')
    frames=[board(i) for i in [1,2]]
    frames[0].save(OUT/'all24-male-female-walking.gif',save_all=True,append_images=frames[1:],duration=220,loop=0,disposal=2)
    data={'status':'Existing outfit selection only; no selection approved or shop change made.','families':24,'variants':48,
        'server_xml_sha256':sha(source),'dat_sha256':cached['dat_sha256'],'spr_sha256':cached['spr_sha256'],
        'rendering':'Previously extracted native frame PNGs verified against current local DAT/SPR and all current enabled server definitions; nearest2x scaling only. Existing player-color example retained.',
        'pairs':[{'family':m['name'],'male':m,'female':f} for m,f in pairs],
        'not_automatically_unlocked_families':[m['name'] for m,f in pairs if m['unlocked']=='no'],
        'access_note':'XML unlocked=no means not automatically unlocked. Quest or script acquisition was not audited for this selection overview.'}
    (OUT/'inventory.json').write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(json.dumps({'families':24,'variants':48,'board':str(OUT/'all24-male-female.png'),'animated_board':str(OUT/'all24-male-female-walking.gif'),'all_current_source_hashes_match':True}))
if __name__=='__main__':main()

