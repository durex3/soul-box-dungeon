-- Explicit one-off native source revision for the RK-073 review return.
-- Not called by normal export. Edits only the four Body cels of the ordinary zombie.
local path=assert(app.params.source)
local sprite=assert(app.open(path))
assert(sprite.width==16 and sprite.height==16 and #sprite.frames==4)
local body=nil
for _,layer in ipairs(sprite.layers) do if layer.name=='Body' then body=layer end end
assert(body)
local pc=app.pixelColor
local function rgb(r,g,b) return pc.rgba(r,g,b,255) end
local green=rgb(58,107,63);local shirt=rgb(122,115,147)
local dark=rgb(26,20,38);local boot=rgb(74,59,51);local bone=rgb(237,227,204)
for frame=1,4 do
 local image=Image(16,16,ColorMode.RGB)
 local function px(x,y,c) assert(x>=0 and x<16 and y>=0 and y<16);image:drawPixel(x,y,c) end
 local function rect(x,y,w,h,c) for yy=y,y+h-1 do for xx=x,x+w-1 do px(xx,yy,c) end end end
 local b=(frame-1)%2
 -- Distinct head, narrow neck, slim torso, projected elbow/forearm.
 rect(5,2-b,4,3,green);px(8,3-b,bone)
 rect(6,5-b,1,1,green)
 rect(5,6-b,3,3+b,shirt)
 px(8,6-b,green);px(9,7-b,green);rect(10,7-b,4,1,green)
 rect(5,8,5,1,shirt)
 if frame==4 then
  -- Alternating walking stance keeps the foot baseline and center fixed.
  px(6,9,boot);px(5,10,boot);rect(4,11,2,1,boot)
  px(9,9,boot);px(10,10,boot);rect(11,11,2,1,boot)
 else
  rect(6,9,1,3,boot);rect(10,9,1,3,boot)
  rect(5,11,2,1,boot);rect(10,11,2,1,boot)
 end
 local raw=Image(image)
 for y=0,15 do for x=0,15 do
  if pc.rgbaA(raw:getPixel(x,y))==0 then
   for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
    local xx,yy=x+d[1],y+d[2]
    if xx>=0 and xx<16 and yy>=0 and yy<16 and pc.rgbaA(raw:getPixel(xx,yy))>0 then px(x,y,dark);break end
   end
  end
 end end
 sprite:deleteCel(body,frame)
 sprite:newCel(body,frame,image,Point(0,0))
end
sprite:saveAs(path);sprite:close()
print('RK073_ZOMBIE_REVISION: saved native source')
