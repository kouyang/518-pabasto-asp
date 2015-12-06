using MNIST

# master launches all worker and parameter server processes

train_examples, train_labels = traindata()
num_train_examples = size(train_examples, 2)
num_processed_examples = 0

# parameters for adaptive control policy
tau = 5
num_workers = 3
batch_size = 10

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

function handle(state::MasterState,msg::GradientUpdateMessage)
	println("[MASTER] Dispatching GradientUpdateMessage")
	remotecall(handle,state.pservers[rand(1:end)][1],msg)
end

function handle(state::MasterState,msg::ParameterUpdateRequestMessage)
	println("[MASTER] Dispatching ParameterUpdateRequestMessage")
	remotecall(handle,state.pservers[rand(1:end)][1],msg)
end

function handle(state::MasterState,msg::Void)
	println("[MASTER] Spinning")
	sleep(1)
end



function master(master_mailbox,paramservers, workers)
	state=MasterState(master_mailbox, paramservers,workers)
	
	while true
		handle(state,take!(state.master_mailbox))
		
		#=
			msg = AdaptiveControlPolicyMessage(tau, num_workers, batch_size);
			for i = 1:length(workers)
				worker_tup = workers[i];
				worker_control_channel = worker_tup[4];
				put!(worker_control_channel, msg);
			end
			println("[MASTER] Control Policy Messages Sent");
		=#
	end
end

function adaptive_control_policy()
	global tau
	global num_workers
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
