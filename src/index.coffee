diff = require ("deep-diff").diff
twinning = ({name, newFn, oldFn, onNewFnError, onDiffs}) -> (args..., cb) ->
  oldResult = null
  newResult = null

  oldPartial = (next) -> oldFn args..., next
  newPartial = (next) -> newFn args..., next

  oldFinished = false
  newFinished = false
  newErrored = false

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
      onNewFnError name, err
      newErrored = true
      if oldFinished
        return cb null, oldResult
    else
      newFinished = true
      newResult = result
      if oldFinished
        onFinish()

  onFinish = () ->
    differences = diff oldResult, newResult
    if differences?
      onDiffs name, differences
    return cb null, oldResult

module.exports = twinning
module.exports.defaults = (defaults) -> (params) ->
  for k, v of defaults
    params[k] ?= v
  return twinning params
