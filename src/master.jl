#master launches all worker and parameter server processes

#list of tuples (worker id, worker process reference, id of paramserver that controls worker, master_channel, pserver_recv_channel, pserver_send_channel)
workers=Tuple{Int, Any, Int, Any, Any, Any}[]

#list of tuples of (param server process id, master_channel)
paramservers=Tuple{Int, Any}[]