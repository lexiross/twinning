diff = require("deep-diff").diff
twinning = ({name, newFn, oldFn, onNewFnError, onDiffs, sync, promises}) -> (args...) ->
  oldResult = null
  newResult = null

  oldFinished = false
  newFinished = false
  newErrored = false

  findAndHandleDiffs = () ->
    differences = diff oldResult, newResult
    if differences? and onDiffs?
      onDiffs name, differences

  async = not sync and not promises

  if async
    [args..., cb] = args
    oldPartial = (next) -> oldFn args..., next
    newPartial = (next) -> newFn args..., next
    onFinish = () ->
      findAndHandleDiffs()
      return cb null, oldResult

    oldPartial (err, result) ->
      if err?
        return cb err
      oldFinished = true
      oldResult = result
      if newFinished
        onFinish()
      else if newErrored
        return cb null, result

    newPartial (err, result) ->
      if err?
        if onNewFnError?
          onNewFnError name, err
        newErrored = true
        if oldFinished
          return cb null, oldResult
      else
        newFinished = true
        newResult = result
        if oldFinished
          onFinish()

  else if promises
    return new Promise (resolve, reject) ->
      oldFn args...
        .then (result) ->
          oldFinished = true
          oldResult = result
          if newFinished
            # run diff in next tick so exceptions don't get caught
            process.nextTick ->
              findAndHandleDiffs()
              resolve(oldResult)
          else if newErrored
            resolve(oldResult)
        .catch (err) ->
          reject(err)
      newFn args...
        .then (result) ->
          newFinished = true
          newResult = result
          if oldFinished
            # run diff in next tick so exceptions don't get caught
            process.nextTick ->
              findAndHandleDiffs()
              resolve(oldResult)
        .catch (err) ->
          if onNewFnError?
            onNewFnError name, err
          newErrored = true
          if oldFinished
            resolve(oldResult)

  else if sync
    oldResult = oldFn args...
    try
      newResult = newFn args...
    catch err
      if onNewFnError?
        onNewFnError name, err
      return oldResult
    findAndHandleDiffs()
    return oldResult

module.exports = twinning
module.exports.defaults = (defaults) -> (params) ->
  for k, v of defaults
    params[k] ?= v
  return twinning params
