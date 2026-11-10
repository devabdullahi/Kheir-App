import math,sys
def seeded(i,salt=0):
    x=math.sin(i*12.9898+salt*78.233)*43758.5453; return x-math.floor(x)
def torn(y,amp,seed,w=1024,step=10):
    pts=[]
    for k in range(int(w/step)+3):
        x=k*step-step
        roll=math.sin(x/170+seeded(seed,5)*6.28)*.6+math.sin(x/61+seeded(seed,6)*6.28)*.4
        pts.append((x,y+roll*amp+(seeded(k,seed+7)-.5)*7))
    return pts
def band(y,amp,seed,color,depth):
    pts=torn(y,amp,seed)
    d=f"M-20 1044 "+" ".join(f"L{x:.1f} {yy:.1f}" for x,yy in pts)+" L1044 1044Z"
    return f'<path d="{d}" fill="{color}" filter="url(#sh{depth})"/>'
def crescent(cx,cy,r,bx,by,br,n=180):
    ax=math.atan2(-by,-bx);out=[];inn=[]
    for k in range(n+1):
        a=ax-math.pi+k/n*2*math.pi;x=cx+math.cos(a)*r;y=cy+math.sin(a)*r
        if math.hypot(x-cx-bx,y-cy-by)>=br: out.append((x,y))
    for k in range(n+1):
        a=ax-math.pi+k/n*2*math.pi;x=cx+bx+math.cos(a)*br;y=cy+by+math.sin(a)*br
        if math.hypot(x-cx,y-cy)<=r: inn.append((x,y))
    return "M"+" L".join(f"{x:.1f} {y:.1f}" for x,y in out+inn[::-1])+"Z"
def star(x,y,r,rot):
    p=[]
    for k in range(10):
        a=math.radians(k*36+rot-90);rr=r if k%2==0 else r*.45;p.append(f"{x+math.cos(a)*rr:.1f} {y+math.sin(a)*rr:.1f}")
    return "M"+" L".join(p)+"Z"
def flower(x,y,s,kind,c1,c2):
    g=f'<g transform="translate({x} {y}) scale({s})">'
    g+='<path d="M0 0 Q3 -14 0 -26" stroke="#2F5E3F" stroke-width="4" fill="none"/>'
    g+=f'<g transform="translate(0 -30)">'
    if kind=='poppy':
        for i,a in enumerate([20,110,200,290]): g+=f'<ellipse cx="0" cy="-8" rx="10" ry="10" fill="{c1 if i%2 else c2}" transform="rotate({a})"/>'
        g+='<circle r="4.5" fill="#2B2118"/>'
    elif kind=='daisy':
        for i in range(12): g+=f'<ellipse cx="0" cy="-9" rx="3" ry="9" fill="{c1}" transform="rotate({i*30})"/>'
        g+='<circle r="5" fill="#E3B65A"/>'
    else:
        for i in range(5): g+=f'<ellipse cx="0" cy="-8" rx="6.5" ry="9" fill="{c1 if i%2 else c2}" transform="rotate({i*72})"/>'
        g+='<circle r="3.5" fill="#E3B65A"/>'
    return g+'</g></g>'
