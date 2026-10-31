"""Original deterministic pixel artwork and synthesized audio. No external assets."""
from pathlib import Path
import math
import random
import struct
import wave
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'art'
OUT.mkdir(parents=True, exist_ok=True)
rng = random.Random(321)
INK = '#27282c'

def rect(d, xy, fill, outline=None, width=1):
    d.rectangle(tuple(map(int, xy)), fill=fill, outline=outline, width=width)

def poly(d, xy, fill, outline=INK, width=1):
    d.polygon(xy, fill=fill)
    if outline:
        d.line(xy + [xy[0]], fill=outline, width=width)

def save(im, name, scale=2):
    im.resize((im.width*scale, im.height*scale), Image.Resampling.NEAREST).save(OUT / name)

# The garage is painted in separate low-resolution pixel geometry, not cut from references.
im = Image.new('RGB', (490, 360), '#a79780')
d = ImageDraw.Draw(im)
for y in range(88, 360):
    for x in range(490):
        n = rng.choice([-5,-3,-1,0,0,0,1,3,5])
        shade = int((y-88)*.025)
        d.point((x,y), fill=(167+n-shade,150+n-shade,127+n-shade))
for _ in range(2300):
    x,y = rng.randrange(490),rng.randrange(90,360)
    c = rng.choice(['#b3a28c','#9a8974','#8f816e','#bcaa91'])
    rect(d,(x,y,x+rng.randrange(1,4),y+rng.randrange(1,2)),c)
# Expansion joints and hand-drawn cracks.
for pts in [[(0,193),(125,203),(276,194),(490,211)],[(0,299),(124,291),(300,306),(490,300)],[(136,91),(144,178),(133,221),(147,291),(140,360)],[(376,90),(361,177),(369,243),(360,301),(374,360)]]:
    d.line(pts, fill='#827868', width=1)
    d.line([(x+1,y+1) for x,y in pts], fill='#bbaa93', width=1)
for x,y in [(38,171),(250,322),(309,149),(440,253),(101,271)]:
    pts=[(x,y)]
    for _ in range(7):
        x+=rng.randrange(-8,9);y+=rng.randrange(4,12);pts.append((x,y))
    d.line(pts, fill='#716b60', width=1)
    d.line([pts[3],(pts[3][0]-11,pts[3][1]+2),(pts[3][0]-17,pts[3][1]+11)],fill='#716b60')
for _ in range(85):
    x,y=rng.randrange(490),rng.randrange(100,360)
    d.ellipse((x,y,x+rng.randrange(2,6),y+rng.randrange(1,3)),fill='#95846e')
# Sunlight from right garage door.
light=Image.new('RGBA',im.size)
ld=ImageDraw.Draw(light)
ld.polygon([(490,98),(490,230),(317,314),(224,249)],fill=(255,219,148,29))
im=Image.alpha_composite(im.convert('RGBA'),light)
d=ImageDraw.Draw(im)
# Back wall, metal rails and dark sill.
rect(d,(0,0,489,79),'#766b5c')
for x in range(0,490,37):
    rect(d,(x,0,x+34,76),'#847563')
    d.line([(x+3,0),(x+3,75)],fill='#a18d71')
rect(d,(0,77,489,89),'#45494a',INK,2)
rect(d,(0,78,489,80),'#a0a29a')
for x in range(9,490,32):
    rect(d,(x,82,x+2,84),'#a3a29a')
# Roller garage shutter.
rect(d,(153,-5,344,71),'#3e4246',INK,2)
rect(d,(158,0,339,66),'#777a7c')
for y in range(0,64,8):
    d.line([(158,y),(339,y)],fill='#555d63',width=2)
    d.line([(159,y+2),(339,y+2)],fill='#92938e')
rect(d,(156,66,341,74),'#373c40',INK,2)
rect(d,(235,62,258,67),'#a4a7a3',INK)
# Cabinet on castors.
for x in [19,100]:
    d.ellipse((x,94,x+9,102),fill='#25272b',outline=INK)
rect(d,(12,16,116,93),'#542e2d',INK,2)
rect(d,(15,17,111,88),'#b64e40')
rect(d,(17,19,109,25),'#d07558')
for y in [29,42,55,68]:
    rect(d,(20,y,106,y+10),'#8e3d36',INK)
    rect(d,(24,y+1,102,y+2),'#c36b53')
    rect(d,(55,y+2,81,y+4),'#b2ada0',INK)
rect(d,(10,10,118,16),'#3a4042',INK,2)
rect(d,(12,10,116,11),'#b2aaa0')
# Tools on pegboard.
rect(d,(16,0,115,7),'#4c3b31',INK)
for x in [127,140]:
    rect(d,(x,15,x+3,53),'#b4aca0',INK)
    d.arc((x-3,8,x+7,20),0,180,fill='#c8bba1',width=3)
