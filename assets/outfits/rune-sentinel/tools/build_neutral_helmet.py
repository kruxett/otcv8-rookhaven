"""Plan neutral pixel edits from one physical crown, not four improvised shapes.

This writes construction/selection data and guarded edit requests. PixelLab applies
the artwork. Native body sprites themselves are never rescaled or regenerated.
"""
from pathlib import Path
from PIL import Image
import math,json,base64

ROOT=Path(__file__).resolve().parents[1]/'male'
SRC=ROOT/'source/v11-neutral-helmet'
DEPTH_COMPRESSION=.25
# Calibrated once against south's root/tip pixels; other directions only rotate.
PRONGS=[{'name':'left','root':[-3,1.5,-.625],'tip':[-4,.7,5.175]},
        {'name':'center','root':[0,3.5,.875],'tip':[0,2.7,7.675]},
        {'name':'right','root':[4,1.5,-1.625],'tip':[4,.7,4.175]}]
TURNS={'south':0,'east':-90,'north':180,'west':90}
CHANNELS={(255,255,0,255),(255,0,0,255),(0,255,0,255),(0,0,255,255)}
def rot(v,angle):
    c=math.cos(angle);s=math.sin(angle)
    return(v[0]*c-v[1]*s,v[0]*s+v[1]*c,v[2])
