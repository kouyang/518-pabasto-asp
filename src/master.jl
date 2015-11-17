#master launches all worker and parameter server processes

#list of tuples (worker id, worker process reference)
workers=Tuple{Int,Any}[]

#list of param server process ids
paramservers=Int[]

function get_paramserver()
	return paramservers[1]
end
