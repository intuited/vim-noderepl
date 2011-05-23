var nodeunit = require('nodeunit'),
    replique = require('../src/replique');

exports['Single context functionality'] = nodeunit.testCase({
    setUp: function setUp(callback) {
        this.context = new replique.Context();
        this.console_log = console.log;
        console.log = function () {};
        callback();
    },
    tearDown: function (callback) {
        console.log = this.console_log;
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
        this.console_log = console.log;
        console.log = function () {};
        callback();
    },
    tearDown: function (callback) {
        console.log = this.console_log;
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

exports['use of Contexts objects'] = nodeunit.testCase({
    setUp: function setUp(callback) {
        this.contexts = new replique.Contexts();
        this.console_log = console.log;
        console.log = function () {};
        callback();
    },
    tearDown: function (callback) {
        console.log = this.console_log;
        callback();
    },

    'context autovivification': function (test) {
        var context = this.contexts.get('test');
        test.ok(context instanceof replique.Context);
        test.done();
    },
    'default context named default': function (test) {
        test.strictEqual(this.contexts.get(), this.contexts.get('default'));
        test.notEqual(this.contexts.get(), this.contexts.get('not default'));
        test.done();
    },
    'getting the same context twice': function (test) {
        this.contexts.get('test').evaluate('var testvar = 1;');
        test.strictEqual(this.contexts.get('test').evaluate('testvar').value,
                         1);
        test.done();
    },
    'unique contexts with empty prefix': function (test) {
        test.strictEqual(this.contexts.uniqueContext(), '1');
        test.strictEqual(this.contexts.uniqueContext(), '2');
        test.notEqual(this.contexts.get('1'), this.contexts.get('2'));
        this.contexts.get('1').evaluate('var test = 1');
        test.strictEqual(this.contexts.get('2').evaluate('test').result,
                         'error');
        test.done();
    },
    'unique contexts with non-empty prefix': function (test) {
        test.strictEqual(this.contexts.uniqueContext('test'), 'test1');
        test.strictEqual(this.contexts.uniqueContext('test'), 'test2');
        test.notEqual(this.contexts.get('test1'),
                      this.contexts.get('test2'));
        this.contexts.get('test1').evaluate('var test = 1');
        test.strictEqual(this.contexts.get('test2').evaluate('test').result,
                         'error');
        test.done();
    },
    'unique contexts with invalid prefix': function (test) {
        var contexts = this.contexts;
        test.throws(function () { contexts.uniqueContext('1'); }, Error);
        test.throws(function () { contexts.uniqueContext('test1'); }, Error);
        test.doesNotThrow(function () { contexts.uniqueContext('test1-'); },
                          Error);
        test.done();
    },
    'incrementation of unique context ID by .get': function (test) {
        this.contexts.get('test2');
        test.strictEqual(this.contexts.uniqueContext('test'), 'test3');
        this.contexts.get('test6');
        test.strictEqual(this.contexts.uniqueContext('test'), 'test7');
        test.done();
    },
});
