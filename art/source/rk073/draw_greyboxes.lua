-- One-time authoring helper: native pixel primitives -> editable Aseprite documents.
-- Never invoked by the normal export pipeline. Refuses to overwrite edited sources.
local out = app.params.out
assert(out, 'Pass --script-param out=/absolute/source/path')
local pc = app.pixelColor
local function color(hex)
  return pc.rgba(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16),255)
end
local C={outline=color('1A1426'), shadow=color('0B0A12'), steel=color('5B7FA6'), light=color('B8C2CC'),
 bone=color('EDE3CC'), boneDark=color('C9B79C'), green=color('7A8C3A'), moss=color('3A6B3F'),
 skin=color('C88A65'), purple=color('7A7393'), robe=color('4B3B6B'), wood=color('9C7B5E'),
 copper=color('9E3B2E'), coal=color('4A3B33'), flame=color('FF8A1F'), gold=color('C9A25E'),
 red=color('FF3B30'), cyan=color('8FD3FF')}
local img,N
local function pixel(x,y,c) if x>=0 and y>=0 and x<N and y<N then img:drawPixel(x,y,c) end end
local function rect(x,y,w,h,c) for yy=y,y+h-1 do for xx=x,x+w-1 do pixel(xx,yy,c) end end end
local function ellipse(x,y,w,h,c)
 for yy=y,y+h-1 do for xx=x,x+w-1 do
  if ((xx-x+0.5-w/2)/(w/2))^2+((yy-y+0.5-h/2)/(h/2))^2<=1 then pixel(xx,yy,c) end
 end end
end
local function line(x0,y0,x1,y1,c)
 local dx,dy=math.abs(x1-x0),-math.abs(y1-y0);local sx=x0<x1 and 1 or -1;local sy=y0<y1 and 1 or -1;local err=dx+dy
 while true do pixel(x0,y0,c);if x0==x1 and y0==y1 then break end;local e=2*err;if e>=dy then err=err+dy;x0=x0+sx end;if e<=dx then err=err+dx;y0=y0+sy end end
end
local function poly(points,c)
 for yy=0,N-1 do for xx=0,N-1 do
  local inside=false;local j=#points
  for i=1,#points do local a,b=points[i],points[j]
   if (a[2]>yy+0.5)~=(b[2]>yy+0.5) and xx+0.5<(b[1]-a[1])*(yy+0.5-a[2])/(b[2]-a[2])+a[1] then inside=not inside end;j=i
  end
  if inside then pixel(xx,yy,c) end
 end end
end
local function outline(elite)
 local src=Image(img);local ink=elite and C.red or C.outline
 for y=0,N-1 do for x=0,N-1 do
  if pc.rgbaA(src:getPixel(x,y))==0 then
   for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
    local xx,yy=x+d[1],y+d[2]
    if xx>=0 and xx<N and yy>=0 and yy<N and pc.rgbaA(src:getPixel(xx,yy))>0 then pixel(x,y,ink);break end
   end
  end
 end end
end
local function hero(id,b,run,p)
 if id=='knight' then
  rect(11,15-b,9,10+b,C.steel);rect(10+p,25,4,3,C.coal);rect(17-p,25,4,3,C.coal)
  rect(12,9-b,9,7,C.steel);rect(17,12-b,5,2,C.outline);rect(12,9-b,3,3,C.light)
  poly({{14,9-b},{13,4-b},{18,4-b},{20,6-b},{17,7-b},{17,10-b}},C.copper)
  ellipse(6,17-b,9,9,C.steel);ellipse(8,19-b,5,5,C.gold);rect(10,18-b,1,7,C.light)
  rect(23,15-b,2,9,C.light);rect(21,23-b,6,1,C.gold);rect(23,24-b,2,2,C.wood)
 else
  poly({{10,16-b},{19,16-b},{21,25},{9,25}},C.green)
  rect(11+p,25,3,3,C.coal);rect(17-p,25,3,3,C.coal)
  rect(13,12-b,7,5,C.skin);poly({{9,12-b},{14,4-b},{17,6-b},{19,12-b}},C.green)
  rect(6,12-b,18,2,C.green);rect(15,12-b,3,1,C.gold)
  line(19,18-b,22,20-b,C.wood);rect(23,18-b,2,2,C.gold);rect(22,20-b,4,5,C.cyan);rect(23,21-b,2,2,C.moss)
 end
