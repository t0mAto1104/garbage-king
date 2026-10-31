"""Original light-pixel workshop art, tool cursors, junk frames and audio."""
from pathlib import Path
import math
import random
import struct
import wave
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/yard'
OUT.mkdir(parents=True,exist_ok=True)
INK='#26343a'
rng=random.Random(821)

def box(d,xy,c,edge=INK,w=1): d.rectangle(xy,fill=c,outline=edge,width=w)
def poly(d,points,c,edge=INK,w=1):
    d.polygon(points,fill=c)
    if edge: d.line(points+[points[0]],fill=edge,width=w)
def save(im,name,scale=2): im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST).save(OUT/name)

# 980x720 original workshop plate; floor remains open for the physical field.
im=Image.new('RGB',(980,720));d=ImageDraw.Draw(im)
for y in range(720):
    t=min(1,max(0,(y-200)/520))
    c=(int(149-12*t),int(153-17*t),int(139-14*t)) if y>=200 else (66,80,80)
    d.line((0,y,980,y),fill=c)
for _ in range(24000):
    x,y=rng.randrange(980),rng.randrange(207,720)
    shade=rng.choice([-9,-5,3,5,8])
    base=im.getpixel((x,y)); c=tuple(max(0,min(255,v+shade)) for v in base)
    d.rectangle((x,y,x+rng.randrange(1,4),y+rng.randrange(1,3)),fill=c)
# Rear wall and steel shutter.
box(d,(0,0,979,194),'#455557',None)
for x in range(0,980,96):
    box(d,(x,0,x+91,189),'#506263','#33464a',2)
    d.line((x+4,0,x+4,183),fill='#76827b',width=2)
box(d,(303,0,663,187),'#303e43',INK,4)
for y in range(0,183,17):
    box(d,(310,y,655,y+14),'#67756f','#3e5155',1)
    d.line((312,y+2,653,y+2),fill='#809087',width=2)
box(d,(446,164,516,174),'#34464b','#8a9889',2)
box(d,(0,188,979,208),'#26383e',INK,2)
d.line((0,191,979,191),fill='#a5b19a',width=3)
# Ceiling girders, hanging work lights.
for x in [50,686,944]:
    box(d,(x,0,x+12,202),'#273d43','#172f37',2)
    box(d,(x+3,0,x+6,190),'#6e7e76',None)
for x in [242,740]:
    d.line((x,0,x,43),fill='#23363b',width=3)
    poly(d,[(x-25,43),(x+25,43),(x+39,61),(x-39,61)],'#293c43',w=2)
    box(d,(x-31,61,x+31,65),'#eed59b','#cfbb85')
# Tool cabinet and wall board to the left of portal.
box(d,(4,76,92,191),'#823e36',INK,3)
for y in [94,117,140,163]:
    box(d,(11,y,86,y+19),'#b65c46','#583f38',2)
    box(d,(30,y+4,67,y+7),'#c3bd9c',INK)
box(d,(0,67,99,78),'#34494e',INK,2)
box(d,(105,11,245,100),'#7e6b4d','#243b40',3)
for x in range(113,243,12):
    for y in range(18,99,12): d.rectangle((x,y,x+1,y+1),fill='#4c5148')
for x,y in [(122,31),(153,21),(192,36),(220,27)]:
    box(d,(x,y,x+4,y+38),'#c4c5a9',INK)
    d.arc((x-4,y-7,x+8,y+5),0,180,fill='#c4c5a9',width=4)
# Workbench at the rear right, drawers and parts.
box(d,(710,138,960,160),'#5e756f',INK,3)
box(d,(704,130,966,140),'#c19a62',INK,3)
for x in [716,942]: box(d,(x,160,x+12,218),'#31484d',INK,2)
box(d,(802,161,914,212),'#507277',INK,2)
for y in [165,185]:
    box(d,(809,y,905,y+15),'#41606a',INK)
    box(d,(848,y+4,867,y+7),'#b7bd9b',INK)
box(d,(731,98,778,128),'#d2a04c',INK,2)
d.arc((742,86,766,105),180,360,fill=INK,width=3)
for x,c,h in [(815,'#a7463f',34),(842,'#b0ba92',44),(876,'#578ca0',28)]:
    box(d,(x,128-h,x+18,128),c,INK,2)
