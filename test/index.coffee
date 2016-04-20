domain   = require "domain"
twinning = require "../src"
sinon    = require "sinon"
expect   = require "expect.js"

oldResult =
  a: 1
  b: 2
  c: [1, 3]
newResult =
  a: 4
  b: 2
  c: [1, 5]
diffs = [
  { kind: 'E', path: [ 'a' ], lhs: 1, rhs: 4 },
  { kind: 'E', path: [ 'c', 1 ], lhs: 3, rhs: 5 }
]
beforeError = new Error("Before error")
oldError = new Error("Old error")
newError = new Error("New error")
evaluationError = new Error("Evalutation error")
afterError = new Error("After error")

callbackify = (syncFn) -> 
  (args..., cb) ->
    setTimeout ->
      try
        result = syncFn args...
        return cb null, result
      catch ex
        return cb ex
    , 0

promisify = (syncFn) -> (args...) ->
  return Promise.resolve().then () -> syncFn args...

# `multi` will convert your params into three different sets of params, one for 
# callbacks, one for promises, and one for synchronous functions, and call your evalutation
# callback with the appropriate values for each.
multi = (description, runner) ->
  
  it "#{description} (callbacks)", (done) ->
    runner (params, args, evaluate) ->
      if not evaluate?
        evaluate = args
        args = []

      params.oldFn = callbackify params.oldFn
      params.newFn = callbackify params.newFn
      params.before = callbackify params.before if params.before?
      params.after = callbackify params.after if params.after?

      twinning(params) args..., (err, result) ->
        try 
          evaluate(err, result)
        catch err
          return done(err)
        done()
  
  it "#{description} (promises)", ->
    runner (params, args, evaluate) ->
      if not evaluate?
        evaluate = args
        args = []

      params.promises = true
      
      params.oldFn = promisify params.oldFn
      params.newFn = promisify params.newFn
      params.before = promisify params.before if params.before?
      params.after = promisify params.after if params.after?

      twinning(params) args...
        .then evaluate.bind(null, null), evaluate

  it "#{description} (sync)", ->
    runner (params, args, evaluate) ->
      if not evaluate?
        evaluate = args
        args = []

      params.sync = true      
      err = null
      try
        result = twinning(params) args...
      catch ex
        err = ex
      evaluate err, result

describe "when new and old functions return the same data", ->

  multi "returns old result, does not call `onDiffs` or `onError`", (run) ->
    params =
      name: "TestFunction"
      oldFn: () -> oldResult
      newFn: () -> oldResult
      onError: sinon.stub()
      onDiffs: sinon.stub()
    run params, (err, result) ->
      expect(err).to.be(null)
      expect(result).to.be(oldResult)

      sinon.assert.notCalled(params.onError)
      sinon.assert.notCalled(params.onDiffs)

describe "when new and old functions return different data", ->

  multi "returns old result, calls `onDiffs` with diffs", (run) ->
    params =
      name: "TestFunction"
      oldFn: () -> oldResult
      newFn: () -> newResult
      onError: sinon.stub()
      onDiffs: sinon.stub()
    run params, (err, result) ->
      expect(err).to.be(null)
      expect(result).to.be(oldResult)

      sinon.assert.calledWith(params.onDiffs, params.name, diffs)
      sinon.assert.notCalled(params.onError)

  describe "when `onDiffs` throws", ->

    multi "throws error from `onDiffs`", (run) ->
      params =
        name: "TestFunction"
        oldFn: () -> oldResult
        newFn: () -> newResult
        onError: sinon.stub()
        onDiffs: sinon.stub().throws(oldError)
      run params, (err, result) ->
        expect(err).to.be(oldError)
        expect(result).to.be(undefined)

        sinon.assert.calledWith(params.onDiffs, params.name, diffs)
        sinon.assert.notCalled(params.onError)

  describe "when `ignore` option is set", ->

    describe "when no diffs match predicate", ->

      multi "calls `onDiffs` with all diffs", (run) ->
        params =
          name: "TestFunction"
          oldFn: () -> oldResult
          newFn: () -> newResult
          onError: sinon.stub()
          onDiffs: sinon.stub()
          ignore: -> false
        run params, (err, result) ->
          expect(err).to.be(null)
          expect(result).to.be(oldResult)

          sinon.assert.calledWith(params.onDiffs, params.name, diffs)
          sinon.assert.notCalled(params.onError)

    describe "when some diffs match predicate", ->

      multi "calls `onDiffs` with diffs that don't match", (run) ->
        params =
          name: "TestFunction"
          oldFn: () -> oldResult
          newFn: () -> newResult
          onError: sinon.stub()
          onDiffs: sinon.stub()
          ignore: (diff) -> diff.lhs is 1
        run params, (err, result) ->
          expect(err).to.be(null)
          expect(result).to.be(oldResult)

          sinon.assert.calledWithMatch(params.onDiffs, params.name, diffs.slice(1))
          sinon.assert.notCalled(params.onError)

    describe "when all diffs match predicate", ->

      multi "does not call `onDiffs`", (run) ->
        params = 
          name: "TestFunction"
          oldFn: () -> oldResult
          newFn: () -> newResult
          onError: sinon.stub()
          onDiffs: sinon.stub()
          ignore: -> true
        run params, (err, result) ->
          expect(err).to.be(null)
          expect(result).to.be(oldResult)

          sinon.assert.notCalled(params.onDiffs)
          sinon.assert.notCalled(params.onError)

