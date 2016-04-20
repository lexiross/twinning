diff = require("deep-diff").diff

twinning = ({name, newFn, oldFn, onError, onDiffs, ignore, sync, promises}) ->

  onResult = (oldErr, newErr, oldResult, newResult) ->
    if newErr or oldErr
      if onError?
        onError name, oldErr, newErr
    else
      diffs = diff oldResult, newResult

      if ignore?
        diffs = diffs?.filter (diff) -> not ignore(diff)

      if diffs?.length > 0 and onDiffs?
        onDiffs name, diffs

    # either of the above may have thrown.
    if oldErr
      throw oldErr
    return oldResult

  handleAsync = (oldPromise, newPromise) ->
    oldErr = null
    newErr = null

    runningOld = oldPromise
      .catch (err) ->
        oldErr = err
        return null

    runningNew = newPromise
      .catch (err) ->
        newErr = err
        return null

    Promise.all [runningOld, runningNew]
      .then ([oldResult, newResult]) -> onResult oldErr, newErr, oldResult, newResult

  handleSync = (args) ->
    oldErr = null
    newErr = null

    try
      oldResult = oldFn args...
    catch err
      oldErr = err

    try
      newResult = newFn args...
    catch err
      newErr = err

    return onResult oldErr, newErr, oldResult, newResult

  return (args...) ->
    usingCb = not sync and not promises

    if usingCb
      [args..., cb] = args

      oldPromise = fromCallback (next) -> oldFn args..., next
      newPromise = fromCallback (next) -> newFn args..., next
      asCallback handleAsync(oldPromise, newPromise), cb
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
