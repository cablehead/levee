# Changelog

## 0.3.2-alpha

* hashring fixes
* add meta.name for usage messages so subcommands can be reused by other
  projects
* clean up repr and move to \_.
* add Host header to http client requests, fix http client User-Agent
* fix bug in chunk transfer encoding parsing
* fix bug in lua msgpack bindings where array/map end states weren't expected
  from the parser
* pull in siphon empty map / array msgpack fix
* improve error logging when coroutines error
* fix composing Host header in http client
* for binaries built by levee, add a package.loader that attempts to open
  linked bundles via dysm

## 0.3.1 - 2015-12-03

* first tagged release
