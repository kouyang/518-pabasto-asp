# master launches all worker and parameter server processes

# list of tuples (worker id, worker process reference, master_recv_channel)
workers = Tuple{Int, Any, Any}[]

# list of tuples of (param server process id, param server process reference, master_recv_channel)
paramservers = Tuple{Int, Any, Any}[]

master_channel = RemoteChannel(() -> Channel(PABASTO.num_workers * 10), 1);

pserver_gradient_update_channel = RemoteChannel(() -> Channel(PABASTO.num_workers * 10), 1);
pserver_update_request_channel = RemoteChannel(() -> Channel(PABASTO.num_workers * 10), 1);

example_indices = collect(1:50)
examples_per_worker = Dict()

function partition_examples()
	for e in example_indices
		w = PABASTO.get_worker(e)
		if (!haskey(examples_per_worker, w))
			examples_per_worker[w] = []
		end
		push!(examples_per_worker[w], e)
	end
end

function master()
	while true
		if !isready(master_channel)
			continue
		end
		request = take!(master_channel)
		id = request.id
		channel = request.master_recv_channel
		examples = []
		for i in 1:10
			if (isempty(examples_per_worker[id]))
				break
			end
			push!(examples, 1)
			deleteat!(examples_per_worker[id], 1)
		end
		put!(channel, ExampleIndicesMessage(examples));
		println("[MASTER] Assigned more examples to worker ", id)
	end
end

function get_pserver_gradient_update_channel()
	if isready(pserver_gradient_update_channel)
		return take!(pserver_gradient_update_channel)
	else
		return nothing
	end
end

function get_pserver_update_request_channel()
	if isready(pserver_update_request_channel)
		return take!(pserver_update_request_channel)
	else
		return nothing
	end
end

