using MNIST

# master launches all worker and parameter server processes

train_examples, train_labels = traindata()
num_train_examples = size(train_examples, 2)
num_processed_examples = 0

# parameters for adaptive control policy
tau = 5.0;
num_workers = 3;
num_paramservers = 1;
# number of examples to be sent to worker in response to ExamplesRequestMessage
example_batch_size = 50;
# number of examples worker should process to compute one gradient update
batch_size = 10;

#REMOVE LATER
num_train_examples = 1000;
#REMOVE LATER
flag = true;

type MasterState
	master_mailbox
	pservers
	workers
end

function handle(state::MasterState,request::ExamplesRequestMessage)
	global num_train_examples
	global num_processed_examples
	global batch_size
	
	if num_processed_examples >= num_train_examples
		# all examples have been processed
		# shut down workers
		
		shutdown_msg = CeaseOperationMessage();
		
		for worker_tup in state.workers
			worker_mailbox = worker_tup[3];
			put!(worker_mailbox, shutdown_msg);
		end
		
		return false;
	end
	
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
	
	return true;
end

function handle(state::MasterState,msg::GradientUpdateMessage)
	println("[MASTER] Dispatching GradientUpdateMessage")
	remotecall(handle,state.pservers[rand(1:end)][1],msg)
	return true;
end

function handle(state::MasterState,msg::ParameterUpdateRequestMessage)
	println("[MASTER] Dispatching ParameterUpdateRequestMessage")
	remotecall(handle,state.pservers[rand(1:end)][1],msg)
	return true;
end

function handle(state::MasterState,msg::Void)
	println("[MASTER] Spinning")
	sleep(1)
	return true;
end

function master(master_mailbox,paramservers, workers)
	global tau
	global num_workers
	global num_paramservers
	global examples_batch_size
	global batch_size
	
	state=MasterState(master_mailbox, paramservers,workers)
	
	while true
		boo = handle(state,take!(state.master_mailbox));
		
		# if false, shut down master
		if !boo
			break
		end
		
		#=
			msg = AdaptiveControlPolicyMessage(tau, num_workers, num_paramservers, examples_batch_size, batch_size);
			for i = 1:length(workers)
				worker_tup = workers[i];
				worker_mailbox = worker_tup[3];
				put!(worker_mailbox, msg);
			end
			println("[MASTER] Control Policy Messages Sent");
		=#
	end
end

function adaptive_control_policy()
	global tau
	global num_workers
	global num_paramservers
	global examples_batch_size
	global batch_size
	global flag
	
	randy = RandomDevice();
	
	if flag
		tau = tau + 1.0;
		flag = false;
		return true;
	else
		return false;
	end
end
