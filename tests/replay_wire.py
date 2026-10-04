"""Actual LMDB recording/replay across the generated 60-type ZeroMQ boundary."""
import json
from pathlib import Path
import socket
import subprocess
import sys
import time
import tempfile
import zmq

root = Path(__file__).resolve().parents[1]
schema = json.loads((root / "schemas/starintel-0.10.1/generated/schema.json").read_text())
manifest = json.loads((root / "schemas/starintel-0.10.1/generated/portable-manifest.json").read_text())

def sample(node):
    if "$ref" in node:
        return sample(schema["$defs"][node["$ref"].split("/")[-1]])
    if "enum" in node:
        return node["enum"][0]
    if "anyOf" in node:
        return sample(node["anyOf"][0])
    kind = node.get("type")
    if kind == "object":
        return {key: sample(node["properties"][key]) for key in node.get("required", [])}
    if kind == "array": return []
    if kind in ("integer", "number"): return node.get("minimum", 0)
    if kind == "boolean": return False
    if node.get("format") == "date-time": return "2026-10-04T12:00:00Z"
    if node.get("format") == "date": return "2026-10-04"
    if node.get("format") == "uri": return "https://example.test/"
    if "pattern" in node:
        if "@" in node["pattern"]: return "fixture@example.test"
        if "0-9()." in node["pattern"]: return "+123456789"
        return "0"
    return "fixture"

def address():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return f"tcp://127.0.0.1:{s.getsockname()[1]}"

def stop(process):
    if process.poll() is None:
        process.terminate()
        try: process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill();process.wait(timeout=5)

pub_address,api_address=address(),address()
context=zmq.Context()
api=context.socket(zmq.DEALER)
api.setsockopt(zmq.IDENTITY,b'documents-test-publisher')
api.setsockopt(zmq.RCVTIMEO,5000)
api.setsockopt(zmq.SNDTIMEO,5000)
api.connect(api_address)
subscriber=context.socket(zmq.SUB)
subscriber.setsockopt(zmq.SUBSCRIBE,b'documents')
subscriber.setsockopt(zmq.RCVTIMEO,5000)
subscriber.connect(pub_address)
processes=[]
try:
    broker=subprocess.Popen([sys.argv[2],'--pubAddress='+pub_address,'--apiAddress='+api_address],
                            stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
    processes.append(broker)
    def send(event,payload,identity):
        api.send_multipart([b'',b'SC01',b'documents-test-publisher',identity.encode(),str(int(time.time())).encode(),
                            str(event).encode(),b'documents',payload.encode()])
        return api.recv_multipart()
    assert send(7,'','registration')==[b'1']
    with tempfile.TemporaryDirectory() as directory:
        recorder=subprocess.Popen([sys.argv[1],'record','--dir='+directory,'--apiAddress='+api_address,'--subAddress='+pub_address],
                                  stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
        processes.append(recorder)
        deadline=time.monotonic()+10
        while not (Path(directory)/'data.mdb').exists():
            assert recorder.poll() is None,recorder.stderr.read().decode()
            assert time.monotonic()<deadline,'recorder did not initialize LMDB'
            time.sleep(.05)
        time.sleep(.3)
        expected={}
        for entry in manifest['types']:
            if entry['kind']!='document':continue
            dtype=entry['name'].split('/')[-1]
            name=''.join(word.capitalize() for word in dtype.split('-'))
            doc=sample(schema['$defs'][name])
            doc.update(id='fixture:'+dtype,dataset='test',dtype=dtype,schemaVersion='0.10.1',
                       extensions={'opaque':{'flag':False,'nil':None,'items':[]}})
            payload=json.dumps(doc)
            identity='record:'+dtype
            assert send(3,payload,identity)==[b'1'],dtype
            frames=subscriber.recv_multipart()
            assert len(frames)==6 and frames[2].decode()==identity and frames[-1].decode()==payload
            expected[identity]=frames
        assert len(expected)==60
        legacy={'_id':'starintel:person:test','dataset':'test','dtype':'person','schema_version':'0.9.0',
                'version':1,'date_added':'2026-10-04T00:00:00Z','date_updated':'2026-10-04T00:00:00Z',
                'sources':[],'evidence':[],'data':{'fname':'Ada'},'extensions':{'opaque':{'flag':False,'nil':None}}}
        payload=json.dumps(legacy)
        identity='record:historical-person'
        assert send(3,payload,identity)==[b'1']
        expected[identity]=subscriber.recv_multipart()
        assert expected[identity][-1].decode()==payload
        # Wait for the real transaction loop to finish before closing its process.
        time.sleep(.5)
        stop(recorder)
        replay=subprocess.Popen([sys.argv[1],'replay','--dir='+directory,'--apiAddress='+api_address,'--subAddress='+pub_address],
                                stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        processes.append(replay)
        actual={}
        for _ in range(len(expected)):
            frames=subscriber.recv_multipart()
            identity=frames[2].decode()
            assert identity not in actual,'duplicate replay'
            assert frames[0]==expected[identity][0] and frames[2]==expected[identity][2] and frames[4:]==expected[identity][4:],(identity,frames,expected[identity])
            assert frames[1].decode().startswith('recorder-'),frames
            assert int(frames[3])>=int(expected[identity][3]),frames
            actual[identity]=frames
        stdout,stderr=replay.communicate(timeout=10)
        assert replay.returncode==0,(stdout.decode(),stderr.decode())
        assert set(actual)==set(expected)
        assert not subscriber.poll(100),'unexpected replay publication'
    with tempfile.TemporaryDirectory() as directory:
        seeded=subprocess.run([sys.argv[3],directory],capture_output=True,text=True,timeout=10)
        assert seeded.returncode==0,seeded.stderr
        rejected=subprocess.run([sys.argv[1],'replay','--dir='+directory,'--apiAddress='+api_address,'--subAddress='+pub_address],
                                capture_output=True,text=True,timeout=10)
        assert rejected.returncode!=0 and 'schema' in rejected.stderr.lower(),rejected.stderr
        assert not subscriber.poll(100),'invalid stored document was published'
    print('actual LMDB recorder/replay: all 60 dtypes, strict historical 0.9.0, invalid stored-record rejection, exact payload bytes and persistent identity/event/topic, single publication PASS')
finally:
    for process in reversed(processes):stop(process)
    api.close(linger=0);subscriber.close(linger=0);context.term()
