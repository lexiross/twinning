# twinning
Compare the result of a new async function against an old async function.
```js
const findCatsById = twinning({
  name: "findCatsById",
  oldFn: OldDatabase.findCatsById,
  newFn: NewDatabase.findCatsById
  onDiff: diffLoggingFunction
});

findCatsById("1234", function(err, result) {
  // err and result come from `OldDatabase.findCatsById`
  // any diffs will be passed to `diffLoggingFunction`
});
```
It's called twinning because in an ideal world, you want your old function and new function to be twins :)

## Setup

### Install

```
$ npm install twinning
```

### Configure defaults

```js
compare = require("twinning").defaults({
  onDiffs: (name, diffs) => {
    for (diff in diffs) {
      console.log("Different result for", name, JSON.stringify(diff));
    }
  },
  onNewFnError: (name, err) => {
    console.log("Error in new version of", name, err.message);
  }
});
```

## API
You can call `twinning` with the following parameters, any of which can be specified using `defaults`:
- `name`: A label for this comparison
- `oldFn`: The original function. It's assumed that this function is currently being used in production, and the results can be trusted. The function must take a callback as its last argument.
- `newFn`: The new function to compare. We assume this function is not yet reliable, so its results will be thrown away after the comparison. The function must take a callback as its last argument.
- `onNewFnError` (optional): A function that will be called when `newFn` errors (when `oldFn` errors, we will simply call its callback with the error). This function will be called with two arguments: `name` and `err`. You might want to use this option to log or throw the error.
- `onDiffs` (optional): A function that will be called when `newFn` yields a different result than `oldFn`. You might want to use this function to log differences, or perhaps throw. The function will be called with the following arguments:
  - `name`: see above
  - `diffs`: an array of change records between the results of `oldFn` and `newFn`. We've used [deep-diff](https://github.com/flitbit/diff) to implement the comparison; see their API for an overview of the structure of change records.
  
### Notes
- The function won't return until both `oldFn` and `newFn` have completed.
- Currently, this module only supports comparing async functions with callbacks, but we plan to support synchronous and promise-based functions in the future.