# Recycling bin.
poly(d,[(414,36),(474,36),(467,113),(420,113)],'#244e68',width=2)
poly(d,[(420,43),(468,43),(462,108),(425,108)],'#397c94',None)
poly(d,[(410,26),(470,22),(479,35),(416,43)],'#33768b',width=2)
poly(d,[(416,29),(467,26),(470,31),(420,36)],'#163648',None)
for x,y,c in [(429,27,'#c75041'),(442,28,'#cbad56'),(459,25,'#52878f')]:
    rect(d,(x,y,x+6,y+7),c,INK)
poly(d,[(439,58),(444,49),(450,59),(446,58),(443,64)],'#c1d0b4',None)
poly(d,[(452,62),(460,66),(454,76),(455,70),(449,69)],'#c1d0b4',None)
poly(d,[(444,76),(434,74),(436,64),(440,70),(447,71)],'#c1d0b4',None)
# Shelves.
rect(d,(356,0,401,72),'#383f3e',INK,2)
rect(d,(360,0,397,67),'#5b5849')
for y in [23,57]:
    rect(d,(355,y,402,y+4),'#969286',INK)
rect(d,(362,31,389,54),'#647158',INK)
rect(d,(368,27,382,32),'#2d3630',INK)
rect(d,(373,39,379,43),'#c2b27c',INK)
rect(d,(364,4,371,21),'#d6b65b',INK)
rect(d,(377,8,387,21),'#557b89',INK)
# Floor props kept out of central interaction.
poly(d,[(0,271),(40,281),(39,327),(0,319)],'#6c523a',width=2)
poly(d,[(0,267),(39,278),(58,269),(21,259)],'#b68b57',width=2)
poly(d,[(40,281),(58,270),(57,315),(39,327)],'#946d43')
rect(d,(10,281,26,297),'#c0a17c')
d.line([(18,282),(18,295)],fill='#896949',width=2)
# Tire, mat, paper scraps.
d.ellipse((428,288,495,355),fill='#343534',outline=INK,width=3)
d.ellipse((442,301,482,340),fill='#67665d',outline='#1f2426',width=4)
d.ellipse((453,311,473,331),fill='#282b2c')
for i in range(12):
    a=i*math.pi/6
    x,y=461+math.cos(a)*29,321+math.sin(a)*29
    d.line([(int(x-3),int(y-3)),(int(x+3),int(y+3))],fill='#55564f',width=2)
poly(d,[(7,127),(65,130),(59,160),(0,157)],'#51514c',width=2)
for y in range(133,155,5):
    d.line([(8,y),(58,y+2)],fill='#6b6b5e')
poly(d,[(395,340),(434,336),(442,360),(401,360)],'#4c5150',width=2)
for x in range(401,437,6):
    d.line([(x,342),(x+4,359)],fill='#20292d',width=3)
for x,y in [(71,319),(397,258),(202,128)]:
    poly(d,[(x,y),(x+7,y-2),(x+9,y+3),(x+2,y+4)],'#c6bca1',None)
save(im,'garage.png')

# Five distinct silhouette frames for each can. Atlas-free independent PNGs.
palettes={'red':('#c84b3f','#ef7558','#853c39'), 'blue':('#3688ad','#69b9cf','#2d526f'), 'gold':('#d79a35','#f8d568','#966534')}
for name,(base,hi,shade) in palettes.items():
    for stage in range(5):
        im=Image.new('RGBA',(64,64));d=ImageDraw.Draw(im)
        heights=[42,35,26,16,8];h=heights[stage];top=52-h
        widths=[25,28,32,37,43];w=widths[stage];left=(64-w)//2;right=left+w
        if stage==0:
            body=[(left,top+4),(right,top+4),(right,49),(right-3,53),(left+2,53),(left-1,49)]
        else:
            body=[(left+3,top+3),(right-2,top+2),(right,top+int(h*.42)),(right-6,top+int(h*.57)),(right+1,49),(right-4,53),(left+2,53),(left-2,48),(left+5,top+int(h*.55)),(left,top+6)]
        poly(d,body,base,width=2)
        poly(d,[(left+3,top+6),(left+7,top+7),(left+8,49),(left+3,49)],hi,None)
        poly(d,[(right-7,top+6),(right-1,top+5),(right-2,49),(right-8,50)],shade,None)
        if stage<3:
            # Original diagonal cream stripe and tiny label marks, no brand logos.
            poly(d,[(left+8,top+int(h*.7)),(right-8,top+7),(right-6,top+12),(left+9,top+int(h*.85))],'#f1ddaa',None)
            for y in range(top+int(h*.65),49,4):
                d.line([(right-8,y),(right-4,y)],fill=hi)
        if stage>0:
            d.line([(left+2,top+int(h*.55)),(left+int(w*.45),top+int(h*.7)),(right-2,top+int(h*.45))],fill=INK,width=2)
            d.line([(left+4,top+int(h*.55)-2),(left+int(w*.45),top+int(h*.7)-2)],fill=hi)
        d.ellipse((left+1,top,right-1,top+8),fill='#c2c5b9',outline=INK,width=1)
        d.ellipse((left+4,top+2,right-4,top+6),fill='#5c6b6e',outline='#e2dfc6')
        d.ellipse((29,top+2,35,top+5),fill='#acb8ad',outline=INK)
        d.line([(left+2,51),(right-3,51)],fill='#d1d0b7',width=2)
        if stage==4:
            d.line([(left+3,48),(29,51),(right-3,46)],fill=hi,width=2)
        save(im,f'can_{name}_{stage}.png')
        if name=='red' and stage==0:
            save(im,'icon.png',4)