# Right side sorted bins.
for x,c in [(781,'#508083'),(841,'#8b975e'),(900,'#9e7650')]:
    poly(d,[(x,266),(x+52,266),(x+48,346),(x+6,346)],c,w=2)
    poly(d,[(x-3,257),(x+47,250),(x+59,264),(x+2,271)],c,w=2)
    d.line((x+18,289,x+31,289,x+26,301),fill='#c9d3b1',width=3)
# Floor joints, cracks and safety demarcation.
for points in [[(0,389),(210,410),(495,389),(980,425)],[(0,577),(240,550),(562,581),(980,562)],[(170,208),(209,406),(240,550),(258,720)],[(702,208),(681,409),(703,562),(738,720)]]:
    d.line(points,fill='#77847d',width=2)
    d.line([(x+2,y+2) for x,y in points],fill='#aab09a',width=1)
for x,y in [(81,335),(434,548),(755,414),(624,653)]:
    points=[(x,y)]
    for i in range(9):
        x+=rng.randrange(-11,12);y+=rng.randrange(6,15);points.append((x,y))
    d.line(points,fill='#65756e',width=2)
    p=points[3];d.line([p,(p[0]-17,p[1]+2),(p[0]-30,p[1]+16)],fill='#65756e')
for x in range(85,922,38):
    d.line((x,624,x+22,624),fill='#a8ab87',width=3)
# Warm light from high window, deliberately low contrast over work area.
light=Image.new('RGBA',im.size);ld=ImageDraw.Draw(light)
ld.polygon([(980,242),(980,584),(599,701),(420,534)],fill=(255,220,147,22))
im=Image.alpha_composite(im.convert('RGBA'),light);d=ImageDraw.Draw(im)
# Floor props only at the edges.
poly(d,[(0,610),(89,622),(85,703),(0,690)],'#97734d',w=3)
poly(d,[(0,603),(84,613),(115,590),(34,580)],'#bd9964',w=2)
poly(d,[(89,622),(114,600),(113,680),(85,703)],'#77624b',w=2)
box(d,(22,627,65,654),'#d1bc8a',None)
d.ellipse((861,624,981,738),fill='#2b3d3f',outline='#1d3036',width=4)
d.ellipse((884,645,957,717),fill='#78847b',outline='#1c3036',width=10)
d.ellipse((908,666,935,695),fill='#2a3e43')
im.save(OUT/'workshop.png')

def intact(kind):
    im=Image.new('RGBA',(64,64));d=ImageDraw.Draw(im)
    if kind=='paper':
        poly(d,[(15,27),(25,15),(38,18),(49,30),(44,47),(23,50),(12,40)],'#ded9b7',w=2)
        for p in [[(25,18),(23,30),(16,36)],[(25,30),(37,32),(43,46)],[(36,20),(34,29),(46,31)],[(23,47),(31,37),(23,30)]]: d.line(p,fill='#9d9f89',width=2)
        d.line((25,22,31,25),fill='#777e75',width=2)
    elif kind=='bottle':
        poly(d,[(27,6),(36,6),(37,17),(43,24),(45,48),(40,55),(23,55),(19,49),(21,24),(26,17)],'#7fae9c',w=2)
        box(d,(26,6,37,13),'#cfb66c',INK)
        box(d,(21,28,44,44),'#d9d5a3',INK)
        d.line((25,19,23,25,23,48),fill='#c4ded0',width=2)
        d.line((29,33,37,33,33,39),fill='#4b897f',width=2)
    elif kind=='keyboard':
        poly(d,[(5,22),(53,15),(60,41),(11,50)],'#52656d',w=2)
        poly(d,[(9,24),(51,19),(55,38),(14,45)],'#bac1a9')
        for row in range(3):
            for col in range(8):
                x=12+col*5+row;y=26+row*5-col//3
                box(d,(x,y,x+3,y+2),'#405961',None)
        d.line((52,15,57,7,63,7),fill=INK,width=2)
    elif kind=='fan':
        poly(d,[(21,54),(43,54),(47,59),(16,59)],'#708a86',w=2)
        box(d,(29,32,35,54),'#a4b8a6',INK)
        d.ellipse((10,3,54,43),fill='#6e8a8c',outline=INK,width=2)
        for a in [0,2.1,4.2]:
            x,y=32+math.cos(a)*10,23+math.sin(a)*9
            d.ellipse((int(x-9),int(y-5),int(x+9),int(y+5)),fill='#b9c7ae',outline='#4a686e')
        d.ellipse((27,18,37,28),fill='#cbac68',outline=INK)
        for x in [17,24,39,46]: d.line((x,9,x,36),fill='#324d57')
        for y in [12,19,27,34]: d.line((15,y,49,y),fill='#324d57')
    elif kind=='computer':
        poly(d,[(16,8),(41,5),(50,13),(50,54),(24,59),(15,51)],'#788d8c',w=2)
        poly(d,[(18,11),(40,8),(40,52),(23,56),(18,50)],'#c0c6ad')
        poly(d,[(41,8),(47,14),(47,51),(42,53)],'#4c6871')
        box(d,(23,17,36,23),'#384e58',INK)
        d.ellipse((25,30,31,36),fill='#8dccb2',outline=INK)
        for y in range(41,50,3): d.line((24,y,35,y),fill='#5b777b')
    elif kind=='washer':
        poly(d,[(9,12),(44,8),(55,17),(54,55),(18,60),(9,51)],'#8a9e96',w=2)
        poly(d,[(11,15),(43,11),(44,52),(18,57),(11,50)],'#d5d4b8')
        poly(d,[(45,12),(52,18),(52,52),(46,55)],'#5b7980')
        d.line((13,23,42,20),fill='#617c80',width=2)
        d.ellipse((16,27,39,51),fill='#3e5962',outline=INK,width=2)
        d.ellipse((20,30,36,47),fill='#6e9fa3',outline='#b0c5b3',width=2)
        d.arc((23,33,33,45),70,250,fill='#a4c7b9',width=2)
        box(d,(15,16,24,19),'#a0a47f',None)
        d.ellipse((33,13,38,18),fill='#c7a65d',outline=INK)
    return im

