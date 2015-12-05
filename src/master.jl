using MNIST

train_examples, train_labels = traindata();
num_train_examples = size(train_examples, 2);
# 0 means not processed, 1 means processed
# use example id to index into array
train_examples_processed = zeros(num_train_examples, 1);
batch_size = 10;

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

function master(master_channel, pserver_gradient_update_channel, pserver_update_request_channel,pserver_ids,worker_ids)
	global num_train_examples
	global train_examples_processed
	global batch_size
	example_indices = collect(1:num_train_examples)
	examples_per_worker = Dict()
	partition_examples(example_indices, examples_per_worker)
	while true
		#take blocks until an item is available
		if isready(master_channel)
			request = take!(master_channel)
			id = request.id
			channel = request.master_recv_channel
			examples = []

			if !haskey(examples_per_worker, id)
				add_worker_hash(id)
				examples_per_worker=Dict()
				#repartition examples
				partition_examples(example_indices,examples_per_worker)
				#the current partition
				#println("[MASTER] current job assignment: $(examples_per_worker)")
			end

			worker_example_indices = examples_per_worker[id];
			count = 0;
			i = 1;

			while count < batch_size && i <= length(worker_example_indices)
				example_id = worker_example_indices[i];
				flag_proc = train_examples_processed[example_id];
				if flag_proc == 0
					push!(examples, example_id);
					train_examples_processed[example_id] = 1;
					count = count + 1;
				end
				i = i + 1;
			end

			#=
			for i in 1:10

				#there is a new worker!
				if !haskey(examples_per_worker,id)
					add_worker_hash(id)
					examples_per_worker=Dict()
					#repartition examples
					partition_examples(example_indices,examples_per_worker)
					#the current partition
					#println("[MASTER] current job assignment: $(examples_per_worker)")
				end
				if (isempty(examples_per_worker[id]))
					break
				end
				push!(examples, 1)
				deleteat!(examples_per_worker[id], 1)
			end
			=#


			#currently, all parameters are passed through the master
			#this we need parameters to be send directly from workers to paramservers
			put!(channel, ExampleIndicesMessage(examples));
			println("[MASTER] Assigned more examples to worker ", id)
		end
		while isready(pserver_gradient_update_channel)
			remotecall(handle,pserver_ids[rand(1:end)],take!(pserver_gradient_update_channel))
		end
		while isready(pserver_update_request_channel)
			remotecall(handle,pserver_ids[rand(1:end)],take!(pserver_update_request_channel))
		end
	end
end
