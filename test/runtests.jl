using Base.Test
include("../src/Etcd.jl")
include("etcd_mock.jl")

# XXX ideally this macro would create that temp func and use that
# instead of this interface here
@etcd_mock test_machines(et) = Etcd.machines(et)
@etcd_mock test_set(et,k,v,t) = Etcd.set(et,k,v,ttl=t)
@etcd_mock test_update(et,k,v,t) = Etcd.update(et,k,v,ttl=t)
@etcd_mock test_create(et,k,v,t) = Etcd.create(et,k,v,ttl=t)
@etcd_mock test_get(et,k,s,r) = Etcd.get(et,k,sort=s,recursive=r)
@etcd_mock test_create_dir(et,k,t) = Etcd.create_dir(et,k,ttl=t)
@etcd_mock test_update_dir(et,k,t) = Etcd.update_dir(et,k,ttl=t)
@etcd_mock test_add_child(et,k,v,t) = Etcd.add_child(et,k,v,ttl=t)
@etcd_mock test_add_child_dir(et,k,t) = Etcd.add_child_dir(et,k,ttl=t)
@etcd_mock test_delete(et,k) = Etcd.delete(et,k)
@etcd_mock test_set_dir(et,k,t) = Etcd.set_dir(et,k,ttl=t)
@etcd_mock test_delete_dir(et,k,r) = Etcd.delete_dir(et,k,recursive=r)
@etcd_mock test_compare_and_delete(et,k,prvv,prvi) = Etcd.compare_and_delete(et,k,
                                                                             prev_value=prvv,
                                                                             prev_index=prvi)
@etcd_mock test_compare_and_swap(et,k,v,pv,previ,t) = Etcd.compare_and_swap(et,k,v,
                                                                            prev_value=pv,
                                                                            prev_index=previ,
                                                                            ttl=t)

function setup_etcd()
    et = Etcd.EtcdServer()
    println("Etcd server created at: ",et)
    et
end

function test_etcd_machines(et)
    mach = test_machines(et)
    @test mach == "http://127.0.0.1:4001"
end

function test_etcd_set(et)
    key = "/test"
    val = "testvalue"
    set_node = test_set(et,key,val,5)
    @test haskey(set_node,"node")
    @test haskey(set_node["node"],"key")
    @test set_node["node"]["key"] == key
    @test haskey(set_node["node"],"value")
    @test set_node["node"]["value"] == val
    @test set_node["node"]["ttl"] == 5
end

function test_etcd_update(et)
    key = "/test_update"
    val = "update-val"
    new_val = "updatED-val"

    test_set(et,key,val,5)

    update = test_update(et,key,"updatED-val",5)
    @test update["action"] == "update"
    @test update["node"]["key"] == key
    @test update["node"]["ttl"] == 5
    @test update["node"]["value"] == new_val
    @test update["prevNode"]["key"] == key
    @test update["prevNode"]["value"] == val

    # This should fail because the key does not exist.
    update = test_update(et,"/nonexistent-key","anything",5)
    @test haskey(update,"errorCode")
end

function test_etcd_create(et)
    key = "/test_create"
    val = "create-val"

    # this should succeed
    created = test_create(et,key,val,5)
    @test haskey(created,"errorCode") == false
    @test haskey(created,"prevNode") == false
    @test created["action"] == "create"
    @test created["node"]["key"] == key
    @test created["node"]["value"] == val
    @test created["node"]["ttl"] == 5

    # this should fail since the key has been already created
    created = test_create(et,key,val,6)
    @test haskey(created,"errorCode")
end

function test_etcd_set_dir(et)
    key = "/set_dir"
    value = "bar"
    ttl = 5
    # set it
    set_node = test_set(et,key,value,ttl)
    @test haskey(set_node,"errorCode") == false

    # This should succeed it should replace the key
    set_dir = test_set_dir(et,key,5)
    @test set_dir["node"]["key"] == key
    @test haskey(set_dir["node"],"value") == false
    @test set_dir["node"]["ttl"] == 5
    @test set_dir["prevNode"]["key"] == key
    @test set_dir["prevNode"]["value"] == value
    @test set_dir["prevNode"]["ttl"] == 5
end

