Promise = require 'bluebird'

# Start the Daemon and wait for requests
Sleep = require 'sleeprest'
server = new Sleep

Sequelize = require 'sequelize'
sequelize = new Sequelize 'kerstgala', 'kerstgala', 'kerstgala',
  host: 'db'

User = sequelize.define 'User',
  tag:
    type: Sequelize.STRING
    allowNull: true
  rijdmee:
    type: Sequelize.BOOLEAN
    defaultValue: false

Nummers = sequelize.define 'Nummers',
  leerlingnummer:
    type: Sequelize.INTEGER
    allowNull: true
  rijdmee:
    type: Sequelize.BOOLEAN
    defaultValue: false
,
  timestamps: false
  tableName: 'leerlingnummers'

Leerlingen = sequelize.define 'Leerlingen',
  nummer:
    type: Sequelize.INTEGER
    primaryKey: true
  klas: Sequelize.STRING
  naam: Sequelize.STRING
  geboorte: Sequelize.STRING
,
  timestamps: false
  tableName: 'leerlingen'

NFC = sequelize.define 'NFC',
  nummer:
    type: Sequelize.INTEGER
    primaryKey: true
  CSN: Sequelize.STRING
,
  timestamps: false
  tableName: 'leerlingen-nfc',

sequelize.sync()

leerling2object = (record, rijdmee) ->
  if not record?
    throw new Error 'HTTP:404 Geen eindexamen leerling!'
  t = Date.parse(record.geboorte.split('/').reverse().join('-'))
  year = Math.floor (Date.now() - t)/1000/60/60/24/365

  leeftijd: year
  naam: record.naam
  nummer: record.nummer
  alcohol: year >= 18
  rijdmee: rijdmee

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

server.resource('nummer/:nummer')
.get (req) ->
  if not req.params.nummer?
    throw new Error 'HTTP:419 No nummer given'

  rijdmee = false
  {nummer} = req.params
  # Look for number
  Nummers.findOne(where: leerlingnummer: nummer).then (record) ->
    if not record?
      throw new Error 'HTTP:404 Nummer not found :\'('

  # If not, look for number in the people who paid
  # With NFC
  .catch (err) ->
    NFC.findOne(where: nummer: nummer).then (record) ->
      console.log record.CSN.toLowerCase()
      User.findOne(where: tag: record.CSN.toLowerCase())
    .then (record) ->
      console.log record.values
      leerlingnummer: nummer
      rijdmee: record.rijdmee

  .then (record) ->
    rijdmee = record.rijdmee
    Leerlingen.findOne(where: nummer: nummer)

  .then (record) ->
    leerling2object(record, rijdmee)


server.resource('tag/:tag')
.get (req) ->
  if not req.params.tag?
    throw new Error 'HTTP:419 No tag given'

  {tag} = req.params
  rijdmee = false
  User.findOne(where: tag: tag).then (record) ->
    if not record?
      throw new Error 'HTTP:404 Tag not found :\'('
    rijdmee = record.rijdmee
    NFC.findOne(where: CSN: tag.toUpperCase())

  .catch ->
    NFC.findOne(where: CSN: tag.toUpperCase()).then (record) ->
      Nummers.findOne(where: leerlingnummer: record.nummer)
    .then (record) ->
      rijdmee: record.rijdmee
      nummer: record.leerlingnummer

  .then (record) ->
    if not record?
      throw new Error 'HTTP:404 Geen eindexamen leerling!'
    Leerlingen.findOne(where: nummer: record.nummer)

  .then (record) ->
    leerling2object(record, rijdmee)


server.listen 8000
console.warn 'Hasta la viesta!'
