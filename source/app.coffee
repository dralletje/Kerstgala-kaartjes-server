Promise = require 'bluebird'

# Start the Daemon and wait for requests
Sleep = require 'sleeprest'
server = new Sleep

Sequelize = require 'sequelize'
sequelize = new Sequelize 'kerstgala', 'kerstgala', 'kerstgala',
  host: 'db'

User = sequelize.define 'User',
  leerling:
    type: Sequelize.INTEGER
    allowNull: true
  tag:
    type: Sequelize.STRING
    allowNull: true
  rijdmee:
    type: Sequelize.BOOLEAN
    defaultValue: false

sequelize.sync()

### Kaartje toevoegen (old) ###
server.resource('kaartje')
.use(Sleep.bodyParser())
.post (req) ->
  tagId = req.body?.tagId
  if not tagId?
    throw new Error 'Tag ID not given'
  rijdmee = req.body?.rijdmee or false

  console.log """
    Tag id: #{tagId}
    Rijd mee: #{rijdmee}

  """

  User.create
    tag: tagId
    rijdmee: rijdmee

  .then ->
    message: 'Done!'
  .catch Sequelize.UniqueConstraintError, ->
    throw new Error 'HTTP:409 Kaartje al geregistreerd'

server.listen '8000'
console.warn 'Hasta la viesta!'
