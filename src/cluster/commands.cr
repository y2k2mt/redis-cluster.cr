module Redis::Cluster::Commands
  abstract def redis(key : String) : Redis

  # [proxy] macro
  # "proxy get, key" generates
  #
  # def get(key)
  #   redis(key).get(key)
  # rescue moved : Redis::Error::Moved
  #   on_moved(moved)
  #   redis(key).get(key)
  # rescue ask : Redis::Error::Ask
  #   redis(Addr.parse(ask.to)).get(key)
  # end

  macro proxy(name, *args)
    def {{ name.id }}({{ args.join(",").id }})
      redis(key).{{ name.id }}({{ args.join(",").id }})
    rescue moved : Redis::Error::Moved
      on_moved(moved)
      redis(key).{{ name.id }}({{ args.join(",").id }})
    rescue ask : Redis::Error::Ask
      redis(Addr.parse(ask.to)).{{ name.id }}({{ args.join(",").id }})
    rescue err : Errno
      redis(key).{{ name.id }}({{ args.join(",").id }})
    end
  end

  proxy get, key
  proxy set, key, val

  # **Return value**: -1 when redis level error
  def counts : Counts
    nodes.reduce(Counts.new) do |h, n|
      h[n] = (redis(n.addr).count rescue -1.to_i64)
      h
    end
  end

  # **Return value**: error message is stored in value when redis level error
  def info(field : String = "v,cnt,m,d")
    nodes.reduce(Hash(NodeInfo, Array(InfoExtractor::Value)).new) do |hash, node|
      begin
        info = InfoExtractor.new(redis(node.addr).info)
        keys = field.split(",").map(&.strip)
        hash[node] = keys.map{|k| info.extract(k)}
      rescue err
        hash[node] = [err.to_s.as(InfoExtractor::Value)]
      end
      hash
    end
  end
end