end
-- Native normal-grid recipes. Elite recipes below have independently chosen proportions.
local function normal(id,b,run,p)
 if id=='skeleton_rat' then
  line(2,9-b,6,10-b,C.boneDark);line(2,9-b,2,7-b,C.boneDark)
  ellipse(6,6-b,7,5,C.bone);poly({{10,6-b},{11,4-b},{13,7-b}},C.bone)
  rect(12,8-b,2,2,C.bone);pixel(12,7-b,C.outline);rect(7+p,11,2,1,C.boneDark);rect(11-p,11,2,1,C.boneDark)
 elseif id=='crypt_zombie' then
  rect(6,4-b,5,4,C.moss);rect(6,8-b,5,3+b,C.purple);rect(10,8-b,4,2,C.moss)
  rect(6+p,11,2,1,C.coal);rect(10-p,11,2,1,C.coal);pixel(10,5-b,C.bone)
 elseif id=='charge_boar' then
  ellipse(5,9-b,12,8,C.coal);poly({{14,10-b},{20,11-b},{21,16-b},{15,17-b}},C.copper)
  line(5,11-b,3,9-b,C.coal);rect(7+p,17,3,3,C.coal);rect(14-p,17,3,3,C.coal)
  poly({{17,16-b},{21,14-b},{20,18-b}},C.bone);pixel(18,12-b,C.gold)
 elseif id=='bone_archer' then
  rect(8,5-b,5,5,C.bone);rect(9,10-b,3,7+b,C.boneDark);line(10,11-b,16,13-b,C.bone)
  line(9,17,7+p,19,C.bone);line(11,17,13-p,19,C.bone)
  line(16,5-b,19,8-b,C.wood);line(19,8-b,20,12-b,C.wood);line(20,12-b,19,16-b,C.wood);line(19,16-b,16,19-b,C.wood)
  line(16,5-b,16,19-b,C.boneDark);pixel(11,7-b,C.outline)
 elseif id=='blast_mushroom' then
  rect(6,9-b,4,3+b,C.boneDark);rect(5+p,11,2,1,C.boneDark);rect(9-p,11,2,1,C.boneDark)
  poly({{2,8-b},{3,5-b},{6,3-b},{10,3-b},{13,5-b},{14,8-b}},C.copper)
  rect(3,8-b,10,1,C.copper);rect(5,5-b,2,1,C.gold);pixel(10,6-b,C.gold)
 elseif id=='slime' then
  poly({{3,11},{3,9-b},{5,7-b},{10,6-b},{13,9-b},{13,11},{11,12},{9,11},{7,12},{5,11}},C.moss)
  pixel(10,8-b,C.bone);pixel(12,8-b,C.bone);line(5,8-b,7,7-b,C.green)
 elseif id=='fire_mage' then
  poly({{8,9-b},{12,7-b},{15,10-b},{16,19},{7,19}},C.robe);rect(9+p,19,2,1,C.coal);rect(13-p,19,2,1,C.coal)
  poly({{8,8-b},{11,3-b},{14,8-b}},C.robe);rect(10,8-b,3,2,C.boneDark)
  line(14,12-b,18,11-b,C.robe);rect(19,6-b,1,14+b,C.wood)
  poly({{17,6-b},{18,3-b},{20,2-b},{22,5-b},{21,8-b},{18,8-b}},C.flame)
 elseif id=='lava_golem' then
  rect(7,11-b,18,13+b,C.coal);rect(10,5-b,13,8,C.copper)
  rect(3,13-b,5,12+b,C.coal);rect(25,12-b,4,13+b,C.coal)
  rect(8+p,24,6,4,C.coal);rect(20-p,24,6,4,C.coal)
  rect(17,9-b,3,2,C.flame);line(15,14-b,18,18-b,C.copper);line(18,18-b,15,22,C.copper)
 end