# Sneaker viewed from above; cursor hotspot is pixel (46,26) in the final image.
im=Image.new('RGBA',(46,70));d=ImageDraw.Draw(im)
poly(d,[(20,2),(28,2),(35,7),(38,17),(37,30),(35,48),(33,62),(28,67),(16,67),(10,62),(9,50),(11,34),(11,17),(14,7)],'#e5d9ba',width=2)
poly(d,[(18,6),(28,5),(33,10),(35,18),(33,31),(31,49),(30,59),(25,63),(18,62),(13,57),(13,46),(15,28),(14,17)],'#c45043',width=1)
poly(d,[(17,7),(25,5),(31,9),(33,16),(31,23),(16,21),(14,17)],'#f5e6c8')
d.line([(16,18),(20,20),(30,21),(33,18)],fill='#b4ac99')
poly(d,[(17,25),(30,26),(30,44),(16,45)],'#903b36')
for y in [27,33,39]:
    for x in [16,29]:
        d.ellipse((x-1,y-1,x+2,y+2),fill='#35373a',outline='#debfa4')
    d.line([(17,y),(29,y+5)],fill='#f3e2bc',width=2)
    d.line([(29,y),(17,y+5)],fill='#e5d8b7',width=2)
poly(d,[(16,47),(29,46),(30,57),(25,62),(18,60),(14,56)],'#323c45',width=2)
poly(d,[(18,49),(26,48),(28,55),(24,58),(18,57)],'#1d292e',None)
d.line([(12,33),(10,49),(12,61),(17,65),(28,65),(32,61)],fill='#9b9380')
save(im,'shoe.png')

im=Image.new('RGBA',(24,24));d=ImageDraw.Draw(im)
d.ellipse((3,3,21,22),fill='#94592b',outline=INK,width=2)
d.ellipse((2,1,20,20),fill='#eaa53b',outline=INK,width=1)
d.ellipse((4,3,18,18),fill='#f9d36a',outline='#a96a2b',width=1)
d.ellipse((6,5,16,16),fill='#e9aa37')
d.line([(11,6),(9,14),(13,14)],fill='#ffeb99',width=2)
d.line([(5,5),(7,3),(13,3)],fill='#fff0b2')
save(im,'coin.png')

# Small, locally synthesized metallic impact and reward sounds.
for name,freq,duration in [('hit',210,.16),('crush',130,.24),('coin',950,.28),('buy',620,.32)]:
    rate=22050; samples=[]
    rr=random.Random(11)
    for i in range(int(duration*rate)):
        t=i/rate; env=math.exp(-t*(25 if name=='hit' else 15))
        if name in ('hit','crush'):
            value=(math.sin(2*math.pi*freq*t)+.5*math.sin(2*math.pi*freq*2.73*t)+.4*rr.uniform(-1,1))*env*.2
        else:
            value=(math.sin(2*math.pi*freq*t)+.3*math.sin(2*math.pi*freq*1.5*t))*env*.2
        samples.append(struct.pack('<h',max(-32767,min(32767,int(value*32767)))))
    p=ROOT/'assets'/'audio'/f'{name}.wav';p.parent.mkdir(exist_ok=True)
    with wave.open(str(p),'wb') as w:
        w.setparams((1,2,rate,0,'NONE','not compressed'));w.writeframes(b''.join(samples))
print('Generated garage, 15 can frames, shoe, coin, icon and 4 sound effects.')
