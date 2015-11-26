hash_circle = Dict()

function add_worker_hash(index)
	hash_circle[hash(index)] = index
end

function remove_worker_hash(index)
	pop!(hash_circle, hash(index), nothing)
end

function get_worker(key)
	if isempty(hash_circle)
		return nothing
	end

	hash_code = hash(key)
	hc_keys = keys(hash_circle)
	f = filter(k -> (hash_code <= k), hc_keys)
	return isempty(f) ? hash_circle[minimum(hc_keys)] : hash_circle[minimum(f)]
end
