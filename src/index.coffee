diff = require("deep-diff").diff
twinning = ({name, newFn, oldFn, onNewFnError, onDiffs, sync, promises}) -> (args...) ->
  oldErrored = false
  newErrored = false

  findAndHandleDiffs = (oldResult, newResult) ->
    if oldErrored and newErrored
      # try to get message out of Error obj
      differences = diff (oldResult.message || oldResult), (newResult.message || newResult)
    else
      differences = diff oldResult, newResult

    if differences? and onDiffs?
      onDiffs name, differences

  usingCb = not sync and not promises

  handleAsync = (oldPromise, newPromise) ->
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
          # only call onNewFnError if only newFn errored
          if newErrored and not oldErrored
            if onNewFnError
              # nextTick so exceptions don't get caught by containing promise
              process.nextTick ->
                onNewFnError name, newResult
          else
            # nextTick so exceptions don't get caught by containing promise
            process.nextTick ->
              findAndHandleDiffs(oldResult, newResult)

          # nextTick resolving so onNewFnError/findAndHandleDiffs get to run first
          process.nextTick ->
            if oldErrored
              reject oldResult
            else
              resolve oldResult

  if usingCb
    [args..., cb] = args

    oldPromise = fromCallback (next) -> oldFn args..., next
    newPromise = fromCallback (next) -> newFn args..., next

    runningTasks = handleAsync oldPromise, newPromise

    asCallback runningTasks, cb
  else if promises
    return handleAsync (oldFn args...), (newFn args...)
  else if sync
    oldResult = oldFn args...
    try
      newResult = newFn args...
    catch err
      if onNewFnError?
        onNewFnError name, err
      return oldResult
    findAndHandleDiffs(oldResult, newResult)
    return oldResult

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
