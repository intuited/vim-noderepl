var nodeunit = require('nodeunit'),
    replique = require('../src/replique');

exports['Single context functionality'] = nodeunit.testCase({
    setUp: function setUp(callback) {
        this.context = new replique.Context();
        callback();
    },

    'basic evaluation': function (test) {
        test.strictEqual(this.context.evaluate('1 + 1').value, 2);
        test.done();
    },

    'basic completion': function (test) {
        test.deepEqual(this.context.complete('Str').completions, ['String']);
        test.done();
    },

    'variable use': function (test) {
        this.context.evaluate('var testVar = 6;');
        test.strictEqual(this.context.evaluate('testVar').value, 6);
        test.done();
    },

    'variable completion': function (test) {
        this.context.evaluate('var testVar = 6;');
        test.deepEqual(this.context.complete('test').completions, ['testVar']);
        test.done();
    },

    // TODO: Check the .value attribute.
    'syntax errors': function (test) {
        test.strictEqual(this.context.evaluate('foo.').result, 'syntaxError');
        test.done();
    },

    'other errors': function (test) {
        var result = this.context.evaluate('throw Error("testing");');
        test.strictEqual(result.result, 'error');
        test.strictEqual(result.value.split("\n")[0], 'Error: testing');
        test.done();
    },
});

exports['Multiple context functionality'] = nodeunit.testCase({
    setUp: function setUp(callback) {
        this.context1 = new replique.Context();
        this.context2 = new replique.Context();
        callback();
    },

    'basic non-interaction': function (test) {
        this.context1.evaluate('var foo = 6;');
        this.context2.evaluate('var foo = 4;');
        test.strictEqual(this.context1.evaluate('foo').value, 6);
        test.strictEqual(this.context2.evaluate('foo').value, 4);
        test.done();
    },

    'global interaction between contexts': function (test) {
        this.context1.evaluate('global.foo = 6');
        test.strictEqual(this.context2.evaluate('global.foo').value, undefined);
        test.done();
    },
});
