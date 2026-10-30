-- Initial native authoring only; normal export never invokes this or overwrites sources.
local root=assert(app.params.root)
local stream=assert(io.open(root..'/art/source/rk074/manifest.json'))
local manifest=json.decode(stream:read('*a'));stream:close()
local function rgb(hex) return app.pixelColor.rgba(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16),255) end
local colors={fire=rgb('FF8A1F'),frost=rgb('A8EEFF'),lightning=rgb('4F7BFF'),mechanical=rgb('C9A25E'),undead=rgb('5FD38D'),holy=rgb('FFE8A3'),melee=rgb('B8C2CC')}
-- Independent 8x8 silhouettes: flame / ice crystal / bolt / gear / skull / ring / crossed swords.
local icons={
 fire={'...#....','...##...','..###.#.','..#####.','.######.','.######.','..####..','...##...'},
 frost={'...##...','..####..','.######.','..####..','..####..','...##...','...##...','...#....'},
 lightning={'....###.','...###..','..###...','.######.','...###..','..###...','.###....','###.....'},
 mechanical={'..#..#..','.######.','########','.##..##.','.##..##.','########','.######.','..#..#..'},
 undead={'.######.','########','##.##.##','##.##.##','###..###','.######.','..#.#.#.','..#####.'},
 holy={'..####..','.##..##.','##....##','##....##','##....##','##....##','.##..##.','..####..'},
 melee={'#......#','##....##','.##..##.','..####..','..####..','.######.','..#..#..','.#....#.'},
}
local pickups={
 xp_small={'.##.','####','####','.##.'},
 xp_medium={'..##..','.####.','######','######','.####.','..##..'},
 xp_large={'...##...','..####..','.######.','########','########','.######.','..####..','...##...'},
 soul_crystal={'.####.','.####.','######','######','.####.','.####.'},
 energy={'...#..','..##..','..###.','.####.','######','.####.'},
}
for _,e in ipairs(manifest.assets) do
 local path=root..'/'..e.source;assert(not app.fs.isFile(path),'Refuse to overwrite '..path)
 local n=e.canvas_size.w;local s=Sprite(n,n,ColorMode.RGB)
 s:assignColorSpace(ColorSpace{sRGB=true});s:loadPalette(root..'/art/palette/soulbox_ally.gpl')
 local body=s.layers[1];body.name='Body'
 local image=Image(n,n,ColorMode.RGB)
 if e.category=='soul' then
  local b=e.body_rect
  -- Rasterize each tier at its native target grid; never resize any prior bitmap.
  for y=b.y,b.y+b.h-1 do for x=b.x,b.x+b.w-1 do
   if ((x+0.5-b.x-b.w/2)/(b.w/2))^2+((y+0.5-b.y-b.h/2)/(b.h/2))^2<=1 then
    local index=(#e.tags==2 and x>=b.x+b.w/2) and 2 or 1
    image:drawPixel(x,y,colors[e.tags[index]])
   end
  end end
  if e.tier>=2 then image:drawPixel(b.x+b.w/2-1,b.y+b.h/2-1,rgb('F0F0F0')) end
  if e.tier>=3 then
   local decor=s:newLayer();decor.name='Decor';local dots=Image(n,n,ColorMode.RGB)
   if e.tier==3 then dots:drawPixel(0,7,colors[e.tags[1]]);dots:drawPixel(1,6,colors[e.tags[1]])
   else for _,p in ipairs({{0,0},{11,0},{0,11},{11,11}}) do dots:drawPixel(p[1],p[2],colors[e.tags[1]]) end end
   s:newCel(decor,1,dots,Point(0,0))
  end
 else
  local pattern=e.category=='tag' and icons[e.id] or pickups[e.id]
  local color=e.category=='tag' and colors[e.id] or (e.id:sub(1,2)=='xp' and rgb('B48CFF') or (e.id=='energy' and rgb('3DF2C5') or rgb('FFC93C')))
  for y,row in ipairs(pattern) do for x=1,#row do if row:sub(x,x)=='#' then image:drawPixel(x-1,y-1,color) end end end
 end
 s:newCel(body,1,image,Point(0,0));s:saveAs(path);s:close()
end
print('RK074_AUTHOR: passed')
