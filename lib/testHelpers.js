module.exports = {
  getTestEnvironmentComponents: function (component) {
    const contents = require('.././components/'+component+'/tmp/test-manifest.json');
    return contents;
  },

  setupEnvironment: function (component) {
    process.env['KR8_BASE'] = 'test/fixtures';
    process.env['KR8_COMPONENT'] = component;
    process.env['KR8_CLUSTER'] = 'test';
    process.env['KR8_JPATH'] = '../../lib';    
  },

  getTestEnvironmentComponent: function ( comp, name, kind) {
    const _ = require("lodash");
    const contents = require('.././components/'+comp+'/tmp/test-manifest.json');

    var component = _.filter(contents, { 'kind': kind, 'metadata': { 'name': name } } );

    // FIXME: if we've done the search correctly, this should return an array of length 1
    // however, this is a fairly sizeable assumption so adding a FIXME
    return component[0]

  },
};
