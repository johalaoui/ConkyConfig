local heightBar = 0
local heightGraph = 0
local widthBarThread = 0
local widthGraphNet = 0

function conky_format(format, number)
  return string.format(format, conky_parse(number))
end

function splitCsv(vals, fromConky)
  local tab = {}
  if fromConky then
    vals = conky_parse(vals)
  end
  for s in string.gmatch(vals, "[^,]+") do
    table.insert(tab, s)
  end
  return tab
end

yellow = "#ffff%02x"
red = "#ff%02x%02x"
p = 1 / 100

-- %02x -> x: hex, 2: 2 chars, 0: default char, %: string.format insert
-- example 255=ff or 0=00
-- keep conky beginning for other usecases
function conky_colorPercentage(percentage)
  local perc = conky_parse(percentage) * p
  local calc = math.floor(255 - perc * 255)
  return string.format("${color " .. yellow .. "}", calc, calc, calc)
end


function execShRetRes(cmd)
  local handle = io.popen(cmd)
  local res = string.format("%s", handle:read("*a"))
  handle:close()
  return res
end

function conky_setSizes(newHeightBar, newHeightGraph, newWidthBarThread, newWidthGraphNet)
  heightBar = conky_parse(newHeightBar)
  heightGraph = conky_parse(newHeightGraph)
  widthBarThread = conky_parse(newWidthBarThread)
  widthGraphNet = conky_parse(newWidthGraphNet)
  return ""
end

nproc = tonumber(execShRetRes("nproc"))
cpuName = execShRetRes([[lscpu | grep "Model name:" | sed 's/.*:[ ]\+//g']])

function getCpuValues()
  local i = 0
  local parse_cpus = ""
  for i = 1, nproc, 1 do
    parse_cpus = parse_cpus .. string.format("${cpu cpu%i},", i)
  end
  parse_cpus = parse_cpus .. "${cpu cpu0}"
  return conky_parse(parse_cpus)
end

function conky_getCpu()
  local i = 0
  local cpuP = splitCsv(getCpuValues(), true)
  local cpu0 = cpuP[nproc + 1]
  -- /sys/class/hwmon/hwmon*
  local out = cpuName ..
  [[${hwmon 0 temp 1}C]] .. conky_colorPercentage(cpu0) .. [[${alignr}${freq} MHz ]] .. string.format("%3.0f", cpu0) .. [[%
${color}${cpugraph cpu0 ]] .. heightGraph .. [[}
Threads
]]
  for i = 1, nproc, 4 do
    local to = math.min(i + 3, nproc)
    local title = true
    out = out .. string.format([[${color}%02i-%02i: ]], i, to)
    for j = i, to, 1 do
      out = out .. string.format("%s${cpubar cpu%i %i,%f} %3.0f%% ", conky_colorPercentage(cpuP[j]), j, heightBar, widthBarThread, cpuP[j])
    end
    out = out .. [[${color}
]]
  end
  out = string.gsub(out, ".$", "")
  return out
end

function getNet(name)
  local out = [[<ifname>: ${addr <ifname>}
▼ ${downspeed <ifname>} ${alignr}▲ ${upspeed <ifname>}
${downspeedgraph <ifname> <height>,<width>} ${alignr}${upspeedgraph <ifname> <height>,<width>}
∑ ${totaldown <ifname>} ${alignr}∑ ${totalup <ifname>}]]
  out = string.gsub(out, "<ifname>", name)
  out = string.gsub(out, "<height>", heightGraph)
  out = string.gsub(out, "<width>", widthGraphNet)
  return out
end

nets = splitCsv(execShRetRes([[ip link | grep -oPz '(?<=: )(enp|wlp|usb).*(?=:)' | tr '\0' ',']]))

function conky_net()
  local res = ""
  for _, n in pairs(nets) do
    res = res .. getNet(n) .. "\n\n"
  end
  return res
end

-- needed for lua_graph usage below
function conky_retGpuUtil()
  return gpuUtil
end

function conky_retGpuMem()
  return gpuMem
end

d = 1 / 1024
function conky_gpuInfo()
  local result = execShRetRes([[ \
    nvidia-smi \
      --query-gpu=gpu_name,memory.used,memory.total,utilization.gpu,clocks.sm,temperature.gpu \
      --format=csv,nounits,noheader]])
  local tab = splitCsv(result)
  if tab[1] == nil then
    return ''
  end
  local memUsed = tonumber(tab[2]) * d
  local memTotal = tonumber(tab[3]) * d
  local memPerc = memUsed / memTotal * 100
  gpuUtil = tab[4]
  gpuMem = memPerc
  local ostr = string.format([[NVIDIA %s
%iC ${alignr}%iMHz %3i%%
${lua_graph conky_retGpuUtil <height>}
GPU RAM ${alignr}%0.2fGiB / %0.2fGiB %3.0f%%
${lua_graph conky_retGpuMem <height>}]], tab[1], tab[6], tab[5], tab[4], memUsed, memTotal, memPerc)
  ostr = string.gsub(ostr, "<height>", heightGraph)
  return ostr
end