describe "when new function errors", ->

  multi "returns old result and calls `onError`", (run) ->
    params =
      name: "TestFunction"
      oldFn: () -> oldResult
      newFn: () -> throw newError
      onError: sinon.stub()
      onDiffs: sinon.stub()
    run params, (err, result) ->
      expect(err).to.be(null)
      expect(result).to.be(oldResult)

      sinon.assert.calledWithMatch(params.onError, params.name, null, newError)
      sinon.assert.notCalled(params.onDiffs)

  describe "when `onError` throws", ->

    multi "throws error from `onError`", (run) ->
      params =
        name: "TestFunction"
        oldFn: () -> oldResult
        newFn: () -> throw newError
        onError: sinon.stub().throws(evaluationError)
        onDiffs: sinon.stub()
      run params, (err, result) ->
        expect(err).to.be(evaluationError)
        expect(result).to.be(undefined)

        sinon.assert.calledWithMatch(params.onError, params.name, null, newError)
        sinon.assert.notCalled(params.onDiffs)


describe "when old function errors", ->

  multi "throws old error and calls `onError`", (run) ->
    params =
      name: "TestFunction"
      oldFn: () -> throw oldError
      newFn: () -> oldResult
      onError: sinon.stub()
      onDiffs: sinon.stub()
    run params, (err, result) ->
      expect(err).to.be(oldError)
      expect(result).to.be(undefined)

      sinon.assert.calledWithMatch(params.onError, params.name, oldError, null)
      sinon.assert.notCalled(params.onDiffs)

  describe "when `onError` throws", ->

    multi "throws error from `onError`", (run) ->
      params =
        name: "TestFunction"
        oldFn: () -> throw oldError
        newFn: () -> oldResult
        onError: sinon.stub().throws(evaluationError)
        onDiffs: sinon.stub()
      run params, (err, result) ->
        expect(err).to.be(evaluationError)
        expect(result).to.be(undefined)

        sinon.assert.calledWithMatch(params.onError, params.name, oldError, null)
        sinon.assert.notCalled(params.onDiffs)

describe "when old and new functions both error", ->

  multi "throws old error and calls `onError`", (run) ->
    params =
      name: "TestFunction"
      oldFn: () -> throw oldError
      newFn: () -> throw newError
      onError: sinon.stub()
      onDiffs: sinon.stub()
    run params, (err, result) ->
      expect(err).to.be(oldError)
      expect(result).to.be(undefined)

      sinon.assert.calledWithMatch(params.onError, params.name, oldError, newError)
      sinon.assert.notCalled(params.onDiffs)

  describe "when `onError` throws", ->

    multi "throws error from `onError`", (run) ->
      params =
        name: "TestFunction"
        oldFn: () -> throw oldError
        newFn: () -> throw newError
        onError: sinon.stub().throws(evaluationError)
        onDiffs: sinon.stub()
      run params, (err, result) ->
        expect(err).to.be(evaluationError)
        expect(result).to.be(undefined)

        sinon.assert.calledWithMatch(params.onError, params.name, oldError, newError)
        sinon.assert.notCalled(params.onDiffs)

describe "when neither `before` nor `after` is provided", ->

  multi "calls oldFn and newFn with given arguments", (run) ->
    originalArgs = [1, 2, 3]
    
    oldFn = sinon.stub()
    newFn = sinon.stub()

    params =
      name: "TestFunction"
      oldFn: oldFn
      newFn: newFn
      onError: sinon.stub()
      onDiffs: sinon.stub()

    run params, originalArgs, (err) ->
      expect(err).to.be(null)

      sinon.assert.calledWith oldFn, originalArgs...
      sinon.assert.calledWith newFn, originalArgs...

