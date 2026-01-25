module.exports = function(grunt) {
  grunt.initConfig({
    eslint: {
      target: ['MediaWiki:Gadget-owidslider.js']
    }
  });

  grunt.loadNpmTasks('grunt-eslint');

  grunt.registerTask('test', ['eslint']);
};