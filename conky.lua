function conky_format(format, number)
  return string.format(format, conky_parse(number))
end

function splitCsv(vals, conky)
  local tab = {}
  if conky then
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
  local calc = 255 - perc * 255
  return string.format("${color " .. yellow .. "}", calc, calc, calc)
end


function execShRetRes(cmd)
  local handle = io.popen(cmd)
  local res = string.format("%s", handle:read("*a"))
  handle:close()
  return res
end

nproc = tonumber(execShRetRes("nproc"))
cpuName = execShRetRes([[lscpu | grep "Model name:" | sed 's/.*:[ ]\+//g']])

function conky_getCpu(width, vals)
  local i = 1
  local cpuP = splitCsv(vals, true)
  local cpu0 = table.remove(cpuP, 1)
  local out = cpuName ..
  [[${hwmon 0 temp 1}C]] .. conky_colorPercentage(cpu0) .. [[${alignr}${freq} MHz ]] .. string.format("%3.0f", cpu0) .. [[%
${color}${cpugraph cpu0 30}
Threads
]]
  while i < nproc do
    local to = 0
    local title = true
    if i + 3 <= nproc then
      to = i + 3
    else
      to = nproc
    end
    out = out .. string.format([[${color}%02i-%02i: ]], i, to)
    for j = i, to, 1 do
      out = out .. string.format("%s${cpubar cpu%i 5,%i} %3.0f%% ", conky_colorPercentage(cpuP[j]), j, width, cpuP[j])
    end
    out = out .. [[${color}
]]
    i = i + 4
  end
  out = string.gsub(out, ".$", "")
  return out
end

-- inception style lua_parse call to take cpu values and minimize lua_parses in conky
function conky_inceptionGetCpu(width)
  local width = width or 26
  out = "${lua_parse getCpu " .. width .. " "
  for i = 0, nproc, 1 do
    out = out .. string.format([[${cpu cpu%i}]], i )
    if i ~= nproc then
      out = out .. ","
    end
  end
  out = out .. [[}]]
  return out
end


function getNet(name, height, width)
  height = height or 30
  width = width or 150
  local out = [[<ifname>: ${addr <ifname>}
▼ ${downspeed <ifname>} ${alignr}▲ ${upspeed <ifname>}
${downspeedgraph <ifname> <height>,<width>} ${alignr}${upspeedgraph <ifname> <height>,<width>}
∑ ${totaldown <ifname>} ${alignr}∑ ${totalup <ifname>}]]
  out = string.gsub(out, "<ifname>", name)
  out = string.gsub(out, "<height>", height)
  out = string.gsub(out, "<width>", width)
  return out
end

lan = execShRetRes([[ip link | grep -oPz 'enp.*(?=:)' | head -n 1]])
wlan = execShRetRes([[ip link | grep -oPz 'wlp.*(?=:)' | head -n 1]])

function conky_net(height, width)
  local res = ""
  if lan ~= '' then
    res = getNet(lan, height, width) .. "\n\n"
  end
  if wlan ~= '' then
    res = res .. getNet(wlan, height, width)
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
  local used = tonumber(tab[2]) * d
  local total = tonumber(tab[3]) * d
  local perc = used / total * 100
  gpuUtil = tab[4]
  gpuMem = perc
  local ostr = string.format([[NVIDIA %s
%iC ${alignr}%iMHz %3i%%
${lua_graph conky_retGpuUtil 30}
GPU RAM ${alignr}%0.2fGiB / %0.2fGiB %3i%%
${lua_graph conky_retGpuMem 30}]], tab[1], tab[6], tab[5], tab[4], used, total, perc)
  return ostr
end