end
local function elite(id,b,run,p)
 if id=='skeleton_rat' then
  line(3,15-b,7,16-b,C.boneDark);line(3,15-b,2,12-b,C.boneDark);line(2,12-b,4,10-b,C.boneDark)
  ellipse(7,11-b,12,7,C.bone);poly({{15,11-b},{17,7-b},{19,10-b},{20,16-b},{22,17-b},{18,19-b}},C.bone)
  line(9,12-b,12,13-b,C.boneDark);rect(9+p,18,3,2,C.boneDark);rect(17-p,18,3,2,C.boneDark);pixel(19,13-b,C.outline)
 elseif id=='crypt_zombie' then
  rect(9,5-b,7,6,C.moss);poly({{8,11-b},{15,10-b},{17,17},{8,18}},C.purple)
  rect(15,11-b,6,3,C.moss);rect(19,13-b,2,3,C.moss)
  rect(8+p,18,4,2,C.coal);rect(15-p,17,3,3,C.coal);rect(14,7-b,2,1,C.bone)
 elseif id=='charge_boar' then
  ellipse(7,12-b,18,12,C.coal);poly({{22,14-b},{30,15-b},{32,21-b},{28,25-b},{22,23-b}},C.copper)
  poly({{10,12-b},{11,8-b},{14,12-b},{17,9-b},{20,13-b}},C.coal)
  line(7,16-b,3,13-b,C.coal);rect(10+p,25,4,7,C.coal);rect(23-p,25,4,7,C.coal)
  poly({{27,22-b},{32,19-b},{31,26-b},{28,27-b}},C.bone);rect(28,17-b,2,1,C.gold)
 elseif id=='bone_archer' then
  rect(10,6-b,8,7,C.bone);rect(12,13-b,4,12+b,C.boneDark)
  line(13,15-b,24,18-b,C.bone);line(13,24,9+p,31,C.bone);line(16,24,19-p,31,C.bone)
  line(24,6-b,29,11-b,C.wood);line(29,11-b,31,19-b,C.wood);line(31,19-b,29,26-b,C.wood);line(29,26-b,24,31-b,C.wood)
  line(24,6-b,24,31-b,C.boneDark);rect(15,9-b,2,2,C.outline);rect(10,17-b,8,1,C.bone)
 elseif id=='blast_mushroom' then
  rect(10,14-b,5,6+b,C.boneDark);rect(8+p,19,3,1,C.boneDark);rect(15-p,19,3,1,C.boneDark)
  poly({{3,13-b},{4,9-b},{8,5-b},{14,4-b},{19,7-b},{21,12-b},{21,14-b},{4,14-b}},C.copper)
  rect(7,8-b,3,2,C.gold);rect(15,10-b,3,1,C.gold);pixel(12,6-b,C.gold)
 elseif id=='slime' then
  poly({{3,18},{4,14-b},{8,11-b},{13,9-b},{18,11-b},{21,15-b},{21,18},{18,20},{15,18},{12,20},{9,18},{6,20}},C.moss)
  rect(16,13-b,2,2,C.bone);pixel(20,14-b,C.bone);line(7,14-b,10,12-b,C.green)
 elseif id=='fire_mage' then
  poly({{9,15-b},{15,12-b},{21,16-b},{23,31},{7,31}},C.robe)
  rect(10+p,31,3,1,C.coal);rect(18-p,31,3,1,C.coal)
  poly({{10,12-b},{13,5-b},{16,7-b},{18,13-b}},C.robe);rect(13,13-b,5,3,C.boneDark)
  line(21,19-b,28,17-b,C.robe);rect(29,9-b,2,23+b,C.wood)
  poly({{26,10-b},{26,6-b},{29,2-b},{32,6-b},{33,10-b},{30,13-b}},C.flame)
 elseif id=='lava_golem' then
  rect(11,16-b,25,19+b,C.coal);rect(16,6-b,18,12,C.copper)
  poly({{5,18-b},{12,15-b},{15,22-b},{13,37},{4,36}},C.coal)
  poly({{35,16-b},{42,18-b},{44,34},{36,38}},C.coal)
  rect(12+p,35,8,9,C.coal);rect(30-p,34,8,10,C.coal)
  rect(27,11-b,4,2,C.flame);line(20,19-b,25,24-b,C.copper);line(25,24-b,21,31,C.copper)
  rect(8,21-b,4,3,C.copper);rect(38,23-b,3,4,C.copper)
 end
