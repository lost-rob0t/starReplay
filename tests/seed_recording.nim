## Seed a historical recording outside the network boundary for rejection checks.
import std/os
import limdb
import flatty
import starRouter
let db = initDatabase(paramStr(1), (string, string))
let transaction = db.initTransaction()
let msg = Message[string](id: "invalid:stored", source: "historical-recorder", topic: "documents",
  time: 1, typ: newDocument, data: "{\"_id\":\"old\",\"dtype\":\"person\",\"schema_version\":\"0.10.1\",\"data\":{}}")
transaction[msg.id] = msg.toFlatty()
transaction.commit()
