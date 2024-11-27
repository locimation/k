K =
  (function()
  local local_k = {}
  local callbacks = {}

  local k_client_id = bitstring.hexstream(Crypto.Digest("sha256", Crypto.GetRandomBytes(32)))

  local function publish(diff)
    Notifications.Publish("com.locimation.K", {k = diff, s = k_client_id})
  end

  _G._locimation_k_timer = Timer.New()
  local source_data = nil

  local function source_clear(data, t)
    if not t then
      t = source_data
    end
    for k, v in pairs(data) do
      if type(v) == "table" and type(t[k]) == "table" then
        t[k] = source_clear(v, t[k])
      else
        t[k] = nil
      end
    end
  end

  _G._locimation_k_timer.EventHandler = function()
    if not source_data then
      return
    end
    publish(source_data)
  end

  _G._locimation_k_timer:Start(10)

  local function extract(t, k)
    if not k or k == "" then
      return t
    end
    local value = t;
    for part in k:gmatch("([^.]+)") do
      value = value[part]
      if value == nil then
        return nil
      end
    end
    return value
  end

  local function deepcopy(t)
    if type(t) ~= "table" then
      return t
    end
    local new_t = {}
    for k, v in pairs(t) do
      if type(v) == "table" then
        new_t[k] = deepcopy(v)
      else
        new_t[k] = v
      end
    end
    return new_t
  end

  local function deepcompare(t1, t2)
    if type(t1) ~= "table" or type(t2) ~= "table" then
      return t1 == t2
    end
    for k, v in pairs(t1) do
      if not deepcompare(v, t2[k]) then
        return false
      end
    end
    for k, v in pairs(t2) do
      if not deepcompare(v, t1[k]) then
        return false
      end
    end
    return true
  end

  local function push_k(new_k)
    if type(new_k) ~= "table" then
      error("Invalid argument to push_k(): expected table")
    end
    local changes = {}
    for key in pairs(callbacks) do
      local old_value = extract(local_k, key)
      local new_value = extract(new_k, key)
      if not deepcompare(old_value, new_value) then
        changes[key] = deepcopy(new_value)
      end
    end
    local_k = new_k
    for key, new_value in pairs(changes) do
      for _, fn in ipairs(callbacks[key]) do
        fn(new_value)
      end
    end
  end

  local function merge(t1, t2)
    if type(t1) ~= "table" or type(t2) ~= "table" then
      return t2
    end
    local new_t = deepcopy(t1)
    for k in pairs(t2) do
      if type(t1[k]) == "table" and type(t2[k]) == "table" then
        new_t[k] = merge(t1[k], t2[k])
      else
        new_t[k] = t2[k]
      end
    end
    return new_t
  end

  local function init()
    Notifications.Subscribe(
      "com.locimation.K",
      function(_, message)
        if message.s == k_client_id then
          return
        end
        if source_data then
          source_clear(message.k)
        end
        push_k(merge(local_k, message.k))
      end
    )
  end

  local function now(diff)
    source_data = merge(source_data or {}, diff)
    push_k(merge(local_k, diff))
    publish(diff)
  end

  local function on(key, fn)
    if type(key) ~= "string" or type(fn) ~= "function" then
      error("Invalid arguments to on(): expected (string, function)")
    end
    if not callbacks[key] then
      callbacks[key] = {}
    end
    for _, existing_fn in ipairs(callbacks[key]) do -- prevent duplicate callbacks
      if existing_fn == fn then
        return
      end
    end
    table.insert(callbacks[key], fn)
  end

  local function off(key, fn)
    if not key then
      callbacks = {}
      return
    end
    if not callbacks[key] then
      return
    end
    local callbacks_filtered = {}
    if fn then
      for _, f in pairs(callbacks[key]) do
        if f ~= fn then
          table.insert(callbacks_filtered, f)
        end
      end
    end
    callbacks[key] = callbacks_filtered
  end

  local function set(str_key, value)
    local parts = {};
    for part in str_key:gmatch("([^.]+)") do
      table.insert(parts, 1, part)
    end
    for _, part in ipairs(parts) do
      value = {[part] = value}
    end
    now(value)
  end

  local function link(key, control, typ, options)
    if type(key) ~= "string" or type(control) ~= "userdata" or type(typ) ~= "string" then
      error("Invalid arguments to link(): expected (string, control, string)")
    end

    local function set_control_value()
      set(key, control[typ])
    end

    local options = options or {}
    control.EventHandler = set_control_value
    on(
      key,
      function(value)
        control[typ] = value
      end
    )
    if not options.no_init then
      Timer.CallAfter(set_control_value, math.random() + 0.3)
    end
  end

  local function get(key)
    return extract(local_k, key)
  end

  return {
    init = init,
    now = now,
    set = set,
    on = on,
    off = off,
    link = link,
    get = get 
  }
end)()
