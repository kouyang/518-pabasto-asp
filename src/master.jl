#master launches all worker and parameter server processes

#list of tuples (worker id, worker process reference, master_recv_channel, master_send_channel)
workers=Tuple{Int, Any, Any, Any}[]

#list of tuples of (param server process id, master_recv_channel, master_send_channel)
paramservers=Tuple{Int, Any, Any}[]