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

function master(master_channel)
	while true
		# take blocks until an item is available
		handle_request(take!(master_channel))
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
