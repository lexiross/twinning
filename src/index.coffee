diff = require("deep-diff").diff

twinning = ({name, newFn, oldFn, onError, onDiffs, ignore, sync, promises}) ->

  findAndHandleDiffs = (oldResult, newResult) ->
    diffs = diff oldResult, newResult

    if ignore?
      diffs = diffs.filter (diff) -> not ignore(diff)

    if diffs? and onDiffs?
      onDiffs name, diffs

  handleAsync = (oldPromise, newPromise) ->
    oldErrored = false
    newErrored = false
    return new Promise (resolve, reject) ->
      runningOld = oldPromise
        .catch (err) ->
          oldErrored = true
          return err

      runningNew = newPromise
        .catch (err) ->
          newErrored = true
          return err

      Promise.all [runningOld, runningNew]
        .then ([oldResult, newResult]) ->
          # only call onError if only newFn errored
          if newErrored or oldErrored
            if onError
              # nextTick so exceptions don't get caught by containing promise
              process.nextTick ->
                onError name,
                  oldErr: if oldErrored then oldResult else undefined
                  newErr: if newErrored then newResult else undefined
          else
            # nextTick so exceptions don't get caught by containing promise
            process.nextTick ->
              findAndHandleDiffs(oldResult, newResult)

          # nextTick resolving so onError/findAndHandleDiffs get to run first
          process.nextTick ->
            if oldErrored
              reject oldResult
            else
              resolve oldResult

  handleSync = (args) ->
    oldErrored = false
    newErrored = false

    try
      oldResult = oldFn args...
    catch err
      oldErrored = true
      oldResult = err

    try
      newResult = newFn args...
    catch err
      newErrored = true
      newResult = err

    if newErrored or oldErrored
      if onError?
        onError name, {
          oldErr: if oldErrored then oldResult else undefined
          newErr: if newErrored then newResult else undefined
        }
    else
      findAndHandleDiffs(oldResult, newResult)

    if oldErrored
      throw oldResult
    else
      return oldResult

  return (args...) ->
    usingCb = not sync and not promises

    if usingCb
      [args..., cb] = args

      oldPromise = fromCallback (next) -> oldFn args..., next
      newPromise = fromCallback (next) -> newFn args..., next

      runningTasks = handleAsync oldPromise, newPromise

      asCallback runningTasks, cb
    else if promises
      return handleAsync (oldFn args...), (newFn args...)
    else if sync
      return handleSync(args)

module.exports = twinning
module.exports.defaults = (defaults) -> (params) ->
  for k, v of defaults
    params[k] ?= v
  return twinning params

fromCallback = (fn) ->
  return new Promise (resolve, reject) ->
    fn (err, result) ->
      if err?
        return reject err
      resolve result

asCallback = (promise, cb) ->
  promise.then cb.bind(null, null), cb
