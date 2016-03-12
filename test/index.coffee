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

  params =
    name: "TestFunction"
    newFn: newFn
    oldFn: oldFn

  beforeEach ->
    params.onNewFnError = sinon.spy()
    params.onDiffs = sinon.spy()

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

describe "twinning promise functions", ->
  oldFn = () -> Promise.resolve oldResult
  newFn = () -> Promise.resolve newResult
  badNewFn = () -> Promise.reject(new Error("Cats cannot land on their backs"))
  sameFn = () -> Promise.resolve oldResult

  params =
    name: "TestFunction"
    newFn: newFn
    oldFn: oldFn
    promises: true

  beforeEach ->
    params.onNewFnError = sinon.spy()
    params.onDiffs = sinon.spy()

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

describe "twinning sync function", ->
  oldFn = () -> oldResult
  newFn = () -> newResult
  badNewFn = () -> throw new Error("Cats hate water")
  sameFn = () -> oldResult

  params =
    name: "TestFunction"
    newFn: newFn
    oldFn: oldFn
    sync: true

  beforeEach ->
    params.onNewFnError = sinon.spy()
    params.onDiffs = sinon.spy()

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
