using JSON

export EtcdServer

type EtcdServer
    ip::String
    port::Int
    version::String
    EtcdServer(ip::String="127.0.0.1",
               port::Int=4001) = new(ip,port,"v2")
end

# default to Requests
http_lib(method::Symbol) = Expr(:.,:Requests,QuoteNode(method))

function etcd_request(http_method,key::String,options=Dict{String,Any}())
    debug("Etcd $http_method called with:",{:key => key, :options => options})
    try
        if isempty(options)
            etcd_response = eval(Expr(:call,http_lib(http_method),key))
        else
            etcd_response = eval(Expr(:call,http_lib(http_method),
                                      key,Expr(:kw,:query,options)))
        end
        etcd_response.data
    catch err
        warn("$http_method Request to server failed with $err")
    end
end

function check_etcd_error(etcd_response)
    if isa(etcd_response,Dict) && haskey(etcd_response,"errorCode")
        ec = etcd_response["errorCode"]
        warn("Request failed with error code $(ec)",
             {:reason => Base.get(etcd_errors,ec,"Unknown Error")})
    end
    etcd_response
end

function check_etcd_response(etcd_response)
    if isa(etcd_response,Dict) && haskey(etcd_response,"errorCode")
        ec = etcd_response["errorCode"]
        warn("Request failed with error code $(ec)",
             {:reason => Base.get(etcd_errors,ec,"Unknown Error")})
    end
    try
        JSON.parse(etcd_response)
    catch _
        etcd_response
    end
end

function machines(etcd::EtcdServer)
    etcd_request(:get,"http://$(etcd.ip):$(etcd.port)/$(etcd.version)/machines") |>
    check_etcd_error
end
