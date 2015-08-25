coffee = require 'coffee-script'
Promise = require 'bluebird'
fs = Promise.promisifyAll(require("fs"))
path = require 'path'
url = require 'url'
mkdirp = Promise.promisify(require('mkdirp'))
debug = require('debug')('express-coffee-script')

regexJs = /\.js$/i

checkMtimes = (files) ->
  Promise.map files, (filename) ->
    fs.statAsync(filename)
      .then((stats) ->
        stats.mtime
      , (e) ->
        e.filename = filename
        throw e
      )

removePrefix = (str, prefix) ->
  str.replace(prefix, '')

middleware = (options = {}) ->
  if typeof options.src != 'string'
    throw new Error 'Please provide `src` option for CoffeeScript middleware'

  options.dest ?= options.src
  options.compile ?= -> coffee.compile.apply(coffee, arguments)
  options.compilerOpts ?= {}
  options.force ?= false
  options.ext ?= '.coffee'

  (req, res, next) ->
    return next() if req.method != 'GET' and req.method != 'HEAD'

    { pathname } = url.parse(req.url)

    return next() if not regexJs.test(pathname)

    pathnameCs = pathname.replace(regexJs, options.ext)

    if options.prefix?
      pathname = removePrefix(pathname, options.prefix)
      pathnameCs = removePrefix(pathnameCs, options.prefix)

    srcCs = path.join(options.src, pathnameCs)
    destJs = path.join(options.dest, pathname)

    debug "Middleware is looking for: '%s'", srcCs
    debug "Middleware will compile to: '%s'", destJs

    compile = ->
      fs.readFileAsync(srcCs)
      .then((data) ->
        options.compile(data.toString(), options.compilerOpts, srcCs)
      )
      .catch((e) -> next(e))

    save = (data) ->
      dirpath = path.dirname(destJs)
      mkdirp(dirpath)
      .then(->
        fs.writeFileAsync(destJs, data)
        .then(-> next())
        .catch((e) -> next(e))
      )
      .catch((e) -> next(e))

    return compile().then(save) if options.force

    checkMtimes([srcCs, destJs])
    .spread((timeCs, timeJs) ->
      if timeCs > timeJs
        debug "'%s' is modified, will be recompiled to: '%s'", srcCs, destJs
        compile().then(save)
      else
        next()
    )
    .catch((err) ->
      if err.filename == destJs
        debug "'%s' hasn't been compiled yet, first time compiling to: '%s'", srcCs, destJs
        compile().then(save)
      else
        next(err)
    )


module.exports = middleware
