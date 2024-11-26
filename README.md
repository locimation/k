# k

**K** is a library for sharing state across multiple Lua scripts on a Q-SYS core.

Using the K-Bridge plugin (not yet released), this shared state can also be extended to other Q-SYS cores on the local network, via UDP multicast.

## Design
The shared state is a Lua table. Each Lua script maintains its own local copy of the shared state.

Any Lua script can call `K.now(...)` with some fragment of a Lua table, to update the shared state.
This fragment will be merged into the shared state in all Lua scripts.

A script that originates a fragment of the shared state will re-transmit it every ten seconds, in order to bring new or restarted scripts and cores up to date. If a more recent fragment is received from another script, the re-transmission of overlapping data is discontinued.

## Example

```lua

require('locimation-k')

K.init()

K.on('room1', function(room)
  print(room.volume, room.mute)
end)

K.now({room1 = { volume = 0.7 }}) -- callback prints 0.7, nil

K.set('room1.mute', true) -- callback prints 0.7, true

```

## Methods

### `K.init()`
Initialize the library and start listening for shared state updates.

### `K.now(fragment)`
Update the shared state with the given fragment.
The fragment is a Lua table, which will be merged into the shared state.

### `K.get(key)`
Get the value of the given key from the shared state.
The key can contain dots to access nested tables, for example `K.get('foo.bar')`.

### `K.set(key, value)`
Set the value of the given key in the shared state.
The key can contain dots to create or update nested tables, for example `K.set('foo.bar', 42)`.

### `K.on(key, callback)`
Register a callback to be called when the given key changes in the shared state.
The key can be a branch of the shared state, for example `K.on('foo', function(value) print(value) end)`.
This callback will then be called whenever `K.now` is called with a fragment that updates `foo`, or any of its children.

### `K.off(key, callback)`
Unregister a callback that was previously registered with `K.on`.
This function can also be used to unregister all callbacks for a given key, by passing `nil` as the callback.

### `K.link(key, control, type)`
Link a control to a key in the shared state.
The control will be updated with the value of the key, and will update the key when its value changes.
For example: `K.link('foo', Controls.MyButton, 'Boolean')`.

## Network Protocol

The shared state is transmitted as a JSON string over UDP multicast, on port 36504.

The multicast address is the same as Q-LAN Discovery Protocol (QDP), 224.0.23.175.

If the "Key" field is set in the K-Bridge plugin, the shared state will be encrypted with AES-256-EBC.
Only cores with the same key will be able to read the shared state.