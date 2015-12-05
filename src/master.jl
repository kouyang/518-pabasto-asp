using MNIST

# master launches all worker and parameter server processes

train_examples, train_labels = traindata()
num_train_examples = size(train_examples, 2)
num_processed_examples = 0
batch_size = 10

function handle_request(request::ExamplesRequestMessage)
	global num_train_examples
	global num_processed_examples
	global batch_size

	id = request.id
	channel = request.master_recv_channel
	examples = []

	count = 0;
	while count < batch_size && num_processed_examples < num_train_examples
		example_id = num_processed_examples + 1
		push!(examples, example_id)
		count = count + 1
		num_processed_examples = num_processed_examples + 1
	end

	put!(channel, ExampleIndicesMessage(examples));
	println("[MASTER] Assigned examples $(examples) to worker $(id)")
end

function master(master_channel, pserver_gradient_update_channel, pserver_update_request_channel,pserver_ids,worker_ids)
	while true
		if isready(master_channel)
			handle_request(take!(master_channel))
		end
		while isready(pserver_gradient_update_channel)
			remotecall(handle,pserver_ids[rand(1:end)],take!(pserver_gradient_update_channel))
		end
		while isready(pserver_update_request_channel)
			remotecall(handle,pserver_ids[rand(1:end)],take!(pserver_update_request_channel))
		end
	end
end