end
local specs={
 {'chr_knight','knight',32,false},{'chr_alchemist','alchemist',32,false},
 {'enm_skeleton_rat','skeleton_rat',16,false},{'enm_skeleton_rat_elite','skeleton_rat',24,true},
 {'enm_crypt_zombie','crypt_zombie',16,false},{'enm_crypt_zombie_elite','crypt_zombie',24,true},
 {'enm_charge_boar','charge_boar',24,false},{'enm_charge_boar_elite','charge_boar',36,true},
 {'enm_bone_archer','bone_archer',24,false},{'enm_bone_archer_elite','bone_archer',36,true},
 {'enm_blast_mushroom','blast_mushroom',16,false},{'enm_blast_mushroom_elite','blast_mushroom',24,true},
 {'enm_slime','slime',16,false},{'enm_slime_elite','slime',24,true},
 {'enm_fire_mage','fire_mage',24,false},{'enm_fire_mage_elite','fire_mage',36,true},
 {'enm_lava_golem','lava_golem',32,false},{'enm_lava_golem_elite','lava_golem',48,true},
}
for _,s in ipairs(specs) do
 N=s[3];local path=out..'/'..s[1]..'.aseprite'
 assert(not app.fs.isFile(path),'Refusing to overwrite edited source: '..path)
 local sprite=Sprite(N,N,ColorMode.RGB)
 sprite:assignColorSpace(ColorSpace{ sRGB=true })
 sprite:loadPalette(out..'/../../palette/soulbox_'..(s[1]:sub(1,3)=='chr' and 'ally' or 'master')..'.gpl')
 local shadow=sprite.layers[1];shadow.name='Shadow'
 local body=sprite:newLayer();body.name='Body'
 for f=2,4 do sprite:newEmptyFrame(f) end
 for f=1,4 do
  sprite.frames[f].duration=f<=2 and 0.167 or 0.083
  img=Image(N,N,ColorMode.RGB)
  local sw=s[1]:sub(1,3)=='chr' and 12 or (s[4] and 12 or 8)
  local sh=s[1]:sub(1,3)=='chr' and 4 or (s[4] and 5 or 3)
  ellipse(math.floor(N/2-sw/2),N-5,sw,sh,C.shadow)
  sprite:newCel(shadow,f,img,Point(0,0))
  img=Image(N,N,ColorMode.RGB)
  local phase=(f-1)%2;local b=phase;local p=f>=3 and phase or 0
  if s[1]:sub(1,3)=='chr' then hero(s[2],b,f>=3,p)
  elseif s[4] then elite(s[2],b,f>=3,p)
  else normal(s[2],b,f>=3,p) end
  outline(s[4]);sprite:newCel(body,f,img,Point(0,0))
 end
 sprite:newTag(1,2).name='idle';sprite:newTag(3,4).name='run'
 sprite:saveAs(path);sprite:close()
 print('AUTHORED '..path)
end
