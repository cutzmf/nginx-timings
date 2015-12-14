local function round(num, idp)
    if idp and idp>0 then
	local mult = 10^idp
	return math.floor(num * mult + 0.5) / mult
    end
    return math.floor(num + 0.5)
end

local function tablelength( T )
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

local function minmax( T )
    local max = -math.huge
    local min = math.huge

    for k,v in pairs( T ) do
    if type(v) == 'number' then
      max = math.max( max, v )
      min = math.min( min, v )
    end
    end

    return min, max
end

function log(ngx_shared_dict, key, trim)
    local function _inc(_key)
	local newval, err = ngx_shared_dict:incr(_key, 1)
	if not newval and err == "not found" then
	    ngx_shared_dict:add(_key, 0)
	    ngx_shared_dict:incr(_key, 1)
	end
    end

    local rq_time = round(ngx.now() - ngx.req.start_time(), trim)
    if not (key == nil or key == '') then key=key..":" end

    _inc(key.."ngx_status:"..ngx.status)
    if ngx.status == ngx.HTTP_OK then
	_inc(key.."ngx_req_time:"..rq_time)

	_inc(key.."last_500_counter")
	local last_500_counter = ngx_shared_dict:get(key.."last_500_counter")
	if last_500_counter == 500 then
	    ngx_shared_dict:set(key.."last_500_counter", 1)
	end
	ngx_shared_dict:set(key.."last_500:"..last_500_counter, rq_time)

    end
end

function printall(ngx_shared_dict)
    for _,v in pairs(ngx_shared_dict:get_keys()) do
	ngx.say(v, " ", ngx_shared_dict:get(v))
    end
end

local function time_buckets(ngx_shared_dict, key)
    local bucket = {}
    local total = 0
    local _match
    if key == nil or key == '' then
	_match="([%a_]+):([%d.]+)"
    else
	_match=key..":([%a_]+):([%d.]+)"
    end

    for _,v in pairs(ngx_shared_dict:get_keys()) do
	ngx_,time = v:match(_match)

	if ngx_ == "ngx_req_time" then
	    bucket[time] = ngx_shared_dict:get(v)
	    total = total + bucket[time]
	end
    end

    local sorted = {}
    for k,v in pairs(bucket) do table.insert(sorted, k) end
    table.sort(sorted)
    return bucket, sorted, total
end

local function last_500_buckets(ngx_shared_dict, key)
    local bucket = {}
    local total = 0
    local _match
    if key == nil or key == '' then
	_match="(last_500):([%d]+)"
    else
	_match=key..":(last_500):([%d]+)"
    end

    for _,v in pairs(ngx_shared_dict:get_keys()) do
	ngx_, counter = v:match(_match)

	if ngx_ == "last_500" then
	    bucket[counter] = ngx_shared_dict:get(v)
	    total = total + bucket[counter]
	end
    end
    return bucket, total
end

function percentile(ngx_shared_dict, key, percent)
    local bucket, sorted, total = time_buckets(ngx_shared_dict, key)
    local percentile = round(total*percent,0)
    local count = 0
    for _,time in ipairs(sorted) do
	count = count + bucket[time]
	if count > percentile then
	    result = time
	    break
	end
    end
    return result
end

function max(ngx_shared_dict, key)
    local bucket, sorted, total = time_buckets(ngx_shared_dict, key)
    return sorted[table.getn(sorted)]
end

function min(ngx_shared_dict, key)
    local bucket, sorted, total = time_buckets(ngx_shared_dict, key)
    return sorted[1]
end

function avg500(ngx_shared_dict, key)
    local bucket, total = last_500_buckets(ngx_shared_dict, key)
    tablelength(bucket)
    return total/tablelength(bucket)
end

function min500(ngx_shared_dict, key)
    local bucket, total = last_500_buckets(ngx_shared_dict, key)
    local min, max = minmax(bucket)
    return min
end

function max500(ngx_shared_dict, key)
    local bucket, total = last_500_buckets(ngx_shared_dict, key)
    local min, max = minmax(bucket)
    return max
end
