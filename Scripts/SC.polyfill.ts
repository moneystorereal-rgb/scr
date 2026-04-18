// polyfills exclusively for supporting IE on the guest page
// we used to have inline polyfills in Global.js, which we would use here, but SWC requires some more polyfills on at least Object for doing its polyfills..
// so we're just using the whole core-js bundle for now until/unless we take the time to determine the minimum needed set of polyfills

// this is like 1MB but only 1 file
import 'core-js-bundle';

// these work and are smaller (still a few hundred KB) but like 300 files (which affects installer times)
// import 'core-js/stable/symbol';
// import 'core-js/stable/object';
// import 'core-js/stable/array';
// import 'core-js/stable/string';

// TODO import core-js features more granularly or use more lightweight polyfills
