-- One-time native-grid authoring. Export never calls this; edited sources are protected.
local out=assert(app.params.out,'Pass an absolute out directory')
local pc=app.pixelColor
local function rgb(s) return pc.rgba(tonumber(s:sub(1,2),16),tonumber(s:sub(3,4),16),tonumber(s:sub(5,6),16),255) end
local C={ink=rgb('1A1426'),shadow=rgb('0B0A12'),bone=rgb('EDE3CC'),boneDark=rgb('C9B79C'),
 robe=rgb('575170'),dark=rgb('3D3850'),steel=rgb('B8C2CC'),wood=rgb('9C7B5E'),
 coal=rgb('4A3B33'),copper=rgb('6E5546'),edge=rgb('9C7B5E'),brass=rgb('C9A25E'),fire=rgb('FF8A1F')}
local img,n
local function pixel(x,y,c)
 assert(x>=0 and x<n and y>=0 and y<n,'Authoring coordinate outside native canvas')
 img:drawPixel(x,y,c)
end
local function rect(x,y,w,h,c) for yy=y,y+h-1 do for xx=x,x+w-1 do pixel(xx,yy,c) end end end
local function poly(p,c)
 for y=0,n-1 do for x=0,n-1 do
  local inside=false;local j=#p
  for i=1,#p do local a,b=p[i],p[j]
   if (a[2]>y+0.5)~=(b[2]>y+0.5) and x+0.5<(b[1]-a[1])*(y+0.5-a[2])/(b[2]-a[2])+a[1] then inside=not inside end
   j=i
  end
  if inside then pixel(x,y,c) end
 end end
end
local function ellipse(x,y,w,h,c)
 for yy=y,y+h-1 do for xx=x,x+w-1 do
  if ((xx-x+0.5-w/2)/(w/2))^2+((yy-y+0.5-h/2)/(h/2))^2<=1 then pixel(xx,yy,c) end
 end end
end
local function outline()
 local src=Image(img)
 for y=0,n-1 do for x=0,n-1 do
  if pc.rgbaA(src:getPixel(x,y))==0 then
   for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
    local xx,yy=x+d[1],y+d[2]
    if xx>=0 and xx<n and yy>=0 and yy<n and pc.rgbaA(src:getPixel(xx,yy))>0 then pixel(x,y,C.ink);break end
   end
  end
 end end
end
local function gravekeeper(b,run,p)
 -- Upright, spare ribcage and skull; the curved blade is separate from the head.
 rect(47,10-b,2,46+b,C.wood)
 poly({{47,6-b},{54,7-b},{60,11-b},{61,18-b},{57,13-b},{51,11-b},{47,11-b}},C.steel)
 rect(47,10-b,2,3,C.boneDark)
 poly({{19,28-b},{24,25-b},{36,26-b},{42,32-b},{38,38-b},{20,38-b}},C.robe)
 poly({{23,34-b},{36,34-b},{39,48},{35,47},{33,50},{29,47},{25,49},{21,47}},C.dark)
 rect(29,27-b,3,18,C.boneDark)
 for y=30-b,38-b,4 do
  rect(25,y,11,2,C.bone);rect(24,y+1,2,2,C.boneDark)
 end
 rect(19,32-b,4,10,C.boneDark);rect(17,40-b,6,4,C.bone)
 poly({{36,31-b},{42,34-b},{48,32-b},{49,35-b},{42,38-b},{35,35-b}},C.boneDark)
 rect(46,32-b,4,3,C.bone)
 -- Stride changes knee/foot positions without shifting the foot baseline.
 local a=run and (p==0 and -2 or 2) or 0
 poly({{25,47},{29,47},{28+a,54},{26+a,58},{23+a,58},{25+a,53}},C.boneDark)
 poly({{33,47},{36,47},{37-a,53},{35-a,59},{32-a,59},{34-a,53}},C.bone)
 rect(22+a,58,7,2,C.robe);rect(32-a,58,8,2,C.robe)
 poly({{24,12-b},{32,10-b},{37,13-b},{38,18-b},{40,20-b},{37,22-b},{35,25-b},{28,25-b},{23,20-b}},C.bone)
 rect(25,13-b,4,3,C.boneDark)
 rect(31,16-b,5,4,C.ink);rect(37,20-b,2,2,C.ink)
 rect(31,23-b,1,3,C.dark);rect(34,23-b,1,3,C.dark)
