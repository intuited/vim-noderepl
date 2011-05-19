var nodeunit = require('nodeunit'),
    replique = require('../src/replique');

exports['Context functionality'] = nodeunit.testCase({
    setUp: function setUp(callback) {
        this.context = new replique.Context();
        callback();
    },

    'basic evaluation': function (test) {
        test.equals(this.context.evaluate('1 + 1').value, 2);
        test.done();
    },

    'basic completion': function (test) {
        test.equals(this.context.complete('Str').completions[0], 'String');
        test.equals(this.context.complete('Str').completions.length, 1);
        test.done();
    },
});