for kind in ['paper','bottle','keyboard','fan','computer','washer']:
    source=intact(kind)
    for stage in range(5):
        im=source.copy();d=ImageDraw.Draw(im)
        if stage:
            # Each damaged frame has a different contour plus discarded pieces.
            notch=stage*3
            d.polygon([(45,18),(64,17),(64,17+notch*2),(45-notch,24+notch)],fill=(0,0,0,0))
            d.line([(25,14),(29,27),(22,34),(35,44),(31,54)],fill=INK,width=1+stage//2)
            d.line([(29,27),(40,29),(44,38)],fill='#d8b07b',width=1)
            for i in range(stage):
                x=12+i*14
                poly(d,[(x,55),(x+6,52),(x+9,58),(x+2,60)],'#6c8789')
        if stage==4:
            flat=Image.new('RGBA',(64,64));fd=ImageDraw.Draw(flat)
            for i,c in enumerate(['#516a70','#9eae9e','#c4c2a0','#7c8b7a']):
                x=9+i*10
                poly(fd,[(x,42+i%2*4),(x+20,38),(x+28,49),(x+7,57),(x-3,52)],c)
            fd.line((15,47,32,44,48,49,29,53),fill=INK,width=2)
            im=flat
        save(im,f'{kind}_{stage}.png')

# Three tools on the same 92x140 canvas as the original sneaker.
for name in ['fist','hammer','drill']:
    im=Image.new('RGBA',(46,70));d=ImageDraw.Draw(im)
    if name=='fist':
        poly(d,[(11,17),(16,8),(29,7),(36,14),(36,31),(31,40),(30,62),(15,62),(14,39),(9,29)],'#577d86',w=2)
        box(d,(14,12,34,30),'#b9c6b0',INK,2)
        for x in [15,21,27]: box(d,(x,9,x+5,19),'#c9d0b9',INK)
        poly(d,[(10,21),(17,20),(21,30),(17,36),(11,31)],'#b6bda5')
        box(d,(17,38,28,58),'#334e5e',INK)
        box(d,(18,41,27,47),'#77c7c7',INK)
        d.line((15,59,30,59),fill='#cbad6d',width=3)
    elif name=='hammer':
        poly(d,[(18,22),(27,21),(33,60),(29,65),(23,64)],'#617a7b',w=2)
        box(d,(20,35,31,43),'#c39b53',INK)
        poly(d,[(4,9),(33,5),(41,12),(38,26),(9,30),(3,23)],'#456375',w=2)
        poly(d,[(5,11),(32,7),(36,12),(9,17)],'#bec7ae')
        poly(d,[(8,18),(36,13),(35,23),(10,27)],'#557b88')
        for x in [10,19,28]: d.line((x,17,x+3,24),fill='#d2a95e',width=3)
        box(d,(24,48,33,61),'#a45c45',INK)
    else:
        poly(d,[(23,4),(28,25),(18,25)],'#c7d5c3',w=1)
        for y in range(10,26,4): d.line((20,y,26,y+2),fill='#455f6d',width=2)
        poly(d,[(13,27),(31,26),(37,38),(35,53),(16,56),(9,47)],'#d09d4e',w=2)
        box(d,(15,29,30,34),'#94d5c9',INK)
        box(d,(17,37,35,43),'#344e5b',INK)
        poly(d,[(17,53),(30,51),(31,65),(18,67)],'#517b85',w=2)
        for y in [56,60,64]: d.line((20,y,28,y-1),fill='#273d47')
    save(im,name+'.png')

# Meaningful inventory icons.
for name in ['portal','magnet','scanner','auto']:
    im=Image.new('RGBA',(48,48));d=ImageDraw.Draw(im)
    if name=='portal':
        d.ellipse((8,3,40,43),fill='#294851',outline=INK,width=2)
        d.ellipse((12,7,36,39),fill='#357e8b',outline='#b4c4a8',width=3)
        d.ellipse((18,11,32,36),fill='#74c9c0')
        box(d,(5,40,43,45),'#6e8787',INK,2)
    elif name=='magnet':
        d.arc((7,4,40,40),0,180,fill=INK,width=12)
        d.arc((8,4,39,39),0,180,fill='#c76c53',width=8)
        box(d,(7,14,16,26),'#d2d2b2',INK)
        box(d,(31,14,40,26),'#d2d2b2',INK)
    elif name=='scanner':
        box(d,(7,8,41,37),'#4d737e',INK,2)
        box(d,(11,12,37,30),'#8bc7b6',INK)
        d.ellipse((18,15,30,27),outline='#315c68',width=2)
        d.line((24,13,24,29),fill='#315c68')
        box(d,(20,38,28,44),'#c8ad70',INK)
    else:
        box(d,(5,20,43,37),'#52727a',INK,2)
        box(d,(9,8,15,25),'#8ca59c',INK)
        box(d,(33,8,39,25),'#8ca59c',INK)
        box(d,(6,5,42,14),'#cda55c',INK,2)
        for x in [10,20,30]: d.line((x,6,x+5,13),fill=INK,width=3)
        box(d,(19,16,29,29),'#b8c5b0',INK)
        box(d,(15,28,33,32),'#354d57',INK)
    save(im,name+'.png')

# Original low-fi loop and differentiated impact / continuous motor sounds.
audio=ROOT/'assets/audio'
def wav(name,seconds,fn,loop=False):
    rate=22050
    values=(max(-32767,min(32767,int(fn(i/rate)*32767))) for i in range(int(seconds*rate)))
    with wave.open(str(audio/(name+'.wav')),'wb') as w:
        w.setparams((1,2,rate,0,'NONE','not compressed'))
        w.writeframes(b''.join(struct.pack('<h',x) for x in values))
wav('yard_hammer',.3,lambda t:(math.sin(t*2*math.pi*92)+.35*math.sin(t*2*math.pi*247))*math.exp(-t*17)*.3)
wav('yard_fist',.18,lambda t:(math.sin(t*2*math.pi*178)+.25*math.sin(t*2*math.pi*532))*math.exp(-t*27)*.23)
wav('yard_drill',1,lambda t:(math.sin(2*math.pi*110*t)+.18*math.sin(2*math.pi*660*t))*min(1,t*40)*min(1,(1-t)*40)*.12)
wav('yard_portal',.6,lambda t:math.sin(2*math.pi*(250*t+90*t*t))*math.sin(math.pi*t/.6)*.14)
bpm=92; beat=60/bpm; duration=beat*32
notes=[130.81,164.81,196,164.81,110,146.83,196,146.83]
def music(t):
    b=int(t/beat);local=t%beat
    bass=math.sin(2*math.pi*notes[(b//2)%8]*t)*math.exp(-local*10)*.13
    kick=math.sin(2*math.pi*(60*local+18*(1-math.exp(-local*30))))*math.exp(-local*28)*(.13 if b%4 in [0,2] else 0)
    hat=math.sin(2*math.pi*4200*t)*math.exp(-(t%(beat/2))*95)*.018
    pad=math.sin(2*math.pi*notes[(b//4)%8]*2*t)*.025+math.sin(2*math.pi*notes[(b//4)%8]*3*t)*.012
    return (bass+kick+hat+pad)*min(1,t*4)*min(1,(duration-t)*4)
wav('yard_music',duration,music)
print('Original yard artwork and audio generated.')
