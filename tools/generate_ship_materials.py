"""Original deterministic seamless detail maps; regenerate with Python + NumPy/Pillow."""
from pathlib import Path
import numpy as np
from PIL import Image
out = Path(__file__).resolve().parents[1] / 'assets' / 'materials'
out.mkdir(parents=True, exist_ok=True)
n = 512
y, x = np.mgrid[0:n, 0:n] / n
rng = np.random.default_rng(1703)
def save(name, a):
    Image.fromarray(np.uint8(np.clip(a, 0, 1)*255)).save(out / name, optimize=True)
# Along-grain coordinate is x. Periodic warping avoids repetition seams.
warp = y + .012*np.sin(x*2*np.pi) + .004*np.sin(x*6*np.pi + y*2*np.pi)
wood = .69 + .12*np.sin(warp*2*np.pi*49) + .055*np.sin(warp*2*np.pi*103)
wood += .05*np.sin(y*2*np.pi*7 + .8*np.sin(x*2*np.pi*2))
wood += .02*np.sin(x*2*np.pi*64+y*2*np.pi*37)
# Sparse darker pores, also periodic.
wood -= .13*np.maximum(0, np.sin(warp*2*np.pi*71))**18
save('timber_detail.png', wood)
# Neutral linen: coarse slubs, fibers, periodic soiling; seams remain shader UV features.
weft = np.sin(x*2*np.pi*128)
warp = np.sin(y*2*np.pi*128)
canvas = .84 + .055*weft + .045*warp + .035*weft*warp
canvas += .045*np.sin(x*2*np.pi*3 + np.sin(y*2*np.pi*2))
canvas += .018*np.sin(x*2*np.pi*19)*np.cos(y*2*np.pi*13)
save('canvas_detail.png', canvas)
# Helical bundles in rope UV/object projection, with small fiber frequency.
hemp = .72 + .13*np.sin(2*np.pi*(x*6+y*3)) + .04*np.sin(2*np.pi*(x*83+y*41))
save('hemp_detail.png', hemp)
print('Generated three original 512px seamless ship material maps')
