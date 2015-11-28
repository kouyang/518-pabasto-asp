# master launches all worker and parameter server processes


function partition_examples(example_indices, examples_per_worker)
	for e in example_indices
		w = PABASTO.get_worker(e)
		if (!haskey(examples_per_worker, w))
			examples_per_worker[w] = []
		end
		push!(examples_per_worker[w], e)
	end
end

function master(master_channel)
	example_indices = collect(1:50)
	examples_per_worker = Dict()
	partition_examples(example_indices, examples_per_worker)
	while true
		#take blocks until an item is available
		request = take!(master_channel)
		id = request.id
		channel = request.master_recv_channel
		examples = []
		for i in 1:10

			#there is a new worker!
			if !haskey(examples_per_worker,id)
				add_worker_hash(id)
				examples_per_worker=Dict()
				#repartition examples
				partition_examples(example_indices,examples_per_worker)
				#the current partition
				println("[MASTER] current job assignment: $(examples_per_worker)")
			end
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

