diff = require("deep-diff").diff

twinning = ({name, newFn, oldFn, before, after, onError, onDiffs, ignore, sync, promises, promiseLib}) ->

  Promise = promiseLib or global.Promise

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

  if sync
    return (args...) ->
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
  
  else if promises
    return (args...) ->
      oldErr = null
      newErr = null

      runningOld = oldFn args...
        .catch (err) ->
          oldErr = err
          return null

      runningNew = newFn args...
        .catch (err) ->
          newErr = err
          return null

      Promise.all [runningOld, runningNew]
        .then ([oldResult, newResult]) -> onResult oldErr, newErr, oldResult, newResult
  
  else
    return (args..., cb) ->
      oldErr = null
      newErr = null

      oldResult = null
      newResult = null

      oldFinished = false
      newFinished = false

      onFinish = () ->
        return if not oldFinished or not newFinished
        try
          result = onResult oldErr, newErr, oldResult, newResult
          return cb null, result
        catch ex
          return cb ex

      oldFn args..., (err, result) ->
        oldErr = err
        oldResult = result
        oldFinished = true
        onFinish()

      newFn args..., (err, result) ->
        newErr = err
        newResult = result
        newFinished = true
        onFinish()

module.exports = twinning
module.exports.defaults = (defaults) -> (params) ->
  for k, v of defaults
    params[k] ?= v
  return twinning params
