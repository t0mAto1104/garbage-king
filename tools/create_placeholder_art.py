"""Generate ORIGINAL simple pixel art placeholder PNGs (no external assets).
Run from anywhere: python tools/create_placeholder_art.py
These are runnable MVP placeholders, not the final production art style.
"""
from PIL import Image,ImageDraw
from pathlib import Path
import random,math
OUT=Path(__file__).resolve().parent.parent/'assets'/'placeholders'
OUT.mkdir(parents=True,exist_ok=True)

palettes={
 'red':{'base':(211,64,70),'light':(255,142,132),'dark':(135,39,52)},
 'blue':{'base':(54,117,203),'light':(126,187,242),'dark':(31,58,126)},
 'gold':{'base':(238,184,58),'light':(255,223,129),'dark':(152,99,38)},
}
INK=(30,31,45);SILVER=(212,217,214);METAL=(101,118,128)

def can_sprite(kind, stage):
 p=palettes[kind]
 im=Image.new('RGBA',(96,80),(0,0,0,0));d=ImageDraw.Draw(im)
 # Same ground baseline regardless of stage. Height decreases by meaningful steps.
 heights=[41,34,26,18,9]
 widths=[56,60,64,68,70]
 h=heights[stage];w=widths[stage];cx=48;bottom=63;left=cx-w//2;right=cx+w//2;top=bottom-h
 d.ellipse((left+5,bottom+1,right+7,bottom+7),fill=(32,32,36,60))
 # Can side compressed profile, with folds for damaged shapes.
 shape=[(left+7,top+3),(right-9,top+2),(right-3,top+7),(right-3,bottom-5),(right-10,bottom),(left+5,bottom),(left+1,bottom-6),(left+3,top+10)]
 if stage>=2:
  shape=[(left+7,top+3),(right-12,top+1),(right-3,top+7),(right-6,top+h//2),(right,bottom-4),(right-10,bottom),(left+5,bottom),(left+1,top+h//2),(left+3,top+8)]
 d.polygon(shape, fill=p['base'],outline=INK,width=2)
 d.polygon([(left+6,top+8),(left+15,top+5),(left+14,bottom-6),(left+7,bottom-3)],fill=p['light'])
 d.polygon([(right-13,top+3),(right-5,top+7),(right-6,bottom-6),(right-13,bottom-1)],fill=p['dark'])
 if stage<4:
  d.ellipse((left+5,top-2,right-11,top+12),fill=INK)
  d.ellipse((left+8,top+1,right-14,top+9),fill=SILVER)
  d.ellipse((left+18,top+2,right-24,top+7),fill=METAL)
  if stage<3:
   d.line([(cx-12,top+15),(cx+9,top+17)],fill=(255,233,214),width=3)
   d.line([(cx-10,bottom-13),(cx+14,bottom-9)],fill=p['light'],width=2)
 else:
  d.line([(left+4,top+4),(right-3,top+6)],fill=SILVER,width=3)
  d.line([(left+7,bottom-3),(right-5,bottom-2)],fill=p['dark'],width=2)
 if stage>=1:
  # creases are painted geometry, not just whole sprite scaling
  for off in range(stage):
   ly=top+max(5,int(h*(off+1)/(stage+1)))
   d.line([(left+12,ly),(cx-7,ly+3),(cx+6,ly-1),(right-10,ly+2)],fill=p['dark'],width=2)
   d.line([(left+14,ly-2),(cx-5,ly+1)],fill=p['light'],width=1)
 if stage>=3:
  d.line([(left+6,top+4),(cx-1,top+1),(right-12,top+5)],fill=INK,width=2)
  d.line([(left+5,bottom-2),(cx+4,bottom-5),(right-2,bottom-2)],fill=INK,width=2)
 im.save(OUT/f'can_{kind}_{stage}.png')

for color in palettes:
 for step in range(5):
  can_sprite(color,step)

# First-person shoe cursor: shoe is the pointer, no leg; toe is near x=22, y=65.
def shoe(name,down=False):
 im=Image.new('RGBA',(80,88),(0,0,0,0));d=ImageDraw.Draw(im)
 dy=4 if down else 0
 upper=(38,64,90);light=(92,119,150);sole=(221,215,196)
 body=[(46,9+dy),(69,15+dy),(64,41+dy),(58,54+dy),(48,68+dy),(18,69+dy),(8,61+dy),(12,52+dy),(29,44+dy),(35,27+dy)]
 d.polygon(body,fill=upper,outline=INK,width=3)
 d.polygon([(45,13+dy),(61,18+dy),(55,39+dy),(46,49+dy),(32,49+dy),(37,30+dy)],fill=light)
 d.polygon([(9,61+dy),(22,68+dy),(47,67+dy),(58,56+dy),(62,61+dy),(52,78+dy),(15,78+dy),(5,69+dy)],fill=sole,outline=INK,width=3)
 # Lace bands
 for q in range(4):
  y=29+q*7+dy
  d.line([(36-q*2,y),(55-q*2,y+5)],fill=(231,230,222),width=3)
 # highlight on toe
 d.line([(13,59+dy),(21,54+dy)],fill=(242,236,218),width=2)
 # Hotspot marker is not included in art; implementation needs offset (x=18, y=69+dy).
 im.save(OUT/f'shoe_cursor_{name}.png')
shoe('idle',False);shoe('stomp',True)

im=Image.new('RGBA',(24,24),(0,0,0,0));d=ImageDraw.Draw(im)
d.ellipse((3,2,20,20),fill=INK);d.ellipse((5,4,18,18),fill=(242,183,46));d.ellipse((7,6,16,16),outline=(255,241,160),width=2);d.line((12,6,12,15),fill=(128,72,26),width=2)
im.save(OUT/'coin.png')

# Low-frequency concrete tile. Tileable enough for demo, not a photo texture.
rng=random.Random(19);im=Image.new('RGB',(128,128),(161,149,139));d=ImageDraw.Draw(im)
for j in range(190):
 x=rng.randrange(128);y=rng.randrange(128);c=rng.choice([(155,141,132),(167,154,144),(151,140,134),(176,159,146)])
 d.rectangle((x,y,x+rng.randrange(1,4),y+rng.randrange(1,3)),fill=c)
for pts in [[(3,16),(34,28),(53,49),(57,77),(73,96),(89,101)],[(100,0),(96,21),(118,39),(126,56)],[(5,115),(21,97),(30,86)]]:
 d.line(pts,fill=(124,111,104),width=1)
im.save(OUT/'concrete_tile.png')

# Automation placeholder sprites in 2D, transparent.
im=Image.new('RGBA',(136,90),(0,0,0,0));d=ImageDraw.Draw(im)
d.rectangle((5,49,130,65),fill=(69,78,90),outline=INK,width=3)
for x in range(16,128,22):
 d.ellipse((x,61,x+10,73),fill=(135,144,148),outline=INK,width=2)
d.rectangle((50,13,90,48),fill=(115,126,133),outline=INK,width=3)
d.rectangle((58,8,82,15),fill=(226,188,68),outline=INK,width=2)
d.rectangle((64,23,76,48),fill=(225,97,74))
d.rectangle((12,64,20,83),fill=(100,110,115),outline=INK,width=2)
d.rectangle((116,64,124,83),fill=(100,110,115),outline=INK,width=2)
im.save(OUT/'auto_stomper.png')

print('Generated',len(list(OUT.glob('*.png'))),'original placeholder PNG files:',OUT)
