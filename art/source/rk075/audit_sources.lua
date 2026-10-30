-- Read-only audit of the final editable native sources.
local root=assert(app.params.root)
local f=assert(io.open(root..'/art/source/rk075/manifest.json'))
local entries=json.decode(f:read('*a')).assets;f:close()
local seen={};local count=0
for _,e in ipairs(entries) do
 if not seen[e.source] then
  local s=assert(app.open(root..'/'..e.source));local n=e.frame_size.w
  assert(s.width==n and s.height==n and #s.frames==4,'Native canvas/frames')
  assert(#s.tags==2 and #s.layers==2,'Exactly two tags/layers')
  assert(s.tags[1].name=='idle' and s.tags[1].fromFrame.frameNumber==1 and s.tags[1].toFrame.frameNumber==2,'Idle tag')
  assert(s.tags[2].name=='run' and s.tags[2].fromFrame.frameNumber==3 and s.tags[2].toFrame.frameNumber==4,'Run tag')
  local layers={};for _,l in ipairs(s.layers) do layers[l.name]=l;assert(l.isVisible and l.opacity==255,'Layer visibility/opacity') end
  assert(layers.Body and layers.Shadow,'Body/Shadow layers')
  local ids,poses={},{}
  for i,frame in ipairs(s.frames) do
   assert(math.abs(frame.duration-(i<=2 and 0.167 or 0.083))<0.00001,'Duration')
   local body=assert(layers.Body:cel(i));local shadow=assert(layers.Shadow:cel(i))
   assert(body.opacity==255 and shadow.opacity==255,'Cel opacity')
   assert(not ids[body.image.id],'No linked Body duplicates');ids[body.image.id]=true
   local bottom=-1;local pose={}
   for p in body.image:pixels() do
    local a=app.pixelColor.rgbaA(p())
    assert(a==0 or a==255,'Body alpha')
    if a>0 then
     local x,y=body.position.x+p.x,body.position.y+p.y
     assert(x>0 and x<n-1 and y>0 and y<n-1,'Body/weapon touches canvas edge')
     bottom=math.max(bottom,y);pose[#pose+1]=x..','..y..':'..p()
    end
   end
   assert(bottom==e.pivot.y-1,'Body foot baseline '..e.source..' frame '..i..' got '..bottom)
   poses[i]=table.concat(pose,';')
   for p in shadow.image:pixels() do
    local value=p();local a=app.pixelColor.rgbaA(value)
    assert(a==0 or (a==255 and app.pixelColor.rgbaR(value)==11 and app.pixelColor.rgbaG(value)==10 and app.pixelColor.rgbaB(value)==18),'Shadow color/alpha')
   end
  end
  assert(poses[1]~=poses[2] and poses[3]~=poses[4] and poses[1]~=poses[3],'Real idle and run pose differences')
  seen[e.source]=true;count=count+1;s:close()
 end
end
assert(count==2,'Exactly two native sources')
print('RK075_SOURCES: passed')
