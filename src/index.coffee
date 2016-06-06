diff = require("deep-diff").diff

twinning = ({name, newFn, oldFn, before, after, onError, onDiffs, disabled, ignore, sync, promises, promiseLib}) ->

  Promise = promiseLib or global.Promise

  onResult = (args, oldErr, newErr, oldResult, newResult) ->
    if not disabled
      if newErr or oldErr
        if onError?
          onError name, args, oldErr, newErr
      else
        diffs = diff oldResult, newResult

        if ignore?
          diffs = diffs?.filter (diff) -> not ignore(diff)

        if diffs?.length > 0 and onDiffs?
          onDiffs name, args, diffs

    if oldErr
      throw oldErr
    return oldResult

  if sync
    return (args...) ->
      oldErr = null
      newErr = null

      if not before?
        fnInput = args
      else
        fnInput = [before args...]

      try
        oldResult = oldFn fnInput...
      catch err
        oldErr = err

      if not disabled
        try
          newResult = newFn fnInput...
        catch err
          newErr = err

      result = onResult args, oldErr, newErr, oldResult, newResult

      if after?
        return after result
      else
        return result

  else if promises
    return (args...) ->
      oldErr = null
      newErr = null

      if not before?
        getInput = Promise.resolve args
      else
        getInput = before args...
          .then (results) -> [results]

      return getInput
        .then (input) ->
          runningOld = oldFn input...
            .catch (err) ->
              oldErr = err
              return null

          if disabled
            return Promise.all [runningOld]

          runningNew = newFn input...
            .catch (err) ->
              newErr = err
              return null
          Promise.all [runningOld, runningNew]
        .then ([oldResult, newResult]) ->
          onResult args, oldErr, newErr, oldResult, newResult
        .then (result) -> if after? then after(result) else result

  else
    return (args..., cb) ->
      (if before? then before else doNothingAsync) args..., (err, result) ->
        if err?
          return cb err

        if before?
          args = [result]

        oldErr = null
        newErr = null

        oldResult = null
        newResult = null

        oldFinished = false
        newFinished = disabled?

        onFinish = () ->
          return if not oldFinished or not newFinished
          try
            result = onResult args, oldErr, newErr, oldResult, newResult
          catch ex
            return cb ex

          (if after? then after else doNothingAsync) result, (err, afterResult) ->
            if err?
              return cb err
            if after?
              result = afterResult
            return cb null, result

        oldFn args..., (err, result) ->
          oldErr = err
          oldResult = result
          oldFinished = true
          onFinish()

        if not disabled
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

doNothingAsync = (args..., cb) -> cb null
