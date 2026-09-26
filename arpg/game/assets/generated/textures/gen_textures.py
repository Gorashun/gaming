import numpy as np
from PIL import Image
out = "/home/user/gaming/arpg/game/assets/generated/textures/"
def save(a, name):
    Image.fromarray(np.clip(a*255,0,255).astype(np.uint8), "RGBA" if a.shape[-1]==4 else "L").save(out+name)

N=64
y,x = np.mgrid[0:N,0:N]; cx=(x-N/2+0.5)/(N/2); cy=(y-N/2+0.5)/(N/2); r=np.sqrt(cx**2+cy**2)
# soft dot: gaussian core + halo
a = np.clip(np.exp(-r**2*6.0)*0.85 + np.exp(-r**2*28)*0.6, 0, 1) * np.clip(1-r,0,1)**0.5
img = np.dstack([np.ones_like(a)]*3+[a]); save(img, "fx_soft_dot.png")
# spark star: 4-point star + core
ang = np.arctan2(cy,cx)
star = np.clip(1 - np.abs(cx)*np.abs(cy)*40 - r*0.9, 0, 1)**2
core = np.exp(-r**2*30)
a = np.clip(star*0.9 + core, 0, 1) * np.clip(1-r,0,1)
save(np.dstack([np.ones_like(a)]*3+[a]), "fx_spark.png")
# tileable value noise 256 (RGBA = 4 octaves/offsets)
rng = np.random.default_rng(7)
S=256
def tile_noise(freq, seed):
    g = np.random.default_rng(seed).random((freq,freq))
    xs = np.arange(S)*freq/S
    i0 = np.floor(xs).astype(int); f = xs-i0; i1=(i0+1)%freq
    f = f*f*(3-2*f)
    a = g[np.ix_(i0,i0)]; b=g[np.ix_(i0,i1)]; c=g[np.ix_(i1,i0)]; d=g[np.ix_(i1,i1)]
    fy=f[:,None]; fx=f[None,:]
    return (a*(1-fx)+b*fx)*(1-fy)+(c*(1-fx)+d*fx)*fy
def fbm(seed, base=4, oct=4):
    v=np.zeros((S,S)); amp=0.5; tot=0
    for o in range(oct):
        v+=tile_noise(base*2**o, seed+o)*amp; tot+=amp; amp*=0.5
    return v/tot
chans=[fbm(1,4),fbm(11,8),fbm(21,2,3),fbm(31,16,3)]
chans=[(c-c.min())/(c.max()-c.min()) for c in chans]
save(np.dstack(chans), "noise_rgba.png")
# smoke puff: noisy soft blob 64
n = fbm(41,4)[:N*4:4,:N*4:4]
a = np.clip(np.exp(-r**2*3.0)*(0.55+0.6*n) - 0.15, 0, 1) * np.clip(1-r,0,1)
save(np.dstack([np.ones_like(a)]*3+[a/a.max()]), "fx_smoke.png")
# snowflake-ish soft hexa flake 32 -> use soft dot small; flame tongue sprite 64x128
H=128; W=64
yy,xx=np.mgrid[0:H,0:W]; u=(xx-W/2+0.5)/(W/2); v=yy/H  # v 0 top 1 bottom
width = 0.15+0.75*np.sin(np.clip(v,0,1)*np.pi*0.95)**1.5*(v)
a = np.clip(1-np.abs(u)/np.maximum(width,1e-3),0,1)**1.5 * np.clip((1-v)*6,0,1)
save(np.dstack([np.ones_like(a)]*3+[a]), "fx_flame.png")
print("ok")