function test_etcd_update_dir(et)
    key = "/update_dir"

    # make sure creating dir doesn't fail
    cr = test_create_dir(et,key,5)
    @test haskey(cr,"errorCode") == false

    # updating the directory should succeed
    up_dir = test_update_dir(et,key,5)
    @test up_dir["action"] == "update"
    @test up_dir["node"]["key"] == key
    @test haskey(up_dir["node"],"value") == false
    @test up_dir["node"]["ttl"] == 5
    @test up_dir["prevNode"]["key"] == key
    @test haskey(up_dir["prevNode"],"value") == false
    @test up_dir["prevNode"]["ttl"] == 5
    @test up_dir["prevNode"]["dir"] == true

    # updating a non-exitent key should fail
    up_dir = test_update_dir(et,"/nonexistent_key",5)
    @test haskey(cr,"errorCode") == false
end

function test_etcd_create_dir(et)
    key = "/create_dir"
    # make sure creating dir doesn't fail
    cr = test_create_dir(et,key,5)
    @test haskey(cr,"errorCode") == false
    @test cr["action"] == "create"
    @test cr["node"]["key"] == key
    @test haskey(cr["node"],"value") == false
    @test cr["node"]["ttl"] == 5
    @test haskey(cr,"prevNode") == false

    # This should fail, because the key is already there
    cr = test_create_dir(et,key,6)
    @test haskey(cr,"errorCode")
end

function test_etcd_get(et)
    key = "/foo"
    value = "bar"
    ttl = 5
    # set it
    set_node = test_set(et,key,value,ttl)
    # then get it
    get_node = test_get(et,key,false,false)
    @test haskey(get_node,"node")
    @test haskey(get_node["node"],"key")
    @test get_node["node"]["key"] == key
    @test haskey(get_node["node"],"value")
    @test get_node["node"]["value"] == value
end

function test_etcd_get_all(et)
    # create dir
    d_name = "/fooDir"
    ttl = 5
    dir = test_create_dir(et,d_name,ttl)
    k0 = test_set(et,"/fooDir/k0", "v0", ttl)
    k1 = test_set(et,"/fooDir/k1", "v1", ttl)

    # Return kv-pairs in sorted order
    nodes = test_get(et,d_name,true,false)
    @test length(nodes["node"]["nodes"]) == 2
    @test nodes["node"]["nodes"][1]["key"] == "/fooDir/k0"
    @test nodes["node"]["nodes"][1]["value"] == "v0"
    @test nodes["node"]["nodes"][1]["ttl"] == ttl

    @test nodes["node"]["nodes"][2]["key"] == "/fooDir/k1"
    @test nodes["node"]["nodes"][2]["value"] == "v1"
    @test nodes["node"]["nodes"][2]["ttl"] == ttl

    ch_dir = test_create_dir(et,d_name*"/childDir",ttl)
    k2 = test_set(et,d_name*"/childDir/k2", "v2", ttl)

    # recursively get kv-pairs in sorted order
    nodes = test_get(et,d_name,true,true)
    @test length(nodes["node"]["nodes"]) == 3
    @test nodes["node"]["nodes"][1]["nodes"][1]["key"] == "/fooDir/childDir/k2"
    @test nodes["node"]["nodes"][1]["nodes"][1]["value"] == "v2"
    @test nodes["node"]["nodes"][1]["nodes"][1]["ttl"] == ttl

    @test nodes["node"]["nodes"][2]["key"] == "/fooDir/k0"
    @test nodes["node"]["nodes"][2]["value"] == "v0"
    @test nodes["node"]["nodes"][2]["ttl"] == ttl

    @test nodes["node"]["nodes"][3]["key"] == "/fooDir/k1"
    @test nodes["node"]["nodes"][3]["value"] == "v1"
    @test nodes["node"]["nodes"][3]["ttl"] == ttl
end

function test_etcd_add_child(et)
    d_name = "/booDir"
    ch_dir = test_create_dir(et,d_name,5)
    c1 = test_add_child(et,d_name,"v0",5)
    c2 = test_add_child(et,d_name,"v1",5)

    nodes = test_get(et,d_name,true,false)
    @test length(nodes["node"]["nodes"]) == 2
    @test nodes["node"]["nodes"][1]["value"] == "v0"
    @test nodes["node"]["nodes"][2]["value"] == "v1"

    # Creating a child under a nonexistent directory should succeed.
    # The directory should be created.
    c3 = test_add_child(et,"/nonexistentDir","foo",5)
    @test c3["node"]["value"] == "foo"
end

function test_etcd_add_child_dir(et)
    d_name = "/looDir"
    ch_dir = test_create_dir(et,d_name,5)
    c1 = test_add_child_dir(et,d_name,5)
    c2 = test_add_child_dir(et,d_name,6)

    nodes = test_get(et,d_name,true,false)
    @test length(nodes["node"]["nodes"]) == 2
    @test nodes["node"]["nodes"][1]["ttl"] == 5
    @test nodes["node"]["nodes"][2]["ttl"] == 6

    # Creating a child under a nonexistent directory should succeed.
    # The directory should be created.
    c3 = test_add_child_dir(et,"/nonexistentDir",5)
    @test haskey(c3["node"],"key")