def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def cross(a,b):return(a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def norm(v):
    n=math.sqrt(sum(x*x for x in v))
    return tuple(x/n for x in v)if n else(0,0,1)
def model_faces():
    faces=[]
    for p in PRONGS:
        r=p['root'];t=p['tip'];mid=[r[j]+(t[j]-r[j])*.82 for j in range(3)];rings=[]
        for center,w,d in [(r,1,.9),(mid,.7,.6)]:
            rings.append([(center[0]-w,center[1]-d,center[2]),(center[0]+w,center[1]-d,center[2]),(center[0]+w,center[1]+d,center[2]),(center[0]-w,center[1]+d,center[2])])
        for j in range(4):
            faces.append([rings[0][j],rings[0][(j+1)%4],rings[1][(j+1)%4],rings[1][j]])
            faces.append([rings[1][j],rings[1][(j+1)%4],tuple(t)])
    for aa,bb in zip(PRONGS,PRONGS[1:]):
        a=aa['root'];b=bb['root']
        # Solid raised frontal plate, not a floating line between fins.
        faces.append([(a[0],a[1]+.4,-3.1),(b[0],b[1]+.4,-3.1),(b[0],b[1]+.4,b[2]),(a[0],a[1]+.4,a[2])])
        faces.append([(a[0],a[1]-.4,a[2]),(b[0],b[1]-.4,b[2]),(b[0],b[1]+.4,b[2]),(a[0],a[1]+.4,a[2])])
    for j in range(16):
        a=math.tau*j/16;b=math.tau*(j+1)/16
        ua,va=4.7*math.cos(a),3.8*math.sin(a)
        ub,vb=4.7*math.cos(b),3.8*math.sin(b)
        faces.append([(ua,va,-3.1),(ub,vb,-3.1),(ub,vb,-3.9),(ua,va,-3.9)])
    return faces

def build():
    rig={'front_direction':'south','prongs':PRONGS,'turns':TURNS,'solid_prong_cross_section':[2.0,1.8],
         'projection':{'x':'world_x','y':'.25*world_y-world_z','depth':'world_y+.25*world_z'},
         'construction':'One raised three-prong front plate and a closed helmet circlet. Rotated, depth resolved, then occluded by original skull.',
         'body_reference':'Actual Citizen128 native phase0 sprites, unchanged proportions.'}
    (SRC/'crown-rig-v2.json').write_text(json.dumps(rig,indent=2)+'\n')
    result={};light=norm((-.6,.2,1))
    for di,degrees in TURNS.items():
        folder=SRC/di
        native=Image.open(folder/'native-body.png').convert('RGBA')
        mask=Image.open(folder/'native-color-mask.png').convert('RGBA')
        oldstyle=Image.open(ROOT/f'editable-v10-native-costume/{di}.png').convert('RGBA')
        detail=Image.open(ROOT/f'source/v10-native-costume/{di}/native-material-detail-mask.png').convert('L')
        head={(x,y)for y in range(64)for x in range(64)if mask.getpixel((x,y))==(255,255,0,255)}
        ay=min(y for x,y in head);xs=[x for x,y in head if y<=ay+1];ax=round(sum(xs)/len(xs))
        def project(v):return(ax+v[0],ay+DEPTH_COMPRESSION*v[1]-v[2],v[1]+DEPTH_COMPRESSION*v[2])
        def skull_depth(x,y):
            if(x,y)not in head:return -1e9
            xx=x-ax;yy=y-ay;ru,rv,rz=4.7,3.8,5
            k=DEPTH_COMPRESSION
            aa=1/rv**2+k*k/rz**2;bb=2*k*(5-yy)/rz**2;cc=xx**2/ru**2+(5-yy)**2/rz**2-1
            disc=bb*bb-4*aa*cc
            if disc<0:return -1e9
            near_y=(-bb+math.sqrt(disc))/(2*aa)
            return (1+k*k)*near_y-k*yy
        zbuf={};colors={};angle=math.radians(degrees)
        def triangle(vs,shade):
            (x0,y0,z0),(x1,y1,z1),(x2,y2,z2)=vs
            den=(y1-y2)*(x0-x2)+(x2-x1)*(y0-y2)
            if abs(den)<1e-8:return
            for y in range(max(0,math.floor(min(y0,y1,y2))),min(63,math.ceil(max(y0,y1,y2)))+1):
                for x in range(max(0,math.floor(min(x0,x1,x2))),min(63,math.ceil(max(x0,x1,x2)))+1):
                    wa=((y1-y2)*(x-x2)+(x2-x1)*(y-y2))/den
                    wb=((y2-y0)*(x-x2)+(x0-x2)*(y-y2))/den;wc=1-wa-wb
                    if min(wa,wb,wc)<-.01:continue
                    depth=wa*z0+wb*z1+wc*z2
                    if depth<skull_depth(x,y)-.15:continue
                    if depth>zbuf.get((x,y),-1e9):
                        zbuf[x,y]=depth;colors[x,y]=(shade,shade,shade,255)
        for face in model_faces():
            world=[rot(v,angle)for v in face]
            normal=norm(cross(sub(world[1],world[0]),sub(world[2],world[0])))
            brightness=.35+.65*abs(sum(normal[j]*light[j]for j in range(3)))
            shade=int(round((75+165*brightness)/5)*5);vs=[project(v)for v in world]
            for j in range(1,len(vs)-1):triangle([vs[0],vs[j],vs[j+1]],shade)
        outline={}
        for x,y in colors:
            for dx,dy in [(-1,0),(1,0),(0,-1),(0,1)]:
                q=x+dx,y+dy
                if q not in colors and 0<=q[0]<64 and 0<=q[1]<64 and skull_depth(*q)<-1e8:
                    outline[q]=(12,12,12,255)
        crown={**outline,**colors};desired={};crown_pixels=[]
        for y in range(64):
            for x in range(64):
                p=x,y;n=native.getpixel(p);m=mask.getpixel(p);v=n
                if n[3] and m in CHANNELS:
                    gray=round(sum(n[:3])/3)
                    if m==(255,0,0,255) and detail.getpixel(p):
                        r,g,b,_=oldstyle.getpixel(p)
                        gray=round(gray*(.78 if r>g*1.12 and g>b*1.15 else.95))
                    v=(gray,gray,gray,n[3])
                if p in crown and (not n[3] or p in head):v=crown[p];crown_pixels.append([x,y])
                if v!=n:desired[p]=v
        pixels=[[x,y,'#'+''.join(f'{c:02x}'for c in native.getpixel((x,y))),'#'+''.join(f'{c:02x}'for c in v)]for(x,y),v in sorted(desired.items(),key=lambda q:(q[0][1],q[0][0]))]
        changes=[{'operation':'patch_pixels','layer':'image','frames':[1],'pixels':pixels,'reason':'Neutral white-gray helmet turnaround from ONE shared physical three-prong front plate and circlet. Correct depth overlap and skull occlusion; native body/face/limbs remain fixed.'}]
        (folder/'neutral-crown-v2-patch.json').write_text(json.dumps(changes,indent=2)+'\n')
        (folder/'construction-v2.json').write_text(json.dumps({'direction':di,'anchor':[ax,ay],'degrees':degrees,'crown_pixels':crown_pixels,'tip_projections':[{p['name']:project(rot(p['tip'],angle))}for p in PRONGS]},indent=2)+'\n')
        result[di]={'source':'data:image/png;base64,'+base64.b64encode((folder/'native-body.png').read_bytes()).decode(),'changes':changes}
    return result
if __name__=='__main__':print(json.dumps(build()))
