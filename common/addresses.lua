

-- Does not work :/
function AOBExtract(target, start, stop, unpacked)
  AOBExtract_reply = nil
  events.send("functions.AOBExtract", {
    target = target,
    start = start,
    stop = stop,
    unpacked = unpacked,
  })
  return AOBExtract_reply
end