end

function test_etcd_delete(et)
    key = "/foo"
    value = "baz"
    ttl = 5
    set_node = test_set(et,key,value,ttl)
    # delete node
    del_node = test_delete(et,key)
    @test del_node["prevNode"]["value"] == value
end

function test_etcd_delete_dir(et)
    test_set_dir(et,"/foo",5)
    # test delete an empty dir
    del_dir = test_delete_dir(et,"/foo",false)

    @test haskey(del_dir["node"],"value") == false
    @test del_dir["prevNode"]["dir"] == true
    @test haskey(del_dir["prevNode"],"value") == false

    # test ability to not delete a non-empty directory
    d_name = "/gooDir"
    ttl = 5
    dir = test_create_dir(et,d_name,ttl)
    foo = test_set(et,d_name*"/goo", "gar", ttl)
    del_dir = test_delete_dir(et,d_name,false)
    @test haskey(del_dir,"errorCode")

    del_dir = test_delete_dir(et,d_name,true)
    @test del_dir["prevNode"]["dir"] == true
    @test haskey(del_dir["prevNode"],"value") == false
    @test haskey(del_dir["node"],"value") == false
end

function test_etcd_compare_and_delete(et)
    key = "/test_c_and_d"
    val = "testvalue"
    set_node = test_set(et,key,val,5)

    cd = test_compare_and_delete(et,key,val,nothing)
    @test cd["prevNode"]["value"] == val
    @test cd["prevNode"]["key"] == key
    @test cd["prevNode"]["ttl"] == 5

    # verify that wrong value fails
    set_node = test_set(et,key,val,6)
    index = set_node["node"]["modifiedIndex"]

    cd = test_compare_and_delete(et,key,"wrongval",nothing)
    @test haskey(cd,"errorCode")

    # should succeed due to correct prevIndex
    cd = test_compare_and_delete(et,key,nothing,index)

    @test cd["prevNode"]["value"] == val
    @test cd["prevNode"]["key"] == key
    @test cd["prevNode"]["ttl"] == 6

    # test giving an incorrect index
    set_node = test_set(et,key,val,7)

    cd = test_compare_and_delete(et,key,nothing,123456)
    @test haskey(cd,"errorCode")
end

function test_etcd_compare_and_swap(et)
    key = "/test_c_and_s"
    val = "testvalue"
    set_node = test_set(et,key,val,5)

    cs = test_compare_and_swap(et,key,"newval",val,nothing,5)
    @test cs["node"]["value"] == "newval"
    @test cs["node"]["key"] == key
    @test cs["node"]["ttl"] == 5
    @test cs["prevNode"]["value"] == val
    @test cs["prevNode"]["key"] == key
    @test cs["prevNode"]["ttl"] == 5

    # verify that wrong prev value fails
    set_node = test_set(et,key,val,6)
    index = set_node["node"]["modifiedIndex"]

    cs = test_compare_and_swap(et,key,"wrongval","wrongprevval",nothing,5)
    @test haskey(cs,"errorCode")

    # swap by index
    cs = test_compare_and_swap(et,key,"newval",nothing,index,5)
    @test cs["node"]["value"] == "newval"
    @test cs["node"]["key"] == key
    @test cs["node"]["ttl"] == 5
    @test cs["prevNode"]["value"] == val
    @test cs["prevNode"]["key"] == key
    @test cs["prevNode"]["ttl"] == 6

    # test giving an incorrect previous index
    set_node = test_set(et,key,val,7)

    cs = test_compare_and_swap(et,key,val,nothing,123456,5)
    @test haskey(cs,"errorCode")
end

function test_etcd()
    et = setup_etcd()
    test_funcs = [test_etcd_machines,
                  test_etcd_set,
                  test_etcd_get,
                  test_etcd_get_all,
                  test_etcd_add_child,
                  test_etcd_add_child_dir,
                  test_etcd_delete,
                  test_etcd_delete_dir,
                  test_etcd_compare_and_delete,
                  test_etcd_compare_and_swap,
                  test_etcd_update,
                  test_etcd_create,
                  test_etcd_set_dir,
                  test_etcd_update_dir,
                  test_etcd_create_dir]
    [f(et) for f in test_funcs]
end

test_etcd()