describe "when `before` is provided", ->

  multi "calls oldFn and newFn with return value of `before`", (run) ->
    originalArgs = [1, 2, 3]
    beforeResult = 4

    before = sinon.stub().returns(beforeResult)
    oldFn = sinon.stub()
    newFn = sinon.stub()

    params =
      name: "TestFunction"
      before: before
      oldFn: oldFn
      newFn: newFn
      onError: sinon.stub()
      onDiffs: sinon.stub()
    
    run params, originalArgs, (err) ->
      expect(err).to.be(null)

      sinon.assert.calledWith oldFn, beforeResult
      sinon.assert.calledWith newFn, beforeResult

  describe "when `before` block errors", (run) ->

    multi "does not run `oldFn`, `newFn`, `after`, `onError`, or `onDiffs`", (run) ->
      oldFn = sinon.stub()
      newFn = sinon.stub()
      after = sinon.stub()

      params =
        name: "TestFunction"
        before: (arg) -> throw beforeError
        oldFn: oldFn
        newFn: newFn
        after: after
        onError: sinon.stub()
        onDiffs: sinon.stub()
      
      run params, [0], (err, result) ->
        expect(err).to.be(beforeError)
        expect(result).to.be(undefined)

        sinon.assert.notCalled(oldFn)
        sinon.assert.notCalled(newFn)
        sinon.assert.notCalled(after)
        sinon.assert.notCalled(params.onError)
        sinon.assert.notCalled(params.onDiffs)

describe "when `after` is provided", ->

  describe "when main operation returns", ->

    multi "calls `after` with result and uses its return value", (run) ->
      mainResult = 1
      afterResult = 2

      params =
        name: "TestFunction"
        before: () -> null
        oldFn: () -> mainResult
        newFn: () -> throw newError # errors from newFn should be ignored
        after: () -> afterResult

      run params, (err, result) ->
        expect(err).to.be(null)
        expect(result).to.be(afterResult)

  describe "when main operation throws", ->

    multi "does not call `after`", (run) ->
      after = sinon.stub()
      
      params =
        name: "TestFunction"
        before: () -> null
        oldFn: () -> throw oldError # errors from oldFn are not ignored
        newFn: () -> 1
        after: after

      run params, (err, result) ->
        expect(err).to.be(oldError)
        expect(result).to.be(undefined)

        sinon.assert.notCalled(after)


  describe "when `after` throws", ->

    multi "throws error from `after`", (run) ->
      params =
        name: "TestFunction"
        before: () -> null
        oldFn: () -> 1
        newFn: () -> 1
        after: () -> throw afterError

      run params, (err, result) ->
        expect(err).to.be(afterError)
        expect(result).to.be(undefined)

describe "when `disabled` is set", ->

  multi "does not run `newFn`, `onDiffs`, or `onError` and returns `oldFn` result", (run) ->
    newFn = sinon.stub()
    params =
      name: "TestFunction"
      disabled: true
      before: (arg) -> arg + 1
      oldFn: (arg) -> arg + 1
      newFn: newFn
      after: (arg) -> arg + 1
      onError: sinon.stub()
      onDiffs: sinon.stub()

    run params, [0], (err, result) ->
      expect(err).to.be(null)
      expect(result).to.be(3)

      sinon.assert.notCalled(newFn)
      sinon.assert.notCalled(params.onError)
      sinon.assert.notCalled(params.onDiffs)

  describe "when `before` throws", (run) ->

    multi "does not run `newFn`, `onDiffs`, or `onError` and throws `before` error", (run) ->
      newFn = sinon.stub()
      params =
        name: "TestFunction"
        disabled: true
        before: () -> throw beforeError
        oldFn: (arg) -> arg + 1
        newFn: newFn
        after: (arg) -> arg + 1
        onError: sinon.stub()
        onDiffs: sinon.stub()

      run params, [0], (err, result) ->
        expect(err).to.be(beforeError)
        expect(result).to.be(undefined)

        sinon.assert.notCalled(newFn)
        sinon.assert.notCalled(params.onError)
        sinon.assert.notCalled(params.onDiffs)


  describe "when `oldFn` throws", (run) ->

    multi "does not run `newFn`, `onDiffs`, or `onError` and throws `oldFn` error", (run) ->
      newFn = sinon.stub()
      params =
        name: "TestFunction"
        disabled: true
        before: (arg) -> arg + 1
        oldFn: () -> throw oldError
        newFn: newFn
        after: (arg) -> arg + 1
        onError: sinon.stub()
        onDiffs: sinon.stub()

      run params, [0], (err, result) ->
        expect(err).to.be(oldError)
        expect(result).to.be(undefined)

        sinon.assert.notCalled(newFn)
        sinon.assert.notCalled(params.onError)
        sinon.assert.notCalled(params.onDiffs)


