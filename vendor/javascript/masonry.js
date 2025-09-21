// masonry@0.0.2 downloaded from https://ga.jspm.io/npm:masonry@0.0.2/index.js

import r from"ejs";import e from"fs";var t="undefined"!==typeof globalThis?globalThis:"undefined"!==typeof self?self:global;var n={};var o=r;var a=e;var i=[];var render=function(r,e,n){var o=null;e=e||{};try{var a=i[r](e)}catch(r){a="<h1>Internal server error</h1><code>"+r+"</code>";o=r}if("function"===typeof n)return n(o,a);if(o){(this||t).statusCode=500;this.setHeader("Content-Type","text/html")}this.end(a)};n=function(r){if(!r)throw new Error("no template directory defined");var e=a.readdirSync(r);e.forEach((function(e){var t=a.readFileSync(r+"/"+e).toString();i[e]=o.compile(t)}));return function(r,e,t){e.render=render;t()}};var f=n;export default f;

