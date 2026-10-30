-- Read-only native source audit, called by rk073_verify.py.
local root=app.params.root
local f=assert(io.open(root..'/art/source/rk073/manifest.json'))
local manifest=json.decode(f:read('*a'));f:close()
local seen={};local count=0
for _,entry in ipairs(manifest.assets) do
 if not seen[entry.source] then
  local s=assert(app.open(root..'/'..entry.source))
  assert(#s.frames==4 and #s.tags==2,'Expected four frames and two tags')
  assert(s.width==entry.frame_size.w and s.height==entry.frame_size.h,'Source dimensions')
  assert(s.tags[1].name=='idle' and s.tags[1].fromFrame.frameNumber==1 and s.tags[1].toFrame.frameNumber==2,'Idle tag')
  assert(s.tags[2].name=='run' and s.tags[2].fromFrame.frameNumber==3 and s.tags[2].toFrame.frameNumber==4,'Run tag')
  local layers={};for _,layer in ipairs(s.layers) do layers[layer.name]=layer end
  assert(layers.Body and layers.Shadow,'Separate Body/Shadow layers')
  local image_ids={}
  for i,frame in ipairs(s.frames) do
   local expected=i<=2 and 0.167 or 0.083
   assert(math.abs(frame.duration-expected)<0.00001,'Source frame duration')
   local cel=assert(layers.Body:cel(i));local bottom=-1
   assert(not image_ids[cel.image.id],'Body frames may not be linked duplicates')
   image_ids[cel.image.id]=true
   for pixel in cel.image:pixels() do
    if app.pixelColor.rgbaA(pixel())>0 then bottom=math.max(bottom,cel.position.y+pixel.y) end
   end
   assert(bottom==entry.pivot.y-1,'Foot baseline drift in '..entry.source..' frame '..i..' got '..bottom)
   assert(layers.Shadow:cel(i),'Shadow frame missing')
  end
  seen[entry.source]=true;count=count+1;s:close()
 end
end
assert(count==18,'Expected 18 sources')
print('RK073_SOURCES: passed')
