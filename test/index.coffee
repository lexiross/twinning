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
oldError = new Error("Old error")
newError = new Error("New error")
evaluationError = new Error("Evalutation error")


# Instead of oldFn and newFn, pass in `oldResult`, `oldError`, `newResult`, and `newError`.
# `multi` will convert your params into three different sets of params, one for 
# callbacks, one for promises, and one for synchronous functions, and call your evalutation
# callback with the appropriate values for each.
multi = (description, runner) ->
  
  it "#{description} (callbacks)", (done) ->
    runner (params, evaluate) ->
      params.oldFn = (cb) -> cb params.oldError or null, params.oldResult
      params.newFn = (cb) -> cb params.newError or null, params.newResult
      twinning(params) (err, result) ->
        try 
          evaluate(err, result)
        catch err
          return done(err)
        done()
  
  it "#{description} (promises)", ->
    runner (params, evaluate) ->
      params.oldFn = -> if params.oldError then Promise.reject(params.oldError) else Promise.resolve(params.oldResult)
      params.newFn = -> if params.newError then Promise.reject(params.newError) else Promise.resolve(params.newResult)
      params.promises = true
      twinning(params)()
        .then evaluate.bind(null, null), evaluate

  it "#{description} (sync)", ->
    runner (params, evaluate) ->
      params.oldFn = -> if params.oldError then throw params.oldError else params.oldResult
      params.newFn = -> if params.newError then throw params.newError else params.newResult
      params.sync = true
      err = null
      try
        result = twinning(params)()
      catch ex
        err = ex
      evaluate err, result

describe "when new and old functions return the same data", ->

  multi "returns old result, does not call `onDiffs` or `onError`", (run) ->
    params =
      name: "TestFunction"
      oldResult: oldResult
      newResult: oldResult
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
      oldResult: oldResult
      newResult: newResult
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
        oldResult: oldResult
        newResult: newResult
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
          oldResult: oldResult
          newResult: newResult
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
          oldResult: oldResult
          newResult: newResult
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
          oldResult: oldResult
          newResult: newResult
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
      oldResult: oldResult
      newError: newError
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
        oldResult: oldResult
        newError: newError
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
      oldError: oldError
      newResult: oldResult
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
        oldError: oldError
        newResult: oldResult
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
      oldError: oldError
      newError: newError
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
        oldError: oldError
        newError: newError
        onError: sinon.stub().throws(evaluationError)
        onDiffs: sinon.stub()
      run params, (err, result) ->
        expect(err).to.be(evaluationError)
        expect(result).to.be(undefined)

        sinon.assert.calledWithMatch(params.onError, params.name, oldError, newError)
        sinon.assert.notCalled(params.onDiffs)