# Kheir app icon: the flower of the day, cut from paper, with the crescent at its heart.
import math
exec(open('diorama_base.py').read().split('PAL={')[0])  # seeded, crescent, defs (shadows + grain)
CX,CY,R=512,512,400
PAL={
 'light':dict(bg='#2E5E3A',leaves=['#5F9A6E','#7FAE7A','#3E7350','#5F9A6E'],outer='#D2694B',inner='#E6A08C',heart='#141A33',moon='#F6EBC8'),
 'dark': dict(bg='#141A33',leaves=['#2F4A44','#3E5A50','#24403A','#2F4A44'],outer='#B8573E',inner='#C98A78',heart='#0B1020',moon='#F6EBC8'),
}
def svg(body): return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{defs}{body}</svg>'
def layer(kind,p):
    if kind=='background':
        b=f'<rect width="1024" height="1024" fill="{p["bg"]}"/>'
        for (x,y,a),c in zip([(200,820,-30),(830,800,25),(170,240,30),(860,230,-25)],p['leaves']):
            b+=f'<ellipse cx="{x}" cy="{y}" rx="70" ry="28" fill="{c}" transform="rotate({a} {x} {y})" filter="url(#sh1)"/>'
        return b+'<rect width="1024" height="1024" fill="#fff" filter="url(#grain)"/>'
    if kind=='outer':
        return ''.join(f'<ellipse cx="{CX}" cy="{CY-R*.55}" rx="{R*.32}" ry="{R*.55}" fill="{p["outer"]}" transform="rotate({i*45} {CX} {CY})" filter="url(#sh1)"/>' for i in range(8))
    if kind=='inner':
        return ''.join(f'<ellipse cx="{CX}" cy="{CY-R*.4}" rx="{R*.22}" ry="{R*.42}" fill="{p["inner"]}" transform="rotate({i*45+22.5} {CX} {CY})" filter="url(#sh1)"/>' for i in range(8))
    if kind=='heart':
        r=R*.26
        return (f'<circle cx="{CX}" cy="{CY}" r="{R*.36}" fill="{p["heart"]}" filter="url(#sh2)"/>'
                f'<g filter="url(#sh1)"><path d="{crescent(CX+r*.15,CY,r,r*.48,-r*.18,r*.92)}" fill="{p["moon"]}"/></g>')
for name,p in PAL.items():
    for k in ['background','outer','inner','heart']:
        open(f'{k}-{name}.svg','w').write(svg(layer(k,p)))
    open(f'flat-{name}.svg','w').write(svg(''.join(layer(k,p) for k in ['background','outer','inner','heart'])))
