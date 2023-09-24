import limdb
import starRouter
import zmq
import asyncdispatch
import cligen
import times
import os
import tables
import strutils
import strformat
import json
import flatty
type
  MQLog = ref object
    # Object Represnting the datastore for storing messages
    dir: string
    db: Database[string, string]








# proc fromBlob*(b: Blob, T: typedesc[Message[string]]):  Message[string] =
#   ## Convert a chunk of data, key or value, to a string
#   ##
#   ## .. note::
#   ##     If you want other data types than a string, implement this for the data type
#   result = Message[string]()
#   copyMem(result.unsafeAddr, b.mvData, b.mvSize)



proc newMQLog(dir: string): MQLog =
  if not dirExists(dir):
    createDir(dir)
  result = MQLog(dir: dir)
  result.db = initDatabase(dir, (string, string))

proc filterMsg(doc: Message[string]): bool =
  case doc.typ:
    # Filter out noise
    of heartbeat:
      result = false
    of ack:
      result = false
    of nack:
      result = false
    else:
      result = true

proc logMsg(mq: MQLog, msg: Message[string]) =
  let t = mq.db.initTransaction()
  try:
    t[msg.id] = msg.toFlatty()
    t.commit()
  except Exception:
    t.reset()

proc saveLoop(client: Client, db: MqLog) =
  var
    client = client
    inbox = newStringInbox(100)
    db = db

  proc handleMsg(doc: Message[string]) {.async.} =
    db.logMsg(doc)
    when defined(debug):
      echo fmt"Saved: {doc.id}"

  inbox.registerFilter(filterMsg)
  inbox.registerCB(handleMsg)
  while true:
    waitFor runStringInbox(client, inbox)


proc replayLoop(client: Client, mq: MQLog) {.async.} =
  for value in mq.db.values():
    let msg = value.fromFlatty(Message[string])
    await client.emit(msg)

proc record(dir: string = fmt"./recording-{now().toTime().toUnix()}/",
            apiAddress: string = "tcp://127.0.0.1:6001",
            subAddress: string = "tcp://127.0.0.1:6000") =
  var client = newClient("recorder", subAddress, apiAddress, 10, @[""])
  waitFor client.connect
  client.subscribe("")
  var mq = newMQLog(dir)
  client.saveLoop(mq)

proc replay(dir: string = fmt"./recording-{now().toTime().toUnix()}/",
            apiAddress: string = "tcp://127.0.0.1:6001",
            subAddress: string = "tcp://127.0.0.1:6000") =
  var client = newClient("recorder", subAddress, apiAddress, 10, @[""])
  waitFor client.connect()
  var mq = newMQLog(dir)
  waitFor client.replayLoop(mq)


when isMainModule:
  dispatchMulti([record, help={"dir": "path to the lmdb directory, will create if it doesnt exist",
             "subAddress": "Server pub/sub connection string, defaults to tcp://127.0.0.1:6000",
             "apiAddress": "Server Api connection string, defaults to tcp://127.0.0.1:6001"}
  ], [replay, help={"dir": "path to the lmdb directory, will create if it doesnt exist",
             "subAddress": "Server pub/sub connection string, defaults to tcp://127.0.0.1:6000",
             "apiAddress": "Server Api connection string, defaults to tcp://127.0.0.1:6001"}])