end
local function colossus(b,run,p)
 -- Native 96px proportions: squat furnace, heavy limbs, detached hammer head.
 rect(78,28-b,3,53+b,C.wood)
 poly({{69,16-b},{88,16-b},{91,21-b},{91,31-b},{87,35-b},{69,35-b},{66,30-b},{66,21-b}},C.coal)
 rect(70,17-b,17,4,C.edge);rect(86,21-b,4,9,C.copper)
 rect(76,23-b,5,7,C.brass)
 poly({{21,29-b},{34,25-b},{60,27-b},{69,36-b},{66,66},{58,72},{26,70},{19,58}},C.copper)
 poly({{12,32-b},{24,29-b},{29,40-b},{23,50-b},{11,47-b},{8,40-b}},C.coal)
 rect(11,36-b,12,4,C.edge)
 poly({{11,47-b},{22,46-b},{24,64},{20,71},{9,68}},C.coal)
 rect(10,62,12,6,C.copper)
 poly({{62,33-b},{72,35-b},{76,45-b},{72,53-b},{61,48-b}},C.coal)
 rect(66,36-b,7,3,C.edge)
 poly({{65,49-b},{74,47-b},{81,50-b},{81,57-b},{68,58-b},{63,55-b}},C.copper)
 rect(77,49-b,6,6,C.brass)
 -- The opening stays dark; warm accents occupy only a small inner grate.
 poly({{34,42-b},{40,38-b},{49,39-b},{55,44-b},{55,61-b},{34,61-b}},C.ink)
 rect(36,44-b,2,14,C.brass);rect(51,44-b,2,14,C.edge)
 rect(41,48-b,8,9,C.coal)
 rect(42,50-b,2,5,C.fire);rect(47,49-b,1,7,C.fire)
 rect(38,61-b,13,2,C.edge)
 poly({{33,12-b},{48,10-b},{56,15-b},{58,24-b},{53,29-b},{35,28-b},{30,22-b}},C.coal)
 rect(34,13-b,14,4,C.copper);rect(48,19-b,10,3,C.ink)
 rect(51,20-b,4,1,C.brass)
 local a=run and (p==0 and -3 or 3) or 0
 poly({{24,69},{37,69},{37+a,80},{34+a,88},{22+a,88},{23+a,78}},C.coal)
 poly({{49,70},{62,69},{65-a,80},{62-a,88},{49-a,88},{50-a,80}},C.coal)
 rect(20+a,86,18,6,C.copper);rect(48-a,86,20,6,C.copper)
 rect(21+a,86,16,2,C.edge);rect(49-a,86,17,2,C.edge)
end
for _,spec in ipairs({{'gravekeeper',64},{'furnace_colossus',96}}) do
 n=spec[2];local path=out..'/bos_'..spec[1]..'.aseprite'
 assert(not app.fs.isFile(path),'Refusing to overwrite edited source: '..path)
 local sprite=Sprite(n,n,ColorMode.RGB)
 sprite:assignColorSpace(ColorSpace{sRGB=true})
 sprite:loadPalette(out..'/../../palette/soulbox_master.gpl')
 local shadow=sprite.layers[1];shadow.name='Shadow'
 local body=sprite:newLayer();body.name='Body'
 for f=2,4 do sprite:newEmptyFrame(f) end
 for f=1,4 do
  sprite.frames[f].duration=f<=2 and 0.167 or 0.083
  img=Image(n,n,ColorMode.RGB)
  if n==64 then ellipse(16,57,34,6,C.shadow) else ellipse(12,86,66,9,C.shadow) end
  sprite:newCel(shadow,f,img,Point(0,0))
  img=Image(n,n,ColorMode.RGB)
  if n==64 then gravekeeper((f-1)%2,f>=3,(f-1)%2) else colossus((f-1)%2,f>=3,(f-1)%2) end
  outline();sprite:newCel(body,f,img,Point(0,0))
 end
 sprite:newTag(1,2).name='idle';sprite:newTag(3,4).name='run'
 sprite:saveAs(path);sprite:close();print('AUTHORED '..path)
end
