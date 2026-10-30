local root=assert(app.params.root);local file=assert(io.open(root..'/art/source/rk074/manifest.json'))
local manifest=json.decode(file:read('*a'));file:close()
local count=0
for _,e in ipairs(manifest.assets) do
 local s=assert(app.open(root..'/'..e.source));assert(#s.frames==1,'Static source must have one frame')
 assert(s.width==e.canvas_size.w and s.height==e.canvas_size.h,'Native canvas')
 local layers={};for _,layer in ipairs(s.layers) do layers[layer.name]=layer;assert(layer.opacity==255,'Layer opacity') end
 assert(layers.Body and layers.Body:cel(1),'Body layer')
 if e.category=='soul' and e.tier>=3 then assert(layers.Decor and layers.Decor:cel(1),'Decor layer') end
 local cel=layers.Body:cel(1)
 local minx,miny,maxx,maxy=999,999,-1,-1
 for p in cel.image:pixels() do if app.pixelColor.rgbaA(p())>0 then
  minx=math.min(minx,p.x+cel.position.x);miny=math.min(miny,p.y+cel.position.y)
  maxx=math.max(maxx,p.x+cel.position.x);maxy=math.max(maxy,p.y+cel.position.y)
 end end
 if e.category=='soul' then
  assert(minx==e.body_rect.x and miny==e.body_rect.y and maxx==minx+e.body_rect.w-1 and maxy==miny+e.body_rect.h-1,'Native body bounds')
 end
 s:close();count=count+1
end
assert(count==60);print('RK074_SOURCES: passed')
