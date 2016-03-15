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

describe "twinning async functions", ->
  oldFn = (cb) ->
    setTimeout (() -> cb(null, oldResult)), 0

  newFn = (cb) ->
    setTimeout (() -> cb(null, newResult)), 0

  badNewFn = (cb) ->
    setTimeout (() -> cb(new Error("Pigs can't fly!"))), 0

  sameFn = (cb) ->
    setTimeout (() -> cb(null, oldResult)), 0

  params = null

  beforeEach ->
    params =
      name: "TestFunction"
      newFn: newFn
      oldFn: oldFn
      onNewFnError: sinon.spy()
      onDiffs: sinon.spy()

  it "works correctly with functions that return different data", (done) ->
    twinning(params) (err, result) ->
      expect(err).to.not.be.ok()
      expect(result).to.eql(oldResult)

      name = params.onDiffs.args[0][0]
      diffs = params.onDiffs.args[0][1]
      expect(name).to.be(params.name)
      expect(diffs).to.eql diffs
      expect(params.onNewFnError.calledOnce).to.be(false)
      done()

  it "works correctly with a new function that errors", (done) ->
    params.newFn = badNewFn
    twinning(params) (err, result) ->
      expect(err).to.not.be.ok()
      expect(result).to.eql(oldResult)

      name = params.onNewFnError.args[0][0]
      err = params.onNewFnError.args[0][1]
      expect(name).to.be(params.name)
      expect(err.message).to.be("Pigs can't fly!")
      expect(params.onDiffs.calledOnce).to.be(false)

      done()

  it "works correctly with functions that return the same data", (done) ->
    params.newFn = sameFn
    twinning(params) (err, result) ->
      expect(result).to.eql(oldResult)
      expect(params.onNewFnError.calledOnce).to.be(false)
      expect(params.onDiffs.calledOnce).to.be(false)
      done()

  describe "when onDiffs throws", ->

    # some setup here to prevent mocha from catching out-of-scope exceptions
    # for this describe block
    mochaErrorListener = null
    stubListener = sinon.spy()

    before ->
      mochaErrorListener = process.listeners('uncaughtException')[0]
      process.removeListener "uncaughtException", mochaErrorListener
      process.addListener "uncaughtException", stubListener

    after ->

    it "still returns result", (done) ->
      params.onDiffs = sinon.stub().throws new Error "stub error"
      twinning(params) (err, result) ->
        process.removeListener "uncaughtException", stubListener
        process.addListener "uncaughtException", mochaErrorListener

        expect(err).to.not.be.ok()
        expect(result).to.eql(oldResult)
        expect(params.onNewFnError.calledOnce).to.be(false)
        expect(params.onDiffs.calledOnce).to.be(true)
        expect(stubListener.calledOnce).to.be(true)
        done()

  describe "error handling", ->

    it "returns error if oldFn errors", (done) ->
      params.newFn = badNewFn
      params.oldFn = badNewFn
      twinning(params) (err, result) ->
        expect(err.message).to.match(/Pigs can't fly/)
        done()

    it "doesn't call onNewFnError if both old and new error", (done) ->
      params.newFn = badNewFn
      params.oldFn = (cb) -> cb new Error()
      twinning(params) (err, result) ->
        expect(err.message).to.be('')
        expect(params.onNewFnError.calledOnce).to.be(false)
        done()

    it "doesn't call onDiffs if old and new error with same message", (done) ->
      params.newFn = badNewFn
      params.oldFn = badNewFn
      twinning(params) (err, result) ->
        expect(err.message).to.match(/Pigs can't fly/)
        expect(params.onNewFnError.calledOnce).to.be(false)
        expect(params.onDiffs.calledOnce).to.be(false)
        done()

    it "calls onDiffs if old and new error with different message", (done) ->
      params.newFn = (cb) -> cb new Error "Cats cannot wink with their ears"
      params.oldFn = badNewFn
      twinning(params) (err, result) ->
        expect(err.message).to.match(/Pigs can't fly/)
        expect(params.onNewFnError.calledOnce).to.be(false)
        expect(params.onDiffs.calledOnce).to.be(true)
        done()

describe "twinning promise functions", ->
  oldFn = () -> Promise.resolve oldResult
  newFn = () -> Promise.resolve newResult
  badNewFn = () -> Promise.reject(new Error("Cats cannot land on their backs"))
  sameFn = () -> Promise.resolve oldResult

  params = null

  beforeEach ->
    params =
      name: "TestFunction"
      newFn: newFn
      oldFn: oldFn
      promises: true
      onNewFnError: sinon.spy()
      onDiffs: sinon.spy()

  it "works correctly with functions that return different data", ->
    twinning(params)()
      .then (result) ->
        expect(result).to.eql(oldResult)
        name = params.onDiffs.args[0][0]
        diffs = params.onDiffs.args[0][1]
        expect(name).to.be(params.name)
        expect(diffs).to.eql diffs
        expect(params.onNewFnError.calledOnce).to.be(false)

  it "works correctly with a function that errors", ->
    params.newFn = badNewFn
    twinning(params)()
      .then (result) ->
        expect(result).to.eql(oldResult)
        name = params.onNewFnError.args[0][0]
        err = params.onNewFnError.args[0][1]
        expect(name).to.be(params.name)
        expect(err.message).to.be("Cats cannot land on their backs")
        expect(params.onDiffs.calledOnce).to.be(false)

  it "works correctly with functions that return the same data", ->
    params.newFn = sameFn
    twinning(params)()
      .then (result) ->
        expect(result).to.eql(oldResult)
        expect(params.onNewFnError.calledOnce).to.be(false)
        expect(params.onDiffs.calledOnce).to.be(false)

  describe "when onDiffs throws", ->

    # some setup here to prevent mocha from catching out-of-scope exceptions
    # for this describe block
    mochaErrorListener = null
    stubListener = sinon.spy()

    before ->
      mochaErrorListener = process.listeners('uncaughtException')[0]
      process.removeListener "uncaughtException", mochaErrorListener
      process.addListener "uncaughtException", stubListener

    after ->
      process.removeListener "uncaughtException", stubListener
      process.addListener "uncaughtException", mochaErrorListener

    it "still returns result", (done) ->
      params.onDiffs = sinon.stub().throws new Error "stub error"
      twinning(params)()
        .then (result) ->
          expect(result).to.eql(oldResult)
          expect(params.onNewFnError.calledOnce).to.be(false)
          expect(params.onDiffs.calledOnce).to.be(true)
          expect(stubListener.calledOnce).to.be(true)
          done()
        .catch done

  describe "error handling", ->

    it "returns error if oldFn errors", ->
      params.newFn = badNewFn
      params.oldFn = badNewFn
      promiseShouldReject twinning(params)(), /Cats cannot land on their backs/

    it "doesn't call onNewFnError if both old and new error", ->
      params.newFn = badNewFn
      params.oldFn = () -> Promise.reject new Error()
      promiseShouldReject twinning(params)(), /.*/
        .then () ->
          expect(params.onNewFnError.calledOnce).to.be(false)

    it "doesn't call onDiffs if old and new error with same message", ->
      params.newFn = badNewFn
      params.oldFn = badNewFn
      promiseShouldReject twinning(params)(), /Cats cannot land on their backs/
        .then () ->
          expect(params.onNewFnError.calledOnce).to.be(false)
          expect(params.onDiffs.calledOnce).to.be(false)

    it "calls onDiffs if old and new error with different message", ->
      params.newFn = () -> Promise.reject new Error "Cats cannot wink with their ears"
      params.oldFn = badNewFn
      promiseShouldReject twinning(params)(), /Cats cannot land on their backs/
        .then () ->
          expect(params.onNewFnError.calledOnce).to.be(false)
          expect(params.onDiffs.calledOnce).to.be(true)

describe "twinning sync function", ->
  oldFn = () -> oldResult
  newFn = () -> newResult
  badNewFn = () -> throw new Error("Cats hate water")
  sameFn = () -> oldResult

  params = null

  beforeEach ->
    params =
      name: "TestFunction"
      newFn: newFn
      oldFn: oldFn
      sync: true
      onNewFnError: sinon.spy()
      onDiffs: sinon.spy()

  it "works correctly with functions that return different data", ->
    result = twinning(params)()
    expect(result).to.eql(oldResult)
    name = params.onDiffs.args[0][0]
    diffs = params.onDiffs.args[0][1]
    expect(name).to.be(params.name)
    expect(diffs).to.eql diffs
    expect(params.onNewFnError.calledOnce).to.be(false)

  it "works correctly with a function that errors", ->
    params.newFn = badNewFn
    result = twinning(params)()
    expect(result).to.eql(oldResult)
    name = params.onNewFnError.args[0][0]
    err = params.onNewFnError.args[0][1]
    expect(name).to.be(params.name)
    expect(err.message).to.be("Cats hate water")
    expect(params.onDiffs.calledOnce).to.be(false)

  it "works correctly with functions that return the same data", ->
    params.newFn = sameFn
    result = twinning(params)()
    expect(result).to.eql(oldResult)
    expect(params.onNewFnError.calledOnce).to.be(false)
    expect(params.onDiffs.calledOnce).to.be(false)

promiseShouldReject = (promise, test) ->
  promise
    .then(
      (() -> throw new Error("Promise should have rejected!")),
      ((err) ->
        if test and !test.test(err.message)
          throw new Error("Error was thrown but didn't match regex: " + test.toString() + "\nactual: " + err.message)
      )
    )
