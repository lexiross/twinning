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

oldFn = (cb) ->
  setTimeout (() -> cb(null, oldResult)), 0

newFn = (cb) ->
  setTimeout (() -> cb(null, newResult)), 0

badNewFn = (cb) ->
  setTimeout (() -> cb(new Error("Pigs can't fly!"))), 0

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
    expect(diffs).to.eql [
      { kind: 'E', path: [ 'a' ], lhs: 1, rhs: 4 },
      { kind: 'E', path: [ 'c', 1 ], lhs: 3, rhs: 5 }
    ]
    expect(params.onNewFnError.calledOnce).to.be(false)
    done()

it "works correctly with a new function that errors", (done) ->
  params.newFn = badNewFn
  twinning(params) (err, result) ->
    expect(err).to.not.be.ok()
    expect(result).to.eql(oldResult)

    name = params.onNewFnError.args[0][0]
    err = params.onNewFnError.args[0][1]
    expect(name).to.be("TestFunction")
    expect(err.message).to.be("Pigs can't fly!")
    expect(params.onDiffs.calledOnce).to.be(false)

    done()
