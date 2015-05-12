express = require 'express'
coffee = require '../src/index'

app = express()

app.use coffee(
  src: 'src/coffee'
  dest: 'public/js'
  prefix: '/js'
  compilerOpts: bare: true
)

app.use express.static 'public'

app.listen(8000)