defs='''<defs>
<filter id="sh1" x="-10%" y="-10%" width="120%" height="130%"><feDropShadow dx="4" dy="9" stdDeviation="8" flood-color="#120a04" flood-opacity=".38"/><feDropShadow dx="1.5" dy="3" stdDeviation="2" flood-color="#120a04" flood-opacity=".3"/></filter>
<filter id="sh2" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="10" dy="22" stdDeviation="16" flood-color="#0b0603" flood-opacity=".42"/><feDropShadow dx="3" dy="6" stdDeviation="3" flood-color="#0b0603" flood-opacity=".35"/></filter>
<filter id="grain" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency=".75" numOctaves="2" seed="7"/><feColorMatrix values="0 0 0 0 .25  0 0 0 0 .17  0 0 0 0 .08  0 0 0 .22 0"/><feComposite in2="SourceGraphic" operator="in"/></filter>
</defs>'''
PAL={
 'dusk':dict(bg='#2A1A3A',bands=['#5B2E4A','#8B2E1A','#D4694A','#E8A87A'],star='#FFF4D6',moon='#F6EBC8',far='#4E8A5A',near='#2F5E3F',flw=[('poppy','#D2402B','#E5644C'),('daisy','#FBF5E8',''),('sakura','#F4B6C2','#F9D3DA'),('poppy','#E58A3A','#F0A860')]),
 'night':dict(bg='#141A33',bands=['#1E2442','#2B3560','#3A4778','#4F5B8E'],star='#FFF4D6',moon='#F6EBC8',far='#2F4A44',near='#1F3A30',flw=[('poppy','#B8402B','#C9604C'),('daisy','#E9E1CF',''),('sakura','#C98EA0','#D9A8B6'),('poppy','#C4783A','#D29158')]),
}
def layer(kind,p):
    body=''
    if kind=='sky':
        body+=f'<rect width="1024" height="1024" fill="{p["bg"]}"/>'
        for i,(y,c) in enumerate(zip([300,470,600,700],p['bands'])): body+=band(y,22,200+i,c,1)
        for i,(x,y,r) in enumerate([(190,170,22),(310,330,14),(820,560,15),(150,520,12),(880,250,11)]): body+=f'<path d="{star(x,y,r,i*17)}" fill="{p["star"]}" filter="url(#sh1)"/>'
        body+='<rect width="1024" height="1024" fill="#fff" filter="url(#grain)"/>'
    if kind=='moon':
        # thread tied straight above the crescent's centre of mass
        r=190;kx,ky=600,250;cx,cy=kx+r*.34,ky+r*.94
        body+=f'<path d="M{kx} -10 L{kx} {ky+8}" stroke="#F3E9D2" stroke-opacity=".75" stroke-width="5"/>'
        body+=f'<g filter="url(#sh2)"><path d="{crescent(cx,cy,r,r*.48,-r*.18,r*.94)}" fill="{p["moon"]}"/></g>'
        body+=f'<circle cx="{kx}" cy="{ky+10}" r="13" fill="#C79A3A" filter="url(#sh1)"/><circle cx="{kx-4}" cy="{ky+6}" r="5" fill="#F6DE93"/>'
    if kind=='hills':
        far=torn(800,26,300); near=torn(890,20,301)
        fd="M-20 1044 "+" ".join(f"L{x:.1f} {y:.1f}" for x,y in far)+" L1044 1044Z"
        nd="M-20 1044 "+" ".join(f"L{x:.1f} {y:.1f}" for x,y in near)+" L1044 1044Z"
        body+=f'<path d="{fd}" fill="{p["far"]}" filter="url(#sh1)"/>'
        for i,x in enumerate([110,250,400,700,860]):
            k,c1,c2=p['flw'][i%4]; y=dict(far)[min(dict(far),key=lambda v:abs(v-x))]
            body+=flower(x,y+14,1.25,k,c1,c2 or c1)
        body+=f'<path d="{nd}" fill="{p["near"]}" filter="url(#sh1)"/>'
        for i,x in enumerate([60,190,330,470,590,760,900,990]):
            k,c1,c2=p['flw'][(i+1)%4]; y=dict(near)[min(dict(near),key=lambda v:abs(v-x))]
            body+=flower(x,y+16,1.9,k,c1,c2 or c1)
        body+='<g opacity=".6"><rect width="1024" height="1024" fill="#fff" filter="url(#grain)"/></g>' if False else ''
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{defs}{body}</svg>'
for pal in PAL:
    for k in ['sky','moon','hills']:
        open(f'{k}-{pal}.svg','w').write(layer(k,PAL[pal]))
# flat composite for preview
for pal in PAL:
    inner=''.join(open(f'{k}-{pal}.svg').read().split(defs)[1].replace('</svg>','') for k in ['sky','moon','hills'])
    open(f'flat-{pal}.svg','w').write(f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{defs}{inner}</svg>')
